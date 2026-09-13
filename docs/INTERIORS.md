# Granular interiors

New [modular homes](MODULAR_HOUSING.md) use world-space walls, windows, operable
doors and furniture supports. Players walk directly inside without switching
interior context. The imported-shell workflow below remains compatible with
existing saved worlds.

The first connected interior workflow is a furnished studio. Select one cabin,
Gabled house or Courtyard house, choose **Furnish interior**, then drill through the room, bookcase, shelf tier
and individual object. **Look closer** frames the current selection. Shelf 4
starts with three independent books; Shelf 2 starts with one ceramic snail.
Each has its own identity, support and local pose. A table's plates also expose
**On this plate**, with separately editable bread, fruit and cheese. This is a limited first
interior profile, not arbitrary architectural reconstruction. Imported houses
use explicit portal rooms; [RENDERER_RECOVERY.md](RENDERER_RECOVERY.md) describes
nearby entry, physical room dimensions, supported-house ownership and return.

## Ownership and execution

`phanes.interiors.generate` runs in the Pascal world worker. The new controller
is `phanes.interiors.ui`, compiled through `phanes.interiors.browser`; it owns
hierarchy navigation, category choices, count capacity, inherited-lock feedback
and interior camera actions. Existing editor callbacks publish worker results
and maintain world history. `phanes.interiors.scene` builds the CGE cutaway from
the validated document. No handwritten interior controller or Python tool is
required.

The hierarchy is `world / building / studio / furniture / support / item`,
continuing through a plate's inner support to its individual food items.
World format 2 embeds the version 1 composition document. Building anchors must
match their exact regional building asset and terrain elevation, or belong to
an admitted groundwork deck. Studio and
furniture profiles have fixed admitted dimensions and local transforms; users
cannot forge different shelf heights, support ownership or furniture overlap
through import. Labels remain independent of identity and retain Unicode.

## Actual WFC decisions

The furniture pass uses a 4 by 4 floor graph with explicit empty aisle cells.
It places exactly one table, two facing chairs and one bookcase. Reciprocal
chair/table sockets and a connected empty floor restrict placement. Four back
anchors and two table positions yield eight admitted layouts. The extra aisle
row represents the physical gap between bookcase and table; it is not another
row of furniture. Search is bounded to 512 backtracks. Rule keys use WFC's
incoming-neighbour convention; Phanes converts its outgoing socket predicates.

Each of the four shelf tiers, the tabletop and each plate has a separate contents
solve. Four reserved, disjoint local volumes define each shelf/tabletop; three
define each plate. The shared contents
adapter chooses roles with exact quotas, then maps those roles to individual
asset choices. Profile dimensions and item measurements constrain eligibility.
Decoded ownership, transforms, contents counts and fit are checked independently
before a scoped composition transaction publishes the result.

Changing a count preserves the appearances and positions of surviving items;
only the requested category may be added or removed. Changing one item's appearance or
replacing a book with a snail preserves every other node exactly. A single-item
reimagine excludes its current appearance when alternatives exist. Default item
names follow an appearance change; custom names survive. Locks propagate through
ownership/support and disable protected choices with an ancestor explanation.
An occupied plate may change appearance without changing any food record.
Regenerating the tabletop retains its occupied plates and their contents.
Reducing the plate count explicitly removes complete owned settings; a locked
food item protects its plate from removal or appearance changes. The world
validator checks every support, including ancestor reservations, after an edit.

Removing a selected cabin removes its owned interior in the same world edit.
A protected descendant rejects that removal. Unrelated buildings retain their
complete records; undo restores the removed building and contents together.
Restore validates the saved instances without regenerating them. Rendering uses
a separate publication version so equal saved revision numbers never imply equal
scene contents.

## Measured catalog

Three unchanged CC0 source files from the existing Kenney Furniture Kit are used.
Their imported provenance is in `data/kits.lock.json` and `asset-inventory.json`.
Measurements include node transforms, rather than only mesh-local bounds.

| Source model                     | Physical wrapper and support                                                                                            |
| -------------------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| `furniture-kit/bookcaseOpen.glb` | Uniform scale 2, centred X/Z and ground aligned; 800 × 500 × 1760 mm; actual shelf planes at 260, 740, 1220 and 1700 mm |
| `furniture-kit/table.glb`        | Uniform scale from measured loaded height to a 750 mm tabletop; conservative 1933 × 1028 mm footprint                   |
| `furniture-kit/chair.glb`        | Uniform scale 2, centred and ground aligned; 400 × 400 × 940 mm; seat at 480 mm                                         |

Source SHA-256 fingerprints:

| Model    | SHA-256                                                            |
| -------- | ------------------------------------------------------------------ |
| Bookcase | `750702218d68c062b15dfef6ab06a4014d1cfa8bd05f02e57c53b7e13bec157c` |
| Table    | `ff1a94498d023957f4bc3ff6f55a7a82977d336dbf01a573b3364f03afe5ff61` |
| Chair    | `c8a11eec93e89e31250ba91afc1b8d56c3bec7ae86640fd1239f595ff4180883` |

Fourteen original MIT-licensed prop definitions are authored in Pascal: three
48 × 190 × 250 mm bound books; two 140 × 90 × 100 mm ceramic snails; two
260 × 260 × 24 mm plates; a 28 × 190 × 8 mm fork; two 50 × 86 × 18 mm bread
portions; two 40 × 40 × 48 mm fruit choices; and two 42 × 44 × 22 mm cheese
portions. Each placed prop is an
independent instance, not a grouped books/food mesh. Books use page blocks,
covers, spines and inset decorative bands; snails use shaped ceramic forms and
spiral relief; plates use a revolved rim profile. These dimensions are conservative
placement envelopes. Small ornament details use reduced tessellation.

Shelf profiles expose 720 × 420 mm usable support, 420 mm headroom and four
160 × 300 × 310 mm reserved volumes. The tabletop uses two 300 mm square plate
slots and two 60 × 240 mm fork slots. These immutable profiles are catalog
contracts, not dimensions guessed from object labels. Interior wrappers do not
inherit the regional renderer's additional scale factor.

A plate's usable square is 116 × 116 mm, inside its 85 mm inner radius, with
80 mm headroom. Contact is 6 mm above the plate origin, below the 24 mm rim.
The food models use original closed geometry and procedural surface detail in
`phanes.interiors.food.scene`: bread crumb pores, fruit freckles, herb flecks and
cheese rind. The apple has a recessed crown and a slightly tilted stem.
Support instances are optional in saved records,
so older empty leaf plates still restore exactly. New eligible plates gain their
stable `.well` surface; initial room furnishing fills its three food categories.
An older leaf plate offers **Prepare this plate for food**, preserving its
appearance while adding that surface explicitly. Its underside foot reaches the
table plane without changing the inner food contact. **Look closer** uses an
elevated orbit view for plates and food so the portions remain visible.

Original procedural material effects add wood grain, plaster variation, cloth,
ceramic and metal response. Detail uses physical local coordinates, fades fine
frequencies with the pixel footprint, and perturbs lighting normals without
changing placement geometry. Imported furniture retains the shared world palette
treatment. These are authored material effects, not extra WFC placement decisions.
Interior wood now uses broad irregular variation and pixel-filtered fine fibres
instead of periodic bands. Enclosed portal rooms increase the four existing
stationary fill lights by 2.4 times to approximate missing indirect bounce; the
gain stays constant across camera modes and resets on exterior return. This adds
no lights or shadow passes and is not a global-illumination solution. Same-world
modular buildings retain the exterior lighting treatment.
The floor uses one continuous surface with pixel-filtered millimetre board seams
and staggered end joints. Soft contact attenuation derives from the four placed
furniture envelopes and wall edges; it is an explicit local approximation, not
full dynamic shadows or screen-space ambient occlusion. It rebuilds with the
layout so imported furniture positions retain their grounding.

## Current limits and verification

The cutaway is a separate editing view with a floor and open walls. It does not
yet connect through the exterior cabin door; exterior door scale and closed
building collision remain separate work. Interior walking uses a 1.68 m eye
height, room boundaries and conservative furniture collision. Picking uses the
nearest visible geometry and its owning instance. Rays start on the visible
near plane and skip back-facing triangles only for single-sided meshes, with
a bounded 128-hit traversal. Double-sided geometry remains selectable. The
cutaway shell is authored.
Selection uses short gold/dark corner brackets with display colours independent
of scene lighting. They retain depth occlusion and do not participate in picking,
collision or shadow casting; the center of the selected object stays visible.
The gold stroke targets two CSS pixels using camera depth, effective field of
view and CSS viewport height, so tiny food remains visibly selected on phones.
Camera movement resizes the same 48 bracket shapes without rebuilding the model.

Only this studio, these furniture poses and these three support profiles are
admitted. Arbitrary furniture placement, editable room programs, named bays,
lock/unlock and rename controls, routes,
larger catalogs and room streaming remain requirements of the full world feature.
Nested assembly envelopes now govern parent replacements and surrounding
contents solves. Validation of very large populated
documents has not yet been benchmarked.

A cabin may now belong to an explicit foundation or launch-pad deck. Its stable
building container owns the same local studio and independently editable contents.
The plot panel opens that studio and restores the exterior camera when leaving.
Compatible support/material edits preserve the complete subtree and its locks;
swapping the furnished cabin to an incompatible shell is rejected. This remains
a separate cutaway view. See [GROUNDWORKS.md](GROUNDWORKS.md) for support admission.

`node tools/test-interiors.cjs` exercises the compiled worker and actual CGE host:
33 seeds including the unsigned maximum, the eight furniture layouts, counts,
scoped/cross-role replacement, protected ancestors, dependent clear, malformed
input, exact restore and desktop/phone interaction. Screenshots and results are
stored under ignored `build/`. Shared composition checks remain in
`tools/test-composition.ps1` and `tools/test-composition.cjs`. A successful test
run does not override the independent visual/UX critic gate.

Each explicit "Look closer" request retains its target independently of later
selection changes. Castle frames that target's bounds and the browser uses its
role and support orientation, even if a parent was selected before the next
render. Automated inspection waits for the matching interior, room and scene
acknowledgements as well as the rendered camera version.

`tools/test-interior-frame.ps1` pauses animation frames between fruit/book
inspection and parent selection, then compares the target bounds and complete
camera pose with normally acknowledged inspection. It checks exact world
preservation and real fruit picking on desktop and touch-emulated phone
viewports. Pass a Chromium `-Browser`, the hosted `-TestUrl`, an
`-EvidenceDirectory` and `-NativeCompiler`; the wrapper compiles the Pascal
driver and tests the supplied site without rebuilding the application.
