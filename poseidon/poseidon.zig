const std = @import("std");
const FieldElement = @import("ff").FieldElement;

const PARAMS: [12]Hasher.Params = .{
    @import("params.zig").BN256_x5_2,
    @import("params.zig").BN256_x5_3,
    @import("params.zig").BN256_x5_4,
    @import("params.zig").BN256_x5_5,
    @import("params.zig").BN256_x5_6,
    @import("params.zig").BN256_x5_7,
    @import("params.zig").BN256_x5_8,
    @import("params.zig").BN256_x5_9,
    @import("params.zig").BN256_x5_10,
    @import("params.zig").BN256_x5_11,
    @import("params.zig").BN256_x5_12,
    @import("params.zig").BN256_x5_13,
};

pub const MODULUS: u254 = 0x30644e72e131a029b85045b68181585d2833e84879b9709143e1f593f0000001;

pub const Hasher = struct {
    endian: std.builtin.Endian,
    state: std.BoundedArray(Element, 13),

    const Element = FieldElement(u254, MODULUS);

    pub const Params = struct {
        /// Round constants.
        ark: []const Element,
        /// MSD matrix.
        mds: []const []const Element,
        /// The number of full rounds (where S-box is applied to all elements of the state).
        full_rounds: u32,
        /// The number of partial rounds (where S-box is applied only to the first element
        /// of the state).
        partial_rounds: u32,
        /// The number of prime fields in the state.
        width: u32,
        /// Exponential used in S-box to power elements of the state
        alpha: u32,
    };

    pub fn init(endian: std.builtin.Endian) Hasher {
        var state: std.BoundedArray(Element, 13) = .{};
        state.appendAssumeCapacity(Element.ZERO);
        return .{
            .endian = endian,
            .state = state,
        };
    }

    pub fn hash(bytes: []const u8, endian: std.builtin.Endian) ![32]u8 {
        if (bytes.len % 32 != 0) return error.InputNotMultipleOf32;
        var hasher = Hasher.init(endian);

        var iter = std.mem.window(u8, bytes, 32, 32);
        while (iter.next()) |slice| {
            try hasher.append(slice);
        }

        return hasher.finish();
    }

    pub fn append(hasher: *Hasher, bytes: []const u8) !void {
        const integer = std.mem.readInt(u256, bytes[0..32], hasher.endian);
        if (integer >= Element.MODULUS) {
            return error.LargerThanMod;
        }
        const element = Element.fromInteger(integer);
        try hasher.state.append(element);
    }

    pub fn finish(hasher: *Hasher) ![32]u8 {
        const width = hasher.state.len;
        const params = PARAMS[width - 2];
        if (width != params.width) return error.Unexpected;

        const all_rounds = params.full_rounds + params.partial_rounds;
        const half_rounds = params.full_rounds / 2;

        for (0..half_rounds) |round| {
            hasher.applyArk(params, round);
            hasher.applySBoxFull(width);
            hasher.applyMds(params);
        }

        for (half_rounds..half_rounds + params.partial_rounds) |round| {
            hasher.applyArk(params, round);
            hasher.applySBoxFull(1);
            hasher.applyMds(params);
        }

        for (half_rounds + params.partial_rounds..all_rounds) |round| {
            hasher.applyArk(params, round);
            hasher.applySBoxFull(width);
            hasher.applyMds(params);
        }

        var result = hasher.state.get(0).fromMontgomery();
        if (hasher.endian == .big) result.value = @byteSwap(result.value);
        return @bitCast(result.value);
    }

    fn applyArk(hasher: *Hasher, params: Params, round: u64) void {
        for (hasher.state.slice(), 0..) |*a, i| {
            a.add(params.ark[round * params.width + i]);
        }
    }

    fn applySBoxFull(hasher: *Hasher, width: u64) void {
        // compute s[i] ^ 5
        for (hasher.state.slice()[0..width]) |*s| {
            var t: Element = undefined;
            t = s.square(); // t = s ^ 2
            t = t.square(); // t = s ^ 4
            s.multiply(t); // s = s ^ 5
        }
    }

    fn applyMds(hasher: *Hasher, params: Params) void {
        const width = params.width;
        var buffer: [13]Element = .{Element.ZERO} ** 13;
        for (0..hasher.state.len) |i| {
            for (hasher.state.slice(), 0..) |*a, j| {
                var t: Element = a.*;
                t.multiply(params.mds[i][j]);
                buffer[i].add(t);
            }
        }
        @memcpy(hasher.state.slice(), buffer[0..width]);
    }
};
