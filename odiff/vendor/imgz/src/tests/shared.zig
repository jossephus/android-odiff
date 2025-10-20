const std = @import("std");

pub fn generateGradientPixels(allocator: std.mem.Allocator, width: u32, height: u32, rgba: bool) ![]u8 {
    var components: usize = 3;
    if (rgba) components = 4;
    const pixels = try allocator.alloc(u8, @as(usize, width) * @as(usize, height) * components);
    const pixel_count = @as(usize, width) * @as(usize, height);
    var i: usize = 0;
    while (i < pixel_count) : (i += 1) {
        const x: u32 = @intCast(i % width);
        const y: u32 = @intCast(i / width);
        const base = i * components;
        pixels[base + 0] = @intCast((x * 255) / (width - 1));
        pixels[base + 1] = @intCast((y * 255) / (height - 1));
        pixels[base + 2] = 0;
        if (rgba) {
            pixels[base + 3] = 255;
        }
    }
    return pixels;
}
