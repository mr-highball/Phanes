# Luna bounded catalog shared-residency adoption review

- **Critic:** Luna (independent critic)
- **Date:** 2026-09-13
- **Repository:** `Phanes`, branch `hello-phanes`, reviewed HEAD `4827875b37ea1bf3f296ddab185e8b147431cf3e`
- **Engine:** `e52f3eeb40ad5a1e3dad1380cf6ec0902ec68379`, unchanged
- **Scope:** source namespaces and aggregate source budget, texture-profile union accounting, residency staging/release ordering, and the retained native/application/WebGL witnesses. This is bounded development adoption advice. It does not approve the full catalog, furniture admissions, physical-phone performance, total decoded/GPU memory budgeting, or release.
- **Method:** focused source inspection, representative image inspection, and retained evidence review; no duplicate builds or GPU runs.

## Decision

**Bounded development adoption recommended.** The integration now makes the shared path explicit and conservative: exact kit/manifest namespaces share immutable source files under one 16 MiB aggregate budget, while each bundle continues to account its complete closure. Texture claims are formed before GPU preparation and distinguish image/sampler state, so an identical decoded image can share pixels while a sampler variant receives a separate allocation. The retained 72-check WebGL fixture demonstrates one live atlas for eight compatible models, a second allocation for a sampler variant, partial release/reload and actual context loss/fresh-page recovery. The application retains its isolated constructor and therefore does not claim production residency sharing.

## Grades

- **Intuitiveness — A-:** The source-pool, shared-store and texture-profile responsibilities are separated clearly, diagnostics distinguish unique source bytes from closure bytes, and the documentation states borrowed-store/pool lifetime and the limits of each counter.
- **Accuracy — A-:** The pool keys by exact kit plus manifest SHA, reserves unique bytes before allocation/read, releases only after scene/bundle destruction, and rejects stale or conflicting source identity. Texture profiles fail closed for missing/underdeclared known images, include sampler/filter properties, union identical claims, and enforce the existing 4,194,304-pixel cap before `PrepareResources`.
- **Wow factor — A-:** Eight real glTF scenes retain identical 3,146-triangle geometry while source bytes fall from 290,028 to 175,004 and decoded/GPU atlas count falls from 8 to 1. The browser witness confirms the same behavior through actual WebGL upload observations, including reload and context recovery.
- **Thinking out of the box — A-:** Namespace identity prevents cross-manifest aliasing, complete closures retain notices, texture profiles separate decoded-image identity from sampler allocation, and release tests exercise derived template retirement, source reacquisition and context loss rather than stopping at initial rendering.

## Findings and limits

1. **No bounded implementation blocker found.** `TCatalogSharedFiles.AcquireFile` validates and bounds the stream, preserves its position, reserves aggregate budget before copying, rolls back reservation on any failure, and compares existing bytes before increasing references. `TCatalogSourcePool.Release` rejects final namespace release while files remain live. `TCatalogSceneStore` frees scene lease before namespace release and recomputes the texture union after retirement.
2. **External ownership remains an integration obligation.** The explicit shared-store constructor borrows its store, and the source pool borrows its aggregate budget through its namespace stores. The documented owner ordering is correct and tested, but integrating code must keep the pool/store alive until all bundles and scenes are destroyed; premature destruction would make later release unsafe.
3. **Texture accounting is conservative but bounded in meaning.** The 4,194,304 figure is a union of declared/profile pixel claims before GPU preparation. The evidence includes actual live atlas/upload observations, but it is not a total decoded-memory, driver allocation or GPU-byte budget. Unsupported texture kinds use opaque declared cost; production admission must continue to reject or conservatively declare such assets rather than treating this fixture as universal coverage.
4. **Production sharing is not yet enabled.** Browser staging and the retained application journeys use isolated construction; the shared path is exercised by the dedicated WebGL fixture. The 72 checks and application/regional/object/world evidence support safe integration groundwork, not full catalog, eight-furniture playability, physical phone, or release acceptance. The independent Actions `99b8df3a` project-path fruit-picking failure remains retained and is outside this change.

## Evidence reviewed

- `build/catalog-sharing-app-01/provenance.json`: canonical source/runtime/evidence index; native 365, world 81, regional 129, objects 188 and GPU 72 checks; engine binding, 16 MiB/32-model/4,194,304-pixel caps and limitations.
- `build/catalog-texture-profiles-01/results.txt`: native storage/profile and WASI checks, including real closure measurements.
- `build/catalog-sharing-wrapper-02/evidence.json` and `checks.log`: 72 real WebGL checks. Shared eight: one live atlas, one upload, profile agreement; sampler variant: two allocations with one decoded image; release/reload and context-loss/fresh-page states all error-free.
- `build/catalog-sharing-world-03/result.txt`, `build/catalog-sharing-regional-01/result.txt`, `build/catalog-sharing-objects-01/result.txt`: retained application journeys pass 81, 129 and 188 checks respectively, with retirement/reacquisition and zero browser errors in their declared scopes.
- `build/catalog-sharing-wrapper-02/shared-eight.png` and `shared-eight-phone.png`: representative desktop and emulated-phone renders showing all eight furniture scenes with identical content between isolated/shared captures. These images do not establish physical-phone performance.
- `docs/CATALOG_PUBLICATION.md` and the current `docs/VERIFICATION.md` residency checkpoint: explicit source/texture semantics and qualification boundaries.

## Reviewed input fingerprints

Hashes below were generated with `build/tools/phanes.reviews.exe hash`; key artifact values are from the canonical provenance/evidence index.

```
cge/code/phanes.catalog.files.pas                         bcf268ee6e804fc6794bc2571ec6662217db4777f140479200ab6662b3304813
cge/code/phanes.catalog.paths.pas                         ec935bb433eef4302a686a2c839943a94a6357e6cf276b2826ec6c2cd870a229
cge/code/phanes.catalog.residency.pas                    a54a9f795a43b6be38c8961f1ad4c2d1710f48828e69f792862aba61b6936565
cge/code/phanes.catalog.scene.pas                         136bd724f9cee0a99a99442c4e7e364b8ec7909d5b94eb90aa6447a7d12e0c51
cge/code/phanes.catalog.shared.files.pas                 519546e58a6c3d04047e657b350164f25e3e3bb1d1b319ff0a40dbecde8de623
cge/code/phanes.catalog.sources.pas                      f20b1e3d81334172a5d7be5e0519af6cf413fe43b6aae5329610618b6f625c9a
cge/code/phanes.catalog.textures.pas                     4d0df14aad3e169a8c851734e9d0c91d4db2a3ca0de4115520fa57232dfa71f8
cge/code/phanes.world.surfaces.pas                       4ca46d9d8d321bbd1edc17ed9da86f17af493505148297791a46ae435fe2436c
src/phanes.catalog.admission.pas                          099ef8870fcd55f636d9e8dbda82e0651775bd82249738d38886750064b775fc
src/phanes.catalog.objects.pas                            3b23fbbbffbb57a6d43a9b39a521d1c81ad87419535e83f778c0cd21e27b19f0
src/phanes.catalog.regional.pas                           267da0acdab8a8df53ed1ceec9db79f1d6912a13e439112cf100449ae65d34ec
src/phanes.world.appearance.pas                           ffa1c3a0f2d77e330b51b76f449ebffcee63097a363225b92e51497c668a291c
tests/catalog-shared-runtime/code/phanes.tests.catalog.shared.gpu.pas cabe30d4017c33abad7ebef1b04d206d9d8806528b9d68e420f380d703608fd5
tests/phanes.tests.catalog.files.lpr                      21b7f7062dcecea6a1f11009133adebf8e9f5e1387418f93f0175777b66a3af1
tests/phanes.tests.catalog.shared.gpu.browser.lpr         7c3131c3931a43a7f3d5fa26830bf152ed78ed189b33ad45850ef2cd35f4f4d2
tests/phanes.tests.catalog.textures.pas                   5e184cd55eac8e60ff053c0b6f56b7530c4ee862ec6ba8cef06e7d7e691586d6
tools/test-catalog-shared-runtime.ps1                      6cc79cc057ed09e658d6942a658cd7f361c9d59c11fab6a8f4d4bdd7f44cb103
docs/CATALOG_PUBLICATION.md                                718c3fb9cc6e9a68e2efb1f3974212599506853fdfd242aae6891399bb4f233a
docs/VERIFICATION.md                                       8c2398519ea7691b5a265e3f828ebfe7d75351062cbfe1b89844205bfb2f1614
reviews/features.json                                      9184714ec47ee84864446c8e57229d2be9ae408743c28331f9266039ac7ae00c
build/catalog-sharing-app-01/provenance.json               6ca63c852ea4cc6f9a56e5abaf6dae0d54a679a6807418a909cea3ce14250b25
build/catalog-sharing-wrapper-02/provenance.json           f9b9affcee73f161bfe94052f4f9c5f8824c54be841a08a99e0e801683ab14dd
build/catalog-sharing-wrapper-02/evidence.json              27809979b81b5066623ef9380814ab17c8392f84c39a5e1b2e8c239e9749df12
build/catalog-texture-profiles-01/results.txt              4a2f10b7175b07e90ad49baea52ab743449cd8c2556a78b731514cd2d0317bc9
```

No implementation, registry, or prior critic report was edited by this review.

