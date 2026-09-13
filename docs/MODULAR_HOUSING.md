# Modular homes in the world

Choose **Build a space**, draw connected floor tiles with Box, Brush or Lasso,
then **Imagine home here**. The footprint uses two-metre tiles independently of
the regional terrain grid. Switch to **Select parts** to tap a floor, wall,
window or door in any camera view. The part list offers the same selection when
a face is difficult to reach. **Look closer** frames the selected part, including
tiny supported objects. **Whole home** selects the home and returns to an
architectural overview. The cutaway hides the roof and same-home walls that
obstruct selected furniture or its contents; selecting the home or a structural
part restores its walls. Turning off the cutaway restores the full enclosure.
First person always keeps the enclosure visible and solid.

An edge can become a wall, window, door or passage. Windows have real openings
and lightly tinted glass: the view beyond is the surrounding world. Nearby
doors offer **Open door / Close door** in exploration as well as editing. The
player must leave the leaf's swing clear. Door state is saved on the same part.

Paint adjoining land and choose **Extend into selection** to grow an existing
home. Existing floors, edge identities, furnishings and nested objects retain
their exact values. Only unlocked former perimeter edges that now join the
extension become passages. Locks can make an otherwise plausible edit fail;
the previous world remains available and unchanged.

Select a floor to imagine a plant, table, bookcase, chair, laboratory bench or
bathroom fixture. Position and facing controls place it within that tile.
**Its contents** and **Up one level** navigate and frame real furniture supports, including
individual shelf tiers and the food support inside a plate. Surface counts
include zero. Removing plates removes their unprotected contents and preserves
other roles, such as forks. Locked descendants prevent removal until unlocked.

## Data and constraints

The versioned asset `phanes.building.modular.v1` distinguishes these homes from
older imported shells. Its composition root belongs directly to the world.
Floors and shared edges have canonical IDs and world-aligned X/Z offsets;
furniture and finer contents use their owner's local coordinates. A fixed
floor datum is chosen above the highest underlying terrain point. A six-metre
graded apron blends the surrounding land to the slab, with shared rendered
triangles and standing heights. Original regional arrays remain exact;
overlapping vegetation is suppressed at rendering and collision time.
Entrance admission checks the doorway and a two-metre landing with the existing
collision, slope and slab-step limits. It permits players to turn beyond that
landing, rather than requiring six metres of unobstructed straight travel.
The regression includes a neighboring wall beyond the clear landing.

`phanes.buildings.generate` runs bounded WFC in the existing world worker.
Its interleaved graph has floor cells, shared-edge cells, and inert junctions.
Floor values select oak or stone; edge values select compatible plaster/timber
walls, windows, operable doors or passages. A stone floor requires plaster
reveals. Existing cells are exact domains, with joining seams changed only by an
extension. Search is capped at 20,000 backtracks; exhaustion is not a proof that
the requested design is impossible.

Independent admission checks exact IDs, poses, edge coverage, material
compatibility, connected rooms and a usable exterior approach. A quarter-metre
physical flood with doors open checks routes around furnishings. Wall meshes,
door leaves and collision share the same module boxes. Furniture admission
checks complete assemblies, support ownership, door sweeps and protected
descendants. Spatial bins keep movement checks local. Populated floor supports
are validated with their full subtrees and unchanged ancestors, avoiding a
full-world content scan for every empty tile.

Worker results publish atomically through the existing history. Undo, Redo,
export/import and recovery checkpoints include module and nested object states;
the checkpoint also records the selected home, part, tool and roof cutaway.
No separate interior room is entered when walking into a modular home.

## Current bounds and verification

The current kit supports one storey, 2.8-metre walls, a flat roof, up to 256
connected tiles and a maximum span of 64 metres. It admits dry footprints with
reasonable terrain support and a clear entrance. One primary furnishing fits
each floor tile, with independently editable supported contents. It does not
yet offer stairs, stacked storeys, free-angle walls or animated door motion.
Existing imported houses retain their saved portal interiors; they are not
silently converted to this new construction contract.

Run `tools/test-buildings.ps1` for native WFC, preservation and count regression
checks. Run `tools/test-renderer.ps1 -Case modular -TestUrl <preview-url>` for the
Pascal browser journey. Both accept compiler/browser configuration parameters.
Generated logs and rendered evidence belong under ignored `build/`. Feature
acceptance is recorded by the independent critic through `reviews/features.json`.
