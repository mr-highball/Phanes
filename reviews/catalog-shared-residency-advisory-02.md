# Luna bounded catalog shared-residency adoption review 02

- **Critic:** Luna (independent critic)
- **Date:** 2026-09-13
- **Repository:** `Phanes`, branch `hello-phanes`, reviewed HEAD `4827875b37ea1bf3f296ddab185e8b147431cf3e`
- **Engine:** `e52f3eeb40ad5a1e3dad1380cf6ec0902ec68379`, unchanged
- **Scope:** renewal of the source namespace pool, aggregate source budget, texture-profile union, production residency staging/release path, and retained native/application/WebGL evidence. This is bounded development adoption advice. It does not approve the full catalog, furniture admission, physical-phone performance, total decoded/GPU budgeting, or release.
- **Method:** independent source inspection and representative desktop/phone application capture review, reusing retained successful evidence; no duplicate builds or GPU runs.

## Decision

**Bounded development adoption recommended.** Review 01 contained an inaccurate statement that production staging remained isolated. The current production path at `phanes.catalog.residency.pas:278–285` acquires an exact kit/manifest namespace from `TCatalogSourcePool` and passes that store to `CatalogBundleFromBrowser`; the bundle constructor consequently uses shared source storage. The regional application evidence records 18 models across five namespaces, 1,104,190 unique source bytes versus 1,217,856 closure bytes, and 786,432 union texture pixels. The world, regional and object journeys pass with release/reacquisition evidence, while the dedicated WebGL fixture independently confirms actual atlas sharing and context recovery.

The correction to review 01 is factual and material: this report supersedes its isolated-production wording. Full feature and release gates remain separate.

## Grades

- **Intuitiveness — A-:** Source pool, namespace store, texture profile and resident lease roles are visible in the API and diagnostics. `sourceBytes`, `closureSourceBytes`, `sourceNamespaces` and union `texturePixels` make the different budgets inspectable.
- **Accuracy — A:** Production staging now uses pooled exact kit/manifest stores, reserves unique source bytes globally, keeps complete per-bundle closure accounting, checks conservative texture union before GPU preparation, and releases scene/bundle before namespace. Retained regional/world/object journeys and the 72-check WebGL witness exercise the relevant release, reload and context-loss paths.
- **Wow factor — A-:** Actual application evidence carries shared resources through 18 regional models and cross-world/object workflows, while the controlled WebGL witness renders eight complete real closures with one atlas/upload and preserves identical pixels through release/reload and a fresh context.
- **Thinking out of the box — A-:** The design separates source identity by manifest revision, decoded-image claims from sampler allocations, closure bytes from unique bytes, and derived template retirement from scene/file release. The tests check real publication and distant ownership rather than only a synthetic cache counter.

## Findings and limits

1. **No bounded implementation blocker found.** `TCatalogSceneStore.StagePending` validates admission and root hashes, acquires the pooled namespace, stages through the shared constructor, profiles textures before `PrepareResources`, and transfers ownership into `TResidentModel`. Failure paths release the temporary bundle/store; retirement frees derived templates, scene lease and then namespace. The source pool owns the aggregate budget; namespace stores borrow that budget and are released only after their files are gone.
2. **External ownership remains an integration obligation.** Direct callers of `TCatalogFileBundle` or `TCatalogSharedFiles` must preserve the documented lifetime ordering. Production residency satisfies this through `TCatalogSceneStore` → `TResidentModel` → scene/bundle → namespace/pool teardown. A future caller must not destroy a borrowed pool/store while a bundle or scene lease remains live.
3. **The accounting claims are deliberately bounded.** The 16 MiB source cap is unique retained source bytes across namespaces; closure bytes are reported separately. The 4,194,304 texture limit is a conservative union of profile claims before GPU preparation. Actual WebGL live-atlas/upload observations corroborate this fixture, but neither metric is total decoded memory, all driver allocations, or a GPU-byte budget.
4. **Application and release limits remain explicit.** The application now exercises the production shared path, but the retained browser journeys cover 18 regional models, 14 optional interior objects and bounded world cases. The eight furniture models are diagnostic fixtures, not admissions; phone captures are emulated; physical performance, all-catalog playability and release/Pages acceptance remain held. The independent `99b8df3a` project-path fruit-picking failure remains a separate retained limitation.

## Evidence reviewed

- `build/catalog-sharing-app-01/provenance.json`: canonical raw-byte source/runtime/evidence index binding current residency source, production drivers, fixture manifest/probe, all retained artifacts and engine commit. Native 365, world 81, regional 129, objects 188 and GPU 72 checks are recorded.
- `build/catalog-sharing-regional-01/resident-all.json`: 18 models, 5 namespaces, 1,104,190 unique source bytes, 1,217,856 closure bytes and 786,432 union texture pixels under unchanged 16 MiB/4,194,304 caps.
- `build/catalog-sharing-world-03/result.txt`, `build/catalog-sharing-regional-01/result.txt`, `build/catalog-sharing-objects-01/result.txt`: production shared-path journeys pass 81, 129 and 188 checks, including cancellation/history, retirement/reacquisition, distant ownership and context recovery in their declared scopes.
- `build/catalog-sharing-wrapper-02/evidence.json` and `checks.log`: 72 actual WebGL checks, including shared eight one-atlas/one-upload, sampler variant two allocations over one decoded image, partial release/reload, fresh context and predicted/actual pixel agreement.
- `build/catalog-sharing-world-03/focused-vase-phone.png`, `modular-book-desktop.png`, `build/catalog-sharing-objects-01/recovered.png` and `build/catalog-sharing-regional-01/trees-models.png`: representative actual application desktop/phone-emulated captures with visible geometry and controls. They do not establish physical-phone performance.
- `docs/CATALOG_PUBLICATION.md` and `docs/VERIFICATION.md`: current production sharing path, ownership and bounded-qualification wording.

## Reviewed input fingerprints

Hashes below were generated with `build/tools/phanes.reviews.exe hash`; the canonical application provenance binds the full current source/test/runtime set. Key changed production paths, drivers and fixture inputs are listed explicitly.

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
tests/catalog-shared-runtime/CastleEngineManifest.xml     0e465cfe85264f6aa3c13b4ce2da019b93c4af7518438ebbc098b092c3ec5850
tests/catalog-shared-runtime/code/phanes.tests.catalog.shared.gpu.pas cabe30d4017c33abad7ebef1b04d206d9d8806528b9d68e420f380d703608fd5
tests/catalog-shared-runtime/probe.html                   2bf86a04ae6228ac05668ce1567cfd41276a9c2af62a8b19730b812a941205ed
tests/phanes.tests.catalog.files.lpr                      21b7f7062dcecea6a1f11009133adebf8e9f5e1387418f93f0175777b66a3af1
tests/phanes.tests.catalog.objects.browser.lpr            9751787a781a347f7ec6da558fd208e0f159d72de29f8ac20925956d0e4a7060
tests/phanes.tests.catalog.regional.browser.lpr            4540e0e37319b279f4663997883abea9b095ecdee99cc3ac2f9675e51d3e9bea
tests/phanes.tests.catalog.shared.gpu.browser.lpr         7c3131c3931a43a7f3d5fa26830bf152ed78ed189b33ad45850ef2cd35f4f4d2
tests/phanes.tests.catalog.textures.pas                   5e184cd55eac8e60ff053c0b6f56b7530c4ee862ec6ba8cef06e7d7e691586d6
tests/phanes.tests.catalog.world.browser.lpr               013613f25ba3d1f7c4f2644c36130909b96cf43bc0c8b8a57b18efe2a3356793
tools/test-catalog-shared-runtime.ps1                      6cc79cc057ed09e658d6942a658cd7f361c9d59c11fab6a8f4d4bdd7f44cb103
build/catalog-sharing-app-01/provenance.json               6ca63c852ea4cc6f9a56e5abaf6dae0d54a679a6807418a909cea3ce14250b25
build/catalog-sharing-regional-01/resident-all.json        2acc5a44aa2323acaf456de9a188479a929675c4dc37b139f83ded4517e3ad49
build/catalog-sharing-wrapper-02/provenance.json           f9b9affcee73f161bfe94052f4f9c5f8824c54be841a08a99e0e801683ab14dd
build/catalog-sharing-wrapper-02/evidence.json              27809979b81b5066623ef9380814ab17c8392f84c39a5e1b2e8c239e9749df12
```

No implementation, registry, or prior critic report was edited by this review. Report 01 is retained as historical evidence; this report corrects its production-staging statement.

