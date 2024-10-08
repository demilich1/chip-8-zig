const raylib = @cImport(@cInclude("raylib.h"));

pub const SCREEN_WIDTH: u16 = 64;
pub const SCREEN_HEIGHT: u16 = 32;

pub const SCREEN_SCALING = 24;

const BACKGROUND_COLOR = raylib.BLACK;
const FOREGROUND_COLOR = raylib.WHITE;

pub const ScreenBuffer = struct {
    width: u16,
    height: u16,
    pixels: [SCREEN_WIDTH * SCREEN_HEIGHT]bool,
    dirty: bool,

    pub fn init() ScreenBuffer {
        const SIZE = SCREEN_WIDTH * SCREEN_HEIGHT;
        return ScreenBuffer{ .width = SCREEN_WIDTH, .height = SCREEN_HEIGHT, .pixels = [_]bool{false} ** SIZE, .dirty = false };
    }

    pub fn render(self: *ScreenBuffer) void {
        if (!self.dirty) return;

        raylib.ClearBackground(BACKGROUND_COLOR);
        for (0..self.width) |x_u| {
            for (0..self.height) |y_u| {
                const x: u16 = @intCast(x_u);
                const y: u16 = @intCast(y_u);
                const index = self.getIndex(x, y);
                if (!self.pixels[index]) continue;

                const draw_x = x * SCREEN_SCALING;
                const draw_y = y * SCREEN_SCALING;

                raylib.DrawRectangle(draw_x, draw_y, SCREEN_SCALING, SCREEN_SCALING, FOREGROUND_COLOR);
            }
        }

        self.dirty = false;
    }

    pub fn xor(self: *ScreenBuffer, x: u16, y: u16) bool {
        const index = self.getIndex(x % SCREEN_WIDTH, y % SCREEN_HEIGHT);
        const result = self.pixels[index];
        self.pixels[index] = result != true;
        return result;
    }

    pub fn clear(self: *ScreenBuffer) void {
        for (self.pixels, 0..) |_, i| {
            self.pixels[i] = false;
        }
    }

    pub fn markDirty(self: *ScreenBuffer) void {
        self.dirty = true;
    }

    fn getIndex(self: *const ScreenBuffer, x: u16, y: u16) u16 {
        const index = x * self.height + y;
        const len: u16 = @intCast(self.pixels.len);
        return index % len;
    }
};
