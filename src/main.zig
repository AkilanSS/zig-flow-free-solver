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
    const level_choice: u8 = 1;
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
    for (0..26) |i| {
        try colorMap.put(
            @intCast(i),
            rl.Color{
                .r = @intCast(rl.getRandomValue(0, 255)),
                .g = @intCast(rl.getRandomValue(0, 255)),
                .b = @intCast(rl.getRandomValue(0, 255)),
                .a = 255,
            },
        );
    }

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
        rl.clearBackground(.white);
    }
}

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
