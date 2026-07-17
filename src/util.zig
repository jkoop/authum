const std = @import("std");

pub fn validUsername(name: []const u8) bool {
    if (name.len == 0) return false;
    for (name) |c| {
        const ok = (c >= 'a' and c <= 'z') or
            (c >= 'A' and c <= 'Z') or
            (c >= '0' and c <= '9') or
            c == '_';
        if (!ok) return false;
    }
    return true;
}

pub fn unixNow(io: std.Io) i64 {
    return std.Io.Clock.real.now(io).toSeconds();
}

pub const session_cookie_name = "authum_session";
pub const cookie_max_age = "4000000000";
pub const ticket_ttl_secs: i64 = 5 * 60;

pub fn randomHex(io: std.Io, comptime nbytes: usize, buf: *[nbytes * 2]u8) void {
    var raw: [nbytes]u8 = undefined;
    io.random(&raw);
    const hex = std.fmt.bytesToHex(raw, .lower);
    @memcpy(buf, &hex);
}

pub fn isBrowserUserAgent(ua: ?[]const u8) bool {
    const value = ua orelse return false;
    return std.mem.indexOf(u8, value, "Mozilla") != null;
}

pub fn hostWithoutPort(host: []const u8) []const u8 {
    if (std.mem.startsWith(u8, host, "[")) {
        if (std.mem.indexOfScalar(u8, host, ']')) |end| {
            return host[0 .. end + 1];
        }
        return host;
    }
    if (std.mem.lastIndexOfScalar(u8, host, ':')) |colon| {
        return host[0..colon];
    }
    return host;
}

pub fn splitPathQuery(uri: []const u8) struct { path: []const u8, query: []const u8 } {
    const path_start = if (std.mem.indexOf(u8, uri, "://")) |scheme| blk: {
        const after = uri[scheme + 3 ..];
        if (std.mem.indexOfScalar(u8, after, '/')) |slash| {
            break :blk scheme + 3 + slash;
        }
        return .{ .path = "/", .query = "" };
    } else 0;

    const rest = uri[path_start..];
    if (std.mem.indexOfScalar(u8, rest, '?')) |q| {
        return .{ .path = if (q == 0) "/" else rest[0..q], .query = rest[q + 1 ..] };
    }
    return .{ .path = if (rest.len == 0) "/" else rest, .query = "" };
}

pub fn queryGet(query: []const u8, key: []const u8) ?[]const u8 {
    var it = std.mem.splitScalar(u8, query, '&');
    while (it.next()) |pair| {
        if (pair.len == 0) continue;
        if (std.mem.indexOfScalar(u8, pair, '=')) |eq| {
            const k = pair[0..eq];
            const v = pair[eq + 1 ..];
            if (std.mem.eql(u8, k, key)) return v;
        } else if (std.mem.eql(u8, pair, key)) {
            return "";
        }
    }
    return null;
}

pub fn urlDecode(allocator: std.mem.Allocator, encoded: []const u8) ![]u8 {
    var list: std.ArrayList(u8) = .empty;
    errdefer list.deinit(allocator);
    var i: usize = 0;
    while (i < encoded.len) {
        const c = encoded[i];
        if (c == '+') {
            try list.append(allocator, ' ');
            i += 1;
        } else if (c == '%' and i + 2 < encoded.len) {
            const hi = std.fmt.parseInt(u8, encoded[i + 1 .. i + 2], 16) catch {
                try list.append(allocator, c);
                i += 1;
                continue;
            };
            const lo = std.fmt.parseInt(u8, encoded[i + 2 .. i + 3], 16) catch {
                try list.append(allocator, c);
                i += 1;
                continue;
            };
            try list.append(allocator, (hi << 4) | lo);
            i += 3;
        } else {
            try list.append(allocator, c);
            i += 1;
        }
    }
    return try list.toOwnedSlice(allocator);
}

pub fn urlEncode(allocator: std.mem.Allocator, value: []const u8) ![]u8 {
    var list: std.ArrayList(u8) = .empty;
    errdefer list.deinit(allocator);
    for (value) |c| {
        const unreserved = (c >= 'A' and c <= 'Z') or
            (c >= 'a' and c <= 'z') or
            (c >= '0' and c <= '9') or
            c == '-' or c == '_' or c == '.' or c == '~' or c == '/';
        if (unreserved) {
            try list.append(allocator, c);
        } else {
            var buf: [3]u8 = undefined;
            _ = try std.fmt.bufPrint(&buf, "%{X:0>2}", .{c});
            try list.appendSlice(allocator, &buf);
        }
    }
    return try list.toOwnedSlice(allocator);
}

pub fn parseBasicAuth(allocator: std.mem.Allocator, header: []const u8) !?struct { username: []u8, password: []u8 } {
    if (!std.mem.startsWith(u8, header, "Basic ")) return null;
    const encoded = std.mem.trim(u8, header["Basic ".len..], " \t");
    const decoder = std.base64.standard.Decoder;
    const maxlen = try decoder.calcSizeForSlice(encoded);
    const decoded = try allocator.alloc(u8, maxlen);
    defer allocator.free(decoded);
    try decoder.decode(decoded, encoded);
    const colon = std.mem.indexOfScalar(u8, decoded, ':') orelse return null;
    const username = try allocator.dupe(u8, decoded[0..colon]);
    errdefer allocator.free(username);
    const password = try allocator.dupe(u8, decoded[colon + 1 ..]);
    return .{ .username = username, .password = password };
}

pub fn htmlEscape(allocator: std.mem.Allocator, value: []const u8) ![]u8 {
    var list: std.ArrayList(u8) = .empty;
    errdefer list.deinit(allocator);
    for (value) |c| {
        switch (c) {
            '&' => try list.appendSlice(allocator, "&amp;"),
            '<' => try list.appendSlice(allocator, "&lt;"),
            '>' => try list.appendSlice(allocator, "&gt;"),
            '"' => try list.appendSlice(allocator, "&quot;"),
            '\'' => try list.appendSlice(allocator, "&#39;"),
            else => try list.append(allocator, c),
        }
    }
    return try list.toOwnedSlice(allocator);
}

pub fn setSessionCookie(allocator: std.mem.Allocator, session_id: []const u8, secure: bool) ![]u8 {
    if (secure) {
        return try std.fmt.allocPrint(
            allocator,
            "{s}={s}; Path=/; HttpOnly; Secure; Max-Age={s}",
            .{ session_cookie_name, session_id, cookie_max_age },
        );
    }
    return try std.fmt.allocPrint(
        allocator,
        "{s}={s}; Path=/; HttpOnly; Max-Age={s}",
        .{ session_cookie_name, session_id, cookie_max_age },
    );
}

pub fn clearSessionCookie(secure: bool) []const u8 {
    return if (secure)
        session_cookie_name ++ "=; Path=/; HttpOnly; Secure; Max-Age=0"
    else
        session_cookie_name ++ "=; Path=/; HttpOnly; Max-Age=0";
}

pub fn schemeFromProto(proto: ?[]const u8) []const u8 {
    if (proto) |p| {
        if (std.ascii.eqlIgnoreCase(p, "http")) return "http";
    }
    return "https";
}

test "splitPathQuery" {
    const a = splitPathQuery("/bar?x=1");
    try std.testing.expectEqualStrings("/bar", a.path);
    try std.testing.expectEqualStrings("x=1", a.query);

    const b = splitPathQuery("https://alpha.foo.com/baz?q=1");
    try std.testing.expectEqualStrings("/baz", b.path);
    try std.testing.expectEqualStrings("q=1", b.query);
}

test "hostWithoutPort" {
    try std.testing.expectEqualStrings("alpha.foo.com", hostWithoutPort("alpha.foo.com:443"));
    try std.testing.expectEqualStrings("alpha.foo.com", hostWithoutPort("alpha.foo.com"));
}

test "queryGet" {
    try std.testing.expectEqualStrings("alpha", queryGet("from_site=alpha&from_path=/bar", "from_site").?);
    try std.testing.expectEqualStrings("/bar", queryGet("from_site=alpha&from_path=/bar", "from_path").?);
}

test "validUsername" {
    try std.testing.expect(validUsername("alice"));
    try std.testing.expect(validUsername("Bob_42"));
    try std.testing.expect(!validUsername(""));
    try std.testing.expect(!validUsername("alice-bob"));
    try std.testing.expect(!validUsername("a b"));
}
