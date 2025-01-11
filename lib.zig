const std = @import("std");
const fiat = @import("fiat.zig");

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

pub const Hasher = struct {
    endian: std.builtin.Endian,
    state: std.BoundedArray(Element, 13),

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
            s.mul(t); // s = s ^ 5
        }
    }

    fn applyMds(hasher: *Hasher, params: Params) void {
        const width = params.width;
        var buffer: [13]Element = .{Element.ZERO} ** 13;
        for (0..hasher.state.len) |i| {
            for (hasher.state.slice(), 0..) |*a, j| {
                var t: Element = a.*;
                t.mul(params.mds[i][j]);
                buffer[i].add(t);
            }
        }
        @memcpy(hasher.state.slice(), buffer[0..width]);
    }
};

pub const Element = struct {
    value: u256,

    const ZERO: Element = .{ .value = 0 };
    /// The prime field modulus.
    const MODULUS = 0x30644e72e131a029b85045b68181585d2833e84879b9709143e1f593f0000001;
    /// `R = M % MODULUS` where `M` is the power of `2^64` closest to the number of bits
    ///  required to represent the field modulus.
    const R = computeR() catch @panic("failed to compute R");
    const N = 0x73f82f1d0d8341b2e39a9828990623916586864b4c6911b3c2e1f593efffffff;
    /// `INVERSE = -MODULUS ^ (-1) mod 2^64`
    const INVERSE = computeInv() catch @panic("failed to compute INV");

    fn computeR() !u256 {
        return try std.math.powi(u257, 2, 256) % MODULUS;
    }

    // TODO: compute it at comptime!
    fn computeInv() !u64 {
        return 0xC2E1F593EFFFFFFF;
    }

    fn add(self: *Element, other: Element) void {
        var sum = self.value + other.value;
        if (sum >= Element.MODULUS) {
            sum -= Element.MODULUS;
        }
        self.value = @bitCast(sum);
    }

    fn mul(self: *Element, other: Element) void {
        const a = self.value;
        const c = other.value;

        const product = @as(u512, a) * @as(u512, c);
        const low_prod: u256 = @truncate(product);
        const high_prod: u256 = @intCast(product >> 256);

        const reduced: u256 = @truncate(@as(u512, low_prod) * @as(u512, N));

        const mod_prod = @as(u512, reduced) * MODULUS;
        const low_mod_prod: u256 = @truncate(mod_prod);
        const high_mod_prod: u256 = @intCast(mod_prod >> 256);

        const interm_sum = @as(u512, low_prod) + @as(u512, low_mod_prod);
        const carry1: u1 = @truncate(interm_sum >> 256);

        const final_sum = @as(u512, carry1) + @as(u512, high_prod) + @as(u512, high_mod_prod);
        const low_final_sum: u256 = @truncate(final_sum);
        const carr2: u1 = @truncate(final_sum >> 256);

        const adjusted_diff = -@as(i512, low_final_sum) - @as(i512, MODULUS);
        const is_negative: i1 = @truncate(adjusted_diff >> 256);
        const low_adjusted_diff: u256 = @bitCast(@as(i256, @truncate(adjusted_diff)));
        const negative_flag: u1 = @bitCast(@as(i1, @truncate(-@as(i2, is_negative))));

        const carry_adjust = (@as(i512, carr2) - @as(i512, negative_flag));
        const is_carry_adjusted: i1 = @truncate(carry_adjust >> 256);
        const final_flag: u1 = @bitCast(@as(i1, @truncate(-@as(i2, is_carry_adjusted))));

        const masked_value: u256 = @bitCast(-@as(i256, final_flag));
        const result: u256 = (masked_value & low_final_sum) | ((~masked_value) & low_adjusted_diff);

        self.value = result;
    }

    inline fn cast(comptime DestType: type, target: anytype) DestType {
        @setEvalBranchQuota(10000);
        if (@typeInfo(@TypeOf(target)) == .Int) {
            const dest = @typeInfo(DestType).Int;
            const source = @typeInfo(@TypeOf(target)).Int;
            if (dest.bits < source.bits) {
                const T = std.meta.Int(source.signedness, dest.bits);
                return @bitCast(@as(T, @truncate(target)));
            }
        }
        return target;
    }

    fn square(self: Element) Element {
        var out: Element = self;
        out.mul(self);
        return out;
    }

    fn fromMontgomery(self: Element) Element {
        var out: Element = undefined;
        fiat.fiatBn254ScalarFromMontgomery(&out.value, .{self.value});
        return out;
    }

    pub fn fromInteger(integer: u256) Element {
        var out: Element = undefined;
        fiat.fiatBn254ScalarToMontgomery(&out.value, @bitCast(integer));
        return out;
    }

    pub fn fiatBn254ScalarMulxU256(out1: *u256, out2: *u256, arg1: u256, arg2: u256) void {
        const x1 = (@as(u512, arg1) * @as(u512, arg2));
        const x2: u256 = @truncate(x1);
        const x3: u256 = @intCast(x1 >> 256);
        out1.* = x2;
        out2.* = x3;
    }

    pub fn fiatBn254ScalarAddcarryxU256(out1: *u256, out2: *u1, arg1: u1, arg2: u256, arg3: u256) void {
        const x1 = ((@as(u512, arg1) + @as(u512, arg2)) + @as(u512, arg3));
        const x2: u256 = @truncate(x1 & @as(u512, 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff));
        const x3: u1 = @truncate(x1 >> 256);
        out1.* = x2;
        out2.* = x3;
    }
    pub fn fiatBn254ScalarSubborrowxU256(out1: *u256, out2: *u1, arg1: u1, arg2: u256, arg3: u256) void {
        const x1 = ((@as(i512, arg2) - @as(i512, arg1)) - @as(i512, arg3));
        const x2: i1 = @truncate(x1 >> 256);
        const x3: u256 = @bitCast(@as(i256, @truncate(x1)));
        out1.* = x3;
        out2.* = @as(u1, @bitCast(@as(i1, @truncate(@as(i2, 0x0) - @as(i2, x2)))));
    }

    pub fn fiatBn254ScalarCmovznzU256(out1: *u256, arg1: u1, arg2: u256, arg3: u256) void {
        const x1 = (~(~arg1));
        const temp1: i1 = @truncate(@as(i2, 0x0) - @as(i2, x1));
        const x2: u256 = @bitCast(@as(i256, temp1));
        const x3 = ((x2 & arg3) | ((~x2) & arg2));
        out1.* = x3;
    }

    pub fn fromArray(array: [4]u64) Element {
        return .{ .value = @bitCast(array) };
    }

    pub fn format(
        elem: Element,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        const integer: u256 = std.mem.readInt(
            u256,
            @ptrCast(&elem.value),
            .little,
        );
        try writer.print("{d}", .{integer});
    }
};
