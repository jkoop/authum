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

    pub const Decision = struct {
        effect: Effect,
        /// Rule id that produced the decision, null when no rule matched (implicit deny).
        rule_id: ?i64,
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

    fn methodMatches(rule_method: []const u8, method_norm: []const u8) bool {
        if (std.mem.eql(u8, rule_method, "*")) return true;
        var it = std.mem.splitScalar(u8, rule_method, ',');
        while (it.next()) |raw| {
            const tok = std.mem.trim(u8, raw, " \t");
            if (tok.len == 0) continue;
            if (std.ascii.eqlIgnoreCase(tok, method_norm)) return true;
        }
        return false;
    }

    /// First match wins. No match => deny.
    /// `group_ids` is the caller's group id memberships.
    pub fn decideWithRule(
        self: *Acl,
        io: std.Io,
        user_id: i64,
        group_ids: []const i64,
        site_id: i64,
        path: []const u8,
        method: []const u8,
    ) Decision {
        self.mutex.lockUncancelable(io);
        defer self.mutex.unlock(io);

        const method_norm = if (std.ascii.eqlIgnoreCase(method, "HEAD")) "GET" else method;

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
            if (!methodMatches(rule.method, method_norm)) continue;
            return .{ .effect = rule.effect, .rule_id = rule.id };
        }
        return .{ .effect = .deny, .rule_id = null };
    }

    pub fn decide(
        self: *Acl,
        io: std.Io,
        user_id: i64,
        group_ids: []const i64,
        site_id: i64,
        path: []const u8,
        method: []const u8,
    ) Effect {
        return self.decideWithRule(io, user_id, group_ids, site_id, path, method).effect;
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
    const rows = [_]Acl.DbRule{
        .{ .id = 1, .pos = 0, .subject = .{ .user_id = 12 }, .site_id = 1, .path = "^/api/", .method = "GET", .effect = .allow },
        .{ .id = 2, .pos = 1, .subject = .any, .site_id = 1, .path = "^/admin", .method = "*", .effect = .deny },
        .{ .id = 3, .pos = 2, .subject = .any, .site_id = 1, .path = "^/", .method = "*", .effect = .allow },
    };
    try acl.load(io, &rows);
    const none: []const i64 = &.{};
    try std.testing.expect(acl.decide(io, 12, none, 1, "/api/x", "GET") == .allow);
    try std.testing.expect(acl.decide(io, 12, none, 1, "/api/x", "HEAD") == .allow);
    try std.testing.expect(acl.decide(io, 12, none, 1, "/admin", "POST") == .deny);
    try std.testing.expect(acl.decide(io, 99, none, 1, "/other", "GET") == .allow);
    try std.testing.expect(acl.decide(io, 12, none, 2, "/", "GET") == .deny);
}

test "acl path regex can deny pdfs" {
    var acl = Acl.init(std.testing.allocator);
    defer acl.deinit();
    const io = std.testing.io;
    const rows = [_]Acl.DbRule{
        .{ .id = 1, .pos = 0, .subject = .any, .site_id = 2, .path = "(?i)\\.pdf$", .method = "*", .effect = .deny },
        .{ .id = 2, .pos = 1, .subject = .any, .site_id = 2, .path = "^/", .method = "*", .effect = .allow },
    };
    try acl.load(io, &rows);
    try std.testing.expect(acl.decide(io, 1, &.{}, 2, "/docs/report.PDF", "GET") == .deny);
    try std.testing.expect(acl.decide(io, 1, &.{}, 2, "/docs/readme.txt", "GET") == .allow);
}

test "acl user subject matches id" {
    var acl = Acl.init(std.testing.allocator);
    defer acl.deinit();
    const io = std.testing.io;
    const rows = [_]Acl.DbRule{.{
        .id = 1,
        .pos = 0,
        .subject = .{ .user_id = 12 },
        .site_id = 3,
        .path = "^/",
        .method = "*",
        .effect = .allow,
    }};
    try acl.load(io, &rows);
    try std.testing.expect(acl.decide(io, 12, &.{}, 3, "/", "GET") == .allow);
    try std.testing.expect(acl.decide(io, 99, &.{}, 3, "/", "GET") == .deny);
}

test "acl group subject matches membership" {
    var acl = Acl.init(std.testing.allocator);
    defer acl.deinit();
    const io = std.testing.io;
    const rows = [_]Acl.DbRule{.{
        .id = 1,
        .pos = 0,
        .subject = .{ .group_id = 5 },
        .site_id = 4,
        .path = "^/",
        .method = "*",
        .effect = .allow,
    }};
    try acl.load(io, &rows);
    const member: []const i64 = &.{5};
    const outsider: []const i64 = &.{9};
    try std.testing.expect(acl.decide(io, 1, member, 4, "/", "GET") == .allow);
    try std.testing.expect(acl.decide(io, 1, outsider, 4, "/", "GET") == .deny);
    try std.testing.expect(acl.decide(io, 1, &.{}, 4, "/", "GET") == .deny);
}

test "acl comma-separated methods" {
    var acl = Acl.init(std.testing.allocator);
    defer acl.deinit();
    const io = std.testing.io;
    const rows = [_]Acl.DbRule{.{
        .id = 1,
        .pos = 0,
        .subject = .any,
        .site_id = 1,
        .path = "^/",
        .method = "GET, OPTIONS, PROPFIND",
        .effect = .allow,
    }};
    try acl.load(io, &rows);
    try std.testing.expect(acl.decide(io, 1, &.{}, 1, "/", "GET") == .allow);
    try std.testing.expect(acl.decide(io, 1, &.{}, 1, "/", "OPTIONS") == .allow);
    try std.testing.expect(acl.decide(io, 1, &.{}, 1, "/", "PROPFIND") == .allow);
    try std.testing.expect(acl.decide(io, 1, &.{}, 1, "/", "HEAD") == .allow);
    try std.testing.expect(acl.decide(io, 1, &.{}, 1, "/", "POST") == .deny);
}

test "acl parseSubject" {
    try std.testing.expect((try parseSubject("*")) == .any);
    try std.testing.expectEqual(@as(i64, 12), (try parseSubject("#12")).user_id);
    try std.testing.expectEqual(@as(i64, 5), (try parseSubject("@5")).group_id);
    try std.testing.expectError(error.InvalidSubject, parseSubject("12:alice"));
    try std.testing.expectError(error.InvalidSubject, parseSubject("@friends"));
    try std.testing.expectError(error.InvalidSubject, parseSubject("@"));
}
