const std = @import("std");
const poseidon = @import("poseidon");
const Hasher = poseidon.Hasher;

const ITERATIONS = 10_000;
const WARMUP = 100;

pub fn sched_setaffinity(pid: std.os.linux.pid_t, set: *const std.os.linux.cpu_set_t) !void {
    const size = @sizeOf(std.os.linux.cpu_set_t);
    const rc = std.os.linux.syscall3(.sched_setaffinity, @as(usize, @bitCast(@as(isize, pid))), size, @intFromPtr(set));

    switch (std.posix.errno(rc)) {
        .SUCCESS => return,
        else => |err| return std.posix.unexpectedErrno(err),
    }
}
pub fn main() !void {
    const cpu0001: std.os.linux.cpu_set_t = [1]usize{0b0001} ++ ([_]usize{0} ** (16 - 1));
    try sched_setaffinity(0, &cpu0001);

    const stdout = std.io.getStdOut().writer();
    const gpa = std.heap.c_allocator;
    var prng = std.Random.DefaultPrng.init(10);
    const random = prng.random();

    for (2..3) |i| {
        try stdout.print("Benchmarking poseidon_bn254_x5_{d}: ", .{i});
        const input = try gpa.alloc(u8, i * 32);
        for (std.mem.bytesAsSlice(u256, input)) |*item| {
            item.* = random.uintLessThan(u256, poseidon.Fe.field_order);
        }

        var j: u64 = 0;
        var total_ns: u64 = 0;
        while (j < ITERATIONS + WARMUP) : (j += 1) {
            var timer = try std.time.Timer.start();
            std.mem.doNotOptimizeAway(Hasher.hash(input, .little) catch unreachable);
            if (j > WARMUP) total_ns += timer.read();
        }

        const average = total_ns / ITERATIONS;
        try stdout.print(
            "{d} us / iterations ; {d} ns / byte\n",
            .{ average / std.time.ns_per_us, average / input.len },
        );
    }
}
