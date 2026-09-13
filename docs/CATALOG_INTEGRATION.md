# Usable catalog integration

The `catalog-integration` branch adds **553 selectable models** from existing
downloads. The source inventory remains 8,365 files; no models were collected.

| First batch | Models |
| --- | ---: |
| Screened | 915 |
| Newly passed | 553 |
| Failed / set aside | 347 |
| Already integrated, preserved | 15 |
| Outside this batch | 7,450 |

The complete optional catalog now contains **593 source models**, up from 40.
These are source-file counts, not a claim of 593 distinct geometric designs.
Core and procedural choices are additional.

## Using the additions

Open the home builder. Search the catalog under **Imagine on this floor**, or
paint existing floors and search the **Furniture** selector for density population.
Search matches category, model name and source kit. Existing default mixtures
remain small; choosing an exact model also uses a small solver domain.

This batch contains static props, food, seating, storage decorations and plants.
They are placed on modular floors, one object per occupied tile. They do not add
editable shelves, tabletop supports, working lights, containers or animations.
Uniform scales normalize the longest dimension to 0.22 m for food, 0.45 m for
general props, 0.65 m for storage props, 0.9 m for seating and 0.6 m for plants.
Per-model scales and millimetre bounds are recorded in the manifest. These are
practical display sizes, not manufacturer dimensions.

## Pass/fail ledger and quick workflow

[`data/catalog-integration.json`](../data/catalog-integration.json) records every
screened source ID, hash, status and reason. Passing rows also include the runtime
asset ID, scale, dimensions, triangles, texture pixels and pinned kit manifest.
`existing` and `outsideBatch` are separate from failures. A failed model is deferred,
not removed from the source library.

The native Pascal importer reuses the existing CGE geometry report. It verifies
the inventory fingerprint, published kit manifests, model closures and file hashes;
checks static glTF/GLB metadata; measures PNG image dimensions; and applies bounded
single-floor dimensions, 5,000-triangle, one-megapixel and four-MiB source budgets.
It never re-decodes the full corpus, downloads assets or repairs rejected models.
The generated registry is `src/phanes.catalog.batch.inc`.

Failures in this batch: 236 need structural, wall, terrain or special placement;
110 need furniture supports or larger footprints; one contains animation.

```powershell
# Check all admitted profiles through the actual placement solver.
./tools/catalog-batch.ps1

# Re-screen the existing published library, regenerate registry/ledger, then check.
./tools/catalog-batch.ps1 -Regenerate -PublishedRoot build/web
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
