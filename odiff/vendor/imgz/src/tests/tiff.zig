const std = @import("std");
const generateGradientPixels = @import("shared.zig").generateGradientPixels;

test "tiff encode" {
    const c = @cImport({
        @cInclude("tiffio.h");
    });

    const width: u32 = 16;
    const height: u32 = 16;

    const pixels = try generateGradientPixels(std.testing.allocator, width, height, true);
    defer std.testing.allocator.free(pixels);

    var temp_dir = std.testing.tmpDir(.{});
    defer temp_dir.cleanup();
    (try temp_dir.dir.createFile("temp_output.tiff", .{})).close();
    var output_path_buf = std.mem.zeroes([std.fs.max_path_bytes]u8);
    const output_path = try temp_dir.dir.realpathZ("temp_output.tiff", &output_path_buf);

    const tif = c.TIFFOpen(output_path.ptr, "w") orelse return error.FailedToCreateTIFF;
    defer _ = c.TIFFClose(tif);

    _ = c.TIFFSetField(tif, c.TIFFTAG_IMAGEWIDTH, @as(c_uint, width));
    _ = c.TIFFSetField(tif, c.TIFFTAG_IMAGELENGTH, @as(c_uint, height));
    _ = c.TIFFSetField(tif, c.TIFFTAG_SAMPLESPERPIXEL, @as(c_int, 4));
    _ = c.TIFFSetField(tif, c.TIFFTAG_BITSPERSAMPLE, @as(c_int, 8));
    _ = c.TIFFSetField(tif, c.TIFFTAG_ORIENTATION, @as(c_int, c.ORIENTATION_TOPLEFT));
    _ = c.TIFFSetField(tif, c.TIFFTAG_PLANARCONFIG, @as(c_int, c.PLANARCONFIG_CONTIG));
    _ = c.TIFFSetField(tif, c.TIFFTAG_PHOTOMETRIC, @as(c_int, c.PHOTOMETRIC_RGB));
    _ = c.TIFFSetField(tif, c.TIFFTAG_COMPRESSION, @as(c_int, c.COMPRESSION_NONE));
    _ = c.TIFFSetField(tif, c.TIFFTAG_ROWSPERSTRIP, @as(c_uint, height));

    if (c.TIFFWriteEncodedStrip(tif, @as(u32, 0), pixels.ptr, @as(c_long, @intCast(pixels.len))) == -1) {
        return error.FailedToEncode;
    }

    const stat = try temp_dir.dir.statFile("temp_output.tiff");
    try std.testing.expect(stat.size > 0);
}

test "tiff decode" {
    const c = @cImport({
        @cInclude("tiffio.h");
    });

    const image_path = "src/tests/test-images/orange.tiff";
    const tif = c.TIFFOpen(image_path, "r") orelse return error.FailedToOpenTIFF;
    defer _ = c.TIFFClose(tif);

    var width: u32 = 0;
    var height: u32 = 0;
    _ = c.TIFFGetField(tif, c.TIFFTAG_IMAGEWIDTH, &width);
    _ = c.TIFFGetField(tif, c.TIFFTAG_IMAGELENGTH, &height);

    const pixels = try std.testing.allocator.alloc(u32, @as(usize, width) * @as(usize, height));
    defer std.testing.allocator.free(pixels);

    if (c.TIFFReadRGBAImage(tif, width, height, pixels.ptr, 0) == 0) {
        return error.FailedToDecode;
    }

    // Verify that we have some pixels
    try std.testing.expect(pixels.len > 0);
}
