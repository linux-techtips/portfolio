const zmpl = @import("zmpl");
const zmd = @import("zmd");
const std = @import("std");

const log = std.log.scoped(.render);

pub const markdown_fragments = struct {
    pub fn block(allocator: std.mem.Allocator, node: zmd.Node) ![]const u8 {
        return try std.fmt.allocPrint(allocator,
            \\<pre><code class="language-{?s}">{s}</code></pre>
        , .{ node.meta, node.content });
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    std.fs.cwd().makeDir("static") catch {};
    var dir = try std.fs.cwd().openDir("static", .{});
    defer dir.close();

    var buffer = std.mem.zeroes([std.fs.max_path_bytes]u8);
    for (zmpl.Manifest.templates) |templ| {
        if (std.fs.path.dirname(templ.key)) |subdir| {
            dir.makeDir(subdir) catch {};
        }

        var data = zmpl.Data.init(allocator);
        defer data.deinit();

        const content = try templ.render(&data, null, null, &.{}, .{});

        const path = try std.fmt.bufPrintZ(&buffer, "{s}.html", .{templ.key});
        const file = try dir.createFile(path, .{});
        defer file.close();

        _ = try file.write(content);

        log.info("successfully rendered template to - {s}", .{path});
    }
}
