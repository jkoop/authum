const std = @import("std");
const httpz = @import("httpz");
const config_mod = @import("config.zig");
const app_mod = @import("app.zig");
const acl_mod = @import("acl.zig");
const sites_mod = @import("sites.zig");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const io = init.io;
    const arena = init.arena.allocator();

    const cfg = try config_mod.Config.fromEnv(arena, init.environ_map);

    var app = app_mod.App{
        .io = io,
        .allocator = allocator,
        .config = cfg,
        .pool = undefined,
        .acl = acl_mod.Acl.init(allocator),
        .sites = sites_mod.Sites.init(allocator),
    };
    app.pool = try app_mod.openPool(allocator, cfg.db_path);
    defer app.deinit();

    try app_mod.bootstrap(&app);

    const address = try parseAddress(cfg.listen_host, cfg.listen_port);
    var server = try httpz.Server(*app_mod.App).init(io, allocator, .{
        .address = address,
        .request = .{
            .max_form_count = 32,
            .max_query_count = 32,
            .max_header_count = 64,
            .max_multiform_count = 8,
        },
    }, &app);
    defer {
        server.stop();
        server.deinit();
    }

    const router = try server.router(.{});
    app_mod.registerRoutes(&app, router);

    std.log.info("authum listening on {s}:{d} (domain {s})", .{ cfg.listen_host, cfg.listen_port, cfg.domain });
    try server.listen();
}

fn parseAddress(host: []const u8, port: u16) !httpz.Config.Address {
    if (std.mem.eql(u8, host, "0.0.0.0") or std.mem.eql(u8, host, "*")) {
        return .all(port);
    }
    if (std.mem.eql(u8, host, "127.0.0.1") or std.mem.eql(u8, host, "localhost")) {
        return .localhost(port);
    }
    var parts: [4]u8 = undefined;
    var it = std.mem.splitScalar(u8, host, '.');
    var i: usize = 0;
    while (it.next()) |part| : (i += 1) {
        if (i >= 4) return error.InvalidListenHost;
        parts[i] = try std.fmt.parseInt(u8, part, 10);
    }
    if (i != 4) return error.InvalidListenHost;
    return .{ .ip = .{ .ip4 = .{ .bytes = parts, .port = port } } };
}

test {
    _ = @import("util.zig");
    _ = @import("acl.zig");
    _ = @import("sites.zig");
}
