# CGE WebGL numeric transfer candidate

This is an isolated development candidate, not an adopted dependency pin or a
passing application feature. The accompanying `cge-webgl-bulk-transfer.patch`
applies to Castle Game Engine commit
`050f07edde6652d6657b4fe0d299822b9f502afa`. The application submodule remains
unchanged. Select a separate checkout explicitly when building the probe.

The patch replaces scalar-by-scalar bridge calls for single-precision matrices
and numeric lists with owned typed-array copies. Compile-time size checks cover
the contiguous record layout, and wide byte-count arithmetic rejects lengths
above the signed wasm32 JOB range before allocation. This change concerns the
matrix/list conversion helpers; existing buffer upload helpers are outside its
scope and are not claimed to gain new range validation.

The retained engine source SHA-256 is
`c4da0f1642a8ae3470f802a93ee647a362907d9fa18e82f0a209453e8984d081`.
The final application compilation in `build/logs/engine-bulk-build-03.log`
produced WASM SHA-256
`3994c8a515573e3329bd862b71f3a132687b6c2e815885e2ed192004e12cf8bc`.
Earlier served output used a different WASM file; its results cannot establish
verification of the final guard revision.

Use the [numeric transfer harness](../../tests/webgl-transfer/README.md) for
baseline and candidate builds. Candidate evidence must explicitly require the
signed-range regression. Application verification additionally needs shader,
populated-world rendering and editing/recovery journeys against the final
WASM and matching startup manifest/host. Desktop phone emulation does not
establish physical-phone responsiveness or background recovery.

On 2026-09-12 Astra assigned the existing transfer harness and isolated staging
wrapper to Sol: both have bounded interfaces and direct execution checks.
Cross-bridge range/layout analysis and application integration remain with
Astra. Luna supplies independent implementation and evidence review. All
existing feature holds remain in force until renewed against current inputs.

## Final guard verification, 2026-09-12

`build/engine-transfer-guard-final-browser-05` records a successful complete
build/serve/browser wrapper run: 9,493 legacy assertions and 13 signed-boundary
assertions, with no browser errors. Its metadata binds the tested source to the
probe WASM. The updated-source pinned baseline passes the same 9,493 assertions
with the candidate-only boundary cases explicitly skipped; see
`build/engine-transfer-baseline-final-browser-url-01` and
`build/logs/engine-transfer-baseline-final-01.log`.

The paired application comparison in `build/engine-final-comparison-01.json`
uses a newly saved seed-732, size-12 (192-metre) world, with nine resident chunks.
Baseline/candidate rates are 9.84/14.74 fps for desktop Orbit,
10.08/15.56 for phone-layout Orbit, 25.55/38.81 for phone-layout walking,
and 25.72/38.93 after graphics recovery. Draws per frame are identical, no
renderer errors occur, and the world survives recovery exactly. Desktop,
phone-layout walking and recovered screenshot pairs have zero differing pixels.
This larger fixture is separate from the archived size-8 measurements. Orbit
responsiveness remains insufficient; these development-machine results do not
establish physical-phone performance.

The final-guard application also passes all 42 terrain editing/recovery checks
in `build/logs/engine-final-landforms-01.log`. Its broader style journey passes
normal exterior/interior styles and phone layouts, then exposes an application
shader-compilation fallback defect. That defect and its subsequent Phanes-side
fix require separate style verification; this candidate report does not approve
the entire application or change either dependency pin.
