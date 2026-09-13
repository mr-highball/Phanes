# Usable catalog integration

The `catalog-integration` branch adds **991 selectable models** from existing
downloads. The source inventory remains 8,365 files; no models were collected.

| Batch | Screened | Newly passed | Set aside | Already integrated |
| --- | ---: | ---: | ---: | ---: |
| Floor props, food and seating | 915 | 553 | 347 | 15 |
| Outdoor nature | 343 | 237 | 90 | 16 |
| Equipment and adventure props | 732 | 201 | 523 | 8 |
| Total | 1,990 | 991 | 960 | 39 |

These batches cover different source kits. Another 6,375 source models remain
outside their scope; they are not counted as failures.

The complete optional catalog now contains **1,031 source models**, up from 40.
These are source-file counts, not a claim of 1,031 distinct geometric designs.
Core and procedural choices are additional.

## Using the additions

Open the home builder. Search the catalog under **Imagine on this floor**, or
paint existing floors and search the **Furniture** selector for density population.
Search matches category, model name and source kit. Existing default mixtures
remain small; choosing an exact model also uses a small solver domain.

The first batch contains static props, food, seating, storage decorations and plants.
They are placed on modular floors, one object per occupied tile. They do not add
editable shelves, tabletop supports, working lights, containers or animations.
Uniform scales normalize the longest dimension to 0.22 m for food, 0.45 m for
general props, 0.65 m for storage props, 0.9 m for seating and 0.6 m for plants.
Per-model scales and millimetre bounds are recorded in the manifest. These are
practical display sizes, not manufacturer dimensions.

The nature batch adds **97 trees, 76 crops, 36 rocks, 20 shrubs and 8 flowers or
mushrooms**. Choose Forest, Flowers or Field in world tools, then a group or exact
item. The landscape palette now has 274 entries. Existing terrain compatibility,
tree/rock collision and selection preservation rules apply. Default creation
keeps its core models; new nature models load when explicitly selected.

Nature models are uniformly scaled within their role envelopes: trees up to
6 m tall and 3.6 m wide/deep; shrubs up to 1.5 m; rocks up to 2.2 m; flowers up
to 0.55 m; crops up to 1.2 m. Bounds include outward millimetre padding.
Large foliage groups use a deterministic, seed-selected subset of at most eight
models per application. Every admitted model remains individually selectable.

The equipment batch adds **79 artifacts, 78 equipment props, 25 containers,
11 sculptures and 8 technology props**. Use the home-builder search and density
controls, just like the first floor-props batch. They are static display props;
containers do not open, tools are not usable equipment, and machinery is not
simulated. Uniform longest-axis targets are 0.3 m for artifacts, 0.7 m for
equipment, 0.8 m for containers, 1.2 m for technology and 1.4 m for sculptures.

## Pass/fail ledger and quick workflow

[`data/catalog-integration.json`](../data/catalog-integration.json) records every
screened source ID, hash, status and reason. Passing rows also include the runtime
asset ID, scale, dimensions, triangles, texture pixels and pinned kit manifest.
`existing` and `outsideBatch` are separate from failures. A failed model is deferred,
not removed from the source library.

[`data/catalog-integration-nature.json`](../data/catalog-integration-nature.json)
records the nature batch separately, preserving the first ledger. Its 90 failures
include structural/attached parts (33), harvested produce (16), texture budgets
(3), masked/blended foliage materials (13), triangle budgets (12), download
budgets (8) and unsupported roles (5). The alpha-material exclusion follows a
poor browser visual sample; these models need a separate material review.
Its generated registry is `src/phanes.catalog.nature.inc`.

[`data/catalog-integration-equipment.json`](../data/catalog-integration-equipment.json)
records the equipment batch; `src/phanes.catalog.equipment.inc` is its registry.
The 523 deferred entries include structural/attached parts and effects (257),
models outside this category (146), furniture needing supports (32), download
budgets (70), texture budgets (11), triangle budgets (4), degenerate bounds (2)
and animation (1). Both previous ledgers remain intact.

The native Pascal importer reuses the existing CGE geometry report. It verifies
the inventory fingerprint, published kit manifests, model closures and file hashes;
checks static glTF/GLB metadata; measures PNG image dimensions; and applies bounded
floor or outdoor role dimensions, 5,000-triangle, one-megapixel and four-MiB source budgets.
It never re-decodes the full corpus, downloads assets or repairs rejected models.
The generated registry is `src/phanes.catalog.batch.inc`.

Failures in the floor-props batch: 236 need structural, wall, terrain or special placement;
110 need furniture supports or larger footprints; one contains animation.

```powershell
# Check all admitted profiles through the actual placement solver.
./tools/catalog-batch.ps1

# Re-screen the existing published library, regenerate registry/ledger, then check.
./tools/catalog-batch.ps1 -Regenerate -PublishedRoot build/web

# Check nature placement, or re-screen nature and refresh the landscape palette.
./tools/catalog-batch.ps1 -Category nature
./tools/catalog-batch.ps1 -Category nature -Regenerate -PublishedRoot build/web

# Equipment-only validation or regeneration, without repeating the older batches.
./tools/catalog-batch.ps1 -Category equipment
./tools/catalog-batch.ps1 -Category equipment -Regenerate -PublishedRoot build/web
```

Pass means mechanically admitted, not individually visually reviewed. The batch
checks include exact-model placement and reconstruction of existing furnishings.
Rendering uses the existing on-demand loader and its unchanged residency limits.
The browser sample covers a Kenney GLB apple, a KayKit glTF chair and a Quaternius
GLB chair on desktop and phone-sized layouts. It exercises search, density and
actual optional-model loading. Physical-phone testing is not included.

Build with `./build-web.ps1 -SkipCatalogPackaging` when the published library is
already present. The browser driver is
`tests/phanes.tests.population.browser.lpr`, invoked with
`BROWSER URL EVIDENCE --catalog-batch`. Evidence belongs under ignored `build/`.
No critic loop or full-corpus gate is needed for this scoped batch workflow.

Verified on 2026-09-13: web release build passed; 3,769 native assertions passed
(including all 553 new profiles); 60 desktop/phone-layout browser assertions passed.
The importer produced identical output on a repeat run against the same sources.
Local evidence: `build/catalog-integration-01/`.

Nature evidence is under `build/catalog-nature-01/`. The native suite places all
237 models through the world generator, checks unchanged cells, tests bounded
group mixtures and replays them deterministically. The browser driver is
`tests/phanes.tests.catalog.nature.browser.lpr`, invoked with `BROWSER URL EVIDENCE`;
it samples each of the five roles and checks actual renderer admission.
Verified on 2026-09-13: final web build and UI compilation passed; 42,079 native
assertions covered all 237 nature models; 36 browser assertions passed, including
the five role samples, phone-layout undo/redo and group rock placement. Evidence:
`build/catalog-nature-01/browser-final/`. The previous props ledger and generated
registry were also regenerated and remained byte-identical.

Equipment evidence is under `build/catalog-equipment-01/`. The native check covers
every new profile using actual floor placement and existing-object reconstruction.
The population browser driver accepts `--catalog-equipment` to sample a textured
factory machine, an untextured potion and a KayKit gravestone on desktop and
phone-sized layouts. Each sample checks search, exact density placement and
renderer admission. Individual visual review of all 201 models is not claimed.
Verified on 2026-09-13: web build passed; 1,657 native assertions covered the new
equipment profiles and existing building behavior; 72 desktop/phone-layout browser
assertions passed. All three ledgers and generated registries reproduced exactly.
