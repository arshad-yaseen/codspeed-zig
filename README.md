# codspeed-zig

`codspeed-zig` is a Zig wrapper around CodSpeed's low-level `instrument-hooks` runtime.
It exposes a small API to mark benchmark start/stop boundaries and report benchmark metadata to CodSpeed.

## Installation

Add the package to `build.zig.zon`:

```sh
zig fetch --save git+https://github.com/arshad-yaseen/codspeed-zig.git
```

Then wire the module in your `build.zig`:

```zig
const codspeed_dep = b.dependency("codspeed_zig", .{
    .target = target,
    .optimize = optimize,
});
exe.root_module.addImport("codspeed", codspeed_dep.module("codspeed"));
```

## Usage

```zig
const std = @import("std");
const CodSpeed = @import("codspeed").CodSpeed;

fn busyWork() void {
    var sum: u64 = 0;
    var i: u64 = 0;
    while (i < 1_000_000) : (i += 1) {
        sum +%= i;
    }
    _ = sum;
}

pub fn main() !void {
    var codspeed = try CodSpeed.init(std.heap.c_allocator); // or page_allocator
    defer codspeed.deinit();

    try codspeed.setIntegration("zig", "0.1.0");
    try codspeed.bench("example/busy_work", busyWork);
}
```

If you want full manual control instead of `bench`, call:

- `startBenchmark()`
- your benchmark function
- `stopBenchmark()`
- `setExecutedBenchmark(pid, uri)`

## References

- CodSpeed docs: https://docs.codspeed.io
- CodSpeed action: https://github.com/CodSpeedHQ/action
