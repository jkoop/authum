const std = @import("std");
const httpz = @import("httpz");
const zqlite = @import("zqlite");
const config_mod = @import("config.zig");
const acl_mod = @import("acl.zig");
const sites_mod = @import("sites.zig");
const templates_mod = @import("templates.zig");
const db = @import("db.zig");
const verify = @import("verify.zig");
const web = @import("web.zig");
const discord = @import("discord.zig");

pub const App = struct {
    io: std.Io,
    allocator: std.mem.Allocator,
    config: config_mod.Config,
    pool: *zqlite.Pool,
    acl: acl_mod.Acl,
    sites: sites_mod.Sites,
    templates: templates_mod.Templates,

    pub fn deinit(self: *App) void {
        self.templates.deinit();
        self.acl.deinit();
        self.sites.deinit();
        self.pool.deinit();
    }

    pub fn notFound(_: *App, _: *httpz.Request, res: *httpz.Response) !void {
        res.status = 404;
        res.body = "not found";
    }

    pub fn uncaughtError(_: *App, req: *httpz.Request, res: *httpz.Response, err: anyerror) void {
        std.log.err("uncaught error at {s}: {s}", .{ req.url.path, @errorName(err) });
        res.status = 500;
        res.body = "internal server error";
    }
};

pub fn openPool(allocator: std.mem.Allocator, db_path: [:0]const u8) !*zqlite.Pool {
    return try zqlite.Pool.init(allocator, .{
        .size = 4,
        .path = db_path,
        .flags = zqlite.OpenFlags.Create | zqlite.OpenFlags.EXResCode,
        .on_first_connection = db.migrate,
        .on_connection = db.onConnection,
    });
}

pub fn bootstrap(app: *App) !void {
    const conn = try app.pool.acquire(app.io);
    defer conn.release(app.io);

    try db.migrateDocumentsToTables(conn, app.allocator);
    try db.seedAdmin(conn, app.allocator, app.io, app.config.admin_user, app.config.admin_password);
    try reloadSites(app, conn);
    try reloadAcl(app, conn);
}

pub fn reloadSites(app: *App, conn: zqlite.Conn) !void {
    const rows = try db.listSites(conn, app.allocator);
    defer {
        for (rows) |s| {
            app.allocator.free(s.name);
            app.allocator.free(s.host);
            app.allocator.free(s.user_id_header);
            app.allocator.free(s.user_name_header);
        }
        app.allocator.free(rows);
    }
    try app.sites.load(app.io, rows);
}

pub fn reloadAcl(app: *App, conn: zqlite.Conn) !void {
    const rows = try db.listAclRules(conn, app.allocator);
    defer {
        for (rows) |r| {
            app.allocator.free(r.path);
            app.allocator.free(r.method);
        }
        app.allocator.free(rows);
    }
    try app.acl.load(app.io, rows);
}

pub fn registerRoutes(app: *App, router: anytype) void {
    _ = app;
    router.get("/auth/verify", verify.handle, .{});
    router.get("/", web.index, .{});
    router.get("/login", web.loginGet, .{});
    router.post("/login", web.loginPost, .{});
    router.get("/logout", web.logout, .{});
    router.post("/logout", web.logout, .{});
    router.get("/admin", web.adminGet, .{});
    router.post("/admin/acl", web.aclCreate, .{});
    router.post("/admin/acl/update", web.aclUpdate, .{});
    router.post("/admin/acl/delete", web.aclDelete, .{});
    router.post("/admin/acl/move", web.aclMove, .{});
    router.post("/admin/sites", web.sitesCreate, .{});
    router.post("/admin/sites/update", web.sitesUpdate, .{});
    router.post("/admin/sites/delete", web.sitesDelete, .{});
    router.post("/admin/users", web.usersCreate, .{});
    router.post("/admin/users/update", web.usersUpdate, .{});
    router.post("/admin/users/delete", web.usersDelete, .{});
    router.post("/admin/users/enabled", web.usersSetEnabled, .{});
    router.get("/login/discord", discord.loginStart, .{});
    router.get("/login/discord/callback", discord.loginCallback, .{});
    router.post("/admin/groups", web.groupsCreate, .{});
    router.post("/admin/groups/update", web.groupsUpdate, .{});
    router.post("/admin/groups/delete", web.groupsDelete, .{});
    router.post("/admin/groups/members", web.groupsMembersAdd, .{});
    router.post("/admin/groups/members/delete", web.groupsMembersDelete, .{});
    router.post("/password", web.changePassword, .{});
}
