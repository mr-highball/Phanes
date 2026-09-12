# Static source conversion

`tools/phanes.tools.obj.pas` converts a deliberately bounded subset of original
OBJ/MTL bytes to derived GLB in Pascal. It does not download files, search for
textures, import a kit, update the catalog or grant placement capabilities.
The caller supplies the exact original OBJ and MTL bytes and their basenames.
The converter returns GLB bytes and owned JSON evidence; evidence is nil after
any rejection.

The existing Castle OBJ loader and glTF exporter are too permissive for this
boundary: unsupported source fields can disappear, and independently indexed
UVs/normals can be exported using position indices. The Phanes converter parses
and validates every source directive and emits explicit corner tuples itself.
The pinned Castle engine then supplies a separate decode/render check.
The source inspection is retained in `build/critic/obj-conversion-design-01.md`.

## Two explicit recipes

`ConvertStaticOBJ` uses `phanes.obj.matte.v1`. It accepts simple planar polygons,
including concave boundaries, and rejects nonplanar faces. Its planarity
tolerance is one hundred-thousandth of that polygon's largest axis extent.

`ConvertSurfaceOBJ` uses `phanes.obj.surface.v1`. It supplies a concrete interior
surface for nonplanar source polygons by projecting their boundary along the
dominant Newell-normal axis and clipping ears in a deterministic order. It
retains the original XYZ positions, normals, UVs and material assignments.
This is an explicit topology adaptation; it does not claim to reproduce an
unspecified OBJ tessellation or the creator's native Blender/FBX surface.

Both recipes validate the float32 positions that the GLB will store. They reject
repeated projected corners, self-intersections, degenerate polygons and triangles,
and failure to preserve oriented projected area. Relative length and area
predicate tolerances are `extent * 1e-9` and `extent² * 1e-12`. The surface recipe
also requires every emitted triangle normal to point with the face's mean normal.
This condition does not bound the angle between neighboring triangle normals;
an intentionally sharp saddle can remain sharp. No face is silently discarded.

For the surface recipe, evidence records `nonplanarFaces` and
`maximumPlaneDeviationRatio`; each emitted source-face range also records its
`planeDeviationRatio`. This measures distance from the Newell plane through the
first source corner, divided by the largest axis extent. It is not a best-fit
plane error, a rotation-invariant quantity or vertex deformation. No source
vertex is flattened to that plane.

## Geometry and material contract

The converter preserves whole-file identity and source coordinates. It infers
neither metres nor the up axis. Every face corner must have an explicit normal;
normals are normalized. OBJ positive and relative indices are resolved at the
point of reference. A face either has complete two-dimensional UVs or none.
Output primitives separate these cases; missing UVs never become fabricated
zero coordinates. Explicit UV V is inverted once for glTF convention. Independent
position/normal/UV indices become unindexed triangle tuples, retaining hard edges
and seams. Source `o`, `g` and `s` metadata, face lines and emitted ranges remain
traceable. This does not make named source groups separately placeable objects.

Materials are an adaptation to Phanes' matte recipe: original Kd is interpreted
as linear base color, metallic is zero, roughness is 0.72, opacity is one and
faces are double-sided. Original material fields remain in evidence and GLB
extras. Ka, Ks and Ns are not silently presented as equivalent PBR shading.
Paired visual review remains necessary for a source family.

Each material requires explicit RGB Kd. The accepted optional fields are RGB Ka
and Ks in `[0,1]`, zero RGB Ke, Ns in `[0,1000]`, Ni in `[1,2.5]`, d equal to one
and illum equal to one or two. Duplicate fields, undefined materials, multiple
or mismatched mtllib declarations, unsupported illumination, textures/maps,
transparency and unknown fields reject. Unsupported OBJ geometry, missing
normals, extra vector components and mixed per-face attribute presence reject.
Texture-bearing and animated sources require separate recipes.

## Bounds and provenance

Each source and each output is limited to 32 MiB. Source text is ASCII with
ordinary CR/LF/tab whitespace and at most 4,096 bytes per line. Limits are 200,000
records per numeric channel, 100,000 faces, 64 corners per polygon, 600,000 source
corners, 200,000 output triangles and 256 materials. Absolute coordinates and
normal components are bounded by one million; UV components by 65,536. Normals
must have length greater than `1e-12`. No caller-provided transform is accepted.

Evidence includes source basenames, both original hashes, recipe, coordinate,
normal and UV policies, source-face/triangle/emitted-vertex counts, original
material parameters and source metadata. The GLB contains this derivation;
external evidence additionally records its output hash. These bytes contain no
clock, host path, random state or archive timestamp.

`phanes.tools.derived` binds the original archive, exact selected member paths,
notice, output pins and conversion evidence in `derived.obj.v1` kit entries.
Original OBJ/MTL bytes, derived GLBs and complete per-model evidence remain
distinct artifacts. A kit publishes only after its staged closure verifies;
verification regenerates its models from the retained originals. Existing kit
IDs require identical files and exact source-lock JSON metadata, including order.
Bundled notices and pinned creator-page evidence are explicit, exclusive modes.
Creator-page mode also checks the original archive has no bundled notice.
One source plus its GLB is one model, and alternate FBX exports or recolors do
not establish additional geometry families. The active source lock and inventory
now include 46 derived kits with 1,249 selected models.

## Current evidence

The independent planar fixture is `tests/phanes.tests.obj.critic.lpr`, frozen at
SHA-256 `49dbf00efcd4c12ae85a7b9e37b72a200626dd3698bda81914d47a46b07ab7d6`.
It passes 27,622 assertions in 11 groups, including independent GLB/corner
decoding, seams, material ownership, concave and oblique polygons, malformed
inputs, limits and deterministic output under changed working directory, locale
and random seed. Report: `build/critic/obj-planar-review-01.md`.
Cross-platform byte reproduction has not yet been executed.

The separate surface fixture, `tests/phanes.tests.obj.surface.critic.lpr`, passes
8,999 assertions. Its SHA-256 is
`2854d1b4056a2f78c4537ef868b737091dc0d22db4b84a85584471bd71ba743a`.
The independent archive oracle checked all 1,258 successful outputs against
their original OBJ/MTL bytes: 636,404 source faces and 1,281,259 emitted triangles,
with no mismatches. It does not use the converter API. Report:
`build/critic/obj-corpus-review-01.md`; this proves bounded geometry conversion,
not source licensing, unique families or player admission.

The importer fixture `tests/phanes.tests.derived.critic.lpr` is frozen at
`8d04af594d23175aabbbe7d3acfc581274489bea8a32170acb5672367dc1a9e1`.
It passes 434 checks across 80 offline fixtures, including source/notice binding,
immutable metadata, altered originals/outputs/evidence, closure case and links,
inventory tampering and rejection preservation. Its prepopulated caches do not
exercise HTTP download behavior. An isolated real import and regeneration check
also passed for 46 kits and 1,249 models after removing nine exact OBJ/MTL
duplicates. The independent notice audit passed all 46 original archives and
source pages: 16 bundled-notice kits cover 529 models, and 30 creator-page kits
cover 720. Report: `build/critic/derived-notices-review-01.md`.

The ignored original-source probe examines 1,506 OBJ files from older Quaternius
archives that have no original glTF representation in the inspected archive.
The planar recipe converts 241; Castle decodes all 241, yielding 235 provisional
static geometry groups. The separate surface recipe converts 1,258; Castle
decodes all 1,258 with matching triangle counts and finite bounds, yielding
1,190 provisional geometry groups. Nine exact source-pair duplicates were removed
before adding 1,249 models to the active catalog. Source format alternatives are
not counted; broader geometry-family reconciliation remains separate.

The 248 surface rejections include 113 projected self-intersections, 83 degenerate
polygons, 26 mean-normal disagreements, 17 line directives, five polygon-budget
violations, two repeated corners, one undefined material and one zero normal.
The probe retains reasons without widening tolerances or skipping faces.
Reports: `build/asset-research/obj-conversion-02.json` and `obj-decoded-02.json`.

Eighteen source/derived samples were rendered using a hidden native Castle
context, identical cameras and matching matte material/light treatment. Images
and hash-bound pair metadata are under `build/asset-research/obj-render-03/`.
They cover food, bathroom fixtures, crops, trees, equipment and animals. The
initial split-image helper failed to position its second viewport correctly;
that failed evidence is retained in `obj-render-01/` and is not a visual result.
The usable samples have separate `-0` source and `-1` derived images. This is a
bounded geometry inspection, not a final visual-quality or player-admission pass.
