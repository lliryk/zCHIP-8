const std = @import("std");
const c = @import("c.zig").c;
const Instr = @import("instr.zig");

opcode: u16,
memory: [4096]u8,
graphics: [64 * 32]u8,
registers: [16]u8,
index: u16,
program_counter: u16,

delay_timer: u8,
sound_timer: u8,

stack: [16]u16,
stack_pointer: u16,

keys: [16]u8,

// Timing
cycle_countdown: i64,

var last_cycle: i64 = undefined;
const ClockSpeedMicro = 16667; // 60 Hz

const Self = @This();

const FontSet = [_]u8{
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

pub fn init(self: *Self) void {
    c.srand(@intCast(c_uint, c.time(0)));

    self.reset();
}

pub fn reset(self: *Self) void {
    self.program_counter = 0x200;
    self.opcode = 0;
    self.index = 0;
    self.stack_pointer = 0;
    self.delay_timer = 0;
    self.sound_timer = 0;

    self.cycle_countdown = 0;
    last_cycle = std.time.microTimestamp();

    for (&self.memory) |*x| {
        x.* = 0;
    }
    for (&self.graphics) |*x| {
        x.* = 0;
    }
    for (&self.registers) |*x| {
        x.* = 0;
    }
    for (&self.stack) |*x| {
        x.* = 0;
    }
    for (&self.keys) |*x| {
        x.* = 0;
    }

    for (FontSet, 0..) |byte, i| {
        self.memory[i] = byte;
    }
}

const RomError = error{
    FileSizeToLarge,
};

pub fn load_rom(self: *Self, filename: []const u8) !void {
    var input_file = try std.fs.cwd().openFile(filename, .{});
    defer input_file.close();

    const size = try input_file.getEndPos();
    var reader = input_file.reader();

    if (size > self.memory.len - 0x200) {
        return RomError.FileSizeToLarge;
    }

    for (0..size) |i| {
        self.memory[i + 0x200] = try reader.readByte();
    }
}

pub const Key = enum(u8) {
    X = 0,
    Key1,
    Key2,
    Key3,
    Q,
    W,
    E,
    A,
    S,
    D,
    Z,
    C,
    Key4,
    R,
    F,
    V,
};

pub const KeyState = enum(u8) {
    Up = 0x0,
    Down,
};

pub fn update_keys(self: *Self, key: Key, state: KeyState) void {
    self.keys[@enumToInt(key)] = @enumToInt(state);
}

fn increment_pc(self: *Self) void {
    self.program_counter += 2;
}

pub fn cycle(self: *Self) bool {
    const cur_time = std.time.microTimestamp();
    self.cycle_countdown -= cur_time - last_cycle;
    last_cycle = cur_time;

    if (self.cycle_countdown > 0) {
        return false;
    }
    self.cycle_countdown = ClockSpeedMicro;

    self.opcode = @intCast(u16, self.memory[self.program_counter]) << 8 | self.memory[self.program_counter + 1];

    const instr = Instr.decode(self.opcode);
    // var writer = std.io.getStdOut().writer();
    // instr.get_mnemonic(writer) catch unreachable;
    // _ = writer.write("\n") catch unreachable;

    self.execute(instr);

    // FIXME: Timers should always run at 60Hz, currently they depend on CPU clockspeed.
    if (self.delay_timer > 0) {
        self.delay_timer -= 1;
    }

    if (self.sound_timer > 0) {
        self.sound_timer -= 1;
    }

    return true;
}

fn execute(self: *Self, instr: Instr) void {
    InstrFunctions[@enumToInt(instr.tag)](self, instr.data);
}

const InstrFunctions = [_]*const fn (self: *Self, data: Instr.Data) void{
    CLS,
    RET,
    JMP,
    CALL,
    SE,
    SNE,
    SER,
    LD,
    ADD,
    LDR,
    OR,
    AND,
    XOR,
    ADDR,
    SUB,
    SHR,
    SUBN,
    SHL,
    SNER,
    LDI,
    JMPV,
    RND,
    DRW,
    SKP,
    SKNP,
    LDRT,
    LDRK,
    LDTR,
    LDSR,
    ADDI,
    LDIF,
    BCD,
    LDIM,
    LDMI,
    @"???",
};

test "Instruction and Tag List Length" {
    try std.testing.expect(InstrFunctions.len == Instr.TagLength);
}

fn CLS(self: *Self, data: Instr.Data) void {
    _ = data;
    for (&self.graphics) |*x| {
        x.* = 0;
    }
    self.increment_pc();
}

fn RET(self: *Self, data: Instr.Data) void {
    _ = data;
    self.stack_pointer -= 1;
    self.program_counter = self.stack[self.stack_pointer];
    self.increment_pc();
}

fn JMP(self: *Self, data: Instr.Data) void {
    self.program_counter = data.tibble.value;
}

fn CALL(self: *Self, data: Instr.Data) void {
    self.stack[self.stack_pointer] = self.program_counter;
    self.stack_pointer += 1;
    self.program_counter = data.tibble.value;
}

fn SE(self: *Self, data: Instr.Data) void {
    if (self.registers[data.reg_dibble.x] == data.reg_dibble.value) {
        self.increment_pc();
    }
    self.increment_pc();
}

fn SNE(self: *Self, data: Instr.Data) void {
    if (self.registers[data.reg_dibble.x] != data.reg_dibble.value) {
        self.increment_pc();
    }
    self.increment_pc();
}

fn SER(self: *Self, data: Instr.Data) void {
    if (self.registers[data.reg_reg.x] == self.registers[data.reg_reg.y]) {
        self.increment_pc();
    }
    self.increment_pc();
}

fn LD(self: *Self, data: Instr.Data) void {
    self.registers[data.reg_dibble.x] = data.reg_dibble.value;
    self.increment_pc();
}

fn ADD(self: *Self, data: Instr.Data) void {
    // +% is a wrapping add, similiar to @addWithOverflow()
    self.registers[data.reg_dibble.x] +%= data.reg_dibble.value;
    self.increment_pc();
}

fn LDR(self: *Self, data: Instr.Data) void {
    self.registers[data.reg_reg.x] = self.registers[data.reg_reg.y];
    self.increment_pc();
}

fn OR(self: *Self, data: Instr.Data) void {
    self.registers[data.reg_reg.x] |= self.registers[data.reg_reg.y];
    self.increment_pc();
}

fn AND(self: *Self, data: Instr.Data) void {
    self.registers[data.reg_reg.x] &= self.registers[data.reg_reg.y];
    self.increment_pc();
}

fn XOR(self: *Self, data: Instr.Data) void {
    self.registers[data.reg_reg.x] ^= self.registers[data.reg_reg.y];
    self.increment_pc();
}

fn ADDR(self: *Self, data: Instr.Data) void {
    const result = @addWithOverflow(self.registers[data.reg_reg.x], self.registers[data.reg_reg.y]);
    self.registers[data.reg_reg.x] = result[0];
    self.registers[0xF] = result[1];
    self.increment_pc();
}

fn SUB(self: *Self, data: Instr.Data) void {
    const result = @subWithOverflow(self.registers[data.reg_reg.x], self.registers[data.reg_reg.y]);
    self.registers[data.reg_reg.x] = result[0];
    self.registers[0xF] = if (result[1] == 0x1) 0 else 1;
    self.increment_pc();
}

fn SHR(self: *Self, data: Instr.Data) void {
    const overflow = self.registers[data.reg.x] & 1;
    self.registers[data.reg.x] >>= 1;
    self.registers[0xF] = overflow;
    self.increment_pc();
}

fn SUBN(self: *Self, data: Instr.Data) void {
    const x = data.reg_reg.x;
    const y = data.reg_reg.y;
    self.registers[x] = self.registers[y] -% self.registers[x];
    self.registers[0xF] = if (self.registers[y] > self.registers[x]) 1 else 0;
    self.increment_pc();
}

fn SHL(self: *Self, data: Instr.Data) void {
    var overflow: u8 = undefined;
    if (self.registers[data.reg.x] & 0x80 != 0) {
        overflow = 1;
    } else {
        overflow = 0;
    }
    self.registers[data.reg.x] <<= 1;
    self.registers[0xF] = overflow;
    self.increment_pc();
}

fn SNER(self: *Self, data: Instr.Data) void {
    if (self.registers[data.reg_reg.x] != self.registers[data.reg_reg.y]) {
        self.increment_pc();
    }
    self.increment_pc();
}

fn LDI(self: *Self, data: Instr.Data) void {
    self.index = data.tibble.value;
    self.increment_pc();
}

fn JMPV(self: *Self, data: Instr.Data) void {
    self.program_counter = data.tibble.value + @intCast(u16, self.registers[0]);
    self.increment_pc();
}

fn RND(self: *Self, data: Instr.Data) void {
    self.registers[data.reg_dibble.x] = @intCast(u8, @rem(c.rand(), 256)) & data.reg_dibble.value;
    self.increment_pc();
}

fn DRW(self: *Self, data: Instr.Data) void {
    self.registers[0xF] = 0;
    const height = data.reg_reg_nibble.value;
    const pos_x = self.registers[data.reg_reg_nibble.x] % 64;
    const pos_y = self.registers[data.reg_reg_nibble.y] % 32;

    for (0..height) |y| {
        if (pos_y + y >= 32) {
            break;
        }

        const sprite_byte: u16 = self.memory[self.index + y];

        for (0..8) |x| {
            if (pos_x + x >= 64) {
                break;
            }
            const pixel = sprite_byte & (@as(u16, 0x80) >> @intCast(u4, x));

            if (pixel != 0) {
                var tx = (pos_x + x) % 64;
                var ty = (pos_y + y) % 32;

                var idx = tx + ty * 64;

                self.graphics[idx] ^= 1;
                if (self.graphics[idx] == 0) {
                    self.registers[0xF] = 1;
                }
            }
        }
    }
    self.increment_pc();
}

fn SKP(self: *Self, data: Instr.Data) void {
    if (self.keys[self.registers[data.reg.x]] == 1) {
        self.increment_pc();
    }

    self.increment_pc();
}

fn SKNP(self: *Self, data: Instr.Data) void {
    if (self.keys[self.registers[data.reg.x]] != 1) {
        self.increment_pc();
    }

    self.increment_pc();
}

fn LDRT(self: *Self, data: Instr.Data) void {
    self.registers[data.reg.x] = self.delay_timer;
    self.increment_pc();
}

fn LDRK(self: *Self, data: Instr.Data) void {
    var key_pressed = false;

    for (self.keys, 0..) |v, i| {
        if (v != 0) {
            self.registers[data.reg.x] = @intCast(u8, i);
            key_pressed = true;
            break;
        }
    }
    if (key_pressed) {
        self.increment_pc();
    }
}

fn LDTR(self: *Self, data: Instr.Data) void {
    self.delay_timer = self.registers[data.reg.x];
    self.increment_pc();
}

fn LDSR(self: *Self, data: Instr.Data) void {
    self.sound_timer = self.registers[data.reg.x];
    self.increment_pc();
}

fn ADDI(self: *Self, data: Instr.Data) void {
    // Not sure what the overflow behavior should be if index > 0x0FFF, (4096 = 0x1000)
    self.index += self.registers[data.reg.x];
    self.increment_pc();
}

fn LDIF(self: *Self, data: Instr.Data) void {
    if (self.registers[data.reg.x] < 16) {
        self.index = self.registers[data.reg.x] * 0x5;
    }
    self.increment_pc();
}

fn BCD(self: *Self, data: Instr.Data) void {
    self.memory[self.index] = self.registers[data.reg.x] / 100;
    self.memory[self.index + 1] = (self.registers[data.reg.x] / 10) % 10;
    self.memory[self.index + 2] = self.registers[data.reg.x] % 10;
    self.increment_pc();
}

fn LDIM(self: *Self, data: Instr.Data) void {
    const x: u8 = data.reg.x;
    for (0..x + 1) |i| {
        self.memory[self.index + i] = self.registers[i];
    }
    self.increment_pc();
}

fn LDMI(self: *Self, data: Instr.Data) void {
    const x: u8 = data.reg.x;
    for (0..x + 1) |i| {
        self.registers[i] = self.memory[self.index + i];
    }
    self.increment_pc();
}

// Treat Invalid Opcodes as no ops
fn @"???"(self: *Self, data: Instr.Data) void {
    _ = data;
    self.increment_pc();
}
