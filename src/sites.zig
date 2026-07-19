const std = @import("std");

pub const Site = struct {
    id: i64,
    name: []const u8,
    host: []const u8,
    user_header: []const u8,
    user_id_header: []const u8,
    user_name_header: []const u8,
};

/// Parsed TSV row before DB insert (id null = auto-assign).
pub const ParsedSite = struct {
    id: ?i64,
    name: []const u8,
    host: []const u8,
    user_header: []const u8,
    user_id_header: []const u8,
    user_name_header: []const u8,
};

pub const ParseResult = union(enum) {
    ok: []ParsedSite,
    invalid: []u8,
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
        allocator.free(site.user_header);
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
                .user_header = try self.allocator.dupe(u8, s.user_header),
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

    /// Parse backup TSV. Strings are slices into `tsv` (or static header skips).
    /// Columns: id, name, host, user_header, user_id_header, user_name_header
    /// (`id` may be blank for auto-assign).
    pub fn parseTsv(tsv: []const u8, msg_allocator: std.mem.Allocator) !ParseResult {
        var list: std.ArrayList(ParsedSite) = .empty;
        errdefer list.deinit(msg_allocator);

        var lines = std.mem.splitScalar(u8, tsv, '\n');
        var line_no: usize = 0;
        while (lines.next()) |raw_line| {
            line_no += 1;
            const line = std.mem.trim(u8, raw_line, " \t\r");
            if (line.len == 0) continue;
            // Comments: '#' not followed by a digit (so '#10' subjects are not comments).
            if (line[0] == '#' and (line.len == 1 or !std.ascii.isDigit(line[1]))) continue;

            var cols: [6][]const u8 = .{ "", "", "", "", "", "" };
            var col_count: usize = 0;
            var it = std.mem.splitScalar(u8, line, '\t');
            while (it.next()) |raw_col| {
                const col = std.mem.trim(u8, raw_col, " \t\r");
                if (col_count < cols.len) cols[col_count] = col;
                col_count += 1;
            }

            const id_col = cols[0];
            const name = cols[1];
            const host = cols[2];
            const user_header = cols[3];
            const user_id_header = cols[4];
            const user_name_header = cols[5];

            if (std.mem.eql(u8, id_col, "id") and (name.len == 0 or std.mem.eql(u8, name, "name"))) continue;
            // Legacy header without id column.
            if (std.mem.eql(u8, id_col, "site_id") and (name.len == 0 or std.mem.eql(u8, name, "host"))) {
                return .{ .invalid = try std.fmt.allocPrint(
                    msg_allocator,
                    "Sites line {d}: legacy site_id header; use id\\tname\\thost\\tuser_header\\tuser_id_header\\tuser_name_header",
                    .{line_no},
                ) };
            }

            if (name.len == 0 or host.len == 0 or user_header.len == 0 or
                user_id_header.len == 0 or user_name_header.len == 0)
            {
                return .{ .invalid = try std.fmt.allocPrint(
                    msg_allocator,
                    "Sites line {d}: name, host, and header names must be non-empty",
                    .{line_no},
                ) };
            }

            const id: ?i64 = if (id_col.len == 0) null else std.fmt.parseInt(i64, id_col, 10) catch {
                return .{ .invalid = try std.fmt.allocPrint(
                    msg_allocator,
                    "Sites line {d}: invalid id {s}",
                    .{ line_no, id_col },
                ) };
            };

            try list.append(msg_allocator, .{
                .id = id,
                .name = name,
                .host = host,
                .user_header = user_header,
                .user_id_header = user_id_header,
                .user_name_header = user_name_header,
            });
        }

        return .{ .ok = try list.toOwnedSlice(msg_allocator) };
    }

    pub fn exportTsv(self: *Sites, io: std.Io, allocator: std.mem.Allocator) ![]u8 {
        self.mutex.lockUncancelable(io);
        defer self.mutex.unlock(io);

        var out: std.ArrayList(u8) = .empty;
        errdefer out.deinit(allocator);
        try out.appendSlice(allocator, "id\tname\thost\tuser_header\tuser_id_header\tuser_name_header\n");
        for (self.sites) |site| {
            const row = try std.fmt.allocPrint(allocator, "{d}\t{s}\t{s}\t{s}\t{s}\t{s}\n", .{
                site.id,
                site.name,
                site.host,
                site.user_header,
                site.user_id_header,
                site.user_name_header,
            });
            try out.appendSlice(allocator, row);
        }
        return try out.toOwnedSlice(allocator);
    }

    fn dupSite(allocator: std.mem.Allocator, site: Site) !Site {
        return .{
            .id = site.id,
            .name = try allocator.dupe(u8, site.name),
            .host = try allocator.dupe(u8, site.host),
            .user_header = try allocator.dupe(u8, site.user_header),
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
        .user_header = "Remote-User",
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

test "sites parseTsv" {
    const parsed = try Sites.parseTsv(
        "id\tname\thost\tuser_header\tuser_id_header\tuser_name_header\n" ++
            "1\talpha\talpha.foo.com\tRemote-User\tRemote-User-Id\tRemote-User-Name\n",
        std.testing.allocator,
    );
    defer std.testing.allocator.free(parsed.ok);
    try std.testing.expect(parsed == .ok);
    try std.testing.expectEqual(@as(usize, 1), parsed.ok.len);
    try std.testing.expectEqual(@as(?i64, 1), parsed.ok[0].id);
    try std.testing.expectEqualStrings("alpha", parsed.ok[0].name);
}

test "sites parseTsv rejects short rows" {
    const result = try Sites.parseTsv(
        "1\talpha\talpha.foo.com\n",
        std.testing.allocator,
    );
    defer std.testing.allocator.free(result.invalid);
    try std.testing.expect(result == .invalid);
}

fn freeTestSite(site: Site) void {
    std.testing.allocator.free(site.name);
    std.testing.allocator.free(site.host);
    std.testing.allocator.free(site.user_header);
    std.testing.allocator.free(site.user_id_header);
    std.testing.allocator.free(site.user_name_header);
}
