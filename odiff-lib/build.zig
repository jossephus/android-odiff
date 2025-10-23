const std = @import("std");
const manifest = @import("build.zig.zon");

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

    const build_options = b.addOptions();
    build_options.addOption([]const u8, "version", manifest.version);

    for (build_targets) |target_query| {
        const target = b.resolveTargetQuery(target_query);
        const odiff = b.dependency("odiff", .{
            .target = target,
            .optimize = optimize,
        });

        const odiff_lib = odiff.artifact("odiff-lib");

        const mod = b.addModule("odiff-android-lib", .{
            .root_source_file = b.path("src/root.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            .imports = &.{
                .{ .name = "odiff-lib", .module = odiff_lib.root_module },
            },
        });

        const root_lib = b.addLibrary(.{
            .name = "odiff-lib",
            .root_module = mod,
            .linkage = .static,
        });

        const abi_output_dir = getOutputDir(target.result) catch |err| {
            std.log.err("Unsupported target architecture: {}", .{target.result.cpu.arch});
            return err;
        };

        const header_output_dir = try std.fs.path.join(b.allocator, &.{ abi_output_dir, "include" });

        const android_triple = try getAndroidTriple(target.result);
        const libc_config = createLibC(b, android_triple, android_api_version, ndk_path, ndk_version);

        odiff_lib.setLibCFile(libc_config);
        odiff_lib.linkLibC();
        b.installArtifact(odiff_lib);

        const c_test_mod = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        });
        c_test_mod.addCSourceFiles(.{
            .files = &.{"src/test-odiff.c"},
            .flags = &.{},
        });

        const c_test_exe = b.addExecutable(.{
            .name = "test_odiff",
            .root_module = c_test_mod,
        });
        c_test_exe.linkLibrary(root_lib);

        const install_artifact = b.addInstallArtifact(odiff_lib, .{
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

        b.getInstallStep().dependOn(&install_artifact.step);
    }
}
