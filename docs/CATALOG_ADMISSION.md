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
# First optional catalog admission batch

The first two profiles in `phanes.catalog.admission` describe the independently
measured optional book and vase below. Later regional and object batches extend
that registry; see [CATALOG_REGIONAL.md](CATALOG_REGIONAL.md) and
[CATALOG_OBJECTS.md](CATALOG_OBJECTS.md). Each record pins the current kit manifest and root model hashes,
the exact model ID, a uniform metre transform, a conservative integer millimetre
envelope, and the decoded triangle count. The manifest hash is part of the
contract because a root glTF hash alone does not bind external buffer and texture
revisions.

| Admission ID | Role | Source | Scale | Measured transformed W × D × H | Envelope |
| --- | --- | --- | ---: | ---: | ---: |
| `phanes.catalog.book.kaykit-single.v1` | book | `kaykit-furniture-bits-1-0/gltf/book_single` | 0.5 | 130.000 × 182.500 × 250.000 mm | 131 × 183 × 251 mm |
| `phanes.catalog.vase.quaternius.v1` | ornament | `quaternius-furniture-low-poly-surface-v1/vase2-2bf7766b41` | 0.85 | 142.441 × 142.441 × 260.122 mm | 143 × 143 × 261 mm |

The placement calculation matches the interior renderer: ground raw minimum Y
at zero and center raw X/Z, then apply the uniform scale. Both conservative
envelopes fit the existing 160 × 300 × 310 mm shelf slot. They also fit the
720 × 420 mm surface and its 420 mm headroom.

The book admission declares 112 vertices and 1,048,576 texture pixels. The
native check derives both values from the real position accessor and PNG header.
The source is one indexed primitive with 112 position vertices, 204 indices and
68 triangles. It uses one external 1024 × 1024 PNG plus a BIN; its three model
files total 22,653 bytes and its notice adds 827 bytes. The packed vertex,
normal, UV and index buffer views total 3,992 bytes. A decoded RGBA texture is
4 MiB before mipmaps and engine/GPU overhead, so source bytes are not its
resident-memory cost.

The vase admission declares 612 vertices and zero texture pixels. The native
check derives both from the real GLB JSON. The source is one non-indexed
primitive with 612 position vertices and 204 triangles. It has position and
normal attributes totaling 14,688 bytes and no texture image. Its GLB is 28,108
bytes and its source notice adds 22,893 bytes.
These attribute sizes describe the verified source representation; Castle and
GPU objects require separate runtime budgets.

`tools/test-catalog-admission.ps1` compiles and runs the native Castle check,
then compiles the portable unit with pas2js. The native check verifies the real
published manifest/root hashes, real source hashes, decoded triangle counts,
raw bounds, grounded and centered transforms, integer envelopes, shelf fit,
unknown-ID behavior, and independent record/array copies.

The browser proof in `build/catalog-admission-render-01` retains the existing
food, external-texture rug, stale-generation, failed-decode, and retry cases,
then fetches and renders the book and vase. It passes 26 checks with no browser
errors or resource warnings. Desktop and phone captures show one bound book and
one decorative vase, supporting the admitted roles. `evidence.json` records
23,480 staged source bytes for the book and 51,001 for the vase, including each
notice; `provenance.json` binds the sources, runtime output and pinned Castle
commit `050f07edde6652d6657b4fe0d299822b9f502afa`.

The isolated admission evidence above does not establish application placement.
The subsequent [world-publication candidate](CATALOG_PUBLICATION.md) connects
these choices to the contents solver, preparation, residency and session paths.
Its current verification status is recorded in [VERIFICATION.md](VERIFICATION.md).
The category breadth and full catalog acceptance requirements remain open.
