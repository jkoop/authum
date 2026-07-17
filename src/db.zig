const std = @import("std");
const zqlite = @import("zqlite");
const password = @import("password.zig");
const util = @import("util.zig");

pub const User = struct {
    id: i64,
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
    \\  created_at integer not null
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
            "insert into users (username, password_hash, created_at) values (?1, ?2, ?3)",
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
        "insert into users (username, password_hash, created_at) values (?1, ?2, ?3)",
        .{ username, hash, util.unixNow(io) },
    );
    return conn.lastInsertedRowId();
}

pub fn listUsers(conn: zqlite.Conn, allocator: std.mem.Allocator) ![]User {
    var list: std.ArrayList(User) = .empty;
    errdefer {
        for (list.items) |u| allocator.free(u.username);
        list.deinit(allocator);
    }

    var rows = try conn.rows("select id, username from users order by id", .{});
    defer rows.deinit();
    while (rows.next()) |row| {
        try list.append(allocator, .{
            .id = row.int(0),
            .username = try allocator.dupe(u8, row.text(1)),
        });
    }
    if (rows.err) |err| return err;
    return try list.toOwnedSlice(allocator);
}

pub fn findUserById(
    conn: zqlite.Conn,
    allocator: std.mem.Allocator,
    id: i64,
) !?struct { id: i64, username: []u8, password_hash: []u8 } {
    const row = (try conn.row(
        "select id, username, password_hash from users where id = ?1",
        .{id},
    )) orelse return null;
    defer row.deinit();
    return .{
        .id = row.int(0),
        .username = try allocator.dupe(u8, row.text(1)),
        .password_hash = try allocator.dupe(u8, row.text(2)),
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
    try conn.exec("delete from users where id = ?1", .{id});
}

pub fn findUserByUsername(
    conn: zqlite.Conn,
    allocator: std.mem.Allocator,
    username: []const u8,
) !?struct { id: i64, username: []u8, password_hash: []u8 } {
    const row = (try conn.row(
        "select id, username, password_hash from users where username = ?1",
        .{username},
    )) orelse return null;
    defer row.deinit();
    return .{
        .id = row.int(0),
        .username = try allocator.dupe(u8, row.text(1)),
        .password_hash = try allocator.dupe(u8, row.text(2)),
    };
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
        \\where sessions.id = ?1
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
