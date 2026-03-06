const std = @import("std");
const main = @import("main.zig");

pub fn solver(allocator: std.mem.Allocator, grid: [][]main.Cell) [][]main.CellIndex {
    const position_map = try getPositionMap(grid, allocator);
}

pub fn getPositionMap(grid: [][]const main.Cell, allocator: std.mem.Allocator) !std.AutoHashMap(u8, [2]@Vector(2, main.CellIndex)) {
    var position_map = std.AutoHashMap(u8, [2]@Vector(2, main.CellIndex)).init(allocator);
    errdefer position_map.deinit();

    for (grid, 0..) |row, r| {
        for (row, 0..) |cell, c| {
            if (cell.isTerminal) {
                const current_pos = @Vector(2, main.CellIndex){ @intCast(r), @intCast(c) };
                const gop = try position_map.getOrPut(cell.color);
                if (!gop.found_existing) {
                    gop.value_ptr.* = .{ current_pos, @Vector(2, main.CellIndex){ -1, -1 } };
                } else {
                    gop.value_ptr.*[1] = current_pos;
                }
            }
        }
    }
    return position_map;
}
