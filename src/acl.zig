const std = @import("std");

pub const Effect = enum { allow, deny };

pub const Rule = struct {
    user_id: ?i64, // null means wildcard *
    site_id: []const u8, // "*" or exact site_id
    path_prefix: []const u8,
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

    pub fn init(allocator: std.mem.Allocator) Acl {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *Acl) void {
        self.freeOwned();
    }

    fn freeOwned(self: *Acl) void {
        for (self.rules) |rule| {
            self.allocator.free(rule.site_id);
            self.allocator.free(rule.path_prefix);
            self.allocator.free(rule.method);
        }
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
            for (rules.items) |rule| {
                self.allocator.free(rule.site_id);
                self.allocator.free(rule.path_prefix);
                self.allocator.free(rule.method);
            }
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

            // Header row: accept site_id or legacy host as the second column name.
            if (std.mem.eql(u8, user_col, "user") and (site_col.len == 0 or
                std.mem.eql(u8, site_col, "site_id") or
                std.mem.eql(u8, site_col, "host"))) continue;

            const user_id: ?i64 = if (std.mem.eql(u8, user_col, "*"))
                null
            else blk: {
                const colon = std.mem.indexOfScalar(u8, user_col, ':') orelse {
                    return .{ .invalid = try std.fmt.allocPrint(
                        msg_allocator,
                        "ACL line {d}: user must be '*' or 'id:username', got {s}",
                        .{ line_no, user_col },
                    ) };
                };
                break :blk std.fmt.parseInt(i64, user_col[0..colon], 10) catch {
                    return .{ .invalid = try std.fmt.allocPrint(
                        msg_allocator,
                        "ACL line {d}: invalid user id in {s}",
                        .{ line_no, user_col },
                    ) };
                };
            };

            if (site_col.len == 0 or path_col.len == 0 or method_col.len == 0) {
                return .{ .invalid = try std.fmt.allocPrint(
                    msg_allocator,
                    "ACL line {d}: site_id, path_prefix, and method must be non-empty",
                    .{line_no},
                ) };
            }

            const effect: Effect = if (std.mem.eql(u8, effect_col, "allow"))
                .allow
            else if (std.mem.eql(u8, effect_col, "deny"))
                .deny
            else
                return .{ .invalid = try std.fmt.allocPrint(
                    msg_allocator,
                    "ACL line {d}: effect must be 'allow' or 'deny', got {s}",
                    .{ line_no, effect_col },
                ) };

            try rules.append(self.allocator, .{
                .user_id = user_id,
                .site_id = try self.allocator.dupe(u8, site_col),
                .path_prefix = try self.allocator.dupe(u8, path_col),
                .method = try self.allocator.dupe(u8, method_col),
                .effect = effect,
            });
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
            \\<table border="1" cellpadding="4">
            \\<tr><th>user</th><th>site_id</th><th>path_prefix</th><th>method</th><th>effect</th></tr>
        );
        for (self.rules) |rule| {
            const user = if (rule.user_id) |id|
                try std.fmt.allocPrint(allocator, "{d}", .{id})
            else
                "*";
            const site = try htmlEscape(allocator, rule.site_id);
            const path = try htmlEscape(allocator, rule.path_prefix);
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
    pub fn decide(self: *Acl, io: std.Io, user_id: i64, site_id: []const u8, path: []const u8, method: []const u8) Effect {
        self.mutex.lockUncancelable(io);
        defer self.mutex.unlock(io);

        for (self.rules) |rule| {
            if (rule.user_id) |rid| {
                if (rid != user_id) continue;
            }
            if (!std.mem.eql(u8, rule.site_id, "*") and !std.mem.eql(u8, rule.site_id, site_id)) continue;
            if (!std.mem.startsWith(u8, path, rule.path_prefix)) continue;
            if (!std.mem.eql(u8, rule.method, "*") and !std.ascii.eqlIgnoreCase(rule.method, method)) continue;
            return rule.effect;
        }
        return .deny;
    }
};

test "acl first match and default deny" {
    var acl = Acl.init(std.testing.allocator);
    defer acl.deinit();
    const io = std.testing.io;
    const result = try acl.loadTsv(
        io,
        "user\tsite_id\tpath_prefix\tmethod\teffect\n" ++
            "12:alice\talpha\t/api/\tGET\tallow\n" ++
            "*\talpha\t/admin\t*\tdeny\n" ++
            "*\talpha\t/\t*\tallow\n",
        std.testing.allocator,
    );
    try std.testing.expect(result == .ok);
    try std.testing.expect(acl.decide(io, 12, "alpha", "/api/x", "GET") == .allow);
    try std.testing.expect(acl.decide(io, 12, "alpha", "/admin", "POST") == .deny);
    try std.testing.expect(acl.decide(io, 99, "alpha", "/other", "GET") == .allow);
    try std.testing.expect(acl.decide(io, 12, "other", "/", "GET") == .deny);
}

test "acl ignores extra columns and pads missing trailing columns" {
    var acl = Acl.init(std.testing.allocator);
    defer acl.deinit();
    const io = std.testing.io;
    // Full row with extras ignored.
    const result = try acl.loadTsv(
        io,
        "user\tsite_id\tpath_prefix\tmethod\teffect\textra\n" ++
            "*\talpha\t/\t*\tallow\tignored\tmore\n",
        std.testing.allocator,
    );
    try std.testing.expect(result == .ok);
    try std.testing.expect(acl.decide(io, 1, "alpha", "/", "GET") == .allow);

    // Missing trailing columns → blanks → nice error (not silent skip).
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
        "*\tsite\t/\t*\tyes\n",
        std.testing.allocator,
    );
    try std.testing.expect(result == .invalid);
    defer std.testing.allocator.free(result.invalid);
    try std.testing.expect(std.mem.indexOf(u8, result.invalid, "line 1") != null);
}

test "acl header accepts legacy host column name" {
    var acl = Acl.init(std.testing.allocator);
    defer acl.deinit();
    const result = try acl.loadTsv(
        std.testing.io,
        "user\thost\tpath_prefix\tmethod\teffect\n" ++
            "*\talpha\t/\t*\tallow\n",
        std.testing.allocator,
    );
    try std.testing.expect(result == .ok);
    try std.testing.expect(acl.decide(std.testing.io, 1, "alpha", "/", "GET") == .allow);
}
