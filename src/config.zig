const std = @import("std");
const util = @import("util.zig");

pub const Listen = struct {
    host: []const u8,
    port: u16,
};

pub const Config = struct {
    domain: []const u8,
    admin_user: []const u8,
    admin_password: []const u8,
    listen_host: []const u8,
    listen_port: u16,
    db_path: [:0]const u8,
    /// null means LDAP disabled
    ldap_listen: ?Listen,
    ldap_base_dn: []const u8,
    /// null means Discord login disabled
    discord_client_id: ?[]const u8,
    discord_client_secret: ?[]const u8,

    pub fn fromEnv(arena: std.mem.Allocator, environ: *const std.process.Environ.Map) !Config {
        const domain = try required(arena, environ, "AUTHUM_DOMAIN");
        const admin_user = try required(arena, environ, "AUTHUM_ADMIN_USER");
        if (!util.validUsername(admin_user)) {
            std.log.err("AUTHUM_ADMIN_USER must contain only letters, numbers, and underscores", .{});
            return error.InvalidAdminUser;
        }
        const admin_password = try required(arena, environ, "AUTHUM_ADMIN_PASSWORD");
        const db_path = try optionalZ(arena, environ, "AUTHUM_DB_PATH", "authum.db");

        var listen_host: []const u8 = "0.0.0.0";
        var listen_port: u16 = 8080;
        if (environ.get("AUTHUM_LISTEN")) |listen| {
            if (std.mem.lastIndexOfScalar(u8, listen, ':')) |colon| {
                listen_host = try arena.dupe(u8, listen[0..colon]);
                listen_port = try std.fmt.parseInt(u16, listen[colon + 1 ..], 10);
            } else {
                listen_port = try std.fmt.parseInt(u16, listen, 10);
            }
        }

        var ldap_listen: ?Listen = null;
        if (environ.get("AUTHUM_LDAP_LISTEN")) |listen| {
            if (listen.len > 0) {
                if (std.mem.lastIndexOfScalar(u8, listen, ':')) |colon| {
                    ldap_listen = .{
                        .host = try arena.dupe(u8, listen[0..colon]),
                        .port = try std.fmt.parseInt(u16, listen[colon + 1 ..], 10),
                    };
                } else {
                    ldap_listen = .{
                        .host = "0.0.0.0",
                        .port = try std.fmt.parseInt(u16, listen, 10),
                    };
                }
            }
        }

        const ldap_base_dn = if (environ.get("AUTHUM_LDAP_BASE_DN")) |v|
            try arena.dupe(u8, v)
        else
            try arena.dupe(u8, "dc=authum,dc=local");

        var discord_client_id: ?[]const u8 = null;
        var discord_client_secret: ?[]const u8 = null;
        if (environ.get("AUTHUM_DISCORD_CLIENT_ID")) |id| {
            if (id.len > 0) {
                if (environ.get("AUTHUM_DISCORD_CLIENT_SECRET")) |secret| {
                    if (secret.len > 0) {
                        discord_client_id = try arena.dupe(u8, id);
                        discord_client_secret = try arena.dupe(u8, secret);
                    }
                }
            }
        }

        return .{
            .domain = domain,
            .admin_user = admin_user,
            .admin_password = admin_password,
            .listen_host = listen_host,
            .listen_port = listen_port,
            .db_path = db_path,
            .ldap_listen = ldap_listen,
            .ldap_base_dn = ldap_base_dn,
            .discord_client_id = discord_client_id,
            .discord_client_secret = discord_client_secret,
        };
    }
};

fn required(arena: std.mem.Allocator, environ: *const std.process.Environ.Map, key: []const u8) ![]const u8 {
    const value = environ.get(key) orelse {
        std.log.err("missing required environment variable {s}", .{key});
        return error.MissingEnv;
    };
    if (value.len == 0) {
        std.log.err("environment variable {s} is empty", .{key});
        return error.MissingEnv;
    }
    return try arena.dupe(u8, value);
}

fn optionalZ(arena: std.mem.Allocator, environ: *const std.process.Environ.Map, key: []const u8, default_value: []const u8) ![:0]const u8 {
    const value = environ.get(key) orelse default_value;
    return try arena.dupeZ(u8, value);
}
