const std = @import("std");
const raylib = @cImport(@cInclude("raylib.h"));

const emulator = @import("emulator.zig");
const screenbuffer = @import("screenbuffer.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var chip8 = try emulator.Chip8.init(&allocator);
    try chip8.loadRom("roms/IBM");

    createWindow(&chip8);

    // clean up
    emulator.destroy(chip8, &allocator);

    const deinit_status = gpa.deinit();
    if (deinit_status == .leak) {
        std.debug.print("Memory leaked!!", .{});
    }
}

fn createWindow(chip8: *emulator.Chip8) void {
    const screenWidth = screenbuffer.SCREEN_WIDTH * screenbuffer.SCREEN_SCALING;
    const screenHeight = screenbuffer.SCREEN_HEIGHT * screenbuffer.SCREEN_SCALING;

    raylib.InitWindow(screenWidth, screenHeight, "Chip-8 Emulator");

    raylib.SetTargetFPS(60);

    while (!raylib.WindowShouldClose()) // Detect window close button or ESC key
    {
        raylib.BeginDrawing();

        chip8.runCycle();
        chip8.screen.render();

        raylib.EndDrawing();
    }

    raylib.CloseWindow();
}
