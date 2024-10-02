const std = @import("std");

pub const PathInstruct = struct {
    instruction: []const u8,
    fpath: []const u8,
};

pub fn splitroute(str: []const u8) !PathInstruct {
    var instruction: []const u8 = undefined;
    var fpath: []const u8 = undefined;

    for (1..str.len) |i| {
        const c = str[i];
        if (c == ' ') {
            break;
        }

        if (c == '/') {
            instruction = str[1..i];
            fpath = str[i + 1 ..];
            break;
        }
    }

    return PathInstruct{ .instruction = instruction, .fpath = fpath };
}

pub const DirFile = struct {
    dir: []const u8,
    file: []const u8,
};

pub fn split_path(path: []const u8) !DirFile {
    var last_slash: usize = 0;

    for (0..path.len) |i| {
        const c = path[i];
        if (c == '/') {
            last_slash = i;
        }
    }

    if (last_slash == 0) {
        return DirFile{ .dir = "", .file = path };
    }
    return DirFile{ .dir = path[0..last_slash], .file = path[last_slash + 1 ..] };
}

pub fn check_instruct(instruction: []const u8) bool {
    const valid = [_][]const u8{
        "upload",
        "download",
        "delete",
    };

    for (valid) |v| {
        if (std.mem.eql(u8, v, instruction)) {
            return true;
        }
    }

    return false;
}
