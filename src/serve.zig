const httpz = @import("httpz");
const std = @import("std");

const log = std.log.scoped(.server);

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    var handler = try Handler.init("static");
    defer handler.deinit();

    var server = try httpz.Server(*Handler).init(allocator, .{ .port = 3000 }, &handler);
    defer {
        server.stop();
        server.deinit();
    }

    log.debug("listening...", .{});

    try server.listen();
}

const Handler = struct {
    dir: std.fs.Dir,

    pub fn init(path: []const u8) !Handler {
        std.fs.cwd().makeDir(path) catch {};
        return .{ .dir = try std.fs.cwd().openDir(path, .{}) };
    }

    pub fn deinit(handler: *Handler) void {
        handler.dir.close();
    }

    pub fn notFound(_: *Handler, _: *httpz.Request, res: *httpz.Response) void {
        res.status = 404;
        res.body = "Not Found";
    }

    pub fn uncaughtError(_: *Handler, req: *httpz.Request, res: *httpz.Response, err: anyerror) void {
        log.debug("uncaught http errror at {s}: {}\n", .{ req.url.path, err });

        res.content_type = .HTML;
        res.status = 505;
        res.body = "<!DOCTYPE html>(╯°□°)╯︵ ┻━┻";
    }

    pub fn handle(handler: *Handler, req: *httpz.Request, res: *httpz.Response) void {
        const file = handler.dir.openFile(req.url.path[1..], .{}) catch |err| switch (err) {
            error.FileNotFound => return notFound(handler, req, res),
            else => return uncaughtError(handler, req, res, err),
        };
        defer file.close();

        const content = file.readToEndAlloc(res.arena, std.math.maxInt(u32)) catch |err| {
            return uncaughtError(handler, req, res, err);
        };

        res.content_type = .HTML;
        res.body = content;
    }
};
