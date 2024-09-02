const std = @import("std");
const math = @import("std").math;
const IntegerBitSet = @import("std").bit_set.IntegerBitSet;
const Rng = std.rand.DefaultPrng;

const opcode = @import("opcode.zig");
const Op = opcode.Op;
const Rom = @import("rom.zig").Rom;
const ScreenBuffer = @import("screenbuffer.zig").ScreenBuffer;

const FONT_START_OFFSET: u16 = 0x050;
const ROM_START_OFFSET: u16 = 0x200;
const MEMORY_SIZE: usize = 4096;
const REGISTERS: usize = 16;
const STACK_SIZE: usize = 16;
const DEFAULT_PC_INC: u16 = 2;
const NONE: u8 = 255;

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
    regs: [REGISTERS]u8, // general purpose registers
    stack: [STACK_SIZE]u16, // stack
    keys: IntegerBitSet(16),
    rng: Rng,
    pc: u16, // program counter
    sp: u8, // stack pointer
    i: u16, // special purpose address regist
    delay_timer: u8, // delay timer
    sound_timer: u8, // sound timer
    key_target_reg: u8,

    pub fn init(allocator: *const std.mem.Allocator) !Chip8 {
        const bytes = try allocator.alloc(u8, MEMORY_SIZE);
        var self = Chip8{
            .screen = ScreenBuffer.init(),
            .memory = bytes,
            .regs = [_]u8{0} ** REGISTERS,
            .stack = [_]u16{0} ** STACK_SIZE,
            .keys = IntegerBitSet(16).initEmpty(),
            .rng = Rng.init(1337),
            .pc = 0,
            .sp = 0,
            .i = 0,
            .delay_timer = 0,
            .sound_timer = 0,
            .key_target_reg = NONE,
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

    pub fn setKey(self: *Chip8, key: u8) void {
        self.keys.set(key);
        if (self.key_target_reg != NONE) {
            self.regs[self.key_target_reg] = key;
            //std.debug.print("Writing key to target reg: {}\n", .{self.key_target_reg});
            self.key_target_reg = NONE;
        }
        //std.debug.print("Key pressed: {}\n", .{key});
    }

    pub fn unsetKey(self: *Chip8, key: u8) void {
        self.keys.unset(key);
        //std.debug.print("Key released: {}\n", .{key});
    }

    pub fn runCycle(self: *Chip8) void {
        // waiting for key press
        if (self.key_target_reg != NONE) return;

        const opcode_raw = self.fetchOpcode();
        const decoded_opcode = opcode.decode(opcode_raw);
        //std.debug.print("OpCode {}\n", .{decoded_opcode});

        self.pc += DEFAULT_PC_INC;
        self.executeInstruction(decoded_opcode);

        if (self.delay_timer > 0)
            self.delay_timer -= 1;
        if (self.sound_timer > 0)
            self.sound_timer -= 1;
    }

    fn fetchOpcode(self: *const Chip8) u16 {
        var p1: u16 = self.memory[self.pc];
        p1 = p1 << 8;
        const p2: u16 = self.memory[self.pc + 1];
        return p1 | p2;
    }

    fn executeInstruction(self: *Chip8, instruction: opcode.OpCode) void {
        switch (instruction.op) {
            Op.sys => self.sys(instruction.getAddr()),
            Op.clr => self.clear(),
            Op.jump => self.jump(instruction.getAddr()),
            Op.call => self.call(instruction.getAddr()),
            Op.ret => self.ret(),
            Op.ske => self.skipEqual(instruction.getS(), instruction.getNN()),
            Op.skne => self.skipNotEqual(instruction.getS(), instruction.getNN()),
            Op.skre => self.skipRegEqual(instruction.getS(), instruction.getT()),
            Op.skrne => self.skipRegNotEqual(instruction.getS(), instruction.getT()),
            Op.load => self.load(instruction.getS(), instruction.getNN()),
            Op.add => self.add(instruction.getS(), instruction.getNN()),
            Op.move => self.move(instruction.getS(), instruction.getT()),
            Op.log_or => self.logicalOr(instruction.getS(), instruction.getT()),
            Op.log_and => self.logicalAnd(instruction.getS(), instruction.getT()),
            Op.log_xor => self.logicalXor(instruction.getS(), instruction.getT()),
            Op.addr => self.addReg(instruction.getS(), instruction.getT()),
            Op.sub => self.subReg(instruction.getS(), instruction.getT()),
            Op.shr => self.shiftRight(instruction.getS()),
            Op.shl => self.shiftLeft(instruction.getS()),
            Op.loadi => self.loadi(instruction.getAddr()),
            Op.rand => self.rand(instruction.getS(), instruction.getNN()),
            Op.draw => self.draw(instruction.getS(), instruction.getT(), instruction.getN()),
            Op.skp => self.skipPressed(instruction.getS()),
            Op.sknp => self.skipNotPressed(instruction.getS()),
            Op.keyd => self.waitForKey(instruction.getS()),
            Op.moved => self.moveDelay(instruction.getS()),
            Op.loadd => self.loadDelayTimer(instruction.getS()),
            Op.loads => self.loadSoundTimer(instruction.getS()),
            Op.addi => self.addi(instruction.getS()),
            Op.ldspr => self.loadSprite(instruction.getS()),
            Op.bcd => self.bcd(instruction.getS()),
            Op.stor => self.store(instruction.getS()),
            Op.read => self.read(instruction.getS()),
            else => std.debug.panic("Trying to execute unknown instruction: {}", .{instruction.op}),
        }
    }

    fn sys(self: *Chip8, addr: u16) void {
        _ = self;
        std.debug.print("Ignoring opcode SYS to addr {}\n", .{addr});
    }

    fn jump(self: *Chip8, addr: u16) void {
        self.pc = addr;
    }

    fn call(self: *Chip8, addr: u16) void {
        self.stack[self.sp] = self.pc;
        self.sp += 1;
        self.pc = addr;
    }

    fn ret(self: *Chip8) void {
        self.sp -= 1;
        self.pc = self.stack[self.sp];
    }

    fn skipEqual(self: *Chip8, s: u8, nn: u8) void {
        if (self.regs[s] == nn) {
            self.pc += DEFAULT_PC_INC;
        }
    }

    fn skipNotEqual(self: *Chip8, s: u8, nn: u8) void {
        if (self.regs[s] != nn) {
            self.pc += DEFAULT_PC_INC;
        }
    }

    fn skipRegEqual(self: *Chip8, s: u8, t: u8) void {
        if (self.regs[s] == self.regs[t]) {
            self.pc += DEFAULT_PC_INC;
        }
    }

    fn skipRegNotEqual(self: *Chip8, s: u8, t: u8) void {
        if (self.regs[s] != self.regs[t]) {
            self.pc += DEFAULT_PC_INC;
        }
    }

    fn clear(self: *Chip8) void {
        self.screen.clear();
        self.screen.markDirty();
    }

    fn load(self: *Chip8, s: u8, nn: u8) void {
        self.regs[s] = nn;
    }

    fn add(self: *Chip8, s: u8, nn: u8) void {
        const value = self.regs[s];
        self.regs[s] = value +% nn;
    }

    fn move(self: *Chip8, s: u8, t: u8) void {
        self.regs[s] = self.regs[t];
    }

    fn logicalOr(self: *Chip8, s: u8, t: u8) void {
        self.regs[s] = self.regs[s] | self.regs[t];
    }

    fn logicalAnd(self: *Chip8, s: u8, t: u8) void {
        self.regs[s] = self.regs[s] & self.regs[t];
    }

    fn logicalXor(self: *Chip8, s: u8, t: u8) void {
        self.regs[s] = self.regs[s] ^ self.regs[t];
    }

    fn addReg(self: *Chip8, s: u8, t: u8) void {
        const s_val = self.regs[s];
        const t_val = self.regs[t];

        if (math.add(u8, s_val, t_val)) |result| {
            // no overflow occured, unset carry flag and return result
            self.regs[REG_F] = 0;
            self.regs[s] = result;
        } else |_| {
            // overflow occured, set carry flag and save wrapped result
            self.regs[REG_F] = 1;
            self.regs[s] = s_val +% t_val;
        }
    }

    fn subReg(self: *Chip8, s: u8, t: u8) void {
        const s_val = self.regs[s];
        const t_val = self.regs[t];

        if (math.sub(u8, s_val, t_val)) |result| {
            // no overflow occured, set carry flag and return result
            self.regs[REG_F] = 1;
            self.regs[s] = result;
        } else |_| {
            // overflow occured, unset carry flag and save wrapped result
            self.regs[REG_F] = 0;
            self.regs[s] = s_val -% t_val;
        }
    }

    fn shiftRight(self: *Chip8, s: u8) void {
        const s_val = self.regs[s];
        self.regs[REG_F] = s_val & 0x1;
        self.regs[s] >>= 1;
    }

    fn shiftLeft(self: *Chip8, s: u8) void {
        const s_val = self.regs[s];
        self.regs[REG_F] = s_val >> 7;
        self.regs[s] <<= 1;
    }

    fn loadi(self: *Chip8, addr: u16) void {
        self.i = addr;
    }

    fn rand(self: *Chip8, s: u8, nn: u8) void {
        const sample = self.rng.next() & nn;
        self.regs[s] = @intCast(sample);
    }

    fn draw(self: *Chip8, s: u8, t: u8, n: u8) void {
        const sx: u16 = @intCast(self.regs[s]);
        const sy: u16 = @intCast(self.regs[t]);

        self.regs[REG_F] = 0;

        var y_line: u16 = 0;
        while (y_line < n) : (y_line += 1) {
            const pixel_row = self.memory[self.i + y_line];
            var x_line: u16 = 0;
            while (x_line < 8) : (x_line += 1) {
                const bits_to_shift: u3 = @intCast(7 - x_line);
                const sprite_bit = (pixel_row >> bits_to_shift) & 0x1;
                if (sprite_bit == 0) continue;

                const x = sx + x_line;
                const y = sy + y_line;

                if (self.screen.xor(x, y)) {
                    self.regs[REG_F] = 1;
                }
            }
        }

        self.screen.markDirty();
    }

    fn skipPressed(self: *Chip8, s: u8) void {
        const key = self.regs[s];
        if (self.keys.isSet(key)) {
            self.pc += DEFAULT_PC_INC;
        }
    }

    fn skipNotPressed(self: *Chip8, s: u8) void {
        const key = self.regs[s];
        if (!self.keys.isSet(key)) {
            self.pc += DEFAULT_PC_INC;
        }
    }

    fn waitForKey(self: *Chip8, s: u8) void {
        //std.debug.print("Waiting for any key press...\n", .{});
        self.key_target_reg = s;
    }

    fn moveDelay(self: *Chip8, s: u8) void {
        self.regs[s] = self.delay_timer;
    }

    fn loadDelayTimer(self: *Chip8, s: u8) void {
        self.delay_timer = self.regs[s];
    }

    fn loadSoundTimer(self: *Chip8, s: u8) void {
        self.sound_timer = self.regs[s];
    }

    fn addi(self: *Chip8, s: u8) void {
        const value: u16 = self.regs[s];
        self.i = (self.i +% value) & 0xFFF;
    }

    fn loadSprite(self: *Chip8, s: u8) void {
        const value: u16 = self.regs[s] * 5;
        self.i = FONT_START_OFFSET + (value & 0xFFF);
    }

    fn bcd(self: *Chip8, s: u8) void {
        const vx = self.regs[s];
        self.memory[self.i] = vx / 100;
        self.memory[self.i + 1] = (vx / 10) % 10;
        self.memory[self.i + 2] = (vx % 100) % 10;
    }

    fn store(self: *Chip8, s: u8) void {
        var i: u16 = 0;
        while (i <= s) : (i += 1) {
            self.memory[self.i + i] = self.regs[i];
        }
    }

    fn read(self: *Chip8, s: u8) void {
        var i: u16 = 0;
        while (i <= s) : (i += 1) {
            self.regs[i] = self.memory[self.i + i];
        }
    }
};

pub fn destroy(chip8: Chip8, allocator: *const std.mem.Allocator) void {
    allocator.free(chip8.memory);
}
