const std = @import("std");
const zap = @import("zap");

const zstore = @import("zstore.zig");

const Result = struct {
    read: usize,
    written: usize,
    status: []const u8,
};

fn upload_file(blob: []const u8, pathins: zstore.PathInstruct) !void {
    const cwd = std.fs.cwd();
    const dir_file = try zstore.split_path(pathins.fpath);
    try cwd.makePath(dir_file.dir);

    const file = try cwd.createFile(pathins.fpath, .{});
    defer file.close();

    const bytes_written = try file.writeAll(blob);
    _ = bytes_written;

    std.log.info("File written: {s}\n", .{pathins.fpath});
}

pub fn download_file(allocator: std.mem.Allocator, path: []const u8) ![]const u8 {
    std.log.info("Attempting to download file: {s}", .{path});

    var file = std.fs.cwd().openFile(path, .{}) catch |err| {
        std.log.err("Failed to open file: {s}. Error: {}", .{ path, err });
        return err;
    };
    defer file.close();

    const file_size = file.getEndPos() catch |err| {
        std.log.err("Failed to get file size for: {s}. Error: {}", .{ path, err });
        return err;
    };

    if (file_size == 0) {
        std.log.warn("File is empty: {s}", .{path});
        return error.EmptyFile;
    }

    std.log.info("File size: {d} bytes", .{file_size});

    const buffer = allocator.alloc(u8, file_size) catch |err| {
        std.log.err("Failed to allocate buffer of size {d} for file: {s}. Error: {}", .{ file_size, path, err });
        return err;
    };
    errdefer allocator.free(buffer);

    const bytes_read = file.readAll(buffer) catch |err| {
        std.log.err("Failed to read file: {s}. Error: {}", .{ path, err });
        return err;
    };

    if (bytes_read != file_size) {
        std.log.err("Incomplete read: expected {d} bytes, got {d} bytes", .{ file_size, bytes_read });
        return error.IncompleteRead;
    }

    std.log.info("Successfully downloaded file: {s}. Size: {d} bytes", .{ path, bytes_read });

    return buffer;
}

fn delete_file(path: []const u8) !void {
    const cwd = std.fs.cwd();
    try cwd.deleteFile(path);
}

fn on_request_verbose(r: zap.Request) void {
    var msg: []const u8 = undefined;
    if (r.path) |the_path| {
        if (the_path.len < 8) {
            std.log.err("NO PATH\n", .{});
            msg = "No path";
        } else {
            std.log.info("PATH: {s}\n", .{the_path});
            const pathins = try zstore.splitroute(the_path);
            std.log.info("INSTRUCTION: {s}\n", .{pathins.instruction});
            std.log.info("FPATH: {s}\n", .{pathins.fpath});

            if (!zstore.check_instruct(pathins.instruction)) {
                std.log.err("INVALID INSTRUCTION\n", .{});
                msg = "Invalid API";
            } else {
                if (std.mem.eql(u8, pathins.instruction, "upload")) {
                    std.log.info("UPLOAD\n", .{});
                    if (r.body) |body| {
                        std.log.info("Body: {d}\n", .{body.len});
                        msg = "OK, Image Uploaded";
                        upload_file(body, pathins) catch |err| {
                            std.log.err("Upload error: {any}", .{err});
                            msg = "Upload error";
                        };
                    } else {
                        std.log.info("Body is empty\n", .{});
                        msg = "Empty data";
                    }
                } else if (std.mem.eql(u8, pathins.instruction, "download")) {
                    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
                    defer _ = gpa.deinit();
                    var allocator = gpa.allocator();

                    std.log.info("DOWNLOAD\n", .{});
                    const blob = download_file(allocator, pathins.fpath) catch |err| {
                        std.log.err("Download error: {any}", .{err});
                        msg = "Download error";
                        return;
                    };
                    defer allocator.free(blob);

                    r.sendBody(blob) catch |err| {
                        std.log.err("Download error: {any}", .{err});
                        msg = "Download error";
                    };
                } else if (std.mem.eql(u8, pathins.instruction, "delete")) {
                    std.log.info("DELETE\n", .{});
                    msg = "OK, Image Deleted";
                    delete_file(pathins.fpath) catch |err| {
                        std.log.err("Delete error: {any}", .{err});
                        msg = "Delete error";
                    };
                }
            }
        }
    } else {
        std.log.err("NO PATH\n", .{});
        msg = "No path";
    }

    r.sendJson(msg) catch return;
}

pub fn main() !void {
    var listener = zap.HttpListener.init(.{
        .port = 3000,
        .on_request = on_request_verbose,
        .log = true,
        .max_clients = 100000,
        .max_body_size = 250 * 1024 * 1024,
    });
    try listener.listen();

    std.log.info("Listening on 0.0.0.0:3000\n", .{});

    // start worker threads
    zap.start(.{
        .threads = 2,
        .workers = 2,
    });
}
