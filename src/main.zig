const std = @import("std");
const raylib = @cImport(@cInclude("raylib.h"));

const emulator = @import("emulator.zig");
const screenbuffer = @import("screenbuffer.zig");

const CYCLES_PER_FRAME: u8 = 4;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var chip8 = try emulator.Chip8.init(&allocator);
    try chip8.loadRom("roms/INVADERS");

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
    raylib.SetExitKey(0);

    while (!raylib.WindowShouldClose()) {
        handleInput(chip8);

        raylib.BeginDrawing();

        for (0..CYCLES_PER_FRAME) |_| {
            chip8.runCycle();
        }
        chip8.screen.render();

        raylib.EndDrawing();
    }

    raylib.CloseWindow();
}

fn handleInput(chip8: *emulator.Chip8) void {
    if (raylib.IsKeyPressed(raylib.KEY_ESCAPE)) chip8.setKey(0x0);
    if (raylib.IsKeyPressed(raylib.KEY_ONE)) chip8.setKey(0x1);
    if (raylib.IsKeyPressed(raylib.KEY_TWO)) chip8.setKey(0x2);
    if (raylib.IsKeyPressed(raylib.KEY_THREE)) chip8.setKey(0x3);
    if (raylib.IsKeyPressed(raylib.KEY_FOUR)) chip8.setKey(0xC);
    if (raylib.IsKeyPressed(raylib.KEY_Q)) chip8.setKey(0x4);
    if (raylib.IsKeyPressed(raylib.KEY_W)) chip8.setKey(0x5);
    if (raylib.IsKeyPressed(raylib.KEY_E)) chip8.setKey(0x6);
    if (raylib.IsKeyPressed(raylib.KEY_R)) chip8.setKey(0xD);
    if (raylib.IsKeyPressed(raylib.KEY_A)) chip8.setKey(0x7);
    if (raylib.IsKeyPressed(raylib.KEY_S)) chip8.setKey(0x8);
    if (raylib.IsKeyPressed(raylib.KEY_D)) chip8.setKey(0x9);

    if (raylib.IsKeyReleased(raylib.KEY_ESCAPE)) chip8.unsetKey(0x0);
    if (raylib.IsKeyReleased(raylib.KEY_ONE)) chip8.unsetKey(0x1);
    if (raylib.IsKeyReleased(raylib.KEY_TWO)) chip8.unsetKey(0x2);
    if (raylib.IsKeyReleased(raylib.KEY_THREE)) chip8.unsetKey(0x3);
    if (raylib.IsKeyReleased(raylib.KEY_FOUR)) chip8.unsetKey(0xC);
    if (raylib.IsKeyReleased(raylib.KEY_Q)) chip8.unsetKey(0x4);
    if (raylib.IsKeyReleased(raylib.KEY_W)) chip8.unsetKey(0x5);
    if (raylib.IsKeyReleased(raylib.KEY_E)) chip8.unsetKey(0x6);
    if (raylib.IsKeyReleased(raylib.KEY_R)) chip8.unsetKey(0xD);
    if (raylib.IsKeyReleased(raylib.KEY_A)) chip8.unsetKey(0x7);
    if (raylib.IsKeyReleased(raylib.KEY_S)) chip8.unsetKey(0x8);
    if (raylib.IsKeyReleased(raylib.KEY_D)) chip8.unsetKey(0x9);
}
