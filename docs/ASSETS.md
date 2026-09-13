# Asset inventory and compositional corpus

The original baseline contains 905 GLB models from six Kenney kits: Castle (76),
Nature (329), Furniture (140), Space (153), City Suburban (40), and Fantasy
Town (167). Counts come from the pinned archives, not the rounded web listings.
All six archives include CC0 notices, retained beside their models.

The current expansion has 8,365 glTF/GLB files from 108 pinned CC0 kits/collections. All decode
through Castle's native scene inspector. The additional 102 kits are stored
outside the startup archive; runtime catalog/placement admission remains pending.
[CATALOG_EXPANSION.md](CATALOG_EXPANSION.md) records the user-accepted roughly ninefold count,
counting rules, importer checks, optional packages and remaining work.

`data/kits.lock.json` records the original download/page URLs, archive SHA-256,
author or collection publisher, source evidence and retrieval date. The Base Mesh
snapshot retains 1,254 separate source archives under one collection, with exact
source/member identities and one common FAQ license declaration.
`tools/assets.ps1 -Action import-kits` compiles and runs
the native Pascal importer, which verifies each archive before
copying original glTF/GLB models and dependencies without transformations.
The 46 explicitly derived kits instead retain original OBJ/MTL files and use
the pinned Pascal conversion contract in [ASSET_CONVERSION.md](ASSET_CONVERSION.md).
These supply 1,249 of the model files, with distinct source/output provenance.
`data/asset-inventory.json` records per-model hashes and source provenance.
Raw mesh-local bounds in that inventory are descriptive; runtime normalization
uses CGE's transformed scene bounds.

`data/palette.json` is the first authored placement corpus. It admits regional
building and nature choices with explicit semantic roles and world footprints.
The cabin now uses an original shell with a measured doorway and studio-sized
interior; keep and rocket recipes compose pieces from their source kits. See
[STRUCTURES.md](STRUCTURES.md) for actual normalization and physical dimensions.
Those arrangements are authored scaffolds; they are not yet a learned or
WFC-generated modular building corpus. Flower/wheat clusters similarly use an
authored scatter inside the finer WFC cell.

The regional WFC model enforces dry building datums, ecology-to-terrain support,
building footprint clearance, shoreline adjacency and role-to-asset matching.
All admitted themes can coexist in the same world. Theme alone never forbids
adjacency. The model does not yet express door matching, wall sockets, interior
accessibility or every asset-to-asset relationship.

Most imported items remain explicitly `inventory-only`. Suggested roles are
filename-based catalog hints, not admission or verified compatibility. The full
objective requires reviewing all items into a shared corpus with sockets,
clearances, support surfaces, complete placement relations and cross-kit tests.
Measured furniture and individual contents are admitted for the cabin studio in
[INTERIORS.md](INTERIORS.md). Named bathroom/laboratory programs now build on
those contracts in [ROOM_PROGRAMS.md](ROOM_PROGRAMS.md). Most of the expanded
furniture and contents inventory still needs physical and contextual admission.

The coverage and admission requirements for foundations, launch pads, routes,
named interiors, furniture surfaces and individual shelf/table contents are in
[GRANULAR_COMPOSITION.md](GRANULAR_COMPOSITION.md). Theme, function, room purpose
and material are independent classifications. Grouped geometry does not count
as independently editable contents.

## Shared surfaces and interface art

`data/materials.lock.json` pins the unmodified CC0 Poly Haven Leafy Grass diffuse
and OpenGL normal textures and their hashes. The native Pascal material command
verifies both files. The current terrain uses those maps with biome tint; this
is not yet a complete set of distinct ground materials. Original kit textures
remain unmodified. A runtime treatment shares palette/finish across kit themes;
the broader art-quality requirement remains open.

The custom interface atlas and authored control styling have separate provenance
in [INTERFACE_ART.md](INTERFACE_ART.md). UI artwork is not evidence for additional
3D assets, verified object sockets or admitted model categories.

## Sources

- [Castle Kit](https://kenney.nl/assets/castle-kit)
- [Nature Kit](https://kenney.nl/assets/nature-kit)
- [Furniture Kit](https://kenney.nl/assets/furniture-kit)
- [Space Kit](https://kenney.nl/assets/space-kit)
- [City Kit Suburban](https://kenney.nl/assets/city-kit-suburban)
- [Fantasy Town Kit](https://kenney.nl/assets/fantasy-town-kit)
