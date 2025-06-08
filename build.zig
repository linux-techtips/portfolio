const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});

    const use_llvm = b.option(bool, "use_llvm", "use llvm?") orelse false;
    const use_lld = b.option(bool, "use_lld", "use lld?") orelse false;

    const render_exe = b.addExecutable(.{
        .name = "render",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/render.zig"),
            .optimize = optimize,
            .target = target,
            .imports = &.{},
        }),
        .use_llvm = use_llvm,
        .use_lld = use_lld,
    });

    const render_exe_install = b.addInstallArtifact(render_exe, .{});

    const render_step = b.step("render", "render the site");
    render_step.dependOn(&render_exe_install.step);

    const render_run = b.addRunArtifact(render_exe);
    render_run.step.dependOn(&render_exe_install.step);

    if (b.args) |args| render_run.addArgs(args);

    const serve_exe = b.addExecutable(.{
        .name = "serve",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/serve.zig"),
            .optimize = optimize,
            .target = target,
            .imports = &.{},
        }),
        .use_llvm = use_llvm,
        .use_lld = use_lld,
    });

    const serve_exe_install = b.addInstallArtifact(serve_exe, .{});
    serve_exe_install.step.dependOn(&render_run.step);

    const serve_run = b.addRunArtifact(serve_exe);
    serve_run.step.dependOn(&serve_exe_install.step);

    const serve_step = b.step("serve", "serve the site");
    serve_step.dependOn(&serve_run.step);

    if (b.args) |args| serve_run.addArgs(args);

    b.getInstallStep().dependOn(&serve_exe_install.step);
}
