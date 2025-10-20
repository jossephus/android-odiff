const std = @import("std");
const generateGradientPixels = @import("shared.zig").generateGradientPixels;

test "webp encode" {
    const c = @cImport({
        @cInclude("webp/encode.h");
    });

    const width: c_int = 16;
    const height: c_int = 16;

    const rgba_pixels = try generateGradientPixels(std.testing.allocator, @intCast(width), @intCast(height), true);
    defer std.testing.allocator.free(rgba_pixels);

    var webp_buffer: ?[*]u8 = null;
    const webp_size = c.WebPEncodeRGBA(rgba_pixels.ptr, width, height, width * 4, 90, &webp_buffer);
    try std.testing.expect(webp_size > 0);
    defer c.WebPFree(webp_buffer);
}

test "webp decode" {
    const c = @cImport({
        @cInclude("webp/decode.h");
        @cInclude("webp/encode.h");
    });

    const rgba_pixels = @embedFile("test-images/orange.webp");

    var decoded_width: c_int = 0;
    var decoded_height: c_int = 0;
    const decoded_pixels = c.WebPDecodeRGBA(rgba_pixels.ptr, rgba_pixels.len, &decoded_width, &decoded_height);
    try std.testing.expect(decoded_pixels != null);
    defer c.WebPFree(decoded_pixels);
}
