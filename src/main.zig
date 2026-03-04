const std = @import("std");
const rl = @import("raylib");
const cfg = @import("config.zig");

pub fn main() anyerror!void {
    const screenWidth = 1000;
    const screenHeight = 1000;

    const colorPink = rl.Color{ .r = 100, .g = 100, .b = 100, .a = 100 };
    _ = colorPink;

    rl.initWindow(screenWidth, screenHeight, "Flow Free Solver");
    defer rl.closeWindow();

    rl.setTargetFPS(60);
    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        defer rl.endDrawing();

        //Below code will draw the grid, based on config
        const x_center = cfg.WINDOW_WIDTH / 2;
        const y_center = cfg.WINDOW_LAYOUT_HEIGHT / 2;
        const grid_x_corner = x_center - cfg.GRID_SIZE * cfg.N / 2;
        const grid_y_corner = y_center - cfg.GRID_SIZE * cfg.N / 2;
        rl.drawRectangleV(rl.Vector2{ .x = grid_x_corner, .y = grid_y_corner }, rl.Vector2{ .x = cfg.GRID_SIZE * cfg.N, .y = cfg.GRID_SIZE * cfg.N }, .black);

        for (0..cfg.N) |i| {
            rl.drawLineEx(rl.Vector2{ .x = @floatFromInt(cfg.GRID_SIZE * i + grid_x_corner), .y = grid_y_corner }, rl.Vector2{ .x = @floatFromInt(cfg.GRID_SIZE * i + grid_x_corner), .y = @floatFromInt(grid_y_corner + cfg.N * cfg.GRID_SIZE) }, 1.0, .light_gray);
            rl.drawLineEx(rl.Vector2{ .y = @floatFromInt(cfg.GRID_SIZE * i + grid_y_corner), .x = grid_x_corner }, rl.Vector2{ .y = @floatFromInt(cfg.GRID_SIZE * i + grid_y_corner), .x = @floatFromInt(grid_x_corner + cfg.N * cfg.GRID_SIZE) }, 1.0, .light_gray);
        }
        rl.clearBackground(.white);
    }
}
