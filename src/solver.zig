const std = @import("std");
const main = @import("main.zig");
const cfg = @import("config.zig");

pub fn solver(allocator: std.mem.Allocator, grid: [][]main.Cell, path_map: std.AutoArrayHashMap(u8, std.ArrayList(main.CellIndex)), heads: std.AutoArrayHashMap(u8, main.CellIndex), cells_filled: u8) std.AutoArrayHashMap(u8, std.ArrayList(main.CellIndex)) {
    if (cells_filled == cfg.N ** 2) return path_map;

    //Backtracking goes her
    for (heads.keys(), heads.values()) |color, cell| {
        std.debug.print("{any}\n", path_map);
        const next_move = getNextMove(cell);
        for (next_move) |move| {
            if (grid[move.i][move.j].hasPipe || grid[move.i][move.j].isTerminal) continue;
            //Update grid state
            grid[move.i][move.j].color = color;
            grid[move.i][move.j].hasPipe = true;
            grid[move.i][move.j].id = grid[cell.i][cell.j].id;

            path_map[color].append(allocator, move);
            heads[color] = move;
            solver(allocator, grid, path_map, heads, cells_filled - 1);

            //Backtrack
            grid[move.i][move.j].color = -1;
            grid[move.i][move.j].hasPipe = false;
            grid[move.i][move.j].id = -1;
        }
    }

    //const position_map = try getPositionMap(grid, allocator);
}

fn getPositionMap(grid: [][]const main.Cell, allocator: std.mem.Allocator) !std.AutoHashMap(u8, [2]@Vector(2, main.CellIndex)) {
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

fn getNextMove(curr_cell: main.CellIndex) [4]main.CellIndex {
    const x = curr_cell.i;
    const y = curr_cell.j;
    const color = curr_cell.color;

    return [4]main.CellIndex{
        main.CellIndex{
            .x = x + 1, //Move Right
            .y = y,
            .color = color,
        },
        main.CellIndex{
            .x = x - 1, //Move Left
            .y = y,
            .color = color,
        },
        main.CellIndex{
            .x = x,
            .y = y + 1, //Move Down
            .color = color,
        },
        main.CellIndex{
            .x = x,
            .y = y - 1, //Move Top
            .color = color,
        },
    };
}
