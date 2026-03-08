const std = @import("std");

pub const Cell = struct {
    isTerminal: bool,
    color: i8,
    hasPipe: bool,
    id: i8,
};

pub const CellIndex = struct {
    i: i32,
    j: i32,
    color: i8,

    pub fn fix(self: *CellIndex) void {
        std.mem.swap(i32, &self.i, &self.j);
    }
};

//{ .{ .i = 4, .j = 0, .color = 1 }, .{ .i = 3, .j = 0, .color = 1 }, .{ .i = 2, .j = 0, .color = 1 }, .{ .i = 1, .j = 0, .color = 1 }, .{ .i = 0, .j = 0, .color = 1 }, .{ .i = 0, .j = 1, .color = 1 }, .{ .i = 0, .j = 2, .color = 1 }, .{ .i = 0, .j = 3, .color = 1 }, .{ .i = 0, .j = 4, .color = 1 }, .{ .i = 0, .j = 5, .color = 1 }, .{ .i = 1, .j = 5, .color = 1 }, .{ .i = 2, .j = 5, .color = 1 }, .{ .i = 2, .j = 5, .color = 1 } }
//{ .{ .i = 4, .j = 0, .color = 1 }, .{ .i = 3, .j = 0, .color = 1 }, .{ .i = 2, .j = 0, .color = 1 }, .{ .i = 1, .j = 0, .color = 1 }, .{ .i = 0, .j = 0, .color = 1 }, .{ .i = 0, .j = 1, .color = 1 }, .{ .i = 0, .j = 2, .color = 1 }, .{ .i = 0, .j = 3, .color = 1 }, .{ .i = 0, .j = 4, .color = 1 }, .{ .i = 0, .j = 5, .color = 1 }, .{ .i = 1, .j = 5, .color = 1 }, .{ .i = 2, .j = 5, .color = 1 } }
//{ .{ .i = 4, .j = 0, .color = 1 }, .{ .i = 3, .j = 0, .color = 1 }, .{ .i = 2, .j = 0, .color = 1 }, .{ .i = 1, .j = 0, .color = 1 }, .{ .i = 0, .j = 0, .color = 1 }, .{ .i = 0, .j = 1, .color = 1 }, .{ .i = 0, .j = 2, .color = 1 }, .{ .i = 0, .j = 3, .color = 1 }, .{ .i = 0, .j = 4, .color = 1 }, .{ .i = 0, .j = 5, .color = 1 }, .{ .i = 1, .j = 5, .color = 1 }, .{ .i = 2, .j = 5, .color = 1 }, .{ .i = 5, .j = 0, .color = 1 } }
