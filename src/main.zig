const std = @import("std");
const rl = @import("raylib");
const rg = @import("raygui");
const cfg = @import("config.zig");
const solver = @import("solver.zig");
const types = @import("types.zig");

const Cell = types.Cell;
const CellIndex = types.CellIndex;

pub fn main() anyerror!void {
    var stdout_buf: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buf);
    const stdout = &stdout_writer.interface;
    _ = stdout;

    var level_dir = try std.fs.cwd().openDir("./levels/", .{ .iterate = true });
    defer std.fs.Dir.close(&level_dir);
    var level_dir_iterator = level_dir.iterate();

    var dba = std.heap.DebugAllocator(.{}){};
    defer _ = dba.deinit();
    const allocator = dba.allocator();

    var fd_array = std.ArrayList(std.fs.File).empty;
    defer fd_array.deinit(allocator);
    defer for (fd_array.items) |f| f.close();
    var level_count: u8 = 0;
    while (try level_dir_iterator.next()) |entry| {
        if (entry.kind == .file) {
            level_count += 1;
            const file = try level_dir.openFile(entry.name, .{ .mode = .read_only });
            try fd_array.append(allocator, file);
        }
    }

    //Read the chosen level, and put it in an array
    const level_choice: u8 = 0;
    var file_buffer: [1024]u8 = undefined;
    const level_file = fd_array.items[level_choice];

    var file_reader = level_file.reader(&file_buffer);
    var grid = try parseBoard(&file_reader, allocator);
    // std.debug.print("{any}\n", .{grid});
    _ = &grid;
    defer {
        for (grid) |row| allocator.free(row);
        allocator.free(grid);
    }

    var colorMap = std.AutoArrayHashMap(i8, rl.Color).init(allocator);
    defer colorMap.deinit();
    try colorMap.put(0, rl.Color{ .r = 255, .g = 105, .b = 180, .a = 255 }); // Hot Pink
    try colorMap.put(1, rl.Color{ .r = 147, .g = 112, .b = 219, .a = 255 }); // Medium Purple
    try colorMap.put(2, rl.Color{ .r = 255, .g = 20, .b = 147, .a = 255 }); // Deep Pink
    try colorMap.put(3, rl.Color{ .r = 75, .g = 0, .b = 130, .a = 255 }); // Indigo
    try colorMap.put(4, rl.Color{ .r = 238, .g = 130, .b = 238, .a = 255 }); // Violet
    try colorMap.put(5, rl.Color{ .r = 255, .g = 192, .b = 203, .a = 255 }); // Pink
    try colorMap.put(6, rl.Color{ .r = 139, .g = 69, .b = 19, .a = 255 }); // Saddle Brown
    try colorMap.put(7, rl.Color{ .r = 210, .g = 180, .b = 140, .a = 255 }); // Tan
    try colorMap.put(8, rl.Color{ .r = 160, .g = 82, .b = 45, .a = 255 }); // Sienna
    try colorMap.put(9, rl.Color{ .r = 121, .g = 85, .b = 72, .a = 255 }); // Umber
    try colorMap.put(10, rl.Color{ .r = 222, .g = 184, .b = 135, .a = 255 }); // Burly Wood
    try colorMap.put(11, rl.Color{ .r = 93, .g = 64, .b = 55, .a = 255 }); // Coffee
    try colorMap.put(12, rl.Color{ .r = 230, .g = 0, .b = 0, .a = 255 }); // Bright Red
    try colorMap.put(13, rl.Color{ .r = 255, .g = 69, .b = 0, .a = 255 }); // Orange Red
    try colorMap.put(14, rl.Color{ .r = 128, .g = 0, .b = 0, .a = 255 }); // Maroon
    try colorMap.put(15, rl.Color{ .r = 255, .g = 127, .b = 80, .a = 255 }); // Coral
    try colorMap.put(16, rl.Color{ .r = 178, .g = 34, .b = 34, .a = 255 }); // Firebrick
    try colorMap.put(17, rl.Color{ .r = 255, .g = 99, .b = 71, .a = 255 }); // Tomato
    try colorMap.put(18, rl.Color{ .r = 255, .g = 255, .b = 0, .a = 255 }); // Pure Yellow
    try colorMap.put(19, rl.Color{ .r = 255, .g = 215, .b = 0, .a = 255 }); // Gold
    try colorMap.put(20, rl.Color{ .r = 173, .g = 255, .b = 47, .a = 255 }); // Green Yellow
    try colorMap.put(21, rl.Color{ .r = 240, .g = 230, .b = 140, .a = 255 }); // Khaki
    try colorMap.put(22, rl.Color{ .r = 0, .g = 255, .b = 0, .a = 255 }); // Lime
    try colorMap.put(23, rl.Color{ .r = 189, .g = 183, .b = 107, .a = 255 }); // Dark Khaki
    try colorMap.put(24, rl.Color{ .r = 0, .g = 255, .b = 255, .a = 255 }); // Cyan
    try colorMap.put(25, rl.Color{ .r = 255, .g = 255, .b = 255, .a = 255 }); // White

    var position_map = try getPositionMap(grid, allocator);
    var target_map = std.AutoArrayHashMap(i8, CellIndex).init(allocator);
    var curr_head = std.AutoArrayHashMap(i8, CellIndex).init(allocator);
    var source_map = std.AutoArrayHashMap(i8, CellIndex).init(allocator);
    defer target_map.deinit();
    defer curr_head.deinit();
    defer position_map.deinit();
    defer source_map.deinit();

    var map_path = std.AutoArrayHashMap(i8, std.ArrayListUnmanaged(CellIndex)).init(allocator);
    var terminal_count: u8 = 0;
    {
        var it = position_map.iterator();
        while (it.next()) |entry| {
            if (entry.key_ptr.* == -1) continue;

            terminal_count += 2;

            try target_map.put(entry.key_ptr.*, entry.value_ptr.*[1]);
            try curr_head.put(entry.key_ptr.*, entry.value_ptr.*[0]);
            try source_map.put(entry.key_ptr.*, entry.value_ptr.*[0]);
            try map_path.put(entry.key_ptr.*, std.ArrayListUnmanaged(CellIndex).empty);
        }
    }

    defer {
        var path_it = map_path.iterator();
        while (path_it.next()) |entry| entry.value_ptr.deinit(allocator);
        map_path.deinit();
    }
    cfg.N = grid[0].len;
    const total_size = cfg.GRID_SIZE * @as(f32, @floatFromInt(cfg.N));
    const x_center = cfg.WINDOW_WIDTH / 2.0;
    const y_center = cfg.WINDOW_LAYOUT_HEIGHT / 2.0;
    const grid_x_corner: f32 = x_center - cfg.GRID_SIZE * @as(f32, @floatFromInt(cfg.N)) / 2.0;
    const grid_y_corner: f32 = y_center - cfg.GRID_SIZE * @as(f32, @floatFromInt(cfg.N)) / 2.0;

    for (grid) |row| {
        for (row) |cell| {
            if (cell.color == -1) std.debug.print(". ", .{}) else std.debug.print("{} ", .{cell.color});
        }
        std.debug.print("\n", .{});
    }

    var all_solved_path = std.ArrayList(std.AutoArrayHashMap(i8, std.ArrayList(CellIndex))).empty;
    defer {
        for (all_solved_path.items) |*map| {
            var map_it = map.iterator();
            while (map_it.next()) |entry| {
                entry.value_ptr.deinit(allocator);
            }
            map.deinit();
        }
        all_solved_path.deinit(allocator);
    }

    const solved_path = try solve(allocator, grid, &curr_head, target_map, &map_path, terminal_count, &all_solved_path);
    if (all_solved_path.items.len == 0) {
        std.debug.print("Nop\n", .{});
        return;
    }
    _ = solved_path;

    std.debug.print("{any}\n", .{all_solved_path.items.len});

    const one_path = getMaxPath(all_solved_path);

    {
        var it = one_path.iterator();
        while (it.next()) |entry| {
            try one_path.getPtr(entry.key_ptr.*).?.insert(allocator, 0, source_map.get(entry.key_ptr.*).?);
            for (entry.value_ptr.items) |*cell| {
                cell.fix();
            }
        }
    }

    // for (all_solved_path.items) |path| {
    //     std.debug.print("{any}\n", .{path.get(1).?.items});
    // }

    std.debug.print("{d}\n", .{all_solved_path.capacity});

    rl.initWindow(cfg.WINDOW_WIDTH, cfg.WINDOW_HEIGHT, "Flow Free Solver");
    defer rl.closeWindow();
    rl.setTargetFPS(60);

    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        defer rl.endDrawing();
        //Below code will draw the grid, based on config
        rl.drawRectangleV(rl.Vector2{ .x = grid_x_corner, .y = grid_y_corner }, rl.Vector2{ .x = total_size, .y = total_size }, .black);
        for (0..cfg.N) |i| {
            const offset = @as(f32, @floatFromInt(i)) * cfg.GRID_SIZE;
            rl.drawLineEx(.{ .x = grid_x_corner + offset, .y = grid_y_corner }, .{ .x = grid_x_corner + offset, .y = grid_y_corner + total_size }, 1.0, .light_gray);
            rl.drawLineEx(.{ .x = grid_x_corner, .y = grid_y_corner + offset }, .{ .x = grid_x_corner + total_size, .y = grid_y_corner + offset }, 1.0, .light_gray);
        }

        //Below will draw the terminals in appropriate cells
        for (grid, 0..cfg.N) |row, i| {
            for (row, 0..cfg.N) |cell, j| {
                if (!cell.isTerminal) continue;
                const offset_x = @as(f32, @floatFromInt(j)) * cfg.GRID_SIZE;
                const offset_y = @as(f32, @floatFromInt(i)) * cfg.GRID_SIZE;
                rl.drawCircleV(rl.Vector2{ .x = grid_x_corner + offset_x + cfg.GRID_SIZE / 2.0, .y = grid_y_corner + offset_y + cfg.GRID_SIZE / 2 }, 20, colorMap.get(cell.color).?);
            }
        }

        //renderPath(&temp_move, grid, grid_x_corner, grid_y_corner, colorMap);

        var it = one_path.iterator();
        while (it.next()) |cell| {
            renderPath(cell.value_ptr.*.items, grid, grid_x_corner, grid_y_corner, colorMap);
        }

        rl.clearBackground(.white);
    }
}

/// Takes a reader to a CSV file containing the home state of a board, returns a [][]Cell
fn parseBoard(content: anytype, allocator: std.mem.Allocator) ![][]Cell {
    var grid = std.ArrayList([]Cell).empty;
    errdefer {
        for (grid.items) |row| allocator.free(row);
        grid.deinit(allocator);
    }
    while (try content.interface.takeDelimiter('\n')) |row| {
        var row_line = std.mem.splitScalar(u8, row, ',');
        var row_arr = std.ArrayList(Cell).empty;
        errdefer row_arr.deinit(allocator);

        while (row_line.next()) |cell| {
            const fixed_cell = std.mem.trim(u8, cell, &std.ascii.whitespace);
            //std.debug.print("{s}\n", .{cell});
            const raw_color = try std.fmt.parseInt(i8, fixed_cell, 10);
            // Normalize empty cells: if the CSV uses 0 for empty, force it to -1
            const final_color = if (raw_color == 0) -1 else raw_color;

            try row_arr.append(allocator, .{
                .color = final_color,
                .hasPipe = false,
                .isTerminal = final_color != -1,
                .id = -1,
            });
        }
        try grid.append(allocator, try row_arr.toOwnedSlice(allocator));
    }
    return try grid.toOwnedSlice(allocator);
}

/// Takes a array of CellIndex, and draws a path along the indices
fn renderPath(path: []CellIndex, grid: [][]Cell, grid_x_corner: f32, grid_y_corner: f32, colorMap: anytype) void {
    _ = grid;
    if (path.len < 2) return;
    for (1..path.len) |i| {
        const prev_cell = path[i - 1];
        const curr_cell = path[i];
        const pipe_orientation = getPipeOrientation(prev_cell, curr_cell);

        const prev_cell_coords = @Vector(2, f32){ grid_x_corner + @as(f32, @floatFromInt(prev_cell.i)) * cfg.GRID_SIZE + cfg.GRID_SIZE / 2.0, grid_y_corner + @as(f32, @floatFromInt(prev_cell.j)) * cfg.GRID_SIZE + cfg.GRID_SIZE / 2.0 };
        const next_cell_coords = @Vector(2, f32){ grid_x_corner + @as(f32, @floatFromInt(curr_cell.i)) * cfg.GRID_SIZE + cfg.GRID_SIZE / 2.0, grid_y_corner + @as(f32, @floatFromInt(curr_cell.j)) * cfg.GRID_SIZE + cfg.GRID_SIZE / 2.0 };

        //Below will now draw the pipe
        //Left to Right
        if (pipe_orientation == 1) {
            rl.drawRectangleV(rl.Vector2{
                .x = prev_cell_coords[0] - 10,
                .y = prev_cell_coords[1] - 10,
            }, rl.Vector2{
                .x = cfg.GRID_SIZE / 2.0 + 10,
                .y = 20,
            }, colorMap.get(path[i].color).?);

            rl.drawRectangleV(rl.Vector2{
                .x = next_cell_coords[0] - cfg.GRID_SIZE / 2.0,
                .y = next_cell_coords[1] - 10,
            }, rl.Vector2{
                .x = cfg.GRID_SIZE / 2.0 + 10,
                .y = 20,
            }, colorMap.get(path[i].color).?);
        } else if (pipe_orientation == 2) { //Right to Left
            rl.drawRectangleV(rl.Vector2{
                .x = next_cell_coords[0] - 10,
                .y = next_cell_coords[1] - 10,
            }, rl.Vector2{
                .x = cfg.GRID_SIZE / 2.0 + 10,
                .y = 20,
            }, colorMap.get(path[i].color).?);

            rl.drawRectangleV(rl.Vector2{
                .x = prev_cell_coords[0] - cfg.GRID_SIZE / 2.0,
                .y = prev_cell_coords[1] - 10,
            }, rl.Vector2{
                .x = cfg.GRID_SIZE / 2.0,
                .y = 20,
            }, colorMap.get(path[i].color).?);
        } else if (pipe_orientation == 3) { //Top to Bottom
            rl.drawRectangleV(rl.Vector2{
                .x = prev_cell_coords[0] - 10,
                .y = prev_cell_coords[1] - 10,
            }, rl.Vector2{
                .x = 20,
                .y = cfg.GRID_SIZE / 2.0 + 10,
            }, colorMap.get(path[i].color).?);

            rl.drawRectangleV(rl.Vector2{
                .x = next_cell_coords[0] - 10,
                .y = next_cell_coords[1] - cfg.GRID_SIZE / 2.0,
            }, rl.Vector2{
                .x = 20,
                .y = cfg.GRID_SIZE / 2.0 + 10,
            }, colorMap.get(path[i].color).?);
        } else if (pipe_orientation == 4) { //Bottom to Top
            rl.drawRectangleV(rl.Vector2{
                .x = next_cell_coords[0] - 10,
                .y = next_cell_coords[1] - 10,
            }, rl.Vector2{
                .x = 20,
                .y = cfg.GRID_SIZE / 2.0 + 10,
            }, colorMap.get(path[i].color).?);

            rl.drawRectangleV(rl.Vector2{
                .x = prev_cell_coords[0] - 10,
                .y = prev_cell_coords[1] - cfg.GRID_SIZE / 2.0,
            }, rl.Vector2{
                .x = 20,
                .y = cfg.GRID_SIZE / 2.0 + 10,
            }, colorMap.get(path[i].color).?);
        }
    }
}

fn getPipeOrientation(a: CellIndex, b: CellIndex) u8 {
    if (a.i < b.i) return 1; //Horizontal Pipe
    if (a.i > b.i) return 2;
    if (a.j < b.j) return 3; //Vertical Pipe
    if (a.j > b.j) return 4;

    return 0;
}

pub fn getPositionMap(grid: [][]types.Cell, allocator: std.mem.Allocator) !std.AutoHashMap(i8, [2]CellIndex) {
    var position_map = std.AutoHashMap(i8, [2]CellIndex).init(allocator);
    errdefer position_map.deinit();
    for (grid, 0..) |row, r| {
        for (row, 0..) |cell, c| {
            if (cell.isTerminal) {
                const current_pos = CellIndex{ .i = @intCast(r), .j = @intCast(c), .color = cell.color };
                const gop = try position_map.getOrPut(cell.color);
                if (!gop.found_existing) {
                    gop.value_ptr.* = .{ current_pos, CellIndex{ .i = -1, .j = -1, .color = cell.color } };
                } else {
                    gop.value_ptr.*[1] = current_pos;
                }
            }
        }
    }
    return position_map;
}

fn getNextMove(curr_cell: CellIndex) [4]CellIndex {
    const x = curr_cell.i;
    const y = curr_cell.j;
    const color = curr_cell.color;

    return [4]CellIndex{
        CellIndex{
            .i = x + 1, //Move Right
            .j = y,
            .color = color,
        },
        CellIndex{
            .i = x - 1, //Move Left
            .j = y,
            .color = color,
        },
        CellIndex{
            .i = x,
            .j = y + 1, //Move Down
            .color = color,
        },
        CellIndex{
            .i = x,
            .j = y - 1, //Move Top
            .color = color,
        },
    };
}

fn checkBounds(move: CellIndex) bool {
    if ((0 <= move.i and move.i < cfg.N) and (0 <= move.j and move.j < cfg.N)) return true;
    return false;
}

fn allow(move: CellIndex, grid: [][]Cell) bool {
    if (grid[@intCast(move.i)][@intCast(move.j)].color != -1) return false;
    return true;
}

fn solve(
    allocator: std.mem.Allocator,
    grid: [][]Cell,
    curr_head: *std.AutoArrayHashMap(i8, CellIndex),
    target_map: std.AutoArrayHashMap(i8, CellIndex),
    map_path: *std.AutoArrayHashMap(i8, std.ArrayListUnmanaged(CellIndex)),
    cells_filled: u8,
    all_map_path: *std.ArrayListUnmanaged(std.AutoArrayHashMap(i8, std.ArrayListUnmanaged(CellIndex))),
) !?*std.ArrayList(std.AutoArrayHashMap(i8, std.ArrayListUnmanaged(CellIndex))) {
    if (curr_head.count() == 0) {
        if (cells_filled == cfg.N * cfg.N) {
            var cloned_map = std.AutoArrayHashMap(i8, std.ArrayListUnmanaged(CellIndex)).init(allocator);

            var it = map_path.iterator();
            while (it.next()) |p_entry| {
                const cloned_list = try p_entry.value_ptr.clone(allocator);
                try cloned_map.put(p_entry.key_ptr.*, cloned_list);
            }
            try all_map_path.*.append(allocator, cloned_map);
        }
        return null;
    }

    if (hasDeadEnd(grid, curr_head, target_map)) {
        return null;
    }

    var it = curr_head.iterator();
    const entry = it.next() orelse return null;
    const color = entry.key_ptr.*;

    const curr_move = curr_head.get(color).?;
    const target = target_map.get(color).?;
    const path_list = map_path.getPtr(color).?;
    const all_next_move = getNextMove(curr_move);

    for (all_next_move) |next_move| {
        if (!checkBounds(next_move)) continue;

        // Reached the target terminal for this color
        if (next_move.i == target.i and next_move.j == target.j) {
            const removed = curr_head.fetchOrderedRemove(color).?;
            try path_list.append(allocator, next_move);
            _ = try solve(allocator, grid, curr_head, target_map, map_path, cells_filled, all_map_path);

            // Backtrack
            try curr_head.put(removed.key, removed.value);
            _ = path_list.pop();
            continue;
        }

        // Skip non-empty cells
        if (grid[@intCast(next_move.i)][@intCast(next_move.j)].color != -1) continue;

        const old_head = curr_head.get(color).?;
        grid[@intCast(next_move.i)][@intCast(next_move.j)].color = color;
        try path_list.append(allocator, next_move);
        try curr_head.put(color, next_move);

        _ = try solve(allocator, grid, curr_head, target_map, map_path, cells_filled + 1, all_map_path);

        // Backtrack
        grid[@intCast(next_move.i)][@intCast(next_move.j)].color = -1;
        try curr_head.put(color, old_head);
        _ = path_list.pop();
    }

    return null;
}

fn checkConnection(
    grid: [][]Cell,
    i: usize,
    j: usize,
    curr_head: *std.AutoArrayHashMap(i8, CellIndex),
    target_map: std.AutoArrayHashMap(i8, CellIndex),
) u8 {
    const color = grid[i][j].color;

    if (color == -1) return 1;

    if (curr_head.contains(color)) {
        const head = curr_head.get(color).?;
        const target = target_map.get(color).?;
        if ((head.i == i and head.j == j) or (target.i == i and target.j == j)) {
            return 1;
        }
    }
    return 0;
}

fn hasDeadEnd(
    grid: [][]Cell,
    curr_head: *std.AutoArrayHashMap(i8, CellIndex),
    target_map: std.AutoArrayHashMap(i8, CellIndex),
) bool {
    const N = cfg.N;
    for (0..N) |i| {
        for (0..N) |j| {
            if (grid[i][j].color != -1) continue;

            var valid_connections: u8 = 0;
            if (i > 0) valid_connections += checkConnection(grid, i - 1, j, curr_head, target_map);
            if (i < N - 1) valid_connections += checkConnection(grid, i + 1, j, curr_head, target_map);
            if (j > 0) valid_connections += checkConnection(grid, i, j - 1, curr_head, target_map);
            if (j < N - 1) valid_connections += checkConnection(grid, i, j + 1, curr_head, target_map);

            if (valid_connections < 2) return true;
        }
    }
    return false;
}

fn getMaxPath(all_solved_path: std.ArrayList(std.AutoArrayHashMap(i8, std.ArrayList(CellIndex)))) std.AutoArrayHashMap(i8, std.ArrayList(CellIndex)) {
    var maxNum: u16 = 0;
    var bestPath: std.AutoArrayHashMap(i8, std.ArrayList(CellIndex)) = all_solved_path.items[0];

    for (all_solved_path.items) |path| {
        const pathNum = findNumberOfBends(path);
        if (pathNum > maxNum) {
            maxNum = pathNum;
            bestPath = path;
        }
    }

    return bestPath;
}

fn findNumberOfBends(path: std.AutoArrayHashMap(i8, std.ArrayList(CellIndex))) u16 {
    var num: u16 = 0;
    var it = path.iterator();
    while (it.next()) |entry| {
        const path_array = entry.value_ptr.*;
        if (path_array.items.len < 3) continue;
        for (0..path_array.items.len - 2) |i| {
            if (isBend(path_array.items[i], path_array.items[i + 1], path_array.items[i + 2])) {
                num += 1;
            }
        }
    }
    return num;
}

fn isBend(a: CellIndex, b: CellIndex, c: CellIndex) bool {
    _ = b;
    return (a.i != c.i) and (a.j != c.j);
}
