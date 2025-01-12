const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const ff_mod = b.addModule("ff", .{
        .root_source_file = b.path("ff/ff.zig"),
        .target = target,
        .optimize = optimize,
    });

    const poseidon_mod = b.addModule("poseidon", .{
        .root_source_file = b.path("poseidon/poseidon.zig"),
        .target = target,
        .optimize = optimize,
    });
    poseidon_mod.addImport("ff", ff_mod);

    const test_exe = b.addTest(.{
        .root_source_file = b.path("tests/test.zig"),
        .target = target,
        .optimize = optimize,
    });
    test_exe.root_module.addImport("poseidon", poseidon_mod);

    const test_step = b.step("test", "Tests the library");
    const run_test = b.addRunArtifact(test_exe);
    test_step.dependOn(&run_test.step);

    const fuzz_exe = b.addExecutable(.{
        .name = "fuzz",
        .root_source_file = b.path("tests/fuzz.zig"),
        .target = target,
        .optimize = optimize,
    });
    fuzz_exe.linkLibC();
    fuzz_exe.root_module.addImport("poseidon", poseidon_mod);
    fuzz_exe.root_module.omit_frame_pointer = false;
    b.installArtifact(fuzz_exe);

    const fuzz_step = b.step("fuzz", "Fuzzes the library");
    const run_fuzz = b.addRunArtifact(fuzz_exe);
    if (b.args) |args| run_fuzz.addArgs(args);
    fuzz_step.dependOn(&run_fuzz.step);

    const bench_exe = b.addExecutable(.{
        .name = "bench",
        .root_source_file = b.path("tests/bench.zig"),
        .target = target,
        .optimize = optimize,
    });
    bench_exe.linkLibC();
    bench_exe.root_module.addImport("poseidon", poseidon_mod);
    b.installArtifact(bench_exe);

    const bench_step = b.step("bench", "Benches the library");
    const run_bench = b.addRunArtifact(bench_exe);
    bench_step.dependOn(&run_bench.step);
}
