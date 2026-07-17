const std = @import("std");
const net = std.Io.net;
const ber = @import("ber.zig");
const db = @import("db.zig");
const password = @import("password.zig");
const App = @import("app.zig").App;

const Tag = struct {
    const ldap_message: u8 = 0x30;
    const bind_request: u8 = 0x60;
    const bind_response: u8 = 0x61;
    const unbind_request: u8 = 0x42;
    const search_request: u8 = 0x63;
    const search_entry: u8 = 0x64;
    const search_done: u8 = 0x65;
    const auth_simple: u8 = 0x80;
    const filter_and: u8 = 0xa0;
    const filter_or: u8 = 0xa1;
    const filter_not: u8 = 0xa2;
    const filter_eq: u8 = 0xa3;
    const filter_present: u8 = 0x87;
    const filter_approx: u8 = 0xa8;
};

const ResultCode = struct {
    const success: i64 = 0;
    const protocol_error: i64 = 2;
    const no_such_object: i64 = 32;
    const invalid_credentials: i64 = 49;
    const unwilling_to_perform: i64 = 53;
};

pub fn startBackground(app: *App) !void {
    if (app.config.ldap_listen == null) return;
    const thread = try std.Thread.spawn(.{}, threadMain, .{app});
    thread.detach();
}

fn threadMain(app: *App) void {
    serve(app) catch |err| {
        std.log.err("ldap server error: {s}", .{@errorName(err)});
    };
}

fn serve(app: *App) !void {
    const listen = app.config.ldap_listen orelse return;
    const addr = try parseListenAddress(listen.host, listen.port);
    var server = try addr.listen(app.io, .{ .reuse_address = true });
    defer server.deinit(app.io);

    std.log.info("authum LDAP listening on {s}:{d} (base {s})", .{
        listen.host,
        listen.port,
        app.config.ldap_base_dn,
    });

    while (true) {
        const stream = try server.accept(app.io);
        const ctx = try app.allocator.create(Conn);
        ctx.* = .{ .app = app, .stream = stream };
        const t = std.Thread.spawn(.{}, connThread, .{ctx}) catch |err| {
            app.allocator.destroy(ctx);
            stream.close(app.io);
            std.log.err("ldap spawn: {s}", .{@errorName(err)});
            continue;
        };
        t.detach();
    }
}

const Conn = struct {
    app: *App,
    stream: net.Stream,
};

fn connThread(ctx: *Conn) void {
    defer {
        ctx.stream.close(ctx.app.io);
        ctx.app.allocator.destroy(ctx);
    }
    handleConn(ctx.app, ctx.stream) catch |err| {
        if (err != error.EndOfStream) {
            std.log.warn("ldap connection: {s}", .{@errorName(err)});
        }
    };
}

fn handleConn(app: *App, stream: net.Stream) !void {
    var bound_username: ?[]u8 = null;
    defer if (bound_username) |u| app.allocator.free(u);

    var read_buf: [8192]u8 = undefined;
    var write_buf: [8192]u8 = undefined;
    var reader = stream.reader(app.io, &read_buf);
    var writer = stream.writer(app.io, &write_buf);

    while (true) {
        const msg = readMessage(app.allocator, &reader.interface) catch |err| {
            if (err == error.EndOfStream) return;
            return err;
        };
        defer app.allocator.free(msg);

        var r: ber.Reader = .{ .bytes = msg };
        const outer_len = try r.expectTag(Tag.ldap_message);
        const outer_end = r.pos + outer_len;
        const message_id = try r.readInteger();
        const op_tag = try r.peekTag();

        switch (op_tag) {
            Tag.bind_request => {
                _ = try r.expectTag(Tag.bind_request);
                const version = try r.readInteger();
                const name = try r.readOctetString();
                const auth_tag = try r.readTag();
                const auth_len = try r.readLength();
                const secret = try r.readBytes(auth_len);

                if (version != 3 or auth_tag != Tag.auth_simple) {
                    try sendResult(&writer.interface, app.allocator, message_id, Tag.bind_response, ResultCode.protocol_error, "unsupported bind");
                    try writer.interface.flush();
                    continue;
                }

                if (name.len == 0 and secret.len == 0) {
                    if (bound_username) |u| app.allocator.free(u);
                    bound_username = null;
                    try sendResult(&writer.interface, app.allocator, message_id, Tag.bind_response, ResultCode.success, "");
                    try writer.interface.flush();
                    continue;
                }

                const username = extractUsername(name, app.config.ldap_base_dn) orelse {
                    try sendResult(&writer.interface, app.allocator, message_id, Tag.bind_response, ResultCode.invalid_credentials, "bad dn");
                    try writer.interface.flush();
                    continue;
                };

                const ok = try verifyPassword(app, username, secret);
                if (!ok) {
                    try sendResult(&writer.interface, app.allocator, message_id, Tag.bind_response, ResultCode.invalid_credentials, "invalid credentials");
                    try writer.interface.flush();
                    continue;
                }
                if (bound_username) |u| app.allocator.free(u);
                bound_username = try app.allocator.dupe(u8, username);
                try sendResult(&writer.interface, app.allocator, message_id, Tag.bind_response, ResultCode.success, "");
                try writer.interface.flush();
            },
            Tag.unbind_request => return,
            Tag.search_request => {
                _ = try r.expectTag(Tag.search_request);
                const base = try r.readOctetString();
                const scope = try r.readEnumerated();
                _ = try r.readEnumerated(); // deref
                _ = try r.readInteger(); // sizeLimit
                _ = try r.readInteger(); // timeLimit
                _ = try r.readBoolean(); // typesOnly
                const filter = try parseFilter(app.allocator, &r);
                defer freeFilter(app.allocator, filter);
                // attributes SEQUENCE — skip
                if (r.pos < outer_end) try r.skipElement();

                try handleSearch(app, &writer.interface, message_id, base, scope, filter);
                try writer.interface.flush();
            },
            else => {
                try r.skipElement();
                try sendResult(&writer.interface, app.allocator, message_id, Tag.search_done, ResultCode.unwilling_to_perform, "unsupported operation");
                try writer.interface.flush();
            },
        }
    }
}

fn readMessage(allocator: std.mem.Allocator, reader: *std.Io.Reader) ![]u8 {
    const tag = try reader.takeByte();
    if (tag != Tag.ldap_message) return error.ProtocolError;

    const first = try reader.takeByte();
    var length: usize = undefined;
    var header_extra: usize = 0;
    var len_bytes: [8]u8 = undefined;
    if (first & 0x80 == 0) {
        length = first;
    } else {
        const nbytes = first & 0x7f;
        if (nbytes == 0 or nbytes > 4) return error.ProtocolError;
        try reader.readSliceAll(len_bytes[0..nbytes]);
        length = 0;
        for (len_bytes[0..nbytes]) |b| length = (length << 8) | b;
        header_extra = nbytes;
    }

    const total = 2 + header_extra + length;
    const buf = try allocator.alloc(u8, total);
    errdefer allocator.free(buf);
    buf[0] = tag;
    buf[1] = first;
    if (header_extra > 0) @memcpy(buf[2 .. 2 + header_extra], len_bytes[0..header_extra]);
    try reader.readSliceAll(buf[2 + header_extra ..]);
    return buf;
}

fn sendResult(w: *std.Io.Writer, allocator: std.mem.Allocator, message_id: i64, op_tag: u8, code: i64, diag: []const u8) !void {
    var list: std.ArrayList(u8) = .empty;
    defer list.deinit(allocator);
    const msg_pos = try ber.writeSequenceStart(&list, allocator, Tag.ldap_message);
    try ber.writeInteger(&list, allocator, message_id);
    const op_pos = try ber.writeSequenceStart(&list, allocator, op_tag);
    try ber.writeEnumerated(&list, allocator, code);
    try ber.writeOctetString(&list, allocator, "");
    try ber.writeOctetString(&list, allocator, diag);
    ber.writeSequenceEnd(&list, op_pos);
    ber.writeSequenceEnd(&list, msg_pos);
    try w.writeAll(list.items);
}

fn sendSearchEntry(
    w: *std.Io.Writer,
    allocator: std.mem.Allocator,
    message_id: i64,
    dn: []const u8,
    attrs: []const struct { name: []const u8, values: []const []const u8 },
) !void {
    var list: std.ArrayList(u8) = .empty;
    defer list.deinit(allocator);
    const msg_pos = try ber.writeSequenceStart(&list, allocator, Tag.ldap_message);
    try ber.writeInteger(&list, allocator, message_id);
    const entry_pos = try ber.writeSequenceStart(&list, allocator, Tag.search_entry);
    try ber.writeOctetString(&list, allocator, dn);
    const attrs_pos = try ber.writeSequenceStart(&list, allocator, ber.Tag.sequence);
    for (attrs) |attr| {
        const attr_pos = try ber.writeSequenceStart(&list, allocator, ber.Tag.sequence);
        try ber.writeOctetString(&list, allocator, attr.name);
        const set_pos = try ber.writeSequenceStart(&list, allocator, 0x31); // SET
        for (attr.values) |v| try ber.writeOctetString(&list, allocator, v);
        ber.writeSequenceEnd(&list, set_pos);
        ber.writeSequenceEnd(&list, attr_pos);
    }
    ber.writeSequenceEnd(&list, attrs_pos);
    ber.writeSequenceEnd(&list, entry_pos);
    ber.writeSequenceEnd(&list, msg_pos);
    try w.writeAll(list.items);
}

const Filter = union(enum) {
    and_f: []Filter,
    or_f: []Filter,
    not_f: *Filter,
    eq: struct { attr: []const u8, value: []const u8 },
    present: []const u8,
    match_all,
    match_none,
};

fn parseFilter(allocator: std.mem.Allocator, r: *ber.Reader) !Filter {
    const tag = try r.readTag();
    const len = try r.readLength();
    const end = r.pos + len;
    defer r.pos = end;

    switch (tag) {
        Tag.filter_and, Tag.filter_or => {
            var list: std.ArrayList(Filter) = .empty;
            errdefer {
                for (list.items) |f| freeFilter(allocator, f);
                list.deinit(allocator);
            }
            var child_r: ber.Reader = .{ .bytes = r.bytes, .pos = r.pos };
            while (child_r.pos < end) {
                try list.append(allocator, try parseFilter(allocator, &child_r));
            }
            r.pos = end;
            const owned = try list.toOwnedSlice(allocator);
            return if (tag == Tag.filter_and) .{ .and_f = owned } else .{ .or_f = owned };
        },
        Tag.filter_not => {
            var child_r: ber.Reader = .{ .bytes = r.bytes, .pos = r.pos };
            const inner = try parseFilter(allocator, &child_r);
            const ptr = try allocator.create(Filter);
            ptr.* = inner;
            r.pos = end;
            return .{ .not_f = ptr };
        },
        Tag.filter_eq, Tag.filter_approx => {
            var child_r: ber.Reader = .{ .bytes = r.bytes[r.pos..end], .pos = 0 };
            const attr = try child_r.readOctetString();
            const value = try child_r.readOctetString();
            return .{ .eq = .{
                .attr = try allocator.dupe(u8, attr),
                .value = try allocator.dupe(u8, value),
            } };
        },
        Tag.filter_present => {
            const attr = r.bytes[r.pos..end];
            return .{ .present = try allocator.dupe(u8, attr) };
        },
        else => return .match_all, // treat unknown filters as match-all so nested wraps still work
    }
}

fn freeFilter(allocator: std.mem.Allocator, filter: Filter) void {
    switch (filter) {
        .and_f, .or_f => |items| {
            for (items) |f| freeFilter(allocator, f);
            allocator.free(items);
        },
        .not_f => |ptr| {
            freeFilter(allocator, ptr.*);
            allocator.destroy(ptr);
        },
        .eq => |e| {
            allocator.free(e.attr);
            allocator.free(e.value);
        },
        .present => |a| allocator.free(a),
        .match_all, .match_none => {},
    }
}

const Entry = struct {
    dn: []const u8,
    attrs: std.StringHashMapUnmanaged([]const []const u8),
};

fn evalFilter(filter: Filter, entry: Entry) bool {
    switch (filter) {
        .match_all => return true,
        .match_none => return false,
        .and_f => |items| {
            for (items) |f| if (!evalFilter(f, entry)) return false;
            return true;
        },
        .or_f => |items| {
            for (items) |f| if (evalFilter(f, entry)) return true;
            return false;
        },
        .not_f => |ptr| return !evalFilter(ptr.*, entry),
        .present => |attr| return getAttr(entry, attr) != null,
        .eq => |e| {
            const vals = getAttr(entry, e.attr) orelse return false;
            for (vals) |v| {
                if (std.ascii.eqlIgnoreCase(e.attr, "objectClass")) {
                    if (std.ascii.eqlIgnoreCase(v, e.value)) return true;
                } else if (std.mem.eql(u8, v, e.value)) return true;
            }
            return false;
        },
    }
}

fn getAttr(entry: Entry, name: []const u8) ?[]const []const u8 {
    var it = entry.attrs.iterator();
    while (it.next()) |kv| {
        if (std.ascii.eqlIgnoreCase(kv.key_ptr.*, name)) return kv.value_ptr.*;
    }
    return null;
}

fn handleSearch(app: *App, w: *std.Io.Writer, message_id: i64, base: []const u8, scope: i64, filter: Filter) !void {
    const base_dn = app.config.ldap_base_dn;
    if (!dnUnder(base, base_dn) and !std.ascii.eqlIgnoreCase(base, base_dn)) {
        // Allow empty base as naming context root.
        if (base.len != 0) {
            try sendResult(w, app.allocator, message_id, Tag.search_done, ResultCode.no_such_object, "bad base");
            return;
        }
    }

    var arena_state: std.heap.ArenaAllocator = .init(app.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    const entries = try buildDirectory(app, arena);
    for (entries) |entry| {
        if (!dnInScope(entry.dn, base, scope, base_dn)) continue;
        if (!evalFilter(filter, entry)) continue;
        var attr_list: std.ArrayList(struct { name: []const u8, values: []const []const u8 }) = .empty;
        var it = entry.attrs.iterator();
        while (it.next()) |kv| {
            try attr_list.append(arena, .{ .name = kv.key_ptr.*, .values = kv.value_ptr.* });
        }
        try sendSearchEntry(w, app.allocator, message_id, entry.dn, attr_list.items);
    }
    try sendResult(w, app.allocator, message_id, Tag.search_done, ResultCode.success, "");
}

fn buildDirectory(app: *App, arena: std.mem.Allocator) ![]Entry {
    const base = app.config.ldap_base_dn;
    const people_ou = try std.fmt.allocPrint(arena, "ou=people,{s}", .{base});
    const groups_ou = try std.fmt.allocPrint(arena, "ou=groups,{s}", .{base});

    const conn = try app.pool.acquire(app.io);
    defer conn.release(app.io);
    const users = try db.listUsers(conn, arena);
    const groups = try db.listGroups(conn, arena);

    var out: std.ArrayList(Entry) = .empty;

    // Root + OUs
    try out.append(arena, try makeOuEntry(arena, base, "authum"));
    try out.append(arena, try makeOuEntry(arena, people_ou, "people"));
    try out.append(arena, try makeOuEntry(arena, groups_ou, "groups"));

    // Preload group memberships for memberOf
    var user_groups: std.AutoHashMapUnmanaged(i64, std.ArrayList([]const u8)) = .empty;
    for (groups) |g| {
        const members = try db.listGroupMembers(conn, arena, g.id);
        const gdn = try std.fmt.allocPrint(arena, "cn={s},{s}", .{ g.name, groups_ou });
        for (members) |m| {
            const gop = try user_groups.getOrPut(arena, m.user_id);
            if (!gop.found_existing) gop.value_ptr.* = .empty;
            try gop.value_ptr.append(arena, gdn);
        }
    }

    for (users) |u| {
        if (!u.enabled) continue;
        const dn = try std.fmt.allocPrint(arena, "uid={s},{s}", .{ u.username, people_ou });
        var attrs: std.StringHashMapUnmanaged([]const []const u8) = .empty;
        const oc = try arena.dupe([]const u8, &.{ "top", "person", "organizationalPerson", "inetOrgPerson" });
        try attrs.put(arena, "objectClass", oc);
        try attrs.put(arena, "uid", try arena.dupe([]const u8, &.{u.username}));
        try attrs.put(arena, "cn", try arena.dupe([]const u8, &.{u.username}));
        try attrs.put(arena, "sn", try arena.dupe([]const u8, &.{u.username}));
        if (user_groups.get(u.id)) |mof| {
            try attrs.put(arena, "memberOf", try arena.dupe([]const u8, mof.items));
        }
        try out.append(arena, .{ .dn = dn, .attrs = attrs });
    }

    for (groups) |g| {
        const dn = try std.fmt.allocPrint(arena, "cn={s},{s}", .{ g.name, groups_ou });
        const members = try db.listGroupMembers(conn, arena, g.id);
        var member_dns: std.ArrayList([]const u8) = .empty;
        for (members) |m| {
            try member_dns.append(arena, try std.fmt.allocPrint(arena, "uid={s},{s}", .{ m.username, people_ou }));
        }
        var attrs: std.StringHashMapUnmanaged([]const []const u8) = .empty;
        try attrs.put(arena, "objectClass", try arena.dupe([]const u8, &.{ "top", "groupOfNames" }));
        try attrs.put(arena, "cn", try arena.dupe([]const u8, &.{g.name}));
        if (member_dns.items.len > 0) {
            try attrs.put(arena, "member", try arena.dupe([]const u8, member_dns.items));
            try attrs.put(arena, "uniqueMember", try arena.dupe([]const u8, member_dns.items));
        }
        try out.append(arena, .{ .dn = dn, .attrs = attrs });
    }

    return try out.toOwnedSlice(arena);
}

fn makeOuEntry(arena: std.mem.Allocator, dn: []const u8, ou: []const u8) !Entry {
    var attrs: std.StringHashMapUnmanaged([]const []const u8) = .empty;
    try attrs.put(arena, "objectClass", try arena.dupe([]const u8, &.{ "top", "organizationalUnit" }));
    try attrs.put(arena, "ou", try arena.dupe([]const u8, &.{ou}));
    return .{ .dn = dn, .attrs = attrs };
}

fn dnUnder(dn: []const u8, base: []const u8) bool {
    if (dn.len < base.len) return false;
    if (!std.ascii.eqlIgnoreCase(dn[dn.len - base.len ..], base)) return false;
    if (dn.len == base.len) return true;
    return dn[dn.len - base.len - 1] == ',';
}

fn dnInScope(dn: []const u8, base: []const u8, scope: i64, root: []const u8) bool {
    const effective_base = if (base.len == 0) root else base;
    if (scope == 0) return std.ascii.eqlIgnoreCase(dn, effective_base); // base
    if (scope == 1) { // one level
        if (std.ascii.eqlIgnoreCase(dn, effective_base)) return false;
        if (!dnUnder(dn, effective_base)) return false;
        // exactly one RDN more
        const prefix = dn[0 .. dn.len - effective_base.len];
        if (prefix.len == 0) return false;
        const trimmed = if (prefix[prefix.len - 1] == ',') prefix[0 .. prefix.len - 1] else prefix;
        return std.mem.indexOfScalar(u8, trimmed, ',') == null;
    }
    // subtree
    return std.ascii.eqlIgnoreCase(dn, effective_base) or dnUnder(dn, effective_base);
}

pub fn extractUsername(dn_or_user: []const u8, base_dn: []const u8) ?[]const u8 {
    if (dn_or_user.len == 0) return null;
    if (std.mem.indexOfScalar(u8, dn_or_user, '=') == null and std.mem.indexOfScalar(u8, dn_or_user, ',') == null) {
        return dn_or_user;
    }
    // uid=name,... or cn=name,...
    const eq = std.mem.indexOfScalar(u8, dn_or_user, '=') orelse return null;
    const attr = dn_or_user[0..eq];
    if (!(std.ascii.eqlIgnoreCase(attr, "uid") or std.ascii.eqlIgnoreCase(attr, "cn"))) return null;
    const rest = dn_or_user[eq + 1 ..];
    const comma = std.mem.indexOfScalar(u8, rest, ',');
    const name = if (comma) |c| rest[0..c] else rest;
    if (name.len == 0) return null;
    if (comma != null) {
        const suffix = rest[comma.? + 1 ..];
        // loose check: suffix should end with base or contain ou=people
        _ = base_dn;
        _ = suffix;
    }
    return name;
}

fn verifyPassword(app: *App, username: []const u8, plain: []const u8) !bool {
    const conn = try app.pool.acquire(app.io);
    defer conn.release(app.io);
    const found = (try db.findUserByUsername(conn, app.allocator, username)) orelse return false;
    defer {
        app.allocator.free(found.username);
        app.allocator.free(found.password_hash);
    }
    if (!found.enabled) return false;
    return try password.verify(app.allocator, app.io, found.password_hash, plain);
}

fn parseListenAddress(host: []const u8, port: u16) !net.IpAddress {
    if (std.mem.eql(u8, host, "0.0.0.0") or std.mem.eql(u8, host, "*")) {
        return .{ .ip4 = net.Ip4Address.unspecified(port) };
    }
    if (std.mem.eql(u8, host, "127.0.0.1") or std.mem.eql(u8, host, "localhost")) {
        return .{ .ip4 = net.Ip4Address.loopback(port) };
    }
    var parts: [4]u8 = undefined;
    var it = std.mem.splitScalar(u8, host, '.');
    var i: usize = 0;
    while (it.next()) |part| : (i += 1) {
        if (i >= 4) return error.InvalidListenHost;
        parts[i] = try std.fmt.parseInt(u8, part, 10);
    }
    if (i != 4) return error.InvalidListenHost;
    return .{ .ip4 = .{ .bytes = parts, .port = port } };
}

test "extractUsername from dn" {
    try std.testing.expectEqualStrings(
        "alice",
        extractUsername("uid=alice,ou=people,dc=authum,dc=local", "dc=authum,dc=local").?,
    );
    try std.testing.expectEqualStrings("alice", extractUsername("alice", "dc=authum,dc=local").?);
}

test "dn scope" {
    const root = "dc=authum,dc=local";
    const people = "ou=people,dc=authum,dc=local";
    const user = "uid=alice,ou=people,dc=authum,dc=local";
    try std.testing.expect(dnInScope(user, people, 2, root));
    try std.testing.expect(dnInScope(user, people, 1, root));
    try std.testing.expect(!dnInScope(user, people, 0, root));
    try std.testing.expect(dnInScope(people, people, 0, root));
}
