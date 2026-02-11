const std = @import("std");

const c = @cImport({
    @cInclude("core.h");
});

pub const CodSpeed = struct {
    handle: ?*c.InstrumentHooks,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !CodSpeed {
        const handle = c.instrument_hooks_init();
        if (handle == null) return error.InitFailed;

        return .{
            .handle = handle,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *CodSpeed) void {
        if (self.handle) |h| {
            c.instrument_hooks_deinit(h);
        }
    }

    pub fn isInstrumented(self: *const CodSpeed) bool {
        return c.instrument_hooks_is_instrumented(self.handle);
    }

    pub fn startBenchmark(self: *const CodSpeed) !void {
        const result = c.instrument_hooks_start_benchmark(self.handle);
        if (result != 0) return error.StartFailed;
    }

    pub fn stopBenchmark(self: *const CodSpeed) !void {
        const result = c.instrument_hooks_stop_benchmark(self.handle);
        if (result != 0) return error.StopFailed;
    }

    pub fn setExecutedBenchmark(self: *const CodSpeed, pid: i32, uri: []const u8) !void {
        const c_uri = try self.allocator.dupeZ(u8, uri);
        defer self.allocator.free(c_uri);

        const result = c.instrument_hooks_set_executed_benchmark(self.handle, pid, c_uri.ptr);
        if (result != 0) return error.SetBenchmarkFailed;
    }

    pub fn setIntegration(self: *const CodSpeed, name: []const u8, version: []const u8) !void {
        const c_name = try self.allocator.dupeZ(u8, name);
        defer self.allocator.free(c_name);

        const c_version = try self.allocator.dupeZ(u8, version);
        defer self.allocator.free(c_version);

        const result = c.instrument_hooks_set_integration(self.handle, c_name.ptr, c_version.ptr);
        if (result != 0) return error.SetIntegrationFailed;
    }

    /// Convenience function to run a benchmark
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
