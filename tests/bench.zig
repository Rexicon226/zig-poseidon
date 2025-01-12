const std = @import("std");
const poseidon = @import("poseidon");
const Hasher = poseidon.Hasher;

const ITERATIONS = 10_000;
const WARMUP = 100;

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    const gpa = std.heap.c_allocator;
    var prng = std.Random.DefaultPrng.init(10);
    const random = prng.random();

    for (1..13) |i| {
        try stdout.print("Benchmarking poseidon_bn254_x5_{d}: ", .{i});
        const input = try gpa.alloc(u8, i * 32);
        for (std.mem.bytesAsSlice(u256, input)) |*item| {
            item.* = random.uintLessThan(u256, poseidon.MODULUS);
        }

        var j: u64 = 0;
        var total_ns: u64 = 0;
        while (j < ITERATIONS + WARMUP) : (j += 1) {
            var timer = try std.time.Timer.start();
            std.mem.doNotOptimizeAway(Hasher.hash(input, .little) catch unreachable);
            if (j > WARMUP) {
                total_ns += timer.read();
            }
        }

        const average = total_ns / ITERATIONS;
        try stdout.print(
            "{d} us / iterations ; {d} ns / byte\n",
            .{ average / std.time.ns_per_us, average / input.len },
        );
    }
}
