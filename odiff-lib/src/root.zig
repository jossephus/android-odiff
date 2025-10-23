const std = @import("std");

pub const c_api = @import("c_odiff_api.zig");

// Ensure C API functions are included
comptime {
    _ = c_api.odiff_diff;
    _ = c_api.odiff_free_diff_lines;
}

// Export allocator functions for C code to use
export fn zig_alloc(allocator_ptr: *anyopaque, size: usize) ?[*]u8 {
    const allocator: *std.mem.Allocator = @ptrCast(@alignCast(allocator_ptr));
    const memory = allocator.alloc(u8, size) catch return null;
    return memory.ptr;
}

export fn zig_free(allocator_ptr: *anyopaque, ptr: [*]u8, size: usize) void {
    const allocator: *std.mem.Allocator = @ptrCast(@alignCast(allocator_ptr));
    const memory = ptr[0..size];
    allocator.free(memory);
}
