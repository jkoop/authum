const std = @import("std");
const httpz = @import("httpz");
const password = @import("password.zig");
const db = @import("db.zig");
const util = @import("util.zig");
const acl_mod = @import("acl.zig");
const app_mod = @import("app.zig");
const App = app_mod.App;

pub fn index(app: *App, req: *httpz.Request, res: *httpz.Response) !void {
    if (try currentUser(app, req, res.arena)) |user| {
        if (std.mem.eql(u8, user.username, app.config.admin_user)) {
            res.status = 302;
            res.header("Location", "/admin");
            return;
        }
        const q = try req.query();
        const msg = q.get("msg") orelse "";
        const err = q.get("error") orelse "";
        res.content_type = .HTML;
        res.body = try app.templates.renderAccount(res.arena, .{
            .username = user.username,
            .user_id = user.user_id,
            .msg = msg,
            .err_msg = err,
            .has_msg = msg.len > 0,
            .has_error = err.len > 0,
        });
        return;
    }
    res.status = 302;
    res.header("Location", "/login");
}

pub fn changePassword(app: *App, req: *httpz.Request, res: *httpz.Response) !void {
    const user = (try currentUser(app, req, res.arena)) orelse {
        res.status = 302;
        res.header("Location", "/login");
        return;
    };

    const form = try req.formData();
    const current = form.get("current_password") orelse "";
    const new_pw = form.get("new_password") orelse "";
    const confirm = form.get("confirm_password") orelse "";

    if (new_pw.len == 0 or !std.mem.eql(u8, new_pw, confirm)) {
        return redirectWith(res, "/?error=", "new passwords do not match");
    }

    const conn = try app.pool.acquire(app.io);
    defer conn.release(app.io);

    const found = (try db.findUserById(conn, res.arena, user.user_id)) orelse {
        return redirectWith(res, "/?error=", "user not found");
    };
    if (!try password.verify(res.arena, app.io, found.password_hash, current)) {
        return redirectWith(res, "/?error=", "current password is wrong");
    }

    try db.updatePassword(conn, res.arena, app.io, user.user_id, new_pw);
    return redirectWith(res, "/?msg=", "password updated");
}

fn redirectWith(res: *httpz.Response, prefix: []const u8, message: []const u8) !void {
    const enc = try util.urlEncode(res.arena, message);
    const loc = try std.fmt.allocPrint(res.arena, "{s}{s}", .{ prefix, enc });
    res.status = 302;
    res.header("Location", loc);
}

pub fn loginGet(app: *App, req: *httpz.Request, res: *httpz.Response) !void {
    const q = try req.query();
    const from_site = q.get("from_site") orelse "";
    const from_path = q.get("from_path") orelse "/";
    const err = q.get("error") orelse "";

    var site_name: []const u8 = from_site;
    if (from_site.len > 0) {
        if (std.fmt.parseInt(i64, from_site, 10)) |site_id| {
            if (try app.sites.byId(app.io, res.arena, site_id)) |site| {
                site_name = site.name;
            }
        } else |_| {}
    }

    const discord_enabled = app.config.discord_client_id != null;
    const discord_href = if (discord_enabled)
        try std.fmt.allocPrint(
            res.arena,
            "/login/discord?from_site={s}&from_path={s}",
            .{ try util.urlEncode(res.arena, from_site), try util.urlEncode(res.arena, from_path) },
        )
    else
        "";

    res.content_type = .HTML;
    res.body = try app.templates.renderLogin(res.arena, .{
        .from_site = from_site,
        .site_name = site_name,
        .from_path = from_path,
        .err_msg = err,
        .has_from_site = from_site.len > 0,
        .has_error = err.len > 0,
        .discord_enabled = discord_enabled,
        .discord_href = discord_href,
    });
}

pub fn loginPost(app: *App, req: *httpz.Request, res: *httpz.Response) !void {
    const form = try req.formData();
    const username = form.get("username") orelse "";
    const plain = form.get("password") orelse "";
    const from_site = form.get("from_site") orelse "";
    const from_path = form.get("from_path") orelse "/";

    const conn = try app.pool.acquire(app.io);
    defer conn.release(app.io);

    const found = (try db.findUserByUsername(conn, res.arena, username)) orelse {
        return redirectLoginError(res, from_site, from_path, "invalid credentials");
    };
    if (!try password.verify(res.arena, app.io, found.password_hash, plain)) {
        return redirectLoginError(res, from_site, from_path, "invalid credentials");
    }
    if (!found.enabled) {
        return redirectLoginError(res, from_site, from_path, "account pending admin approval");
    }

    const session_id = try db.createSession(conn, res.arena, app.io, found.id);
    const secure = isSecureRequest(req);
    const cookie = try util.setSessionCookie(res.arena, session_id, secure);
    res.header("Set-Cookie", cookie);

    if (from_site.len == 0) {
        res.status = 302;
        res.header("Location", if (std.mem.eql(u8, found.username, app.config.admin_user)) "/admin" else "/");
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

pub fn logout(app: *App, req: *httpz.Request, res: *httpz.Response) !void {
    var cookies = req.cookies();
    if (cookies.get(util.session_cookie_name)) |sid| {
        const conn = try app.pool.acquire(app.io);
        defer conn.release(app.io);
        try db.deleteSession(conn, sid);
    }
    res.status = 302;
    res.header("Set-Cookie", util.clearSessionCookie(isSecureRequest(req)));
    res.header("Location", "/login");
}

pub fn adminGet(app: *App, req: *httpz.Request, res: *httpz.Response) !void {
    _ = try requireAdmin(app, req, res) orelse return;

    const conn = try app.pool.acquire(app.io);
    defer conn.release(app.io);
    const users = try db.listUsers(conn, res.arena);

    var rows: std.ArrayList(u8) = .empty;
    defer rows.deinit(res.arena);

    try rows.appendSlice(res.arena,
        \\<table>
        \\<tr><th>ID</th><th>Username</th><th>Password</th><th>Discord ID</th><th>Enabled</th><th></th><th>Delete</th></tr>
    );

    for (users) |u| {
        const is_admin = std.mem.eql(u8, u.username, app.config.admin_user);
        const name_esc = try util.htmlEscape(res.arena, u.username);
        const discord_esc = try util.htmlEscape(res.arena, u.discord_id orelse "");
        const enabled_cell = if (is_admin)
            "yes"
        else if (u.enabled)
            try std.fmt.allocPrint(res.arena,
                \\<form method="POST" action="/admin/users/enabled">
                \\<input type="hidden" name="id" value="{d}">
                \\<input type="hidden" name="enabled" value="0">
                \\<button type="submit" class="secondary">Disable</button>
                \\</form>
            , .{u.id})
        else
            try std.fmt.allocPrint(res.arena,
                \\<form method="POST" action="/admin/users/enabled">
                \\<input type="hidden" name="id" value="{d}">
                \\<input type="hidden" name="enabled" value="1">
                \\<button type="submit">Enable</button>
                \\</form>
            , .{u.id});

        if (is_admin) {
            const row = try std.fmt.allocPrint(res.arena,
                \\<tr>
                \\<form class="row" method="POST" action="/admin/users/update">
                \\<input type="hidden" name="id" value="{d}">
                \\<input type="hidden" name="username" value="{s}">
                \\<td>{d}</td>
                \\<td>{s} <em>(admin)</em></td>
                \\<td><input name="password" type="password" placeholder="new password (optional)"></td>
                \\<td><input name="discord_id" value="{s}" placeholder="discord id"></td>
                \\<td>{s}</td>
                \\<td><button type="submit">Save</button></td>
                \\</form>
                \\<td>—</td>
                \\</tr>
            , .{ u.id, name_esc, u.id, name_esc, discord_esc, enabled_cell });
            try rows.appendSlice(res.arena, row);
        } else {
            const row = try std.fmt.allocPrint(res.arena,
                \\<tr>
                \\<form class="row" method="POST" action="/admin/users/update">
                \\<input type="hidden" name="id" value="{d}">
                \\<td>{d}</td>
                \\<td><input name="username" value="{s}" required></td>
                \\<td><input name="password" type="password" placeholder="new password (optional)"></td>
                \\<td><input name="discord_id" value="{s}" placeholder="discord id"></td>
                \\<td>{s}</td>
                \\<td><button type="submit">Save</button></td>
                \\</form>
                \\<td>
                \\<form method="POST" action="/admin/users/delete" class="inline" onsubmit="return confirm('Delete user?');">
                \\<input type="hidden" name="id" value="{d}">
                \\<button type="submit">Delete</button>
                \\</form>
                \\</td>
                \\</tr>
            , .{ u.id, u.id, name_esc, discord_esc, enabled_cell, u.id });
            try rows.appendSlice(res.arena, row);
        }
    }
    try rows.appendSlice(res.arena,
        \\<tr>
        \\<form class="row" method="POST" action="/admin/users">
        \\<td>+</td>
        \\<td><input name="username" placeholder="username" required></td>
        \\<td><input name="password" type="password" placeholder="password" required></td>
        \\<td></td>
        \\<td></td>
        \\<td><button type="submit">Add</button></td>
        \\<td></td>
        \\</form>
        \\</tr>
        \\</table>
    );

    const groups = try db.listGroups(conn, res.arena);
    var groups_html: std.ArrayList(u8) = .empty;
    defer groups_html.deinit(res.arena);
    try groups_html.appendSlice(res.arena,
        \\<table>
        \\<tr><th>ID</th><th>Name</th><th></th><th>Members</th><th>Delete</th></tr>
    );
    for (groups) |g| {
        const name_esc = try util.htmlEscape(res.arena, g.name);
        const members = try db.listGroupMembers(conn, res.arena, g.id);
        var members_buf: std.ArrayList(u8) = .empty;
        defer members_buf.deinit(res.arena);
        for (members) |m| {
            const mname = try util.htmlEscape(res.arena, m.username);
            const chip = try std.fmt.allocPrint(res.arena,
                \\{s} ({d})
                \\<form method="POST" action="/admin/groups/members/delete" class="inline">
                \\<input type="hidden" name="group_id" value="{d}">
                \\<input type="hidden" name="user_id" value="{d}">
                \\<button type="submit">×</button>
                \\</form>
            , .{ mname, m.user_id, g.id, m.user_id });
            if (members_buf.items.len > 0) try members_buf.appendSlice(res.arena, "<br>");
            try members_buf.appendSlice(res.arena, chip);
        }
        const add_form = try std.fmt.allocPrint(res.arena,
            \\<form method="POST" action="/admin/groups/members" style="margin-top:0.5em">
            \\<input type="hidden" name="group_id" value="{d}">
            \\<input name="username" placeholder="username" required>
            \\<button type="submit">Add</button>
            \\</form>
        , .{g.id});
        const row = try std.fmt.allocPrint(res.arena,
            \\<tr>
            \\<form class="row" method="POST" action="/admin/groups/update">
            \\<input type="hidden" name="id" value="{d}">
            \\<td>{d}</td>
            \\<td><input name="name" value="{s}" required></td>
            \\<td><button type="submit">Save</button></td>
            \\</form>
            \\<td>{s}{s}</td>
            \\<td>
            \\<form method="POST" action="/admin/groups/delete" class="inline" onsubmit="return confirm('Delete group?');">
            \\<input type="hidden" name="id" value="{d}">
            \\<button type="submit">Delete</button>
            \\</form>
            \\</td>
            \\</tr>
        , .{ g.id, g.id, name_esc, members_buf.items, add_form, g.id });
        try groups_html.appendSlice(res.arena, row);
    }
    try groups_html.appendSlice(res.arena,
        \\<tr>
        \\<form class="row" method="POST" action="/admin/groups">
        \\<td>+</td>
        \\<td><input name="name" placeholder="group name" required></td>
        \\<td><button type="submit">Add group</button></td>
        \\<td></td>
        \\<td></td>
        \\</form>
        \\</tr>
        \\</table>
    );

    const sites_html = try buildSitesHtml(app, res.arena);
    const acl_html = try buildAclHtml(app, res.arena, users, groups);

    res.content_type = .HTML;
    res.body = try app.templates.renderAdmin(res.arena, .{
        .acl_table = acl_html,
        .sites_table = sites_html,
        .users_html = rows.items,
        .groups_html = groups_html.items,
    });
}

fn buildSitesHtml(app: *App, arena: std.mem.Allocator) ![]u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(arena);
    try out.appendSlice(arena,
        \\<table>
        \\<tr><th>ID</th><th>Name</th><th>Host</th><th>User-Id header</th><th>User-Name header</th><th></th><th></th></tr>
    );
    app.sites.mutex.lockUncancelable(app.io);
    defer app.sites.mutex.unlock(app.io);
    for (app.sites.sites) |s| {
        const name = try util.htmlEscape(arena, s.name);
        const host = try util.htmlEscape(arena, s.host);
        const uidh = try util.htmlEscape(arena, s.user_id_header);
        const unh = try util.htmlEscape(arena, s.user_name_header);
        const row = try std.fmt.allocPrint(arena,
            \\<tr>
            \\<form class="row" method="POST" action="/admin/sites/update">
            \\<input type="hidden" name="id" value="{d}">
            \\<td>{d}</td>
            \\<td><input name="name" value="{s}" placeholder="name" required></td>
            \\<td><input name="host" value="{s}" placeholder="host" required></td>
            \\<td><input name="user_id_header" value="{s}" placeholder="user_id_header" required></td>
            \\<td><input name="user_name_header" value="{s}" placeholder="user_name_header" required></td>
            \\<td><button type="submit">Save</button></td>
            \\</form>
            \\<td>
            \\<form method="POST" action="/admin/sites/delete" class="inline" onsubmit="return confirm('Delete site? Site-scoped ACL rules are removed.');">
            \\<input type="hidden" name="id" value="{d}">
            \\<button type="submit">Delete</button>
            \\</form>
            \\</td>
            \\</tr>
        , .{ s.id, s.id, name, host, uidh, unh, s.id });
        try out.appendSlice(arena, row);
    }
    try out.appendSlice(arena,
        \\<tr>
        \\<form class="row" method="POST" action="/admin/sites">
        \\<td>+</td>
        \\<td><input name="name" placeholder="name" required></td>
        \\<td><input name="host" placeholder="host" required></td>
        \\<td><input name="user_id_header" placeholder="user_id_header" value="Remote-User-Id" required></td>
        \\<td><input name="user_name_header" placeholder="user_name_header" value="Remote-User-Name" required></td>
        \\<td><button type="submit">Add site</button></td>
        \\<td></td>
        \\</form>
        \\</tr>
        \\</table>
    );
    return try out.toOwnedSlice(arena);
}

const AclSiteOpt = struct {
    id: i64,
    label: []const u8, // already html-escaped "name (host)"
};

fn buildSubjectSelect(arena: std.mem.Allocator, users: []const db.User, groups: []const db.Group, selected: ?acl_mod.Subject) ![]u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(arena);
    try out.appendSlice(arena, "<select name=\"user\" required>");
    const any_sel = if (selected) |s| (s == .any) else true;
    try out.appendSlice(arena, try std.fmt.allocPrint(arena,
        \\<option value="*"{s}>* anyone</option>
    , .{if (any_sel) " selected" else ""}));
    for (users) |u| {
        const name = try util.htmlEscape(arena, u.username);
        const sel = if (selected) |s| switch (s) {
            .user_id => |id| id == u.id,
            else => false,
        } else false;
        try out.appendSlice(arena, try std.fmt.allocPrint(arena,
            \\<option value="#{d}"{s}>#{d} {s}</option>
        , .{ u.id, if (sel) " selected" else "", u.id, name }));
    }
    for (groups) |g| {
        const name = try util.htmlEscape(arena, g.name);
        const sel = if (selected) |s| switch (s) {
            .group_id => |id| id == g.id,
            else => false,
        } else false;
        try out.appendSlice(arena, try std.fmt.allocPrint(arena,
            \\<option value="@{d}"{s}>@{d} {s}</option>
        , .{ g.id, if (sel) " selected" else "", g.id, name }));
    }
    try out.appendSlice(arena, "</select>");
    return try out.toOwnedSlice(arena);
}

fn buildSiteSelect(arena: std.mem.Allocator, sites: []const AclSiteOpt, selected: ?i64) ![]u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(arena);
    try out.appendSlice(arena, "<select name=\"site_id\" required>");
    try out.appendSlice(arena, try std.fmt.allocPrint(arena,
        \\<option value="*"{s}>* any site</option>
    , .{if (selected == null) " selected" else ""}));
    for (sites) |s| {
        const sel = if (selected) |sid| sid == s.id else false;
        try out.appendSlice(arena, try std.fmt.allocPrint(arena,
            \\<option value="{d}"{s}>{d} {s}</option>
        , .{ s.id, if (sel) " selected" else "", s.id, s.label }));
    }
    try out.appendSlice(arena, "</select>");
    return try out.toOwnedSlice(arena);
}

fn buildAclHtml(app: *App, arena: std.mem.Allocator, users: []const db.User, groups: []const db.Group) ![]u8 {
    var site_opts: std.ArrayList(AclSiteOpt) = .empty;
    errdefer site_opts.deinit(arena);
    {
        app.sites.mutex.lockUncancelable(app.io);
        defer app.sites.mutex.unlock(app.io);
        for (app.sites.sites) |s| {
            const name = try util.htmlEscape(arena, s.name);
            const host = try util.htmlEscape(arena, s.host);
            const label = try std.fmt.allocPrint(arena, "{s} ({s})", .{ name, host });
            try site_opts.append(arena, .{ .id = s.id, .label = label });
        }
    }

    const RuleSnap = struct {
        id: i64,
        subject: acl_mod.Subject,
        site_id: ?i64,
        path: []const u8,
        method: []const u8,
        effect: acl_mod.Effect,
    };
    var snaps: std.ArrayList(RuleSnap) = .empty;
    errdefer snaps.deinit(arena);
    {
        app.acl.mutex.lockUncancelable(app.io);
        defer app.acl.mutex.unlock(app.io);
        for (app.acl.rules) |rule| {
            try snaps.append(arena, .{
                .id = rule.id,
                .subject = rule.subject,
                .site_id = rule.site_id,
                .path = try util.htmlEscape(arena, rule.path_pattern),
                .method = try util.htmlEscape(arena, rule.method),
                .effect = rule.effect,
            });
        }
    }

    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(arena);
    try out.appendSlice(arena,
        \\<table>
        \\<tr><th></th><th>User</th><th>Site</th><th>Path</th><th>Method</th><th>Effect</th><th></th><th></th></tr>
    );
    for (snaps.items) |rule| {
        const user_sel = try buildSubjectSelect(arena, users, groups, rule.subject);
        const site_sel = try buildSiteSelect(arena, site_opts.items, rule.site_id);
        const effect = @tagName(rule.effect);
        const row = try std.fmt.allocPrint(arena,
            \\<tr>
            \\<td>
            \\<form method="POST" action="/admin/acl/move" class="inline">
            \\<input type="hidden" name="id" value="{d}">
            \\<input type="hidden" name="dir" value="up">
            \\<button type="submit" title="Move up">↑</button>
            \\</form>
            \\<form method="POST" action="/admin/acl/move" class="inline">
            \\<input type="hidden" name="id" value="{d}">
            \\<input type="hidden" name="dir" value="down">
            \\<button type="submit" title="Move down">↓</button>
            \\</form>
            \\</td>
            \\<form class="row" method="POST" action="/admin/acl/update">
            \\<input type="hidden" name="id" value="{d}">
            \\<td>{s}</td>
            \\<td>{s}</td>
            \\<td><input name="path" value="{s}" placeholder="path regex" required></td>
            \\<td><input name="method" value="{s}" placeholder="GET,OPTIONS,*" required></td>
            \\<td>
            \\<select name="effect">
            \\<option value="allow"{s}>allow</option>
            \\<option value="deny"{s}>deny</option>
            \\</select>
            \\</td>
            \\<td><button type="submit">Save</button></td>
            \\</form>
            \\<td>
            \\<form method="POST" action="/admin/acl/delete" class="inline" onsubmit="return confirm('Delete rule?');">
            \\<input type="hidden" name="id" value="{d}">
            \\<button type="submit">Delete</button>
            \\</form>
            \\</td>
            \\</tr>
        , .{
            rule.id,
            rule.id,
            rule.id,
            user_sel,
            site_sel,
            rule.path,
            rule.method,
            if (effect[0] == 'a') " selected" else "",
            if (effect[0] == 'd') " selected" else "",
            rule.id,
        });
        try out.appendSlice(arena, row);
    }
    const blank_user = try buildSubjectSelect(arena, users, groups, null);
    const blank_site = try buildSiteSelect(arena, site_opts.items, null);
    try out.appendSlice(arena, try std.fmt.allocPrint(arena,
        \\<tr>
        \\<form class="row" method="POST" action="/admin/acl">
        \\<td>+</td>
        \\<td>{s}</td>
        \\<td>{s}</td>
        \\<td><input name="path" placeholder="^/" required></td>
        \\<td><input name="method" placeholder="GET,OPTIONS,*" value="*" required></td>
        \\<td><select name="effect"><option value="allow">allow</option><option value="deny">deny</option></select></td>
        \\<td><button type="submit">Add rule</button></td>
        \\<td></td>
        \\</form>
        \\</tr>
        \\</table>
    , .{ blank_user, blank_site }));
    return try out.toOwnedSlice(arena);
}

fn parseAclForm(form: anytype, arena: std.mem.Allocator) !struct {
    subject: acl_mod.Subject,
    site_id: ?i64,
    path: []const u8,
    method: []const u8,
    effect: acl_mod.Effect,
} {
    const user = form.get("user") orelse "";
    const site_col = form.get("site_id") orelse "";
    const path = form.get("path") orelse "";
    const method = form.get("method") orelse "";
    const effect_col = form.get("effect") orelse "";

    const subject = acl_mod.parseSubject(user) catch {
        return error.BadSubject;
    };
    if (path.len == 0 or method.len == 0) return error.BadFields;
    const site_id: ?i64 = if (std.mem.eql(u8, site_col, "*"))
        null
    else
        std.fmt.parseInt(i64, site_col, 10) catch return error.BadSite;
    const effect: acl_mod.Effect = if (std.mem.eql(u8, effect_col, "allow"))
        .allow
    else if (std.mem.eql(u8, effect_col, "deny"))
        .deny
    else
        return error.BadEffect;

    // Validate regex
    var re = @import("regex").compile(arena, path) catch return error.BadRegex;
    re.deinit();

    return .{
        .subject = subject,
        .site_id = site_id,
        .path = path,
        .method = method,
        .effect = effect,
    };
}

pub fn aclCreate(app: *App, req: *httpz.Request, res: *httpz.Response) !void {
    _ = try requireAdmin(app, req, res) orelse return;
    const form = try req.formData();
    const fields = parseAclForm(form, res.arena) catch {
        res.status = 400;
        res.body = "invalid ACL fields (user: *|#id|@id; site: *|id; path regex; method; allow|deny)";
        return;
    };
    const conn = try app.pool.acquire(app.io);
    defer conn.release(app.io);
    _ = db.createAclRule(conn, fields.subject, fields.site_id, fields.path, fields.method, fields.effect) catch |err| {
        if (err == error.ConstraintForeignKey) {
            res.status = 400;
            res.body = "unknown user, group, or site id";
            return;
        }
        return err;
    };
    try app_mod.reloadAcl(app, conn);
    res.status = 302;
    res.header("Location", "/admin");
}

pub fn aclUpdate(app: *App, req: *httpz.Request, res: *httpz.Response) !void {
    _ = try requireAdmin(app, req, res) orelse return;
    const form = try req.formData();
    const id = std.fmt.parseInt(i64, form.get("id") orelse "", 10) catch {
        res.status = 400;
        res.body = "invalid id";
        return;
    };
    const fields = parseAclForm(form, res.arena) catch {
        res.status = 400;
        res.body = "invalid ACL fields";
        return;
    };
    const conn = try app.pool.acquire(app.io);
    defer conn.release(app.io);
    db.updateAclRule(conn, id, fields.subject, fields.site_id, fields.path, fields.method, fields.effect) catch |err| {
        if (err == error.ConstraintForeignKey) {
            res.status = 400;
            res.body = "unknown user, group, or site id";
            return;
        }
        return err;
    };
    try app_mod.reloadAcl(app, conn);
    res.status = 302;
    res.header("Location", "/admin");
}

pub fn aclDelete(app: *App, req: *httpz.Request, res: *httpz.Response) !void {
    _ = try requireAdmin(app, req, res) orelse return;
    const form = try req.formData();
    const id = std.fmt.parseInt(i64, form.get("id") orelse "", 10) catch {
        res.status = 400;
        res.body = "invalid id";
        return;
    };
    const conn = try app.pool.acquire(app.io);
    defer conn.release(app.io);
    try db.deleteAclRule(conn, id);
    try app_mod.reloadAcl(app, conn);
    res.status = 302;
    res.header("Location", "/admin");
}

pub fn aclMove(app: *App, req: *httpz.Request, res: *httpz.Response) !void {
    _ = try requireAdmin(app, req, res) orelse return;
    const form = try req.formData();
    const id = std.fmt.parseInt(i64, form.get("id") orelse "", 10) catch {
        res.status = 400;
        res.body = "invalid id";
        return;
    };
    const dir_str = form.get("dir") orelse "";
    const dir: db.AclMoveDir = if (std.mem.eql(u8, dir_str, "up"))
        .up
    else if (std.mem.eql(u8, dir_str, "down"))
        .down
    else {
        res.status = 400;
        res.body = "invalid dir";
        return;
    };
    const conn = try app.pool.acquire(app.io);
    defer conn.release(app.io);
    try db.moveAclRule(conn, id, dir);
    try app_mod.reloadAcl(app, conn);
    res.status = 302;
    res.header("Location", "/admin");
}

pub fn sitesCreate(app: *App, req: *httpz.Request, res: *httpz.Response) !void {
    _ = try requireAdmin(app, req, res) orelse return;
    const form = try req.formData();
    const name = form.get("name") orelse "";
    const host = form.get("host") orelse "";
    const user_id_header = form.get("user_id_header") orelse "";
    const user_name_header = form.get("user_name_header") orelse "";
    if (name.len == 0 or host.len == 0 or user_id_header.len == 0 or user_name_header.len == 0) {
        res.status = 400;
        res.body = "all site fields required";
        return;
    }
    const conn = try app.pool.acquire(app.io);
    defer conn.release(app.io);
    _ = db.createSite(conn, name, host, user_id_header, user_name_header) catch |err| {
        if (err == error.ConstraintUnique) {
            res.status = 400;
            res.body = "site name or host already exists";
            return;
        }
        return err;
    };
    try app_mod.reloadSites(app, conn);
    res.status = 302;
    res.header("Location", "/admin");
}

pub fn sitesUpdate(app: *App, req: *httpz.Request, res: *httpz.Response) !void {
    _ = try requireAdmin(app, req, res) orelse return;
    const form = try req.formData();
    const id = std.fmt.parseInt(i64, form.get("id") orelse "", 10) catch {
        res.status = 400;
        res.body = "invalid id";
        return;
    };
    const name = form.get("name") orelse "";
    const host = form.get("host") orelse "";
    const user_id_header = form.get("user_id_header") orelse "";
    const user_name_header = form.get("user_name_header") orelse "";
    if (name.len == 0 or host.len == 0 or user_id_header.len == 0 or user_name_header.len == 0) {
        res.status = 400;
        res.body = "all site fields required";
        return;
    }
    const conn = try app.pool.acquire(app.io);
    defer conn.release(app.io);
    db.updateSite(conn, id, name, host, user_id_header, user_name_header) catch |err| {
        if (err == error.ConstraintUnique) {
            res.status = 400;
            res.body = "site name or host already exists";
            return;
        }
        return err;
    };
    try app_mod.reloadSites(app, conn);
    res.status = 302;
    res.header("Location", "/admin");
}

pub fn sitesDelete(app: *App, req: *httpz.Request, res: *httpz.Response) !void {
    _ = try requireAdmin(app, req, res) orelse return;
    const form = try req.formData();
    const id = std.fmt.parseInt(i64, form.get("id") orelse "", 10) catch {
        res.status = 400;
        res.body = "invalid id";
        return;
    };
    const conn = try app.pool.acquire(app.io);
    defer conn.release(app.io);
    try db.deleteSite(conn, id);
    try app_mod.reloadSites(app, conn);
    try app_mod.reloadAcl(app, conn);
    res.status = 302;
    res.header("Location", "/admin");
}

pub fn usersCreate(app: *App, req: *httpz.Request, res: *httpz.Response) !void {
    _ = try requireAdmin(app, req, res) orelse return;
    const form = try req.formData();
    const username = form.get("username") orelse "";
    const plain = form.get("password") orelse "";
    if (username.len == 0 or plain.len == 0) {
        res.status = 400;
        res.body = "username and password required";
        return;
    }
    if (!util.validUsername(username)) {
        res.status = 400;
        res.body = "username may only contain letters, numbers, and underscores";
        return;
    }
    const conn = try app.pool.acquire(app.io);
    defer conn.release(app.io);
    _ = db.createUser(conn, res.arena, app.io, username, plain) catch |err| {
        if (err == error.ConstraintUnique) {
            res.status = 400;
            res.body = "username already exists";
            return;
        }
        return err;
    };
    res.status = 302;
    res.header("Location", "/admin");
}

pub fn usersUpdate(app: *App, req: *httpz.Request, res: *httpz.Response) !void {
    _ = try requireAdmin(app, req, res) orelse return;
    const form = try req.formData();
    const id_str = form.get("id") orelse "";
    const username = form.get("username") orelse "";
    const plain = form.get("password") orelse "";
    const discord_id = form.get("discord_id") orelse "";
    const id = std.fmt.parseInt(i64, id_str, 10) catch {
        res.status = 400;
        res.body = "invalid id";
        return;
    };
    if (username.len == 0) {
        res.status = 400;
        res.body = "username required";
        return;
    }
    if (!util.validUsername(username)) {
        res.status = 400;
        res.body = "username may only contain letters, numbers, and underscores";
        return;
    }

    const conn = try app.pool.acquire(app.io);
    defer conn.release(app.io);

    const existing = (try db.findUserById(conn, res.arena, id)) orelse {
        res.status = 404;
        res.body = "user not found";
        return;
    };

    if (std.mem.eql(u8, existing.username, app.config.admin_user) and
        !std.mem.eql(u8, username, app.config.admin_user))
    {
        res.status = 400;
        res.body = "cannot rename admin user";
        return;
    }

    db.updateUsername(conn, id, username) catch |err| {
        if (err == error.ConstraintUnique) {
            res.status = 400;
            res.body = "username already exists";
            return;
        }
        return err;
    };

    if (plain.len > 0) {
        try db.updatePassword(conn, res.arena, app.io, id, plain);
    }

    db.setUserDiscordId(conn, id, if (discord_id.len == 0) null else discord_id) catch |err| {
        if (err == error.ConstraintUnique) {
            res.status = 400;
            res.body = "discord id already linked to another user";
            return;
        }
        return err;
    };

    res.status = 302;
    res.header("Location", "/admin");
}

pub fn usersDelete(app: *App, req: *httpz.Request, res: *httpz.Response) !void {
    _ = try requireAdmin(app, req, res) orelse return;
    const form = try req.formData();
    const id_str = form.get("id") orelse "";
    const id = std.fmt.parseInt(i64, id_str, 10) catch {
        res.status = 400;
        res.body = "invalid id";
        return;
    };

    const conn = try app.pool.acquire(app.io);
    defer conn.release(app.io);

    const existing = (try db.findUserById(conn, res.arena, id)) orelse {
        res.status = 404;
        res.body = "user not found";
        return;
    };
    if (std.mem.eql(u8, existing.username, app.config.admin_user)) {
        res.status = 400;
        res.body = "cannot delete admin user";
        return;
    }

    try db.deleteUser(conn, id);
    res.status = 302;
    res.header("Location", "/admin");
}

pub fn usersSetEnabled(app: *App, req: *httpz.Request, res: *httpz.Response) !void {
    _ = try requireAdmin(app, req, res) orelse return;
    const form = try req.formData();
    const id_str = form.get("id") orelse "";
    const enabled_str = form.get("enabled") orelse "";
    const id = std.fmt.parseInt(i64, id_str, 10) catch {
        res.status = 400;
        res.body = "invalid id";
        return;
    };
    const enabled = std.mem.eql(u8, enabled_str, "1");

    const conn = try app.pool.acquire(app.io);
    defer conn.release(app.io);
    const existing = (try db.findUserById(conn, res.arena, id)) orelse {
        res.status = 404;
        res.body = "user not found";
        return;
    };
    if (std.mem.eql(u8, existing.username, app.config.admin_user) and !enabled) {
        res.status = 400;
        res.body = "cannot disable admin user";
        return;
    }
    try db.setUserEnabled(conn, id, enabled);
    res.status = 302;
    res.header("Location", "/admin");
}

pub fn groupsCreate(app: *App, req: *httpz.Request, res: *httpz.Response) !void {
    _ = try requireAdmin(app, req, res) orelse return;
    const form = try req.formData();
    const name = form.get("name") orelse "";
    if (name.len == 0 or !util.validUsername(name)) {
        res.status = 400;
        res.body = "group name may only contain letters, numbers, and underscores";
        return;
    }
    const conn = try app.pool.acquire(app.io);
    defer conn.release(app.io);
    _ = db.createGroup(conn, name) catch |err| {
        if (err == error.ConstraintUnique) {
            res.status = 400;
            res.body = "group already exists";
            return;
        }
        return err;
    };
    res.status = 302;
    res.header("Location", "/admin");
}

pub fn groupsUpdate(app: *App, req: *httpz.Request, res: *httpz.Response) !void {
    _ = try requireAdmin(app, req, res) orelse return;
    const form = try req.formData();
    const id_str = form.get("id") orelse "";
    const name = form.get("name") orelse "";
    const id = std.fmt.parseInt(i64, id_str, 10) catch {
        res.status = 400;
        res.body = "invalid id";
        return;
    };
    if (name.len == 0 or !util.validUsername(name)) {
        res.status = 400;
        res.body = "group name may only contain letters, numbers, and underscores";
        return;
    }
    const conn = try app.pool.acquire(app.io);
    defer conn.release(app.io);
    if ((try db.findGroupById(conn, res.arena, id)) == null) {
        res.status = 404;
        res.body = "group not found";
        return;
    }
    db.updateGroupName(conn, id, name) catch |err| {
        if (err == error.ConstraintUnique) {
            res.status = 400;
            res.body = "group already exists";
            return;
        }
        return err;
    };
    res.status = 302;
    res.header("Location", "/admin");
}

pub fn groupsDelete(app: *App, req: *httpz.Request, res: *httpz.Response) !void {
    _ = try requireAdmin(app, req, res) orelse return;
    const form = try req.formData();
    const id_str = form.get("id") orelse "";
    const id = std.fmt.parseInt(i64, id_str, 10) catch {
        res.status = 400;
        res.body = "invalid id";
        return;
    };
    const conn = try app.pool.acquire(app.io);
    defer conn.release(app.io);
    try db.deleteGroup(conn, id);
    res.status = 302;
    res.header("Location", "/admin");
}

pub fn groupsMembersAdd(app: *App, req: *httpz.Request, res: *httpz.Response) !void {
    _ = try requireAdmin(app, req, res) orelse return;
    const form = try req.formData();
    const group_id_str = form.get("group_id") orelse "";
    const username = form.get("username") orelse "";
    const group_id = std.fmt.parseInt(i64, group_id_str, 10) catch {
        res.status = 400;
        res.body = "invalid group id";
        return;
    };
    if (username.len == 0) {
        res.status = 400;
        res.body = "username required";
        return;
    }
    const conn = try app.pool.acquire(app.io);
    defer conn.release(app.io);
    if ((try db.findGroupById(conn, res.arena, group_id)) == null) {
        res.status = 404;
        res.body = "group not found";
        return;
    }
    const user = (try db.findUserByUsername(conn, res.arena, username)) orelse {
        res.status = 404;
        res.body = "user not found";
        return;
    };
    db.addGroupMember(conn, group_id, user.id) catch |err| {
        if (err == error.ConstraintPrimaryKey or err == error.ConstraintUnique) {
            res.status = 302;
            res.header("Location", "/admin");
            return;
        }
        return err;
    };
    res.status = 302;
    res.header("Location", "/admin");
}

pub fn groupsMembersDelete(app: *App, req: *httpz.Request, res: *httpz.Response) !void {
    _ = try requireAdmin(app, req, res) orelse return;
    const form = try req.formData();
    const group_id_str = form.get("group_id") orelse "";
    const user_id_str = form.get("user_id") orelse "";
    const group_id = std.fmt.parseInt(i64, group_id_str, 10) catch {
        res.status = 400;
        res.body = "invalid group id";
        return;
    };
    const user_id = std.fmt.parseInt(i64, user_id_str, 10) catch {
        res.status = 400;
        res.body = "invalid user id";
        return;
    };
    const conn = try app.pool.acquire(app.io);
    defer conn.release(app.io);
    try db.removeGroupMember(conn, group_id, user_id);
    res.status = 302;
    res.header("Location", "/admin");
}

fn requireAdmin(app: *App, req: *httpz.Request, res: *httpz.Response) !?db.SessionUser {
    const user = (try currentUser(app, req, res.arena)) orelse {
        res.status = 302;
        res.header("Location", "/login");
        return null;
    };
    if (!std.mem.eql(u8, user.username, app.config.admin_user)) {
        std.log.warn(
            "[{d}] 403 admin-only denied: user={s} path={s}",
            .{ util.unixNow(app.io), user.username, req.url.path },
        );
        res.status = 403;
        res.body = "admin only";
        return null;
    }
    return user;
}

fn currentUser(app: *App, req: *httpz.Request, arena: std.mem.Allocator) !?db.SessionUser {
    var cookies = req.cookies();
    const sid = cookies.get(util.session_cookie_name) orelse return null;
    const conn = try app.pool.acquire(app.io);
    defer conn.release(app.io);
    return try db.sessionUser(conn, arena, sid);
}

fn isSecureRequest(req: *httpz.Request) bool {
    if (req.header("x-forwarded-proto")) |p| {
        return std.ascii.eqlIgnoreCase(p, "https");
    }
    return false;
}
