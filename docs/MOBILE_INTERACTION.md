# Mobile creation and playback

Pascal owns the movement-pad state, held keys, normalized flight movement,
mode changes, drawer visibility and adaptive canvas sizing. Browser glue keeps
the existing world-worker and Castle host contracts. Fly and First person share
the movement pad; Fly adds independent Rise and Descend touches. Release,
pointer cancellation, focus loss, camera changes and covered dialogs clear held
movement. Escape returns keyboard focus to the Tools control; Shift+Tab remains
available for normal traversal. Focused movement buttons accept held Space or
Enter, in addition to WASD/QE. Released pointer IDs are removed immediately so
input polling does not grow with the length of a touch session.

First person uses a 95-degree field of view on the larger viewport axis, so
portrait screens do not expand the vertical view beyond that angle. Other camera
modes retain their existing projection. Initial portal-room entry looks slightly
below the horizon (pitch -0.12 radians); restoring a saved room retains its pose.

The Tools control hides or reopens the creator drawer without changing the
camera or Create/Explore mode. Entering Explore initially hides it. Reimagine,
Clear and generation requests are blocked in Explore. Zoom controls only appear
in cameras that use zoom. Short landscape layouts retain a scrolling side drawer.
The mobile action layout keeps Clear, Undo and Redo available; the former
responsive rule that hid them is overridden by the authoring layout.
The phone Tools drawer also exposes **Export world**, including while exploring,
inside a house and in the groundwork tools. The common action stays at the top
when those specialized panels hide exterior authoring controls. Recovery-storage
warnings therefore lead to a reachable portable save action.

Balanced rendering starts with a maximum 2 device-pixel ratio for the 3D
buffer and adapts down to 1.5 after sustained slow frames. Ratios never exceed
the screen's native density. Smooth limits it to one; Detail
uses the device's full ratio. DOM controls retain their full resolution.
Castle rendering and chunk work pause while the opaque music dimension covers
the world. Generation already runs in dedicated Pascal web workers; the pinned
Castle renderer remains on the main thread.

The regional outline now uses one indexed terrain-following ribbon instead of
one box per metre. Idle walking avoids repeating the same contact/camera update,
and chunk metrics cross the browser bridge only when their values change.
Scene frustum culling and dynamic batching remain enabled. Broader placement
LOD, resource ownership and physical-phone performance remain under review.

Tempo changes preserve the active track and worker. Unsounded voices are
rescheduled at a bar boundary; sounding envelopes and echo tails continue.
An imminent committed change finishes before a newer request takes effect.
When a faster tempo needs more sections to retain at least five minutes, WFC
must admit the extended form with its composed prefix fixed before playback is
retimed. A final landing already composed or being generated keeps its tempo
until the following track if retiming would make it too short.

## Verification

The affected physical phone confirmed startup now loads after the part-transfer
fix documented in [STARTUP.md](STARTUP.md). Subsequent phone feedback identified
black surfaces, missing house traversal, a renderer failure after minimizing,
and low image sharpness. [RENDERER_RECOVERY.md](RENDERER_RECOVERY.md) records that
separate repair and its remaining physical-device acceptance.

Use `tools/test-mobile.ps1 -Browser <Chromium> -TestUrl <preview>`.
Both the driver and browser instrumentation are Pascal, using pinned WFC CDP.
The latest complete run in `build/mobile-controls-10` passes 48 checks. It covers
touch Fly and actual first-person traversal, forward/back/strafe/diagonal input,
release, focus loss and camera changes while held, focused Space and WASD,
active-pointer cleanup, drawer recovery and Explore edit guards. Rendered and
hit-tested layouts include 390-pixel and 360-pixel portrait and 640 × 360 landscape;
Rise remains usable beside the open drawer. It also checks high-DPR settings,
covered-world draw suppression and rapid BPM changes with a stable track/worker.
The 5.6-second audio trace records no late events, dropped voices or underruns.
This is desktop GPU touch emulation, not measured physical-phone FPS or a
listening-quality certification. `build/logs/mobile-renderer-build-09.log`
records the latest successful Castle release build with checks. The recovery
notes record the focused controller/worker compiles and renderer checks.

Native `tests/phanes.tests.tempo.lpr` checks 999 form extensions against fixed
composed prefixes, independently enumerated phase transitions and duration.
It does not replace browser timeline, rejection, memory or audible-peak checks.

The new Pascal authoring controller adds explicit selections in every view,
brush/lasso masks and category-to-item browsing with a separate Apply action.
[AUTHORING.md](AUTHORING.md) describes its current contract and evidence, including
the difference between exact layer-array preservation and physical shoreline
grading. Expanded optional catalog placement, broader rendered/lifecycle checks
and physical-phone performance remain part of the world-creator goal. No overall
mobile/performance/audio pass is claimed by these intermediate checks.
