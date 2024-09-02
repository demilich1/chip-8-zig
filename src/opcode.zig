const std = @import("std");

pub const Op = enum {
    sys, // 0nnn; System call (ignored)
    clr, // 00E0; Clear the screen
    ret, // 00EE; Return from subroutine
    jump, // 1nnn; Jump to address nnn
    load, // 6snn; Load register s with value nn
    add, // 7snn; Add value nn to register s
    loadi, // Annn; Load index with value nnn
    draw, // Dstn; Draw n byte sprite at x location reg s, y location reg t
};

pub const OpCode = struct {
    op: Op,
    raw: u16,

    pub fn getAddr(self: *const OpCode) u16 {
        return self.raw & 0x0FFF;
    }

    pub fn getS(self: *const OpCode) u8 {
        const s = (self.raw & 0x0F00) >> 8;
        return @intCast(s);
    }

    pub fn getT(self: *const OpCode) u8 {
        const t = (self.raw & 0x00F0) >> 4;
        return @intCast(t);
    }

    pub fn getN(self: *const OpCode) u8 {
        const n = (self.raw & 0x000F);
        return @intCast(n);
    }

    pub fn getNN(self: *const OpCode) u8 {
        return @intCast(self.raw & 0x00FF);
    }
};

pub fn decode(val: u16) OpCode {
    const first_nibble = val & 0xF000;
    const op = switch (first_nibble) {
        0x0000 => switch (getN34(val)) {
            0x00E0 => Op.clr,
            0x00EE => Op.ret,
            else => Op.clr,
        },
        0x1000 => Op.jump,
        0x6000 => Op.load,
        0x7000 => Op.add,
        0xA000 => Op.loadi,
        0xD000 => Op.draw,
        else => std.debug.panic("Encountered unknown opCode: 0x{X}", .{first_nibble}),
    };

    return OpCode{ .op = op, .raw = val };
}

fn getN34(opcode: u16) u8 {
    return @intCast(opcode & 0x00FF);
}
