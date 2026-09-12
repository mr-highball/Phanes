# WFC terrain landforms

This work expands the requested composition hierarchy beneath land cover,
foliage, foundations, routes and structures. The terrain feature remains
**pending independent feature acceptance**. New worlds now start with a WFC
height field before the regional land-cover, building and foliage passes.
The Pascal world adapter provides local shaping, versioned persistence and
protected construction support. Browser controls and recovery are under review;
native correctness alone does not establish visual or phone acceptance.

## Player workflow and saved worlds

Choose **Shape the land**, draw with Box, Brush or Lasso, and apply Raise, Lower,
Imagine hills or Soften height edits. The same selection gestures operate in
Overhead, Orbit, Fly and First person. Six amount choices range from 0.25 to 8 m;
these are maximum allowed changes, not a promise every selected point moves by
that amount. The existing tools toggle leaves more space for drawing on phones.
Undo and Redo retain complete validated snapshots.

Pascal controls accept a completed touch or pen gesture on the same enabled,
visible button. Dragging, interruption, a second pointer or a changed editing
context cancels the activation. Consumed gesture identities and originating
timestamps prevent later compatibility clicks from replaying it, including
when opening a panel moves another control beneath the finger. Mouse and
keyboard clicks retain their native paths.

The world adapter uses an eight-metre shared-vertex grid, 250 mm level steps,
a saved range of −8 to +8 m, and at most 1 m cardinal rise over 8 m. Fresh
generation chooses absolute heights between 1 and 6 m. Land cover subsequently
forms shorelines and admitted building pads over that field. Those blends are
separate authored geometry, not extra WFC height choices.

World formats 1 and 2 retain the original analytic surface. A successful first
height edit saves format 4: an additive field over that exact original surface.
Format 3 stores absolute fields, including fresh worlds. Restore never generates
replacement elevations. Older absolute fields retain their admitted level step
and range; the amount selector adapts to that step.

Local edits pin every vertex contributing to an unselected cell, including holes
in nonrectangular masks. They also retain sea-facing boundary strips, existing
water/shore influence, regional buildings, complete plot landings and modular
foundation aprons. Rooms and nested furnishings remain exact composition nodes.
Plant clusters keep their existing identity and cannot lose dry support. A
one-cell-wide fine selection may contain no editable interior vertex; the tool
asks for a wider region rather than changing a neighboring surface.

Raise and Lower require a real change. Soften only moves a level toward its
previous neighborhood mean and cannot increase the field's squared cardinal
roughness. In an older analytic world it softens height edits, preserving the
original hills. A successful no-op retains the original world, seed, counters
and Undo/Redo history. Failed searches and incompatible protected regions retain
the current world. Search is bounded at 4096 backtracks.

## Elevation contract

`phanes.terrain.types` describes a versioned rectangular grid of shared
vertices. Columns and rows are vertex counts, not biome cells. Each vertex
stores an integer level; multiplying by the level step gives its elevation in
millimetres. Origin and spacing also use millimetres. The initial admitted
frame has 2–97 vertices per side, spacing 250–32000 mm, endpoints within
±4096 m, and 1–65 ordered levels. Level numbers lie between −1024 and 1024,
step sizes between 1 and 8000 mm, and resulting elevations within ±512 m.
These are bounded kernel limits, not promises of arbitrary world streaming.

One WFC cell corresponds to one height vertex. Values are equal-weight
elevation levels. Reciprocal cardinal adjacency limits the rise between
neighboring vertices. Caller intervals can constrain every vertex, including
exact heights. The result is decoded and independently checked against
geometry, adjacency, intent and preservation; the validator does not inspect
the graph or reuse its rule builder. The existing pinned WFC API supplies this
model without dependency changes.

A maximum cardinal rise bounds each coordinate slope. It does **not** by itself
certify a traversable total grade: simultaneous X and Z rise must be considered.
Roads, streams, lava and bridges require their own connected route, flow,
clearance and hazard constraints over the admitted terrain. They are not
implemented by an elevation interval.

## Local repair and ownership

A repair uses the baseline's exact frame and elevation contract. Its selection
is a rectangle of **cells**. Only vertices strictly inside that rectangle may
change. Boundary vertices and every outside vertex remain exact saved values;
additional protected vertices pin occupied supports or other preserved areas.
This ring keeps the actual outside triangles unchanged, including the edge of
the selected surface. Caller intervals that conflict with a preserved height
reject the edit rather than relaxing the pin.

Fresh generation requires the whole frame selection and solves boundary
vertices too. It does not invent a zero-height baseline. A one-cell-wide or
one-cell-deep repair has no interior vertices. Successful repairs that change
no height return a detached copy of the complete baseline, retain its seed and
solver counters, and explain that no height changed.

Generation stages a separate candidate and assigns output only after admission.
Failed requests, search failures and malformed inputs leave both ordinary and
aliased output arguments intact. This kernel has no world revision or worker
publication authority; the world adapter must provide those transactions.

## Contact surface

`phanes.terrain.surface` owns a validated, detached snapshot. Each cell consists
of two planes with an anti-diagonal between its +X and +Z corners. This
triangulation is part of version 1. The continuous height is piecewise planar;
the derivative can have creases. It is not bilinear interpolation.

Queries use metres and reject nonfinite or out-of-frame positions. Rectangle
bounds visit every touched cell and include clipped triangle vertices,
including diagonal intersections and interior grid extrema. Slope bounds
include both one-sided derivatives at triangle and grid creases. Only
derivative admission uses a small normalization tolerance; heights are not
snapped or extrapolated.
Height ranges include a 0.0000001 m outward allowance for bounded floating-point
arithmetic at the extreme admitted coordinate and slope limits.

The detailed CGE terrain uses the same diagonal on a one-metre grid, with
quarter-metre modular aprons and the existing finer groundwork profiles.
Standing/soil contact interpolates those rendered triangles rather than
evaluating nonlinear shoreline blends between their vertices. Raw field
sampling remains separate for saved heights and foundation datum admission.

Distant four-metre tiles retain every one-metre perimeter vertex and use a
shared-index center fan. This stitches chunk boundaries and transitions within
a chunk. Tiles touching the complete shoreline or regional-pad influence use
the same one-metre triangles as detailed terrain, including virtual water
outside the world. Existing plot/modular chunks retain their denser policy.
The fan follows each absolute field plane exactly. The legacy analytic
component has an independently derived 11.473 mm interpolation bound relative
to detailed contact before floating-point allowance; the declared distant
terrain policy allows at most 25 mm. Edge normals use bounded one-sided queries.

## Integration and remaining acceptance

`phanes.world.height` supplies absolute or additive field heights, ranges and
gradients to regional admission, groundworks and the landscape. The renderer,
walking contact and construction use that same provider. Chunk signatures include
the field contract, interpretation and relevant vertex levels. Terrain picking
clips rays to the saved frame before marching or bisection; edge normals use
bounded one-sided samples.

The initial independent integration rerun passed 323,047 native checks; retained
evidence is `build/critic/landforms-core-review-02.md` and
`build/critic/landforms-run-07.log`. It covers arbitrary masks, legacy/absolute
worlds, protected construction and nested contents, plant clusters, invalid
output witnesses, fresh generation, replay and restore. The builder's
`tests/phanes.tests.landforms.lpr` passes 4,664 native checks. Neither result is
a four-category feature pass.

Remaining acceptance includes complete desktop/phone shaping journeys,
cancellation/recovery and measured browser budgets. The independent
critic owns the final feature decision. No physical-phone performance claim is
made from development-machine native timings.

The critic's actual native CGE mesh probes initially exposed metre-scale
shoreline errors (`build/critic/landforms-mesh-run-01.log` through `run-03`).
The shared-contact and stitched-fan correction closes those witnesses in
`build/critic/landforms-mesh-run-07.log`: 1,966,582 assertions across eleven
admitted worlds, including size 48, virtual shoreline water, closed frame edges
and steep imported fields. Ordinary detailed and absolute distant contact differ
by at most 0.014071 mm; the tested legacy/additive distant cases remain below
8.6 mm. Every tested adjacent chunk/LOD pair shares 65 identical boundary
vertices and 64 identical boundary segments. Actual CGE triangle interpolation
checks contact independently of float ray precision. The retained modular-apron
regression also passes. See `build/critic/landforms-mesh-review-02.md` for bounds,
original failure witnesses and limits. These numerical results do not establish
final visual acceptance.

The builder's full browser journey is retained in `build/landforms-browser-20`
and `build/logs/landforms-browser-20.log`: 40 top-level assertions, including
eight saved-context controls. Real touch input covers Box and Brush/Lasso in
all four cameras, local edits, history, legacy migration, unchanged Soften and
forced graphics recovery. Recovery keeps world, history, fine mask, amount and
the open terrain panel; the selected drawing tool currently returns to Tap.
Orbit is framed before its on-land gesture; the earlier off-land stroke and its
useful refusal remain in run18. Default screenshot capture follows the touch
journey because earlier capture interfered with emulated input; its separate
diagnosis and original failures remain under `build/critic/`.

The recovered-phone and desktop captures have their actual 780×1688 and
1280×900 dimensions. Three-second development-GPU samples contain 180/179
animation-frame callback intervals, 16.667/16.665 ms means, 17.2/17.1 ms p95
and no recorded browser errors. These are browser callback timings, not a
measurement of CGE frame rate. They cover a cleared four-region legacy fixture, not populated
large-world or physical-phone performance. The complete release build with
tests passes in `build/logs/landforms-web-build-06.log` without warnings.
Independent input edge cases, populated-world appearance and cancellation
acceptance remain part of the pending full-scope critic review.

The first independent populated desktop journey exposed a responsiveness
blocker. At 1280×900, a fresh size-eight, seed-731 world produced nine actual
CGE renders over 3.076 seconds; a settled 10.184-second repeat produced thirty
renders (about 2.95 fps). The page was visible, uncovered and using the GTX 1080
through D3D11, with no recorded browser errors. The retained evidence is
`build/critic/landforms-review-browser-01/populated-render-metrics.json` and
`results-4.json`. Layer/composition preservation and undo/redo passed in that
journey, but neither those results nor the cleared-world callback timings
establish a responsive populated-world experience. Profiling and correction
are required before the terrain feature can pass.

The independent input follow-up closes the multi-touch selection and covered
Cancel-button witnesses: 25 assertions in
`build/critic/terrain-landforms-input-review-02.md`. It exercises both touch
orders across Tools and the canvas, a later fresh brush stroke, and first-touch
cancellation in six phone layouts. Cancellation retains the exact world,
history and selection. These checks do not substitute for populated rendering
performance or physical-phone feedback.

Profiling identified per-shape WebAssembly/WebGL submissions and cabin trim as
major costs. The static foliage and cabin caches preserve mesh geometry and
surface grain while reducing submissions. `tools/test-batching.ps1` builds its
native dependencies from the pinned engine configuration and checks actual CGE
ray intersections, mirrored/scaled placements, material sharing and fallback.
The current builder run passes 54,239 assertions, with a maximum measured
foliage/cabin ray difference of 0.001907 mm. Its standalone build and output are
`build/logs/batching-tests-build.log` and `batching-tests.log`.

The first combined-cache browser run (`build/batch-browser-03`) renders the
same populated size-eight fixture at 14.46 fps in desktop Orbit, 15.26 fps in
phone-layout Orbit and 26.10 fps in phone-layout first person. Desktop drawing
falls from 1,044 submissions per frame with the initial foliage-only cache to
306 after cabin consolidation. These are actual CGE frame counters on the same
development GPU, with no recorded browser errors. They demonstrate improvement
but leave the populated responsiveness requirement open. A later material-sharing
pass and the complete final player journey still require measured review.

Rendered comparison then exposed missing cast shadows in the early caches.
Some imported models close across several material parts; mixing those parts
with unrelated open foliage made CGE reject their shadow volumes. Closed and
open shapes also need distinct material groups. The retained failure is
`build/critic/terrain-batching-shadow-review-02.md`; its crystal and pine
witnesses lose 364 and 204 shadow-eligible triangles respectively before the
correction. Complete source closure now owns a separate batch, with unchanged
source-shape grouping and a conservative transform fallback. The native suite
checks source-versus-batch shadow eligibility for every admitted foliage asset.

`build/batch-browser-05` visibly restores shrub and canopy shadows, including
ones absent from run03. Its actual rates are 14.96 fps desktop Orbit, 15.07 fps
phone-layout Orbit and 25.23 fps phone-layout first person. Runs03/04 are retained
diagnostic measurements, not evidence of a quality-preserving performance pass.
The full builder editing/recovery journey passes again in
`build/landforms-browser-21` with actual CGE frame/draw counters, but uses its
cleared small-world fixture and does not close this populated-world hold.

Color packing retains the source physical RGB at every foliage vertex and
the untinted cabin RGB beneath a shared world tint. The independent native
color review passes 60,494 foliage checks and 22,004 cabin/tint checks
(`build/critic/terrain-batching-color-review-04.md`). Browser run07 retains
the corrected shadows and materials, with 18.49 fps desktop Orbit, 20.76 fps
phone-layout Orbit and 33.25 fps phone-layout first person; desktop submissions
fall to 208 per frame. These measurements use the development GPU, not a
physical phone. Populated Orbit responsiveness remains a blocker. A subsequent
static shadow cache is being evaluated separately and is not included in those
results.

The subsequent foliage shadow cache reuses GPU silhouettes and separate caps
while retaining CGE's per-shape culling, camera-dependent stencil setup and
opaque-cap depth rule. It is restricted to static opaque directional-light
scenes; unsupported modes fall back. Vertex buffers share a 16 MiB admission
limit, and temporary vertex/facing allocation is independently bounded before
allocation. CPU geometry is freed after upload. Scene changes, light/transform
changes and GL context closure invalidate the cache.

Release build16 and `build/batch-browser-10` measure 24.41 fps desktop Orbit,
25.18 fps phone-layout Orbit, 44.47 fps phone-layout first person and 46.28 fps
after forced graphics recovery, with no recorded renderer errors. The populated
saved world survives recovery exactly and the captured shadows remain visible.
These remain development-GPU measurements. The reported host camera height is
reconciled to the actual walking surface after recovery; the rendered viewpoint
appears unchanged, so host camera JSON alone is not a camera-pixel oracle.

The critic's retained shadow geometry probe passes 138,394 checks across 1,120
shape/transform/light cases. It uses independent edge cancellation for synthetic
tetrahedra and the pinned engine's welded adjacency contract for actual assets.
The builder rerun against the latest cache also passes
(`build/logs/shadowcache-builder-run-01.log`). The full editing/recovery journey
passes 42 assertions in `build/logs/landforms-browser-22.log`. The critic stopped
on a usage limit before completing the new cache review; neither these checks
nor its earlier bounded color/shadow reports constitute a passing terrain
feature review. Populated Orbit speed, final independent review and physical
phone feedback remain open.

## Reproducible kernel checks

Run `./tools/test-terrain.ps1` with `FPC_NATIVE` configured. A web build with
`-WithTests` compiles the same Pascal driver; run
`node tools/test-terrain.cjs` with the repository's Playwright environment.
Both paths are included in CI.
`./tools/test-terrain-wasm.ps1` additionally compiles the same driver for FPC
WASM and executes it with Node's WASI host; set `FPC_WASM` when the compiler is
not on `PATH`. This numerical test host is separate from the browser game.

The driver compares every binary-domain assignment on a four-vertex square
against an exhaustive feasibility oracle, exercises positive-only fresh
boundaries, malformed requests, seed replay, protected repair, aliased
transactions, unchanged strips, saddle/grid extrema, immutable snapshots and
bounds across creases. Independent critic tests supplement these fixtures.

`tests/phanes.tests.terrain.bench.lpr` measures progressively larger admitted
height graphs. Timings describe that solver workload on the tested machine,
not an end-to-end game frame rate or a guarantee for every request.
