<!--
MIT License

Copyright (c) 2026 mr-highball

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
-->
# Bounded optional regional catalog

`phanes.catalog.regional` admits 18 measured optional models: four trees, four
shrubs, four flowering plants or groundcover patches, three crops, and three
rocks. Each record pins the current kit manifest and root source hashes. The
physical profile uses a uniform scale and the conservative ceiling of the full
decoded X, Z and Y spans in millimetres. Ground placement centers X/Z and moves
the decoded minimum Y to zero.

The scales preserve recognizable proportions rather than expanding every model
to its role cap. This matters for narrow grain stalks: normalizing their width
to 1.2 metres would make them more than three metres tall. Every final full
horizontal rectangle remains within its role maximum: trees 3.6 m, shrubs 2 m,
flowers 0.7 m, crops 1.2 m, and rocks 2.4 m.

| Admission ID | Source interpretation | Scale | W × D × H mm | Triangles | Vertices | Texels |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| `phanes.catalog.tree.forest-canopy.v1` | Textured trunk and compact green canopy with UV/tangent data | 3.5 | 3246 × 3090 × 5894 | 182 | 428 | 262144 |
| `phanes.catalog.tree.autumn.v1` | Textured trunk and orange autumn canopy with UV/tangent data | 5.0 | 2765 × 2632 × 7055 | 198 | 348 | 262144 |
| `phanes.catalog.tree.birch.v1` | Trunk/canopy mesh with black, white and two green material partitions | 1.4 | 2383 × 3472 × 5004 | 1704 | 5112 | 0 |
| `phanes.catalog.tree.island-palm.v1` | Textured tall trunk with broad green radial fronds and UV/tangent data | 1.4 | 3485 × 3485 × 5899 | 338 | 680 | 262144 |
| `phanes.catalog.shrub.leafy-bush.v1` | Compact rounded green foliage mesh | 1.0 | 1329 × 1691 × 1242 | 364 | 1092 | 0 |
| `phanes.catalog.shrub.broadleaf.v1` | Balanced broadleaf volume with a dark-green surface | 1.5 | 1635 × 1459 × 1416 | 600 | 1800 | 0 |
| `phanes.catalog.shrub.berry-bush.v1` | Compact branched crop-pack bush form | 2.0 | 1185 × 1030 × 1012 | 140 | 420 | 0 |
| `phanes.catalog.shrub.forest-plant.v1` | Low radial forest plant with the original color-map texture | 4.0 | 1586 × 1722 × 768 | 156 | 408 | 262144 |
| `phanes.catalog.flowers.cactus-bloom.v1` | Tall cactus bloom with separate green and pink material factors | 0.6 | 287 × 671 × 1002 | 1184 | 3552 | 0 |
| `phanes.catalog.flowers.cactus-cluster.v1` | Distinct narrow cactus cluster with green and pink material parts | 0.9 | 101 × 661 × 845 | 800 | 2400 | 0 |
| `phanes.catalog.flowers.wildflowers.v1` | Three-part cyan/yellow bloom and green foliage cluster | 1.1 | 539 × 676 × 912 | 408 | 1224 | 0 |
| `phanes.catalog.flowers.flower-patch.v1` | Low cyan/yellow flowering groundcover patch | 2.3 | 672 × 674 × 268 | 134 | 402 | 0 |
| `phanes.catalog.wheat.corn.v1` | Mature upright corn plant geometry | 0.95 | 641 × 544 × 1185 | 348 | 1044 | 0 |
| `phanes.catalog.wheat.rice.v1` | Mature narrow rice cluster geometry | 1.3 | 805 × 310 × 1000 | 628 | 1884 | 0 |
| `phanes.catalog.wheat.grain.v1` | Mature slender grain stalk geometry | 1.7 | 281 × 414 × 1181 | 246 | 738 | 0 |
| `phanes.catalog.rock.granite.v1` | Low asymmetric angular rock volume | 1.9 | 1413 × 2376 × 1489 | 128 | 384 | 0 |
| `phanes.catalog.rock.mossy.v1` | Same rock form with separate rock and green surface parts | 1.9 | 1413 × 2376 × 1489 | 128 | 384 | 0 |
| `phanes.catalog.rock.forest-stones.v1` | Multi-stone forest cluster with the original color map | 2.6 | 2351 × 2216 × 1181 | 236 | 414 | 262144 |

The choices span five kits and retain multiple silhouettes, material treatments
and source structures. Semantic admission used decoded proportions, primitive
and material partitions, UV/texture bindings and source representation inspection
in addition to names. The four `flowers` records are flowering plants or flower
patches; fungi and generic grass were excluded from that role. Three neutral-gray
tree sources and two neutral-gray flower sources were rejected after actual CGE
rendering exposed that their original exports had no texture, vertex color or
non-neutral material factor.

`tools/test-catalog-regional.ps1` compiles and runs the native Castle verifier,
then compiles the portable profile unit with pas2js. The native test loads all
18 source scenes, compares Castle triangles and bounds to
`data/catalog-geometry.json`, verifies actual publication and source hashes,
reads POSITION accessors and PNG dimensions independently, checks exact scaled
integer envelopes and role caps, and exercises unknown IDs and independent
record and ID-array copies. Every admitted tree and flower must also have an
actual texture binding, `COLOR_0` attribute or non-neutral material factor; a
neutral untextured source fails admission even when its filename suggests color.

The regional batch totals 7,922 triangles, 22,714 position vertices and 1,310,720
texture pixels. Its conservative staged-source calculation is 1,217,856 bytes;
it adds each model closure and a notice per resident model even when records
share a kit. Including the two earlier book/vase records gives 20 models,
1,292,337 staged source bytes, 8,194 triangles, 23,438 vertices and 2,359,296
texture pixels. These stay below the requested 32-model, 16 MiB source,
50,000-triangle, 250,000-vertex and 4 Mi-texel limits.

## World integration

`tools/assets.ps1 -Action prepare-regional-palette` regenerates only the optional
rows of `data/palette.json` from the measured profiles, preserving the core rows
and prefab recipes, and refreshes the catalog summary. The palette exposes 37
regional choices through the existing category, subgroup, search and exact-item
controls. The first Create operation chooses core models; subsequent explicit
nature edits can select the optional batch. No optional geometry joins the
startup archive.

Optional regional models have a separate placement domain from shelf objects.
The worker independently validates their declared role and single-instance
placement count. The renderer uses the profile's physical scale directly,
centers X/Z and grounds minimum Y. Tree collision conservatively encloses the
whole horizontal rectangle with a circle; rock collision uses the rectangle,
including quarter turns and deterministic placement jitter. Every full
horizontal envelope remains inside the four-metre ecological clearance radius
at maximum jitter. These are conservative closed collision proxies, not detailed
trunk or branch contacts.

Publication prepares each required regional model before mutating the world or
history. Residency pins the complete vegetation layer, including distant chunks.
Retirement waits for all old chunk references to be replaced and the new world
to render, then destroys regional and interior templates before raw scenes and
retained files. The existing limits count distinct profiles, not all placed
instances or total GPU allocations.

The native integration wrapper `tools/test-catalog-regional-integration.ps1`
passes 4,114 checks: all 18 exact WFC edits, every unaffected layer/cell, palette
profile consistency, collision clearance, core-first creation, and rejection of
shelf placement and forged cluster counts. The Castle release build passes in
`build/logs/catalog-regional-main-build-02.log`; the shared interior publication
regression passes all 67 checks in `build/catalog-regional-interior-world-02`.
Full source verification still accepts all 8,365 models and 37 palette choices.

The actual application journey passes 129 checks in
`build/catalog-regional-browser-actual-05`: every admitted model through the
category/group/item/Apply controls, exact unaffected output, all 18 resident
together, desktop and phone Undo/Redo, phone Apply, saved-session recovery,
retirement to zero, reacquisition and distant-chunk streaming. The distant case
first proves no detailed template exists, then moves the camera to build it,
streams away while retaining the model, and finally removes and retires it.
Initial world creation uses the visible Create button; the later 16-cell streaming
fixture uses the validated generation API because the welcome form is hidden
after publication. Both journeys retain zero uncaught errors, console errors or
model resource warnings.

Eighteen individual captures and five group views use the same Pascal terrain
contact-height calculation as the renderer to frame the actual placed geometry.
Desktop/phone catalog captures document the real controls. These are development
machine renders, not physical-phone performance measurements. Source/artifact
provenance is retained in `build/catalog-regional-provenance-02.json` and the
browser evidence directories. Broader catalog coverage and independent
full-catalog acceptance remain open.
