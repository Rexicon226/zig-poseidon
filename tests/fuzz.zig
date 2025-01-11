//! Script for performing conformance testing against other Poseidon hash implementations.

const std = @import("std");
const builtin = @import("builtin");
const poseidon = @import("poseidon");
const Hasher = poseidon.Hasher;
const Element = poseidon.Element;

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .{};
    defer _ = gpa.deinit();
    const allocator = switch (builtin.mode) {
        .Debug => gpa.allocator(),
        else => std.heap.c_allocator,
    };

    var prng = std.Random.DefaultPrng.init(0);
    const random = prng.random();

    var arg_iter = try std.process.argsWithAllocator(allocator);
    defer arg_iter.deinit();
    _ = arg_iter.next();
    const other_script = arg_iter.next() orelse usage();

    std.debug.print("other script: {s}\n", .{other_script});

    const buffer = try allocator.alloc(u8, 12 * 32);
    defer allocator.free(buffer);

    var node = std.Progress.start(.{ .root_name = "Runs" });
    defer node.end();

    while (true) {
        const length = random.intRangeAtMost(u32, 1, 12);
        const input = buffer[0 .. length * 32];
        random.bytes(input);

        const my_hash = Hasher.hash(input, .little);

        const args = try bytesToArgs(input, other_script, allocator);
        defer {
            for (args) |arg| allocator.free(arg);
            allocator.free(args);
        }

        const result = try std.process.Child.run(.{
            .argv = args,
            .allocator = allocator,
        });
        defer {
            allocator.free(result.stdout);
            allocator.free(result.stderr);
        }

        const stdout = result.stdout;
        const parsed_result = try parseLightPoseidon(stdout, allocator);
        switch (parsed_result) {
            .Error => {
                if (!std.meta.isError(my_hash)) {
                    abortWithMismatch(input);
                }
            },
            .Result => |items| {
                defer allocator.free(items);
                if (my_hash) |hash| {
                    if (!std.mem.eql(u8, items, &hash)) {
                        abortWithMismatch(input);
                    }
                } else |_| abortWithMismatch(input);
            },
        }

        node.completeOne();
    }
}

const Result = union(enum) {
    Error,
    Result: []const u8,
};

fn parseLightPoseidon(stdout: []u8, allocator: std.mem.Allocator) !Result {
    if (std.mem.startsWith(u8, stdout, "error")) {
        return .Error;
    } else if (std.mem.startsWith(u8, stdout, "result: ")) {
        var list = std.ArrayList(u8).init(allocator);
        const start = std.mem.indexOfScalar(u8, stdout, '[').?;
        const slice = stdout[start + 1 .. stdout.len - 2];
        var iter = std.mem.splitSequence(u8, slice, ", ");
        while (iter.next()) |item| {
            const integer = try std.fmt.parseInt(u8, item, 10);
            try list.append(integer);
        }
        return .{ .Result = try list.toOwnedSlice() };
    } else @panic("unknown");
}

fn bytesToArgs(
    bytes: []const u8,
    path: []const u8,
    allocator: std.mem.Allocator,
) ![]const []const u8 {
    var list = std.ArrayList([]const u8).init(allocator);
    try list.append(try allocator.dupe(u8, path));
    for (bytes) |byte| {
        const arg = try std.fmt.allocPrint(allocator, "{d}", .{byte});
        try list.append(arg);
    }
    return list.toOwnedSlice();
}

fn abortWithMismatch(bytes: []const u8) noreturn {
    std.debug.print("failed with: {d}\n", .{bytes});
    std.posix.abort();
}

fn usage() noreturn {
    const stdout = std.io.getStdOut().writer();
    stdout.print("usage: fuzz other_program\n", .{}) catch {
        @panic("failed to print usage");
    };
    std.posix.abort();
}
