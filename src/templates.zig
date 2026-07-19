const std = @import("std");
const ztl = @import("ztl");

pub const ZtlApp = struct {
    pub const ZtlConfig = struct {
        pub const escape_by_default: bool = true;
    };

    pub fn partial(self: @This(), _: std.mem.Allocator, _: []const u8, include_key: []const u8) !?ztl.PartialResult {
        _ = self;
        if (std.mem.eql(u8, include_key, "styles")) {
            return .{ .src = @embedFile("views/styles.ztl") };
        }
        return null;
    }
};

pub const Templates = struct {
    app: ZtlApp = .{},
    login: ztl.Template(ZtlApp),
    account: ztl.Template(ZtlApp),
    admin: ztl.Template(ZtlApp),
    pending: ztl.Template(ZtlApp),
    forbidden: ztl.Template(ZtlApp),

    pub fn init(allocator: std.mem.Allocator) !Templates {
        var self: Templates = .{
            .login = ztl.Template(ZtlApp).init(allocator, .{}),
            .account = ztl.Template(ZtlApp).init(allocator, .{}),
            .admin = ztl.Template(ZtlApp).init(allocator, .{}),
            .pending = ztl.Template(ZtlApp).init(allocator, .{}),
            .forbidden = ztl.Template(ZtlApp).init(allocator, .{}),
        };
        errdefer self.deinit();

        var report = ztl.CompileErrorReport{};
        self.login.compile(@embedFile("views/login.ztl"), .{ .error_report = &report }) catch {
            std.log.err("login template: {s}", .{report.message});
            return error.TemplateCompile;
        };
        self.account.compile(@embedFile("views/account.ztl"), .{ .error_report = &report }) catch {
            std.log.err("account template: {s}", .{report.message});
            return error.TemplateCompile;
        };
        self.admin.compile(@embedFile("views/admin.ztl"), .{ .error_report = &report }) catch {
            std.log.err("admin template: {s}", .{report.message});
            return error.TemplateCompile;
        };
        self.pending.compile(@embedFile("views/pending.ztl"), .{ .error_report = &report }) catch {
            std.log.err("pending template: {s}", .{report.message});
            return error.TemplateCompile;
        };
        self.forbidden.compile(@embedFile("views/forbidden.ztl"), .{ .error_report = &report }) catch {
            std.log.err("forbidden template: {s}", .{report.message});
            return error.TemplateCompile;
        };
        return self;
    }

    pub fn deinit(self: *Templates) void {
        self.login.deinit();
        self.account.deinit();
        self.admin.deinit();
        self.pending.deinit();
        self.forbidden.deinit();
    }

    pub fn renderLogin(self: *Templates, arena: std.mem.Allocator, args: anytype) ![]u8 {
        return render(&self.login, arena, args);
    }

    pub fn renderAccount(self: *Templates, arena: std.mem.Allocator, args: anytype) ![]u8 {
        return render(&self.account, arena, args);
    }

    pub fn renderAdmin(self: *Templates, arena: std.mem.Allocator, args: anytype) ![]u8 {
        return render(&self.admin, arena, args);
    }

    pub fn renderPending(self: *Templates, arena: std.mem.Allocator, args: anytype) ![]u8 {
        return render(&self.pending, arena, args);
    }

    pub fn renderForbidden(self: *Templates, arena: std.mem.Allocator, args: anytype) ![]u8 {
        return render(&self.forbidden, arena, args);
    }

    fn render(tmpl: anytype, arena: std.mem.Allocator, args: anytype) ![]u8 {
        var aw: std.Io.Writer.Allocating = .init(arena);
        errdefer aw.deinit();
        var report = ztl.RenderErrorReport{};
        tmpl.render(&aw.writer, args, .{ .allocator = arena, .error_report = &report }) catch |err| {
            defer report.deinit();
            std.log.err("template render: {s}", .{report.message});
            return err;
        };
        return try aw.toOwnedSlice();
    }
};

test "templates compile and render" {
    var t = try Templates.init(std.testing.allocator);
    defer t.deinit();
    const login = try t.renderLogin(std.testing.allocator, .{
        .from_site = "jellyfin",
        .from_path = "/",
        .err_msg = "",
        .has_from_site = true,
        .has_error = false,
        .discord_enabled = false,
        .discord_href = "",
    });
    defer std.testing.allocator.free(login);
    try std.testing.expect(std.mem.indexOf(u8, login, "authum") != null);
    try std.testing.expect(std.mem.indexOf(u8, login, "jellyfin") != null);

    const forbidden = try t.renderForbidden(std.testing.allocator, .{
        .reason = "unknown site",
        .hint = "Host is not in the sites registry.",
        .fwd_host = "app.example.com",
        .host = "app.example.com",
        .fwd_uri = "/dashboard",
        .path = "/dashboard",
        .method = "GET",
        .proto = "https",
        .site_name = "—",
        .site_id = "—",
        .user_name = "alice",
        .user_label = "1",
    });
    defer std.testing.allocator.free(forbidden);
    try std.testing.expect(std.mem.indexOf(u8, forbidden, "403 Forbidden") != null);
    try std.testing.expect(std.mem.indexOf(u8, forbidden, "app.example.com") != null);
    try std.testing.expect(std.mem.indexOf(u8, forbidden, "<details>") != null);
    try std.testing.expect(std.mem.indexOf(u8, forbidden, "alice") != null);
}
