const std = @import("std");
// I feel like there's probably a better way of doing this.
const c = @import("c.zig").c;

const CHIP8 = @import("chip8.zig");
const panic = std.debug.panic;

var window: *c.SDL_Window = undefined;
var renderer: *c.SDL_Renderer = undefined;
var texture: *c.SDL_Texture = undefined;

var cpu: *CHIP8 = undefined;

pub fn init() void {
    const flags = c.SDL_INIT_VIDEO | c.SDL_INIT_EVENTS;
    if (c.SDL_Init(flags) < 0) panic("SDL Initilization Failed", .{});

    if (c.SDL_CreateWindow("zCHIP-8", c.SDL_WINDOWPOS_CENTERED, c.SDL_WINDOWPOS_CENTERED, 1024, 512, 0)) |val| {
        window = val;
    } else {
        panic("SDL Window Creation Failed", .{});
    }

    if (c.SDL_CreateRenderer(window, -1, 0)) |val| {
        renderer = val;
    } else {
        panic("SDL Renderer Initialization Failed!", .{});
    }

    if (c.SDL_CreateTexture(renderer, c.SDL_PIXELFORMAT_RGBA8888, c.SDL_TEXTUREACCESS_STREAMING, 64, 32)) |val| {
        texture = val;
    } else {
        panic("SDL Texture Initilization Failed!", .{});
    }
}

pub fn deinit() void {
    c.SDL_DestroyWindow(window);
    c.SDL_Quit();
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    init();
    defer deinit();

    cpu = try allocator.create(CHIP8);
    cpu.init();

    // Load a rom from the first command line argument
    var arg_it = try std.process.argsWithAllocator(allocator);
    _ = arg_it.skip();

    var filename = arg_it.next() orelse {
        std.debug.print("Usage: ./zCHIP-8 rom_path\n", .{});
        return;
    };
    try cpu.load_rom(filename);

    var keep_open = true;

    while (keep_open) {
        // Emulator Cycle
        _ = cpu.cycle();

        // Input
        var e: c.SDL_Event = undefined;
        while (c.SDL_PollEvent(&e) > 0) {
            switch (e.type) {
                c.SDL_QUIT => keep_open = false,
                c.SDL_KEYDOWN => {
                    const key = switch (e.key.keysym.scancode) {
                        c.SDL_SCANCODE_X => CHIP8.Key.X,
                        c.SDL_SCANCODE_1 => CHIP8.Key.Key1,
                        c.SDL_SCANCODE_2 => CHIP8.Key.Key2,
                        c.SDL_SCANCODE_3 => CHIP8.Key.Key3,
                        c.SDL_SCANCODE_Q => CHIP8.Key.Q,
                        c.SDL_SCANCODE_W => CHIP8.Key.W,
                        c.SDL_SCANCODE_E => CHIP8.Key.E,
                        c.SDL_SCANCODE_A => CHIP8.Key.A,
                        c.SDL_SCANCODE_S => CHIP8.Key.S,
                        c.SDL_SCANCODE_D => CHIP8.Key.D,
                        c.SDL_SCANCODE_Z => CHIP8.Key.Z,
                        c.SDL_SCANCODE_C => CHIP8.Key.C,
                        c.SDL_SCANCODE_4 => CHIP8.Key.Key4,
                        c.SDL_SCANCODE_R => CHIP8.Key.R,
                        c.SDL_SCANCODE_F => CHIP8.Key.F,
                        c.SDL_SCANCODE_V => CHIP8.Key.V,
                        else => null,
                    };
                    if (key) |k| {
                        std.debug.print("Key {s} Down\n", .{@tagName(k)});
                    }
                },
                c.SDL_KEYUP => {
                    const key = switch (e.key.keysym.scancode) {
                        c.SDL_SCANCODE_X => CHIP8.Key.X,
                        c.SDL_SCANCODE_1 => CHIP8.Key.Key1,
                        c.SDL_SCANCODE_2 => CHIP8.Key.Key2,
                        c.SDL_SCANCODE_3 => CHIP8.Key.Key3,
                        c.SDL_SCANCODE_Q => CHIP8.Key.Q,
                        c.SDL_SCANCODE_W => CHIP8.Key.W,
                        c.SDL_SCANCODE_E => CHIP8.Key.E,
                        c.SDL_SCANCODE_A => CHIP8.Key.A,
                        c.SDL_SCANCODE_S => CHIP8.Key.S,
                        c.SDL_SCANCODE_D => CHIP8.Key.D,
                        c.SDL_SCANCODE_Z => CHIP8.Key.Z,
                        c.SDL_SCANCODE_C => CHIP8.Key.C,
                        c.SDL_SCANCODE_4 => CHIP8.Key.Key4,
                        c.SDL_SCANCODE_R => CHIP8.Key.R,
                        c.SDL_SCANCODE_F => CHIP8.Key.F,
                        c.SDL_SCANCODE_V => CHIP8.Key.V,
                        else => null,
                    };
                    if (key) |k| {
                        std.debug.print("Key {s} Up\n", .{@tagName(k)});
                    }
                },
                else => {},
            }
        }

        // Rendering
        _ = c.SDL_RenderClear(renderer);

        // Build Texture
        var bytes: ?[*]u32 = null;
        var pitch: c_int = 0;

        _ = c.SDL_LockTexture(texture, null, @as([*c]?*anyopaque, @ptrCast(&bytes)), &pitch);

        for (cpu.graphics, 0..) |g, i| {
            bytes.?[i] = if (g == 1) 0xFFFFFFFF else 0x00000000;
        }

        c.SDL_UnlockTexture(texture);

        _ = c.SDL_RenderCopy(renderer, texture, null, null);
        c.SDL_RenderPresent(renderer);
    }
}
