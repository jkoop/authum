const std = @import("std");
const argon2 = std.crypto.pwhash.argon2;

pub fn hash(allocator: std.mem.Allocator, io: std.Io, password: []const u8) ![]u8 {
    var out: [256]u8 = undefined;
    const hashed = try argon2.strHash(password, .{
        .allocator = allocator,
        .params = argon2.Params.owasp_2id,
        .mode = .argon2id,
    }, &out, io);
    return try allocator.dupe(u8, hashed);
}

pub fn verify(allocator: std.mem.Allocator, io: std.Io, hashed: []const u8, password: []const u8) !bool {
    argon2.strVerify(hashed, password, .{ .allocator = allocator }, io) catch |err| switch (err) {
        error.PasswordVerificationFailed, error.InvalidEncoding, error.WeakParameters => return false,
        else => return err,
    };
    return true;
}
