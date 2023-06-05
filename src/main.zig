const std = @import("std");
const zui = @import("zui");
const fs = std.fs;
const Input = zui.Input;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const TuiWindow = zui.TuiWindow;
fn read_file(alloc: Allocator, path: []const u8) ![]u8 {
    const file = try fs.cwd().openFile(path, .{});
    defer file.close();
    const size = try file.getEndPos();
    const buff: []u8 = try alloc.alloc(u8, size);
    _ = try file.read(buff);
    return buff;
}

const Line = struct {
    start: usize,
    end: usize
};
const Buffer = struct {
    data: []u8,
    lines: ArrayList(Line),
    allocator: Allocator,
    const Self = @This();
    pub fn fromFile(alloc: Allocator, path: []const u8) !Self {
        const data = try read_file(alloc, path);
        var lines = ArrayList(Line).init(alloc);
        for (data, 0..) |c, i| {
            if (c == '\n') {
                const lastLine = lines.getLastOrNull();
                var start: usize = undefined;
                if (lastLine) |line| {
                    start = line.end + 1;
                } else {
                    start = 0;
                }
                const end = i;
                try lines.append( .{ .start = start, .end = end } );
            }
        }
        return .{ 
            .data = data,
            .lines = lines,
            .allocator = alloc
        };
    }
    pub fn deinit(self: *Self) void {
        self.allocator.free(self.data);
        self.lines.deinit();
    }
};

fn digit_count(comptime T: type, int: T) usize {
    var num = int;
    comptime std.debug.assert(@typeInfo(T) == .Int);
    var length: usize = 0;
    while (num > 0) : (num /= 10)  {
        length += 1;
    }
    return length;
}

const JimCtx = struct {
    buffer: Buffer,
    cursor: @Vector(2, usize),
    const Self = @This();
    pub fn fromFile(alloc: Allocator, path: []const u8) !Self {
        return .{ .buffer = try Buffer.fromFile(alloc, path), .cursor = .{ 0, 0 } };
    }
    pub fn deinit(self: *Self) void {
        self.buffer.deinit();
    }
};
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    var jimctx = try JimCtx.fromFile(allocator, "src/main.zig");
    defer jimctx.deinit();
    var ctx = try zui.TuiCtx.init(allocator);
    defer ctx.deinit();
    try ctx.start();
    var window = try TuiWindow.init(allocator, 30, 10, 100, 100);
    defer window.deinit();
    try ctx.add_window(window);
    window.printAt(.{}, 0, 0, jimctx.buffer.data[0..jimctx.buffer.lines.items[50].end]);
    window.buff[0].attrs = .{ .bold = true };
    window.buff[1].attrs = .{ .bold = false };
    try ctx.draw_windows();
    while (true) {
        const input = try ctx.get_input();
        if (std.meta.eql(input, Input.fromStr("C-q"))) break;
        if (std.meta.eql(input, Input.fromStr("C-n"))) jimctx.cursor[1] += 1;
        if (std.meta.eql(input, Input.fromStr("C-p"))) jimctx.cursor[1] -= 1;
        if (std.meta.eql(input, Input.fromStr("C-f"))) jimctx.cursor[0] += 1;
        if (std.meta.eql(input, Input.fromStr("C-b"))) jimctx.cursor[0] -= 1;
    }
    try ctx.stop();
}
