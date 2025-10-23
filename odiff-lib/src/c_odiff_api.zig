const std = @import("std");
const odiff = @import("odiff-lib").diff;
const image_io = @import("odiff-lib").io;

// C-compatible structs
pub const CDiffOptions = extern struct {
    antialiasing: bool,
    output_diff_mask: bool,
    diff_overlay_factor: f32, // 0.0 if not set
    diff_lines: bool,
    diff_pixel: u32,
    threshold: f64,
    fail_on_layout_change: bool,
    enable_asm: bool,
    ignore_region_count: usize,
    ignore_regions: ?[*]const odiff.IgnoreRegion,
};

pub const CDiffResult = extern struct {
    result_type: c_int, // 0 = layout, 1 = pixel
    diff_count: u32,
    diff_percentage: f64,
    diff_line_count: usize,
    diff_lines: ?[*]u32,
    diff_output_path: ?[*:0]const u8, // if saved
};

pub const COdiffError = enum(c_int) {
    success = 0,
    image_not_loaded = 1,
    unsupported_format = 2,
    failed_to_diff = 3,
    out_of_memory = 4,
    invalid_hex_color = 5,
};

fn parseHexColor(hex: []const u8) !u32 {
    if (hex.len != 7 or hex[0] != '#') return error.InvalidHexColor;
    return std.fmt.parseInt(u32, hex[1..], 16) catch error.InvalidHexColor;
}

pub export fn odiff_diff(
    base_image_path: [*:0]const u8,
    comp_image_path: [*:0]const u8,
    diff_output_path: ?[*:0]const u8,
    c_options: CDiffOptions,
) COdiffError {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var base_img = image_io.loadImage(allocator, std.mem.span(base_image_path)) catch |err| switch (err) {
        error.ImageNotLoaded => return .image_not_loaded,
        error.UnsupportedFormat => return .unsupported_format,
        else => return .failed_to_diff,
    };
    defer base_img.deinit(allocator);

    var comp_img = image_io.loadImage(allocator, std.mem.span(comp_image_path)) catch |err| switch (err) {
        error.ImageNotLoaded => return .image_not_loaded,
        error.UnsupportedFormat => return .unsupported_format,
        else => return .failed_to_diff,
    };
    defer comp_img.deinit(allocator);

    var ignore_regions: ?[]const odiff.IgnoreRegion = null;
    if (c_options.ignore_regions) |regions| {
        ignore_regions = regions[0..c_options.ignore_region_count];
    }

    const diff_options = odiff.DiffOptions{
        .antialiasing = c_options.antialiasing,
        .output_diff_mask = c_options.output_diff_mask,
        .diff_overlay_factor = if (c_options.diff_overlay_factor > 0.0) c_options.diff_overlay_factor else null,
        .diff_lines = c_options.diff_lines,
        .diff_pixel = c_options.diff_pixel,
        .threshold = c_options.threshold,
        .ignore_regions = ignore_regions,
        .capture_diff = diff_output_path != null,
        .fail_on_layout_change = c_options.fail_on_layout_change,
        .enable_asm = c_options.enable_asm,
    };

    const result = odiff.diff(&base_img, &comp_img, diff_options, allocator) catch return .failed_to_diff;

    switch (result) {
        .layout => {
            return .success; // Or define a way to indicate layout diff
        },
        .pixel => |pixel_result| {
            defer {
                if (pixel_result.diff_output) |*output| {
                    var img = output.*;
                    img.deinit(allocator);
                }
                if (pixel_result.diff_lines) |lines| {
                    var mutable_lines = lines;
                    mutable_lines.deinit();
                }
            }

            if (diff_output_path) |output_path| {
                if (pixel_result.diff_output) |output_img| {
                    image_io.saveImage(output_img, std.mem.span(output_path)) catch return .failed_to_diff;
                }
            }

            return .success;
        },
    }
}

pub export fn odiff_free_diff_lines(diff_lines: [*]u32, count: usize) void {
    const slice = diff_lines[0..count];
    std.heap.page_allocator.free(slice);
}

pub export fn parse_hex_color(hex: [*:0]const u8) u32 {
    const hex_str = std.mem.span(hex);
    if (hex_str.len == 0) return 0xFF0000FF;

    var color_str = hex_str;
    if (hex_str[0] == '#') {
        color_str = hex_str[1..];
    }

    if (color_str.len != 6) {
        @panic("Invalid Hex Color");
    }

    const r = std.fmt.parseInt(u8, color_str[0..2], 16) catch @panic("R is missing");
    const g = std.fmt.parseInt(u8, color_str[2..4], 16) catch @panic("G is missing");
    const b = std.fmt.parseInt(u8, color_str[4..6], 16) catch @panic("B is missing");

    return (@as(u32, 255) << 24) | (@as(u32, b) << 16) | (@as(u32, g) << 8) | @as(u32, r);
}
