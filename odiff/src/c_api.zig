const std = @import("std");
const image_io = @import("image_io.zig");
const diff = @import("diff.zig");

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
    ignore_regions: ?[*]const diff.IgnoreRegion,
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

    // Load images
    std.debug.print("LOADING_IMAGE {s}", .{base_image_path});
    std.debug.print("LOADING_IMAGE {s}", .{std.mem.span(base_image_path)});
    var base_img = image_io.loadImage(std.mem.span(base_image_path), allocator) catch |err| switch (err) {
        error.ImageNotLoaded => return .image_not_loaded,
        error.UnsupportedFormat => return .unsupported_format,
        else => return .failed_to_diff,
    };
    defer base_img.deinit();

    var comp_img = image_io.loadImage(std.mem.span(comp_image_path), allocator) catch |err| switch (err) {
        error.ImageNotLoaded => return .image_not_loaded,
        error.UnsupportedFormat => return .unsupported_format,
        else => return .failed_to_diff,
    };
    defer comp_img.deinit();

    // Convert options
    var ignore_regions: ?[]const diff.IgnoreRegion = null;
    if (c_options.ignore_regions) |regions| {
        ignore_regions = regions[0..c_options.ignore_region_count];
    }

    const diff_options = diff.DiffOptions{
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

    const result = diff.diff(&base_img, &comp_img, diff_options, allocator) catch return .failed_to_diff;

    switch (result) {
        .layout => {
            // For layout differences, we can't return detailed results in this simple API
            // Perhaps extend later
            return .success; // Or define a way to indicate layout diff
        },
        .pixel => |pixel_result| {
            defer {
                if (pixel_result.diff_output) |*output| {
                    var img = output.*;
                    img.deinit();
                }
                if (pixel_result.diff_lines) |lines| {
                    var mutable_lines = lines;
                    mutable_lines.deinit();
                }
            }

            if (diff_output_path) |output_path| {
                if (pixel_result.diff_output) |output_img| {
                    image_io.saveImage(&output_img, std.mem.span(output_path), allocator) catch return .failed_to_diff;
                }
            }

            // In this simple API, we don't return the detailed results back to C
            // Just perform the diff and save if needed
            return .success;
        },
    }
}

// Simplified version that returns results
pub export fn odiff_diff_with_results(
    base_image_path: [*:0]const u8,
    comp_image_path: [*:0]const u8,
    diff_output_path: ?[*:0]const u8,
    c_options: CDiffOptions,
    out_result: *CDiffResult,
) COdiffError {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Load images
    var base_img = image_io.loadImage(std.mem.span(base_image_path), allocator) catch |err| switch (err) {
        error.ImageNotLoaded => return .image_not_loaded,
        error.UnsupportedFormat => return .unsupported_format,
        else => return .failed_to_diff,
    };
    defer base_img.deinit();

    var comp_img = image_io.loadImage(std.mem.span(comp_image_path), allocator) catch |err| switch (err) {
        error.ImageNotLoaded => return .image_not_loaded,
        error.UnsupportedFormat => return .unsupported_format,
        else => return .failed_to_diff,
    };
    defer comp_img.deinit();
    std.debug.print("Base Image: {s}\n", .{base_image_path});
    std.debug.print("Base Image: {s}\n", .{comp_image_path});

    // Convert options
    var ignore_regions: ?[]const diff.IgnoreRegion = null;
    if (c_options.ignore_regions) |regions| {
        ignore_regions = regions[0..c_options.ignore_region_count];
    }

    const diff_options = diff.DiffOptions{
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

    const result = diff.diff(&base_img, &comp_img, diff_options, allocator) catch return .failed_to_diff;

    switch (result) {
        .layout => {
            out_result.result_type = 0;
            out_result.diff_count = 0;
            out_result.diff_percentage = 0.0;
            out_result.diff_line_count = 0;
            out_result.diff_lines = null;
            out_result.diff_output_path = null;
            return .success;
        },
        .pixel => |pixel_result| {
            defer {
                if (pixel_result.diff_output) |*output| {
                    var img = output.*;
                    img.deinit();
                }
            }

            out_result.result_type = 1;
            out_result.diff_count = pixel_result.diff_count;
            out_result.diff_percentage = pixel_result.diff_percentage;
            out_result.diff_line_count = 0;
            out_result.diff_lines = null;
            out_result.diff_output_path = diff_output_path;

            if (pixel_result.diff_lines) |*lines| {
                defer @constCast(lines).deinit();
                if (lines.count > 0) {
                    // Copy diff lines to C-allocated memory
                    const lines_copy = allocator.alloc(u32, lines.count) catch return .out_of_memory;
                    @memcpy(lines_copy, lines.getItems());
                    out_result.diff_lines = lines_copy.ptr;
                    out_result.diff_line_count = lines.count;
                }
            }

            if (diff_output_path) |output_path| {
                if (pixel_result.diff_output) |output_img| {
                    image_io.saveImage(&output_img, std.mem.span(output_path), allocator) catch return .failed_to_diff;
                }
            }

            return .success;
        },
    }
}

// Function to free memory allocated for diff_lines
pub export fn odiff_free_diff_lines(diff_lines: [*]u32, count: usize) void {
    const slice = diff_lines[0..count];
    std.heap.page_allocator.free(slice);
}
