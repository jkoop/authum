const std = @import("std");
const regex = @import("regex");

pub const Effect = enum { allow, deny };

pub const Subject = union(enum) {
    any,
    user_id: i64,
    group_id: i64,
};

pub const Rule = struct {
    id: i64,
    pos: i64,
    subject: Subject,
    site_id: ?i64, // null = *
    path_pattern: []const u8,
    path_re: regex.Regexp,
    method: []const u8,
    effect: Effect,
};

/// Parsed TSV / form row before DB insert (no compiled regex).
pub const ParsedRule = struct {
    subject: Subject,
    site_id: ?i64,
    path: []const u8,
    method: []const u8,
    effect: Effect,
};

pub const ParseResult = union(enum) {
    ok: []ParsedRule,
    invalid: []u8,
};

pub const Acl = struct {
    allocator: std.mem.Allocator,
    mutex: std.Io.Mutex = .init,
    rules: []Rule = &.{},
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
        allocator.free(rule.path_pattern);
        allocator.free(rule.method);
        rule.path_re.deinit();
    }

    fn freeOwned(self: *Acl) void {
        for (self.rules) |*rule| freeRule(self.allocator, rule);
        self.allocator.free(self.rules);
        self.rules = &.{};
    }

    pub const DbRule = struct {
        id: i64,
        pos: i64,
        subject: Subject,
        site_id: ?i64,
        path: []const u8,
        method: []const u8,
        effect: Effect,
    };

    /// Replace in-memory ACL from DB-shaped rows (compiles path regexes).
    pub fn load(self: *Acl, io: std.Io, rows: []const DbRule) !void {
        var rules: std.ArrayList(Rule) = .empty;
        errdefer {
            for (rules.items) |*rule| freeRule(self.allocator, rule);
            rules.deinit(self.allocator);
        }

        for (rows) |row| {
            var path_re = try regex.compile(self.allocator, row.path);
            errdefer path_re.deinit();
            const path_pattern = try self.allocator.dupe(u8, row.path);
            errdefer self.allocator.free(path_pattern);
            const method = try self.allocator.dupe(u8, row.method);
            errdefer self.allocator.free(method);
            try rules.append(self.allocator, .{
                .id = row.id,
                .pos = row.pos,
                .subject = row.subject,
                .site_id = row.site_id,
                .path_pattern = path_pattern,
                .path_re = path_re,
                .method = method,
                .effect = row.effect,
            });
        }

        const owned = try rules.toOwnedSlice(self.allocator);
        self.mutex.lockUncancelable(io);
        defer self.mutex.unlock(io);
        self.freeOwned();
        self.rules = owned;
    }

    /// Parse backup TSV. Subject: `*`, `#user_id`, `@group_id`. Site: `*` or numeric id.
    /// Path strings alias into `tsv`.
    pub fn parseTsv(tsv: []const u8, msg_allocator: std.mem.Allocator) !ParseResult {
        var list: std.ArrayList(ParsedRule) = .empty;
        errdefer list.deinit(msg_allocator);

        var lines = std.mem.splitScalar(u8, tsv, '\n');
        var line_no: usize = 0;
        while (lines.next()) |raw_line| {
            line_no += 1;
            const line = std.mem.trim(u8, raw_line, " \t\r");
            if (line.len == 0) continue;
            // Comments: '#' not followed by a digit (so '#10\t…' is a rule).
            if (line[0] == '#' and (line.len == 1 or !std.ascii.isDigit(line[1]))) continue;

            var cols: [5][]const u8 = .{ "", "", "", "", "" };
            var col_count: usize = 0;
            var it = std.mem.splitScalar(u8, line, '\t');
            while (it.next()) |raw_col| {
                const col = std.mem.trim(u8, raw_col, " \t\r");
                if (col_count < cols.len) cols[col_count] = col;
                col_count += 1;
            }

            const user_col = cols[0];
            const site_col = cols[1];
            const path_col = cols[2];
            const method_col = cols[3];
            const effect_col = cols[4];

            if (std.mem.eql(u8, user_col, "user") and (site_col.len == 0 or
                std.mem.eql(u8, site_col, "site_id") or
                std.mem.eql(u8, site_col, "host"))) continue;

            const subject = parseSubject(user_col) catch {
                return .{ .invalid = try std.fmt.allocPrint(
                    msg_allocator,
                    "ACL line {d}: user must be '*', '#id', or '@id', got {s}",
                    .{ line_no, user_col },
                ) };
            };

            if (site_col.len == 0 or path_col.len == 0 or method_col.len == 0) {
                return .{ .invalid = try std.fmt.allocPrint(
                    msg_allocator,
                    "ACL line {d}: site_id, path, and method must be non-empty",
                    .{line_no},
                ) };
            }

            const site_id: ?i64 = if (std.mem.eql(u8, site_col, "*"))
                null
            else
                std.fmt.parseInt(i64, site_col, 10) catch {
                    return .{ .invalid = try std.fmt.allocPrint(
                        msg_allocator,
                        "ACL line {d}: site_id must be '*' or numeric id, got {s}",
                        .{ line_no, site_col },
                    ) };
                };

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

            // Validate regex compiles.
            var path_re = regex.compile(msg_allocator, path_col) catch {
                return .{ .invalid = try std.fmt.allocPrint(
                    msg_allocator,
                    "ACL line {d}: invalid path regex: {s}",
                    .{ line_no, path_col },
                ) };
            };
            path_re.deinit();

            try list.append(msg_allocator, .{
                .subject = subject,
                .site_id = site_id,
                .path = path_col,
                .method = method_col,
                .effect = effect,
            });
        }

        return .{ .ok = try list.toOwnedSlice(msg_allocator) };
    }

    pub fn exportTsv(self: *Acl, io: std.Io, allocator: std.mem.Allocator) ![]u8 {
        self.mutex.lockUncancelable(io);
        defer self.mutex.unlock(io);

        var out: std.ArrayList(u8) = .empty;
        errdefer out.deinit(allocator);
        try out.appendSlice(allocator, "user\tsite_id\tpath\tmethod\teffect\n");
        for (self.rules) |rule| {
            const user = switch (rule.subject) {
                .any => "*",
                .user_id => |id| try std.fmt.allocPrint(allocator, "#{d}", .{id}),
                .group_id => |id| try std.fmt.allocPrint(allocator, "@{d}", .{id}),
            };
            const site = if (rule.site_id) |sid|
                try std.fmt.allocPrint(allocator, "{d}", .{sid})
            else
                "*";
            const row = try std.fmt.allocPrint(allocator, "{s}\t{s}\t{s}\t{s}\t{s}\n", .{
                user,
                site,
                rule.path_pattern,
                rule.method,
                @tagName(rule.effect),
            });
            try out.appendSlice(allocator, row);
        }
        return try out.toOwnedSlice(allocator);
    }

    /// First match wins. No match => deny.
    /// `group_ids` is the caller's group id memberships.
    pub fn decide(
        self: *Acl,
        io: std.Io,
        user_id: i64,
        group_ids: []const i64,
        site_id: i64,
        path: []const u8,
        method: []const u8,
    ) Effect {
        self.mutex.lockUncancelable(io);
        defer self.mutex.unlock(io);

        for (self.rules) |*rule| {
            switch (rule.subject) {
                .any => {},
                .user_id => |rid| if (rid != user_id) continue,
                .group_id => |gid| {
                    var member = false;
                    for (group_ids) |g| {
                        if (g == gid) {
                            member = true;
                            break;
                        }
                    }
                    if (!member) continue;
                },
            }
            if (rule.site_id) |rid| {
                if (rid != site_id) continue;
            }
            const path_ok = rule.path_re.matchScratch(&self.scratch, path) catch false;
            if (!path_ok) continue;
            if (!std.mem.eql(u8, rule.method, "*") and !std.ascii.eqlIgnoreCase(rule.method, method)) continue;
            return rule.effect;
        }
        return .deny;
    }
};

pub fn parseSubject(user_col: []const u8) !Subject {
    if (std.mem.eql(u8, user_col, "*")) return .any;
    if (user_col.len >= 2 and user_col[0] == '#' and std.ascii.isDigit(user_col[1])) {
        const id = try std.fmt.parseInt(i64, user_col[1..], 10);
        return .{ .user_id = id };
    }
    if (user_col.len >= 2 and user_col[0] == '@' and std.ascii.isDigit(user_col[1])) {
        const id = try std.fmt.parseInt(i64, user_col[1..], 10);
        return .{ .group_id = id };
    }
    return error.InvalidSubject;
}

pub fn formatSubject(allocator: std.mem.Allocator, subject: Subject) ![]u8 {
    return switch (subject) {
        .any => try allocator.dupe(u8, "*"),
        .user_id => |id| try std.fmt.allocPrint(allocator, "#{d}", .{id}),
        .group_id => |id| try std.fmt.allocPrint(allocator, "@{d}", .{id}),
    };
}

test "acl first match and default deny" {
    var acl = Acl.init(std.testing.allocator);
    defer acl.deinit();
    const io = std.testing.io;
    const parsed = try Acl.parseTsv(
        "user\tsite_id\tpath\tmethod\teffect\n" ++
            "#12\t1\t^/api/\tGET\tallow\n" ++
            "*\t1\t^/admin\t*\tdeny\n" ++
            "*\t1\t^/\t*\tallow\n",
        std.testing.allocator,
    );
    defer switch (parsed) {
        .ok => |r| std.testing.allocator.free(r),
        .invalid => |m| std.testing.allocator.free(m),
    };
    try std.testing.expect(parsed == .ok);
    var rows: [3]Acl.DbRule = undefined;
    for (parsed.ok, 0..) |p, i| {
        rows[i] = .{
            .id = @intCast(i + 1),
            .pos = @intCast(i),
            .subject = p.subject,
            .site_id = p.site_id,
            .path = p.path,
            .method = p.method,
            .effect = p.effect,
        };
    }
    try acl.load(io, &rows);
    const none: []const i64 = &.{};
    try std.testing.expect(acl.decide(io, 12, none, 1, "/api/x", "GET") == .allow);
    try std.testing.expect(acl.decide(io, 12, none, 1, "/admin", "POST") == .deny);
    try std.testing.expect(acl.decide(io, 99, none, 1, "/other", "GET") == .allow);
    try std.testing.expect(acl.decide(io, 12, none, 2, "/", "GET") == .deny);
}

test "acl path regex can deny pdfs" {
    var acl = Acl.init(std.testing.allocator);
    defer acl.deinit();
    const io = std.testing.io;
    const parsed = try Acl.parseTsv(
        "*\t2\t(?i)\\.pdf$\t*\tdeny\n" ++
            "*\t2\t^/\t*\tallow\n",
        std.testing.allocator,
    );
    defer std.testing.allocator.free(parsed.ok);
    try std.testing.expect(parsed == .ok);
    var rows: [2]Acl.DbRule = undefined;
    for (parsed.ok, 0..) |p, i| {
        rows[i] = .{
            .id = @intCast(i + 1),
            .pos = @intCast(i),
            .subject = p.subject,
            .site_id = p.site_id,
            .path = p.path,
            .method = p.method,
            .effect = p.effect,
        };
    }
    try acl.load(io, &rows);
    try std.testing.expect(acl.decide(io, 1, &.{}, 2, "/docs/report.PDF", "GET") == .deny);
    try std.testing.expect(acl.decide(io, 1, &.{}, 2, "/docs/readme.txt", "GET") == .allow);
}

test "acl user subject matches id" {
    var acl = Acl.init(std.testing.allocator);
    defer acl.deinit();
    const io = std.testing.io;
    const parsed = try Acl.parseTsv("#12\t3\t^/\t*\tallow\n", std.testing.allocator);
    defer std.testing.allocator.free(parsed.ok);
    try std.testing.expect(parsed == .ok);
    const rows = [_]Acl.DbRule{.{
        .id = 1,
        .pos = 0,
        .subject = parsed.ok[0].subject,
        .site_id = parsed.ok[0].site_id,
        .path = parsed.ok[0].path,
        .method = parsed.ok[0].method,
        .effect = parsed.ok[0].effect,
    }};
    try acl.load(io, &rows);
    try std.testing.expect(acl.decide(io, 12, &.{}, 3, "/", "GET") == .allow);
    try std.testing.expect(acl.decide(io, 99, &.{}, 3, "/", "GET") == .deny);
}

test "acl group subject matches membership" {
    var acl = Acl.init(std.testing.allocator);
    defer acl.deinit();
    const io = std.testing.io;
    const parsed = try Acl.parseTsv("@5\t4\t^/\t*\tallow\n", std.testing.allocator);
    defer std.testing.allocator.free(parsed.ok);
    try std.testing.expect(parsed == .ok);
    const rows = [_]Acl.DbRule{.{
        .id = 1,
        .pos = 0,
        .subject = parsed.ok[0].subject,
        .site_id = parsed.ok[0].site_id,
        .path = parsed.ok[0].path,
        .method = parsed.ok[0].method,
        .effect = parsed.ok[0].effect,
    }};
    try acl.load(io, &rows);
    const member: []const i64 = &.{5};
    const outsider: []const i64 = &.{9};
    try std.testing.expect(acl.decide(io, 1, member, 4, "/", "GET") == .allow);
    try std.testing.expect(acl.decide(io, 1, outsider, 4, "/", "GET") == .deny);
    try std.testing.expect(acl.decide(io, 1, &.{}, 4, "/", "GET") == .deny);
}

test "acl rejects legacy named subjects" {
    const r1 = try Acl.parseTsv("12:alice\t1\t^/\t*\tallow\n", std.testing.allocator);
    defer std.testing.allocator.free(r1.invalid);
    try std.testing.expect(r1 == .invalid);

    const r2 = try Acl.parseTsv("@friends\t1\t^/\t*\tallow\n", std.testing.allocator);
    defer std.testing.allocator.free(r2.invalid);
    try std.testing.expect(r2 == .invalid);
}

test "acl bad group subject" {
    const result = try Acl.parseTsv("@\t1\t^/\t*\tallow\n", std.testing.allocator);
    defer std.testing.allocator.free(result.invalid);
    try std.testing.expect(result == .invalid);
}

test "acl invalid path regex" {
    const result = try Acl.parseTsv("*\t1\t[\t*\tallow\n", std.testing.allocator);
    defer std.testing.allocator.free(result.invalid);
    try std.testing.expect(result == .invalid);
    try std.testing.expect(std.mem.indexOf(u8, result.invalid, "regex") != null);
}

test "acl ignores extra columns and pads missing trailing columns" {
    const parsed = try Acl.parseTsv(
        "user\tsite_id\tpath\tmethod\teffect\textra\n" ++
            "*\t*\t^/\t*\tallow\tignored\tmore\n",
        std.testing.allocator,
    );
    defer std.testing.allocator.free(parsed.ok);
    try std.testing.expect(parsed == .ok);
    try std.testing.expect(parsed.ok[0].site_id == null);

    const short = try Acl.parseTsv("*\t1\t/\n", std.testing.allocator);
    defer std.testing.allocator.free(short.invalid);
    try std.testing.expect(short == .invalid);
}

test "acl nice error on bad effect" {
    const result = try Acl.parseTsv("*\t1\t^/\t*\tyes\n", std.testing.allocator);
    defer std.testing.allocator.free(result.invalid);
    try std.testing.expect(result == .invalid);
    try std.testing.expect(std.mem.indexOf(u8, result.invalid, "line 1") != null);
}
