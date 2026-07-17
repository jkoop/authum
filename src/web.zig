const std = @import("std");
const httpz = @import("httpz");
const password = @import("password.zig");
const db = @import("db.zig");
const util = @import("util.zig");
const App = @import("app.zig").App;

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
        const msg_html = if (msg.len > 0)
            try std.fmt.allocPrint(res.arena, "<p style=\"color:green\">{s}</p>", .{try util.htmlEscape(res.arena, msg)})
        else
            "";
        const err_html = if (err.len > 0)
            try std.fmt.allocPrint(res.arena, "<p style=\"color:red\">{s}</p>", .{try util.htmlEscape(res.arena, err)})
        else
            "";

        res.content_type = .HTML;
        res.body = try std.fmt.allocPrint(res.arena,
            \\<!DOCTYPE html><html><head><meta name="viewport" content="width=device-width, initial-scale=1"></head><body>
            \\<p>Logged in as {s} (id {d}).</p>
            \\{s}{s}
            \\<h2>Change password</h2>
            \\<form method="POST" action="/password">
            \\<p>Current password: <input name="current_password" type="password" required autocomplete="current-password"></p>
            \\<p>New password: <input name="new_password" type="password" required autocomplete="new-password"></p>
            \\<p>Confirm new password: <input name="confirm_password" type="password" required autocomplete="new-password"></p>
            \\<p><button type="submit">Change password</button></p>
            \\</form>
            \\<p><a href="/logout">Log out</a></p>
            \\</body></html>
        , .{ user.username, user.user_id, msg_html, err_html });
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
    _ = app;
    const q = try req.query();
    const from_site = q.get("from_site") orelse "";
    const from_path = q.get("from_path") orelse "/";
    const err = q.get("error") orelse "";
    const site_esc = try util.htmlEscape(res.arena, from_site);
    const path_esc = try util.htmlEscape(res.arena, from_path);
    const err_html = if (err.len > 0)
        try std.fmt.allocPrint(res.arena, "<p style=\"color:red\">{s}</p>", .{try util.htmlEscape(res.arena, err)})
    else
        "";

    res.content_type = .HTML;
    res.body = try std.fmt.allocPrint(res.arena,
        \\<!DOCTYPE html><html><head><meta name="viewport" content="width=device-width, initial-scale=1"><title>Login</title></head><body>
        \\<h1>Login</h1>
        \\{s}
        \\<form method="POST" action="/login" autocomplete="on">
        \\<input type="hidden" name="from_site" value="{s}">
        \\<input type="hidden" name="from_path" value="{s}">
        \\<p>Username: <input name="username" autocomplete="username" required></p>
        \\<p>Password: <input name="password" type="password" autocomplete="current-password" required></p>
        \\<p><button type="submit">Log in</button></p>
        \\</form>
        \\</body></html>
    , .{ err_html, site_esc, path_esc });
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

    const session_id = try db.createSession(conn, res.arena, app.io, found.id);
    const secure = isSecureRequest(req);
    const cookie = try util.setSessionCookie(res.arena, session_id, secure);
    res.header("Set-Cookie", cookie);

    if (from_site.len == 0) {
        res.status = 302;
        res.header("Location", if (std.mem.eql(u8, found.username, app.config.admin_user)) "/admin" else "/");
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
        \\<table border="1" cellpadding="4">
        \\<tr><th>ID</th><th>Username / Password</th><th>Delete</th></tr>
    );

    for (users) |u| {
        const is_admin = std.mem.eql(u8, u.username, app.config.admin_user);
        const name_esc = try util.htmlEscape(res.arena, u.username);
        if (is_admin) {
            const row = try std.fmt.allocPrint(res.arena,
                \\<tr>
                \\<td>{d}</td>
                \\<td>
                \\<form method="POST" action="/admin/users/update" style="display:inline">
                \\<input type="hidden" name="id" value="{d}">
                \\<input type="hidden" name="username" value="{s}">
                \\{s} <em>(admin)</em>
                \\<input name="password" type="password" placeholder="new password (optional)">
                \\<button type="submit">Save</button>
                \\</form>
                \\</td>
                \\<td>—</td>
                \\</tr>
            , .{ u.id, u.id, name_esc, name_esc });
            try rows.appendSlice(res.arena, row);
        } else {
            const row = try std.fmt.allocPrint(res.arena,
                \\<tr>
                \\<td>{d}</td>
                \\<td>
                \\<form method="POST" action="/admin/users/update" style="display:inline">
                \\<input type="hidden" name="id" value="{d}">
                \\<input name="username" value="{s}" required>
                \\<input name="password" type="password" placeholder="new password (optional)">
                \\<button type="submit">Save</button>
                \\</form>
                \\</td>
                \\<td>
                \\<form method="POST" action="/admin/users/delete" style="display:inline" onsubmit="return confirm('Delete user?');">
                \\<input type="hidden" name="id" value="{d}">
                \\<button type="submit">Delete</button>
                \\</form>
                \\</td>
                \\</tr>
            , .{ u.id, u.id, name_esc, u.id });
            try rows.appendSlice(res.arena, row);
        }
    }
    try rows.appendSlice(res.arena,
        \\<tr>
        \\<td>+</td>
        \\<td>
        \\<form method="POST" action="/admin/users" style="display:inline">
        \\<input name="username" placeholder="username" required>
        \\<input name="password" type="password" placeholder="password" required>
        \\<button type="submit">Add</button>
        \\</form>
        \\</td>
        \\<td></td>
        \\</tr>
        \\</table>
    );

    const acl_table = try app.acl.htmlTable(app.io, res.arena);
    const sites_table = try app.sites.htmlTable(app.io, res.arena);

    res.content_type = .HTML;
    res.body = try std.fmt.allocPrint(res.arena,
        \\<!DOCTYPE html><html><head><meta name="viewport" content="width=device-width, initial-scale=1"><title>Admin</title></head><body>
        \\<h1>Authum Admin</h1>
        \\<p><a href="/logout">Log out</a></p>
        \\
        \\<h2>ACL</h2>
        \\{s}
        \\<p><a href="/admin/acl.tsv">Download ACL</a></p>
        \\<form method="POST" action="/admin/acl" enctype="multipart/form-data">
        \\<input type="file" name="file" accept=".tsv,text/tab-separated-values,text/plain" required>
        \\<button type="submit">Upload ACL</button>
        \\</form>
        \\
        \\<h2>Sites</h2>
        \\{s}
        \\<p><a href="/admin/sites.tsv">Download Sites</a></p>
        \\<form method="POST" action="/admin/sites" enctype="multipart/form-data">
        \\<input type="file" name="file" accept=".tsv,text/tab-separated-values,text/plain" required>
        \\<button type="submit">Upload Sites</button>
        \\</form>
        \\
        \\<h2>Users</h2>
        \\{s}
        \\</body></html>
    , .{ acl_table, sites_table, rows.items });
}

pub fn aclDownload(app: *App, req: *httpz.Request, res: *httpz.Response) !void {
    _ = try requireAdmin(app, req, res) orelse return;
    const body = try app.acl.snapshotSource(app.io, res.arena);
    res.header("Content-Type", "text/tab-separated-values; charset=utf-8");
    res.header("Content-Disposition", "attachment; filename=\"acl.tsv\"");
    res.body = body;
}

pub fn aclUpload(app: *App, req: *httpz.Request, res: *httpz.Response) !void {
    _ = try requireAdmin(app, req, res) orelse return;
    const body = try readUploadFile(req) orelse {
        res.status = 400;
        res.body = "missing file";
        return;
    };
    switch (try app.acl.loadTsv(app.io, body, res.arena)) {
        .ok => {},
        .invalid => |msg| {
            res.status = 400;
            res.content_type = .HTML;
            res.body = try std.fmt.allocPrint(res.arena,
                \\<!DOCTYPE html><html><head><meta name="viewport" content="width=device-width, initial-scale=1"></head><body>
                \\<p style="color:red">{s}</p>
                \\<p><a href="/admin">Back</a></p>
                \\</body></html>
            , .{try util.htmlEscape(res.arena, msg)});
            return;
        },
    }
    const conn = try app.pool.acquire(app.io);
    defer conn.release(app.io);
    try db.saveAclDocument(conn, body);
    res.status = 302;
    res.header("Location", "/admin");
}

pub fn sitesDownload(app: *App, req: *httpz.Request, res: *httpz.Response) !void {
    _ = try requireAdmin(app, req, res) orelse return;
    const body = try app.sites.snapshotSource(app.io, res.arena);
    res.header("Content-Type", "text/tab-separated-values; charset=utf-8");
    res.header("Content-Disposition", "attachment; filename=\"sites.tsv\"");
    res.body = body;
}

pub fn sitesUpload(app: *App, req: *httpz.Request, res: *httpz.Response) !void {
    _ = try requireAdmin(app, req, res) orelse return;
    const body = try readUploadFile(req) orelse {
        res.status = 400;
        res.body = "missing file";
        return;
    };
    switch (try app.sites.loadTsv(app.io, body, res.arena)) {
        .ok => {},
        .invalid => |msg| {
            res.status = 400;
            res.content_type = .HTML;
            res.body = try std.fmt.allocPrint(res.arena,
                \\<!DOCTYPE html><html><head><meta name="viewport" content="width=device-width, initial-scale=1"></head><body>
                \\<p style="color:red">{s}</p>
                \\<p><a href="/admin">Back</a></p>
                \\</body></html>
            , .{try util.htmlEscape(res.arena, msg)});
            return;
        },
    }
    const conn = try app.pool.acquire(app.io);
    defer conn.release(app.io);
    try db.saveSitesDocument(conn, body);
    res.status = 302;
    res.header("Location", "/admin");
}

fn readUploadFile(req: *httpz.Request) !?[]const u8 {
    const form = try req.multiFormData();
    const field = form.get("file") orelse return null;
    if (field.value.len == 0) return null;
    return field.value;
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

fn requireAdmin(app: *App, req: *httpz.Request, res: *httpz.Response) !?db.SessionUser {
    const user = (try currentUser(app, req, res.arena)) orelse {
        res.status = 302;
        res.header("Location", "/login");
        return null;
    };
    if (!std.mem.eql(u8, user.username, app.config.admin_user)) {
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
