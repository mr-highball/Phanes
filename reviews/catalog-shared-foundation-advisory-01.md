# Luna bounded catalog shared-foundation adoption review

- **Critic:** Luna (independent critic)
- **Date:** 2026-09-13
- **Repository:** `Phanes`, base commit `99b8df3af91c8d388be5f1626d524109a1d63d55`
- **Engine:** `e52f3eeb40ad5a1e3dad1380cf6ec0902ec68379`, unchanged by this work
- **Scope:** shared source-file store, bundle delegation, common path validation, optional shared-store constructor, scene-lease ownership tests, and their build/evidence plumbing. This is a bounded storage/refactor advisory. It does not approve production residency sharing, catalog admission, GPU texture sharing, physical-phone performance, full catalog or release gates.
- **Method:** focused source inspection and retained native/browser/application evidence review; no duplicate build, browser, or GPU run.

## Decision

**Bounded development adoption recommended.** The refactor preserves isolated bundle behavior while adding an explicit shared-store path with immutable exact-case files, reference-counted release, unique-byte accounting, unique protocol names and per-bundle closure accounting. The native witness exercises real glTF scenes and reload after partial release; the WASI bridge and fresh application build compile successfully. The retained browser journey remains the existing isolated constructor and therefore supports application regression only, not a claim that production staging now shares residency.

## Grades

- **Intuitiveness — A-:** The API has a simple owned constructor and an explicit externally supplied store constructor. Names and documentation state the source-byte budget, lease lifetime and isolated-versus-shared behavior. The native checks report useful ownership and byte-count outcomes.
- **Accuracy — A-:** `TCatalogSharedFiles` validates paths, rejects case-only aliases and conflicting bytes, reads into independent streams, restores input stream position, checks bounds before allocation/read, and removes entries after the last reference. `TCatalogFileBundle` retains complete closure accounting and rolls back failed acquisition; `TCatalogSceneLease` destroys the scene before its source bundle. The 328 native checks and 26 browser checks pass.
- **Wow factor — B+:** Eight real furniture closures retain identical 3,146-triangle geometry while the shared witness reduces decoded atlas images from 8 to 1 and source bytes from 290,028 to 175,004. This is a meaningful foundation result, with no unsupported GPU-memory claim.
- **Thinking out of the box — A-:** The change separates immutable source sharing from bundle closure budgets, tests case aliases and stale protocol URLs, injects stream-position restore failure, verifies failed decode ownership, and checks reload of surviving scene leases after partial release.

## Findings and integration limits

1. **No bounded source blocker found.** The shared store publishes a file only after a complete bounded copy and successful position restoration. Existing entries are compared byte-for-byte before reference increment; failed or conflicting acquisitions leave store counts unchanged. The native tests cover these paths, including oversized and restore-failure streams.
2. **External store lifetime is a documented integration obligation.** The overload accepting `TCatalogSharedFiles` borrows the store and does not retain or free it. A caller must keep it alive until every bundle/scene lease releases its paths. The docs state this and the real-scene witness follows it; future production integration should make the owner ordering explicit because premature store destruction would make later lease destruction unsafe.
3. **Shared production residency is intentionally unclaimed.** `TCatalogFileBundle.Create(AByteLimit)` still creates an isolated store, the retained browser fixture uses that constructor, and the application build evidence does not enable shared staging or GPU texture sharing. The real native witness proves source/decoded-image behavior under the fixture’s Castle path only. No residency cap, decoded/GPU budget, or performance result follows from this report.
4. **Full feature gates remain held.** Full catalog admission, placement/playability, cross-context recovery, physical-phone behavior and release/Pages checks are outside this foundation milestone.

## Evidence reviewed

- `build/catalog-shared-foundation-01/provenance.json`: base/engine bindings, native 328 checks, shared versus isolated measurements, WASI compile and application build exit 0.
- `build/catalog-shared-foundation-01/results.txt`: native wrapper and focused rerun both exit 0; real eight-scene witness reports isolated 8 images/290,028 bytes and shared 1 image/175,004 bytes, both 3,146 triangles, with notices retained.
- `build/catalog-shared-foundation-browser-01/evidence.json`: retained 26-check isolated application journey, five object/retry cases, zero browser errors and warnings.
- `build/catalog-shared-foundation-browser-01/book-phone.png` and `vase.png`: representative rendered object captures; geometry is visibly present and the evidence makes no visual-performance claim.
- `docs/CATALOG_PUBLICATION.md`: current explicit shared-store lifetime, closure-budget and non-GPU-sharing contract.

## Reviewed input fingerprints

Hashes below were generated with `build/tools/phanes.reviews.exe hash`. Artifact values are retained from the same checker/provenance inputs.

```
cge/code/phanes.catalog.files.pas                  bf96e13d2a3c3473ce0bff97dc3834bc036ad7960d9597b060e48b6739ae2c28
cge/code/phanes.catalog.paths.pas                  ec935bb433eef4302a686a2c839943a94a6357e6cf276b2826ec6c2cd870a229
cge/code/phanes.catalog.shared.files.pas          8490af56b0ceffe229c54e49bd410c7e7ac8b9a0c1c31ac7611e10264ce12632
cge/code/phanes.catalog.scene.pas                  136bd724f9cee0a99a99442c4e7e364b8ec7909d5b94eb90aa6447a7d12e0c51
tests/phanes.tests.catalog.files.lpr                36f43614dae66cee64ac8c1cba1fbae4b3430a974a13a54d6c0554e34b56b6ca
tests/phanes.tests.catalog.shared.scenes.pas       efa14545571f49624fc5066995f615099f09db6cc7d0ab1d605aa81d7e2cd25d
docs/CATALOG_PUBLICATION.md                         4566b201b27837ba8156aca6256c3d7965c295b1b8ddbcd5de559ee7ae97f96a
reviews/features.json                               e09f5517da1e77b96419b35fe547f71aa87b9da309a02f8dee3acd7bc0dbf83e
tools/test-catalog-runtime.ps1                     98eab1c928b950208d04a4f2fae12aa2416f08315b67afa95b896fa673ff7552
build/catalog-shared-foundation-01/provenance.json c17e7b1f17d4648296462281835fda32ec4722c3dd0e18da067d221ade510ed4
build/catalog-shared-foundation-01/results.txt     cb6be55496bc67af5124ac935442d159a6b5ae42a8b0e5f21fba369436094437
build/catalog-shared-foundation-browser-01/provenance.json ddece82961423b2ddd905ba99e2e92371f23c77cb35ede1fecc75a10e227f982
build/catalog-shared-foundation-browser-01/evidence.json d9c0cc341b243e141d98289ba10b9acc4800e091b5783b462241e0e0783054c0
build/catalog-shared-foundation-browser-01/book-phone.png 1c6e1d1fd187983ca82af5396a31eec841b4c27f9be5917d208f31a86be7b517
build/catalog-shared-foundation-browser-01/vase.png 9ac45dea49ee7369c6611d1baa2535ad7e0836a51b4cf7c161986f29cd86d09b
```

No implementation, registry, or builder-evidence file was edited by this review.

