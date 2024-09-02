const std = @import("std");

const opcode = @import("opcode.zig");
const Op = opcode.Op;
const Rom = @import("rom.zig").Rom;
const ScreenBuffer = @import("screenbuffer.zig").ScreenBuffer;

const FONT_START_OFFSET: u16 = 0x050;
const ROM_START_OFFSET: u16 = 0x200;
const MEMORY_SIZE: usize = 4096;
const REGISTERS: usize = 16;
const STACK_SIZE: usize = 16;

const REG_F: usize = 0xF;

const FONT_DATA = [_]u8{
    0xF0, 0x90, 0x90, 0x90, 0xF0, // 0
    0x20, 0x60, 0x20, 0x20, 0x70, // 1
    0xF0, 0x10, 0xF0, 0x80, 0xF0, // 2
    0xF0, 0x10, 0xF0, 0x10, 0xF0, // 3
    0x90, 0x90, 0xF0, 0x10, 0x10, // 4
    0xF0, 0x80, 0xF0, 0x10, 0xF0, // 5
    0xF0, 0x80, 0xF0, 0x90, 0xF0, // 6
    0xF0, 0x10, 0x20, 0x40, 0x40, // 7
    0xF0, 0x90, 0xF0, 0x90, 0xF0, // 8
    0xF0, 0x90, 0xF0, 0x10, 0xF0, // 9
    0xF0, 0x90, 0xF0, 0x90, 0x90, // A
    0xE0, 0x90, 0xE0, 0x90, 0xE0, // B
    0xF0, 0x80, 0x80, 0x80, 0xF0, // C
    0xE0, 0x90, 0x90, 0x90, 0xE0, // D
    0xF0, 0x80, 0xF0, 0x80, 0xF0, // E
    0xF0, 0x80, 0xF0, 0x80, 0x80, // F
};

pub const Chip8 = struct {
    screen: ScreenBuffer,
    memory: []u8, // main memory
    v: [REGISTERS]u8, // general purpose registers
    stack: [STACK_SIZE]u16, // stack
    pc: u16, // program counter
    sp: u8, // stack pointer
    i: u16, // special purpose address regist
    dt: u8, // delay timer
    st: u8, // sound timer

    pub fn init(allocator: *const std.mem.Allocator) !Chip8 {
        const bytes = try allocator.alloc(u8, MEMORY_SIZE);
        var self = Chip8{
            .screen = ScreenBuffer.init(),
            .memory = bytes,
            .v = [_]u8{0} ** REGISTERS,
            .stack = [_]u16{0} ** STACK_SIZE,
            .pc = 0,
            .sp = 0,
            .i = 0,
            .dt = 0,
            .st = 0,
        };
        self.loadMem(&FONT_DATA, FONT_START_OFFSET);
        self.pc = ROM_START_OFFSET;
        return self;
    }

    pub fn loadRom(self: *const Chip8, path: []const u8) !void {
        const rom = try Rom.load(path);
        self.loadMem(rom.getBytes(), ROM_START_OFFSET);
    }

    fn loadMem(self: *const Chip8, data: []const u8, offset: u16) void {
        for (data, 0..) |value, i| {
            self.memory[i + offset] = value;
        }
    }

    pub fn runCycle(self: *Chip8) void {
        const opcode_raw = self.fetchOpcode();
        const decoded_opcode = opcode.decode(opcode_raw);
        std.debug.print("OpCode {}\n", .{decoded_opcode});

        self.pc += 2;
        self.executeOpcode(decoded_opcode);
    }

    fn fetchOpcode(self: *const Chip8) u16 {
        var p1: u16 = self.memory[self.pc];
        p1 = p1 << 8;
        const p2: u16 = self.memory[self.pc + 1];
        return p1 | p2;
    }

    fn executeOpcode(self: *Chip8, op_code: opcode.OpCode) void {
        switch (op_code.op) {
            Op.sys => self.sys(op_code.getAddr()),
            Op.clr => self.clr(),
            Op.jump => self.jump(op_code.getAddr()),
            Op.load => self.load(op_code.getS(), op_code.getNN()),
            Op.add => self.add(op_code.getS(), op_code.getNN()),
            Op.loadi => self.loadi(op_code.getAddr()),
            Op.draw => self.draw(op_code.getS(), op_code.getT(), op_code.getN()),
            else => @panic("Trying to execute unknown opcode"),
        }
    }

    fn sys(self: *Chip8, addr: u16) void {
        _ = self;
        std.debug.print("Ignoring opcode SYS to addr {}\n", .{addr});
    }

    fn jump(self: *Chip8, addr: u16) void {
        self.pc = addr;
    }

    fn clr(self: *Chip8) void {
        self.screen.clear();
    }

    fn load(self: *Chip8, s: u8, nn: u8) void {
        self.v[s] = nn;
    }

    fn add(self: *Chip8, s: u8, nn: u8) void {
        const value = self.v[s];
        self.v[s] = value +% nn;
    }

    fn loadi(self: *Chip8, addr: u16) void {
        self.i = addr;
    }

    fn draw(self: *Chip8, s: u8, t: u8, n: u8) void {
        const sx: u16 = @intCast(self.v[s]);
        const sy: u16 = @intCast(self.v[t]);

        self.v[REG_F] = 0;

        var y_line: u16 = 0;
        while (y_line < n) : (y_line += 1) {
            var x_line: u16 = 0;
            const pixel_row = self.memory[self.i + y_line];
            while (x_line < 8) : (x_line += 1) {
                const bits_to_shift: u3 = @intCast(7 - x_line);
                const sprite_bit = (pixel_row >> bits_to_shift) & 0x1;
                if (sprite_bit == 0) continue;

                const x = sx + x_line;
                const y = sy + y_line;

                if (self.screen.xor(x, y)) {
                    self.v[REG_F] = 1;
                }
            }
        }
    }
};

pub fn destroy(chip8: Chip8, allocator: *const std.mem.Allocator) void {
    allocator.free(chip8.memory);
}
