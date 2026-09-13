# Physical structure and placement contracts

This increment corrects scale and ground-level admission for the current regional
catalog. The complete layered groundwork and modular building workflow remains
required by [GRANULAR_COMPOSITION.md](GRANULAR_COMPOSITION.md). Physical dimensions
alone do not pass the world creator's visual or interaction review.

## Measured placement

The world uses metres: one regional cell spans 16 m, and each ecology cell spans
8 m. For imported models, the catalog's legacy `width` is multiplied by two to
obtain the maximum horizontal model dimension. The authored cabin instead uses
its explicit dimensional profile, including roof overhang beyond the structural
footprint. The original GLBs retain their transforms and hashes.
The complete loaded assembly is centered in X/Z, grounded at its lowest Y, and
uniformly normalized once. Its normalization lives inside a referenced child;
placed Castle references also explicitly use `rtDoNotIgnore`.

This matters because Castle's default transform-reference behavior ignores the
referenced root's direct transform. The former root scale did not apply to
regional instances, and the rocket's source offset displaced it from its anchor.
Actual Castle bounds now measure the centered rocket at 7.2 × 11.6 × 7.2 m.
The gabled suburban house's maximum horizontal dimension is 12 m.

`tools/test-structures.cjs` inspects the real WebAssembly renderer's reference
bounds on desktop and phone. It captures the mixed-model view and a walking view
of the cabin door, waiting for the rendered camera revision and actual player
eye height. Acknowledgments run after the child viewport renders, so effective
FOV measurements belong to that frame. `window.phanesAssetBounds` is diagnostic evidence from Castle, not
dimensions inferred from a screenshot or copied from catalog declarations.

## Authored cabin shell

`phanes.structures.scene` builds original segmented geometry with dimensions
shared through `phanes.structures.dimensions`. Its structural footprint is
10 × 10 m, with 0.30 m walls and a 9.4 × 9.4 m clear interior. The floor top is
0.08 m above its placement datum, matching the existing studio frame. Walls rise
2.70 m above that floor; the roof ridge rises another 1.80 m. Roof overhang and
thickness and raised seams bring the overall bounds to approximately
10.66 × 4.67 × 10.6 m; the browser records the exact loaded bounds.

The doorway is authored independently of overall building scale. Its jambs and
header leave a 1.20 × 2.20 m opening; the closed leaf measures 1.155 × 2.175 m.
There are three window openings, physical trim, gables, roof seams and fascia.
Wood/plaster/glass-like surfaces use the existing original procedural material
treatment and shared palette tint. Tinted transparent panes are not a claim of
refraction or a complete lighting solution.

Exterior movement still uses a closed building proxy. The cabin studio remains
a separate cutaway entered through its editing action; this increment does not
connect it through the door. The same 1.68 m eye height applies in both views.
Walking uses a 70-degree field of view on the smaller viewport dimension, while
orbit framing retains 45 degrees. A neighboring higher terrace can still change
the apparent scale of a nearby entrance; graded approaches remain necessary.

## Collision and elevation

`phanes.world.placement` shares deterministic scale jitter and quarter turns
between rendering and collision. Boulder and crystal profiles are conservative
rectangles taken from the complete normalized Castle bounds, rounded outward
to millimetres. Collision expands those rotated rectangles by the player's
radius, including rounded corners. On model admission the renderer compares the
loaded bounds against these profiles so a changed model cannot silently retain
an obsolete collider. This is kinematic collision, not rigid-body physics.

Tree profiles use normalized Castle triangles clipped through 2/0.85 m, including
edge/height-plane intersections. Applying each instance's 0.85–1.15 scale then
encloses geometry in a two-metre band above its placement datum. Outward-rounded
base radii are oak 1.566 m, pine 2.401 m, autumn 0.973 m and fantasy tree 1.078 m.
Oak roots and low autumn branches count as solid. Pine includes its dense low
crown to prevent the player entering opaque foliage at eye height. The fantasy
tree has one mixed primitive, so its whole lower envelope is retained. These
are conservative cylinders; they do not imply leaf deformation or full physics.
Original models are pinned in the inventory and included in the critic inputs.

`phanes.world.elevation` is the single authored continuous height function used
by generation and rendering. WFC excludes architectural values where the current
building datum lies below the 0.10 m standing threshold, reserving one millimetre
for integer composition elevation. Explicit building requests fail instead of
silently generating an empty cell. Saved worlds with submerged building datums
are rejected before rendering. A meadow category alone no longer certifies a
dry building floor.

The unit also provides conservative continuous height intervals over finite
rectangles within 4096 m of the origin. It includes sine/cosine extrema inside
each interval; it does not assume that corner samples bound the landform. These
bounds support the groundwork adapter and do not themselves generate soil.

## Connecting buildings to explicit groundworks

The legacy renderer still makes an implicit plateau beneath a regional building.
The [groundwork adapter](GROUNDWORKS.md) now supplies independently editable
foundations and launch pads, with surface IDs, bounded excavation/fill, dry
coverage, visible support geometry and traversable approaches. Seven normalized
shells now attach to a deck at its exact datum and access quarter turn. The
explicit model catalog checks whole-model envelopes and preserves a walking
perimeter. Building identity is independent of the shared `scifi` role used by
rockets and habitats. A cabin can own its furnished studio; compatible support
edits preserve that subtree and its locks. Chunk signatures and movement proxies
include attached buildings. More varied contact patches, modular building parts
and open exterior/interior navigation remain required.

The existing WFC mapped passes, domains, adjacency, quotas and connectivity can
express these relationships. Current blockers are Phanes admission and geometry
contracts; dependency changes are not needed for this work.
