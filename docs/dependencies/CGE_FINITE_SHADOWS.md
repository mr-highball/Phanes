# Finite directional shadows

The development engine pin is `e52f3eeb40ad5a1e3dad1380cf6ec0902ec68379`,
published on the owned Castle Game Engine fork's `hello-phanes-shadow-projection`
branch. It corrects directional shadow projection and near-plane admission.
The complete delta from `25f2d98122997f8f039f759f9ffb76207b4f3cfe` is preserved
in `cge-finite-shadows.patch`.

Luna's bounded source review found no semantic blocker to development adoption;
the unchanged report is `reviews/finite-shadow-adoption-advisory-01.md`.
The full feature and release gates remain held. A fresh release build from the
pinned vendor passes: 1,145,649 lines, 23 warnings and one note. Its browser
startup, Orbit, overhead and restored-Orbit captures pass without captured
renderer or shader errors. All 54,000 sampled water pixels are lit; the measured
345,530-pixel overhead world region matches the reviewed candidate exactly.
The full screenshot changes where the repaired preview now loads UI artwork.
All 920 uncompressed data archive entries match the prior candidate.
`build/shadow-engine-adoption-01/provenance.json` binds commit reachability and
the fresh build; `build/shadow-adopted-smoke-01/provenance.json` binds packaging
and browser verification. Earlier candidate evidence below identifies its own
exact tested source and binaries.

The engine exposes an opt-in `DirectionalShadowDistance` on the viewport and
passes it through the shadow renderer to ordinary scene geometry. Zero retains
the existing infinite path. Positive directional distances produce finite side
quads and reverse-wound end caps. End caps use normal depth testing separately
from the existing opaque source-cap depth rule. Positional lights retain their
existing geometry and near-plane classifier.

The directional near-prism classifier uses Double edge/light cross products and
edge-relative AABB support tests. Invalid or near-parallel input conservatively
selects z-fail. This relies on complete caps and a far plane enclosing them.

`phanes.world.shadowbounds` derives the extrusion distance from the complete
world box and the actual world-space light selected by the engine. For each
nonzero component of the normalized direction, it divides the corresponding
box span plus a Single rounding margin by the component's absolute magnitude.
It chooses the shortest of these distances and rounds strictly upward to a
power of two. This translates the endpoint box beyond every receiver on at least
one coordinate axis. Each parallel ray moves monotonically on that axis, so
it cannot encounter a receiver beyond its endpoint. Invalid inputs are rejected.

The viewport uses the engine's existing `MainLightForShadowVolumes` query,
now protected, which resolves current parent transforms on demand. An absent or
positional light retains the default path. The far bound encloses all scene
geometry and finite endpoints; near distance, camera position and X/Y framing
are preserved. Camera changes do not change extrusion distance. World bounds or
light changes can change it and invalidate the corresponding cache entries.

Both rendering paths choose each finite quad's diagonal from a consistent
world-space endpoint order. Reversed shared borders therefore use opposing
copies of the same triangles despite rounded, potentially nonplanar endpoints.
The bounded static cache includes light, transform and distance in its key,
accounts for finite sides and caps within its 16 MiB temporary/resident bound,
frees CPU geometry after upload, and clears GPU entries on context loss.
Unsupported geometry and exhausted capacity use the ordinary path.

Current evidence under ignored `build/`:

- `shadow-production-candidate-03/provenance.json` binds the current ten source
  snapshots, engine patch, fresh cached WASM build and numerical evidence.
- `shadow-axis-bounds-test-01/evidence.json` records 6,050 independent checks of
  actual rounded Single endpoints, common-axis separation, far enclosure,
  camera stability, scaled directions and invalid inputs. Earlier 10,416-check
  bounds results belong to the superseded diagonal algorithm.
- `shadow-production-candidate-03/full-world.json` binds actual cached production
  captures on SwiftShader and GTX 1080 hardware. Both leave zero dark pixels in
  the 54,000-pixel overhead water sample, with empty captured error/shader-failure
  arrays. The actual overhead projection matrix gives a far plane of about
  424.82. Orbit captures are visual evidence only; their retained trace is not an
  independent Orbit measurement. Extrusion distance is not instrumented here.
- The unchanged engine-linked near-prism helper previously passed 253
  constructive intersections and 24 independent separation controls. Original
  and comparator-only controls missed 154 and 39 intersections respectively.
- The unchanged geometry implementation passed 924 checks, including the exact
  temporary-capacity boundary and the shared-border regression: 24 unmatched
  triangles before canonical diagonals, zero afterward.

Historical isolation evidence remains under `shadow-production-candidate-02/`.
At the old diagonal-derived distance of 512, both cached and ordinary software
rendering left 52 dark water sample pixels. Caster isolation assigned 11 to
buildings and 41 to foliage; a single cabin's third opaque batch reproduced all
11 building pixels. Native reconstruction found closed directed-edge topology
for all opaque cabin batches, so that experiment did not implicate mixed-shape
classification. Overlapping parent/child glass controls did not qualify glass.

Fixed-projection diagnostics then reduced distance from 512 to 32, removing all
52 sampled dots in software. Hardware retained zero sampled dots; its two full
images differed in one of 697,788 pixels. Those hardcoded experiments justified
investigating shorter conservative bounds, but applied only to that captured
world and sun. The current implementation computes its bound from actual inputs.
See `cabin-parts.json`, `cabin-topology.json`, `cabin-distance.json`,
`distance-diagnostic-safety.json` and `full-world-distance.json` for provenance
and experimental limitations.

The current direction-aware cube/floor fixture also passes all eight ray masks
(four views on each backend) with zero false positives or negatives. Its actual
light query returns a directional light and distance 4; every on/off pair has
identical light, view and projection matrices. `shadow-axis-fixture-01/evidence.json`
and `fixture-masks.json` bind sources, binaries, commands and positive lit/shadow
sample coverage. Fixture `frame.far` is nominal:
the captured projection matrix is authoritative for the effective far plane.

The current ordinary/cache full-world comparison has five byte-identical PNG
pairs out of six. The hardware restored-Orbit pair differs in one of 697,788
pixels by one 8-bit color level. Both paths leave zero sampled water dots on
both backends. `shadow-production-candidate-03/ordinary-cached-agreement.json`
records the exact difference and the frozen ordinary fallback override.

The current six-shape cube state fixture has 20 cache/ordinary comparisons
with identical light, view, projection and distance inputs and exact decoded
RGBA. Settled frames retain cache build counts; changed states rebuild, while
point and absent lights use distance zero without new cache builds. State changes
also reset or notify other properties, so build deltas do not uniquely isolate
each cache-key cause. See `shadow-axis-state-fixture-01/evidence.json`.

An opposite-side baseline provides positive visible-shadow coverage for the
multi-shape cube. Four independent masks (both paths and both backends) each
qualify 14,421 shadow and 426,884 lit pixels, with zero false positives/negatives.
Software paired pixels are exact; hardware has one one-level RGB difference,
while both images independently pass the mask. See
`shadow-axis-state-opposite-fixture-01/evidence.json`. Historical comparisons with
slightly different light inputs are explicitly invalid and retained separately.

`shadow-production-candidate-03/styles.json` binds the passing 74-check,
64-capture style/recovery journey: exterior and populated-interior styles,
regional picking, four phone layouts, real shader-failure fallback and exact
saved-session restoration after graphics loss. `landforms.json` binds 42 passing
checks of touch selection in all camera modes, scoped edits, wire round trips,
Undo/Redo and terrain-state recovery. Physical-phone checks remain distinct.

The dedicated serial benchmark on the larger saved world reports cached/ordinary
rates of 15.10/9.10 fps for desktop Orbit, 16.10/9.91 for phone-layout Orbit,
36.08/16.71 for phone-layout walking and 36.12/17.07 after graphics recovery.
Draw counts match; three desktop/phone screenshot pairs have zero differing
pixels. Both paths preserve the exact world through recovery. These are single
five-second development-machine windows, not physical-phone benchmarks. Orbit
performance remains insufficient for the full product goal. See `benchmark.json`.

Initial application previews used asset directory links, which the strict WFC
server correctly refused. Fresh previews use copied assets from an already
budgeted Pages stage; studio entry and the full style journey then pass with
unchanged runtime binaries. `plain-directory-previews.json` and
`interior-entry-repair.json` retain that packaging failure and correction.

Current object-picking regression passes 55 picks across desktop and phone layouts
with zero errors; see `picking.json`. Physical-phone qualification, clean remote
CI verification and independent feature review remain open. The broader performance
work is unfinished. Successful tests do not establish feature acceptance or
clear the release gate.
