const std = @import("std");
const zqlite = @import("zqlite");
const password = @import("password.zig");
const util = @import("util.zig");

pub const User = struct {
    id: i64,
    username: []const u8,
    enabled: bool,
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
    \\create table if not exists tickets (
    \\  id text primary key,
    \\  session_id text not null references sessions(id) on delete cascade,
    \\  site_id text not null,
    \\  path text not null,
    \\  expires_at integer not null
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
}

pub fn onConnection(conn: zqlite.Conn, _: ?*anyopaque) !void {
    try conn.execNoArgs("pragma foreign_keys = on");
    try conn.busyTimeout(5000);
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

pub fn ensureDocuments(conn: zqlite.Conn) !void {
    const default_acl = "user\tsite_id\tpath_prefix\tmethod\teffect\n";
    const default_sites = "site_id\thost\tuser_header\tuser_id_header\tuser_name_header\n";

    if (try conn.row("select 1 from acl_document where id = 1", .{})) |row| {
        row.deinit();
    } else {
        try conn.exec("insert into acl_document (id, body) values (1, ?1)", .{default_acl});
    }

    if (try conn.row("select 1 from sites_document where id = 1", .{})) |row| {
        row.deinit();
    } else {
        try conn.exec("insert into sites_document (id, body) values (1, ?1)", .{default_sites});
    }
}

pub fn loadAclDocument(conn: zqlite.Conn, allocator: std.mem.Allocator) ![]u8 {
    const row = (try conn.row("select body from acl_document where id = 1", .{})) orelse return error.MissingDocument;
    defer row.deinit();
    return try allocator.dupe(u8, row.text(0));
}

pub fn loadSitesDocument(conn: zqlite.Conn, allocator: std.mem.Allocator) ![]u8 {
    const row = (try conn.row("select body from sites_document where id = 1", .{})) orelse return error.MissingDocument;
    defer row.deinit();
    return try allocator.dupe(u8, row.text(0));
}

pub fn saveAclDocument(conn: zqlite.Conn, body: []const u8) !void {
    try conn.exec(
        "insert into acl_document (id, body) values (1, ?1) on conflict(id) do update set body = excluded.body",
        .{body},
    );
}

pub fn saveSitesDocument(conn: zqlite.Conn, body: []const u8) !void {
    try conn.exec(
        "insert into sites_document (id, body) values (1, ?1) on conflict(id) do update set body = excluded.body",
        .{body},
    );
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
        for (list.items) |u| allocator.free(u.username);
        list.deinit(allocator);
    }

    var rows = try conn.rows("select id, username, enabled from users order by id", .{});
    defer rows.deinit();
    while (rows.next()) |row| {
        try list.append(allocator, .{
            .id = row.int(0),
            .username = try allocator.dupe(u8, row.text(1)),
            .enabled = row.int(2) != 0,
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

/// Group names the user belongs to (allocated from `allocator`).
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
    site_id: []const u8,
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
) !?struct { session_id: []u8, site_id: []u8, path: []u8 } {
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
    const site_id = try allocator.dupe(u8, row.text(1));
    errdefer allocator.free(site_id);
    const path = try allocator.dupe(u8, row.text(2));
    errdefer allocator.free(path);
    row.deinit();

    try conn.exec("delete from tickets where id = ?1", .{ticket_id});
    try conn.commit();

    if (expires_at < util.unixNow(io)) {
        allocator.free(session_id);
        allocator.free(site_id);
        allocator.free(path);
        return null;
    }

    return .{
        .session_id = session_id,
        .site_id = site_id,
        .path = path,
    };
}
