const std = @import("std");
const httpz = @import("httpz");
const db = @import("db.zig");
const util = @import("util.zig");
const App = @import("app.zig").App;

pub fn loginStart(app: *App, req: *httpz.Request, res: *httpz.Response) !void {
    const client_id = app.config.discord_client_id orelse {
        std.log.err("[{d}] discord login start requested but not configured", .{util.unixNow(app.io)});
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
        std.log.err("[{d}] discord callback hit but client_id not configured", .{util.unixNow(app.io)});
        res.status = 404;
        res.body = "discord login not configured";
        return;
    };
    const client_secret = app.config.discord_client_secret orelse {
        std.log.err("[{d}] discord callback hit but client_secret not configured", .{util.unixNow(app.io)});
        res.status = 404;
        res.body = "discord login not configured";
        return;
    };

    const q = try req.query();
    if (q.get("error")) |oauth_err| {
        std.log.err("[{d}] discord oauth callback returned error: {s}", .{ util.unixNow(app.io), oauth_err });
        return redirectLoginError(res, "", "/", try std.fmt.allocPrint(res.arena, "discord: {s}", .{oauth_err}));
    }
    const code = q.get("code") orelse {
        std.log.err("[{d}] discord oauth callback missing code", .{util.unixNow(app.io)});
        return redirectLoginError(res, "", "/", "missing discord code");
    };
    const state = q.get("state") orelse {
        std.log.err("[{d}] discord oauth callback missing state", .{util.unixNow(app.io)});
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

    const discord_user = exchangeAndFetchUser(app, res.arena, client_id, client_secret, code) catch |err| {
        std.log.err("[{d}] discord exchange/fetch failed: {s}", .{ util.unixNow(app.io), @errorName(err) });
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

    const site_id = std.fmt.parseInt(i64, from_site, 10) catch {
        return redirectLoginError(res, from_site, from_path, "unknown site");
    };
    const site = (try app.sites.byId(app.io, res.arena, site_id)) orelse {
        return redirectLoginError(res, from_site, from_path, "unknown site");
    };
    const path = if (from_path.len == 0) "/" else from_path;
    const ticket = try db.createTicket(conn, res.arena, app.io, session_id, site.id, path);
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
    if (token_res.status != .ok) {
        std.log.err(
            "[{d}] discord token exchange failed: status={s} body={s}",
            .{ util.unixNow(app.io), @tagName(token_res.status), token_aw.written() },
        );
        return error.DiscordTokenFailed;
    }
    const token = try std.json.parseFromSliceLeaky(
        struct { access_token: []const u8 },
        arena,
        token_aw.written(),
        .{ .ignore_unknown_fields = true },
    );

    var user_aw: std.Io.Writer.Allocating = .init(arena);
    const auth_header = try std.fmt.allocPrint(arena, "Bearer {s}", .{token.access_token});
    const user_res = try client.fetch(.{
        .location = .{ .url = "https://discord.com/api/users/@me" },
        .method = .GET,
        .extra_headers = &.{
            .{ .name = "Authorization", .value = auth_header },
        },
        .response_writer = &user_aw.writer,
    });
    if (user_res.status != .ok) {
        std.log.err(
            "[{d}] discord user fetch failed: status={s} body={s}",
            .{ util.unixNow(app.io), @tagName(user_res.status), user_aw.written() },
        );
        return error.DiscordUserFailed;
    }
    return try std.json.parseFromSliceLeaky(
        DiscordUser,
        arena,
        user_aw.written(),
        .{ .ignore_unknown_fields = true },
    );
}

fn redirectUri(app: *App, arena: std.mem.Allocator) ![]u8 {
    return try std.fmt.allocPrint(arena, "https://{s}/login/discord/callback", .{app.config.domain});
}

fn uniqueUsername(conn: anytype, arena: std.mem.Allocator, discord_name: []const u8) ![]const u8 {
    var buf: std.ArrayList(u8) = .empty;
    defer buf.deinit(arena);
    for (discord_name) |c| {
        if (std.ascii.isAlphanumeric(c) or c == '_') try buf.append(arena, c);
    }
    if (buf.items.len == 0 or !util.validUsername(buf.items)) {
        buf.clearRetainingCapacity();
        try buf.appendSlice(arena, "discord");
    }
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

test "discord user json parse" {
    const json =
        \\{"id":"12345","username":"Cool_User","avatar":null}
    ;
    const parsed = try std.json.parseFromSlice(
        DiscordUser,
        std.testing.allocator,
        json,
        .{ .ignore_unknown_fields = true },
    );
    defer parsed.deinit();
    try std.testing.expectEqualStrings("12345", parsed.value.id);
    try std.testing.expectEqualStrings("Cool_User", parsed.value.username);
}
