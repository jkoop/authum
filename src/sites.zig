const std = @import("std");

pub const Site = struct {
    id: i64,
    name: []const u8,
    host: []const u8,
    user_id_header: []const u8,
    user_name_header: []const u8,
};

pub const Sites = struct {
    allocator: std.mem.Allocator,
    mutex: std.Io.Mutex = .init,
    sites: []Site = &.{},

    pub fn init(allocator: std.mem.Allocator) Sites {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *Sites) void {
        self.freeOwned();
    }

    fn freeSite(allocator: std.mem.Allocator, site: Site) void {
        allocator.free(site.name);
        allocator.free(site.host);
        allocator.free(site.user_id_header);
        allocator.free(site.user_name_header);
    }

    fn freeOwned(self: *Sites) void {
        for (self.sites) |site| freeSite(self.allocator, site);
        self.allocator.free(self.sites);
        self.sites = &.{};
    }

    /// Replace in-memory registry from DB rows (duplicates strings into self.allocator).
    pub fn load(self: *Sites, io: std.Io, rows: []const Site) !void {
        var list: std.ArrayList(Site) = .empty;
        errdefer {
            for (list.items) |site| freeSite(self.allocator, site);
            list.deinit(self.allocator);
        }
        for (rows) |s| {
            try list.append(self.allocator, .{
                .id = s.id,
                .name = try self.allocator.dupe(u8, s.name),
                .host = try self.allocator.dupe(u8, s.host),
                .user_id_header = try self.allocator.dupe(u8, s.user_id_header),
                .user_name_header = try self.allocator.dupe(u8, s.user_name_header),
            });
        }
        const owned = try list.toOwnedSlice(self.allocator);

        self.mutex.lockUncancelable(io);
        defer self.mutex.unlock(io);
        self.freeOwned();
        self.sites = owned;
    }

    fn dupSite(allocator: std.mem.Allocator, site: Site) !Site {
        return .{
            .id = site.id,
            .name = try allocator.dupe(u8, site.name),
            .host = try allocator.dupe(u8, site.host),
            .user_id_header = try allocator.dupe(u8, site.user_id_header),
            .user_name_header = try allocator.dupe(u8, site.user_name_header),
        };
    }

    pub fn byId(self: *Sites, io: std.Io, allocator: std.mem.Allocator, id: i64) !?Site {
        self.mutex.lockUncancelable(io);
        defer self.mutex.unlock(io);
        for (self.sites) |site| {
            if (site.id == id) return try dupSite(allocator, site);
        }
        return null;
    }

    pub fn byHost(self: *Sites, io: std.Io, allocator: std.mem.Allocator, host: []const u8) !?Site {
        self.mutex.lockUncancelable(io);
        defer self.mutex.unlock(io);
        for (self.sites) |site| {
            if (std.mem.eql(u8, site.host, host)) return try dupSite(allocator, site);
        }
        return null;
    }
};

test "sites lookup" {
    var sites = Sites.init(std.testing.allocator);
    defer sites.deinit();
    const io = std.testing.io;
    const rows = [_]Site{.{
        .id = 1,
        .name = "alpha",
        .host = "alpha.foo.com",
        .user_id_header = "Remote-User-Id",
        .user_name_header = "Remote-User-Name",
    }};
    try sites.load(io, &rows);
    const site = (try sites.byId(io, std.testing.allocator, 1)).?;
    defer freeTestSite(site);
    try std.testing.expectEqualStrings("alpha.foo.com", site.host);
    if (try sites.byHost(io, std.testing.allocator, "alpha.foo.com")) |found| {
        defer freeTestSite(found);
        try std.testing.expectEqual(@as(i64, 1), found.id);
        try std.testing.expectEqualStrings("alpha", found.name);
    } else return error.TestUnexpectedResult;
    try std.testing.expect((try sites.byHost(io, std.testing.allocator, "missing")) == null);
}

fn freeTestSite(site: Site) void {
    std.testing.allocator.free(site.name);
    std.testing.allocator.free(site.host);
    std.testing.allocator.free(site.user_id_header);
    std.testing.allocator.free(site.user_name_header);
}
