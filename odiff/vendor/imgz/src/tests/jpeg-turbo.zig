const std = @import("std");
const generateGradientPixels = @import("shared.zig").generateGradientPixels;

test "jpeg-turbo encode" {
    const jpeg_c = @cImport({
        @cInclude("stddef.h");
        @cInclude("stdio.h");
        @cInclude("jpeglib.h");
    });

    const width: u32 = 16;
    const height: u32 = 16;

    const rgb_pixels = try generateGradientPixels(std.testing.allocator, width, height, false);
    defer std.testing.allocator.free(rgb_pixels);

    // Encode to JPEG in memory
    var jpeg_buffer: ?[*]u8 = null;
    var jpeg_size: c_ulong = 0;
    var cinfo: jpeg_c.jpeg_compress_struct = undefined;
    var jerr: jpeg_c.jpeg_error_mgr = undefined;
    cinfo.err = jpeg_c.jpeg_std_error(&jerr);
    jpeg_c.jpeg_create_compress(&cinfo);
    defer jpeg_c.jpeg_destroy_compress(&cinfo);
    jpeg_c.jpeg_mem_dest(&cinfo, &jpeg_buffer, &jpeg_size);
    cinfo.image_width = width;
    cinfo.image_height = height;
    cinfo.input_components = 3;
    cinfo.in_color_space = jpeg_c.JCS_RGB;
    jpeg_c.jpeg_set_defaults(&cinfo);
    jpeg_c.jpeg_set_quality(&cinfo, 90, 1);
    jpeg_c.jpeg_start_compress(&cinfo, 1);
    const row_stride = width * 3;
    var row_ptr: [*]u8 = rgb_pixels.ptr;
    while (cinfo.next_scanline < cinfo.image_height) {
        var row_pointers: [1][*]u8 = .{row_ptr};
        _ = jpeg_c.jpeg_write_scanlines(&cinfo, @as([*c][*c]u8, @ptrCast(&row_pointers)), 1);
        row_ptr += row_stride;
    }
    jpeg_c.jpeg_finish_compress(&cinfo);
    try std.testing.expect(jpeg_size > 0);
}

test "jpeg-turbo decode" {
    const jpeg_c = @cImport({
        @cInclude("stddef.h");
        @cInclude("stdio.h");
        @cInclude("jpeglib.h");
    });

    const jpeg_data = @embedFile("test-images/orange.jpeg");

    var dinfo: jpeg_c.jpeg_decompress_struct = undefined;
    var djerr: jpeg_c.jpeg_error_mgr = undefined;
    dinfo.err = jpeg_c.jpeg_std_error(&djerr);
    jpeg_c.jpeg_create_decompress(&dinfo);
    defer jpeg_c.jpeg_destroy_decompress(&dinfo);
    jpeg_c.jpeg_mem_src(&dinfo, jpeg_data.ptr, @as(c_ulong, @intCast(jpeg_data.len)));
    if (jpeg_c.jpeg_read_header(&dinfo, 1) != jpeg_c.JPEG_HEADER_OK) {
        return error.FailedToReadHeader;
    }
    _ = jpeg_c.jpeg_start_decompress(&dinfo);
    const decoded_rgb = try std.testing.allocator.alloc(u8, @as(usize, dinfo.output_width) * @as(usize, dinfo.output_height) * @as(usize, @intCast(dinfo.num_components)));
    defer std.testing.allocator.free(decoded_rgb);
    var decoded_row_ptr: [*]u8 = decoded_rgb.ptr;
    const decoded_row_stride = @as(usize, dinfo.output_width) * @as(usize, @intCast(dinfo.num_components));
    while (dinfo.output_scanline < dinfo.output_height) {
        var decoded_row_pointers: [1][*]u8 = .{decoded_row_ptr};
        _ = jpeg_c.jpeg_read_scanlines(&dinfo, @as([*c][*c]u8, @ptrCast(&decoded_row_pointers)), 1);
        decoded_row_ptr += decoded_row_stride;
    }
    _ = jpeg_c.jpeg_finish_decompress(&dinfo);
    try std.testing.expect(decoded_rgb.len > 0);
}
