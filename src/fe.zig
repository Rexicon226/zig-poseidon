/// Copied from `https://github.com/ziglang/zig/blob/master/lib/std/crypto/pcurves/common.zig`
const std = @import("std");
const crypto = std.crypto;
const debug = std.debug;
const mem = std.mem;
const meta = std.meta;

const NonCanonicalError = crypto.errors.NonCanonicalError;
const NotSquareError = crypto.errors.NotSquareError;

/// Parameters to create a finite field type.
pub const FieldParams = struct {
    fiat: type,
    field_order: comptime_int,
    field_bits: comptime_int,
    saturated_bits: comptime_int,
    encoded_length: comptime_int,
};

/// A field element, internally stored in Montgomery domain.
pub fn Field(comptime params: FieldParams) type {
    const fiat = params.fiat;
    const MontgomeryDomainFieldElement = fiat.MontgomeryDomainFieldElement;
    const NonMontgomeryDomainFieldElement = fiat.NonMontgomeryDomainFieldElement;

    return struct {
        const Fe = @This();

        limbs: MontgomeryDomainFieldElement,

        /// Field size.
        pub const field_order = params.field_order;

        /// Number of bits to represent the set of all elements.
        pub const field_bits = params.field_bits;

        /// Number of bits that can be saturated without overflowing.
        pub const saturated_bits = params.saturated_bits;

        /// Number of bytes required to encode an element.
        pub const encoded_length = params.encoded_length;

        /// Zero.
        pub const zero: Fe = Fe{ .limbs = mem.zeroes(MontgomeryDomainFieldElement) };

        /// One.
        pub const one = one: {
            var fe: Fe = undefined;
            fiat.setOne(&fe.limbs);
            break :one fe;
        };

        /// Reject non-canonical encodings of an element.
        pub fn rejectNonCanonical(s_: [encoded_length]u8, endian: std.builtin.Endian) NonCanonicalError!void {
            var s = if (endian == .little) s_ else orderSwap(s_);
            const field_order_s = comptime fos: {
                var fos: [encoded_length]u8 = undefined;
                mem.writeInt(std.meta.Int(.unsigned, encoded_length * 8), &fos, field_order, .little);
                break :fos fos;
            };
            if (crypto.utils.timingSafeCompare(u8, &s, &field_order_s, .little) != .lt) {
                return error.NonCanonical;
            }
        }

        /// Swap the endianness of an encoded element.
        pub fn orderSwap(s: [encoded_length]u8) [encoded_length]u8 {
            var t = s;
            for (s, 0..) |x, i| t[t.len - 1 - i] = x;
            return t;
        }

        /// Unpack a field element.
        pub fn fromBytes(s_: [encoded_length]u8, endian: std.builtin.Endian) NonCanonicalError!Fe {
            const s = if (endian == .little) s_ else orderSwap(s_);
            try rejectNonCanonical(s, .little);
            var limbs_z: NonMontgomeryDomainFieldElement = undefined;
            fiat.fromBytes(&limbs_z, s);
            var limbs: MontgomeryDomainFieldElement = undefined;
            fiat.toMontgomery(&limbs, limbs_z);
            return Fe{ .limbs = limbs };
        }

        /// Pack a field element.
        pub fn toBytes(fe: Fe, endian: std.builtin.Endian) [encoded_length]u8 {
            var limbs_z: NonMontgomeryDomainFieldElement = undefined;
            fiat.fromMontgomery(&limbs_z, fe.limbs);
            var s: [encoded_length]u8 = undefined;
            fiat.toBytes(&s, limbs_z);
            return if (endian == .little) s else orderSwap(s);
        }

        pub fn fromArray(limbs: NonMontgomeryDomainFieldElement) Fe {
            return .{ .limbs = limbs };
        }

        /// Element as an integer.
        pub const IntRepr = meta.Int(.unsigned, params.field_bits);

        /// Create a field element from an integer.
        pub fn fromInt(comptime x: IntRepr) NonCanonicalError!Fe {
            var s: [encoded_length]u8 = undefined;
            mem.writeInt(IntRepr, &s, x, .little);
            return fromBytes(s, .little);
        }

        /// Return the field element as an integer.
        pub fn toInt(fe: Fe) IntRepr {
            const s = fe.toBytes(.little);
            return mem.readInt(IntRepr, &s, .little);
        }

        /// Add field elements.
        pub fn add(a: Fe, b: Fe) Fe {
            var fe: Fe = undefined;
            fiat.add(&fe.limbs, a.limbs, b.limbs);
            return fe;
        }

        /// Multiply field elements.
        pub fn mul(a: Fe, b: Fe) Fe {
            var fe: Fe = undefined;
            fiat.mul(&fe.limbs, a.limbs, b.limbs);
            return fe;
        }

        /// Square a field element.
        pub fn sq(a: Fe) Fe {
            var fe: Fe = undefined;
            fiat.square(&fe.limbs, a.limbs);
            return fe;
        }

        /// Compute a^n.
        pub fn pow(a: Fe, comptime T: type, comptime n: T) Fe {
            var fe = one;
            var x: T = n;
            var t = a;
            while (true) {
                if (@as(u1, @truncate(x)) != 0) fe = fe.mul(t);
                x >>= 1;
                if (x == 0) break;
                t = t.sq();
            }
            return fe;
        }
    };
}
