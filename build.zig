const std = @import("std");

pub fn build(b: *std.Build) !void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});

    const use_llvm = b.option(bool, "use_llvm", "use llvm?") orelse false;
    const use_lld = b.option(bool, "use_lld", "use lld?") orelse false;

    const httpz_dep = b.dependency("httpz", .{
        .optimize = optimize,
        .target = target,
    });

    const zmpl_dep = b.dependency("zmpl", .{
        .use_llvm = use_llvm,
        .optimize = optimize,
        .target = target,
        .zmpl_markdown_fragments = try genMarkdownFragments(b, "src/render.zig"),
    });

    const zmd_dep = b.dependency("zmd", .{
        .optimize = optimize,
        .target = target,
    });

    const zmpl_compile = zmpl_dep.builder.top_level_steps.get("compile").?;

    const render_exe = b.addExecutable(.{
        .name = "render",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/render.zig"),
            .optimize = optimize,
            .target = target,
            .imports = &.{
                .{ .name = "zmpl", .module = zmpl_dep.module("zmpl") },
                .{ .name = "zmd", .module = zmd_dep.module("zmd") },
            },
        }),
        .use_llvm = use_llvm,
        .use_lld = use_lld,
    });
    render_exe.step.dependOn(&zmpl_compile.step);

    const render_exe_install = b.addInstallArtifact(render_exe, .{});

    const render_run = b.addRunArtifact(render_exe);
    render_run.step.dependOn(&render_exe_install.step);

    const render_step = b.step("render", "render the site");
    render_step.dependOn(&render_run.step);

    if (b.args) |args| render_run.addArgs(args);

    const serve_exe = b.addExecutable(.{
        .name = "serve",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/serve.zig"),
            .optimize = optimize,
            .target = target,
            .imports = &.{
                .{ .name = "httpz", .module = httpz_dep.module("httpz") },
            },
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

fn genMarkdownFragments(b: *std.Build, path: []const u8) ![]const u8 {
    const file = std.fs.cwd().openFile(path, .{}) catch |err| switch (err) {
        error.FileNotFound => return "",
        else => return err,
    };

    const stat = try file.stat();
    const source = try file.readToEndAllocOptions(b.allocator, @intCast(stat.size), null, .of(u8), 0);

    if (try getMarkdownFragmentSource(b.allocator, source[0.. :0])) |fragments| {
        return std.fmt.allocPrint(b.allocator,
            \\const std = @import("std");
            \\const zmd = @import("zmd");
            \\
            \\{s};
            \\
        , .{fragments});
    }

    return "";
}

fn getMarkdownFragmentSource(allocator: std.mem.Allocator, source: [:0]const u8) !?[]const u8 {
    var ast = try std.zig.Ast.parse(allocator, source, .zig);
    defer ast.deinit(allocator);

    search: for (ast.nodes.items(.tag), 0..) |tag, i| {
        switch (tag) {
            .simple_var_decl => {
                const decl = ast.simpleVarDecl(@enumFromInt(i));
                const ident = ast.tokenSlice(decl.ast.mut_token + 1);
                if (std.mem.eql(u8, ident, "markdown_fragments")) return ast.getNodeSource(@enumFromInt(i));
            },
            else => continue :search,
        }
    }

    return null;
}
