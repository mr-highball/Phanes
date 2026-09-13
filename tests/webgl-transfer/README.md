# WebGL numeric transfer regression

This small Castle web application exercises the actual FPC WASM/JOB numeric
conversion path. It does not depend on the Phanes world or its assets. The same
fixtures run against the pinned engine and a separate candidate checkout.

It checks all matrix and numeric-list overloads, column-major order, exact
integer values, float sign and precision, empty lists, unused list capacity,
ownership after mutation/free, and retained results after actual WASM memory
growth. Candidate runs also verify 64-bit byte-count arithmetic immediately
below, at and above the signed 2 GiB JOB boundary. Synthetic logical list counts
reach the rejection paths without allocating the enormous arrays. A short
conversion timing is diagnostic only; it has no speed threshold.

Build and run a candidate from the repository root with the usual FPC WASM,
pas2js and native FPC toolchains on `PATH`. Pass the separate engine checkout;
the wrapper sets `CASTLE_ENGINE_PATH` only for the build and leaves vendor files
and dependency pins untouched. It compiles the probe, serves it with the pinned
WFC Pascal server, launches the Pascal browser driver, stops the server and
records source and WASM hashes with the result.

```powershell
./tools/test-webgl-transfer.ps1 `
  -EnginePath ../castle-engine-candidate `
  -BuildDirectory build/webgl-transfer-candidate `
  -EvidenceDirectory build/webgl-transfer-candidate-browser `
  -Browser 'C:/path/to/chromium' `
  -WebToolchainDirectory build/toolchain `
  -RequireSignedRangeGuard
```

`-WebToolchainDirectory` is optional when the configured FPC WASM and pas2js
executables are already first on `PATH`. It temporarily prepends an isolated
toolchain directory for the Castle build and restores `PATH` afterward.

The `-RequireSignedRangeGuard` switch defines the candidate-only boundary
fixture at compile time and requires its 13 assertions to pass. A pinned engine
without the guard must explicitly omit that switch. Existing callers may still
serve an already-built probe and use the URL mode:

```powershell
./tools/test-webgl-transfer.ps1 `
  -TestUrl http://127.0.0.1:4294/probe.html `
  -EvidenceDirectory build/webgl-transfer-pinned-browser
```

`result.json` records the 9,493 legacy assertions, candidate boundary assertions,
conversion timing and browser errors. `verification.json` records the exact build
arguments and SHA-256 hashes. Failures return a nonzero process status; an
initialization failure retains diagnostics. Run browser measurements serially.
A phone-sized desktop browser is not a physical-phone performance measurement.
Rendering, shader switching and recovery still require the separate application
journeys.
