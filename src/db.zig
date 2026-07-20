const std = @import("std");
const zqlite = @import("zqlite");
const password = @import("password.zig");
const util = @import("util.zig");
const acl_mod = @import("acl.zig");
const sites_mod = @import("sites.zig");

pub const User = struct {
    id: i64,
    username: []const u8,
    enabled: bool,
    discord_id: ?[]const u8,
};

pub const Group = struct {
    id: i64,
    name: []const u8,
};

pub const GroupMember = struct {
    user_id: i64,
    username: []const u8,
};

pub const SessionUser = struct {
    session_id: []const u8,
    user_id: i64,
    username: []const u8,
};

pub const SiteRow = sites_mod.Site;

pub const AclRuleRow = acl_mod.Acl.DbRule;

const schema =
    \\create table if not exists users (
    \\  id integer primary key,
    \\  username text not null unique,
    \\  password_hash text not null,
    \\  created_at integer not null,
    \\  enabled integer not null default 1,
    \\  discord_id text
    \\);
    \\create table if not exists sessions (
    \\  id text primary key,
    \\  user_id integer not null references users(id),
    \\  created_at integer not null
    \\);
    \\create table if not exists groups (
    \\  id integer primary key,
    \\  name text not null unique
    \\);
    \\create table if not exists group_members (
    \\  group_id integer not null references groups(id) on delete cascade,
    \\  user_id integer not null references users(id) on delete cascade,
    \\  primary key (group_id, user_id)
    \\);
    \\create table if not exists sites (
    \\  id integer primary key,
    \\  name text not null unique,
    \\  host text not null unique,
    \\  user_id_header text not null,
    \\  user_name_header text not null
    \\);
    \\create table if not exists tickets (
    \\  id text primary key,
    \\  session_id text not null references sessions(id) on delete cascade,
    \\  site_id integer not null references sites(id),
    \\  path text not null,
    \\  expires_at integer not null
    \\);
    \\create table if not exists acl_rules (
    \\  id integer primary key,
    \\  pos integer not null,
    \\  subject_kind text not null check (subject_kind in ('any','user','group')),
    \\  user_id integer references users(id) on delete cascade,
    \\  group_id integer references groups(id) on delete cascade,
    \\  site_id integer references sites(id) on delete cascade,
    \\  path text not null,
    \\  method text not null,
    \\  effect text not null check (effect in ('allow','deny')),
    \\  check (
    \\    (subject_kind = 'any' and user_id is null and group_id is null) or
    \\    (subject_kind = 'user' and user_id is not null and group_id is null) or
    \\    (subject_kind = 'group' and group_id is not null and user_id is null)
    \\  )
    \\);
    \\create table if not exists acl_document (
    \\  id integer primary key check (id = 1),
    \\  body text not null
    \\);
    \\create table if not exists sites_document (
    \\  id integer primary key check (id = 1),
    \\  body text not null
    \\);
;

pub fn migrate(conn: zqlite.Conn, _: ?*anyopaque) !void {
    try conn.execNoArgs(schema);
    try conn.execNoArgs("pragma foreign_keys = on");
    // Additive migrations for existing databases.
    conn.execNoArgs("alter table users add column enabled integer not null default 1") catch {};
    conn.execNoArgs("alter table users add column discord_id text") catch {};
    try conn.execNoArgs(
        \\create unique index if not exists users_discord_id_unique
        \\on users(discord_id) where discord_id is not null
    );
    conn.execNoArgs("alter table sites drop column user_header") catch {};

    // Existing DBs may still have tickets.site_id as text (no FK). Recreate.
    if (try ticketsSiteIdIsText(conn)) {
        try conn.execNoArgs("drop table if exists tickets");
        try conn.execNoArgs(
            \\create table tickets (
            \\  id text primary key,
            \\  session_id text not null references sessions(id) on delete cascade,
            \\  site_id integer not null references sites(id),
            \\  path text not null,
            \\  expires_at integer not null
            \\)
        );
    }
}

fn ticketsSiteIdIsText(conn: zqlite.Conn) !bool {
    var rows = try conn.rows("pragma table_info(tickets)", .{});
    defer rows.deinit();
    while (rows.next()) |row| {
        if (std.mem.eql(u8, row.text(1), "site_id")) {
            const typ = row.text(2);
            return std.ascii.indexOfIgnoreCase(typ, "int") == null;
        }
    }
    if (rows.err) |err| return err;
    return false;
}

pub fn onConnection(conn: zqlite.Conn, _: ?*anyopaque) !void {
    try conn.execNoArgs("pragma foreign_keys = on");
    try conn.busyTimeout(5000);
}

/// One-shot: import legacy *_document TSV into sites / acl_rules when those tables are empty.
pub fn migrateDocumentsToTables(conn: zqlite.Conn, allocator: std.mem.Allocator) !void {
    if (try tableEmpty(conn, "sites")) {
        if (try loadDocumentBody(conn, "sites_document", allocator)) |body| {
            defer allocator.free(body);
            try importLegacySitesDocument(conn, allocator, body);
        }
    }
    if (try tableEmpty(conn, "acl_rules")) {
        if (try loadDocumentBody(conn, "acl_document", allocator)) |body| {
            defer allocator.free(body);
            try importLegacyAclDocument(conn, allocator, body);
        }
    }
}

fn tableEmpty(conn: zqlite.Conn, comptime table: []const u8) !bool {
    const sql = "select 1 from " ++ table ++ " limit 1";
    if (try conn.row(sql, .{})) |row| {
        row.deinit();
        return false;
    }
    return true;
}

fn loadDocumentBody(conn: zqlite.Conn, table: []const u8, allocator: std.mem.Allocator) !?[]u8 {
    if (std.mem.eql(u8, table, "sites_document")) {
        const row = (try conn.row("select body from sites_document where id = 1", .{})) orelse return null;
        defer row.deinit();
        return try allocator.dupe(u8, row.text(0));
    }
    if (std.mem.eql(u8, table, "acl_document")) {
        const row = (try conn.row("select body from acl_document where id = 1", .{})) orelse return null;
        defer row.deinit();
        return try allocator.dupe(u8, row.text(0));
    }
    return null;
}

fn importLegacySitesDocument(conn: zqlite.Conn, allocator: std.mem.Allocator, tsv: []const u8) !void {
    _ = allocator;
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

        const site_id = cols[0];
        const host = cols[1];
        // Legacy col 2 was user_header; ignored after removal.
        const user_id_header = cols[3];
        const user_name_header = cols[4];

        if (std.mem.eql(u8, site_id, "site_id") and (host.len == 0 or std.mem.eql(u8, host, "host"))) continue;
        if (site_id.len == 0 or host.len == 0 or user_id_header.len == 0 or user_name_header.len == 0) {
            std.log.warn("skipping legacy sites line {d}: incomplete", .{line_no});
            continue;
        }

        try conn.exec(
            \\insert into sites (name, host, user_id_header, user_name_header)
            \\values (?1, ?2, ?3, ?4)
        ,
            .{ site_id, host, user_id_header, user_name_header },
        );
    }
}

fn importLegacyAclDocument(conn: zqlite.Conn, allocator: std.mem.Allocator, tsv: []const u8) !void {
    var lines = std.mem.splitScalar(u8, tsv, '\n');
    var line_no: usize = 0;
    var pos: i64 = 0;
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

        const user_col = cols[0];
        const site_col = cols[1];
        const path_col = cols[2];
        const method_col = cols[3];
        const effect_col = cols[4];

        if (std.mem.eql(u8, user_col, "user") and (site_col.len == 0 or
            std.mem.eql(u8, site_col, "site_id") or
            std.mem.eql(u8, site_col, "host"))) continue;

        if (site_col.len == 0 or path_col.len == 0 or method_col.len == 0) {
            std.log.warn("skipping legacy ACL line {d}: incomplete", .{line_no});
            continue;
        }

        const effect = effect_col;
        if (!std.mem.eql(u8, effect, "allow") and !std.mem.eql(u8, effect, "deny")) {
            std.log.warn("skipping legacy ACL line {d}: bad effect", .{line_no});
            continue;
        }

        var subject_kind: []const u8 = undefined;
        var user_id: ?i64 = null;
        var group_id: ?i64 = null;

        if (std.mem.eql(u8, user_col, "*")) {
            subject_kind = "any";
        } else if (user_col.len >= 2 and user_col[0] == '#' and std.ascii.isDigit(user_col[1])) {
            subject_kind = "user";
            user_id = std.fmt.parseInt(i64, user_col[1..], 10) catch {
                std.log.warn("skipping legacy ACL line {d}: bad user id", .{line_no});
                continue;
            };
        } else if (user_col.len >= 2 and user_col[0] == '@' and std.ascii.isDigit(user_col[1])) {
            subject_kind = "group";
            group_id = std.fmt.parseInt(i64, user_col[1..], 10) catch {
                std.log.warn("skipping legacy ACL line {d}: bad group id", .{line_no});
                continue;
            };
        } else if (user_col.len > 1 and user_col[0] == '@') {
            subject_kind = "group";
            const gname = user_col[1..];
            group_id = try findGroupIdByName(conn, gname);
            if (group_id == null) {
                std.log.warn("skipping legacy ACL line {d}: unknown group {s}", .{ line_no, gname });
                continue;
            }
        } else if (std.mem.indexOfScalar(u8, user_col, ':')) |colon| {
            subject_kind = "user";
            user_id = std.fmt.parseInt(i64, user_col[0..colon], 10) catch {
                std.log.warn("skipping legacy ACL line {d}: bad user id", .{line_no});
                continue;
            };
        } else {
            std.log.warn("skipping legacy ACL line {d}: bad subject {s}", .{ line_no, user_col });
            continue;
        }

        const site_id: ?i64 = if (std.mem.eql(u8, site_col, "*"))
            null
        else blk: {
            if (std.fmt.parseInt(i64, site_col, 10)) |sid| {
                break :blk sid;
            } else |_| {
                break :blk try findSiteIdByName(conn, site_col);
            }
        };
        if (!std.mem.eql(u8, site_col, "*") and site_id == null) {
            std.log.warn("skipping legacy ACL line {d}: unknown site {s}", .{ line_no, site_col });
            continue;
        }

        _ = allocator;
        try insertAclRule(conn, pos, subject_kind, user_id, group_id, site_id, path_col, method_col, effect);
        pos += 1;
    }
}

fn findGroupIdByName(conn: zqlite.Conn, name: []const u8) !?i64 {
    const row = (try conn.row("select id from groups where name = ?1", .{name})) orelse return null;
    defer row.deinit();
    return row.int(0);
}

fn findSiteIdByName(conn: zqlite.Conn, name: []const u8) !?i64 {
    const row = (try conn.row("select id from sites where name = ?1", .{name})) orelse return null;
    defer row.deinit();
    return row.int(0);
}

fn insertAclRule(
    conn: zqlite.Conn,
    pos: i64,
    subject_kind: []const u8,
    user_id: ?i64,
    group_id: ?i64,
    site_id: ?i64,
    path: []const u8,
    method: []const u8,
    effect: []const u8,
) !void {
    try conn.exec(
        \\insert into acl_rules (pos, subject_kind, user_id, group_id, site_id, path, method, effect)
        \\values (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8)
    ,
        .{ pos, subject_kind, user_id, group_id, site_id, path, method, effect },
    );
}

pub fn seedAdmin(
    conn: zqlite.Conn,
    allocator: std.mem.Allocator,
    io: std.Io,
    username: []const u8,
    plain_password: []const u8,
) !void {
    const hash = try password.hash(allocator, io, plain_password);
    defer allocator.free(hash);
    const now = util.unixNow(io);

    if (try conn.row("select id from users where username = ?1", .{username})) |row| {
        defer row.deinit();
        try conn.exec(
            "update users set password_hash = ?1 where username = ?2",
            .{ hash, username },
        );
    } else {
        try conn.exec(
            "insert into users (username, password_hash, created_at, enabled) values (?1, ?2, ?3, 1)",
            .{ username, hash, now },
        );
    }
}

// --- sites CRUD ---

pub fn listSites(conn: zqlite.Conn, allocator: std.mem.Allocator) ![]SiteRow {
    var list: std.ArrayList(SiteRow) = .empty;
    errdefer {
        for (list.items) |s| {
            allocator.free(s.name);
            allocator.free(s.host);
            allocator.free(s.user_id_header);
            allocator.free(s.user_name_header);
        }
        list.deinit(allocator);
    }

    var rows = try conn.rows(
        \\select id, name, host, user_id_header, user_name_header
        \\from sites order by id
    ,
        .{},
    );
    defer rows.deinit();
    while (rows.next()) |row| {
        try list.append(allocator, .{
            .id = row.int(0),
            .name = try allocator.dupe(u8, row.text(1)),
            .host = try allocator.dupe(u8, row.text(2)),
            .user_id_header = try allocator.dupe(u8, row.text(3)),
            .user_name_header = try allocator.dupe(u8, row.text(4)),
        });
    }
    if (rows.err) |err| return err;
    return try list.toOwnedSlice(allocator);
}

pub fn createSite(
    conn: zqlite.Conn,
    name: []const u8,
    host: []const u8,
    user_id_header: []const u8,
    user_name_header: []const u8,
) !i64 {
    try conn.exec(
        \\insert into sites (name, host, user_id_header, user_name_header)
        \\values (?1, ?2, ?3, ?4)
    ,
        .{ name, host, user_id_header, user_name_header },
    );
    return conn.lastInsertedRowId();
}

pub fn updateSite(
    conn: zqlite.Conn,
    id: i64,
    name: []const u8,
    host: []const u8,
    user_id_header: []const u8,
    user_name_header: []const u8,
) !void {
    try conn.exec(
        \\update sites set name = ?1, host = ?2,
        \\user_id_header = ?3, user_name_header = ?4 where id = ?5
    ,
        .{ name, host, user_id_header, user_name_header, id },
    );
}

pub fn deleteSite(conn: zqlite.Conn, id: i64) !void {
    try conn.exec("delete from tickets where site_id = ?1", .{id});
    try conn.exec("delete from sites where id = ?1", .{id});
}

// --- acl_rules CRUD ---

pub fn listAclRules(conn: zqlite.Conn, allocator: std.mem.Allocator) ![]AclRuleRow {
    var list: std.ArrayList(AclRuleRow) = .empty;
    errdefer {
        for (list.items) |r| {
            allocator.free(r.path);
            allocator.free(r.method);
        }
        list.deinit(allocator);
    }

    var rows = try conn.rows(
        \\select id, pos, subject_kind, user_id, group_id, site_id, path, method, effect
        \\from acl_rules order by pos, id
    ,
        .{},
    );
    defer rows.deinit();
    while (rows.next()) |row| {
        const kind = row.text(2);
        const subject: acl_mod.Subject = if (std.mem.eql(u8, kind, "any"))
            .any
        else if (std.mem.eql(u8, kind, "user"))
            .{ .user_id = row.nullableInt(3) orelse return error.CorruptAclRule }
        else if (std.mem.eql(u8, kind, "group"))
            .{ .group_id = row.nullableInt(4) orelse return error.CorruptAclRule }
        else
            return error.CorruptAclRule;

        const effect: acl_mod.Effect = if (std.mem.eql(u8, row.text(8), "allow"))
            .allow
        else if (std.mem.eql(u8, row.text(8), "deny"))
            .deny
        else
            return error.CorruptAclRule;

        try list.append(allocator, .{
            .id = row.int(0),
            .pos = row.int(1),
            .subject = subject,
            .site_id = row.nullableInt(5),
            .path = try allocator.dupe(u8, row.text(6)),
            .method = try allocator.dupe(u8, row.text(7)),
            .effect = effect,
        });
    }
    if (rows.err) |err| return err;
    return try list.toOwnedSlice(allocator);
}

fn subjectParts(subject: acl_mod.Subject) struct { []const u8, ?i64, ?i64 } {
    return switch (subject) {
        .any => .{ "any", null, null },
        .user_id => |id| .{ "user", id, null },
        .group_id => |id| .{ "group", null, id },
    };
}

pub fn createAclRule(
    conn: zqlite.Conn,
    subject: acl_mod.Subject,
    site_id: ?i64,
    path: []const u8,
    method: []const u8,
    effect: acl_mod.Effect,
) !i64 {
    const next_pos: i64 = blk: {
        if (try conn.row("select coalesce(max(pos), -1) + 1 from acl_rules", .{})) |row| {
            defer row.deinit();
            break :blk row.int(0);
        }
        break :blk 0;
    };
    const parts = subjectParts(subject);
    try insertAclRule(conn, next_pos, parts[0], parts[1], parts[2], site_id, path, method, @tagName(effect));
    return conn.lastInsertedRowId();
}

pub fn updateAclRule(
    conn: zqlite.Conn,
    id: i64,
    subject: acl_mod.Subject,
    site_id: ?i64,
    path: []const u8,
    method: []const u8,
    effect: acl_mod.Effect,
) !void {
    const parts = subjectParts(subject);
    try conn.exec(
        \\update acl_rules set subject_kind = ?1, user_id = ?2, group_id = ?3,
        \\site_id = ?4, path = ?5, method = ?6, effect = ?7 where id = ?8
    ,
        .{ parts[0], parts[1], parts[2], site_id, path, method, @tagName(effect), id },
    );
}

pub fn deleteAclRule(conn: zqlite.Conn, id: i64) !void {
    try conn.exec("delete from acl_rules where id = ?1", .{id});
}

pub const AclMoveDir = enum { up, down };

pub fn moveAclRule(conn: zqlite.Conn, id: i64, direction: AclMoveDir) !void {
    const cur = (try conn.row("select pos from acl_rules where id = ?1", .{id})) orelse return;
    defer cur.deinit();
    const pos = cur.int(0);

    const neighbor_sql = switch (direction) {
        .up => "select id, pos from acl_rules where pos < ?1 order by pos desc limit 1",
        .down => "select id, pos from acl_rules where pos > ?1 order by pos asc limit 1",
    };
    const neighbor = (try conn.row(neighbor_sql, .{pos})) orelse return;
    defer neighbor.deinit();
    const nid = neighbor.int(0);
    const npos = neighbor.int(1);

    try conn.exec("update acl_rules set pos = ?1 where id = ?2", .{ npos, id });
    try conn.exec("update acl_rules set pos = ?1 where id = ?2", .{ pos, nid });
}

/// Move a rule to the given 1-based position in ACL order.
pub fn moveAclRuleToPos(conn: zqlite.Conn, id: i64, pos_1based: i64) !void {
    if (pos_1based < 1) return;
    const cur = (try conn.row("select pos from acl_rules where id = ?1", .{id})) orelse return;
    defer cur.deinit();
    const current_pos = cur.int(0);

    const count_row = (try conn.row("select count(*) from acl_rules", .{})) orelse return;
    defer count_row.deinit();
    const total = count_row.int(0);
    if (total <= 1) return;

    var target_pos = pos_1based - 1;
    if (target_pos < 0) target_pos = 0;
    if (target_pos >= total) target_pos = total - 1;
    if (target_pos == current_pos) return;

    try conn.transaction();
    errdefer conn.rollback();
    if (target_pos < current_pos) {
        try conn.exec(
            "update acl_rules set pos = pos + 1 where pos >= ?1 and pos < ?2",
            .{ target_pos, current_pos },
        );
    } else {
        try conn.exec(
            "update acl_rules set pos = pos - 1 where pos > ?1 and pos <= ?2",
            .{ current_pos, target_pos },
        );
    }
    try conn.exec("update acl_rules set pos = ?1 where id = ?2", .{ target_pos, id });
    try conn.commit();
}

pub fn createUser(
    conn: zqlite.Conn,
    allocator: std.mem.Allocator,
    io: std.Io,
    username: []const u8,
    plain_password: []const u8,
) !i64 {
    const hash = try password.hash(allocator, io, plain_password);
    defer allocator.free(hash);
    try conn.exec(
        "insert into users (username, password_hash, created_at, enabled) values (?1, ?2, ?3, 1)",
        .{ username, hash, util.unixNow(io) },
    );
    return conn.lastInsertedRowId();
}

/// Create a Discord-provisioned user (disabled until an admin enables them).
pub fn createDiscordUser(
    conn: zqlite.Conn,
    allocator: std.mem.Allocator,
    io: std.Io,
    username: []const u8,
    discord_id: []const u8,
) !i64 {
    const plain = try randomPassword(allocator, io);
    defer allocator.free(plain);
    const hash = try password.hash(allocator, io, plain);
    defer allocator.free(hash);
    try conn.exec(
        \\insert into users (username, password_hash, created_at, enabled, discord_id)
        \\values (?1, ?2, ?3, 0, ?4)
    ,
        .{ username, hash, util.unixNow(io), discord_id },
    );
    return conn.lastInsertedRowId();
}

fn randomPassword(allocator: std.mem.Allocator, io: std.Io) ![]u8 {
    var buf: [64]u8 = undefined;
    util.randomHex(io, 32, &buf);
    return try allocator.dupe(u8, buf[0..]);
}

pub fn listUsers(conn: zqlite.Conn, allocator: std.mem.Allocator) ![]User {
    var list: std.ArrayList(User) = .empty;
    errdefer {
        for (list.items) |u| {
            allocator.free(u.username);
            if (u.discord_id) |d| allocator.free(d);
        }
        list.deinit(allocator);
    }

    var rows = try conn.rows("select id, username, enabled, discord_id from users order by id", .{});
    defer rows.deinit();
    while (rows.next()) |row| {
        const discord_raw = row.nullableText(3);
        try list.append(allocator, .{
            .id = row.int(0),
            .username = try allocator.dupe(u8, row.text(1)),
            .enabled = row.int(2) != 0,
            .discord_id = if (discord_raw) |d| try allocator.dupe(u8, d) else null,
        });
    }
    if (rows.err) |err| return err;
    return try list.toOwnedSlice(allocator);
}

pub fn findUserById(
    conn: zqlite.Conn,
    allocator: std.mem.Allocator,
    id: i64,
) !?struct { id: i64, username: []u8, password_hash: []u8, enabled: bool } {
    const row = (try conn.row(
        "select id, username, password_hash, enabled from users where id = ?1",
        .{id},
    )) orelse return null;
    defer row.deinit();
    return .{
        .id = row.int(0),
        .username = try allocator.dupe(u8, row.text(1)),
        .password_hash = try allocator.dupe(u8, row.text(2)),
        .enabled = row.int(3) != 0,
    };
}

pub fn updateUsername(conn: zqlite.Conn, id: i64, username: []const u8) !void {
    try conn.exec("update users set username = ?1 where id = ?2", .{ username, id });
}

pub fn updatePassword(
    conn: zqlite.Conn,
    allocator: std.mem.Allocator,
    io: std.Io,
    id: i64,
    plain_password: []const u8,
) !void {
    const hash = try password.hash(allocator, io, plain_password);
    defer allocator.free(hash);
    try conn.exec("update users set password_hash = ?1 where id = ?2", .{ hash, id });
}

pub fn deleteUser(conn: zqlite.Conn, id: i64) !void {
    try conn.exec("delete from sessions where user_id = ?1", .{id});
    try conn.exec("delete from group_members where user_id = ?1", .{id});
    try conn.exec("delete from users where id = ?1", .{id});
}

pub fn createGroup(conn: zqlite.Conn, name: []const u8) !i64 {
    try conn.exec("insert into groups (name) values (?1)", .{name});
    return conn.lastInsertedRowId();
}

pub fn listGroups(conn: zqlite.Conn, allocator: std.mem.Allocator) ![]Group {
    var list: std.ArrayList(Group) = .empty;
    errdefer {
        for (list.items) |g| allocator.free(g.name);
        list.deinit(allocator);
    }

    var rows = try conn.rows("select id, name from groups order by name", .{});
    defer rows.deinit();
    while (rows.next()) |row| {
        try list.append(allocator, .{
            .id = row.int(0),
            .name = try allocator.dupe(u8, row.text(1)),
        });
    }
    if (rows.err) |err| return err;
    return try list.toOwnedSlice(allocator);
}

pub fn findGroupById(
    conn: zqlite.Conn,
    allocator: std.mem.Allocator,
    id: i64,
) !?Group {
    const row = (try conn.row("select id, name from groups where id = ?1", .{id})) orelse return null;
    defer row.deinit();
    return .{
        .id = row.int(0),
        .name = try allocator.dupe(u8, row.text(1)),
    };
}

pub fn updateGroupName(conn: zqlite.Conn, id: i64, name: []const u8) !void {
    try conn.exec("update groups set name = ?1 where id = ?2", .{ name, id });
}

pub fn deleteGroup(conn: zqlite.Conn, id: i64) !void {
    try conn.exec("delete from groups where id = ?1", .{id});
}

pub fn addGroupMember(conn: zqlite.Conn, group_id: i64, user_id: i64) !void {
    try conn.exec(
        "insert into group_members (group_id, user_id) values (?1, ?2)",
        .{ group_id, user_id },
    );
}

pub fn removeGroupMember(conn: zqlite.Conn, group_id: i64, user_id: i64) !void {
    try conn.exec(
        "delete from group_members where group_id = ?1 and user_id = ?2",
        .{ group_id, user_id },
    );
}

pub fn listGroupMembers(
    conn: zqlite.Conn,
    allocator: std.mem.Allocator,
    group_id: i64,
) ![]GroupMember {
    var list: std.ArrayList(GroupMember) = .empty;
    errdefer {
        for (list.items) |m| allocator.free(m.username);
        list.deinit(allocator);
    }

    var rows = try conn.rows(
        \\select users.id, users.username
        \\from group_members
        \\join users on users.id = group_members.user_id
        \\where group_members.group_id = ?1
        \\order by users.username
    ,
        .{group_id},
    );
    defer rows.deinit();
    while (rows.next()) |row| {
        try list.append(allocator, .{
            .user_id = row.int(0),
            .username = try allocator.dupe(u8, row.text(1)),
        });
    }
    if (rows.err) |err| return err;
    return try list.toOwnedSlice(allocator);
}

/// Group names the user belongs to (allocated from `allocator`). Used by LDAP.
pub fn listGroupNamesForUser(
    conn: zqlite.Conn,
    allocator: std.mem.Allocator,
    user_id: i64,
) ![][]const u8 {
    var list: std.ArrayList([]const u8) = .empty;
    errdefer {
        for (list.items) |n| allocator.free(n);
        list.deinit(allocator);
    }

    var rows = try conn.rows(
        \\select groups.name
        \\from group_members
        \\join groups on groups.id = group_members.group_id
        \\where group_members.user_id = ?1
        \\order by groups.name
    ,
        .{user_id},
    );
    defer rows.deinit();
    while (rows.next()) |row| {
        try list.append(allocator, try allocator.dupe(u8, row.text(0)));
    }
    if (rows.err) |err| return err;
    return try list.toOwnedSlice(allocator);
}

/// Group ids the user belongs to (allocated from `allocator`).
pub fn listGroupIdsForUser(
    conn: zqlite.Conn,
    allocator: std.mem.Allocator,
    user_id: i64,
) ![]i64 {
    var list: std.ArrayList(i64) = .empty;
    errdefer list.deinit(allocator);

    var rows = try conn.rows(
        \\select groups.id
        \\from group_members
        \\join groups on groups.id = group_members.group_id
        \\where group_members.user_id = ?1
        \\order by groups.id
    ,
        .{user_id},
    );
    defer rows.deinit();
    while (rows.next()) |row| {
        try list.append(allocator, row.int(0));
    }
    if (rows.err) |err| return err;
    return try list.toOwnedSlice(allocator);
}

pub fn findUserByUsername(
    conn: zqlite.Conn,
    allocator: std.mem.Allocator,
    username: []const u8,
) !?struct { id: i64, username: []u8, password_hash: []u8, enabled: bool } {
    const row = (try conn.row(
        "select id, username, password_hash, enabled from users where username = ?1",
        .{username},
    )) orelse return null;
    defer row.deinit();
    return .{
        .id = row.int(0),
        .username = try allocator.dupe(u8, row.text(1)),
        .password_hash = try allocator.dupe(u8, row.text(2)),
        .enabled = row.int(3) != 0,
    };
}

pub fn findUserByDiscordId(
    conn: zqlite.Conn,
    allocator: std.mem.Allocator,
    discord_id: []const u8,
) !?struct { id: i64, username: []u8, enabled: bool } {
    const row = (try conn.row(
        "select id, username, enabled from users where discord_id = ?1",
        .{discord_id},
    )) orelse return null;
    defer row.deinit();
    return .{
        .id = row.int(0),
        .username = try allocator.dupe(u8, row.text(1)),
        .enabled = row.int(2) != 0,
    };
}

pub fn setUserEnabled(conn: zqlite.Conn, id: i64, enabled: bool) !void {
    try conn.exec("update users set enabled = ?1 where id = ?2", .{ if (enabled) @as(i64, 1) else @as(i64, 0), id });
}

/// Empty / null clears the Discord link. Non-empty sets it (unique when not null).
pub fn setUserDiscordId(conn: zqlite.Conn, id: i64, discord_id: ?[]const u8) !void {
    if (discord_id) |d| {
        if (d.len == 0) {
            try conn.exec("update users set discord_id = null where id = ?1", .{id});
        } else {
            try conn.exec("update users set discord_id = ?1 where id = ?2", .{ d, id });
        }
    } else {
        try conn.exec("update users set discord_id = null where id = ?1", .{id});
    }
}

pub fn usernameTaken(conn: zqlite.Conn, username: []const u8) !bool {
    if (try conn.row("select 1 from users where username = ?1", .{username})) |row| {
        row.deinit();
        return true;
    }
    return false;
}

pub fn createSession(conn: zqlite.Conn, allocator: std.mem.Allocator, io: std.Io, user_id: i64) ![]u8 {
    var id_buf: [64]u8 = undefined;
    util.randomHex(io, 32, &id_buf);
    try conn.exec(
        "insert into sessions (id, user_id, created_at) values (?1, ?2, ?3)",
        .{ id_buf[0..], user_id, util.unixNow(io) },
    );
    return try allocator.dupe(u8, id_buf[0..]);
}

pub fn deleteSession(conn: zqlite.Conn, session_id: []const u8) !void {
    try conn.exec("delete from sessions where id = ?1", .{session_id});
}

pub fn sessionUser(conn: zqlite.Conn, allocator: std.mem.Allocator, session_id: []const u8) !?SessionUser {
    const row = (try conn.row(
        \\select sessions.id, users.id, users.username
        \\from sessions
        \\join users on users.id = sessions.user_id
        \\where sessions.id = ?1 and users.enabled = 1
    , .{session_id})) orelse return null;
    defer row.deinit();
    return .{
        .session_id = try allocator.dupe(u8, row.text(0)),
        .user_id = row.int(1),
        .username = try allocator.dupe(u8, row.text(2)),
    };
}

pub fn createTicket(
    conn: zqlite.Conn,
    allocator: std.mem.Allocator,
    io: std.Io,
    session_id: []const u8,
    site_id: i64,
    path: []const u8,
) ![]u8 {
    var id_buf: [64]u8 = undefined;
    util.randomHex(io, 32, &id_buf);
    const expires = util.unixNow(io) + util.ticket_ttl_secs;
    try conn.exec(
        "insert into tickets (id, session_id, site_id, path, expires_at) values (?1, ?2, ?3, ?4, ?5)",
        .{ id_buf[0..], session_id, site_id, path, expires },
    );
    return try allocator.dupe(u8, id_buf[0..]);
}

/// Consume a one-time ticket. Returns session_id, site_id, path.
pub fn consumeTicket(
    conn: zqlite.Conn,
    allocator: std.mem.Allocator,
    io: std.Io,
    ticket_id: []const u8,
) !?struct { session_id: []u8, site_id: i64, path: []u8 } {
    try conn.transaction();
    errdefer conn.rollback();

    const row = (try conn.row(
        "select session_id, site_id, path, expires_at from tickets where id = ?1",
        .{ticket_id},
    )) orelse {
        conn.rollback();
        return null;
    };

    const expires_at = row.int(3);
    const session_id = try allocator.dupe(u8, row.text(0));
    errdefer allocator.free(session_id);
    const site_id = row.int(1);
    const path = try allocator.dupe(u8, row.text(2));
    errdefer allocator.free(path);
    row.deinit();

    try conn.exec("delete from tickets where id = ?1", .{ticket_id});
    try conn.commit();

    if (expires_at < util.unixNow(io)) {
        allocator.free(session_id);
        allocator.free(path);
        return null;
    }

    return .{
        .session_id = session_id,
        .site_id = site_id,
        .path = path,
    };
}

test "migrateDocumentsToTables imports legacy TSV" {
    var conn = try zqlite.open(":memory:", zqlite.OpenFlags.Create | zqlite.OpenFlags.EXResCode);
    defer conn.close();
    try migrate(conn, null);
    try conn.execNoArgs("pragma foreign_keys = on");

    try conn.exec(
        "insert into users (id, username, password_hash, created_at, enabled) values (1, 'admin', 'x', 0, 1)",
        .{},
    );
    try conn.exec("insert into groups (id, name) values (7, 'friends')", .{});
    try conn.exec(
        \\insert into sites_document (id, body) values (1, ?1)
    ,
        .{"site_id\thost\tuser_header\tuser_id_header\tuser_name_header\n" ++
            "jellyfin\tmedia.example.com\tRemote-User\tRemote-User-Id\tRemote-User-Name\n"},
    );
    try conn.exec(
        \\insert into acl_document (id, body) values (1, ?1)
    ,
        .{"user\tsite_id\tpath\tmethod\teffect\n" ++
            "@friends\tjellyfin\t^/\t*\tallow\n" ++
            "1:admin\t*\t^/admin\t*\tallow\n"},
    );

    try migrateDocumentsToTables(conn, std.testing.allocator);

    const sites = try listSites(conn, std.testing.allocator);
    defer {
        for (sites) |s| {
            std.testing.allocator.free(s.name);
            std.testing.allocator.free(s.host);
            std.testing.allocator.free(s.user_id_header);
            std.testing.allocator.free(s.user_name_header);
        }
        std.testing.allocator.free(sites);
    }
    try std.testing.expectEqual(@as(usize, 1), sites.len);
    try std.testing.expectEqualStrings("jellyfin", sites[0].name);

    const rules = try listAclRules(conn, std.testing.allocator);
    defer {
        for (rules) |r| {
            std.testing.allocator.free(r.path);
            std.testing.allocator.free(r.method);
        }
        std.testing.allocator.free(rules);
    }
    try std.testing.expectEqual(@as(usize, 2), rules.len);
    try std.testing.expect(rules[0].subject == .group_id);
    try std.testing.expectEqual(@as(i64, 7), rules[0].subject.group_id);
    try std.testing.expectEqual(sites[0].id, rules[0].site_id.?);
    try std.testing.expect(rules[1].subject == .user_id);
    try std.testing.expectEqual(@as(i64, 1), rules[1].subject.user_id);
    try std.testing.expect(rules[1].site_id == null);
}
