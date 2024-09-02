const std = @import("std");

pub const Rom = struct {
    bytes: []u8,

    pub fn load(path: []const u8) !Rom {
        const cwd: std.fs.Dir = std.fs.cwd();
        var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        const allocator = gpa.allocator();

        var file = try cwd.openFile(path, .{});
        defer file.close();

        const read_buf = try file.readToEndAlloc(allocator, 4096);

        return Rom{ .bytes = read_buf };
    }

    pub fn getBytes(self: *const Rom) []u8 {
        return self.bytes;
    }
};
