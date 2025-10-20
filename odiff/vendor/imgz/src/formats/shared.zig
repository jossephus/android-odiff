const std = @import("std");

pub const RequiredLibrary = enum {
    /// Use the system provided library
    system,
    /// Use imgz's bundled version of the library
    bundled,
    /// A custom library will be linked manually
    custom,
    /// Don't link to the library
    disabled,
};

pub const LazyFileEditor = struct {
    step: std.Build.Step,
    wf: *std.Build.Step.WriteFile,
    source_file: std.Build.LazyPath,
    basename: []const u8,
    result: std.Build.LazyPath,
    editor_fn: *const fn (source_contents: []const u8, out_writer: *std.Io.Writer) anyerror!void,

    pub fn create(
        b: *std.Build,
        path: std.Build.LazyPath,
        basename: []const u8,
        editor_fn: *const fn (source_contents: []const u8, out_writer: *std.Io.Writer) anyerror!void,
    ) *LazyFileEditor {
        const self = b.allocator.create(LazyFileEditor) catch @panic("OOM");
        const wf = b.addWriteFiles();
        const dest_file = wf.getDirectory().path(b, basename);
        self.* = .{
            .step = std.Build.Step.init(.{
                .id = .custom,
                .name = "Lazy File Editor",
                .owner = b,
                .makeFn = make,
            }),
            .wf = wf,
            .basename = b.dupe(basename),
            .source_file = path,
            .result = dest_file,
            .editor_fn = editor_fn,
        };
        wf.step.dependOn(&self.step);
        return self;
    }

    fn make(step: *std.Build.Step, _: std.Build.Step.MakeOptions) !void {
        const self: *@This() = @fieldParentPtr("step", step);
        const b = step.owner;

        const source_file_path = try self.source_file.getPath3(b, step).toString(b.allocator);
        defer b.allocator.free(source_file_path);

        const source_file_contents = try std.fs.cwd().readFileAlloc(b.allocator, source_file_path, std.math.maxInt(usize));
        defer b.allocator.free(source_file_contents);

        var dest_writer = std.Io.Writer.Allocating.init(b.allocator);
        defer dest_writer.deinit();

        try self.editor_fn(source_file_contents, &dest_writer.writer);
        try dest_writer.writer.flush();

        const dest_file_contents = dest_writer.written();
        _ = self.wf.add(self.basename, dest_file_contents);
    }
};
