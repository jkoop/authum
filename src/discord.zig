const std = @import("std");
const httpz = @import("httpz");
const db = @import("db.zig");
const util = @import("util.zig");
const App = @import("app.zig").App;

pub fn loginStart(app: *App, req: *httpz.Request, res: *httpz.Response) !void {
    const client_id = app.config.discord_client_id orelse {
        res.status = 404;
        res.body = "discord login not configured";
        return;
    };
    const q = try req.query();
    const from_site = q.get("from_site") orelse "";
    const from_path = q.get("from_path") orelse "/";

    var nonce_buf: [32]u8 = undefined;
    util.randomHex(app.io, 16, &nonce_buf);
    const state = try std.fmt.allocPrint(
        res.arena,
        "{s}|{s}|{s}",
        .{ from_site, from_path, nonce_buf[0..] },
    );
    const state_enc = try util.urlEncode(res.arena, state);
    const redirect_uri = try redirectUri(app, res.arena);
    const redirect_enc = try util.urlEncode(res.arena, redirect_uri);
    const loc = try std.fmt.allocPrint(
        res.arena,
        "https://discord.com/api/oauth2/authorize?client_id={s}&response_type=code&scope=identify&redirect_uri={s}&state={s}",
        .{ client_id, redirect_enc, state_enc },
    );
    res.status = 302;
    res.header("Location", loc);
}

pub fn loginCallback(app: *App, req: *httpz.Request, res: *httpz.Response) !void {
    const client_id = app.config.discord_client_id orelse {
        res.status = 404;
        res.body = "discord login not configured";
        return;
    };
    const client_secret = app.config.discord_client_secret orelse {
        res.status = 404;
        res.body = "discord login not configured";
        return;
    };

    const q = try req.query();
    if (q.get("error")) |oauth_err| {
        return redirectLoginError(res, "", "/", try std.fmt.allocPrint(res.arena, "discord: {s}", .{oauth_err}));
    }
    const code = q.get("code") orelse {
        return redirectLoginError(res, "", "/", "missing discord code");
    };
    const state = q.get("state") orelse {
        return redirectLoginError(res, "", "/", "missing discord state");
    };

    var from_site: []const u8 = "";
    var from_path: []const u8 = "/";
    {
        var it = std.mem.splitScalar(u8, state, '|');
        from_site = it.next() orelse "";
        from_path = it.next() orelse "/";
        _ = it.next(); // nonce
    }

    const discord_user = exchangeAndFetchUser(app, res.arena, client_id, client_secret, code) catch {
        return redirectLoginError(res, from_site, from_path, "discord login failed");
    };

    const conn = try app.pool.acquire(app.io);
    defer conn.release(app.io);

    var user_id: i64 = undefined;
    var username: []const u8 = undefined;
    var enabled: bool = undefined;
    var newly_created = false;

    if (try db.findUserByDiscordId(conn, res.arena, discord_user.id)) |existing| {
        user_id = existing.id;
        username = existing.username;
        enabled = existing.enabled;
    } else {
        const uname = try uniqueUsername(conn, res.arena, discord_user.username);
        user_id = try db.createDiscordUser(conn, res.arena, app.io, uname, discord_user.id);
        username = uname;
        enabled = false;
        newly_created = true;
    }

    if (!enabled) {
        res.content_type = .HTML;
        res.body = try app.templates.renderPending(res.arena, .{
            .username = username,
            .newly_created = newly_created,
        });
        return;
    }

    const session_id = try db.createSession(conn, res.arena, app.io, user_id);
    const secure = isSecureRequest(req);
    const cookie = try util.setSessionCookie(res.arena, session_id, secure);
    res.header("Set-Cookie", cookie);

    if (from_site.len == 0) {
        res.status = 302;
        res.header("Location", if (std.mem.eql(u8, username, app.config.admin_user)) "/admin" else "/");
        return;
    }

    const site = (try app.sites.byId(app.io, res.arena, from_site)) orelse {
        return redirectLoginError(res, from_site, from_path, "unknown site");
    };
    const path = if (from_path.len == 0) "/" else from_path;
    const ticket = try db.createTicket(conn, res.arena, app.io, session_id, site.site_id, path);
    const path_enc = try util.urlEncode(res.arena, path);
    const scheme = util.schemeFromProto(req.header("x-forwarded-proto"));
    const loc = try std.fmt.allocPrint(
        res.arena,
        "{s}://{s}/_authum/login?path={s}&ticket={s}",
        .{ scheme, site.host, path_enc, ticket },
    );
    res.status = 302;
    res.header("Location", loc);
}

const DiscordUser = struct {
    id: []const u8,
    username: []const u8,
};

fn exchangeAndFetchUser(
    app: *App,
    arena: std.mem.Allocator,
    client_id: []const u8,
    client_secret: []const u8,
    code: []const u8,
) !DiscordUser {
    var client: std.http.Client = .{ .allocator = app.allocator, .io = app.io };
    defer client.deinit();

    const redirect_uri = try redirectUri(app, arena);
    const body = try std.fmt.allocPrint(
        arena,
        "client_id={s}&client_secret={s}&grant_type=authorization_code&code={s}&redirect_uri={s}",
        .{
            try util.urlEncode(arena, client_id),
            try util.urlEncode(arena, client_secret),
            try util.urlEncode(arena, code),
            try util.urlEncode(arena, redirect_uri),
        },
    );

    var token_aw: std.Io.Writer.Allocating = .init(arena);
    const token_res = try client.fetch(.{
        .location = .{ .url = "https://discord.com/api/oauth2/token" },
        .method = .POST,
        .payload = body,
        .headers = .{
            .content_type = .{ .override = "application/x-www-form-urlencoded" },
        },
        .response_writer = &token_aw.writer,
    });
    if (token_res.status != .ok) return error.DiscordTokenFailed;
    const token_json = token_aw.written();
    const access_token = try jsonStringField(arena, token_json, "access_token");

    var user_aw: std.Io.Writer.Allocating = .init(arena);
    const auth_header = try std.fmt.allocPrint(arena, "Bearer {s}", .{access_token});
    const user_res = try client.fetch(.{
        .location = .{ .url = "https://discord.com/api/users/@me" },
        .method = .GET,
        .extra_headers = &.{
            .{ .name = "Authorization", .value = auth_header },
        },
        .response_writer = &user_aw.writer,
    });
    if (user_res.status != .ok) return error.DiscordUserFailed;
    const user_json = user_aw.written();
    return .{
        .id = try jsonStringField(arena, user_json, "id"),
        .username = try jsonStringField(arena, user_json, "username"),
    };
}

fn jsonStringField(arena: std.mem.Allocator, json: []const u8, key: []const u8) ![]const u8 {
    // Find `"key":` without allocating.
    var search_at: usize = 0;
    const start = while (search_at < json.len) {
        const q = std.mem.indexOfScalarPos(u8, json, search_at, '"') orelse return error.MissingJsonField;
        const after_q = q + 1;
        if (after_q + key.len + 2 <= json.len and
            std.mem.eql(u8, json[after_q .. after_q + key.len], key) and
            json[after_q + key.len] == '"' and
            json[after_q + key.len + 1] == ':')
        {
            break after_q + key.len + 1; // index of ':'
        }
        search_at = after_q;
    } else return error.MissingJsonField;
    var i = start + 1;
    while (i < json.len and (json[i] == ' ' or json[i] == '\t')) : (i += 1) {}
    if (i >= json.len or json[i] != '"') return error.MissingJsonField;
    i += 1;
    const value_start = i;
    while (i < json.len) : (i += 1) {
        if (json[i] == '\\') {
            i += 1;
            continue;
        }
        if (json[i] == '"') break;
    }
    if (i >= json.len) return error.MissingJsonField;
    return try arena.dupe(u8, json[value_start..i]);
}

fn redirectUri(app: *App, arena: std.mem.Allocator) ![]u8 {
    return try std.fmt.allocPrint(arena, "https://{s}/login/discord/callback", .{app.config.domain});
}

fn uniqueUsername(conn: anytype, arena: std.mem.Allocator, discord_name: []const u8) ![]const u8 {
    var buf: std.ArrayList(u8) = .empty;
    defer buf.deinit(arena);
    for (discord_name) |c| {
        const ok = (c >= 'A' and c <= 'Z') or (c >= 'a' and c <= 'z') or (c >= '0' and c <= '9') or c == '_';
        if (ok) try buf.append(arena, c);
    }
    if (buf.items.len == 0) try buf.appendSlice(arena, "discord");
    if (buf.items.len > 32) buf.items.len = 32;

    const base = try arena.dupe(u8, buf.items);
    if (!try db.usernameTaken(conn, base)) return base;

    var n: u32 = 2;
    while (n < 10000) : (n += 1) {
        const candidate = try std.fmt.allocPrint(arena, "{s}_{d}", .{ base, n });
        if (!try db.usernameTaken(conn, candidate)) return candidate;
    }
    return error.UsernameExhausted;
}

fn redirectLoginError(res: *httpz.Response, from_site: []const u8, from_path: []const u8, msg: []const u8) !void {
    const site_enc = try util.urlEncode(res.arena, from_site);
    const path_enc = try util.urlEncode(res.arena, from_path);
    const msg_enc = try util.urlEncode(res.arena, msg);
    const loc = try std.fmt.allocPrint(
        res.arena,
        "/login?from_site={s}&from_path={s}&error={s}",
        .{ site_enc, path_enc, msg_enc },
    );
    res.status = 302;
    res.header("Location", loc);
}

fn isSecureRequest(req: *httpz.Request) bool {
    if (req.header("x-forwarded-proto")) |p| {
        return std.ascii.eqlIgnoreCase(p, "https");
    }
    return false;
}

test "jsonStringField" {
    const json =
        \\{"id":"12345","username":"Cool_User","avatar":null}
    ;
    const id = try jsonStringField(std.testing.allocator, json, "id");
    defer std.testing.allocator.free(id);
    const username = try jsonStringField(std.testing.allocator, json, "username");
    defer std.testing.allocator.free(username);
    try std.testing.expectEqualStrings("12345", id);
    try std.testing.expectEqualStrings("Cool_User", username);
}
