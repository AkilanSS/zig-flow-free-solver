const std = @import("std");
const rl = @import("raylib");
const rg = @import("raygui");
const cfg = @import("config.zig");

const Cell = struct {
    isTerminal: bool,
    color: u8,
    hasPipe: bool,
    id: i8,
};

const CellIndex = struct {
    i: u8,
    j: u8,
    color: u8,
};

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
    const level_choice: u8 = 2;
    var file_buffer: [1024]u8 = undefined;
    const level_file = fd_array.items[level_choice];

    var file_reader = level_file.reader(&file_buffer);
    const grid = try parseBoard(&file_reader, allocator);
    std.debug.print("{any}\n", .{grid});

    defer {
        for (grid) |row| allocator.free(row);
        allocator.free(grid);
    }

    var colorMap = std.AutoArrayHashMap(u8, rl.Color).init(allocator);
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

    cfg.N = grid[0].len;
    const total_size = cfg.GRID_SIZE * @as(f32, @floatFromInt(cfg.N));
    const x_center = cfg.WINDOW_WIDTH / 2.0;
    const y_center = cfg.WINDOW_LAYOUT_HEIGHT / 2.0;
    const grid_x_corner: f32 = x_center - cfg.GRID_SIZE * @as(f32, @floatFromInt(cfg.N)) / 2.0;
    const grid_y_corner: f32 = y_center - cfg.GRID_SIZE * @as(f32, @floatFromInt(cfg.N)) / 2.0;

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
                if (cell.color == 0) continue;
                const offset_x = @as(f32, @floatFromInt(j)) * cfg.GRID_SIZE;
                const offset_y = @as(f32, @floatFromInt(i)) * cfg.GRID_SIZE;
                rl.drawCircleV(rl.Vector2{ .x = grid_x_corner + offset_x + cfg.GRID_SIZE / 2.0, .y = grid_y_corner + offset_y + cfg.GRID_SIZE / 2 }, 20, colorMap.get(cell.color).?);
            }
        }

        //Test render path
        var temp_move: [6]CellIndex = [6]CellIndex{ CellIndex{ .i = 0, .j = 0, .color = 2 }, CellIndex{ .i = 1, .j = 0, .color = 2 }, CellIndex{ .i = 2, .j = 0, .color = 2 }, CellIndex{ .i = 3, .j = 0, .color = 2 }, CellIndex{ .i = 3, .j = 1, .color = 2 }, CellIndex{ .i = 2, .j = 1, .color = 2 } };
        renderPath(&temp_move, grid, grid_x_corner, grid_y_corner, colorMap);

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
            if (fixed_cell.len != 0) {
                try row_arr.append(allocator, .{
                    .color = try std.fmt.parseInt(u8, fixed_cell, 10),
                    .hasPipe = false,
                    .isTerminal = true,
                    .id = -1,
                });
            }
        }
        try grid.append(allocator, try row_arr.toOwnedSlice(allocator));
    }
    return try grid.toOwnedSlice(allocator);
}

/// Takes a array of CellIndex, and draws a path along the indices
fn renderPath(path: []CellIndex, grid: [][]Cell, grid_x_corner: f32, grid_y_corner: f32, colorMap: anytype) void {
    _ = grid;
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
        } else if (pipe_orientation == 3) {
            rl.drawRectangleV(rl.Vector2{
                .x = prev_cell_coords[0] - 10,
                .y = prev_cell_coords[1],
            }, rl.Vector2{
                .x = 20,
                .y = cfg.GRID_SIZE / 2.0,
            }, colorMap.get(path[i].color).?);

            rl.drawRectangleV(rl.Vector2{
                .x = next_cell_coords[0] - 10,
                .y = next_cell_coords[1] - cfg.GRID_SIZE / 2.0,
            }, rl.Vector2{
                .x = 20,
                .y = cfg.GRID_SIZE / 2.0,
            }, colorMap.get(path[i].color).?);
        } else if (pipe_orientation == 4) {
            rl.drawRectangleV(rl.Vector2{
                .x = next_cell_coords[0] - 10,
                .y = next_cell_coords[1],
            }, rl.Vector2{
                .x = 20,
                .y = cfg.GRID_SIZE / 2.0,
            }, colorMap.get(path[i].color).?);

            rl.drawRectangleV(rl.Vector2{
                .x = prev_cell_coords[0] - 10,
                .y = prev_cell_coords[1] - cfg.GRID_SIZE / 2.0,
            }, rl.Vector2{
                .x = 20,
                .y = cfg.GRID_SIZE / 2.0,
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
