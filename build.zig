const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    // const optimize = b.standardOptimizeOption(.{});

    // Compile all 25 configurations
    inline for (0..25) |i| {
        const id = std.fmt.allocPrint(b.allocator, "{d:0>3}", .{i}) catch unreachable;
        const exe = b.addExecutable(.{
            .name = b.fmt("saturn-{s}", .{id}),
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = .ReleaseFast,
        });

        // Add config_NNN.zig as a package
        const config_path = std.fmt.allocPrint(b.allocator, "src/config_{s}.zig", .{id}) catch unreachable;
        const config = b.addModule("engine_config", .{ .root_source_file = b.path(config_path)});
        exe.root_module.addImport("engine_config", config);

        b.installArtifact(exe);
    }
}

