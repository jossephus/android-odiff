const std = @import("std");
const shared = @import("shared.zig");
const RequiredLibrary = shared.RequiredLibrary;
const LazyFileEditor = shared.LazyFileEditor;
const ndk = @import("ndk.zig");
const getAndroidTriple = ndk.getAndroidTriple;
const getOutputDir = ndk.getOutputDir;
const createLibC = ndk.createLibC;
const ndk_path = ndk.DEFAULT_NDK_PATH;
const ndk_version = ndk.DEFAULT_NDK_VERSION;
const android_api_version = ndk.DEFAULT_ANDROID_API_VERSION;

pub const Options = struct {};

pub const Deps = struct {
    libz: RequiredLibrary = RequiredLibrary.bundled,
};

pub fn get(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    option: Options,
    deps: Deps,
) !*std.Build.Step.Compile {
    _ = option;

    const mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    const lib = b.addLibrary(.{
        .name = "spng",
        .root_module = mod,
        .linkage = .static,
    });

    lib.linkLibC();

    const android_triple = getAndroidTriple(lib.rootModuleTarget()) catch |err| @panic(@errorName(err));

    const libc_config = createLibC(b, android_triple, android_api_version, ndk_path, ndk_version);

    lib.setLibCFile(libc_config);

    switch (deps.libz) {
        .system => {
            mod.linkSystemLibrary("z", .{});
        },
        .bundled => if (b.lazyDependency("zlib", .{
            .target = target,
            .optimize = optimize,
        })) |zlib_dep| {
            mod.linkLibrary(zlib_dep.artifact("z"));
        },
        .custom => {}, // user is responsible for providing the library
        .disabled => {
            std.log.err("Spng requires zlib, but it was disabled", .{});
            return error.ZlibDisabled;
        },
    }

    if (b.lazyDependency("spng_upstream", .{})) |spng_dep| {
        mod.addIncludePath(spng_dep.path("spng"));
        mod.addCSourceFiles(.{
            .files = &.{"spng.c"},
            .flags = &.{ "-std=c99", "-DSPNG_STATIC" },
            .root = spng_dep.path("spng"),
        });

        const spng_out_h_gen = LazyFileEditor.create(b, spng_dep.path("spng/spng.h"), "spng.h", spng_header_editor);
        lib.installHeader(spng_out_h_gen.result, "spng.h");
    }

    return lib;
}

fn spng_header_editor(source_contents: []const u8, out_writer: *std.Io.Writer) anyerror!void {
    try out_writer.writeAll(
        \\#ifndef SPNG_STATIC
        \\#define SPNG_STATIC
        \\#endif
        \\
    );
    try out_writer.writeAll(source_contents);
}
