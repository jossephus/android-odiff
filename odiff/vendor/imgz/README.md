# imgz

Popular image libraries packaged for the Zig build system.
All dependencies fetched from upstream and built from source with Zig.
Supports cross-compilation to almost all platforms (create an issue if it doesn't build for any platforms).

## Requirements

- Zig: 0.15.0 or newer
- NASM: required on x86/x86_64 for libjpeg-turbo SIMD. If unavailable, disable SIMD via `.simd = false` (consumer) or `-Djpeg_turbo_simd=false` (when building this repo).

## Install

```sh
zig fetch --save git+https://github.com/shreyassanthu77/imgz.git
```

## In your build.zig

```zig
const std = @import("std");
const imgz = @import("imgz");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        ...
    });

    // Add imgz libraries to the executable's module
    const options = imgz.Options{
        .target = target,
        .optimize = optimize,
        .jpeg_turbo = .{},
        .spng = .{},
        .tiff = .{},
        .webp = .{},
    };
    try imgz.addToModule(b, exe.root_module, options);
}
```

## Usage in Code

Use the C APIs directly via `@cImport`. Headers from enabled libraries are provided by adding imgz to your module, so no extra include paths are typically required.

## Configuration

You can configure imgz either as a dependency (via the `addToModule` API) or when building this repository with `zig build` flags.

- As a dependency (recommended) — pass options to `imgz.addToModule(...)`:

```zig
const options = imgz.Options{
    .target = target,
    .optimize = optimize,
    .jpeg_turbo = .{
        .arith_enc = true,  // arithmetic encoding
        .arith_dec = true,  // arithmetic decoding
        .simd = true,       // SIMD extensions
    },
    .spng = .{},            // libspng (no options currently)
    .tiff = .{},            // libtiff (no options currently)
    .webp = .{
        .enable_encoding = true,
        .enable_mux = true, // currently no effect (mux/demux not exposed)
        .enable_threading = true,
        .enable_simd = true,
    },
    .libz = .bundled,       // zlib: bundled, system, custom, or disabled
    .libsharpyuv = .bundled, // libsharpyuv: bundled, system, custom, or disabled
    .liblerc = .disabled,   // liblerc for tiff: bundled, system, custom, or disabled
    .liblzma = .disabled,   // liblzma for tiff: bundled, system, custom, or disabled
    .libzstd = .disabled,   // libzstd for tiff: bundled, system, custom, or disabled
};
try imgz.addToModule(b, exe.root_module, options);
```

Set any library option to `null` to exclude it from the build:

```zig
const options = imgz.Options{
    .target = target,
    .optimize = optimize,
    .jpeg_turbo = null,  // exclude libjpeg-turbo
    .spng = .{},
    .tiff = .{},
    .webp = .{},
};
try imgz.addToModule(b, exe.root_module, options);
```

- When building this repo directly — available flags (defaults in parentheses):
  - `-Dspng` (true): enable libspng
  - `-Djpeg_turbo` (true): enable libjpeg-turbo
  - `-Djpeg_turbo_arith_enc` (true): enable arithmetic encoding
  - `-Djpeg_turbo_arith_dec` (true): enable arithmetic decoding
  - `-Djpeg_turbo_simd` (true): enable SIMD extensions
  - `-Dtiff` (true): enable libtiff
  - `-Dwebp` (true): enable libwebp
  - `-Dwebp_encoding` (true): enable encoding
  - `-Dwebp_mux` (true): enable mux support
  - `-Dwebp_threading` (true): enable threading
  - `-Dwebp_simd` (true): enable SIMD
  - `-Dlibz` (bundled): zlib version (bundled/system/custom/disabled)
  - `-Dlibsharpyuv` (bundled): libsharpyuv version (bundled/system/custom/disabled)
  - `-Dliblerc` (false): enable lerc support in libtiff
  - `-Dliblzma` (false): enable lzma support in libtiff
  - `-Dlibzstd` (false): enable zstd support in libtiff

  Note: For TIFF extras, set the corresponding flag to `true` to enable system library linking. Bundled versions are not provided for liblerc/liblzma/libzstd.
Examples:

```sh
zig build -Djpeg_turbo=false
zig build -Djpeg_turbo_simd=false   # if nasm is unavailable
zig build -Dliblzma=true            # enable lzma support in libtiff
zig build -Dwebp=false
zig build -Dwebp_simd=false
```

## Testing

Run the test suite to verify that all libraries are working correctly:

```sh
zig build test
```

The tests include basic encode/decode operations for each supported format using sample images in the `test-images/` directory.

## Cross-Compilation

This package supports cross-compilation to all platforms supported by Zig. The underlying C libraries are built from source for each target platform.

Notes:
- x86/x86_64 SIMD for libjpeg-turbo uses NASM; install NASM or disable SIMD.
- RISC-V has no libjpeg-turbo SIMD support (automatically disabled).
- libwebp SIMD can be disabled with `.enable_simd = false` or `-Dwebp_simd=false`.

## Upstream Versions

These are pinned in `build.zig.zon`:

- libspng: v0.7.4 — https://github.com/randy408/libspng
- libjpeg-turbo: 3.1.2 (JPEG_LIB_VERSION 80) — https://github.com/libjpeg-turbo/libjpeg-turbo
- libtiff: commit 57dd777… — https://gitlab.com/libtiff/libtiff
- libwebp: commit 23359a1… — https://github.com/webmproject/libwebp
- zlib (vendored for consumers): 1.3.1 — https://github.com/allyourcodebase/zlib

## Supported Libraries

- [libjpeg-turbo](https://libjpeg-turbo.org/)
- [libspng](https://libspng.org/)
- [libtiff](https://libtiff.gitlab.io/libtiff/)
- [libwebp](https://github.com/webmproject/libwebp)

(PRs are welcome for more libraries.)

## Troubleshooting

- `nasm: command not found` or assembler errors on x86/x86_64: install NASM or set `.simd = false` / `-Djpeg_turbo_simd=false`.
- `@cImport` cannot find headers: ensure `imgz.addToModule(...)` is called on the module that contains the `@cImport` before compiling.
- Missing system libs when enabling TIFF extras: when setting `.liblerc = .system`, `.liblzma = .system`, or `.libzstd = .system`, ensure the corresponding system library is installed and discoverable by the host toolchain.

## Contributing

Contributions are welcome! Please feel free to submit pull requests for:

- Additional image format libraries
- Bug fixes and improvements
- Documentation enhancements
- Test coverage improvements

When adding new libraries, please include:
- Build configuration in the appropriate `formats/*.zig` file
- Tests in `test.zig`
- Documentation updates in this README
