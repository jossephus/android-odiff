const std = @import("std");
const manifest = @import("build.zig.zon");
const Imgz = @import("imgz");

const ndk = @import("ndk.zig");
const getAndroidTriple = ndk.getAndroidTriple;
const getOutputDir = ndk.getOutputDir;
const createLibC = ndk.createLibC;
const ndk_path = ndk.DEFAULT_NDK_PATH;
const ndk_version = ndk.DEFAULT_NDK_VERSION;
const android_api_version = ndk.DEFAULT_ANDROID_API_VERSION;

const build_targets: []const std.Target.Query = &.{
    .{ .cpu_arch = .aarch64, .os_tag = .linux, .abi = .android, .android_api_level = 24 },
    .{ .cpu_arch = .arm, .os_tag = .linux, .abi = .androideabi, .android_api_level = 24 },
    .{ .cpu_arch = .x86, .os_tag = .linux, .abi = .android, .android_api_level = 24 },
    .{ .cpu_arch = .x86_64, .os_tag = .linux, .abi = .android, .android_api_level = 24 },
};

pub fn build(b: *std.Build) !void {
    const optimize = b.standardOptimizeOption(.{});
    const dynamic = b.option(bool, "dynamic", "Link against libspng, libjpeg and libtiff dynamically") orelse false;

    const build_options = b.addOptions();
    build_options.addOption([]const u8, "version", manifest.version);

    for (build_targets) |target_query| {
        const target = b.resolveTargetQuery(target_query);
        const imgz = b.dependency("imgz", .{
            .target = target,
            .optimize = optimize,
        });
        const abi_output_dir = getOutputDir(target.result) catch |err| {
            std.log.err("Unsupported target architecture: {}", .{target.result.cpu.arch});
            return err;
        };

        const header_output_dir = try std.fs.path.join(b.allocator, &.{ abi_output_dir, "include" });
        const build_options_mod = build_options.createModule();

        const lib_mod, const exe = buildOdiff(b, target, optimize, dynamic, build_options_mod);
        _ = exe;

        // Build and install the library
        const root_lib = b.addLibrary(.{
            .name = "odiff",
            .root_module = lib_mod,
            .linkage = if (dynamic) .dynamic else .static,
        });

        root_lib.linkLibC();

        const android_triple = getAndroidTriple(root_lib.rootModuleTarget()) catch |err| @panic(@errorName(err));

        const libc_config = createLibC(b, android_triple, android_api_version, ndk_path, ndk_version);

        root_lib.setLibCFile(libc_config);

        b.installArtifact(root_lib);

        const install_artifact = b.addInstallArtifact(root_lib, .{
            .h_dir = .{
                .override = .{
                    .custom = header_output_dir,
                },
            },
            .dest_dir = .{
                .override = .{
                    .custom = abi_output_dir,
                },
            },
        });

        addInstallArtifact(b, imgz.artifact("z"), b.getInstallStep(), header_output_dir, abi_output_dir);
        addInstallArtifact(b, imgz.artifact("zstd"), b.getInstallStep(), header_output_dir, abi_output_dir);
        addInstallArtifact(b, imgz.artifact("spng"), b.getInstallStep(), header_output_dir, abi_output_dir);
        addInstallArtifact(b, imgz.artifact("jpeg-turbo"), b.getInstallStep(), header_output_dir, abi_output_dir);
        addInstallArtifact(b, imgz.artifact("webp"), b.getInstallStep(), header_output_dir, abi_output_dir);
        addInstallArtifact(b, imgz.artifact("tiff"), b.getInstallStep(), header_output_dir, abi_output_dir);

        b.getInstallStep().dependOn(&install_artifact.step);
    }
}

fn addInstallArtifact(b: *std.Build, lib: *std.Build.Step.Compile, step: *std.Build.Step, header_output_dir: []const u8, abi_output_dir: []const u8) void {
    const zlib_install_artifact = b.addInstallArtifact(lib, .{
        .h_dir = .{
            .override = .{
                .custom = header_output_dir,
            },
        },
        .dest_dir = .{
            .override = .{
                .custom = abi_output_dir,
            },
        },
    });

    step.dependOn(&zlib_install_artifact.step);
}

fn buildOdiff(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    dynamic: bool,
    build_options_mod: *std.Build.Module,
) struct { *std.Build.Module, *std.Build.Step.Compile } {
    const lib_mod = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    linkDeps(b, target, optimize, dynamic, lib_mod);

    var c_flags = std.array_list.Managed([]const u8).init(b.allocator);
    defer c_flags.deinit();
    c_flags.append("-std=c99") catch @panic("OOM");
    c_flags.append("-Wno-nullability-completeness") catch @panic("OOM");
    c_flags.append("-DHAVE_SPNG") catch @panic("OOM");
    c_flags.append("-DSPNG_STATIC") catch @panic("OOM");
    c_flags.append("-DSPNG_SSE=3") catch @panic("OOM");
    c_flags.append("-DHAVE_JPEG") catch @panic("OOM");
    c_flags.append("-DHAVE_TIFF") catch @panic("OOM");
    c_flags.append("-DHAVE_WEBP") catch @panic("OOM");
    c_flags.append("-fno-sanitize=undefined") catch @panic("OOM");

    lib_mod.addCSourceFiles(.{
        .files = &.{
            "c_bindings/odiff_io.c",
            "src/rvv.c",
        },
        .flags = c_flags.items,
    });

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe_mod.addImport("odiff_lib", lib_mod);
    exe_mod.addImport("build_options", build_options_mod);
    lib_mod.addImport("build_options", build_options_mod);

    if (target.result.cpu.arch == .x86_64) {
        const os_tag = target.result.os.tag;
        const fmt: ?[]const u8 = switch (os_tag) {
            .linux => "elf64",
            .macos => "macho64",
            else => null,
        };

        if (fmt) |nasm_fmt| {
            const nasm = b.addSystemCommand(&.{ "nasm", "-f", nasm_fmt, "-o" });
            const asm_obj = nasm.addOutputFileArg("vxdiff.o");
            nasm.addFileArg(b.path("src/vxdiff.asm"));
            lib_mod.addObjectFile(asm_obj);
        }
    }

    const exe = b.addExecutable(.{
        .name = "odiff",
        .root_module = exe_mod,
    });

    return .{ lib_mod, exe };
}

pub fn linkDeps(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode, dynamic: bool, module: *std.Build.Module) void {
    const host_target = b.graph.host.result;
    const build_target = target.result;
    const is_cross_compiling = host_target.cpu.arch != build_target.cpu.arch or
        host_target.os.tag != build_target.os.tag;
    if (dynamic and !is_cross_compiling) {
        switch (build_target.os.tag) {
            .windows => {
                std.log.warn("Dynamic linking is not supported on Windows, falling back to static linking", .{});
                return linkDeps(b, target, optimize, false, module);
            },
            else => {
                module.linkSystemLibrary("spng", .{});
                module.linkSystemLibrary("jpeg", .{});
                module.linkSystemLibrary("tiff", .{});
            },
        }
    } else {
        Imgz.addToModule(b, module, .{
            .target = target,
            .optimize = optimize,
            .jpeg_turbo = .{ .simd = false },
            .spng = .{},
            .tiff = .{},
            .webp = .{},
        }) catch @panic("Failed to link required dependencies, please create an issue on the repo :)");
    }
}
