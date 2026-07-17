const std = @import("std");

pub const Site = struct {
    site_id: []const u8,
    host: []const u8,
    user_header: []const u8,
    user_id_header: []const u8,
    user_name_header: []const u8,
};

pub const LoadResult = union(enum) {
    ok,
    invalid: []u8,
};

pub const Sites = struct {
    allocator: std.mem.Allocator,
    mutex: std.Io.Mutex = .init,
    sites: []Site = &.{},
    source: []const u8 = "",

    pub fn init(allocator: std.mem.Allocator) Sites {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *Sites) void {
        self.freeOwned();
    }

    fn freeSite(allocator: std.mem.Allocator, site: Site) void {
        allocator.free(site.site_id);
        allocator.free(site.host);
        allocator.free(site.user_header);
        allocator.free(site.user_id_header);
        allocator.free(site.user_name_header);
    }

    fn freeOwned(self: *Sites) void {
        for (self.sites) |site| freeSite(self.allocator, site);
        self.allocator.free(self.sites);
        self.allocator.free(self.source);
        self.sites = &.{};
        self.source = "";
    }

    /// On parse failure returns `.invalid` with a message allocated from `msg_allocator`.
    /// Does not modify the in-memory sites registry on failure.
    pub fn loadTsv(self: *Sites, io: std.Io, tsv: []const u8, msg_allocator: std.mem.Allocator) !LoadResult {
        var list: std.ArrayList(Site) = .empty;
        errdefer {
            for (list.items) |site| freeSite(self.allocator, site);
            list.deinit(self.allocator);
        }

        var lines = std.mem.splitScalar(u8, tsv, '\n');
        var line_no: usize = 0;
        while (lines.next()) |raw_line| {
            line_no += 1;
            const line = std.mem.trim(u8, raw_line, " \t\r");
            if (line.len == 0 or line[0] == '#') continue;

            var cols: [5][]const u8 = .{ "", "", "", "", "" };
            var col_count: usize = 0;
            var it = std.mem.splitScalar(u8, line, '\t');
            while (it.next()) |raw_col| {
                const col = std.mem.trim(u8, raw_col, " \t\r");
                if (col_count < cols.len) cols[col_count] = col;
                col_count += 1;
            }
            // Extra columns ignored; missing trailing columns stay blank ("").

            const site_id = cols[0];
            const host = cols[1];
            const user_header = cols[2];
            const user_id_header = cols[3];
            const user_name_header = cols[4];

            if (std.mem.eql(u8, site_id, "site_id") and (host.len == 0 or std.mem.eql(u8, host, "host"))) continue;

            if (site_id.len == 0 or host.len == 0 or user_header.len == 0 or
                user_id_header.len == 0 or user_name_header.len == 0)
            {
                return .{ .invalid = try std.fmt.allocPrint(
                    msg_allocator,
                    "Sites line {d}: site_id, host, and header names must be non-empty",
                    .{line_no},
                ) };
            }

            try list.append(self.allocator, .{
                .site_id = try self.allocator.dupe(u8, site_id),
                .host = try self.allocator.dupe(u8, host),
                .user_header = try self.allocator.dupe(u8, user_header),
                .user_id_header = try self.allocator.dupe(u8, user_id_header),
                .user_name_header = try self.allocator.dupe(u8, user_name_header),
            });
        }

        const owned_source = try self.allocator.dupe(u8, tsv);
        errdefer self.allocator.free(owned_source);
        const owned = try list.toOwnedSlice(self.allocator);

        self.mutex.lockUncancelable(io);
        defer self.mutex.unlock(io);
        self.freeOwned();
        self.sites = owned;
        self.source = owned_source;
        return .ok;
    }

    pub fn snapshotSource(self: *Sites, io: std.Io, allocator: std.mem.Allocator) ![]u8 {
        self.mutex.lockUncancelable(io);
        defer self.mutex.unlock(io);
        return try allocator.dupe(u8, self.source);
    }

    /// Read-only HTML table of current sites (escaped). Allocated from `allocator`.
    pub fn htmlTable(self: *Sites, io: std.Io, allocator: std.mem.Allocator) ![]u8 {
        self.mutex.lockUncancelable(io);
        defer self.mutex.unlock(io);

        var out: std.ArrayList(u8) = .empty;
        errdefer out.deinit(allocator);
        try out.appendSlice(allocator,
            \\<table>
            \\<tr><th>site_id</th><th>host</th><th>user_header</th><th>user_id_header</th><th>user_name_header</th></tr>
        );
        for (self.sites) |site| {
            const row = try std.fmt.allocPrint(allocator,
                \\<tr><td>{s}</td><td>{s}</td><td>{s}</td><td>{s}</td><td>{s}</td></tr>
            , .{
                try htmlEscape(allocator, site.site_id),
                try htmlEscape(allocator, site.host),
                try htmlEscape(allocator, site.user_header),
                try htmlEscape(allocator, site.user_id_header),
                try htmlEscape(allocator, site.user_name_header),
            });
            try out.appendSlice(allocator, row);
        }
        try out.appendSlice(allocator, "</table>");
        return try out.toOwnedSlice(allocator);
    }

    fn htmlEscape(allocator: std.mem.Allocator, value: []const u8) ![]u8 {
        var list: std.ArrayList(u8) = .empty;
        errdefer list.deinit(allocator);
        for (value) |c| {
            switch (c) {
                '&' => try list.appendSlice(allocator, "&amp;"),
                '<' => try list.appendSlice(allocator, "&lt;"),
                '>' => try list.appendSlice(allocator, "&gt;"),
                '"' => try list.appendSlice(allocator, "&quot;"),
                else => try list.append(allocator, c),
            }
        }
        return try list.toOwnedSlice(allocator);
    }

    fn dupSite(allocator: std.mem.Allocator, site: Site) !Site {
        return .{
            .site_id = try allocator.dupe(u8, site.site_id),
            .host = try allocator.dupe(u8, site.host),
            .user_header = try allocator.dupe(u8, site.user_header),
            .user_id_header = try allocator.dupe(u8, site.user_id_header),
            .user_name_header = try allocator.dupe(u8, site.user_name_header),
        };
    }

    pub fn byId(self: *Sites, io: std.Io, allocator: std.mem.Allocator, site_id: []const u8) !?Site {
        self.mutex.lockUncancelable(io);
        defer self.mutex.unlock(io);
        for (self.sites) |site| {
            if (std.mem.eql(u8, site.site_id, site_id)) return try dupSite(allocator, site);
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
    const result = try sites.loadTsv(
        io,
        "site_id\thost\tuser_header\tuser_id_header\tuser_name_header\n" ++
            "alpha\talpha.foo.com\tRemote-User\tRemote-User-Id\tRemote-User-Name\n",
        std.testing.allocator,
    );
    try std.testing.expect(result == .ok);
    const site = (try sites.byId(io, std.testing.allocator, "alpha")).?;
    defer freeTestSite(site);
    try std.testing.expectEqualStrings("alpha.foo.com", site.host);
    if (try sites.byHost(io, std.testing.allocator, "alpha.foo.com")) |found| {
        defer freeTestSite(found);
        try std.testing.expectEqualStrings("alpha", found.site_id);
    } else return error.TestUnexpectedResult;
    try std.testing.expect((try sites.byHost(io, std.testing.allocator, "missing")) == null);
}

test "sites ignores extras and pads missing trailing columns" {
    var sites = Sites.init(std.testing.allocator);
    defer sites.deinit();
    const result = try sites.loadTsv(
        std.testing.io,
        "site_id\thost\tuser_header\tuser_id_header\tuser_name_header\textra\n" ++
            "alpha\talpha.foo.com\tRemote-User\tRemote-User-Id\tRemote-User-Name\tignored\n",
        std.testing.allocator,
    );
    try std.testing.expect(result == .ok);

    var sites2 = Sites.init(std.testing.allocator);
    defer sites2.deinit();
    const short = try sites2.loadTsv(
        std.testing.io,
        "alpha\talpha.foo.com\n",
        std.testing.allocator,
    );
    try std.testing.expect(short == .invalid);
    defer std.testing.allocator.free(short.invalid);
}

fn freeTestSite(site: Site) void {
    std.testing.allocator.free(site.site_id);
    std.testing.allocator.free(site.host);
    std.testing.allocator.free(site.user_header);
    std.testing.allocator.free(site.user_id_header);
    std.testing.allocator.free(site.user_name_header);
}
