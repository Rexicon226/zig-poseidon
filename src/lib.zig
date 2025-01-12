const std = @import("std");

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

pub const Element = struct {
    value: u256,

    /// The additive identity of the field.
    pub const ZERO: Element = .{ .value = 0 };
    /// The prime field modulus. NOT in Montgomery form.
    pub const MODULUS: u254 = 0x30644e72e131a029b85045b68181585d2833e84879b9709143e1f593f0000001;
    /// `R = M % MODULUS` where `M` is the power of `2^64` closest to the number of bits
    ///  required to represent the field modulus.
    pub const R: u256 = (std.math.powi(u257, 2, 256) catch @panic("failed to compute R")) % MODULUS;
    /// `R2 = R^2 % MODULUS`
    pub const R2: u256 = (std.math.powi(u512, R, 2) catch @panic("failed to compute R2")) % MODULUS;
    /// `INVERSE = -MODULUS ^ (-1) mod 2^254`
    ///
    /// `INVERSE = R ^ (-1)`
    pub const INVERSE = inv: {
        var inv: u256 = 1;
        for (0..@bitSizeOf(@TypeOf(MODULUS))) |_| {
            inv *%= inv;
            inv *%= MODULUS;
        }
        break :inv -%inv;
    };

    /// Adds two field elements in the Montgomery domain.
    fn add(self: *Element, other: Element) void {
        var sum = self.value + other.value;
        if (sum >= Element.MODULUS) {
            sum -= Element.MODULUS;
        }
        self.value = @bitCast(sum);
    }

    /// Multiplies two field elements in the Montgomery domain.
    fn multiply(self: *Element, other: Element) void {
        const product = @as(u512, self.value) * @as(u512, other.value);
        const low_prod: u256 = @truncate(product);
        const high_prod: u256 = @intCast(product >> 256);

        const reduced: u256 = low_prod *% INVERSE;
        const mod_prod = @as(u512, reduced) * MODULUS;
        const low_mod_prod: u256 = @truncate(mod_prod);
        const high_mod_prod: u256 = @intCast(mod_prod >> 256);

        const carry = @addWithOverflow(low_prod, low_mod_prod)[1];
        var final_sum: u256 = @truncate(@as(u512, carry) + @as(u512, high_prod) + @as(u512, high_mod_prod));

        if (final_sum >= MODULUS) {
            final_sum -%= MODULUS;
        }

        self.value = final_sum;
    }

    /// Squares a field element in the Montgomery domain.
    ///
    /// NOTE: Just performs `self.mul(self)` for now, I'm not aware
    /// of a better solution.
    fn square(self: Element) Element {
        var out: Element = self;
        out.multiply(self);
        return out;
    }

    /// Translates a field element out of the Montgomery domain.
    fn fromMontgomery(self: Element) Element {
        const product: u256 = @truncate(@as(u512, self.value) * @as(u512, INVERSE));
        const mod_prod = @as(u512, product) * MODULUS;
        const low_mod_prod: u256 = @truncate(mod_prod);
        const high_mod_prod: u256 = @truncate(mod_prod >> 256);
        const add_overflow: u1 = @addWithOverflow(self.value, low_mod_prod)[1];
        const adjusted_diff = add_overflow + high_mod_prod;

        // TODO: this is just a compare and reduce
        const carry_adjust, const is_carry_adjusted = @subWithOverflow(adjusted_diff, MODULUS);
        const is_negative = @subWithOverflow(0, is_carry_adjusted)[1];
        const result = if (is_negative == 0) carry_adjust else adjusted_diff;
        return .{ .value = result };
    }

    /// Translates a field element into of the Montgomery domain.
    pub fn fromInteger(integer: u256) Element {
        const product = @as(u512, integer) * @as(u512, R2);
        const low_prod: u256 = @truncate(product);
        const high_prod: u256 = @truncate(product >> 256);
        const n_prod: u256 = @truncate(@as(u512, low_prod) * @as(u512, INVERSE));
        const mod_prod = @as(u512, n_prod) * MODULUS;
        const low_mod_prod: u256 = @truncate(mod_prod);
        const high_mod_prod: u256 = @truncate(mod_prod >> 256);
        const add_overflow = @addWithOverflow(low_prod, low_mod_prod)[1];
        const adjusted_diff = add_overflow + high_prod + high_mod_prod;

        // TODO: this is just a compare and reduce
        const carry_adjust, const is_carry_adjusted = @subWithOverflow(adjusted_diff, MODULUS);
        const is_negative = @subWithOverflow(0, is_carry_adjusted)[1];
        const result = if (is_negative == 0) carry_adjust else adjusted_diff;
        return .{ .value = result };
    }

    /// A helper function for the parameters list. Assumes the array is little endian
    /// and already in Montgomery form.
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
