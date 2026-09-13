# Optional objects in a world

The current integration candidate connects fourteen measured interior admissions
to the existing contents solver and renderer. The initial book and vase are in
[CATALOG_ADMISSION.md](CATALOG_ADMISSION.md); the twelve additional objects and food
items are in [CATALOG_OBJECTS.md](CATALOG_OBJECTS.md). Full catalog breadth and the
release gate remain open. This document
describes the implementation contract; execution evidence is recorded separately
in [VERIFICATION.md](VERIFICATION.md).

The worker validates the candidate composition before it reaches the browser.
`phanes.catalog.runtime` collects its optional asset IDs and prepares each missing
model. The downloaded manifest must match the compiled admission, including its
external-file identities. Castle verifies the root identity, copies the bounded
closure into an owned filesystem, decodes the scene, checks its triangle count
and transformed envelope, applies the world's surface treatment, and prepares
rendering resources. Only after this acknowledgement can the publication callback
replace the world and update history, selection or session state.

Generate, import, Undo, Redo and session restoration use this preparation gate.
An unsuccessful download, stale request, rejected admission or failed decode does
not invoke the callback. Saved-session failure retains the saved data and exposes
the existing recovery controls. Preparing raw assets does not guarantee against
an unrelated later renderer or graphics-driver failure; the normal renderer
recovery path still applies.

Downloads leave the current world editable. The busy indicator and status show
preparation; Cancel stops it. A new request supersedes the old one. Selection or
world revision changes are checked before and after awaited work and by a
100 ms timer active only during preparation. Visibility loss, pagehide, freeze
and startup failure also cancel pending work. A covered view can prepare resources;
a suspended view cannot. No partial candidate is published while waiting.

## Ownership and limits

The browser cache has a 16 MiB retained-byte limit. Each browser lease is released
after Castle copies the source closure. Castle retains a separate source copy
for as long as its scene may need resource reload. Active-world assets remain
pinned while a replacement is preparing, so the limits include the old world
and the candidate together.

| Castle resident measure | Limit |
| --- | ---: |
| Source files including notices | 16 MiB |
| Distinct admitted models | 32 |
| Declared position vertices | 250,000 |
| Triangles | 50,000 |
| Texture pixels | 4,194,304 |

These are independent source and geometry limits, not a total decoded-memory or
GPU-byte limit. Texture mipmaps, renderer buffers, browser networking and decoder
temporaries add overhead. The admitted vertex and texture values come from the
pinned source profiles and their native tests; the runtime rechecks decoded
triangles and bounds. Unadmitted files cannot enter through a saved asset ID.

`phanes.catalog.residency` retains each scene lease until the new world's drawn
revision is acknowledged and preparation has ended. It then removes unused
derived templates from both the studio and modular-building caches before freeing
the raw scene and filesystem. A future Undo can reacquire the source. At view
shutdown, derived components are destroyed before the lease store; CGE's
inherited `Stop` itself does not free `FreeAtStop` components.

Browser diagnostics expose `phanesCatalogReadyIds` and
`phanesCatalogResidentStats` as JSON strings. These help bind browser evidence to
actual Castle residency; they are not product controls or total-memory telemetry.

The source bundle also supports an explicitly supplied `TCatalogSharedFiles`
store. A shared store retains one immutable byte sequence per live exact-case
path, rejects different bytes and case aliases, and releases a file after its
last bundle reference. Each bundle still counts its entire closure, including
notices. Read streams own their copies. The caller must keep the store alive
until every scene and bundle using it has been destroyed; scene leases destroy
their scene before releasing their source bundle.

Browser staging shares source files only within an exact kit ID and manifest
SHA-256 namespace. `phanes.catalog.sources` owns these namespaces and one source
budget spanning them. New bytes reserve capacity before allocation or reading;
duplicate live files consume no additional capacity. Each scene releases its
bundle before releasing its namespace, and the pool outlives every resident.
The 16 MiB source limit still includes the current world and staged candidates.

Before GPU preparation, `phanes.catalog.textures` captures conservative claims
from decoded image URLs, dimensions, texture classes, flip/repeat state, texture
properties and effective rendering filters. Only identical claims share their
pixel cost. Different samplers remain separate even when the decoded image is
shared. Missing decoded images and known costs above the declaration reject;
unsupported texture kinds and unmeasured declared padding retain a per-profile
cost. Texture nodes and filtering must remain unchanged while these snapshots
are resident. World surface changes only replace shader effects.

Diagnostics report `sourceBytes` as the unique retained source total,
`closureSourceBytes` as the sum of complete resident closures, and
`sourceNamespaces` as the live namespace count. `texturePixels` is the union of
the conservative claims. All existing caps remain unchanged. GPU texture sharing
and resource reload require browser evidence; native image identity alone is
insufficient. Full feature acceptance remains pending.

`tools/test-catalog-files.ps1` exercises storage failures and scene ownership,
including eight pinned furniture closures with their notices. Its shared and
isolated controls compare complete transformed geometry, release four scenes,
reload the surviving textures, and require zero retained files after final
release. These fixtures do not admit the furniture to the playable catalog.

`tools/test-catalog-shared-runtime.ps1 -Browser <Chromium executable>` builds and
serves the isolated WebAssembly fixture using the pinned library in `build/web`.
It compares eight isolated atlas allocations against one shared allocation,
checks the texture profiles against intercepted GPU uploads, releases and reloads
survivors, and exercises context loss followed by a fresh page. A sampler variant
must allocate separately while retaining the shared decoded image. Source hashes,
runtime hashes, screenshots and results are retained under its evidence directory.
Its isolated eight-texture control exceeds the application texture cap by design;
the fixture is a resource regression check, not a playable admission or a phone
performance benchmark.

The current admissions are leaf contents with known transforms. The interior
picker filters compatible choices by category, subgroup and name. Additional
composition roles, prefab dependencies and larger model
profiles still need their own admission and ownership evidence before expansion.
