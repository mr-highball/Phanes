# World creation architecture

## Runtime ownership

Castle Game Engine owns the window, viewport, camera, scene loading and rendering.
FPC compiles `cge/code/phanes.app.*` to WebAssembly. Phanes' Pascal host uses the
pinned WASI/JOB APIs to start it with visible startup progress and errors; see
[STARTUP.md](STARTUP.md).
The HTML overlay owns input and presentation. `phanes.editor.js` sends requests
to a dedicated worker running Pascal compiled by pas2js.

`src/phanes.world.types.pas` defines portable world/request types.
`phanes.world.generate` builds and solves the WFC graph; `phanes.world.validate`
checks decoded support/placement contracts independently. `phanes.world.wire`
checks browser input shapes and encodes messages. `phanes.worker.lpr` is the
worker entry point. Source files use dotted, lowercase Phanes namespaces.

## Current five-pass graph

[MODULAR_HOUSING.md](MODULAR_HOUSING.md) describes the separate world-space
construction adapter: two-metre floors and shared wall/window/door edges, followed
by local furniture and nested support graphs. It shares the exterior viewport,
terrain, collision, history and saved composition. The following regional graph
continues to serve broad terrain/ecology changes and imported building shells.

| Pass         | Cell pitch | Values and dependency                                                             |
| ------------ | ---------- | --------------------------------------------------------------------------------- |
| Terrain      | 8 × 8      | Meadow, forest, water, field, stone; shoreline adjacency                          |
| Architecture | 8 × 8      | Empty, cabin, castle, modern, sci-fi; dry terrain support                         |
| Ecology      | 4 × 4      | Empty, tree, shrub, flowers, rock, wheat; terrain and complete building clearance |
| Buildings    | 8 × 8      | Real asset/prefab IDs mapped to architectural roles                               |
| Vegetation   | 4 × 4      | Real asset IDs mapped to ecological roles                                         |

WFC's integer mapped-pass API relates resolutions in a common coordinate system.
These pitches are logical lattice units. The current renderer maps a regional
cell to 16 metres and an ecology cell to 8 metres. Finer future container graphs
require explicit units and transforms, not reuse of this coarse cell size.
The current graph is a regional plane with depth one, rendered as 3D geometry.
It is not yet the volumetric, nested modular building generator required by the
full objective. The cabin shell, keep/rocket assemblies and small plant clusters are authored
recipes, clearly distinguished from the actual WFC decisions.

A new request constructs a fresh graph. Outside a selected region, every pass
gets the previous value as an exact caller domain. Inside it, the intent changes
allowed domains. The solver stages the complete result; the independent validator
checks it before it leaves the worker. The UI accepts only the current job ID.
Cancellation terminates that worker. Rejected/cancelled requests preserve the
visible baseline. Undo/redo swaps validated snapshots, and restore validates
saved layer arrays without re-generating their contents.

[AUTHORING.md](AUTHORING.md) defines nonrectangular masks, camera-bound gestures,
layer scope and category/group/exact-item requests. The portable selection mapper
sets caller domains; a separate decoded-edit validator checks exact preservation.
Fine foliage masks never authorize changes to a coarse terrain or building cell.

The first implementation uses ordinary bounded WFC search. Prepared workspaces,
scoped graph reuse, upstream negotiation, learning, quotas and connectivity must
be added where they serve the nested creation workflows. Do not claim they are
already in use simply because the dependency supports them.

## Required granular composition

[GRANULAR_COMPOSITION.md](GRANULAR_COMPOSITION.md) defines the required layer
systems, local container hierarchy, catalog admission contracts and end-to-end
acceptance examples. Stable instance IDs, named bays/rooms, furniture support
surfaces, shelf tiers and independently editable contents cannot be represented
by adding more values to the five regional arrays. This hierarchy requires a
deliberate versioned world format and worker/editor/renderer integration.
World format 2 and the first cabin studio integration now provide this path for
measured shelves, tabletop surfaces and nested plate/food supports; see
[INTERIORS.md](INTERIORS.md). Its Pascal controller, local furniture/content
graphs and CGE cutaway do not yet supply arbitrary building interiors.
The shared contents adapter uses explicit support profiles and complete transformed
assembly envelopes. The world validator rechecks ancestor reservations after
child edits; optional profiles preserve compatibility with older leaf props.

The current unintegrated room prototype is a fixed dining layout; it is not
evidence for arbitrary room programs or item-level creation in the browser.

The separate `phanes.spaces.floor.*` adapter now solves complete furniture
footprints with role quotas, declared operating fronts, preserved placements
and player-clearance validation; see [FLOOR_PLACEMENT.md](FLOOR_PLACEMENT.md).
The new `phanes.spaces.programs`, `phanes.spaces.rooms` and
`phanes.spaces.plans` bridge connects it to named bay/room documents and finer
furniture contents; see [ROOM_PROGRAMS.md](ROOM_PROGRAMS.md). Two-, four- and
six-bay cabin scaffolds and bathroom/laboratory programs connect through
`phanes.spaces.world` to whole-world admission and worker publication.
`phanes.spaces.geometry` supplies shared authored wall/portal rectangles for
the cutaway/full-height meshes and player collision. The Pascal interior
controller supplies layout, purpose, naming and finer contents controls.
Named-room desktop/phone review evidence is retained; shared runtime changes
require renewed acceptance. Arbitrary resizing, modular enclosures and broader
world generation remain open.

[GROUNDWORKS.md](GROUNDWORKS.md) documents the explicit plot/deck/support hierarchy.
Its worker stages regional clearance and local WFC material generation in one
transaction. A Pascal controller selects individual parts; Castle renders the
support geometry and distinct soil/standing surfaces. Seven measured static
shells attach through explicit deck ownership; a cabin can retain its studio
and contents through compatible support edits. Terrain grading and support shapes
are admitted authored recipes; the material graph supplies the WFC choices.

## Asset and rendering boundaries

`data/kits.lock.json` and `asset-inventory.json` track 8,365 glTF/GLB files
from 108 CC0 kits/collections: 7,116 original exports and 1,249 explicitly derived
OBJ/MTL models with pinned Pascal conversion evidence. Explicit dependency aliases
repair original export paths while preserving model and texture bytes.
The original six remain in the startup archive; 102 optional kits
live outside it and have separate content-hashed web packages. Admitted optional
objects now load through the staged publication and retained-source contract in
[CATALOG_PUBLICATION.md](CATALOG_PUBLICATION.md). Broader category admission remains
open; see [CATALOG_EXPANSION.md](CATALOG_EXPANSION.md).
`data/palette.json` admits the current regional choices and
records prefab composition. Most inventory remains unreviewed for generation.
See [ASSETS.md](ASSETS.md) for provenance and remaining compatibility work.

The renderer loads each raw model and assembled template once, then places
`TCastleTransformReference` instances. It normalizes standalone assets from
CGE scene bounds to the declared footprint and applies the current metre scale.
Detailed chunks now consolidate eligible static foliage into material groups.
This cache bakes the existing placement geometry, explicit UVs and normals;
it does not add WFC decisions or change saved ownership. Complete static
material fields, resolved texture URLs and vertex layouts govern sharing.
Unknown effects, changed visibility/shadow flags, generated texture coordinates
and unsupported normal-map transforms keep their original scene path. The
authored cabin also combines opaque trim boxes while retaining its glass,
named doorway measurements and collision geometry. Both paths preserve source
surface-grain coordinates and continue to cast and receive shadows.
Physical base colors are stored per vertex, allowing matching materials to
share a draw without losing authored colors. Cabin vertices retain their
untinted color while the shared material receives the current world tint.
Models whose shadow closure spans material parts retain their source grouping
in a separate batch. A static foliage shadow cache is under review: it retains
directional-light silhouettes and caps in GPU buffers while CGE still performs
per-frame caster visibility, stencil configuration and cap selection. Geometry,
light or transform changes and GL context closure invalidate those buffers.
The optional cache admits at most 16 MiB of vertex data across resident scenes,
with a separate 16 MiB bound on temporary geometry/facing data. Wide preflight
arithmetic and fixed capacities precede temporary allocation. CPU geometry is
released after upload; a scene exceeding the cache budget uses the ordinary
engine path before any of its stencil geometry is drawn.
Fresh terrain is a WFC field of shared height vertices, rendered as indexed
triangle chunks with diffuse/normal maps and biome tint. The Pascal world
adapter applies local height intents and protects unselected surfaces, occupied
support, water and plants. Versioned persistence preserves legacy analytic
worlds through an additive edit field. `phanes.world.height` shares height,
range and gradient queries with construction and landscape admission.
Shoreline and building-pad blends remain authored geometry. Rendered contact,
LOD compatibility and the complete player journey still require the independent
terrain feature review; [TERRAIN.md](TERRAIN.md) records its limits and evidence.

Chunk signatures retain unaffected geometry across edits. The renderer admits
one chunk build per frame with at most nine detailed resident chunks plus a
staging chunk. Distant chunks currently contain terrain only. Plot-bearing chunks
retain their contact terrain mesh even when their props are distant. Assets still load
from the upfront Castle data archive for core models. Admitted optional models
are prepared before publication and pinned by the complete active world, including
distant chunks. This is per-model loading; chunk detail still follows the existing
camera streaming policy.
Large-world frame/memory budgets and visible distant landmarks remain required.

Walking uses a 1.68-metre eye height, substepped ground movement, slope/water
checks and conservative closed exterior collision proxies. It does not yet
provide enterable doorways or rigid-body physics. The authored cabin has a
separately measured doorway; other exterior models need doorway admission.
See [STRUCTURES.md](STRUCTURES.md) for normalized bounds, collision contracts,
dry datum constraints and the remaining groundwork requirements.
Groundwork picking follows the nearest rendered face and resolves its placed
composition ID; the graded landing uses the nearest actual terrain hit. Regional
drag selection retains its height-surface query. Shared visible-ray filtering
also serves interior object selection. Dynamic batching, ACES tone mapping, sun/fill
light and fog are enabled. SSAO is disabled because the tested WebGL path rejects
its framebuffer format.

A separate four-cell WFC solve chooses a valid shared palette, key light,
atmosphere and finish. `appearanceSeed` is preserved across regional edits and
is optional in older snapshot-v1 input, defaulting to the saved seed. Shared
runtime material treatment applies across all themes. The visual quality gate
remains held; a common tint and surface grain alone do not establish the desired
stylized forms with realistic detail.

Browser assets and Castle data are hosted in `build/web/`; there is no runtime
CDN or server API. Generated optional CacheStorage access is guarded for LAN
HTTP. Git submodules remain unchanged at their initial reviewed pins.
