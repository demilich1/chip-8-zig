const std = @import("std");

pub const Op = enum {
    sys, // 0nnn; System call (ignored)
    clr, // 00E0; Clear the screen
    ret, // 00EE; Return from subroutine
    jump, // 1nnn; Jump to address nnn
    call, // 2nnn; Call routine at address
    ske, // 3snn; Skip next instruction if register s is equal to nn
    skne, // 4snn; Skip next instruction if register s is not equal to nn
    skre, // 5st0; Skip next instruction if register s is equal to register t
    load, // 6snn; Load register s with value nn
    add, // 7snn; Add value nn to register s
    move, // 8st0; Move value from register s to register t
    log_or, // 8st1; Perform logical OR on register s and t and store in t
    log_and, // 8st2; Perform logical AND on register s and t and store in t
    log_xor, // 8st3; Perform logical XOR on register s and t and store in t
    addr, // 8st4; Add s to t and store in s - register F set on carry
    sub, // 8st5; Subtract s from t and store in s - register F set on carry
    shr, // 8s06; Shift bits in register s 1 bit to the right - bit 0 shifts to register F
    shl, // 8s0E; Shift bits in register s 1 bit to the left - bit 7 shifts to register F
    skrne, // 9st0; Skip next instruction if register s is not equal to register t
    loadi, // Annn; Load index with value nnn
    draw, // Dstn; Draw n byte sprite at x location reg s, y location reg t
    skp, // Es9E; Skip next instruction if key with the value of s is pressed
    sknp, // EsA1; Skip next instruction if key with the value of s is not pressed
    moved, // Fs07; Move delay timer value into register s
    keyd, // Fs0A; Wait for keypress and store in register s
    loadd, // Fs15; Load delay timer with value in register s
    loads, // Fs18; Load sound timer with value in register s
    addi, // Fs1E; Add value in register s to index
    ldspr, // Fs29; Load index with sprite from register s
    bcd, // Fs33; Store the binary coded decimal value of register s at index
    stor, // Fs55; Store the values of register s registers at index
    read, // Fs65; Read back the stored values at index into registers
    err, // INVALID op code; should never be encountered for well formed ROMs
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
            else => Op.err,
        },
        0x1000 => Op.jump,
        0x2000 => Op.call,
        0x3000 => Op.ske,
        0x4000 => Op.skne,
        0x5000 => Op.skre,
        0x6000 => Op.load,
        0x7000 => Op.add,
        0x8000 => switch (getN4(val)) {
            0x00 => Op.move,
            0x01 => Op.log_or,
            0x02 => Op.log_and,
            0x03 => Op.log_xor,
            0x04 => Op.addr,
            0x05 => Op.sub,
            0x06 => Op.shr,
            0x0E => Op.shl,
            else => Op.err,
        },
        0x9000 => Op.skrne,
        0xA000 => Op.loadi,
        0xD000 => Op.draw,
        0xE000 => switch (getN34(val)) {
            0x009E => Op.skp,
            0x00A1 => Op.sknp,
            else => Op.err,
        },
        0xF000 => switch (getN34(val)) {
            0x0007 => Op.moved,
            0x000A => Op.keyd,
            0x0015 => Op.loadd,
            0x0018 => Op.loads,
            0x001E => Op.addi,
            0x0029 => Op.ldspr,
            0x0033 => Op.bcd,
            0x0055 => Op.stor,
            0x0065 => Op.read,
            else => Op.err,
        },
        else => std.debug.panic("Encountered unknown opCode: 0x{x}", .{first_nibble}),
    };

    return OpCode{ .op = op, .raw = val };
}

fn getN4(opcode: u16) u8 {
    return @intCast(opcode & 0x000F);
}

fn getN34(opcode: u16) u8 {
    return @intCast(opcode & 0x00FF);
}
