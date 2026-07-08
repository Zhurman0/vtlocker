const std = @import("std");


pub fn build(b: *std.Build) void {
    const target   = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});


    const ui_mod = b.addModule("ui", .{
        .root_source_file = b.path("src/ui/root.zig"),
        .target = target, 
    });

    const locker_mod = b.addModule("locker", .{
        .root_source_file = b.path("src/locker/root.zig"),
        .target = target,
    });
    locker_mod.addImport("ui", ui_mod);
    //locker_mod.linkSystemLibrary("pam", .{});
    

    const exe = b.addExecutable(.{
        .name = "vtlocker",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target   = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "locker", .module = locker_mod },
            },
        }),
    });

    b.installArtifact(exe);


    const run_step = b.step("run", "Run the app");

    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }


    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });

    const run_exe_tests = b.addRunArtifact(exe_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_exe_tests.step);


    const clean_step = b.step("clean", "Remove build artifacts");
    
    clean_step.dependOn(&b.addSystemCommand(&.{
        "rm", "-rf", "zig-out", ".zig-cache",
    }).step);    
}
