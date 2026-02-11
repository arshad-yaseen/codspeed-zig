const std = @import("std");

const c = @cImport({
    @cInclude("core.h");
});

/// Zig wrapper around CodSpeed `instrument-hooks`.
///
/// Create one instance per process, then mark benchmark boundaries with
/// `startBenchmark`/`stopBenchmark` and report benchmark metadata with
/// `setExecutedBenchmark`.
pub const CodSpeed = struct {
    handle: ?*c.InstrumentHooks,
    allocator: std.mem.Allocator,

    /// Initializes the CodSpeed hook runtime.
    ///
    /// Returns `error.InitFailed` when the underlying hooks fail to initialize.
    pub fn init(allocator: std.mem.Allocator) !CodSpeed {
        const handle = c.instrument_hooks_init();
        if (handle == null) return error.InitFailed;

        return .{
            .handle = handle,
            .allocator = allocator,
        };
    }

    /// Releases resources associated with this instance.
    ///
    /// Call exactly once for each successful `init`.
    pub fn deinit(self: *CodSpeed) void {
        if (self.handle) |h| {
            c.instrument_hooks_deinit(h);
        }
    }

    /// Returns whether benchmark instrumentation is currently active.
    ///
    /// This is usually `false` outside CodSpeed/Valgrind environments, where
    /// the hook implementation may behave as a no-op.
    pub fn isInstrumented(self: *const CodSpeed) bool {
        return c.instrument_hooks_is_instrumented(self.handle);
    }

    /// Marks the start of a benchmark sample.
    ///
    /// Pair every successful call with `stopBenchmark`.
    /// Returns `error.StartFailed` if the hook backend reports a failure.
    pub fn startBenchmark(self: *const CodSpeed) !void {
        const result = c.instrument_hooks_start_benchmark(self.handle);
        if (result != 0) return error.StartFailed;
    }

    /// Marks the end of a benchmark sample.
    ///
    /// Returns `error.StopFailed` if the hook backend reports a failure.
    pub fn stopBenchmark(self: *const CodSpeed) !void {
        const result = c.instrument_hooks_stop_benchmark(self.handle);
        if (result != 0) return error.StopFailed;
    }

    /// Reports the benchmark identifier executed by process `pid`.
    ///
    /// `uri` should be a stable benchmark identifier (for example
    /// `"suite/benchmark_name"`). Returns `error.SetBenchmarkFailed` if the
    /// hook backend reports a failure.
    pub fn setExecutedBenchmark(self: *const CodSpeed, pid: i32, uri: []const u8) !void {
        const c_uri = try self.allocator.dupeZ(u8, uri);
        defer self.allocator.free(c_uri);

        const result = c.instrument_hooks_set_executed_benchmark(self.handle, pid, c_uri.ptr);
        if (result != 0) return error.SetBenchmarkFailed;
    }

    /// Reports integration metadata to CodSpeed.
    ///
    /// Use this to identify the calling integration (for example `"zig"` and
    /// your package version). Returns `error.SetIntegrationFailed` if the hook
    /// backend reports a failure.
    pub fn setIntegration(self: *const CodSpeed, name: []const u8, version: []const u8) !void {
        const c_name = try self.allocator.dupeZ(u8, name);
        defer self.allocator.free(c_name);

        const c_version = try self.allocator.dupeZ(u8, version);
        defer self.allocator.free(c_version);

        const result = c.instrument_hooks_set_integration(self.handle, c_name.ptr, c_version.ptr);
        if (result != 0) return error.SetIntegrationFailed;
    }

    /// Convenience helper that executes `func` as a benchmark and reports it.
    ///
    /// `func` must be callable as `fn() void`.
    pub fn bench(self: *const CodSpeed, name: []const u8, comptime func: anytype) !void {
        try self.startBenchmark();
        defer self.stopBenchmark() catch {};

        func();

        const pid = std.os.linux.getpid();
        try self.setExecutedBenchmark(pid, name);
    }
};

test "init and deinit" {
    var codspeed = try CodSpeed.init(std.testing.allocator);
    defer codspeed.deinit();

    try std.testing.expect(codspeed.handle != null);
}

test "isInstrumented" {
    var codspeed = try CodSpeed.init(std.testing.allocator);
    defer codspeed.deinit();

    const instrumented = codspeed.isInstrumented();
    try std.testing.expectEqual(@TypeOf(instrumented), bool);
}

test "start and stop benchmark" {
    var codspeed = try CodSpeed.init(std.testing.allocator);
    defer codspeed.deinit();

    try codspeed.startBenchmark();
    try codspeed.stopBenchmark();
}

test "setExecutedBenchmark" {
    var codspeed = try CodSpeed.init(std.testing.allocator);
    defer codspeed.deinit();

    const pid: i32 = 1234;
    const uri = "test_benchmark";
    try codspeed.setExecutedBenchmark(pid, uri);
}

test "setIntegration" {
    var codspeed = try CodSpeed.init(std.testing.allocator);
    defer codspeed.deinit();

    const name = "zig-integration";
    const version = "1.0.0";
    try codspeed.setIntegration(name, version);
}

test "bench convenience function" {
    var codspeed = try CodSpeed.init(std.testing.allocator);
    defer codspeed.deinit();

    try codspeed.bench("test_bench", struct {
        fn func() void {
            _ = @as(u64, 1 + 2);
        }
    }.func);
}
