const std = @import("std");

pub const Tag = struct {
    pub const boolean: u8 = 0x01;
    pub const integer: u8 = 0x02;
    pub const octet_string: u8 = 0x04;
    pub const null_: u8 = 0x05;
    pub const enumerated: u8 = 0x0a;
    pub const sequence: u8 = 0x30;
    /// LDAP BindRequest [APPLICATION 0] CONSTRUCTED
    pub const bind_request: u8 = 0x60;
    /// LDAP AuthenticationChoice simple [0] IMPLICIT OCTET STRING
    pub const auth_simple: u8 = 0x80;
};

pub const Error = error{
    Truncated,
    InvalidLength,
    UnexpectedTag,
    IntegerOverflow,
};

pub const Reader = struct {
    bytes: []const u8,
    pos: usize = 0,

    pub fn remaining(self: Reader) []const u8 {
        return self.bytes[self.pos..];
    }

    pub fn peekTag(self: Reader) Error!u8 {
        if (self.pos >= self.bytes.len) return error.Truncated;
        return self.bytes[self.pos];
    }

    pub fn readTag(self: *Reader) Error!u8 {
        if (self.pos >= self.bytes.len) return error.Truncated;
        const tag = self.bytes[self.pos];
        self.pos += 1;
        return tag;
    }

    pub fn readLength(self: *Reader) Error!usize {
        if (self.pos >= self.bytes.len) return error.Truncated;
        const first = self.bytes[self.pos];
        self.pos += 1;
        if (first & 0x80 == 0) return first;

        const nbytes = first & 0x7f;
        if (nbytes == 0) return error.InvalidLength; // indefinite not supported
        if (nbytes > @sizeOf(usize)) return error.InvalidLength;
        if (self.pos + nbytes > self.bytes.len) return error.Truncated;

        var len: usize = 0;
        for (0..nbytes) |_| {
            len = (len << 8) | self.bytes[self.pos];
            self.pos += 1;
        }
        return len;
    }

    pub fn readTagLength(self: *Reader) Error!struct { tag: u8, length: usize } {
        const tag = try self.readTag();
        const length = try self.readLength();
        return .{ .tag = tag, .length = length };
    }

    pub fn readBytes(self: *Reader, n: usize) Error![]const u8 {
        if (self.pos + n > self.bytes.len) return error.Truncated;
        const slice = self.bytes[self.pos .. self.pos + n];
        self.pos += n;
        return slice;
    }

    pub fn expectTag(self: *Reader, expected: u8) Error!usize {
        const tl = try self.readTagLength();
        if (tl.tag != expected) return error.UnexpectedTag;
        return tl.length;
    }

    pub fn readInteger(self: *Reader) Error!i64 {
        const len = try self.expectTag(Tag.integer);
        return try decodeInteger(try self.readBytes(len));
    }

    pub fn readEnumerated(self: *Reader) Error!i64 {
        const len = try self.expectTag(Tag.enumerated);
        return try decodeInteger(try self.readBytes(len));
    }

    pub fn readBoolean(self: *Reader) Error!bool {
        const len = try self.expectTag(Tag.boolean);
        if (len != 1) return error.InvalidLength;
        const bytes = try self.readBytes(1);
        return bytes[0] != 0;
    }

    pub fn readNull(self: *Reader) Error!void {
        const len = try self.expectTag(Tag.null_);
        if (len != 0) return error.InvalidLength;
    }

    pub fn readOctetString(self: *Reader) Error![]const u8 {
        const len = try self.expectTag(Tag.octet_string);
        return try self.readBytes(len);
    }

    /// Consume one complete TLV without interpreting contents.
    pub fn skipElement(self: *Reader) Error!void {
        const tl = try self.readTagLength();
        _ = try self.readBytes(tl.length);
    }
};

fn decodeInteger(bytes: []const u8) Error!i64 {
    if (bytes.len == 0) return error.InvalidLength;
    if (bytes.len > 8) return error.IntegerOverflow;

    var value: i64 = @as(i8, @bitCast(bytes[0]));
    for (bytes[1..]) |b| {
        value = (value << 8) | @as(i64, b);
    }
    return value;
}

fn encodeIntegerBytes(value: i64, buf: *[9]u8) []const u8 {
    // Two's complement, fewest octets, preserving sign bit.
    var tmp: [8]u8 = undefined;
    std.mem.writeInt(i64, &tmp, value, .big);

    var start: usize = 0;
    while (start < 7) {
        // Drop leading 0x00 when next bit is clear, or 0xff when next bit is set.
        if (tmp[start] == 0x00 and (tmp[start + 1] & 0x80) == 0) {
            start += 1;
            continue;
        }
        if (tmp[start] == 0xff and (tmp[start + 1] & 0x80) != 0) {
            start += 1;
            continue;
        }
        break;
    }
    const out = tmp[start..];
    @memcpy(buf[0..out.len], out);
    return buf[0..out.len];
}

pub fn writeLength(list: *std.ArrayList(u8), allocator: std.mem.Allocator, length: usize) !void {
    if (length < 0x80) {
        try list.append(allocator, @intCast(length));
        return;
    }
    var tmp: [8]u8 = undefined;
    var n: usize = 0;
    var v = length;
    while (v > 0) : (n += 1) {
        tmp[7 - n] = @truncate(v);
        v >>= 8;
    }
    try list.append(allocator, @intCast(0x80 | n));
    try list.appendSlice(allocator, tmp[8 - n ..]);
}

pub fn writeTagLength(list: *std.ArrayList(u8), allocator: std.mem.Allocator, tag: u8, length: usize) !void {
    try list.append(allocator, tag);
    try writeLength(list, allocator, length);
}

pub fn writeInteger(list: *std.ArrayList(u8), allocator: std.mem.Allocator, value: i64) !void {
    var buf: [9]u8 = undefined;
    const encoded = encodeIntegerBytes(value, &buf);
    try writeTagLength(list, allocator, Tag.integer, encoded.len);
    try list.appendSlice(allocator, encoded);
}

pub fn writeEnumerated(list: *std.ArrayList(u8), allocator: std.mem.Allocator, value: i64) !void {
    var buf: [9]u8 = undefined;
    const encoded = encodeIntegerBytes(value, &buf);
    try writeTagLength(list, allocator, Tag.enumerated, encoded.len);
    try list.appendSlice(allocator, encoded);
}

pub fn writeOctetString(list: *std.ArrayList(u8), allocator: std.mem.Allocator, value: []const u8) !void {
    try writeTagLength(list, allocator, Tag.octet_string, value.len);
    try list.appendSlice(allocator, value);
}

pub fn writeNull(list: *std.ArrayList(u8), allocator: std.mem.Allocator) !void {
    try writeTagLength(list, allocator, Tag.null_, 0);
}

pub fn writeBoolean(list: *std.ArrayList(u8), allocator: std.mem.Allocator, value: bool) !void {
    try writeTagLength(list, allocator, Tag.boolean, 1);
    try list.append(allocator, if (value) 0xff else 0x00);
}

/// Writes `tag` and a 4-byte definite length placeholder (`0x84` + zeros).
/// Returns the index of the `0x84` byte so `writeSequenceEnd` can patch length.
pub fn writeSequenceStart(list: *std.ArrayList(u8), allocator: std.mem.Allocator, tag: u8) !usize {
    try list.append(allocator, tag);
    const len_pos = list.items.len;
    try list.appendSlice(allocator, &[_]u8{ 0x84, 0, 0, 0, 0 });
    return len_pos;
}

pub fn writeSequenceEnd(list: *std.ArrayList(u8), len_pos: usize) void {
    const header = 5; // 0x84 + 4 length bytes
    const content_len = list.items.len - (len_pos + header);
    list.items[len_pos] = 0x84;
    std.mem.writeInt(u32, list.items[len_pos + 1 ..][0..4], @intCast(content_len), .big);
}

test "integer round-trip" {
    const allocator = std.testing.allocator;
    const values = [_]i64{ 0, 1, -1, 127, 128, -128, -129, 255, 256, -32768, 32767, std.math.maxInt(i32), std.math.minInt(i32) };

    for (values) |v| {
        var list: std.ArrayList(u8) = .empty;
        defer list.deinit(allocator);
        try writeInteger(&list, allocator, v);

        var r: Reader = .{ .bytes = list.items };
        try std.testing.expectEqual(v, try r.readInteger());
        try std.testing.expectEqual(list.items.len, r.pos);
    }
}

test "octet string round-trip" {
    const allocator = std.testing.allocator;
    const samples = [_][]const u8{ "", "a", "hello", "cn=admin,dc=example,dc=com" };

    for (samples) |s| {
        var list: std.ArrayList(u8) = .empty;
        defer list.deinit(allocator);
        try writeOctetString(&list, allocator, s);

        var r: Reader = .{ .bytes = list.items };
        try std.testing.expectEqualStrings(s, try r.readOctetString());
        try std.testing.expectEqual(list.items.len, r.pos);
    }
}

test "decode BindRequest skeleton" {
    // LDAPMessage { messageID 1, BindRequest { version 3, name "cn=admin", simple "secret" } }
    const msg = [_]u8{
        0x30, 0x1a,
        0x02, 0x01,
        0x01, 0x60,
        0x15, 0x02,
        0x01, 0x03,
        0x04, 0x08,
        'c',  'n',
        '=',  'a',
        'd',  'm',
        'i',  'n',
        0x80, 0x06,
        's',  'e',
        'c',  'r',
        'e',  't',
    };

    var r: Reader = .{ .bytes = &msg };
    try std.testing.expectEqual(@as(u8, Tag.sequence), try r.peekTag());
    const seq_len = try r.expectTag(Tag.sequence);
    const seq_end = r.pos + seq_len;

    try std.testing.expectEqual(@as(i64, 1), try r.readInteger());

    const bind_len = try r.expectTag(Tag.bind_request);
    const bind_end = r.pos + bind_len;
    try std.testing.expectEqual(@as(i64, 3), try r.readInteger());
    try std.testing.expectEqualStrings("cn=admin", try r.readOctetString());

    const auth_len = try r.expectTag(Tag.auth_simple);
    try std.testing.expectEqualStrings("secret", try r.readBytes(auth_len));

    try std.testing.expectEqual(bind_end, r.pos);
    try std.testing.expectEqual(seq_end, r.pos);
}

test "encode BindRequest via sequence helpers" {
    const allocator = std.testing.allocator;
    var list: std.ArrayList(u8) = .empty;
    defer list.deinit(allocator);

    const msg_pos = try writeSequenceStart(&list, allocator, Tag.sequence);
    try writeInteger(&list, allocator, 1);
    const bind_pos = try writeSequenceStart(&list, allocator, Tag.bind_request);
    try writeInteger(&list, allocator, 3);
    try writeOctetString(&list, allocator, "cn=admin");
    try writeTagLength(&list, allocator, Tag.auth_simple, 6);
    try list.appendSlice(allocator, "secret");
    writeSequenceEnd(&list, bind_pos);
    writeSequenceEnd(&list, msg_pos);

    var r: Reader = .{ .bytes = list.items };
    _ = try r.expectTag(Tag.sequence);
    try std.testing.expectEqual(@as(i64, 1), try r.readInteger());
    _ = try r.expectTag(Tag.bind_request);
    try std.testing.expectEqual(@as(i64, 3), try r.readInteger());
    try std.testing.expectEqualStrings("cn=admin", try r.readOctetString());
    const auth_len = try r.expectTag(Tag.auth_simple);
    try std.testing.expectEqualStrings("secret", try r.readBytes(auth_len));
}

test "boolean null enumerated skip" {
    const allocator = std.testing.allocator;
    var list: std.ArrayList(u8) = .empty;
    defer list.deinit(allocator);

    try writeBoolean(&list, allocator, true);
    try writeBoolean(&list, allocator, false);
    try writeNull(&list, allocator);
    try writeEnumerated(&list, allocator, 2);
    try writeOctetString(&list, allocator, "x");

    var r: Reader = .{ .bytes = list.items };
    try std.testing.expect(try r.readBoolean());
    try std.testing.expect(!(try r.readBoolean()));
    try r.readNull();
    try std.testing.expectEqual(@as(i64, 2), try r.readEnumerated());
    try r.skipElement();
    try std.testing.expectEqual(list.items.len, r.pos);
}
