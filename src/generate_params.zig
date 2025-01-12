//! File to generating the round constants and MDS field for the hash.
//!
//! A reduced implementation of:
//! https://extgit.isec.tugraz.at/krypto/hadeshash/-/blob/master/code/generate_parameters_grain.sage

const std = @import("std");
const poseidon = @import("lib.zig");

const R_F = 8;
const R_P = 57;
const T = 3;
const N = 254;
const PRIME = 0x30644e72e131a029b85045b68181585d2833e84879b9709143e1f593f0000001;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const initial: u80 = 0b01000000001111111000000000001100000010000000111001111111111111111111111111111111;
    var generator = try Generator.init(initial);
    generator.mix();

    const round_constants = try generator.generateConstants(allocator);
    defer allocator.free(round_constants);

    // Convert to Montgomery form here, so there's need to do it at runtime later.
    for (round_constants) |*constant| {
        constant.* = poseidon.Element.fromInteger(constant.*).value;
    }

    const mds = try generator.createMDS(allocator);
    _ = mds;
}

const Generator = struct {
    // TODO: use std.BitStack instead
    stack: std.BoundedArray(u1, 1024) = .{},

    fn init(int: anytype) !Generator {
        const bsize = @bitSizeOf(@TypeOf(int));
        const vec: @Vector(bsize, u1) = @bitCast(@bitReverse(int));
        var stack: std.BoundedArray(u1, 1024) = .{};
        for (0..bsize) |i| {
            try stack.append(vec[i]);
        }
        return .{ .stack = stack };
    }

    fn mix(g: *Generator) void {
        for (0..160) |_| {
            _ = g.produce();
        }
    }

    fn produce(g: *Generator) u1 {
        const new_bit = g.stack.get(62) ^
            g.stack.get(51) ^
            g.stack.get(38) ^
            g.stack.get(23) ^
            g.stack.get(13) ^
            g.stack.get(0);
        _ = g.stack.orderedRemove(0);
        g.stack.appendAssumeCapacity(new_bit);
        return new_bit;
    }

    fn generate(g: *Generator) u1 {
        var new_bit = g.produce();
        while (new_bit == 0) {
            _ = g.produce();
            new_bit = g.produce();
        }
        new_bit = g.produce();
        return new_bit;
    }

    fn makeInteger(g: *Generator, comptime size: u32) std.meta.Int(.unsigned, size) {
        var vec: @Vector(size, u1) = undefined;
        for (0..size) |i| {
            vec[i] = g.generate();
        }
        const result: std.meta.Int(.unsigned, size) = @bitCast(vec);
        return @bitReverse(result);
    }

    fn generateConstants(g: *Generator, allocator: std.mem.Allocator) ![]u256 {
        const num_constants = (R_F + R_P) * T;
        const list = try allocator.alloc(u256, num_constants);
        for (list) |*item| {
            var random_integer = g.makeInteger(N);
            while (random_integer >= PRIME) {
                random_integer = g.makeInteger(N);
            }
            item.* = random_integer;
        }
        return list;
    }

    fn createMDS(g: *Generator, allocator: std.mem.Allocator) ![T][T]u256 {
        var matrix: [T][T]u256 = .{.{0} ** T} ** T;

        const list = try allocator.alloc(u256, T * 2);
        defer allocator.free(list);
        for (list) |*item| {
            const element = g.makeInteger(N);
            item.* = element;
        }

        const x = list[0..T];
        const y = list[T..];

        for (0..T) |i| {
            for (0..T) |j| {
                const entry = (x[i] + y[j]) % PRIME;
                // TODO: compute the inverse correctly!
                // const inv = inverse();
                std.debug.print("entry: {}\n", .{entry});
                matrix[i][j] = entry;
            }
        }

        _ = &matrix;

        return matrix;
    }
};

fn inverse(a: u256) u256 {
    var x: u256 = 0;
    var y: u256 = 0;
    const g = gcd(a, PRIME, &x, &y);
    if (!g) {
        @panic("inverse doesn't exist");
    } else {
        const result = (x % PRIME + PRIME) % PRIME;
        return result;
    }
}

fn gcd(a: u256, b: u256, x: *u256, y: *u256) bool {
    if (b == 0) {
        x.* = 1;
        y.* = 0;
        return a == 1;
    }

    var x1: u256 = 0;
    var y1: u256 = 0;
    const g = gcd(b, a % b, &x1, &y1);
    x.* = y1;
    y.* = x1 - (a / b) * y1;
    return g;
}
