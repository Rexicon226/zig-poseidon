const std = @import("std");
const poseidon = @import("poseidon");
const Hasher = poseidon.Hasher;
const Fe = poseidon.Fe;

const ITERATIONS = 6_000;
const WARMUP = 100;

const Benchmarks = enum {
    hash,
};

pub fn main() !void {
    const cpu0001: std.os.linux.cpu_set_t = [1]usize{0b0001} ++ ([_]usize{0} ** (128 / @sizeOf(usize) - 1));
    try sched_setaffinity(0, &cpu0001);

    const stdout = std.fs.File.stdout();
    var writer = stdout.writer(&.{});

    const gpa = std.heap.c_allocator;
    var prng = std.Random.DefaultPrng.init(10);
    const random = prng.random();

    var args = try std.process.argsWithAllocator(gpa);
    defer args.deinit();
    _ = args.skip();

    var maybe_benchmark: ?Benchmarks = null;
    while (args.next()) |arg| {
        if (std.meta.stringToEnum(Benchmarks, arg)) |bench| {
            if (maybe_benchmark != null) @panic("only one benchmark argument");
            maybe_benchmark = bench;
            continue;
        }
        @panic("unknown argument");
    }
    const benchmark = maybe_benchmark orelse @panic("expected benchmark");

    switch (benchmark) {
        .hash => try benchHash(gpa, &writer.interface, random),
    }
}

fn benchHash(
    gpa: std.mem.Allocator,
    stdout: *std.io.Writer,
    random: std.Random,
) !void {
    for (1..13) |i| {
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

pub fn sched_setaffinity(pid: std.os.linux.pid_t, set: *const std.os.linux.cpu_set_t) !void {
    const size = @sizeOf(std.os.linux.cpu_set_t);
    const rc = std.os.linux.syscall3(.sched_setaffinity, @as(usize, @bitCast(@as(isize, pid))), size, @intFromPtr(set));

    switch (std.posix.errno(rc)) {
        .SUCCESS => return,
        else => |err| return std.posix.unexpectedErrno(err),
    }
}
