const std = @import("std");

pub fn FieldElement(T: type, MOD: T) type {
    return struct {
        value: Int,

        // Some helper types
        const Element = @This();
        const bit_size = @bitSizeOf(T);
        /// The power of `2 ^ 64` closest to the number of bits required to represent
        /// the field modulus.
        const rounded_2_pow_64 = std.mem.alignForward(u32, bit_size, 64);
        const DoubleInt = std.meta.Int(.unsigned, rounded_2_pow_64 * 2);
        const Int = std.meta.Int(.unsigned, rounded_2_pow_64);

        /// The additive identity of the field.
        pub const ZERO: Element = .{ .value = 0 };
        /// The prime field modulus. NOT in Montgomery form.
        pub const MODULUS: u254 = MOD;
        /// `R = M % MODULUS` where `M` is `2 ^ rounded_2_pow_64`.
        pub const R: Int = (std.math.powi(DoubleInt, 2, rounded_2_pow_64) catch
            @panic("failed to compute R")) % MODULUS;
        /// `R2 = R^2 % MODULUS`.
        pub const R2: Int = (std.math.powi(DoubleInt, R, 2) catch
            @panic("failed to compute R2")) % MODULUS;
        /// - `INVERSE = -MODULUS ^ (-1) mod 2^254`
        /// - `INVERSE = R ^ (-1)`
        pub const INVERSE = inv: {
            var inv: Int = 1;
            for (0..bit_size) |_| {
                inv *%= inv;
                inv *%= MODULUS;
            }
            break :inv -%inv;
        };

        /// Adds two field elements in the Montgomery domain.
        pub fn add(self: *Element, other: Element) void {
            var sum = self.value + other.value;
            if (sum >= Element.MODULUS) {
                sum -= Element.MODULUS;
            }
            self.value = @bitCast(sum);
        }

        /// Multiplies two field elements in the Montgomery domain.
        pub fn multiply(self: *Element, other: Element) void {
            const product = @as(DoubleInt, self.value) * @as(DoubleInt, other.value);
            const low_prod: Int = @truncate(product);
            const high_prod: Int = @intCast(product >> rounded_2_pow_64);

            const reduced: Int = low_prod *% INVERSE;
            const mod_prod = @as(DoubleInt, reduced) * MODULUS;
            const low_mod_prod: Int = @truncate(mod_prod);
            const high_mod_prod: Int = @intCast(mod_prod >> rounded_2_pow_64);

            // TODO: this is a wrapping subtraction!
            const carry = @addWithOverflow(low_prod, low_mod_prod)[1];
            var final_sum: Int = @truncate(@as(DoubleInt, carry) +
                @as(DoubleInt, high_prod) +
                @as(DoubleInt, high_mod_prod));

            if (final_sum >= MODULUS) {
                final_sum -%= MODULUS;
            }

            self.value = final_sum;
        }

        /// Squares a field element in the Montgomery domain.
        ///
        /// NOTE: Just performs `self.mul(self)` for now, I'm not aware
        /// of a better solution.
        pub fn square(self: Element) Element {
            var out: Element = self;
            out.multiply(self);
            return out;
        }

        /// Translates a field element out of the Montgomery domain.
        pub fn fromMontgomery(self: Element) Element {
            const product: Int = @truncate(@as(DoubleInt, self.value) * @as(DoubleInt, INVERSE));
            const mod_prod = @as(DoubleInt, product) * MODULUS;
            const low_mod_prod: Int = @truncate(mod_prod);
            const high_mod_prod: Int = @truncate(mod_prod >> rounded_2_pow_64);
            const add_overflow: u1 = @addWithOverflow(self.value, low_mod_prod)[1];
            const adjusted_diff = add_overflow + high_mod_prod;

            // TODO: this is just a compare and reduce
            const carry_adjust, const is_carry_adjusted = @subWithOverflow(adjusted_diff, MODULUS);
            const is_negative = @subWithOverflow(0, is_carry_adjusted)[1];
            const result = if (is_negative == 0) carry_adjust else adjusted_diff;
            return .{ .value = result };
        }

        /// Translates a field element into of the Montgomery domain.
        pub fn fromInteger(integer: Int) Element {
            const product = @as(DoubleInt, integer) * @as(DoubleInt, R2);
            const low_prod: Int = @truncate(product);
            const high_prod: Int = @truncate(product >> rounded_2_pow_64);
            const n_prod: Int = @truncate(@as(DoubleInt, low_prod) * @as(DoubleInt, INVERSE));
            const mod_prod = @as(DoubleInt, n_prod) * MODULUS;
            const low_mod_prod: Int = @truncate(mod_prod);
            const high_mod_prod: Int = @truncate(mod_prod >> rounded_2_pow_64);
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
        pub fn fromArray(array: [@divExact(rounded_2_pow_64, 64)]u64) Element {
            return .{ .value = @bitCast(array) };
        }

        pub fn format(
            elem: Element,
            comptime _: []const u8,
            _: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            try writer.print("{d}", .{elem.value});
        }
    };
}
