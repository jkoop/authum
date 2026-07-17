const std = @import("std");
const regex = @import("regex");

pub const Effect = enum { allow, deny };

pub const Subject = union(enum) {
    any,
    user_id: i64,
    group: []const u8,
};

pub const Rule = struct {
    subject: Subject,
    site_id: []const u8, // "*" or exact site_id
    path_pattern: []const u8, // regex source (for display / source TSV)
    path_re: regex.Regexp,
    method: []const u8, // "*" or method
    effect: Effect,
};

pub const LoadResult = union(enum) {
    ok,
    invalid: []u8,
};

pub const Acl = struct {
    allocator: std.mem.Allocator,
    mutex: std.Io.Mutex = .init,
    rules: []Rule = &.{},
    source: []const u8 = "",
    scratch: regex.Scratch,

    pub fn init(allocator: std.mem.Allocator) Acl {
        return .{
            .allocator = allocator,
            .scratch = .init(allocator),
        };
    }

    pub fn deinit(self: *Acl) void {
        self.freeOwned();
        self.scratch.deinit();
    }

    fn freeRule(allocator: std.mem.Allocator, rule: *Rule) void {
        switch (rule.subject) {
            .group => |name| allocator.free(name),
            .any, .user_id => {},
        }
        allocator.free(rule.site_id);
        allocator.free(rule.path_pattern);
        allocator.free(rule.method);
        rule.path_re.deinit();
    }

    fn freeOwned(self: *Acl) void {
        for (self.rules) |*rule| freeRule(self.allocator, rule);
        self.allocator.free(self.rules);
        self.allocator.free(self.source);
        self.rules = &.{};
        self.source = "";
    }

    /// On parse failure returns `.invalid` with a message allocated from `msg_allocator`.
    /// Does not modify the in-memory ACL on failure.
    pub fn loadTsv(self: *Acl, io: std.Io, tsv: []const u8, msg_allocator: std.mem.Allocator) !LoadResult {
        var rules: std.ArrayList(Rule) = .empty;
        errdefer {
            for (rules.items) |*rule| freeRule(self.allocator, rule);
            rules.deinit(self.allocator);
        }

        var lines = std.mem.splitScalar(u8, tsv, '\n');
        var line_no: usize = 0;
        while (lines.next()) |raw_line| {
            line_no += 1;
            const line = std.mem.trim(u8, raw_line, " \t\r");
            if (line.len == 0 or line[0] == '#') continue;

            var cols: [5][]const u8 = .{ "", "", "", "", "" };
            var col_count: usize = 0;
            var it = std.mem.splitScalar(u8, line, '\t');
            while (it.next()) |raw_col| {
                const col = std.mem.trim(u8, raw_col, " \t\r");
                if (col_count < cols.len) cols[col_count] = col;
                col_count += 1;
            }
            // Extra columns ignored; missing trailing columns stay blank ("").

            const user_col = cols[0];
            const site_col = cols[1];
            const path_col = cols[2];
            const method_col = cols[3];
            const effect_col = cols[4];

            // Header row: site_id or legacy host; path or legacy path_prefix.
            if (std.mem.eql(u8, user_col, "user") and (site_col.len == 0 or
                std.mem.eql(u8, site_col, "site_id") or
                std.mem.eql(u8, site_col, "host"))) continue;

            const subject: Subject = if (std.mem.eql(u8, user_col, "*"))
                .any
            else if (user_col.len > 1 and user_col[0] == '@') blk: {
                const gname = user_col[1..];
                if (gname.len == 0 or !validGroupName(gname)) {
                    return .{ .invalid = try std.fmt.allocPrint(
                        msg_allocator,
                        "ACL line {d}: group must be '@name' with [A-Za-z0-9_], got {s}",
                        .{ line_no, user_col },
                    ) };
                }
                break :blk .{ .group = try self.allocator.dupe(u8, gname) };
            } else blk: {
                const colon = std.mem.indexOfScalar(u8, user_col, ':') orelse {
                    return .{ .invalid = try std.fmt.allocPrint(
                        msg_allocator,
                        "ACL line {d}: user must be '*', 'id:username', or '@group', got {s}",
                        .{ line_no, user_col },
                    ) };
                };
                const id = std.fmt.parseInt(i64, user_col[0..colon], 10) catch {
                    return .{ .invalid = try std.fmt.allocPrint(
                        msg_allocator,
                        "ACL line {d}: invalid user id in {s}",
                        .{ line_no, user_col },
                    ) };
                };
                // Username after ':' is a human label only; authz uses id.
                break :blk .{ .user_id = id };
            };
            // Cleared only after the rule is appended (`.invalid` is not an error return).
            var subject_owned = true;
            defer if (subject_owned) switch (subject) {
                .group => |name| self.allocator.free(name),
                .any, .user_id => {},
            };

            if (site_col.len == 0 or path_col.len == 0 or method_col.len == 0) {
                return .{ .invalid = try std.fmt.allocPrint(
                    msg_allocator,
                    "ACL line {d}: site_id, path, and method must be non-empty",
                    .{line_no},
                ) };
            }

            const effect: Effect = if (std.mem.eql(u8, effect_col, "allow"))
                .allow
            else if (std.mem.eql(u8, effect_col, "deny"))
                .deny
            else {
                return .{ .invalid = try std.fmt.allocPrint(
                    msg_allocator,
                    "ACL line {d}: effect must be 'allow' or 'deny', got {s}",
                    .{ line_no, effect_col },
                ) };
            };

            var path_re = regex.compile(self.allocator, path_col) catch {
                return .{ .invalid = try std.fmt.allocPrint(
                    msg_allocator,
                    "ACL line {d}: invalid path regex: {s}",
                    .{ line_no, path_col },
                ) };
            };
            var path_re_owned = true;
            defer if (path_re_owned) path_re.deinit();

            const site_id = try self.allocator.dupe(u8, site_col);
            errdefer self.allocator.free(site_id);
            const path_pattern = try self.allocator.dupe(u8, path_col);
            errdefer self.allocator.free(path_pattern);
            const method = try self.allocator.dupe(u8, method_col);
            errdefer self.allocator.free(method);

            try rules.append(self.allocator, .{
                .subject = subject,
                .site_id = site_id,
                .path_pattern = path_pattern,
                .path_re = path_re,
                .method = method,
                .effect = effect,
            });
            subject_owned = false;
            path_re_owned = false;
        }

        const owned_source = try self.allocator.dupe(u8, tsv);
        errdefer self.allocator.free(owned_source);
        const owned_rules = try rules.toOwnedSlice(self.allocator);

        self.mutex.lockUncancelable(io);
        defer self.mutex.unlock(io);
        self.freeOwned();
        self.rules = owned_rules;
        self.source = owned_source;
        return .ok;
    }

    pub fn snapshotSource(self: *Acl, io: std.Io, allocator: std.mem.Allocator) ![]u8 {
        self.mutex.lockUncancelable(io);
        defer self.mutex.unlock(io);
        return try allocator.dupe(u8, self.source);
    }

    /// Read-only HTML table of current rules (escaped). Allocated from `allocator`.
    pub fn htmlTable(self: *Acl, io: std.Io, allocator: std.mem.Allocator) ![]u8 {
        self.mutex.lockUncancelable(io);
        defer self.mutex.unlock(io);

        var out: std.ArrayList(u8) = .empty;
        errdefer out.deinit(allocator);
        try out.appendSlice(allocator,
            \\<table>
            \\<tr><th>user</th><th>site_id</th><th>path</th><th>method</th><th>effect</th></tr>
        );
        for (self.rules) |rule| {
            const user = switch (rule.subject) {
                .any => "*",
                .user_id => |id| try std.fmt.allocPrint(allocator, "{d}", .{id}),
                .group => |name| try std.fmt.allocPrint(allocator, "@{s}", .{name}),
            };
            const site = try htmlEscape(allocator, rule.site_id);
            const path = try htmlEscape(allocator, rule.path_pattern);
            const method = try htmlEscape(allocator, rule.method);
            const effect = @tagName(rule.effect);
            const row = try std.fmt.allocPrint(allocator,
                \\<tr><td>{s}</td><td>{s}</td><td>{s}</td><td>{s}</td><td>{s}</td></tr>
            , .{ user, site, path, method, effect });
            try out.appendSlice(allocator, row);
        }
        try out.appendSlice(allocator, "</table>");
        return try out.toOwnedSlice(allocator);
    }

    fn htmlEscape(allocator: std.mem.Allocator, value: []const u8) ![]u8 {
        var list: std.ArrayList(u8) = .empty;
        errdefer list.deinit(allocator);
        for (value) |c| {
            switch (c) {
                '&' => try list.appendSlice(allocator, "&amp;"),
                '<' => try list.appendSlice(allocator, "&lt;"),
                '>' => try list.appendSlice(allocator, "&gt;"),
                '"' => try list.appendSlice(allocator, "&quot;"),
                else => try list.append(allocator, c),
            }
        }
        return try list.toOwnedSlice(allocator);
    }

    /// First match wins. No match => deny.
    /// `groups` is the caller's group name memberships for `user_id`.
    /// User subjects match by numeric id only (username in the TSV is a label).
    pub fn decide(
        self: *Acl,
        io: std.Io,
        user_id: i64,
        groups: []const []const u8,
        site_id: []const u8,
        path: []const u8,
        method: []const u8,
    ) Effect {
        self.mutex.lockUncancelable(io);
        defer self.mutex.unlock(io);

        for (self.rules) |*rule| {
            switch (rule.subject) {
                .any => {},
                .user_id => |rid| if (rid != user_id) continue,
                .group => |gname| {
                    var member = false;
                    for (groups) |g| {
                        if (std.mem.eql(u8, g, gname)) {
                            member = true;
                            break;
                        }
                    }
                    if (!member) continue;
                },
            }
            if (!std.mem.eql(u8, rule.site_id, "*") and !std.mem.eql(u8, rule.site_id, site_id)) continue;
            const path_ok = rule.path_re.matchScratch(&self.scratch, path) catch false;
            if (!path_ok) continue;
            if (!std.mem.eql(u8, rule.method, "*") and !std.ascii.eqlIgnoreCase(rule.method, method)) continue;
            return rule.effect;
        }
        return .deny;
    }
};

fn validGroupName(name: []const u8) bool {
    return @import("util.zig").validUsername(name);
}

test "acl first match and default deny" {
    var acl = Acl.init(std.testing.allocator);
    defer acl.deinit();
    const io = std.testing.io;
    const result = try acl.loadTsv(
        io,
        "user\tsite_id\tpath\tmethod\teffect\n" ++
            "12:alice\talpha\t^/api/\tGET\tallow\n" ++
            "*\talpha\t^/admin\t*\tdeny\n" ++
            "*\talpha\t^/\t*\tallow\n",
        std.testing.allocator,
    );
    try std.testing.expect(result == .ok);
    const none: []const []const u8 = &.{};
    try std.testing.expect(acl.decide(io, 12, none, "alpha", "/api/x", "GET") == .allow);
    try std.testing.expect(acl.decide(io, 12, none, "alpha", "/admin", "POST") == .deny);
    try std.testing.expect(acl.decide(io, 99, none, "alpha", "/other", "GET") == .allow);
    try std.testing.expect(acl.decide(io, 12, none, "other", "/", "GET") == .deny);
}

test "acl path regex can deny pdfs" {
    var acl = Acl.init(std.testing.allocator);
    defer acl.deinit();
    const io = std.testing.io;
    const result = try acl.loadTsv(
        io,
        "*\tfiles\t(?i)\\.pdf$\t*\tdeny\n" ++
            "*\tfiles\t^/\t*\tallow\n",
        std.testing.allocator,
    );
    try std.testing.expect(result == .ok);
    try std.testing.expect(acl.decide(io, 1, &.{}, "files", "/docs/report.PDF", "GET") == .deny);
    try std.testing.expect(acl.decide(io, 1, &.{}, "files", "/docs/readme.txt", "GET") == .allow);
}

test "acl user subject matches id not username label" {
    var acl = Acl.init(std.testing.allocator);
    defer acl.deinit();
    const io = std.testing.io;
    // Label says "alice" but authz only cares about id 12.
    const result = try acl.loadTsv(
        io,
        "12:alice\tsite\t^/\t*\tallow\n",
        std.testing.allocator,
    );
    try std.testing.expect(result == .ok);
    try std.testing.expect(acl.decide(io, 12, &.{}, "site", "/", "GET") == .allow);
    try std.testing.expect(acl.decide(io, 99, &.{}, "site", "/", "GET") == .deny);
}

test "acl group subject matches membership" {
    var acl = Acl.init(std.testing.allocator);
    defer acl.deinit();
    const io = std.testing.io;
    const result = try acl.loadTsv(
        io,
        "@friends\tjellyfin\t^/\t*\tallow\n",
        std.testing.allocator,
    );
    try std.testing.expect(result == .ok);
    const member: []const []const u8 = &.{"friends"};
    const outsider: []const []const u8 = &.{"other"};
    try std.testing.expect(acl.decide(io, 1, member, "jellyfin", "/", "GET") == .allow);
    try std.testing.expect(acl.decide(io, 1, outsider, "jellyfin", "/", "GET") == .deny);
    try std.testing.expect(acl.decide(io, 1, &.{}, "jellyfin", "/", "GET") == .deny);
}

test "acl bad group subject" {
    var acl = Acl.init(std.testing.allocator);
    defer acl.deinit();
    const result = try acl.loadTsv(
        std.testing.io,
        "@\tjellyfin\t^/\t*\tallow\n",
        std.testing.allocator,
    );
    try std.testing.expect(result == .invalid);
    defer std.testing.allocator.free(result.invalid);
}

test "acl invalid path regex" {
    var acl = Acl.init(std.testing.allocator);
    defer acl.deinit();
    const result = try acl.loadTsv(
        std.testing.io,
        "*\tsite\t[\t*\tallow\n",
        std.testing.allocator,
    );
    try std.testing.expect(result == .invalid);
    defer std.testing.allocator.free(result.invalid);
    try std.testing.expect(std.mem.indexOf(u8, result.invalid, "regex") != null);
}

test "acl ignores extra columns and pads missing trailing columns" {
    var acl = Acl.init(std.testing.allocator);
    defer acl.deinit();
    const io = std.testing.io;
    const result = try acl.loadTsv(
        io,
        "user\tsite_id\tpath\tmethod\teffect\textra\n" ++
            "*\talpha\t^/\t*\tallow\tignored\tmore\n",
        std.testing.allocator,
    );
    try std.testing.expect(result == .ok);
    try std.testing.expect(acl.decide(io, 1, &.{}, "alpha", "/", "GET") == .allow);

    var acl2 = Acl.init(std.testing.allocator);
    defer acl2.deinit();
    const short = try acl2.loadTsv(
        std.testing.io,
        "*\talpha\t/\n",
        std.testing.allocator,
    );
    try std.testing.expect(short == .invalid);
    defer std.testing.allocator.free(short.invalid);
}

test "acl nice error on bad effect" {
    var acl = Acl.init(std.testing.allocator);
    defer acl.deinit();
    const result = try acl.loadTsv(
        std.testing.io,
        "*\tsite\t^/\t*\tyes\n",
        std.testing.allocator,
    );
    try std.testing.expect(result == .invalid);
    defer std.testing.allocator.free(result.invalid);
    try std.testing.expect(std.mem.indexOf(u8, result.invalid, "line 1") != null);
}

test "acl header accepts legacy host and path_prefix column names" {
    var acl = Acl.init(std.testing.allocator);
    defer acl.deinit();
    const result = try acl.loadTsv(
        std.testing.io,
        "user\thost\tpath_prefix\tmethod\teffect\n" ++
            "*\talpha\t^/\t*\tallow\n",
        std.testing.allocator,
    );
    try std.testing.expect(result == .ok);
    try std.testing.expect(acl.decide(std.testing.io, 1, &.{}, "alpha", "/", "GET") == .allow);
}
