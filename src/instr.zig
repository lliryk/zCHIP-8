// What should the instruction struct provide:

// 1. Unique representation of every Chip-8 instructions

// 2. Seperate functions per instruction that operate on a Chip-8 CPU
// This ^ will be done by the CPU

// 3. A way to get the Mnemonic name and representation for an instruction
// 4. A way to convert back into Chip-8 u16 opcode

const std = @import("std");
const CHIP8 = @import("chip8.zig");

tag: Tag,
data: Data,

const Self = @This();

pub const Data = packed union {
    opcode: u16,
    dibble: Dibble,
    tibble: Tibble,
    reg: Reg,
    reg_dibble: RegDibble,
    reg_reg: RegReg,
    reg_reg_nibble: RegRegNibble,
};

test "Data Size valid" {
    try std.testing.expect(@sizeOf(Data) == @sizeOf(u16));
}

const DataTag = enum {
    Opcode,
    Dibble,
    Tibble,
    Reg,
    RegDibble,
    RegReg,
    RegRegNibble,
    Invalid,
};

pub const Dibble = packed struct {
    value: u8,
    _pad: u8,
};

pub const Tibble = packed struct {
    value: u12,
    _pad: u4,
};

pub const Reg = packed struct {
    _pad1: u8,
    x: u4,
    _pad: u4,
};

pub const RegDibble = packed struct {
    value: u8,
    x: u4,
    _pad: u4,
};

pub const RegReg = packed struct {
    _pad1: u4,
    y: u4,
    x: u4,
    _pad: u4,
};

pub const RegRegNibble = packed struct {
    value: u4,
    y: u4,
    x: u4,
    _pad: u4,
};

pub const Tag = enum(u8) {
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

pub const TagLength = @intFromEnum(Tag.@"???") + 1;

const Tags = [_][]const u8{
    "CLS",
    "RET",
    "JMP",
    "CALL",
    "SE",
    "SNE",
    "SE",
    "LD",
    "ADD",
    "LD",
    "OR",
    "AND",
    "XOR",
    "ADD",
    "SUB",
    "SHR",
    "SUBN",
    "SHL",
    "SNE",
    "LD",
    "JMP",
    "RND",
    "DRW",
    "SKP",
    "SKNP",
    "LD",
    "LD",
    "LD",
    "LD",
    "ADD",
    "LD",
    "BCD",
    "LD",
    "LD",
    "???",
};

pub const DataTags = [_]DataTag{
    DataTag.Opcode,
    DataTag.Opcode,
    DataTag.Tibble,
    DataTag.Tibble,
    DataTag.RegDibble,
    DataTag.RegDibble,
    DataTag.RegReg,
    DataTag.RegDibble,
    DataTag.RegDibble,
    DataTag.RegReg,
    DataTag.RegReg,
    DataTag.RegReg,
    DataTag.RegReg,
    DataTag.RegReg,
    DataTag.RegReg,
    DataTag.RegReg,
    DataTag.RegReg,
    DataTag.RegReg,
    DataTag.RegReg,
    DataTag.Tibble,
    DataTag.Tibble,
    DataTag.RegDibble,
    DataTag.RegRegNibble,
    DataTag.Reg,
    DataTag.Reg,
    DataTag.Reg,
    DataTag.Reg,
    DataTag.Reg,
    DataTag.Reg,
    DataTag.Reg,
    DataTag.Reg,
    DataTag.Reg,
    DataTag.Reg,
    DataTag.Reg,
    DataTag.Invalid,
};

test "Tag and Tags length match" {
    try std.testing.expect(Tags.len == TagLength);
    try std.testing.expect(DataTags.len == Tags.len);
}

pub fn get_tag(self: *const Self) []const u8 {
    return Tags[@intFromEnum(self.tag)];
}

pub fn get_mnemonic(self: *const Self, writer: anytype) !void {
    const opcode = "{s:<4}";
    const xibble = "{s:<4} 0x{X}";
    const reg = "{s:<4} V{X}";
    const reg_dibble = "{s:<4} V{X}, 0x{X}";
    const reg_reg = "{s:<4} V{X}, V{X}";
    const reg_reg_nibble = "{s:<4} V{X}, V{X}, 0x{X}";

    const format = std.fmt.format;

    // This kinda seems poorly named, but if we break from the early exit that means
    // we don't exit early
    early_exit: {
        switch (self.tag) {
            Tag.LDI => try format(writer, "{s:<4} I, 0x{X}", .{ self.get_tag(), self.data.tibble.value }),
            Tag.JMPV => try format(writer, reg_dibble, .{ self.get_tag(), 0, self.data.tibble.value }),
            Tag.LDRT => try format(writer, "{s:<4} V{X}, DT", .{ self.get_tag(), self.data.reg.x }),
            Tag.LDRK => try format(writer, "{s:<4} V{X}, KEY", .{ self.get_tag(), self.data.reg.x }),
            Tag.LDTR => try format(writer, "{s:<4} DT, V{X}", .{ self.get_tag(), self.data.reg.x }),
            Tag.LDSR => try format(writer, "{s:<4} ST, V{X}", .{ self.get_tag(), self.data.reg.x }),
            Tag.ADDI => try format(writer, "{s:<4} I, V{X}", .{ self.get_tag(), self.data.reg.x }),
            Tag.LDIF => try format(writer, "{s:<4} I, Font(V{X})", .{ self.get_tag(), self.data.reg.x }),
            Tag.LDIM => try format(writer, "{s:<4} [I], V{X}", .{ self.get_tag(), self.data.reg.x }),
            Tag.LDMI => try format(writer, "{s:<4} V{X}, [I]", .{ self.get_tag(), self.data.reg.x }),
            else => break :early_exit,
        }
        return;
    }

    const tag_type = switch (self.tag) {
        Tag.CLS => DataTag.Opcode,
        Tag.RET => DataTag.Opcode,
        Tag.JMP => DataTag.Tibble,
        Tag.CALL => DataTag.Tibble,
        Tag.SE => DataTag.RegDibble,
        Tag.SNE => DataTag.RegDibble,
        Tag.SER => DataTag.RegReg,
        Tag.LD => DataTag.RegDibble,
        Tag.ADD => DataTag.RegDibble,
        Tag.LDR => DataTag.RegReg,
        Tag.OR => DataTag.RegReg,
        Tag.AND => DataTag.RegReg,
        Tag.XOR => DataTag.RegReg,
        Tag.ADDR => DataTag.RegReg,
        Tag.SUB => DataTag.RegReg,
        Tag.SHR => DataTag.RegReg,
        Tag.SUBN => DataTag.RegReg,
        Tag.SHL => DataTag.RegReg,
        Tag.SNER => DataTag.RegReg,
        Tag.LDI => DataTag.Tibble,
        Tag.JMPV => DataTag.Tibble,
        Tag.RND => DataTag.RegDibble,
        Tag.DRW => DataTag.RegRegNibble,
        Tag.SKP => DataTag.Reg,
        Tag.SKNP => DataTag.Reg,
        Tag.LDRT => DataTag.Reg,
        Tag.LDRK => DataTag.Reg,
        Tag.LDTR => DataTag.Reg,
        Tag.LDSR => DataTag.Reg,
        Tag.ADDI => DataTag.Reg,
        Tag.LDIF => DataTag.Reg,
        Tag.BCD => DataTag.Reg,
        Tag.LDIM => DataTag.Reg,
        Tag.LDMI => DataTag.Reg,
        Tag.@"???" => DataTag.Invalid,
    };

    switch (tag_type) {
        DataTag.Opcode => try format(writer, opcode, .{self.get_tag()}),
        DataTag.Dibble => try format(writer, xibble, .{ self.get_tag(), self.data.tibble.value }),
        DataTag.Tibble => try format(writer, xibble, .{ self.get_tag(), self.data.tibble.value }),
        DataTag.Reg => try format(writer, reg, .{ self.get_tag(), self.data.reg.x }),
        DataTag.RegDibble => try format(writer, reg_dibble, .{ self.get_tag(), self.data.reg_dibble.x, self.data.reg_dibble.value }),
        DataTag.RegReg => try format(writer, reg_reg, .{ self.get_tag(), self.data.reg_reg.x, self.data.reg_reg.y }),
        DataTag.RegRegNibble => try format(writer, reg_reg_nibble, .{ self.get_tag(), self.data.reg_reg_nibble.x, self.data.reg_reg_nibble.y, self.data.reg_reg_nibble.value }),
        DataTag.Invalid => try format(writer, xibble, .{ self.get_tag(), self.data.opcode }),
    }
}

pub fn encode(self: *Self) u16 {
    if (self.tag == Tag.@"???") {
        // Should we encode invalid instructions?
        // Or should the user just not blow their own foot off?
    }
    return @as(u16, @bitCast(self.data));
}

pub fn decode(opcode: u16) Self {
    // For opcode instructions, check so we can exit early
    if (opcode == 0x00E0) {
        return Self{
            .tag = Tag.CLS,
            .data = .{ .opcode = opcode },
        };
    } else if (opcode == 0x00EE) {
        return Self{
            .tag = .RET,
            .data = .{ .opcode = opcode },
        };
    }

    const first = opcode >> 12;
    const tag = switch (first) {
        0x1 => Tag.JMP,
        0x2 => Tag.CALL,
        0x3 => Tag.SE,
        0x4 => Tag.SNE,
        0x5 => Tag.SER,
        0x6 => Tag.LD,
        0x7 => Tag.ADD,
        0x8 => switch (opcode & 0x000F) {
            0x0 => Tag.LDR,
            0x1 => Tag.OR,
            0x2 => Tag.AND,
            0x3 => Tag.XOR,
            0x4 => Tag.ADDR,
            0x5 => Tag.SUB,
            0x6 => Tag.SHR,
            0x7 => Tag.SUBN,
            0xE => Tag.SHL,
            else => Tag.@"???",
        },
        0x9 => Tag.SNER,
        0xA => Tag.LDI,
        0xB => Tag.JMPV,
        0xC => Tag.RND,
        0xD => Tag.DRW,
        0xE => switch (opcode & 0x00FF) {
            0x9E => Tag.SKP,
            0xA1 => Tag.SKNP,
            else => Tag.@"???",
        },
        0xF => switch (opcode & 0x00FF) {
            0x07 => Tag.LDRT,
            0x0A => Tag.LDRK,
            0x15 => Tag.LDTR,
            0x18 => Tag.LDSR,
            0x1E => Tag.ADDI,
            0x29 => Tag.LDIF,
            0x33 => Tag.BCD,
            0x55 => Tag.LDIM,
            0x65 => Tag.LDMI,
            else => Tag.@"???",
        },
        else => Tag.@"???",
    };
    // Default: return invalid instruction
    return Self{ .tag = tag, .data = @as(Data, @bitCast(opcode)) };
}
