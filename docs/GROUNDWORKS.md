# Groundwork implementation

The Pascal domain adapter now connects to the world worker, editor and Castle
renderer. Players can place a foundation or launch pad, inspect its parts,
reimagine individual rim panels, exchange its support structure and walk onto
the deck. Building attachment and retained interior descendants remain pending;
the full groundwork feature has not passed the independent critic gate.

## Physical profile

The first version uses a selected 2 by 2 regional plot (32 by 32 metres), a
16-metre square deck, a 2-metre-wide, 6-metre-long access ramp and a 2-metre
graded landing. Plot origins can be any regional cell; the central plot in a
4 by 4 world is valid. Stored transforms and heights are integer millimetres.
Quarter turns follow Castle's positive rotation about the up axis.

`phanes.groundworks.geometry` checks a conservative continuous terrain envelope.
The deck is 200–201 millimetres above its upper bound. The substructure extends
100–101 millimetres below the lower bound; exposed height is limited to 4.5
metres. These are authored game geometry limits, not an engineering certificate.
The profile currently requires a clear, dry regional border and cleared ecology
inside the selection. This restriction ensures the input field is the actual
unmodified analytic terrain through the player approach. Existing composition
plots and building roots also receive conservative overlap/apron checks.

Every ramp direction is checked against a maximum grade of 0.6 and maximum
excavation of 0.5 metres, including the slab underside. The complete landing and
0.28-metre player apron must stay above the standing threshold. Bounds use sine
intervals over rectangles, including interior extrema; dense test samples are
regressions rather than the proof used for admission.

The ramp ends at a planar toe. The landing blends that toe to the original
terrain with a smoothstep across its last two metres. Every point on the outer
edge matches the terrain's value and derivative. Analytic derivative bounds
include longitudinal and lateral grade. Side edges still need rendered retaining
faces and complete player-footprint admission; continuity at the outer edge
alone does not prove navigation. The deck does not silently level the soil below
it. Separate surface and soil functions expose that distinction for integration.

## Persistent parts and actual WFC choices

`phanes.groundworks.assembly` encodes the following in the existing versioned
composition document. New profile IDs end in `.v1`; they do not change the generic
node wire format or make existing world import automatically admit the profiles.

| Part         | Ownership and contract                                                           |
| ------------ | -------------------------------------------------------------------------------- |
| Plot         | Stable world child at the selected plot centre; foundation or launch-pad purpose |
| Deck         | Stable surface owned by the plot; complete 16-metre support boundary             |
| Substructure | Editable deck child; plinth or piers with identical deck datum and coverage      |
| Ramp         | Deck child with both its origin and frame rotated toward the selected approach   |
| Landing      | Ramp child; its local height records the toe's drop from the deck                |
| Core plate   | One continuous 8-metre square object, despite reserving four graph cells         |
| Rim panels   | Twelve independent 4-metre panel objects with persistent IDs                     |

The WFC graph has 4 by 4 cells in the deck frame. Its actual choices are rim
materials: stone, concrete, ceramic and steel. Authored adjacency requires a
concrete or ceramic transition between stone and steel; a quota keeps 2–10 rim
panels different from the core. Foundations use a concrete core; launch pads use
a ceramic core. Theme is not an input. The uninterrupted central plate avoids
putting seams through the current rocket's cardinal foot contacts. Complete
building-footprint admission still has to be implemented before placing any
building on this surface.

The geometry, core, chosen approach direction and chosen substructure recipe are
authored/requested inputs, not claimed as WFC geometry generation. Search is
bounded at 2,048 backtracks and independently decoded material constraints are
checked before committing. Exhaustion is not proof of impossibility.

Creation stages a composition and uses the existing revision/lock transaction.
Reimagination freezes every unselected or protected panel domain. Changing the
support body does not rewrite its parent deck, core or other panels. Generic
dependency protection remains intact. Profile admission rejects missing parts,
unknown profiles, shifted cores, incorrectly rotated ramp origins, extra owned
objects and noncanonical world roots. All fields round-trip through the existing
composition codec. Region arrays are not modified by this adapter.

`ReadGroundwork` decodes one assembly. `ValidateGroundworks` independently checks
every recognized plot and rejects orphaned reserved profiles. Public creation
and reimagination run that whole-document admission both before and after staging,
so an edit cannot carry a malformed neighboring plot into a new revision.
Extreme coordinates and unknown enum values reject before arithmetic or catalog
indexing. Protected or immutable scopes reject explicitly. A one-panel edit
excludes the old material from its domain; any remaining unchanged result is
reported without publishing a revision or modifying the output snapshot.

## World transactions and controls

Worker operations `foundation` and `launch-pad` stage the selected 2 by 2 region
as cleared meadow, reconcile existing composition, create the local groundwork
and validate the complete world. The published transaction advances exactly one
revision, including when only one revision remains available. Outside regional
arrays and protected composition records remain unchanged. `groundwork` edits
an existing semantic object scope without regenerating regional arrays. Exact
restore admits these profiles; shifted, missing or orphan parts reject. Clearing
a plot requires its complete footprint and retains the lock gate.

The Pascal `phanes.groundworks.ui` controller runs alongside the interior
controller. **Foundations & launch pads** opens a 32 by 32 m plot selection,
with automatic or cardinal access and plinth/pier choices. A deterministic
terrain preview reports the approach; final placement also checks composition
and locks in the worker. The deck plan exposes twelve rim panels and one
continuous core. Reimagination and G target the selected part. Core/access
geometry stays fixed. Support buttons change only the body. Undo restores the
exact prior world. **Walk the approach** places the player at the landing's outer edge,
facing the deck; keyboard and phone pad movement use the same Castle navigation.

## Rendering, contact and residency

`phanes.groundworks.scene` builds original deck slabs, plinths or nine piers,
visible underside infill, solid ramp segments, retaining faces and rails. The
same shared material treatment applies as elsewhere in the world. The current
single-height movement model cannot enter underneath a deck; visible infill
communicates that boundary. Seven rail rectangles, including their square end
posts, are expanded by the player radius for collision.

The landscape caches decoded assemblies and regional cell owners. Walking uses
the deck/ramp/landing surface; terrain uses distinct soil beneath the ramp.
Chunk signatures include every rendered assembly field, so local finish/support
edits invalidate affected geometry and preserve distant chunks. Cut soil has
separate patch-edge vertices. Curved landing and retaining edges use 0.125 m
subdivision, with a 2 mm measured contact target.

Plot-bearing chunks retain their metre terrain grid and landing subdivision even
when their props are distant. This keeps a plot crossing chunk boundaries coherent
when its complete support scene lives in a detailed origin chunk. It adds distant
terrain vertices without increasing the nine detailed placement chunk limit.
Large-world memory/frame budgets and distant structural landmarks still require
validation. Asset network streaming remains unimplemented.

## Supported building ownership

Each plot can own one `site-X-Z.deck.building` container, with both parent and
support identifying its deck. The local position is exactly zero and the quarter
turn follows the approach. Seven explicitly measured static shells fit: cabin,
keep, two suburban houses, a sealed round module, a small habitat and rocket. Both plot purposes
admit them by physical fit. The shared `scifi` category does not decide whether
an asset is a rocket or habitat. These are authored prefabs; explicit placement
does not claim WFC-generated modular building geometry or rocket operation.

`place-building` and `remove-building` publish one atomic deck transaction.
Replacement preserves a custom name and rejects incompatible retained rooms.
Explicit removal still honors every descendant lock. A cabin may own its exact
studio subtree; the other six shells currently have no admitted interiors.
Support and panel edits preserve the entire building subtree, including locks.
The validator admits all descendants rather than skipping an owned plot wholesale.
Pure interior admission has no landscape dependency or recursive validation call.

The Pascal plot panel provides building choices and cabin furnishing/entry. The
Castle attachment uses the same normalized model templates as regional placement,
at the deck datum, without extra scaling or jitter. Collision and chunk signatures
include the attached shell. A conservative whole-model envelope reserves walking
space around the shell; these proxies do not represent open exterior doors.
Primary entrances use explicit model-facing offsets: keep 270 degrees, both
suburban houses 180 degrees, cabin and small habitat zero. The sealed round
module and rocket have no admitted entrance direction. Their offset stays zero.
Live normalized Castle bounds must remain within each reviewed support envelope.

## Selecting rendered parts

The creator resolves the nearest visible triangle to its placed composition ID.
An exposed panel, core, support body, ramp or attached building can be clicked
or tapped; the Pascal controls and a depth-tested outline share that ID.
Deck rails select the whole deck. Access rails select the ramp. The graded
landing resolves its actual terrain hit to `.deck.ramp.landing`; a nearer
building or other opaque object still occludes it. Panel numbering stays aligned
to world north when the approach and building rotate.

Shared model templates carry no placement identity: each attached instance has
its own tagged wrapper. Selection outlines cannot intercept rays or affect
navigation. Gold and dark contours retain contrast across pale and dark surfaces;
their display colours remain independent of atmospheric fog and tone mapping.
The gold stroke targets 2.25 CSS pixels as the camera or viewport changes. The
same 24 edge instances are resized rather than recreated during camera movement.
A selected part survives chunk replacement by ID; Look closer first
loads its owning plot, then frames the current rendered bounds. Landing bounds
include the complete 0.125 m mesh grid rather than only its four corners.

Selection alone changes no world data, revision or undo entry. Fixed and locked
parts remain inspectable. Missing selected nodes fall back to their surviving
deck. Entering or furnishing a cabin remains a separate action. Pointer actions
carry scene/camera versions, and mode changes, import and cancelled gestures
invalidate pending picks. Region drags and orbit drags do not become object
clicks simply because they end over a part.

## Required completion and critic acceptance

Broader physical profiles, full catalog admission and independent product grades remain
required. Existing plot materials and dimensions are a first explicit hierarchy,
not a complete volumetric WFC construction system.

Run `tools/test-groundworks.ps1`, build with `build-web.ps1 -WithTests`, then run
`node tools/test-groundworks.cjs`, `node tools/test-groundworks-view.cjs` and
`node tools/test-supported-buildings.cjs` and `node tools/test-groundwork-picking.cjs` against
the served build. Tests exercise 8,100 plot/direction candidates,
the critic's full-width seam and submerged-edge regressions, deterministic WFC,
scoped panel/body replacement, lock preservation, overlap rejection and wire
round trips, actual worker revisions, desktop/phone editing and walking journeys.
Generated evidence is retained under `build/`. The critic gate in
`reviews/features.json` remains pending.

For a focused visual recheck, `TEST_OUTLINE_ONLY=1` runs the actual panel/core,
ramp and landing picks plus overhead/oblique captures, and writes the separate
`build/groundwork-outline-evidence.json`. `TEST_DPR=2` exercises the phone at two
physical pixels per CSS pixel. The default suite additionally exercises locks,
shared building templates, chunk replacement, unloaded selection and gestures.
