# Catalog expansion

The user accepted roughly nine times the original **905 models from six kits**
after reviewing the acquisition findings. Further acquisition to hit ten times
is unnecessary. Coverage across all categories, coherent appearance and usable
placement remain required. A model file, a material variant, an animation,
a repeated instance and an admitted placement choice are different counts.

## Current measured state

The catalog contains **8,365 glTF/GLB files from 108 CC0 kits/collections**: 46 from
Kenney, ten from Kay Lousberg, 51 from Quaternius and one Base Mesh snapshot.
This is about 9.2 times the original model-file count. Of these, 7,116 are original
glTF/GLB exports and 1,249 are explicitly derived from original OBJ/MTL sources.
All 8,365 output file hashes are distinct.
The accepted acquisition count is reached; playable expansion remains open.

The native Pascal Castle inspector decoded all 8,365 models, obtained finite
transformed scene bounds and found rendered triangles in each. The report is
`data/catalog-geometry.json`, bound to the inventory hash. The committed report
uses the Ubuntu 24.04 x86-64 CI toolchain and pinned CGE decoder; its SHA-256 is
`b39c94157cc2bbecc4d30a46c6ca0137f776b0a380d39530793c07c914aea05f`.
Actions runs 34728304188 and 34730331921 produced that same report hash.
The Windows i386 development decoder differs in 37 rows, including 25 shape
hashes and bounds differing by at most `1.1920928955078125e-7` model units.
All 7,717 geometry groups have identical membership in those two outputs.
Thus individual quantized shape hashes are decoder/platform results, not a
cross-platform identity guarantee. Regenerating on another platform may change
this tracked report and requires review; source model hashes remain authoritative.
Static decode does
not certify animation playback, collision, doors, support surfaces or physical
placement. The regional palette now has 19 core choices plus 18 optional nature
profiles with verified rendered journeys; their earlier bounded approval requires
renewal after shared changes. Imported models do not automatically enter WFC
domains. Fourteen optional interior objects now include books, artifacts,
equipment and food through [CATALOG_OBJECTS.md](CATALOG_OBJECTS.md). The earlier
two-object publication/recovery contract is in
[CATALOG_PUBLICATION.md](CATALOG_PUBLICATION.md); broad playable coverage
and current full-feature acceptance remain open.

The inspector also groups transformed current-pose triangle geometry, normalized
for translation and uniform scale and quantized to one millionth of the longest
extent. It ignores triangle/vertex order, winding, materials, UVs and normals,
while retaining repeated triangles. The current run reports 7,717 static geometry
groups. These are grouping aids, not certified model families: alternate
triangulation, rotations, animation and source lineage still need review.

The added kits cover food/tableware, furniture-like props, animals/characters,
vehicles, rail and watercraft, industrial equipment, geology/caves, routes,
modular construction and further fantasy/modern/space scenery. Category and
theme coverage must be reviewed per model; a kit name is not a physical role.

## Reproducible acquisition and publication

- `tools/phanes.discover.kits.lpr` reads the creator's four current 3D catalog
  pages, downloads original free archives and writes a candidate lock under
  ignored `build/asset-research/`. Source discovery never automatically replaces
  the committed lock. Its date and archive counts are acquisition metadata.
  Its optional `kaykit` mode discovers the creator's public GitHub repositories
  and pins exact source commits and archives.
  Its `quaternius` mode reads the creator's original OpenGameArt submissions and
  verifies actual archive contents. Paid-edition headlines and sample rigs from
  animation libraries are not added to model counts.
- `data/kits.lock.json` retains author, original source/download URL, retrieval
  date and archive SHA-256. The six original pins are preserved. The derived
  batch also preserves all 62 previously imported kit pins.
- `tools/assets.ps1 -Action import-kits` runs the Pascal importer. It validates
  manifest IDs, selected archive paths and bounds, unique output IDs, glTF 2.0/GLB
  metadata, retained CC0 notice and exact local image/buffer dependencies.
  Original glTF/GLB models and textures are copied without transformations.
  Separately declared `derived.obj.v1` kits retain original OBJ/MTL files and
  use a pinned, bounded Pascal conversion recipe with complete evidence; see
  [ASSET_CONVERSION.md](ASSET_CONVERSION.md).
  Explicit `modelFormat` chooses GLB, glTF JSON or mixed glTF 2.0 files.
  Mixed representations that collide on a stable output ID reject the import.
- An explicit `dependencyAliases` mapping repairs a source export's broken local
  texture paths by copying original dependency bytes to the declared location.
  Canonical, case-exact source/target paths, unchanged hashes, no collisions and
  no alias chains are enforced. Models and textures are not rewritten. The
  Fantasy Props archive requires 13 such texture aliases, retained in provenance.
- The Modular Sci-Fi MegaKit adds 191 original glTF files with 53 texture-path
  aliases and one explicitly reviewed binary-path alias. For archive
  `4ca9acbc7a13e7baa48e24c4853b779889b7ab21587004c36668826e705c8a10`,
  the supplied `Decal_Line_90.bin` matches the glTF reference to
  `Decal_Line_90_001.bin`. Independent decoding matches all 30 positions,
  face-corner normals/UVs and 28 triangles to the same archive's 14 OBJ quads,
  within the original six-decimal rounding. Four corrupted-data controls reject.
  This is an exact source repair; no general binary renaming heuristic was added.
  The source audit verifies all 1,021 dependency references and preserves every
  prior inventory row. Evidence: `build/critic/scifi-bin-review-01.md` and
  `scifi-alias-evidence-01.json`. This batch adds 179 static geometry groups.
  The current publication audit checks all 56 optional packages, all 7,692
  shared file blobs and both root/project deployment paths. Every prior package
  hash remains unchanged. Evidence: `build/critic/catalog-files-review-04.md`.
- Optional creator-page license evidence is a separate reviewed source mode.
  Exact pinned HTML is preserved as `SourceLicense.html`; the DOM validator checks
  the real author, archive link and CC0 license element, excluding comments and
  inert content. It cannot replace a bundled notice. The original 60 single-archive kits
  retain their own bundled notices; the derived batch adds 16 bundled notices
  and 30 explicit creator-page notices. Base Mesh uses the separate collection
  evidence adapter described below.
- Every extraction uses a fresh staging directory. Dependency paths must match
  selected archive members with exact filename case. A successful new kit is
  published by one directory rename; existing selected files must already match
  byte for byte. Complete unlisted kits can remain if a later kit fails.
  The inventory is published atomically only after the entire import succeeds.
- `verify-kits` checks model, dependency and license hashes, as well as existing
  palette references. `summarize-catalog` produces `data/catalog-summary.json`.
- `tools/catalog-inspect.ps1` compiles the Pascal inspector against the pinned
  Castle source. It records complete scene bounds and triangle counts, with
  failures explicitly quarantined. This is native development tooling; the
  application target remains web.

The independent critic exercised 15 isolated importer cases, including malformed
paths, duplicate manifests, empty selections, incomplete destinations, stale
staging files and dependency case mismatches. Separate verifier fixtures reject
changed texture, buffer and license bytes. Evidence is retained under
`build/critic/asset-importer-review-03.md` and the referenced probe logs.
Three critic-owned Pascal programs retain 324 independent assertions: 142 for
import/verification, 97 for creator-page evidence and 85 for dependency aliases.
Run `tools/test-kits.ps1`; CI runs these offline suites before publication.
The static geometry grouping has a separate 26-check critic fixture, including
real recolors, scene transforms and unused coordinate outliers. Run it with
`tools/catalog-inspect.ps1 -WithTests`.

## Web packages

The original core models remain under `cge/data/kits`. The added 102 kits live
under `assets/library/kits`, outside Castle's eager startup archive.

`package-catalog`, also invoked by `build-web.ps1`, verifies the inventory and
writes one content-hashed ZIP per optional kit under `build/web/library`.
Packages contain only inventoried models, their verified dependencies and the
original notice. Their index is `build/web/data/library-packages.json`.
Archive entries use ordinal path ordering, fixed timestamps and explicit
portable attributes. Stream-backed compression preserves those settings.

At the 5,671-model checkpoint, the independent critic decompressed every package and matched the exact
inventory closure: 4,766 optional models in 6,078 files, with 251,211,572 total
ZIP bytes. Moving identical source bytes to another directory and changing
file times produced all 54 identical package hashes and an identical index.
The startup ZIP remained 6,046,795 bytes with exactly 905 core models.
All 13 alias source files also match the pinned original archive. Evidence is in
`build/critic/package-audit-evidence-03.json`.

The 6,925-model checkpoint audit verifies 55 optional packages containing 6,020
models in 7,333 files: 274,132,737 compressed bytes and 435,877,005 expanded bytes.
All 55 ZIP hashes reproduce after relocation, reversed file creation order,
changed timestamps and repeated publication. All previous 54 package rows remain
identical. Startup remains 919 files and 905 models in the same 6,046,795-byte ZIP.

Some optional packs are 40–79 MB, so whole-kit downloads are unsuitable for many
small-object interactions. The publisher now also writes shared content-addressed
files under `library/blobs` and a separate lazy manifest for each kit. The small
`data/library-files.json` index points to those manifests; each model lists its
exact local filenames, source hashes, shared blob URLs and download bytes.
Notices retain their own hashed file entry. This permits per-model dependency
loading and cross-model reuse without downloading an entire kit. The admitted
runtime now uses this path. The editor's startup source count uses the small summary and
does not require the full inventory or block palette readiness if the count fails.
That checkpoint's LF-bound critic audit verified all 6,050 shared files, 6,891 original
external dependency URIs and both root/project HTTP paths. Reordered file
creation, relocation and changed timestamps reproduce every package, lazy
manifest and index. Desktop and phone startup checks also pass with the optional
summary request deliberately unavailable. Evidence is retained in
`build/critic/catalog-files-review-02.md` and the catalog browser logs.

That checkpoint's fine-file audit verifies 7,305 shared blobs totaling 429,868,609 bytes,
12,966 model/notice references and the same 6,891 original dependency URI checks.
Both hosting paths pass 240 HTTP hash checks each, covering all 55 manifests and
notices plus sampled model closures. Exact compressed source-page evidence stays
outside runtime downloads. Current evidence is retained in
`build/critic/catalog-files-review-03.md`; desktop and phone startup checks pass
with the 6,925-model summary and a deliberately unavailable optional summary.

The deployment stage now includes only the current shared-file closure, avoiding
duplicate bulk ZIPs and obsolete catalog generations. The same 6,925-model
snapshot stages to 570,685,917 bytes, with a 900,000,000-byte publication budget.
Its immutable output and CI hosting flow are documented in [PUBLISHING.md](PUBLISHING.md).

The previous 7,116-model snapshot publishes 56 optional packages and 6,211 optional
models. The independent audit preserves all 55 earlier package rows and hashes.
The new fine-file closure has 7,692 distinct blobs totaling 443,396,814 bytes,
14,179 file references and 7,912 checked original dependency URIs. The current
Pages stage is 585,339,654 bytes across 7,790 files. Startup remains the original
905 models in the same 6,046,795-byte ZIP.

## Multi-archive collection acquisition

The imported Base Mesh snapshot adds 1,254 models whose original downloads span
small household objects, tools, instruments, medical objects and other
categories. Discovery and curation are Pascal programs:
`tools/phanes.discover.basemesh.lpr` and `tools/phanes.curate.basemesh.lpr`.
They retain original archives and compressed, byte-exact source pages, then write
a candidate lock without replacing the catalog. The reviewed snapshot
`basemesh-20260908` is now included in the measured counts above.

The independent acquisition audit checked every original archive and source page,
preserved all 60 prior kit pins and all 5,671 prior inventory rows, and excluded
the 1,254 OBJ plus 1,254 FBX format alternatives. This batch's source tags include
112 industrial, 90 tools, 92 kitchen, 63 food, 52 furniture, 45 technology,
27 music/instrument and 17 medical entries. There are 30 tags in total; these
memberships overlap and do not increase the 1,254-model count. Tags describe
source categories and do not grant physical or gameplay capabilities. Evidence:
`build/critic/basemesh-acquisition-review-01.md`.

The selected GLBs total 52,190,916 bytes. Their compressed original web-page
evidence totals 235,139,815 bytes and stays in developer provenance, outside
runtime model downloads.

The explicit `collection.v1` source mode groups multiple pinned archives under
one snapshot kit. Each source has its own namespace, exact original model member
pins and source-page/archive relationship. A complete fresh collection stage is
published atomically; a failed later source preserves the previous inventory.
Existing snapshots remain immutable. Format copies are not additional assets.

The dedicated Base Mesh evidence adapter verifies the publisher's collection
FAQ and each model page separately. Exact common FAQ bytes remain an explicit
notice; compressed original page evidence stays outside runtime packages.
The adapter does not assign sole authorship to the collection publisher or
override bundled notices. Source namespaces prevent cross-archive texture
borrowing. The independent source-evidence suite currently passes 58 checks;
the collection importer passes 126 independent checks covering source isolation,
transactional publication, exact provenance, malformed counts and deterministic
publication. These are importer results, not playable asset admission.

Package hashing, copying and byte measurement stream large ZIPs. A collection
does not imply an eager full-collection download: shared per-model publication
remains the intended runtime boundary. Six critic-owned importer/evidence/file
suites pass 542 checks, including a file larger than 128 MiB compared with an
independent platform hash. The separate Pages staging fixture adds 525 checks;
`tools/test-kits.ps1` now runs ten suites (38,122 checks), including 27,622 planar
conversion assertions, 8,999 surface conversion assertions and 434 derived
importer checks. The separate static geometry fixture adds 26 checks.

This is packaging infrastructure. The game does not yet browse or demand-load
these optional kits. The runtime still needs loading/progress/cancellation,
bounded parsed-model ownership and placement integration before optional models
are player-available.

## Required coverage and remaining admission

The expansion must increase useful choices throughout the hierarchy:

| Category | Admission work |
| --- | --- |
| Terrain and geology | Ground contact, cliffs/caves, valid height and traversal |
| Trees, groundcover, flowers/fungi and crops | Distinct families, scale, biome support, growth variants |
| Complete structures | Foundation fit, fronts/doors, access and interior ownership |
| Modular construction and routes | Walls, fences, bridges, pads, paths and matching connectors |
| Furniture and fixtures | Seating, storage, sleeping, kitchen, bathroom, office, lab and workshop |
| Individual contents | Food, tableware, books, tools, instruments, electronics and decorations |
| Industrial/scientific equipment | Mounts, operating clearance, utilities and explicit functions |
| Vehicles | Land, rail, water, air and space; placement distinct from driving behavior |
| People and animals | Distinct designs, metre scale and verified animations where advertised |
| Surfaces and effects | Coherent realistic detail and particles, counted separately from models |

Further acquisition to reach a numerical target is paused at the user's request.
The next work is category review, coherent physical/material profiles, optional
loading and placement integration for the accepted catalog. Source listings and
paid-edition headlines are not imported counts.
The staged fetch, Castle loading, placement and lifetime contract is documented
in [CATALOG_RUNTIME.md](CATALOG_RUNTIME.md); implementation and bounded evidence are
recorded in [CATALOG_PUBLICATION.md](CATALOG_PUBLICATION.md).

The new pure Pascal OBJ conversion recipes and measured original-source probes
are documented in [ASSET_CONVERSION.md](ASSET_CONVERSION.md). The surface recipe
converted 1,258 source files spanning older nonbuilding and building packs.
After independent source/geometry/notice review and removal of nine exact
OBJ/MTL duplicates, 1,249 are included in the current catalog. Native Castle
decode, conversion evidence and physical player admission remain distinct checks.

Additional free KayKit source research is retained under ignored
`build/asset-research/itch/`, outside the active lock and inventory. The unfinished
frontend acquisition adapter is parked there too; it is not a production source
mode or a completed importer. No count-driven acquisition is needed to finish
the accepted expansion.

`tools/phanes.discover.polyhaven.lpr` also evaluates original 1k glTF exports via
the publisher's public API, using an application-specific User-Agent. Its 521
model listings yield 519 discovery candidates with 3,121,198,410 declared file
bytes; one lacks a 1k glTF export and one has a 948,849,556-byte geometry buffer.
No Poly Haven models have been imported or added to the counts above. Texture
tiers do not lower geometry complexity or multiply the number of source models.
This full set exceeds the Pages budget, so any acquisition needs a measured
selection and physical/material review. Publisher metadata retains original case,
author credits and dependency URLs, including shared buffers stored under other
texture-tier paths. The independent design audit is
`build/critic/polyhaven-acquisition-design-01.md`.

The searchable catalog needs separate function/theme filters, scale-aware
preview, contextual placement and responsive desktop/phone journeys. Physical
compatibility must use measured geometry and explicit constraints. Downloading
more files cannot satisfy this step. Shared materials must retain Phanes'
stylized forms with realistic surface detail across unrelated themes.

The full `catalog-expansion` feature is registered with no passing review.
All four critic categories must reach B+ after acquisition, usable coverage,
visual consistency and performance are exercised together.

The regional editor now browses its admitted palette through category, subgroup
and exact-item choices, with search and explicit Apply to selection. Group
requests restrict WFC to the displayed subgroup while preserving the complete
vocabulary for unselected cells. See [AUTHORING.md](AUTHORING.md). This improves
control over the core and optional regional choices. Optional source geometry is
downloaded only when required by an accepted edit or restored world; first-world
creation uses the core catalog. Most of the accepted library still needs placement
profiles and category-specific integration.
