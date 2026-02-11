# codspeed-zig

`codspeed-zig` is a Zig wrapper for CodSpeed's `instrument-hooks` runtime.
It lets you mark benchmark boundaries from Zig and send benchmark metadata to CodSpeed.

## Installation

Add the dependency:

```sh
zig fetch --save git+https://github.com/arshad-yaseen/codspeed-zig.git
```

In `build.zig`, import the module:

```zig
const codspeed_dep = b.dependency("codspeed_zig", .{
    .target = target,
    .optimize = optimize,
});
exe.root_module.addImport("codspeed", codspeed_dep.module("codspeed"));
```

## Benchmarking a Function

### 1. Write the function you want to measure

```zig
fn busyWork() void {
    var sum: u64 = 0;
    var i: u64 = 0;
    while (i < 1_000_000) : (i += 1) {
        sum +%= i;
    }
    _ = sum;
}
```

### 2. Run it through `CodSpeed.bench`

```zig
const std = @import("std");
const CodSpeed = @import("codspeed").CodSpeed;

pub fn main() !void {
    var codspeed = try CodSpeed.init(std.heap.c_allocator);
    defer codspeed.deinit();

    // Optional metadata to identify your integration in CodSpeed.
    try codspeed.setIntegration("zig", "0.1.0");

    try codspeed.bench("example/busy_work", busyWork);
}
```

`bench()` does this sequence for you:

1. `startBenchmark()`
2. run your function
3. `stopBenchmark()`
4. `setExecutedBenchmark(current_pid, benchmark_id)`

If needed, you can call these methods manually for custom control.

## Integration with CI (GitHub Actions)

CodSpeed measurements are generated in CI by wrapping your benchmark command with `CodSpeedHQ/action`.

### Recommended workflow (OIDC)

```yaml
name: CodSpeed Benchmarks

on:
  push:
    branches: ["main"]
  pull_request:
  workflow_dispatch:

permissions:
  contents: read
  id-token: write

jobs:
  benchmarks:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v5
      - uses: mlugg/setup-zig@v2
        with:
          version: 0.16.0-dev.2490+fce7878a9
      - name: Run benchmarks with CodSpeed
        uses: CodSpeedHQ/action@v4
        with:
          mode: simulation
          run: zig build test
```

`zig build test` is only an example command.  
It produces benchmark results only for code paths that call:

- `CodSpeed.bench(...)`, or
- the manual sequence `startBenchmark()` -> `stopBenchmark()` -> `setExecutedBenchmark(...)`.

So if your test suite has regular tests plus a few benchmark-marked tests, only those benchmark-marked tests are reported to CodSpeed.

If you prefer separation, create a dedicated benchmark entrypoint/step (for example `zig build bench`) and use that in `run:` instead.

### Token-based alternative

If you prefer static token auth, add:

```yaml
with:
  mode: simulation
  run: zig build test
  token: ${{ secrets.CODSPEED_TOKEN }}
```

### Important notes

- Use `mode: simulation` for current CodSpeed CPU simulation mode.
- Public repositories can use tokenless auth; private repositories need token or OIDC.
- Keep benchmark IDs stable over time so CodSpeed can compare performance across commits and pull requests.

## References

- CodSpeed docs: https://docs.codspeed.io
- CodSpeed GitHub Action docs: https://docs.codspeed.io/ci-cd/github-action
- CodSpeed CPU simulation mode: https://docs.codspeed.io/instruments/cpu-simulation
- CodSpeed action repository: https://github.com/CodSpeedHQ/action
- Zig build system: https://ziglang.org/learn/build-system/
