const std = @import("std");
const testing = std.testing;

const Base64 = struct {
    _table: *const [64]u8,

    pub fn init() Base64 {
        const upper = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
        const lower = "abcdefghijklmnopqrstuvwxyz";
        const numbers_symb = "0123456789+/";

        return Base64{
            ._table = upper ++ lower ++ numbers_symb,
        };
    }

    pub fn _char_at(self: Base64, idx: u8) u8 {
        return self._table[idx];
    }

    fn _calc_decode_length(in: []const u8) !usize {
        if (in.len < 4) {
            const n_output: usize = 3;
            return n_output;
        }

        // Ym9hcmQ= 8
        // board need 5
        const n_out: usize = try std.math.divFloor(usize, in.len, 4);

        if (in[in.len - 2] == '=') return n_out * 3 - 2;
        if (in[in.len - 1] == '=') return n_out * 3 - 1;

        return n_out * 3;
    }

    fn _calc_encode_length(in: []const u8) !usize {
        if (in.len < 3) {
            return 4;
        }

        const n_out: usize = try std.math.divCeil(usize, in.len, 3);
        return n_out * 4;
    }

    fn _char_index(self: Base64, char: u8) u8 {
        if (char == '=') return 64;
        var index: u8 = 0;

        for (0..63) |_i| {
            const i = @as(u8, @intCast(_i));

            if (self._char_at(i) == char) {
                index = i;
                break;
            }
        }

        return index;
    }

    pub fn decode(self: Base64, alloc: std.mem.Allocator, in: []const u8) ![]u8 {
        if (in.len == 0) {
            return "";
        }

        const n_out = try _calc_decode_length(in);
        var out = try alloc.alloc(u8, n_out);
        var cnt: u8 = 0;
        var iout: u64 = 0;
        var buf = [4]u8{ 0, 0, 0, 0 };

        for (0..in.len) |i| {
            buf[cnt] = self._char_index(in[i]);
            cnt += 1;
            if (cnt == 4) {
                out[iout] = (buf[0] << 2) + (buf[1] >> 4);
                if (buf[2] != 64) {
                    out[iout + 1] = (buf[1] << 4) + (buf[2] >> 2);
                }
                if (buf[3] != 64) {
                    out[iout + 2] = (buf[2] << 6) + buf[3];
                }
                iout += 3;
                cnt = 0;
            }
        }

        return out;
    }

    pub fn encode(self: Base64, alloc: std.mem.Allocator, in: []const u8) ![]u8 {
        if (in.len == 0) {
            return "";
        }

        const n_out = try _calc_encode_length(in);
        var out = try alloc.alloc(u8, n_out);
        var buf = [3]u8{ 0, 0, 0 };
        var cnt: u8 = 0;
        var iout: u64 = 0;

        for (in, 0..) |_, i| {
            buf[cnt] = in[i];
            cnt += 1;
            if (cnt == 3) {
                out[iout] = self._char_at(buf[0] >> 2);
                out[iout + 1] = self._char_at(((buf[0] & 0x03) << 4) + (buf[1] >> 4));
                out[iout + 2] = self._char_at(((buf[1] & 0x0f) << 2) + (buf[2] >> 6));
                out[iout + 3] = self._char_at(buf[2] & 0x3f);
                iout += 4;
                cnt = 0;
            }
        }

        if (cnt == 1) {
            out[iout] = self._char_at(buf[0] >> 2);
            out[iout + 1] = self._char_at((buf[0] & 0x03) << 4);
            out[iout + 2] = '=';
            out[iout + 3] = '=';
        }

        if (cnt == 2) {
            out[iout] = self._char_at(buf[0] >> 2);
            out[iout + 1] = self._char_at(((buf[0] & 0x03) << 4) + (buf[1] >> 4));
            out[iout + 2] = self._char_at((buf[1] & 0x0f) << 2);
            out[iout + 3] = '=';
            iout += 4;
        }

        return out;
    }
};

test "simple char_at function" {
    const b = Base64.init();
    try testing.expect(b._char_at(2) == 'C');
}

test "encode test without gap" {
    const in = "something";
    const expect = "c29tZXRoaW5n";

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const b = Base64.init();

    const in_result = try b.encode(allocator, in);
	defer allocator.free(in_result);

    try testing.expectEqualDeep(in_result, expect);
}

test "encode test with one gap" {
    const in = "board";
    const expect = "Ym9hcmQ=";

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const b = Base64.init();

    const in_result = try b.encode(allocator, in);
	defer allocator.free(in_result);

    try testing.expectEqualDeep(in_result, expect);
}

test "encode test with two gap" {
    const in = "boardfd";
    const expect = "Ym9hcmRmZA==";

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const b = Base64.init();

    const in_result = try b.encode(allocator, in);
	defer allocator.free(in_result);

    try testing.expectEqualDeep(in_result, expect);
}

test "decode test without gap" {
    const in = "c29tZXRoaW5n";
    const expect = "something";

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const b = Base64.init();

    const in_result = try b.decode(allocator, in);
	defer allocator.free(in_result);

    try testing.expectEqualDeep(expect, in_result);
}

test "decode test with one gap" {
    const in = "Ym9hcmQ=";
    const expect = "board";

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const b = Base64.init();

    const in_result = try b.decode(allocator, in);
	defer allocator.free(in_result);

    try testing.expectEqualDeep(expect, in_result);
}

test "decode test with two gap" {
    const in = "Ym9hcmRmZA==";
    const expect = "boardfd";

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const b = Base64.init();

    const in_result = try b.decode(allocator, in);
	defer allocator.free(in_result);

    try testing.expectEqualDeep(expect, in_result);
}
