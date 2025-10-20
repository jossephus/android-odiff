const std = @import("std");
const ndk = @import("ndk.zig");
const getAndroidTriple = ndk.getAndroidTriple;
const getOutputDir = ndk.getOutputDir;
const createLibC = ndk.createLibC;
const ndk_path = ndk.DEFAULT_NDK_PATH;
const ndk_version = ndk.DEFAULT_NDK_VERSION;
const android_api_version = ndk.DEFAULT_ANDROID_API_VERSION;

// must be in sync with libjpeg_turbo_upstream dependency
const conf = .{
    .version = "3.1.2",
    .jpeg_lib_version = 80,
};

pub const Options = struct {
    arith_enc: bool = true,
    arith_dec: bool = true,
    simd: bool = false,
};

pub fn get(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    options: Options,
) !*std.Build.Step.Compile {
    const enable_arith_enc = options.arith_enc;
    const enable_arith_dec = options.arith_dec;
    const with_simd = options.simd and !target.result.cpu.arch.isRISCV();

    const libjpeg_turbo_version_number = computeVersionNumber(conf.version);
    const build_date = try computeBuildDate(b.allocator);

    const mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    const lib = b.addLibrary(.{
        .name = "jpeg-turbo",
        .root_module = mod,
        .linkage = .static,
    });

    lib.linkLibC();

    const android_triple = getAndroidTriple(lib.rootModuleTarget()) catch |err| @panic(@errorName(err));

    const libc_config = createLibC(b, android_triple, android_api_version, ndk_path, ndk_version);

    lib.setLibCFile(libc_config);

    if (b.lazyDependency("libjpeg_turbo_upstream", .{})) |j| {
        const jconfig = b.addConfigHeader(.{
            .style = .{ .cmake = j.path("src/jconfig.h.in") },
        }, .{
            .VERSION = conf.version,
            .LIBJPEG_TURBO_VERSION = conf.version,
            .LIBJPEG_TURBO_VERSION_NUMBER = libjpeg_turbo_version_number,
            .JPEG_LIB_VERSION = conf.jpeg_lib_version,
            .WITH_SIMD = with_simd,
            .C_ARITH_CODING_SUPPORTED = enable_arith_enc,
            .D_ARITH_CODING_SUPPORTED = enable_arith_dec,
            .RIGHT_SHIFT_IS_UNSIGNED = false,
        });

        const jconfigint = b.addConfigHeader(.{
            .style = .{ .cmake = j.path("src/jconfigint.h.in") },
        }, .{
            .BUILD = build_date,
            .HIDDEN = "__attribute__((visibility(\"hidden\")))",
            .INLINE = "__inline__ __attribute__((always_inline))",
            .THREAD_LOCAL = "__thread",
            .CMAKE_PROJECT_NAME = "libjpeg-turbo",
            .VERSION = conf.version,
            .SIZE_T = target.result.ptrBitWidth() / 8,
            .HAVE_BUILTIN_CTZL = true,
            .HAVE_INTRIN_H = target.result.os.tag == .windows,
            .C_ARITH_CODING_SUPPORTED = enable_arith_enc,
            .D_ARITH_CODING_SUPPORTED = enable_arith_dec,
            .WITH_SIMD = with_simd,
        });

        const jversion = b.addConfigHeader(.{
            .style = .{ .cmake = j.path("src/jversion.h.in") },
        }, .{ .COPYRIGHT_YEAR = "1991-2025" });

        mod.addConfigHeader(jconfig);
        mod.addConfigHeader(jconfigint);
        mod.addConfigHeader(jversion);
        mod.addIncludePath(j.path("src"));
        mod.addIncludePath(j.path("simd"));

        mod.addCSourceFiles(.{
            .files = &.{
                "src/jcapimin.c",
                "src/jcapistd.c",
                "src/wrapper/jcapistd-8.c",
                "src/wrapper/jcapistd-12.c",
                "src/wrapper/jcapistd-16.c",
                "src/jccoefct.c",
                "src/wrapper/jccoefct-8.c",
                "src/wrapper/jccoefct-12.c",
                "src/jccolor.c",
                "src/wrapper/jccolor-8.c",
                "src/wrapper/jccolor-12.c",
                "src/wrapper/jccolor-16.c",
                "src/jcdctmgr.c",
                "src/wrapper/jcdctmgr-8.c",
                "src/wrapper/jcdctmgr-12.c",
                "src/jcdiffct.c",
                "src/wrapper/jcdiffct-8.c",
                "src/wrapper/jcdiffct-12.c",
                "src/wrapper/jcdiffct-16.c",
                "src/jchuff.c",
                "src/jcicc.c",
                "src/jcinit.c",
                "src/jclhuff.c",
                "src/jclossls.c",
                "src/wrapper/jclossls-8.c",
                "src/wrapper/jclossls-12.c",
                "src/wrapper/jclossls-16.c",
                "src/jcmainct.c",
                "src/wrapper/jcmainct-8.c",
                "src/wrapper/jcmainct-12.c",
                "src/wrapper/jcmainct-16.c",
                "src/jcmarker.c",
                "src/jcmaster.c",
                "src/jcomapi.c",
                "src/jcparam.c",
                "src/jcphuff.c",
                "src/jcprepct.c",
                "src/wrapper/jcprepct-8.c",
                "src/wrapper/jcprepct-12.c",
                "src/wrapper/jcprepct-16.c",
                "src/jcsample.c",
                "src/wrapper/jcsample-8.c",
                "src/wrapper/jcsample-12.c",
                "src/wrapper/jcsample-16.c",
                "src/jctrans.c",
                "src/jdapimin.c",
                "src/jdapistd.c",
                "src/wrapper/jdapistd-8.c",
                "src/wrapper/jdapistd-12.c",
                "src/wrapper/jdapistd-16.c",
                "src/jdatadst.c",
                "src/jdatasrc.c",
                "src/jdcoefct.c",
                "src/wrapper/jdcoefct-8.c",
                "src/wrapper/jdcoefct-12.c",
                "src/jdcolor.c",
                "src/wrapper/jdcolor-8.c",
                "src/wrapper/jdcolor-12.c",
                "src/wrapper/jdcolor-16.c",
                "src/jddctmgr.c",
                "src/wrapper/jddctmgr-8.c",
                "src/wrapper/jddctmgr-12.c",
                "src/jddiffct.c",
                "src/wrapper/jddiffct-8.c",
                "src/wrapper/jddiffct-12.c",
                "src/wrapper/jddiffct-16.c",
                "src/jdhuff.c",
                "src/jdicc.c",
                "src/jdinput.c",
                "src/jdlhuff.c",
                "src/jdlossls.c",
                "src/wrapper/jdlossls-8.c",
                "src/wrapper/jdlossls-12.c",
                "src/wrapper/jdlossls-16.c",
                "src/jdmainct.c",
                "src/wrapper/jdmainct-8.c",
                "src/wrapper/jdmainct-12.c",
                "src/wrapper/jdmainct-16.c",
                "src/jdmarker.c",
                "src/jdmaster.c",
                "src/jdmerge.c",
                "src/wrapper/jdmerge-8.c",
                "src/wrapper/jdmerge-12.c",
                "src/jdphuff.c",
                "src/jdpostct.c",
                "src/wrapper/jdpostct-8.c",
                "src/wrapper/jdpostct-12.c",
                "src/wrapper/jdpostct-16.c",
                "src/jdsample.c",
                "src/wrapper/jdsample-8.c",
                "src/wrapper/jdsample-12.c",
                "src/wrapper/jdsample-16.c",
                "src/jdtrans.c",
                "src/jerror.c",
                "src/jfdctflt.c",
                "src/jfdctfst.c",
                "src/wrapper/jfdctfst-8.c",
                "src/wrapper/jfdctfst-12.c",
                "src/jfdctint.c",
                "src/wrapper/jfdctint-8.c",
                "src/wrapper/jfdctint-12.c",
                "src/jidctflt.c",
                "src/wrapper/jidctflt-8.c",
                "src/wrapper/jidctflt-12.c",
                "src/jidctfst.c",
                "src/wrapper/jidctfst-8.c",
                "src/wrapper/jidctfst-12.c",
                "src/jidctint.c",
                "src/wrapper/jidctint-8.c",
                "src/wrapper/jidctint-12.c",
                "src/jidctred.c",
                "src/wrapper/jidctred-8.c",
                "src/wrapper/jidctred-12.c",
                "src/jmemmgr.c",
                "src/jmemnobs.c",
                "src/jpeg_nbits.c",
                "src/jquant1.c",
                "src/wrapper/jquant1-8.c",
                "src/wrapper/jquant1-12.c",
                "src/jquant2.c",
                "src/wrapper/jquant2-8.c",
                "src/wrapper/jquant2-12.c",
                "src/jutils.c",
                "src/wrapper/jutils-8.c",
                "src/wrapper/jutils-12.c",
                "src/wrapper/jutils-16.c",
            },
            .flags = &.{"-std=c89"},
            .root = j.path("."),
        });

        if (enable_arith_enc or enable_arith_dec) {
            mod.addCSourceFiles(.{
                .files = &.{"src/jaricom.c"},
                .flags = &.{"-std=c89"},
                .root = j.path("."),
            });
        }

        if (enable_arith_enc) {
            mod.addCSourceFiles(.{
                .files = &.{"src/jcarith.c"},
                .flags = &.{"-std=c89"},
                .root = j.path("."),
            });
        }

        if (enable_arith_dec) {
            mod.addCSourceFiles(.{
                .files = &.{"src/jdarith.c"},
                .flags = &.{"-std=c89"},
                .root = j.path("."),
            });
        }

        if (with_simd) {}

        lib.installConfigHeader(jconfig);
        lib.installHeader(j.path("src/jerror.h"), "jerror.h");
        lib.installHeader(j.path("src/jmorecfg.h"), "jmorecfg.h");
        lib.installHeader(j.path("src/jpeglib.h"), "jpeglib.h");
    }

    return lib;
}

fn nasmCompile(
    b: *std.Build,
    j: *std.Build.Dependency,
    target: std.Build.ResolvedTarget,
    include_path: []const u8,
    asm_file: std.Build.LazyPath,
    pic: bool,
) std.Build.LazyPath {
    const ofmt = target.result.ofmt;
    const arch = target.result.cpu.arch;
    const abi = target.result.abi;
    const f, const D = switch (ofmt) {
        .elf => .{ if (abi == .gnux32) "elf32" else switch (arch) {
            .x86_64 => "elf64",
            .x86 => "elf32",
            else => unreachable,
        }, "ELF" },
        .macho => .{ switch (arch) {
            .x86_64 => "macho64",
            .x86 => "macho32",
            else => unreachable,
        }, "MACHO" },
        .coff => switch (arch) {
            .x86_64 => .{ "win64", "WIN64" },
            .x86 => .{ "win32", "WIN32" },
            else => unreachable,
        },
        else => @panic("Unsupported object format"),
    };

    const run_nasm = b.addSystemCommand(&.{
        "nasm",
        "-Isrc",
        b.fmt("-D{s}", .{D}),
        if (arch == .x86_64) "-D__x86_64__" else "",
        if (pic) "-DPIC" else "",
        "-Isimd/nasm",
        b.fmt("-I{s}", .{include_path}),
        "-f",
        f,
    });
    run_nasm.setCwd(j.path("."));

    run_nasm.addArg("-o");

    const asm_file_path = asm_file.getDisplayName();
    const obj_basename = std.fs.path.stem(asm_file_path);
    const obj_ext = ofmt.fileExt(arch);
    const obj_name = b.fmt("{s}{s}", .{ obj_basename, obj_ext });
    const obj_file = run_nasm.addOutputFileArg(obj_name);

    run_nasm.addFileArg(asm_file);
    return obj_file;
}

fn computeVersionNumber(version: []const u8) u32 {
    var result: u32 = 0;
    var parts = std.mem.splitScalar(u8, version, '.');
    var multiplier: u32 = 1000000;

    while (parts.next()) |part| {
        const num = std.fmt.parseInt(u32, part, 10) catch 0;
        result += num * multiplier;
        multiplier /= 100;
    }

    return result;
}

fn computeBuildDate(allocator: std.mem.Allocator) ![]u8 {
    const epoch_seconds = std.time.timestamp();

    const days_since_epoch = @divFloor(epoch_seconds, 86_400);
    const days_from_ce = days_since_epoch + 719_468;

    const era = if (days_from_ce >= 0)
        @divFloor(days_from_ce, 146_097)
    else
        @divFloor(days_from_ce - 146_096, 146_097);

    const day_of_era = days_from_ce - era * 146_097;

    const year_of_era = @divFloor(
        day_of_era - @divFloor(day_of_era, 1_460) + @divFloor(day_of_era, 36_524) - @divFloor(day_of_era, 146_096),
        365,
    );

    var year: i64 = year_of_era + era * 400;

    const day_of_year = day_of_era - (365 * year_of_era + @divFloor(year_of_era, 4) - @divFloor(year_of_era, 100));

    const month_prime = @divFloor(5 * day_of_year + 2, 153);

    const day = day_of_year - @divFloor(153 * month_prime + 2, 5) + 1;
    var month: i64 = month_prime + 3;

    if (month > 12) {
        month -= 12;
        year += 1;
    }

    return try std.fmt.allocPrint(
        allocator,
        "{d:0>4}{d:0>2}{d:0>2}",
        .{ year, month, day },
    );
}
