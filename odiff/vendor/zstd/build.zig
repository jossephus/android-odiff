const std = @import("std");

const DEFAULT_NDK_PATH = "/nix/store/lnvzilffxf3wb6dg6fsgg12aacpip3ch-android-sdk-env/share/android-sdk/ndk/29.0.13113456/toolchains/llvm/prebuilt/linux-x86_64/sysroot/"; // Based on the current flake.nix and flake.locks
const DEFAULT_NDK_VERSION = "29.0.13113456";
const DEFAULT_ANDROID_API_VERSION: u32 = 34;

const build_targets: []const std.Target.Query = &.{
    .{ .cpu_arch = .aarch64, .os_tag = .linux, .abi = .android, .android_api_level = 34 },
    .{ .cpu_arch = .arm, .os_tag = .linux, .abi = .androideabi, .android_api_level = 34 },
    .{ .cpu_arch = .x86, .os_tag = .linux, .abi = .android, .android_api_level = 34 },
    .{ .cpu_arch = .x86_64, .os_tag = .linux, .abi = .android, .android_api_level = 34 },
};

pub fn build(b: *std.Build) !void {
    const upstream = b.dependency("zstd", .{});
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});

    const ndk_path = b.option([]const u8, "ndk-path", "Path to Android NDK sysroot") orelse DEFAULT_NDK_PATH;
    const ndk_version = b.option([]const u8, "ndk-version", "Android NDK version") orelse DEFAULT_NDK_VERSION;
    const android_api_version = b.option(u32, "android-api", "Android API level") orelse DEFAULT_ANDROID_API_VERSION;

    const linkage = b.option(std.builtin.LinkMode, "linkage", "Link mode") orelse .static;
    const strip = b.option(bool, "strip", "Omit debug information");
    const pic = b.option(bool, "pie", "Produce Position Independent Code");

    const compression = b.option(bool, "compression", "build compression module") orelse true;
    const decompression = b.option(bool, "decompression", "build decompression module") orelse true;
    const dictbuilder = b.option(bool, "dictbuilder", "build dictbuilder module") orelse compression;
    const deprecated = b.option(bool, "deprecated", "build deprecated module") orelse false;

    const minify = b.option(bool, "minify", "Configures a bunch of other options to space-optimized defaults") orelse false;
    const legacy_support = b.option(usize, "legacy-support", "makes it possible to decompress legacy zstd formats") orelse @as(usize, if (minify) 0 else 5);
    // For example, `-Dlegacy-support=0` means: no support for legacy formats
    // For example, `-Dlegacy-support=2` means: support legacy formats >= v0.2.0
    std.debug.assert(legacy_support < 8);

    const disable_assembly = b.option(bool, "disable-assembly", "Assembly support") orelse false;
    const huf_force_decompress_x1 = b.option(bool, "huf-force-decompress-x1", "") orelse minify;
    const huf_force_decompress_x2 = b.option(bool, "huf-force-decompress-x2", "") orelse false;
    const force_decompress_sequences_short = b.option(bool, "force-decompress-sequences-short", "") orelse minify;
    const force_decompress_sequences_long = b.option(bool, "force-decompress-sequences-long", "") orelse false;
    const no_inline = b.option(bool, "no-inline", "Disable Inlining") orelse minify;
    const strip_error_strings = b.option(bool, "strip-error-strings", "removes the error messages that are otherwise returned by `ZSTD_getErrorName` (implied by `-Dminify`)") orelse minify;
    const exclude_compressors_dfast_and_up = b.option(bool, "exclude-compressors-dfast-and-up", "") orelse false;
    const exclude_compressors_greedy_and_up = b.option(bool, "exclude-compressors-greedy-and-up", "") orelse false;
    const multi_thread = b.option(bool, "multi-thread", "Enable multi-threading") orelse true;

    //for (build_targets) |target_query| {
    //const target = b.resolveTargetQuery(target_query);
    //const abi_output_dir = getOutputDir(target.result) catch |err| {
    //std.log.err("Unsupported target architecture: {}", .{target.result.cpu.arch});
    //return err;
    //};
    //const header_output_dir = try std.fs.path.join(b.allocator, &.{ abi_output_dir, "include" });

    const zstd = b.addLibrary(.{
        .linkage = linkage,
        .name = "zstd",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .strip = strip,
            .pic = pic,
            .link_libc = true,
        }),
    });

    zstd.linkLibC();

    const android_triple = getAndroidTriple(zstd.rootModuleTarget()) catch |err| @panic(@errorName(err));

    const libc_config = createLibC(b, android_triple, android_api_version, ndk_path, ndk_version);

    zstd.setLibCFile(libc_config);

    zstd.root_module.addCSourceFiles(.{ .root = upstream.path("lib"), .files = common_sources });
    // zstd does not install into its own subdirectory. :(
    zstd.installHeader(upstream.path("lib/zstd.h"), "zstd.h");
    zstd.installHeader(upstream.path("lib/zdict.h"), "zdict.h");
    zstd.installHeader(upstream.path("lib/zstd_errors.h"), "zstd_errors.h");
    if (compression) zstd.addCSourceFiles(.{ .root = upstream.path("lib"), .files = compression_sources });
    if (decompression) zstd.addCSourceFiles(.{ .root = upstream.path("lib"), .files = decompress_sources });
    if (dictbuilder) zstd.addCSourceFiles(.{ .root = upstream.path("lib"), .files = dict_builder_sources });
    if (deprecated) zstd.addCSourceFiles(.{ .root = upstream.path("lib"), .files = deprecated_sources });
    if (legacy_support != 0) {
        for (legacy_support..8) |i| zstd.addCSourceFile(.{ .file = upstream.path(b.fmt("lib/legacy/zstd_v0{d}.c", .{i})) });
    }

    if (target.result.cpu.arch == .x86_64) {
        if (decompression) {
            zstd.root_module.addAssemblyFile(upstream.path("lib/decompress/huf_decompress_amd64.S"));
        }
    } else {
        zstd.root_module.addCMacro("ZSTD_DISABLE_ASM", "");
    }

    zstd.root_module.addCMacro("ZSTD_LEGACY_SUPPORT", b.fmt("{d}", .{legacy_support}));
    if (multi_thread) zstd.root_module.addCMacro("ZSTD_MULTITHREAD", "1");
    if (disable_assembly) zstd.root_module.addCMacro("ZSTD_DISABLE_ASM", "");
    if (huf_force_decompress_x1) zstd.root_module.addCMacro("HUF_FORCE_DECOMPRESS_X1", "");
    if (huf_force_decompress_x2) zstd.root_module.addCMacro("HUF_FORCE_DECOMPRESS_X2", "");
    if (force_decompress_sequences_short) zstd.root_module.addCMacro("ZSTD_FORCE_DECOMPRESS_SEQUENCES_SHORT", "");
    if (force_decompress_sequences_long) zstd.root_module.addCMacro("ZSTD_FORCE_DECOMPRESS_SEQUENCES_LONG", "");
    if (no_inline) zstd.root_module.addCMacro("ZSTD_NO_INLINE", "");
    if (strip_error_strings) zstd.root_module.addCMacro("ZSTD_STRIP_ERROR_STRINGS", "");
    if (exclude_compressors_dfast_and_up) {
        zstd.root_module.addCMacro("ZSTD_EXCLUDE_DFAST_BLOCK_COMPRESSOR", "");
        zstd.root_module.addCMacro("ZSTD_EXCLUDE_GREEDY_BLOCK_COMPRESSOR", "");
        zstd.root_module.addCMacro("ZSTD_EXCLUDE_LAZY2_BLOCK_COMPRESSOR", "");
        zstd.root_module.addCMacro("ZSTD_EXCLUDE_BTLAZY2_BLOCK_COMPRESSOR", "");
        zstd.root_module.addCMacro("ZSTD_EXCLUDE_BTOPT_BLOCK_COMPRESSOR", "");
        zstd.root_module.addCMacro("ZSTD_EXCLUDE_BTULTRA_BLOCK_COMPRESSOR", "");
    }
    if (exclude_compressors_greedy_and_up) {
        zstd.root_module.addCMacro("ZSTD_EXCLUDE_GREEDY_BLOCK_COMPRESSOR", "");
        zstd.root_module.addCMacro("ZSTD_EXCLUDE_LAZY2_BLOCK_COMPRESSOR", "");
        zstd.root_module.addCMacro("ZSTD_EXCLUDE_BTLAZY2_BLOCK_COMPRESSOR", "");
        zstd.root_module.addCMacro("ZSTD_EXCLUDE_BTOPT_BLOCK_COMPRESSOR", "");
        zstd.root_module.addCMacro("ZSTD_EXCLUDE_BTULTRA_BLOCK_COMPRESSOR", "");
    }

    //const install_artifact = b.addInstallArtifact(zstd, .{
    //.h_dir = .{
    //.override = .{
    //.custom = header_output_dir,
    //},
    //},
    //.dest_dir = .{
    //.override = .{
    //.custom = abi_output_dir,
    //},
    //},
    //});

    //b.getInstallStep().dependOn(&install_artifact.step);
    b.installArtifact(zstd);
    //}
}

const common_sources: []const []const u8 = &.{
    "common/zstd_common.c",
    "common/threading.c",
    "common/entropy_common.c",
    "common/fse_decompress.c",
    "common/xxhash.c",
    "common/error_private.c",
    "common/pool.c",
};

const compression_sources: []const []const u8 = &.{
    "compress/fse_compress.c",
    "compress/huf_compress.c",
    "compress/zstd_double_fast.c",
    "compress/zstd_compress_literals.c",
    "compress/zstdmt_compress.c",
    "compress/zstd_compress_superblock.c",
    "compress/zstd_opt.c",
    "compress/zstd_compress.c",
    "compress/zstd_compress_sequences.c",
    "compress/hist.c",
    "compress/zstd_ldm.c",
    "compress/zstd_lazy.c",
    "compress/zstd_preSplit.c",
    "compress/zstd_fast.c",
};

const decompress_sources: []const []const u8 = &.{
    "decompress/zstd_decompress.c",
    "decompress/huf_decompress.c",
    "decompress/zstd_decompress_block.c",
    "decompress/zstd_ddict.c",
};

const dict_builder_sources: []const []const u8 = &.{
    "dictBuilder/divsufsort.c",
    "dictBuilder/zdict.c",
    "dictBuilder/cover.c",
    "dictBuilder/fastcover.c",
};

const deprecated_sources: []const []const u8 = &.{
    "deprecated/zbuff_decompress.c",
    "deprecated/zbuff_common.c",
    "deprecated/zbuff_compress.c",
};

const legacy_sources: []const []const u8 = &.{
    "legacy/zstd_v01.c",
    "legacy/zstd_v02.c",
    "legacy/zstd_v03.c",
    "legacy/zstd_v04.c",
    "legacy/zstd_v05.c",
    "legacy/zstd_v06.c",
    "legacy/zstd_v07.c",
};

// Convert Zig target to Android NDK triple format
fn getAndroidTriple(target: std.Target) error{InvalidAndroidTarget}![]const u8 {
    if (target.abi != .android and target.abi != .androideabi) return error.InvalidAndroidTarget;
    return switch (target.cpu.arch) {
        .x86 => "i686-linux-android",
        .x86_64 => "x86_64-linux-android",
        .arm => "arm-linux-androideabi",
        .aarch64 => "aarch64-linux-android",
        .riscv64 => "riscv64-linux-android",
        else => error.InvalidAndroidTarget,
    };
}

// Get Android ABI output directory name from target architecture
fn getOutputDir(target: std.Target) ![]const u8 {
    return switch (target.cpu.arch) {
        .aarch64 => "arm64-v8a",
        .arm => "armeabi-v7a",
        .x86 => "x86",
        .x86_64 => "x86_64",
        .riscv64 => "riscv64",
        else => error.UnsupportedArchitecture,
    };
}

// Create Android libc configuration file for Zig
fn createLibC(b: *std.Build, system_target: []const u8, android_api_version: u32, ndk_sysroot_path: []const u8, ndk_version: []const u8) std.Build.LazyPath {
    const libc_file_format =
        \\# Generated by zig-android-sdk. DO NOT EDIT.
        \\
        \\# The directory that contains `stdlib.h`.
        \\# On POSIX-like systems, include directories be found with: `cc -E -Wp,-v -xc /dev/null`
        \\include_dir={[include_dir]s}
        \\
        \\# The system-specific include directory. May be the same as `include_dir`.
        \\# On Windows it's the directory that includes `vcruntime.h`.
        \\# On POSIX it's the directory that includes `sys/errno.h`.
        \\sys_include_dir={[sys_include_dir]s}
        \\
        \\# The directory that contains `crt1.o`.
        \\# On POSIX, can be found with `cc -print-file-name=crt1.o`.
        \\# Not needed when targeting MacOS.
        \\crt_dir={[crt_dir]s}
        \\
        \\# The directory that contains `vcruntime.lib`.
        \\# Only needed when targeting MSVC on Windows.
        \\msvc_lib_dir=
        \\
        \\# The directory that contains `kernel32.lib`.
        \\# Only needed when targeting MSVC on Windows.
        \\kernel32_lib_dir=
        \\
        \\gcc_dir=
    ;

    const include_dir = b.fmt("{s}/usr/include", .{ndk_sysroot_path});
    const sys_include_dir = b.fmt("{s}/usr/include/{s}", .{ ndk_sysroot_path, system_target });
    const crt_dir = b.fmt("{s}/usr/lib/{s}/{d}", .{ ndk_sysroot_path, system_target, android_api_version });

    const libc_file_contents = b.fmt(libc_file_format, .{
        .include_dir = include_dir,
        .sys_include_dir = sys_include_dir,
        .crt_dir = crt_dir,
    });

    const filename = b.fmt("android-libc_target-{s}_version-{d}_ndk-{s}.conf", .{ system_target, android_api_version, if (ndk_version.len > 0) ndk_version else "unknown" });

    const write_file = b.addWriteFiles();
    const android_libc_path = write_file.add(filename, libc_file_contents);
    return android_libc_path;
}
