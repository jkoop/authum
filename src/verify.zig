const std = @import("std");
const httpz = @import("httpz");
const password = @import("password.zig");
const db = @import("db.zig");
const util = @import("util.zig");
const App = @import("app.zig").App;

pub fn handle(app: *App, req: *httpz.Request, res: *httpz.Response) !void {
    const arena = res.arena;
    const host_hdr = req.header("x-forwarded-host") orelse req.header("host") orelse {
        res.status = 400;
        res.body = "missing X-Forwarded-Host";
        return;
    };
    const uri = req.header("x-forwarded-uri") orelse {
        res.status = 400;
        res.body = "missing X-Forwarded-Uri";
        return;
    };
    const method = req.header("x-forwarded-method") orelse @tagName(req.method);
    const proto = req.header("x-forwarded-proto");
    const scheme = util.schemeFromProto(proto);
    const secure = std.ascii.eqlIgnoreCase(scheme, "https");
    const host = util.hostWithoutPort(host_hdr);
    const parsed = util.splitPathQuery(uri);
    const path = parsed.path;
    const query = parsed.query;

    // Special paths inferred from the original request.
    if (std.mem.eql(u8, path, "/_authum/login")) {
        return handleAuthumLogin(app, req, res, arena, host, query, scheme, secure);
    }
    if (std.mem.eql(u8, path, "/_authum/logout")) {
        return handleAuthumLogout(app, req, res, arena, secure);
    }

    const browser = util.isBrowserUserAgent(req.header("user-agent"));
    const user = try resolveUser(app, req, res, arena, browser) orelse return;

    const site = (try app.sites.byHost(app.io, arena, host)) orelse {
        return respondForbidden(app, req, res, arena, browser, .{
            .reason = "unknown site",
            .host = host,
            .path = path,
            .method = method,
            .site_name = "—",
            .site_id = "—",
            .user = user,
        });
    };

    const groups = blk: {
        const conn = try app.pool.acquire(app.io);
        defer conn.release(app.io);
        break :blk try db.listGroupIdsForUser(conn, arena, user.user_id);
    };
    const decision = app.acl.decideWithRule(app.io, user.user_id, groups, site.id, path, method);
    if (decision.effect == .deny) {
        return respondForbidden(app, req, res, arena, browser, .{
            .reason = "forbidden",
            .host = host,
            .path = path,
            .method = method,
            .site_name = site.name,
            .site_id = try std.fmt.allocPrint(arena, "{d}", .{site.id}),
            .user = user,
            .acl_rule_id = decision.rule_id,
        });
    }

    const id_str = try std.fmt.allocPrint(arena, "{d}", .{user.user_id});
    res.status = 200;
    res.header(site.user_id_header, id_str);
    res.header(site.user_name_header, user.username);
    res.body = "OK";
}

fn resolveUser(
    app: *App,
    req: *httpz.Request,
    res: *httpz.Response,
    arena: std.mem.Allocator,
    browser: bool,
) !?db.SessionUser {
    var cookies = req.cookies();
    if (cookies.get(util.session_cookie_name)) |sid| {
        const conn = try app.pool.acquire(app.io);
        defer conn.release(app.io);
        if (try db.sessionUser(conn, arena, sid)) |user| {
            return user;
        }
    }

    if (!browser) {
        if (req.header("authorization")) |auth| {
            if (try util.parseBasicAuth(arena, auth)) |creds| {
                const conn = try app.pool.acquire(app.io);
                defer conn.release(app.io);
                if (try db.findUserByUsername(conn, arena, creds.username)) |found| {
                    if (found.enabled and try password.verify(arena, app.io, found.password_hash, creds.password)) {
                        // Stateless for this request; no cookie required for API clients.
                        return .{
                            .session_id = "",
                            .user_id = found.id,
                            .username = found.username,
                        };
                    }
                }
            }
        }
        res.status = 401;
        res.header("WWW-Authenticate", "Basic realm=\"authum\"");
        res.body = "unauthorized";
        return null;
    }

    // Browser: redirect to login.
    const host_hdr = req.header("x-forwarded-host") orelse {
        res.status = 401;
        res.body = "unauthorized";
        return null;
    };
    const uri = req.header("x-forwarded-uri") orelse "/";
    const host = util.hostWithoutPort(host_hdr);
    const parsed = util.splitPathQuery(uri);
    const method = req.header("x-forwarded-method") orelse @tagName(req.method);
    const site = (try app.sites.byHost(app.io, arena, host)) orelse {
        try respondForbidden(app, req, res, arena, true, .{
            .reason = "unknown site",
            .host = host,
            .path = parsed.path,
            .method = method,
            .site_name = "—",
            .site_id = "—",
            .user = null,
        });
        return null;
    };
    const from_path = try util.urlEncode(arena, parsed.path);
    const loc = try std.fmt.allocPrint(
        arena,
        "{s}://{s}/login?from_site={d}&from_path={s}",
        .{ util.schemeFromProto(req.header("x-forwarded-proto")), app.config.domain, site.id, from_path },
    );
    res.status = 302;
    res.header("Location", loc);
    res.body = "redirecting to login";
    return null;
}

const ForbiddenCtx = struct {
    reason: []const u8,
    host: []const u8,
    path: []const u8,
    method: []const u8,
    site_name: []const u8,
    site_id: []const u8,
    user: ?db.SessionUser,
    acl_rule_id: ?i64 = null,
};

fn respondForbidden(
    app: *App,
    req: *httpz.Request,
    res: *httpz.Response,
    arena: std.mem.Allocator,
    browser: bool,
    ctx: ForbiddenCtx,
) !void {
    log403(app, req, ctx);
    res.status = 403;
    if (!browser) {
        res.body = ctx.reason;
        return;
    }

    const user_name = if (ctx.user) |u| u.username else "—";
    res.content_type = .HTML;
    res.body = try app.templates.renderForbidden(arena, .{
        .reason = ctx.reason,
        .host = ctx.host,
        .path = ctx.path,
        .method = ctx.method,
        .site_name = ctx.site_name,
        .user_name = user_name,
        .admin_href = try std.fmt.allocPrint(
            arena,
            "{s}://{s}/admin",
            .{ util.schemeFromProto(req.header("x-forwarded-proto")), app.config.domain },
        ),
    });
}

fn log403(app: *App, req: *httpz.Request, ctx: ForbiddenCtx) void {
    const ts = util.unixNow(app.io);
    const user_name = if (ctx.user) |u| u.username else "-";
    std.log.warn(
        "[{d}] 403 reason={s} acl_rule_id={?d} host={s} path={s} method={s} user={s} site_name={s} site_id={s} fwd_host={s} fwd_uri={s}",
        .{
            ts,
            ctx.reason,
            ctx.acl_rule_id,
            ctx.host,
            ctx.path,
            ctx.method,
            user_name,
            ctx.site_name,
            ctx.site_id,
            req.header("x-forwarded-host") orelse "-",
            req.header("x-forwarded-uri") orelse "-",
        },
    );
}

fn handleAuthumLogin(
    app: *App,
    req: *httpz.Request,
    res: *httpz.Response,
    arena: std.mem.Allocator,
    host: []const u8,
    query: []const u8,
    scheme: []const u8,
    secure: bool,
) !void {
    _ = req;
    const ticket_id = util.queryGet(query, "ticket") orelse {
        res.status = 400;
        res.body = "missing ticket";
        return;
    };
    const path_q = util.queryGet(query, "path") orelse "/";
    const path = try util.urlDecode(arena, path_q);

    const conn = try app.pool.acquire(app.io);
    defer conn.release(app.io);

    const ticket = (try db.consumeTicket(conn, arena, app.io, ticket_id)) orelse {
        res.status = 401;
        res.body = "invalid ticket";
        return;
    };

    const site = (try app.sites.byId(app.io, arena, ticket.site_id)) orelse {
        res.status = 400;
        res.body = "unknown site";
        return;
    };
    if (!std.mem.eql(u8, site.host, host)) {
        res.status = 400;
        res.body = "site mismatch";
        return;
    }

    // Prefer ticket path; fall back to query path.
    const dest = if (ticket.path.len > 0) ticket.path else path;
    const dest_path = if (std.mem.startsWith(u8, dest, "/")) dest else try std.fmt.allocPrint(arena, "/{s}", .{dest});

    // Absolute Location: Traefik ForwardAuth resolves relative Location against the
    // auth backend (e.g. http://authum:8080/...), not the original site host.
    const loc = try std.fmt.allocPrint(arena, "{s}://{s}{s}", .{ scheme, site.host, dest_path });
    const cookie = try util.setSessionCookie(arena, ticket.session_id, secure);
    res.status = 302;
    res.header("Set-Cookie", cookie);
    res.header("Location", loc);
    res.body = "logged in";
}

fn handleAuthumLogout(
    app: *App,
    req: *httpz.Request,
    res: *httpz.Response,
    arena: std.mem.Allocator,
    secure: bool,
) !void {
    var cookies = req.cookies();
    if (cookies.get(util.session_cookie_name)) |sid| {
        const conn = try app.pool.acquire(app.io);
        defer conn.release(app.io);
        try db.deleteSession(conn, sid);
    }
    res.status = 302;
    res.header("Set-Cookie", util.clearSessionCookie(secure));
    const loc = try std.fmt.allocPrint(arena, "https://{s}/login", .{app.config.domain});
    res.header("Location", loc);
    res.body = "logged out";
}
