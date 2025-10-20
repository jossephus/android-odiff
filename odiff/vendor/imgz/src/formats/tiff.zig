const std = @import("std");
const RequiredLibrary = @import("shared.zig").RequiredLibrary;

const ndk = @import("ndk.zig");
const getAndroidTriple = ndk.getAndroidTriple;
const getOutputDir = ndk.getOutputDir;
const createLibC = ndk.createLibC;
const ndk_path = ndk.DEFAULT_NDK_PATH;
const ndk_version = ndk.DEFAULT_NDK_VERSION;
const android_api_version = ndk.DEFAULT_ANDROID_API_VERSION;

pub const Options = struct {
    has_glut_glut_h: bool = false,
    has_gl_glut_h: bool = false,
    has_gl_glu_h: bool = false,
    has_gl_gl_h: bool = false,
    has_opengl_glu_h: bool = false,
    has_opengl_gl_h: bool = false,
};

pub const Deps = struct {
    libz: RequiredLibrary = .disabled,
    libjpeg_turbo: RequiredLibrary = .disabled,
    libwebp: RequiredLibrary = .disabled,
    liblzma: RequiredLibrary = .disabled,
    libzstd: RequiredLibrary = .bundled,
    liblerc: RequiredLibrary = .disabled,
};

pub fn get(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    options: Options,
    deps: Deps,
) !*std.Build.Step.Compile {
    const has_glut_glut_h = options.has_glut_glut_h;
    const has_gl_glut_h = options.has_gl_glut_h;
    const has_gl_glu_h = options.has_gl_glu_h;
    const has_gl_gl_h = options.has_gl_gl_h;
    const has_opengl_glu_h = options.has_opengl_glu_h;
    const has_opengl_gl_h = options.has_opengl_gl_h;

    const mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    const lib = b.addLibrary(.{
        .name = "tiff",
        .root_module = mod,
        .linkage = .static,
    });

    lib.linkLibC();

    const android_triple = getAndroidTriple(lib.rootModuleTarget()) catch |err| @panic(@errorName(err));

    const libc_config = createLibC(b, android_triple, android_api_version, ndk_path, ndk_version);

    lib.setLibCFile(libc_config);

    if (b.lazyDependency("libtiff_upstream", .{})) |tiff_upstream| {
        const bit_width = target.result.ptrBitWidth() / 8;
        const tif_config = b.addConfigHeader(.{
            .style = .{ .cmake = tiff_upstream.path("libtiff/tif_config.h.cmake.in") },
            .include_path = "tif_config.h",
        }, .{
            .CCITT_SUPPORT = true,
            .CHECK_JPEG_YCBCR_SUBSAMPLING = true,
            .CHUNKY_STRIP_READ_SUPPORT = true,
            .CXX_SUPPORT = false,
            .DEFER_STRILE_LOAD = true,
            .HAVE_ASSERT_H = true,
            .HAVE_DECL_OPTARG = true,
            .HAVE_FCNTL_H = true,
            .HAVE_FSEEKO = true,
            .HAVE_GETOPT = true,
            .HAVE_GLUT_GLUT_H = has_glut_glut_h,
            .HAVE_GL_GLUT_H = has_gl_glut_h,
            .HAVE_GL_GLU_H = has_gl_glu_h,
            .HAVE_GL_GL_H = has_gl_gl_h,
            .HAVE_IO_H = target.result.os.tag == .windows,
            .HAVE_JBG_NEWLEN = false,
            .HAVE_MMAP = target.result.os.tag != .windows,
            .HAVE_OPENGL_GLU_H = has_opengl_glu_h,
            .HAVE_OPENGL_GL_H = has_opengl_gl_h,
            .HAVE_SETMODE = target.result.os.tag == .windows,
            .HAVE_STRINGS_H = true,
            .HAVE_SYS_TYPES_H = true,
            .HAVE_UNISTD_H = target.result.os.tag != .windows,
            .JPEG_DUAL_MODE_8_12 = deps.libjpeg_turbo != .disabled,
            .HAVE_JPEGTURBO_DUAL_MODE_8_12 = false,
            .LERC_SUPPORT = deps.liblerc != .disabled,
            .LERC_STATIC = deps.liblerc != .disabled,
            .LZMA_SUPPORT = deps.liblzma != .disabled,
            .WEBP_SUPPORT = deps.libwebp != .disabled,
            .ZSTD_SUPPORT = deps.libzstd != .disabled,
            .USE_WIN32_FILEIO = target.result.os.tag == .windows,
            .SIZEOF_SIZE_T = bit_width,
            .STRIP_SIZE_DEFAULT = 8192,
            .TIFF_MAX_DIR_COUNT = 65535,
            .LIBJPEG_12_PATH = "jpeglib.h",
            .PACKAGE = "libtiff",
            .PACKAGE_NAME = "libtiff",
            .PACKAGE_TARNAME = "libtiff",
            .PACKAGE_URL = "https://libtiff.gitlab.io/libtiff/",
            .PACKAGE_BUGREPORT = "https://gitlab.com/libtiff/libtiff/-/issues",
            .VAR = "lol",
        });

        const tiffconf = b.addConfigHeader(.{
            .style = .{ .cmake = tiff_upstream.path("libtiff/tiffconf.h.cmake.in") },
            .include_path = "tiffconf.h",
        }, .{
            .TIFF_INT16_T = "int16_t",
            .TIFF_INT32_T = "int32_t",
            .TIFF_INT64_T = "int64_t",
            .TIFF_INT8_T = "int8_t",
            .TIFF_UINT16_T = "uint16_t",
            .TIFF_UINT32_T = "uint32_t",
            .TIFF_UINT64_T = "uint64_t",
            .TIFF_UINT8_T = "uint8_t",
            .TIFF_SSIZE_T = if (bit_width == 4)
                "int32_t"
            else if (bit_width == 8)
                "int64_t"
            else
                return error.UnsupportedBitWidth,
            .HAVE_IEEEFP = true,
            .HOST_BIG_ENDIAN = target.result.cpu.arch.endian(),
            .CCITT_SUPPORT = true,
            .JPEG_SUPPORT = deps.libjpeg_turbo != .disabled,
            .JBIG_SUPPORT = false,
            .LERC_SUPPORT = deps.liblerc != .disabled,
            .LOGLUV_SUPPORT = true,
            .LZW_SUPPORT = true,
            .NEXT_SUPPORT = false,
            .OJPEG_SUPPORT = false,
            .PACKBITS_SUPPORT = true,
            .PIXARLOG_SUPPORT = true,
            .THUNDER_SUPPORT = false,
            .ZIP_SUPPORT = true,
            .LIBDEFLATE_SUPPORT = false,
            .STRIPCHOP_DEFAULT = .TIFF_STRIPCHOP,
            .SUBIFD_SUPPORT = true,
            .DEFAULT_EXTRASAMPLE_AS_ALPHA = true,
            .CHECK_JPEG_YCBCR_SUBSAMPLING = true,
            .MDI_SUPPORT = false,

            .VAR = "lol",
        });

        const tiffvers = blk: {
            const version_file = tiff_upstream.path("VERSION").getPath(b);
            const version = try std.fs.cwd().readFileAlloc(b.allocator, version_file, 1024);
            const version_trimmed = std.mem.trim(u8, version, " \n");
            var version_split = std.mem.splitScalar(u8, version_trimmed, '.');
            const major_version = try std.fmt.parseInt(u16, version_split.next() orelse return error.InvalidVersion, 10);
            const minor_version = try std.fmt.parseInt(u16, version_split.next() orelse return error.InvalidVersion, 10);
            const micro_version = try std.fmt.parseInt(u16, version_split.next() orelse return error.InvalidVersion, 10);

            const release_date_file = tiff_upstream.path("RELEASE-DATE").getPath(b);
            const release_date = try std.fs.cwd().readFileAlloc(b.allocator, release_date_file, 1024);

            const tiffvers = b.addConfigHeader(.{
                .style = .{ .cmake = tiff_upstream.path("libtiff/tiffvers.h.cmake.in") },
                .include_path = "tiffvers.h",
            }, .{
                .LIBTIFF_VERSION = version_trimmed,
                .LIBTIFF_RELEASE_DATE = release_date,
                .LIBTIFF_MAJOR_VERSION = major_version,
                .LIBTIFF_MINOR_VERSION = minor_version,
                .LIBTIFF_MICRO_VERSION = micro_version,

                .VAR = "lol",
            });

            break :blk tiffvers;
        };

        mod.addConfigHeader(tif_config);
        mod.addConfigHeader(tiffconf);
        mod.addConfigHeader(tiffvers);
        mod.addIncludePath(tiff_upstream.path("libtiff"));

        mod.addCSourceFiles(.{
            .root = tiff_upstream.path("."),
            .files = &.{
                "libtiff/tif_aux.c",
                "libtiff/tif_close.c",
                "libtiff/tif_codec.c",
                "libtiff/tif_color.c",
                "libtiff/tif_compress.c",
                "libtiff/tif_dir.c",
                "libtiff/tif_dirinfo.c",
                "libtiff/tif_dirread.c",
                "libtiff/tif_dirwrite.c",
                "libtiff/tif_dumpmode.c",
                "libtiff/tif_error.c",
                "libtiff/tif_extension.c",
                "libtiff/tif_fax3.c",
                "libtiff/tif_fax3sm.c",
                "libtiff/tif_flush.c",
                "libtiff/tif_getimage.c",
                "libtiff/tif_hash_set.c",
                "libtiff/tif_jbig.c",
                "libtiff/tif_jpeg.c",
                "libtiff/tif_jpeg_12.c",
                "libtiff/tif_lerc.c",
                "libtiff/tif_luv.c",
                "libtiff/tif_lzma.c",
                "libtiff/tif_lzw.c",
                "libtiff/tif_next.c",
                "libtiff/tif_ojpeg.c",
                "libtiff/tif_open.c",
                "libtiff/tif_packbits.c",
                "libtiff/tif_pixarlog.c",
                "libtiff/tif_predict.c",
                "libtiff/tif_print.c",
                "libtiff/tif_read.c",
                "libtiff/tif_strip.c",
                "libtiff/tif_swab.c",
                "libtiff/tif_thunder.c",
                "libtiff/tif_tile.c",
                "libtiff/tif_version.c",
                "libtiff/tif_warning.c",
                "libtiff/tif_webp.c",
                "libtiff/tif_write.c",
                "libtiff/tif_zip.c",
                "libtiff/tif_zstd.c",
                if (target.result.os.tag == .windows)
                    "libtiff/tif_win32.c"
                else
                    "libtiff/tif_unix.c",
            },
            .flags = &.{
                "-std=c99",
                "-Wall",
                "-Wextra",
                "-Werror",
            },
        });

        switch (deps.libz) {
            .system => mod.linkSystemLibrary("z", .{}),
            .bundled => if (b.lazyDependency("zlib", .{
                .target = target,
                .optimize = optimize,
            })) |zlib_dep| {
                mod.linkLibrary(zlib_dep.artifact("z"));
            },
            .custom => {}, // user is responsible for providing the library
            .disabled => {},
        }

        switch (deps.liblzma) {
            .system => mod.linkSystemLibrary("lzma", .{}),
            .bundled => {
                std.log.err("imgz doesn't support bundled liblzma", .{});
                return error.UnsupportedLiblzma;
            },
            .custom => {}, // user is responsible for providing the library
            .disabled => {},
        }
        switch (deps.liblerc) {
            .system => mod.linkSystemLibrary("Lerc", .{}),
            .bundled => {
                std.log.err("imgz doesn't support bundled liblerc", .{});
                return error.UnsupportedLiblerc;
            },
            .custom => {}, // user is responsible for providing the library
            .disabled => {},
        }
        switch (deps.libzstd) {
            .system => mod.linkSystemLibrary("zstd", .{}),
            .bundled => if (b.lazyDependency("zstd", .{
                .target = target,
                .optimize = optimize,
            })) |zstd_dep| {
                mod.linkLibrary(zstd_dep.artifact("zstd"));
            },
            .custom => {}, // user is responsible for providing the library
            .disabled => {},
        }

        lib.installHeader(tiff_upstream.path("libtiff/tiff.h"), "tiff.h");
        lib.installHeader(tiff_upstream.path("libtiff/tiffio.h"), "tiffio.h");
        lib.installConfigHeader(tiffvers);
        lib.installConfigHeader(tif_config);
        lib.installConfigHeader(tiffconf);
    }

    return lib;
}
