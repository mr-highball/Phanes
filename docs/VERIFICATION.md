# Initialization verification

## 2026-09-12 development checkpoint

The current integration candidate pins CGE commit
`25f2d98122997f8f039f759f9ffb76207b4f3cfe` through the owned Castle fork.
The fork branch advertises the exact revision and a fresh sparse remote clone
retrieves the matching Git blob. The ordinary release build compiles the changed
WebGL unit from the submodule and passes. Against that build, the object journey
passes 188 checks and the full style journey passes 73 checks with 64 captures.
Source, runtime and browser evidence are bound by
`build/engine-adoption-provenance-01.json` and the manifests in
`build/engine-adoption-objects-01` and `build/engine-adoption-styles-01`.
Independent report `reviews/engine-webgl-bulk-transfer-candidate-04.json` gives
B+ intuitiveness, accuracy and wow factor, and A- thinking out of the box.
Adoption remains `changes_requested` pending a clean Phanes Actions build.
All 39 source inputs and 15 evidence fingerprints match, using the recorded
raw or normalized artifact convention
(`build/engine-adoption-review-verification-01.json`).
The subsequent CI additions change the reviewed workflow and publishing guide;
that report remains a checkpoint until renewed with the clean-runner result.
The checker regression suite passes 26 checks, while all seventeen registered
features remain held (`build/logs/ci-snapshot-review-gate-01.log`).

The immutable stage contains 9,253 files and 770,798,310 bytes, below its
900,000,000-byte budget. Its retained verification is
`build/engine-adoption-pages-evidence-01.json`. The LAN preview now serves
`build/pages/b511e42b62c64170f5840135b6397031300b36fd8f8ba1953c2b1966977cf3e7`.
Five actual HTTP host/UI responses match the staged hashes
(`build/engine-adoption-http-01/result.json`). Earlier references below to
`build/web-engine-bulk-final` describe the previous preview checkpoint.

At the user's request, the CI path was compared with AutoForge's successful
Actions run 34160777525 at commit `bf5fce2108266cc84c86336ba06f533350e682e8`.
The compiler bootstrap was already byte-identical. Phanes now copies AutoForge's
cache-save ordering, retaining a successful compiler installation before later
application checks can fail. Phanes' own clean Actions build and deployment are
still pending; the reference run does not establish them.

The first Phanes Actions run, 34727283782 at source checkpoint
`c77b5797a87228bc1c7572befe6272da1971f054`, passed compiler bootstrap and cache
preparation, then reached corpus validation. The native
`phanes.tests.fingerprint.critic` link failed because Ubuntu lacked `-lX11`.
The workflow now installs `libx11-dev`; a clean rerun must verify the fix. This
prerequisite change does not alter the separate critic hold or deployment gate.

The object-catalog candidate adds twelve measured leaf models to the existing
book/vase pair: books, artifacts, equipment and four food items. The shared
contents catalog now contains 28 choices, including fourteen optional models.
The picker adds compatible category, subgroup and name/group search without
publishing a world change until an item is chosen. All 32 optional regional and
interior models together retain 1,838,347 conservative source bytes, 11,623
triangles, 33,017 POSITION vertices and 3,670,016 texture pixels, within the
existing independent limits. Final admission evidence passes 1,018 native checks
and pas2js compilation in `build/catalog-objects-02`. The actual-world fixture
passes 4,609 checks in `build/logs/catalog-objects-world-test-03.log`, including
every interior admission on an actual generated support, unrelated-node
preservation and locks. That world run preceded only the vial display-name
correction; profile geometry and solver behavior are unchanged.

The first application journey passes 174 checks in `build/catalog-objects-browser-01`,
including all fourteen optional choices, Undo/Redo and actual graphics-loss
restoration. Its screenshots exposed cramped default dropdown styling, now
corrected with full-width 44-pixel controls. Rendered inspection also changed the
pale bottle's display name to Stoppered vial. The final release build passes in
`build/logs/catalog-objects-main-build-02.log`, with source and artifact hashes in
`build/catalog-objects-provenance-02.json`. The final styled-control browser run
passes 188 checks in `build/catalog-objects-browser-02`, including all fourteen
admissions, compatible filters, empty search feedback, full-width touch targets,
exact unrelated-node/selection preservation, Undo/Redo and actual graphics-loss
restoration. Final browser errors and shader-failure arrays are empty; 29 PNGs
retain every chooser/object view and the recovered session. Its provenance binds
six test sources and all final evidence. Independent Luna report
`reviews/catalog-expansion-01.json` records B intuitiveness, C accuracy,
B wow factor and B+ thinking out of the box. The full feature remains
`changes_requested`: broader category admission, placement, visual coherence and
populated-world performance still need implementation and evidence. All 98
registered inputs and 54 evidence fingerprints match
(`build/catalog-objects-review-verification.json`). The completed subset is not
full catalog acceptance.

The release checker ran once after registering this report in
`build/logs/catalog-objects-review-gate.log`: its 26 regression checks pass;
the isolated engine candidate passes and sixteen other features remain held.

The independently reviewed engine transfer source is now recorded as local
commit `25f2d98122997f8f039f759f9ffb76207b4f3cfe` on
`codex/phanes-webgl-bulk-upload` in the separate engine development checkout.
Its source hash still matches the approved isolated candidate exactly. This
recorded a reproducible revision before the current integration candidate; at
that checkpoint the application pin was unchanged and the commit was local.
Historical evidence is retained in
`build/engine-transfer-local-commit.json`.

The preceding room-surface candidate builds against the pinned engine
(`build/logs/surface-candidate-main-build-01.log`). It replaces periodic interior
wood grain, increases existing stationary fill lights in portal rooms, limits
first-person field of view to 95 degrees on the larger viewport axis, and adjusts
initial room-entry pitch. The same authored world, excluding solve timing, is
retained in `build/surface-sweep-baseline-01` and `build/surface-sweep-candidate-01`.
Each contains 48 captures across desktop, portrait and landscape, None and Toon,
top/orbit/fly/walk and grazing views, phone quality choices and graphics recovery.
The candidate passes 57 checks with no recorded uncaught errors or shader
compilation failures; its source and artifact provenance verifies 118 hashes.
Shader instrumentation queries compile status, so these runs are visual and
recovery evidence, not performance benchmarks. Physical-phone performance and
full feature acceptance remain open. Report 03 below predates this candidate.

The named-room recovery journey passes 24 checks against that candidate in
`build/recovery-rooms-run05` (`tools/test-recovery-rooms.ps1`). Actual catalog Apply
creates a cabin, followed by a six-bay plan, Bay 5 laboratory and nested shelf
object. Native IndexedDB and actual WebGL-loss reload preserve the exact world,
Undo/Redo stacks, nonrectangular selection and interior context. Fresh canvas ray
picks select the framed object before and after recovery; a subsequent local edit
preserves every unrelated composition node. Phone and desktop captures and source/
artifact provenance are retained. Runs 01-04 retain fixture failures: category
selection did not Apply a cabin, and an incorrect mask used local instead of world
grid coordinates. The final fixture uses a cleared seeded world and complete
catalog controls. No runtime change was needed for this journey.

Independent Luna report `reviews/mobile-rendering-recovery-04.json` resolves the
tested named-room recovery and desktop surface-comparison gaps. Grades are B+
intuitiveness, B accuracy, B+ wow factor and B+ thinking out of the box. The full
feature remains `changes_requested` pending final affected-phone measurements
and background/return/authoring verification. At that checkpoint all 129 declared
inputs and 236 retained evidence fingerprints matched
(`build/surface-room-review-verification.json`). The newer catalog/picker changes
make that review historical until renewed acceptance.
The review checker and its regression tests ran in
`build/logs/surface-room-review-gate.log`; release acceptance remains held. The
LAN preview still serves the earlier `build/web-engine-bulk-final` candidate;
this new pinned-engine build has not been promoted there or published.

Saved-workspace reads now wait for the IndexedDB transaction to complete before
starting world admission. A reproduced abort after a successful `get` previously
restored the world anyway, and a synchronous `get` exception escaped into startup
failure. Both now retain the checkpoint and offer recovery retry. The release
build passes in `build/logs/recovery-read-main-build-01.log`. Five targeted storage
cases pass 35 checks in `build/recovery-storage-final-01`: queued saves, immediate
read abort, abort after read success, synchronous read failure, and size preflight.
They compare persisted and live world/history/selection/camera data and exercise
retry. Faults are deterministic instrumentation, not observed OS quota failures.

The delayed first-entry journey passes 24 checks against the fixed build in
`build/logs/recovery-entry-02.log`, with captures in `build/recovery-entry-02`.
It retains a nonrectangular mask and both history stacks through actual browser
freeze/active and WebGL-loss reload, rejects an injected stale valid worker result,
and successfully enters afterward. Application provenance is recorded in
`build/recovery-read-provenance-01.json`; both final evidence directories bind
their tests and artifacts. Independent Luna report
`reviews/mobile-rendering-recovery-03.json` confirms these corrections, retaining
B+/B/B/B+ and `changes_requested` for the unchanged full mobile scope.
At that checkpoint, all 127 declared source fingerprints and 24 evidence
fingerprints matched the critic report
(`build/recovery-read-review-verification.json`). That gate accepted the isolated
engine candidate and held the other 16 entries;
see `build/logs/recovery-read-review-gate.log`.
Named-room loss with fresh picking is exercised by the newer candidate above;
remaining device checks and full mobile acceptance remain open. The session
source change makes the earlier bounded
regional approval below historical until renewed review.

The regional optional-catalog candidate adds 18 measured models across five kits
and all five ecological roles, expanding the palette from 19 to 37 choices.
`tools/test-catalog-regional.ps1` passes 669 native checks and pas2js compilation;
`tools/test-catalog-regional-integration.ps1` passes 4,114 WFC placement,
preservation, palette, collision and invalid-domain checks. The two interior
admissions still pass 65 native checks, and their actual application journey
passes all 67 checks against the final build in `build/catalog-regional-interior-world-02`.
The release build passes in `build/logs/catalog-regional-main-build-02.log` and
full source verification accepts all 8,365 models and 37 palette entries in
`build/logs/catalog-regional-kit-verification-02.log`. Application and generated
runtime hashes are recorded in `build/catalog-regional-provenance-02.json`.
The regional browser journey passes 129 checks in
`build/catalog-regional-browser-actual-05`, including every exact item, unchanged
surroundings, all 18 models resident together, phone Apply, desktop/phone history,
save/reload, complete retirement/reacquisition and distant chunk pinning. Its 18
individual captures use actual terrain height for framing; group and phone
controls captures provide context. Both pre-reload and final console logs are
empty. Five initially gray source exports were replaced with textured or colored
models before this final run, and native admission now rejects uncolored tree
and flower sources. Independent Luna review passes this bounded milestone at B+
in all four categories in `reviews/catalog-regional-bounded-01.json`, with all
81 normalized fingerprints verified. The registered milestone includes its retained
local evidence; it does not clear the full catalog or release. The native gate
passes this milestone and the isolated engine candidate while holding the other
15 features (`build/logs/catalog-regional-review-gate.log`). The earlier two-object report
below is historical after these shared changes.

The first optional world-publication candidate builds against the pinned engine
(`build/logs/catalog-main-build-02.log`). It adds the book/vase admissions,
preparation before world/history/session mutation, bounded scene residency and
retirement from both renderer template caches. Native regressions pass 308
modular-building assertions and 963 composition/contents assertions. The first
actual-application browser journey passes 67 checks in
`build/catalog-world-actual-08` (retained `checks.log`): book/vase replacement through object controls,
exact unaffected-node preservation, optional-world and core-world session reload,
Undo/Redo, complete retirement, failed-download preservation and successful retry.
Held real fetches exercise explicit Cancel and selection-change cancellation,
including exact world/history/future preservation and no stale overwrite. The
modular-building journey also retires and reacquires its distinct template cache.
Successful retry immediately clears the previous error notification. Desktop and
phone-layout captures show the admitted models without notification occlusion;
all phases check for uncaught browser errors, including before reloads.
Both models together retain 74,481 source bytes, 724 vertices, 272 triangles and
1,048,576 texture pixels. Independent Luna review passes this bounded milestone
in `reviews/catalog-publication-bounded-01.json` with B+, A-, B+, A- and 33
verified normalized fingerprints. It covers the two leaf admissions and their
publication paths; `catalog-expansion` remains pending. The residency counters
sum distinct model profiles rather than every placed instance or total GPU bytes.
Application/runtime fingerprints before and after
that browser run match `build/catalog-world-provenance-04.json`, including the
compiled nearby-entry and JavaScript fetch-exception fixes. This candidate was
tested separately on localhost; the owned test server is now stopped. It has not
replaced the reviewed user LAN preview.

The earlier optional-loader and decoded-scene lease milestone passed independent Luna
review in `reviews/catalog-runtime-bounded-04.json` (B+, A-, B+, A-). Current
evidence includes 67 fetch checks in `build/logs/catalog-fetch-cleanup-test.log`,
49 native filesystem/scene checks, and 18 Castle browser checks in
`build/catalog-runtime-lease-final`, with source/runtime provenance, four captures
and no browser errors or resource warnings. The reviewed contract document retains
its pre-review checkpoint text; this journal records the subsequent decision.
The subsequent integration edits change inputs of that bounded review, so its
decision is historical evidence for the earlier candidate. This milestone does
not pass full catalog placement, WFC admission, session
integration or global decoded/GPU budgeting. `catalog-expansion` remains pending.

The user confirmed on a physical phone that shadows and Orbit look much better
after moving closer to the access point. Desktop local download speed was also
reported fast. This is qualitative device evidence; phone/browser identity,
measured phone FPS, text crispness and minimize/return recovery remain unconfirmed.
The phone used the isolated engine candidate on LAN port 4200. Improved loading
near the access point is consistent with a Wi-Fi contribution, without isolating
the adapter or access point as the cause.

The separately staged shader fallback fix on localhost port 4202 passed the
complete Pascal style journey: 73 checks and 64 captures, no failure, including
real GLSL compilation failure, restoration of None, renderer reload, exact saved
world/history/style/session preservation and successful subsequent style changes.
Evidence: `build/engine-style-fallback-full-01/evidence.json`; stage provenance:
`build/web-style-fallback-01-evidence.json`. Independent Luna report
`reviews/visual-styles-02.json` passes with A-/A-/A-/B+ after the evidence
documentation update. The direct registry checker accepts visual styles and the
engine candidate; the other 14 features remain held.

The reviewed shader fix was then promoted to the existing LAN port-4200 site.
All 124 new manifest parts were verified before switching the host, and old
immutable parts were retained for in-flight downloads. Served host, WASM and
manifest hashes match the reviewed stage. Promotion evidence is retained in
`build/lan-style-promotion-01.json` and `build/lan-style-promotion-http-01.json`.
The earlier user phone confirmation still refers to the pre-promotion build.

The independent engine candidate report 03 passes the actual registry checker
after critic-owned report serialization corrections. All 26 checker regression
fixtures pass. The bounded shadow-cache
approval does not approve the full terrain feature or adopt the engine dependency.

Usage controls now limit work to one active subagent, default routine Sol work
to Low reasoning and retain Luna review at B+ in every category. The local token
snapshot in `build/agent-usage-20260912.json`, weighted using published Standard
credit rates, estimates relative consumption at 60.7% Astra, 38.6% combined Sol
builders and 0.7% Luna. This is a planning estimate, not account billing or a
breakdown of the reported weekly allowance. It supports reducing coordination
and builder work rather than weakening the critic gate. Updated assignment rules
are recorded in `CRITIC_WORKFLOW.md`.

## Modular housing verification

The Castle release web build and Pascal checks pass without compiler warnings in
`build/logs/modular-renderer-build-10.log`. The native modular suite passes
308 assertions (`build/logs/modular-tests-13-wrapper.log`), covering exact WFC
footprints, preserved extensions and nested contents, zero plates, protected
descendants, furniture placement and physically blocked routes. The independent
critic's native probes pass 27,929 checks, including comparison of 25,921
spatial collision queries with a complete geometry scan. Retained native review
and failure history: `build/critic/modular-furniture-review-02.md`.

The browser journey in `build/modular-browser-07` passes 18 assertions through
the real controls: create a home, change a wall to a window, furnish a floor,
set plates to two then zero through Reimagine, extend while preserving contents,
open/close a nearby door, walk inside without changing world context, and reload
the exact world/history/tool selection. Desktop and phone-sized renders include
the furnished extension and a view of the surrounding land through a window.
This builder journey supplies exact masks and part-list selections. The independent
critic additionally exercises actual Box-created homes and extensions, phone Brush
strokes, and Lasso/part picking across all four camera views. See
`build/critic/modular-ui-review-01.md` and `modular-ui-review-02.md`.

An empty 256-floor home took approximately 33 seconds to generate in the first
native admission profile. Avoiding repeated full-document checks for empty
floor supports reduced the independent optimized-native measurement to 437 ms;
whole-world admission took 156 ms. These are bounded workstation fixtures.
The browser construction CPU capture fell from 12.0 seconds to 3.34 seconds
after sharing immutable CGE material effect nodes; the earlier profile was
dominated by repeated shader compilation. The shared-cache comparison is in
`build/modular-browser-05/construction-profile.json` and
`build/modular-browser-06/construction-profile.json`. These captures include
driver/idle time and are not phone frame-rate claims.

The gate checker passes its 26 synthetic regression cases. Full feature
acceptance remains controlled by the independent reports in `reviews/`; the
development evidence above does not override pending or stale product gates.

Build 08 adds selected-object framing,
empty-support bounds, a separate whole-home overview, camera-scaled selection
outlines, inspection bounds independent of distance culling, and compatible
high-zoom recovery. Its visual refinement retains saved material identities
while reducing large-scale plaster/wood contrast and adding filtered floor
joints. The independent baseline gesture record is
`build/critic/modular-ui-review-01.md`; its retained failures prompted these
corrections. The second rendered review verifies plate, empty-support and fruit
framing, all four shelf facings, distant-home framing beyond the culling radius,
and exact high-zoom recovery. Build 09 also synchronizes the Tap highlight when
selecting/restoring parts and retains the selected furnishing's own rotation
when framing it. The third rendered review caught wall occlusion despite correct
camera coordinates. Build 10 adds an inspection cutaway for same-home wall
modules between the eye and selected furniture/support bounds; the document and
walking collision remain unchanged. Whole home now selects the root and restores
its walls. Independent final captures in `build/critic/modular-browser-04`
verify the wall-adjacent bookcase, restoration when reveal is disabled or a
wall/home is selected, and actual touch movement blocked by the restored wall
in first person. Forced `WEBGL_lose_context` recovers the exact world, history,
redo stack, mask, nested selection and high-zoom camera; a new engine ray selects
the same apple after recovery. Browser errors remain empty. These are desktop
Chromium checks with phone dimensions/DPR2, not physical-phone GPU or OS-kill
acceptance. The separate legacy plate regression passes 19/19 actual phone-layout
checks, including zero counts, retained forks, Undo/Redo and protected food;
evidence is `build/critic/plate-primary-current-02/checks.json`.

The independent final report is
[modular-housing-01](../reviews/modular-housing-01.json): B+ intuitiveness,
B+ accuracy, B+ wow factor and A− thinking out of the box. All 141 declared
input fingerprints match. The final checker accepts `modular-housing` and its
26 synthetic regression cases pass (`build/logs/modular-final-gate-01.log`).
Fourteen broader feature gates remain held for pending, stale or rejected
reviews; this feature acceptance does not clear the overall release gate.
Dependency pins remain unchanged. No commit, push or deployment was performed.

Verified locally on 2026-09-07:

- Built the Castle command line tool from the pinned submodule source.
- Compiled the release WebAssembly application and pas2js dependency check.
  Dotted application and test unit names compiled successfully.
- Ran the browser smoke check at `/` and `/Phanes/`, each at 1280 × 800 and
  390 × 844. WFC initialization and Castle rendering passed with no JavaScript
  errors, failed requests or HTTP error responses.
- Inspected desktop and phone screenshots of the project-title view.
- Checked authored source license headers, dotted unit declarations, formatting,
  workflow YAML, shell syntax and PowerShell parsing.

Logs, screenshots and JSON evidence are in ignored `build/`. Local builds used
the available FPC 3.3.1/pas2js toolchain; the Linux compiler bootstrap and GitHub
Pages deployment must be exercised by the first workflow run. No deployment or
GitHub repository setting was changed during initialization.

## Regional world editor

The first world-creation increment builds the Castle web application and Pascal
worker successfully. Asset verification covers 905 imported model hashes,
GLB/texture references, notices, and all 18 regional palette/prefab references.

Generator tests passed for deterministic generation at region widths 4, 8, 12,
24 and 48. They also cover every initial brush, exact preservation of all cells
outside a selected region, clearing all four finer ecology cells under each
building, rejection of an incompatible forest/water edit, exact saved-layer
restore, and rejection of unknown assets, fractional dimensions and truncated
saved layers. These checks exercise the real compiled Pascal worker.

On this machine, two cold worker runs together took about 0.52 seconds at width
12 (1,584 pass cells) and 5.16 seconds at width 48 (25,344 pass cells). These are
local development measurements including worker startup, not browser rendering
benchmarks or a cross-platform performance guarantee. Large-world rendering,
chunk updates, memory budgets and device comparisons remain unverified.

Desktop and phone UI checks exercise initial creation, castle replacement,
Castle rendering, all four camera modes and the editing/exploration toggle.
Desktop checks additionally exercise drag selection through CGE picking and
exact undo/redo. Current evidence and screenshots are retained under `build/`.
The public GitHub workflow and Pages deployment have not been run for this
increment. See ROADMAP.md for the complete outstanding objective.

## Pascal audio tooling and current review status

On 2026-09-08, the native Pascal asset tools verified all 905 imported models
and reproduced the musical corpus from 135 distinct scores and 393 excerpts.
The native generator exercised participation by all 135 references in each of
four lanes, deterministic initial generation, seams, locked lanes and ten style
arrangements. The Castle web application and both Pascal audio entry points
also compiled successfully. These checks do not establish complete playback UX.

Ten styles were rendered through the browser's offline audio context using the
same Pascal synthesizer as live playback. The outputs had nonzero audio and no
clipped samples; waveform statistics do not establish listening quality. Live
startup produced scheduled events without reported late events or underruns
during a short probe. Longer playback, individual audible locks, phone controls
and listening assessment still require evidence and independent re-review.

The first audio critic review was **changes requested**: intuitiveness C,
accuracy C, wow factor C, thinking out of the box B. Corrections and new evidence
do not promote these grades automatically. See the durable reports under
`reviews/` and [CRITIC_WORKFLOW.md](CRITIC_WORKFLOW.md) for the acceptance gate.
The complete world creator and public Pages deployment remain unfinished.

## Critic workflow

The independent critic accepted the workflow and Pascal release checker in
[review 03](../reviews/critic-workflow-03.json): intuitiveness A-, accuracy B+,
wow factor B+, thinking out of the box B+. Its earlier implementation rejection
is retained in review 02; both reported path traversal cases were corrected.
All 26 native gate regression checks passed. Subsequent additions to the CI
workflow invalidate report 03's fingerprint; the workflow feature needs a new
review before release. The real registry also holds the unfinished foundation,
world and audio features. GitHub has not yet exercised the configured Pages gate
remotely.

## Custom Phanes interface and granular composition

The 2026-09-08 interface pass uses a project-local, 24-glyph imagegen atlas and
custom world/music controls. Generation prompts, the selected hash and the
RGB/screen compositing limitation are in [INTERFACE_ART.md](INTERFACE_ART.md).
The Castle/FPC release build with pas2js checks passed. The existing browser
suite passed at both root and `/Phanes/`, including desktop/phone startup and
the real Pascal audio worker protocol checks. Logs are
`build/logs/identity-build.log`, `identity-root-browser.log` and
`identity-project-browser.log`.

The independent first interface review requested changes (B/B/B/B+) for visible
atlas tiles and music-node overlap intercepting a blend slider. It is retained
as [interface review 01](../reviews/interface-identity-01.json). Corrected CSS
uses opaque painted backdrops for blending and budgets spacing for each whole
node plus its strength control. A geometry/hit-test sweep at 360, 390, 700, 900,
1100, 1180, 1280 and 1440 pixels found no default node overlaps and all ten slider
centers hit the intended input. Evidence is `build/identity-spacing.json`.
Desktop and phone images are retained under `build/identity-*.png`.
The independent [interface review 02](../reviews/interface-identity-02.json)
passed with B+ in all four categories. It covered eleven widths including both
sides of responsive breakpoints, direct slider input, desktop and project-path
phone flows, focus, reduced motion and clean rendered glyphs. No page/resource
errors were captured. The registry now points to report 02 while retaining the
initial rejection. This approval covers only the interface identity and control
integration; subsequent interior changes to its declared inputs make this
approval historical. The interface needs a fresh review, and the complete world
and audio features remain held.

[GRANULAR_COMPOSITION.md](GRANULAR_COMPOSITION.md) records the required terrain,
foliage, routes, foundations, modular structures, named interiors, furniture
surfaces, shelf tiers and independently editable contents. Source inspection
confirmed that the five regional arrays and fixed dining-room prototype do not
implement this hierarchy. The catalog audit identifies existing candidate
modules and missing admission contracts; it does not claim new usable 3D models
or a completed nested editor.

## Composition document primitives

The portable Pascal composition document and scoped transaction layer passed
63 native and 63 browser-compiled checks. The fixture uses explicit test asset
IDs for Bay 5, a laboratory, a shelf unit, two shelf tiers, a snail and three
individual books. It is not evidence that those models or editing tools are
available in the game. Run `tools/test-composition.ps1` for native checks;
`build-web.ps1 -WithTests` compiles the same program for the browser, and
`node tools/test-composition.cjs` executes it in Chromium. CI includes both paths.

Checks cover identity/order independence, rename/reference preservation,
independent snapshots, scoped insertion/replacement/deletion boundaries, locks,
stale candidate/baseline revisions, caller output aliasing, orphan/cycle rejection,
and storage-order-independent depth limits. Independent critic counterexamples
exposed and drove fixes for scope-root reparenting, indirect movement through
external support, a locked dependent inside a wider scope and aliased output
clearing its baseline. Evidence is in `build/composition-browser-evidence.json`,
`build/logs/composition-tests.log` and the critic's composition probes under
`build/critic/`. Full-world acceptance remains pending.

The same program also passes 252 WFC content checks and 68 composition wire
checks on both runtimes. Contents checks exercise exact per-surface quotas,
multiple seeds, deterministic replay, measured headroom, rotated footprints,
per-item asset filters, grouped-mesh rejection, locks, atomic failure, forged
decoded results and preservation of neighboring instances. A native/browser
record-alias difference exposed accidental catalog mutation; indexed record
copies fixed it and a regression checks input catalog preservation.

Wire checks exercise all serialized fields, unsigned seeds, Unicode labels,
escaped text, independent loaded snapshots, output aliasing and failure
preservation. They reject malformed or oversized numeric fields, missing fields,
unsupported versions/units, duplicate keys (including escaped duplicates),
unquoted keys, trailing documents, unknown kinds, unpaired Unicode surrogates
and invalid hierarchies. Native UTF-8 transport and Unicode display names avoid
ANSI label loss.

The independent critic's content oracle matched 400 cases on both targets
(52 feasible, 348 impossible). Separate nested-overhang cases reject when a
complete assembly envelope is unavailable; a leaf on an explicit nested surface
still solves and preserves Unicode labels. The critic's wire retest passed 16
shared adversarial cases and three native encoding cases, including unpaired
surrogates, malformed UTF-8 and the same UTF-8 byte-size limit on both targets.
The bounded reports retain their original findings and correction evidence in
`build/critic/contents-correctness-01.md` and
`build/critic/composition-wire-correctness-01.md`. These are correctness reviews,
not full-feature grades or world-creator approval.

The release web build also compiled these tests successfully. These portable
Pascal foundations now support the cabin workflow described below. The full
catalog admission and world-creator critic gate remain outstanding.
Existing WFC dependency, audio worker protocol and Castle desktop/phone startup
checks passed after the build (`build/logs/composition-web-smoke.log`).

## First connected cabin interior

World format 2 embeds the composition document; older regional snapshots migrate
to an empty composition root. The worker, CGE renderer and new Pascal browser
controller now support furnishing a selected cabin, entering a cutaway studio,
drilling into four real shelf tiers and replacing one independent object. The
initial example has three books on Shelf 4 and a ceramic snail on Shelf 2.
Tables expose separate plate and fork instances. Model measurements, graph
encoding, admission rules and current limits are in [INTERIORS.md](INTERIORS.md).

The 383 native composition checks passed after the contents naming correction
(`build/logs/interior-composition-tests.log`). The actual compiled worker and
desktop/phone CGE journeys passed in `build/logs/interiors-visible-pick-tests.log`:
33 seeds yielded eight admitted furniture layouts; edits preserved unrelated
records; invalid roles, support geometry, wire shapes and locked changes were
rejected; undo, export and exact import succeeded. The pointer checks exposed
an invisible near-clipped bookcase post intercepting clicks. Picking now begins
on the camera's visible near plane, including off-centre perspective rays.
These initial results preceded the final floor and picking corrections below.

The floor refinement subsequently passed the release web build and full root
and project-path journeys (`build/logs/interiors-face-picking-build.log`,
`build/logs/interiors-face-picking-root.log` and
`build/logs/interiors-face-picking-project.log`). This includes ten visible-prop
picks per viewport, covering centre/four offsets in frontal and oblique poses.
The oblique regression also exposed double-sided collision hits on culled mesh
backfaces; the corrected picking traverses past those faces while retaining
genuinely double-sided geometry. A renderer acknowledgement now distinguishes
the visible room from UI state in these checks. The full 383 browser composition
checks, regional generation/preservation checks and root/project general web
startup/audio protocol suites passed in `interiors-composition-browser.log`,
`interiors-world-regression.log`, `interiors-web-root.log` and
`interiors-web-project.log` under `build/logs/`.

The independent [interior review 01](../reviews/granular-interiors-01.json)
passed this bounded cabin workflow with **B+ in each of the four categories**.
The critic verified all 44 input fingerprints, desktop/phone interactions,
20 edge-slot picking cases, selection of a genuinely visible post, and a copied
double-sided GLB fixture whose visible backface remains selectable. Exact
neighbor preservation, undo/redo, export and announced keyboard context passed.
Prior rejections and fixes remain in
[the critic-owned history](../reviews/granular-interiors-00-history.md) and
the linked adversarial reports under `build/critic/`.
The complete world still needs connected exterior/interior scale, named room
programs, foundations, paths/flows, modular structures and wider catalog coverage.
The release gate's 26 native regressions passed. Its real registry still holds
the unfinished world, foundation and musical development, plus stale interface
and workflow reviews; this interior pass does not authorize a release. Subsequent
scale, material and frame-acknowledgment changes invalidate its input fingerprints;
report 01 is now historical and an updated interior review is required.

Dependency checkouts remain pinned to CGE
`050f07edde6652d6657b4fe0d299822b9f502afa` and WFC
`47fa3d8cb8f0f72bf53943eb5eb79758c8f22ce4`. No dependency edits were needed for
these local furniture and contents graphs.

## Physical structure scale and admission

The scale increment is described in [STRUCTURES.md](STRUCTURES.md). The actual
Castle reference tests exposed an ignored root multiplier and the rocket's
embedded origin offset. Complete assemblies now use centered physical bounds;
the cabin is an original shell sized around the 9.4 m studio and a separately
measured doorway. The critic also exposed a scaled-rock collision mismatch,
overlapping doorway trim, repetitive exterior grain and stale frame reporting.
The builder addressed these findings. The independent
[physical structures review 01](../reviews/physical-structures-01.json) passed
the registered increment with **B+ in all four categories**, after rechecking
all 59 input fingerprints. Earlier findings and corrections are retained in
[its review history](../reviews/physical-structures-00-history.md).

The release WebAssembly/pas2js build passed in
`build/logs/structures-render-ack-build.log`. Actual structure bounds, 1.68 m eye,
70-degree minimum effective walking FOV and clean desktop/phone rendering passed
at root and project paths in `structures-render-ack-root.log` and
`structures-render-ack-project.log`. The full cabin interior journeys passed
again in `structures-interiors-root.log` and `structures-interiors-project.log`.
General Castle startup and audio worker protocol checks passed on both paths in
`structures-web-root.log` and `structures-web-project.log`.

Native landscape checks passed 84,238 assertions, including continuous height
intervals and current tree/rock placement profiles. The 383 composition/content/
wire checks passed natively and through pas2js. The real worker suite passed
generation, frozen-region and import tests, plus explicit submerged-building
refusal. It no longer accepts a meadow label as proof of a dry floor. The Pascal
asset tool verifies 905 unchanged source models and 19 regional choices,
including the exact authored cabin generator profile. Logs use the `structures-`
prefix under `build/logs/`; screenshots and measured bounds are under `build/`.

The 26 critic-gate regression checks also passed. The real release gate continues
to hold incomplete features and stale reviews. This increment does not implement
explicit foundations, graded approaches, connected doors, named room programs,
routes/flows or the requested musical development. Dependency pins are unchanged.

## Groundwork domain increment

[GROUNDWORKS.md](GROUNDWORKS.md) describes the Pascal adapter. At this initial
checkpoint it was not yet integrated into the application.
Native and pas2js/Chromium checks passed 537,222 assertions: 8,100 cardinal plot
candidates, continuous-envelope and full-width access checks, deterministic
material WFC, exact scoped preservation, save round trips and malformed-document
rejection. Evidence is `build/logs/groundworks-runner-native.log`,
`build/logs/groundworks-browser.log` and `build/groundworks-browser-evidence.json`.

The independent domain critic found extreme-coordinate overflow, unchecked enum
values, success without a changed result, and edits preserving a malformed
neighboring plot. Regression fixes retain locked/outside parts and rejected output.
The bounded review history and native/browser probes are under
`build/critic/groundwork-domain-review-01.md`. This domain review awards no product
grades; the full `groundworks` feature is registered and pending.
The critic's final native and Chromium probes closed those counterexamples and
retained 90 independent pose/profile tamper rejections, 64 actual single-panel
alternatives, orphan/unknown-profile rejection and aliased-output preservation.
The 26 release-gate regressions also pass; the actual feature registry remains
held for pending features and stale implementation fingerprints.

The release Castle/pas2js build and new CI test compilation passed in
`build/logs/groundworks-full-build.log`. Desktop/phone startup and audio protocol
checks passed at root and project paths in `groundworks-web-root.log` and
`groundworks-web-project.log`. At that checkpoint the profiles were not admitted
by the live world worker or rendered by Castle. The integration below adds that
path; building footprints and descendant preservation remain required.
Changes to shared build/specification inputs stale the historical physical
structures review; its B+ grades are retained, not treated as a current release
pass. No feature gate was bypassed and dependency pins remain unchanged.

## Groundwork worker, renderer and creation controls

The explicit plots now run through the actual world worker and Castle renderer.
The release build passed in `build/logs/groundworks-ui-build-06.log`. Native and
pas2js/Chromium suites pass **538,728 checks**, including real world transactions,
one-revision publication, the final available revision, exact restore, partial
clear rejection, protected descendants, material scope preservation, terrain
caches and walking access. Evidence is `groundworks-spawn-native.log` and
`groundworks-spawn-browser.log` under `build/logs/`. The actual worker protocol
suites pass at root and project paths (`groundworks-worker-confirm.log` and
`groundworks-worker-project.log`).

The Pascal creation controller now places foundations/launch pads, selects deck
parts, reimagines individual rim panels, swaps the support body and restores
exact prior worlds through undo. The real Castle browser journeys exercise
desktop keyboard and phone touch movement, exact south/east entry coordinates,
constant 1.68 m eye height and arrival on the deck. Both hosting paths pass with
no page errors: `groundworks-view-root-03.log` and `groundworks-view-project.log`.
Their corresponding `build/groundworks-view-{root,project}-evidence.json` files
retain the measured start/arrival positions and revisions. Screenshots use the
`build/groundworks-` prefix. Visual inspection corrected an inherited two-column
phone sidebar; the updated test requires the controls to use the full width.
The complete existing cabin interior worker and desktop/phone browser journeys
also pass at the project path (`groundworks-interiors-project.log`).
An additional ordinary phone-toolbar regression was corrected by wrapping its
four selection actions into two columns. The critic independently exercised
their touch hit targets, selection, regeneration, entry and return focus. Each
action fits within the viewport at 181 by 52 px. This stylesheet-only correction
is included in the served build and in the updated `test-web.cjs` width checks.
The final root and project startup, audio protocol and desktop/phone suites also
pass (`groundworks-web-root-07.log` and `groundworks-web-project-07.log`).

The independent critic found a square-post collision corner, a 27.91 mm landing
contact error, different coarse terrain contact and an approach shortcut outside
the admitted dry apron. Corrections use expanded post rectangles, 0.125 m landing
and retaining-edge subdivisions, retained contact terrain across prop LOD, and an
entry point at the landing's outer edge. The critic's actual Castle ray sweep
peaks at 0.565 mm contact error; sampled boundary seams peak at 1.962 mm, within
the 2 mm target. The formerly submerged shortcut now enters and reaches the deck
through real phone input. All 12 current vegetation GLBs and placement envelopes
also retain clearance from the admitted approach. These are bounded measurements,
not universal performance or asset-compatibility claims.

The independent failure/closure history is retained in
`build/critic/groundwork-render-review-01.md`; worker findings are in
`groundwork-integration-review-01.md`. At that checkpoint, building attachment,
retained studio descendants, direct 3D part picking/highlighting, wider profiles
and large-world performance remained outstanding. No product grades or groundwork feature pass
have been awarded. The 26 release-gate regressions pass; the real registry
continues to hold unfinished features and stale reviews. Dependency checkouts
are clean and their pins remain unchanged.

## Supported buildings and retained cabin contents

The supported-building adapter now gives each admitted plot one explicit
deck-owned shell. Its cabin can own the existing studio, four-tier shelf,
tabletop surfaces and independently editable props. Placement, removal,
incompatible replacement rejection and compatible support edits preserve the
scoped transaction and lock rules. Custom building names survive replacement.

Release build `build/logs/attached-web-build-06.log` compiles the Castle WASM
application, worker and Pascal controllers/tests. Native and Chromium runs each
pass **541,191** groundwork checks (`attached-native-final.log` and
`attached-browser-final.log`). Added fixtures cover all seven profiles on both
plot purposes in all four directions, complete walking circuits, forged poses
and ownership, extra descendants, locks, retained furnished subtrees, malformed
layers and the last available public revision. The existing 383 composition
checks and world-generation/restore browser checks also pass.

The actual root-hosted journey (`attached-view-root-07.log`, with
`build/supported-buildings-root-final-evidence.json`) and project-hosted journey
(`attached-view-project-final.log`, with
`build/supported-buildings-project-final-evidence.json`) pass on desktop and phone.
It places all seven shells, furnishes a supported cabin, verifies three books on
Shelf 4 and the Shelf 2 ornament, frames and ray-picks that individual ornament,
reimagines it with all neighbors unchanged, restores the exterior camera, edits
supports/panels, removes/undoes the building and restores the saved furnished
world. The keep's complete six-segment perimeter circuit runs through real
keyboard and touch input at a 1.68 m eye height. This is exterior collision;
the studio remains a separate cutaway.

The legacy cabin worker and actual desktop/phone interior journey also pass at
the project hosting path (`attached-legacy-interiors-project-final.log`).

Independent critic evidence under `build/critic/` retains 944 adversarial
mutations, initial failures and corrections. `attached-domain-review-01.md`
closes malformed-layer and custom-name defects. `attached-facing-review-01.md`
records sixteen actual cardinal model views and source geometry checks: keep
uses a 270-degree offset, both suburban primary facades 180, small habitat zero,
and the round asset is correctly described as a sealed module. A dark facet
was not evidence of an entrance. Live Castle bounds are checked against reviewed
support envelopes before a loaded model can retain those collision assumptions.
`attached-facing-review-02.md` independently reviews the root result and retained
images, closes the concrete walking/picking/framing gaps, and records a fresh
944-mutation native retest. It awards no full feature grades.

An incremental WASM failure was traced to old terrain-scene destruction after
the support record changed. The initial build had reused the terrain unit while
recompiling the record's direct consumers. Rebuilding authored units cleared the
failure; `build-web.ps1` now invalidates authored `.ppu`/`.o` artifacts together.
The stack, compilation evidence and limits of that diagnosis are retained in
`attached-renderer-diagnostic-01.md`. No vendor ownership change was needed.

The 26 critic-gate regression checks pass, while all eight registered features
remain on hold. At this attachment checkpoint, direct 3D groundwork selection
was still outstanding. Larger room and asset catalogs, modular construction,
routes, full visual quality and scalable performance remain required by the
original objective. This bounded verification does not award a product pass or
change dependency pins.

## Direct exterior part selection

The shared Pascal visible-ray helper now resolves the nearest rendered face to
the placed instance's persistent ID. Per-instance building wrappers prevent two
references to the same model from sharing selection identity. Ordinary terrain
hits resolve the admitted landing only when no nearer opaque geometry occludes
it. Outlines and region borders cannot intercept selection rays or navigation.

Root-hosted desktop and phone checks pass in
`build/logs/groundwork-picking-root-04.log` (desktop branch) and
`groundwork-picking-root-phone-05.log` (corrected phone fixture). Complete results
are preserved separately as `build/groundwork-picking-root-desktop-evidence.json`
and `groundwork-picking-root-phone-evidence.json`. Initial phone fixture failures
expected a south-facing panel after an eastward rotation, aimed at a rail smaller
than one screen pixel, or targeted a support behind the access ramp. Corrected
checks frame small geometry and explicitly retain the ramp occlusion case.

Release build `build/logs/groundwork-picking-build-08.log` and the project-hosted
journey `groundwork-picking-project-final-02.log` pass. The latter records 27 actual
desktop selections and 28 on a 390 CSS-pixel phone at device scale factor two,
with no page/network errors. `build/groundwork-picking-project-final-evidence.json`
retains both complete branches. Every selection compares every field in the world
and undo/redo snapshots; no mutation is allowed. Coverage includes
all twelve rim panels, the core, guards, ramp, graded landing, exposed supports,
roof occlusion, two shared-template building instances, locked inspection,
chunk replacement, unloading/reframing and out-and-back pointer drags.

The legacy interior worker and desktop/phone journey also pass in
`build/logs/groundwork-picking-interiors-project-01.log`. Its added regression
selects a parent and changes the camera without replaying the previous item ray.
The complete supported-building desktop/phone journey passes in
`groundwork-picking-supported-project-01.log`, including all seven shells,
the keep walking circuit, retained shelf contents and saved-world restore.

The independent critic found stale/cancelled pointer dispatch, region-drag
misclassification, a four-corner landing bound that missed a mesh vertex by
37.35 mm, and framing that could lose unloaded geometry. Corrections invalidate
pending rays at mode/import/cancellation boundaries, track maximum gesture
excursion, bound every 0.125 m landing vertex, and load the owning plot before
resolving a part's current bounds. Evidence under `build/critic/` includes
`groundwork-picking-source-review-01.md`, `groundwork-pointer-evidence-02.json`,
`landing-bounds-evidence-01.txt` and `visible-ray-evidence-02.txt`. The latter uses
actual Castle triangles, including reversed winding and double-sided material.

`groundwork-picking-visual-review-02.md` and
`groundwork-picking-outline-review-03.md` retain independent image review. The
critic measured approximately two CSS pixels on desktop and DPR2 phone after
camera-aware stroke scaling, but still found weak contrast against concrete.
Release build `build/logs/groundwork-picking-build-09.log` corrects it with separate
light and dark contours and fixed display ink after fog/tone mapping. Focused
actual selection and overhead/oblique captures pass on desktop and DPR2 phone at
both hosting paths: `groundwork-outline-root-09.log` and
`groundwork-outline-project-09.log`. Their complete results are preserved as
`build/groundwork-outline-{root,project}-evidence.json`; `outlineOnly: true`
distinguishes these focused checks from the full selection journey above.

General editor regressions also pass on build09 at both hosting paths:
`build/logs/groundwork-picking-web-{root,project}-09.log`. They exercise actual
Castle startup, world creation, the castle brush, desktop region dragging and
undo/redo, all four cameras, the edit toggle and phone action widths. Dependency
checks and 32 Pascal audio-worker protocol checks pass; these protocol checks
do not assess soundtrack quality. Complete reports are preserved as
`build/groundwork-picking-web-{root,project}-evidence.json` with no page or request
failures.

The critic independently closes the concrete-edge contrast finding with actual
dark (9,17,19) and gold (250,219,133) pixels and visible landing rail occlusion.
Its native Castle oracle passes 9,811 checks covering 24 reused edges across
nine widths and three offsets, contour separation, geometry outside the selected
bounds, disabled shadows, ray/sphere/box exclusion and component cleanup.
Evidence is `build/critic/outline-native-evidence-04.txt` and
`groundwork-picking-outline-review-04.md`. Full feature grades remain pending; this evidence
does not pass the product gate.

## Critic workflow revalidation

The independent reviewer rechecked the full existing workflow scope after the
publishing and CI inputs changed. `reviews/critic-workflow-04.json` awards
intuitiveness A-, accuracy B+, wow factor B+ and thinking out of the box B+,
assessed as developer tooling. All nine declared inputs have current fingerprints.
The critic independently rebuilt the checker and passed all 26 regression cases,
rejected both report-path traversal probes, and executed the extracted CI guard
with success, failure, cancelled, skipped and empty outcomes. Only success exits
zero. Evidence is retained under `build/critic/workflow-04-*`.

The real gate now passes `critic-workflow` and holds the other seven features.
This renews acceptance of the review mechanism only. It does not approve world
creation, visuals, performance, audio or publishing, and no hosted deployment
result is claimed. Previous critic reports remain retained.

## Nested contents and food on plates

The generic contents adapter now admits complete supported assemblies through
explicit catalog profiles. Native and executed browser Pascal pass 911 checks:
63 document, 252 contents, 528 nested assembly and 68 wire checks. Evidence is
`nested-contents-native-06.log` and `nested-contents-composition-browser-04.log`.
The non-food fixtures cover case/tray/specimen/support/badge hierarchies,
rotations, overhang, sibling overlap, unknown geometry, ownership, locks,
explicit removal/movement, failed output preservation and saved-ID limits.

The independent critic found two candidate-domain omissions: generated support
IDs could collide with existing nodes or exceed the ID limit, and could also
collide with a second requested root that had not yet been created. Both were
fixed before WFC candidate admission. The independent final probe passes 64
deep transform cases, 15 contact/separation cases and 192 candidate solves in
native Pascal and executed pas2js. The failure history and source fingerprints
are retained in `build/critic/nested-contents-correctness-review-02.md`.

The production profile adds two plate appearances and six individual food
definitions. Independent native CGE measurements admit all six food envelopes
and their bottom contact. A 13,689-ray sweep of the usable 116 mm square matches
the plate's 6 mm inner contact within 0.000006 mm. This exposed a pre-existing
3 mm gap beneath the plate; an underside foot now reaches zero while retaining
the inner support height. The original and corrected geometry evidence remains
under `build/critic/food-native-evidence-*.txt`.

`nested-contents-web-build-06.log` records the successful release web build.
The full journeys in `nested-contents-interiors-root-06.log` and
`nested-contents-interiors-project-06.log` passed
33 worker seeds, independent item edits, parent-appearance and surrounding-table
preservation, exact food/plate counts, descendant locks, malformed contact and
geometry rejection, old-save restore, and second-room isolation. Actual desktop
and phone journeys passed food picking, elevated framing, appearance changes,
count removal, undo, explicit preparation of a legacy leaf plate, protected
plate appearance controls and editable sibling food. A count
action initially changed neighboring cheese appearance; count requests now pin
surviving assets and permit vacancy only for the explicitly reduced category.

The critic's visual findings also led to a recessed apple crown, herb/rind detail
and short corner brackets. Initial brackets became subpixel on phones; the final
version targets two CSS pixels from the actual camera and viewport. Independent
CGE checks verify 336 edges across seven widths, reuse of all 48 shapes,
unchanged physical bounds/picking and the 4% resize tolerance. Current phone
and desktop screenshots show the corrected feedback; earlier failed review
images and grades remain in `build/critic/granular-interiors-corrective-review-*.md`.

The 541,199 native and browser groundwork checks also pass with the populated plate
hierarchy (`nested-contents-groundworks-native-03.log` and
`nested-contents-groundworks-browser-05.log`). Screenshots and the
journey results are retained in `build/interior-plate-*.png`,
`build/interior-fruit-*.png` and
`build/nested-contents-interiors-{root,project}-evidence-06.json`. The broader room,
route, catalog and streaming requirements remain unfinished. The release gate
remains held for the full product.

The final supported-building project-path regression also passes on desktop and
touch phone (`nested-contents-supported-project-06.log` and
`build/nested-contents-supported-project-evidence-06.json`). All seven shells,
keep walking, supported cabin furnishings, retained nested records, support and
panel edits, incompatible shell rejection, building removal/undo and exact
restore completed with no page/resource errors. This extends the earlier
support-path evidence to the populated plate hierarchy and final renderer.

The independent final review is `reviews/granular-interiors-03.json`. It retains
the complete previous studio scope and explicitly adds nested plate/food
assemblies and lock-aware parent/content edits. Intuitiveness, accuracy and wow
factor each receive B+; thinking out of the box receives A-. All 56 declared
input fingerprints match, and the actual Pascal checker accepts the report.
Earlier visual failures remain in `reviews/granular-interiors-02-history.md`.
This passes the expanded studio workflow, while the overall world and audio
requirements remain held.

## Local room floor adapter checkpoint

The new `phanes.spaces.floor.*` adapter solves complete multi-cell fixture
footprints, instance quotas, rotated operating fronts, connected standing space,
service/height eligibility and preserved floor placements. It validates decoded
physical envelopes and swept player clearance independently before publishing a
result. It is not yet connected to named bays or bathroom/laboratory creation in
the browser; the full `named-room-programs` registry scope remains pending.

The final Castle/WebAssembly and pas2js release build passes in
`build/logs/floor-web-build-05.log`. Native and executed browser Pascal each pass
4,867 checks: 564 builder checks and 4,303 permanent independent critic checks
(`floor-native-run-05.log`, `floor-browser-run-05.log`). The browser suite from
that full build completed in 1,828 ms, recorded in `build/floor-browser-evidence.json`.
It includes actual solves at three structural work boundaries and a 60-second
browser watchdog. The app data archive remains 918 files, 16.11 MB uncompressed
and 5.77 MB compressed; no candidate room fixtures were added to the runtime catalog.

Independent source-model admission probes measured seven candidate furniture
models through Castle, 28 rotated assembly bounds and five contact sweeps.
The sloped consoles cannot offer a full flat work surface; the shower's closed
door and raised tray do not prove walk-in entry. These are retained admission
limits, not waived by an abstract room role or a free neighbouring cell.
The audit is `build/critic/named-room-feasibility-review-01.md`.

The critic found and retained early failures involving the meaning of one-object
geometry and the shared quarter-turn convention. It also exposed a severe rule
construction cost: repeated `NewRule` calls synchronize the whole inverse-rule
graph. The corrected adapter uses the existing public bulk rule API with detached
reciprocal arrays and explicit deny-all semantics. No dependency change was needed.

In independent desktop Chromium workers, the optimized compact bathroom and lab
fixtures resolve in 15–43 ms and 19–32 ms respectively. The largest tested token
case resolves in 232 ms, after the original native implementation was stopped
above 143 CPU seconds. Six seeded cases retain identical placements, every
free-floor flag and decisions/propagations/backtracks across pre-optimization
native, optimized native and optimized Chromium implementations. Evidence is in
`build/critic/floor-after-chromium-evidence-11.json`,
`floor-nearlimit-chromium-evidence-09.json` and `floor-exact-equivalence-11.json`.
These measurements exclude CGE rendering and do not establish phone performance
or the unimplemented named-room UX. Whole-product acceptance remains held.

The critic renewed the unchanged studio and workflow scopes after inspecting
their test-orchestration-only deltas: `reviews/granular-interiors-04.json` and
`reviews/critic-workflow-05.json`. The actual checker accepts both reports and
their current fingerprints (`build/logs/floor-final-gate-05.log`); all seven
other feature holds remain, including the full named-room program requirement.
All 26 critic-checker regressions also pass
(`build/logs/floor-review-checker-tests-05.log`). Prior reports and failed floor
probes remain retained. No upstream branch, dependency pin, commit or deployment
was changed during this checkpoint.

## Explicit volumes and named-room document operations

The new composition volume contract and room/plan bridge are described in
[COMPOSITION_FORMAT.md](COMPOSITION_FORMAT.md) and [ROOM_PROGRAMS.md](ROOM_PROGRAMS.md).
This checkpoint supplies document operations; the preview still uses the studio.

- Release Castle WebAssembly and all pas2js targets compile with `-WithTests`
  (`build/logs/spaces-web-build-14.log`). The existing 918-file data archive
  remains 16.11 MB uncompressed and 5.77 MB zipped; the new fixture sources
  already belong to the pinned imported kits.
- The combined room suite passes 1,119 builder checks plus 505 independent
  critic checks natively, and 1,119 plus 513 in Chromium. The complete browser
  suite takes 45.24 seconds; that is a regression-suite duration, not a
  per-operation performance claim. Logs are `spaces-native-run-14.log`,
  `spaces-browser-run-14.log` and `build/spaces-browser-evidence.json`.
- Existing composition checks pass 963 assertions on each runtime, including
  52 new explicit-volume assertions. The independent extent audit at its
  recorded hashes passes 4,296 native and 4,303 browser checks. It verifies
  transformed/odd-sized volumes, v1/v2 rejection and retention, whole-world
  rejection of dimensions on implicit profiles, and conservative locks.
- Generic floor checks pass 4,867 on each runtime. Groundwork geometry and
  composition checks pass 541,199 on each runtime. Logs use the
  `spaces-composition-*`, `spaces-floor-*` and `spaces-groundworks-*` names
  under `build/logs/`.
- The existing studio worker, nested item, lock, restore, undo, camera and
  pointer journeys pass on desktop and phone at both root and project-path
  URLs. Evidence is `build/spaces-studio-root-evidence-12.json` and
  `build/spaces-studio-project-evidence-12.json`; both report no browser errors.
  The resulting desktop room and phone Shelf 4 images were inspected.

Independent review retained two pre-fix ID failures: unrelated nodes could own
a generated root or future support ID, causing late rejection despite a legal
alternative layout. Reserved root namespaces now constrain WFC before solving.
The critic also found that substring tests could misinterpret opaque room IDs
as shelf numbers; exact support identities now determine initial contents.
A failing browser fixture was traced to the pinned compiler's record
`for ... in` alias behavior and corrected using indexed copies.
The permanent critic unit is `tests/phanes.tests.spaces.critic.pas`.

The bounded report and source fingerprints are
`build/critic/program-room-plan-correctness-review-01.md` and its adjacent
reviewed-inputs JSON. Shell/portal feasibility evidence is in
`build/critic/six-bay-feasibility-review-01.md`: it rejects a 3950 mm bay depth
that overlaps window trim, and validates the reduced 3900 mm proposal.
These are core/geometry audits, not passing product grades.

All nine registered feature gates currently hold after the changed source and
CI inputs (`build/logs/spaces-final-gate-14.log`). The checker itself still
passes all 26 regressions. Prior reports remain intact; no grade was rewritten.
The next integration must admit plan ownership in whole-world validation,
publish scoped worker actions, render and navigate the actual partitions and
portals, and provide desktop/phone room creation and granular selection.
Arbitrary resizing, modular walls, routes/streams, landform generation, broad
catalog coverage, audio development and the remaining full objective stay open.
Dependency pins remain unchanged. No upstream edit, commit, push or deployment
was performed.

## Named-room worker and first rendered integration

Room programs now connect to whole-world admission, the real worker, a Pascal
controller and Castle partition geometry. `rooms-integration-web-build-03.log`
records the release build with all then-current browser test targets. The data
archive remains 918 files, 16.11 MB uncompressed and 5.77 MB zipped.

- Durable independent room integration tests pass 1,159 world and 10,071 wall
  assertions natively, and 1,163 world plus 10,071 wall assertions in Chromium
  (10.55 seconds). The browser-only difference covers world save/read. Logs:
  `rooms-integration-native-03.log`, `rooms-integration-browser-03.log`.
- Existing composition checks pass 963 assertions; the room document suite
  passes 1,119 builder plus 505 independent assertions natively. Groundwork
  checks pass 541,199. Logs use `rooms-composition-native-03`,
  `rooms-spaces-native-03` and `rooms-groundworks-native-03`.
- The actual root-host creation journey passes at 1440 × 960 and 390 × 844:
  six-bay layout, independent names, laboratory in Bay 5, shelf counts, single
  snail replacement, six books on a bench, bathroom neighbor preservation,
  export/restore, undo/redo, protected descendants, four/two-bay replacement,
  return camera and foundation-owned cabin entry. Evidence is
  `build/rooms-root-evidence-03.json`; images use `build/rooms-*.png`.

Independent early rendered review found two defects: shelf framing ignored
accumulated bay/furniture turns, and secondary controls hid the main purpose
action on phones. The current controller frames through the support hierarchy;
purpose now precedes secondary controls, with naming collapsed and layout at
the interior root. Updated builder screenshots show all three Shelf 4 books
and immediately visible phone purpose controls. The critic's initial doorway
walking and floor/furniture picking checks pass; its complete revised camera,
navigation and visual review remains in progress. The complete project-path
journey subsequently passes both viewports (`rooms-project-journey-04.log`,
`build/rooms-project-evidence-04.json`), including two additional cases: rejected
blank naming and synchronous cancellation of a started room worker preserve
both the scene revision and undo history. Legacy studio compatibility remains
to be recorded for this revision. No feature grades are inferred from these
test results.

The new independent tests are `phanes.tests.spaces.world.critic`,
`phanes.tests.spaces.walls.critic` and their separate integration driver.
They are wired into native/browser CI alongside `test-room-journeys.cjs`.
All nine feature gates still hold at this checkpoint; dependency pins and prior
critic reports are preserved. No upstream changes or publication occurred.

The final release build (`rooms-integration-web-build-05.log`) includes the new
independent integration driver. Its root room journey passes 17 cases on both
viewports, adding studio/plan undo and redo that retain cabin context and exact
saved contents. The earlier project-path run covers the other 16 cases on both
viewports. Final evidence: `build/rooms-root-final-05-evidence.json`.

Existing studio regressions pass at root and project paths, including 33 seeded
worker layouts, nested plate/food and shelf edits, direct rays, locks, export,
restore and history. The full supported-building root suite passes all seven
shells, keyboard/touch traversal and interior preservation through compatible
deck/support edits on desktop and phone. Evidence:
`build/rooms-studio-root-05-evidence.json`,
`build/rooms-studio-project-05-evidence.json` and
`build/rooms-supported-root-05-evidence.json`. All report no browser errors.

The independent revised rendered audit also verifies a fully furnished
six-laboratory plan: 18 furniture roots and 123 composition nodes without page
or shader errors. All four composed shelf facings and 12 individual book rays
pass; a phone/DPR2 tap selects a framed book. Actual touch-pad movement follows
the corridor, responds to the doorway jamb and enters Bay 5 at eye height
1.68 m. Evidence and retained initial failures are in
`build/critic/rooms-ui-correctness-review-01.md`,
`build/critic/rooms-ui-correctness-review-02.md` and their adjacent captures.
The final gate report records the feature's grades separately from the wider
world, architecture, catalog and audio requirements that remain unfinished.

The final independent report is
[named-room-programs-02](../reviews/named-room-programs-02.json): B+
intuitiveness, B+ accuracy, B+ wow factor and A− thinking out of the box.
All 76 declared input fingerprints match the current source. The checker accepts
this feature and retains all eight other holds
(`build/logs/rooms-final-gate-detail-05.log`); its 26 regression checks pass
(`rooms-final-gate-tests-05.log`). The failed initial review remains under
`reviews/named-room-programs-01.json` and its narrative. Minor phone scrolling
for the final purpose option and some dark book faces are recorded refinements.
No prior unrelated review was renewed, no goal was narrowed, and no dependency
change, commit, push or deployment occurred.

## WFC terrain kernel checkpoint

The new `phanes.terrain.*` core solves shared elevation vertices with cardinal
rise limits, caller intervals and exact protected/boundary preservation. Its
immutable triangle sampler supplies clipped height and one-sided gradient
bounds. The playable world still uses analytic elevation; save-format,
groundwork-provider, rendered-grid and player-control integration remain open
under the complete `terrain-landforms` feature scope in the registry.

Final kernel driver evidence is `build/logs/terrain-native-11.log`,
`terrain-wasm-11.log`, `terrain-browser-11.log` and
`build/terrain-browser-evidence.json`. Native Pascal and FPC WASM each pass
63,686 builder checks plus 24,637 independent critic checks. Chromium passes
63,686 plus 24,665, including its runtime type/record guards. Exact solved
height sequences match across all three targets. The WASM tests execute the
compiled Pascal program through Node WASI, not through translated JavaScript.

The critic's permanent `phanes.tests.terrain.critic` unit covers an independent
clipped-polygon extrema/gradient oracle, extreme admitted coordinates and
slopes, grid/diagonal creases, full boundary-surface preservation, mutable array
ownership, aliased success/failure, unchanged metadata, malformed nested
records, the 97×97 singleton limit and 65-level replay. The initial grid-crease
underbound and unchanged-result seed/counter mutation were reproduced and
fixed. Retained design and probe evidence is under `build/critic/terrain-*`.
The bounded final audit is `build/critic/terrain-kernel-review-01.md`; its
negative control correctly fails the retained pre-fix crease implementation.
An extra WASM replay check exposed a target-sensitive arithmetic expression in
the test's rolling fingerprint; actual solver heights already matched. The
fixture now compares the complete exact integer sequence instead.

The benchmark (`terrain-bench-native-01.log`, `terrain-bench-browser-02.log`,
`build/terrain-bench-browser-evidence.json`) solves 289, 1,089, 2,401 and 9,409
vertices with progressively larger elevation domains. The largest 65-level,
two-level-rise field took 4,391 ms in optimized native Pascal and 5,833 ms in
Chromium on this workstation. A 9,409-vertex unrestricted-rise case took 868 ms
in Chromium. These measured seeded cases use no backtracks; they are not
guarantees for every request, browser or full game frame.

The Castle release build with tests passes
(`terrain-kernel-web-build-07.log`). Its desktop/phone root startup, dependency,
audio-protocol and interaction checks pass
(`terrain-kernel-root-web-07.log`, `build/terrain-kernel-root-evidence-07.json`).
Later changes were confined to the standalone kernel, tests, orchestration and
documentation; the final native, pas2js and WASM driver builds are recorded
above. All three terrain check paths are wired into CI.

The critic gate regression suite passes all 26 cases
(`terrain-kernel-gate-tests-08.log`). All ten full feature gates currently hold:
terrain is pending integration and review, and the earlier named-room report
requires renewal because its shared build/CI inputs changed. The original
named-room grades and reports are retained. No terrain feature grades, product
completion, upstream dependency change or publication are claimed here.

## Terrain integration and rendering checkpoint

The terrain adapter, protected local height edits, contact geometry, selection,
cancellation and saved-session integration now have native and browser evidence
recorded in [TERRAIN.md](TERRAIN.md). Release build16 succeeds without compiler
warnings or errors (`landforms-web-build-16.log`); the final builder editing and
recovery journey passes 42 assertions (`landforms-browser-22.log`). Native
batching checks pass 54,239 assertions, and the retained critic shadow-geometry
probe passes 138,394 when rerun against the bounded static cache. These are
bounded checks, not full product acceptance.

The populated size-eight fixture in `build/batch-browser-10` measures 24.41 fps
desktop Orbit and 44.47 fps phone-layout first person, with visible shadows and
no recorded renderer errors. Forced graphics recovery preserves its exact saved
world and resumes rendering. The device is still the development GPU; physical
phone performance and the final independent cache review remain outstanding.
The critic's review stopped at a usage limit after leaving its native probe.

All 26 synthetic critic-gate regressions pass (`landforms-gate-16.log`). The 15
registered feature gates still hold for pending, rejected or stale reports;
no grades were changed or bypassed. The engine and WFC submodule pins remain
unchanged. No publication or full objective completion is claimed.
