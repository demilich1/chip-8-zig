const raylib = @cImport(@cInclude("raylib.h"));

pub const SCREEN_WIDTH: u16 = 64;
pub const SCREEN_HEIGHT: u16 = 32;

pub const SCREEN_SCALING = 16;

pub const ScreenBuffer = struct {
    width: u16,
    height: u16,
    pixels: [SCREEN_WIDTH * SCREEN_HEIGHT]bool,

    pub fn init() ScreenBuffer {
        const SIZE = SCREEN_WIDTH * SCREEN_HEIGHT;
        return ScreenBuffer{ .width = SCREEN_WIDTH, .height = SCREEN_HEIGHT, .pixels = [_]bool{false} ** SIZE };
    }

    pub fn render(self: *const ScreenBuffer) void {
        raylib.ClearBackground(raylib.BLACK);
        for (0..self.width) |x_u| {
            for (0..self.height) |y_u| {
                const x: u16 = @intCast(x_u);
                const y: u16 = @intCast(y_u);
                const index = self.getIndex(x, y);
                if (!self.pixels[index]) continue;

                const draw_x = x * SCREEN_SCALING;
                const draw_y = y * SCREEN_SCALING;

                raylib.DrawRectangle(draw_x, draw_y, SCREEN_SCALING, SCREEN_SCALING, raylib.WHITE);
            }
        }
    }

    pub fn xor(self: *ScreenBuffer, x: u16, y: u16) bool {
        const index = self.getIndex(x, y);
        const result = self.pixels[index];
        self.pixels[index] = result != true;
        return result;
    }

    pub fn clear(self: *ScreenBuffer) void {
        for (self.pixels, 0..) |_, i| {
            self.pixels[i] = false;
        }
    }

    fn getIndex(self: *const ScreenBuffer, x: u16, y: u16) u16 {
        const len: u16 = @intCast(self.pixels.len);
        var index = x * self.height + y;
        index = index % len;
        return index;
    }
};
