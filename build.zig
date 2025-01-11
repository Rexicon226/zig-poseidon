const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const test_exe = b.addTest(.{
        .root_source_file = b.path("test.zig"),
        .target = target,
        .optimize = optimize,
    });

    const test_step = b.step("test", "Tests the library");
    const run_test = b.addRunArtifact(test_exe);
    test_step.dependOn(&run_test.step);
}
