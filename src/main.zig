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
        const total_size = cfg.GRID_SIZE * @as(f32, @floatFromInt(cfg.N));
        const x_center = cfg.WINDOW_WIDTH / 2.0;
        const y_center = cfg.WINDOW_LAYOUT_HEIGHT / 2.0;
        const grid_x_corner: f32 = x_center - cfg.GRID_SIZE * cfg.N / 2.0;
        const grid_y_corner: f32 = y_center - cfg.GRID_SIZE * cfg.N / 2.0;

        rl.drawRectangleV(rl.Vector2{ .x = grid_x_corner, .y = grid_y_corner }, rl.Vector2{ .x = total_size, .y = total_size }, .black);

        for (0..cfg.N) |i| {
            const offset = @as(f32, @floatFromInt(i)) * cfg.GRID_SIZE;
            rl.drawLineEx(.{ .x = grid_x_corner + offset, .y = grid_y_corner }, .{ .x = grid_x_corner + offset, .y = grid_y_corner + total_size }, 1.0, .light_gray);
            rl.drawLineEx(.{ .x = grid_x_corner, .y = grid_y_corner + offset }, .{ .x = grid_x_corner + total_size, .y = grid_y_corner + offset }, 1.0, .light_gray);
        }
        //Render logic for displaying the grid ends here

        rl.clearBackground(.white);
    }
}
