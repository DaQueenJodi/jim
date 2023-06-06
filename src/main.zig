const std = @import("std");
const zui = @import("zui");
const fs = std.fs;
const Input = zui.Input;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const TuiWindow = zui.TuiWindow;
const TuiWriter = zui.TuiWriter;
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
    window: TuiWindow,
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
            .window = try TuiWindow.init(0, 0, 100, 50),
            .data = data,
            .lines = lines,
            .allocator = alloc
        };
    }
    pub fn deinit(self: *Self) void {
        self.allocator.free(self.data);
        self.lines.deinit();
    }
    pub fn draw(self: *Self, writer: *TuiWriter) !void {
        try self.window.draw(writer);
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
const Cursor = struct {
    x: usize,
    y: usize,
    constraint_x: usize,
    constraint_y: usize,
    const Self = @This();
    pub fn move(self: *Self, x: usize, y: usize) void {
        self.x = @min(self.constraint_x, x);
        self.y = @min(self.constraint_y, y);
    }
    pub fn down(self: *Self) void {
        self.y = @min(self.constraint_y, self.y + 1);
    }
    pub fn up(self: *Self) void {
        if (self.y > 0) self.y -= 1;
    }
    pub fn left(self: *Self) void {
        if (self.x > 0) self.x -= 1;
    }
    pub fn right (self: *Self) void {
        self.x = @min(self.constraint_x, self.x + 1);
    }
};
const JimCtx = struct {
    buffer: Buffer,
    cursor: Cursor,
    const Self = @This();
    pub fn fromFile(alloc: Allocator, path: []const u8) !Self {
        const buff = try Buffer.fromFile(alloc, path);
        return .{ 
            .buffer = buff,
            .cursor = .{
                .x = 0,
                .y = 0,
                .constraint_x = buff.window.size.x,
                .constraint_y = buff.window.size.y
            }
        };
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
    while (true) {
        jimctx.buffer.window.printAt(.{}, 0, 0, jimctx.buffer.data[0..jimctx.buffer.lines.items[5].end]);
        jimctx.buffer.window.buff[
            jimctx.buffer.window.coord_to_idx(
                jimctx.cursor.x,
                jimctx.cursor.y
            )
        ].attrs = .{ .reverse = true };
        try ctx.writer.clear();
        try jimctx.buffer.draw(&ctx.writer);
        try ctx.writer.flush();
        const input = try ctx.get_input();
        const eql = std.meta.eql;
        if (eql(input, Input.fromStr("C-q"))) break;
        if (eql(input, Input.fromStr("C-n"))) jimctx.cursor.down();
        if (eql(input, Input.fromStr("C-p"))) jimctx.cursor.up();
        if (eql(input, Input.fromStr("C-f"))) jimctx.cursor.right();
        if (eql(input, Input.fromStr("C-b"))) jimctx.cursor.left();
    }
    try ctx.stop();
}
