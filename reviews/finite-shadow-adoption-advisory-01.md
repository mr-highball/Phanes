# Luna bounded finite-shadow adoption advisory

- **Critic:** Luna
- **Date:** 2026-09-13
- **Scope:** the five-file Castle Game Engine finite directional shadow candidate and its Phanes integration
- **Decision:** bounded development-adoption recommendation; no full finite-shadows feature, Pages, physical-phone, or product-performance acceptance
- **Method:** independent source/diff inspection and retained evidence review; no browser, GPU, or suite rerun

## Findings

The candidate's five-file delta is internally coherent. It adds an opt-in `DirectionalShadowDistance` with zero preserving the existing infinite-volume path, passes the value through scene rendering, emits finite side quads and reversed endpoint caps, and keeps positional lights on the old path. The near-prism classifier uses Double cross products, scale-aware margins, and conservative possible-overlap results for invalid, degenerate, or near-parallel inputs. The canonical endpoint ordering is shared by the ordinary renderer and Phanes static cache, addressing the rounded nonplanar shared-edge case. The Castle light query is now protected and resolves the current world transform on demand.

Phanes calls that protected query during projection calculation, resets the finite distance when the light is absent or positional, derives the axis-separated distance from `Items.BoundingBox` and the same world light, and supplies the distance to both the ordinary renderer and cache. The cache key includes light, distance, whole-scene closure, and per-shape transform; context loss and visible/geometry changes clear entries. Capacity exhaustion and unsupported modes fall back to the ordinary path. The reviewed code now normalizes the transformed directional light in both the engine renderer and Phanes cache/helper, satisfying the normalization concern from the prior advisory.

I found no new semantic blocker in the bounded source delta. The exact engine checkout is still a dirty worktree at base commit `25f2d98122997f8f039f759f9ffb76207b4f3cfe`, with these five files modified. Before application adoption, materialize this exact patch as a committed, pinned engine revision and bind the Phanes vendor/gitlink and build provenance to that revision. Until then, reproducibility is the adoption blocker even though the retained compiled evidence is bound to frozen source snapshots.

The numerical witness is proportionate: the current axis helper reports 6,050 checks over rounded Single endpoints, far enclosure, camera stability, direction scaling, near-parallel/tiny/translated bounds, malformed inputs, and near-maximum Single bounds. The candidate fixture has eight independent analytic masks; the corrected state fixture has 20 paired cache/ordinary states; the opposite-side fixture adds four positive-shadow masks with 14,421 shadow and 426,884 lit pixels per mask. The retained full-world cached run has zero dark pixels in the 54,000-pixel overhead sample on SwiftShader and GTX1080, and ordinary/cache images are byte-identical in five of six pairs. The one hardware restored-Orbit difference is recorded as one pixel and one 8-bit level.

The remaining qualification limits are material but outside this bounded adoption recommendation: the production sample is not a generic proof over arbitrary geometry or all camera/state combinations; the full-world lit-pass sample does not independently classify every shadow pixel; the cache budget counts its declared vertex storage rather than all driver/GPU allocations; Orbit is about 15 fps cached on the development machine; and phone layouts are desktop emulation. Full feature and release gates therefore remain held.

## Reviewed inputs and normalized fingerprints

Hashes were generated directly with `build/tools/phanes.reviews.exe hash` from the exact current files.

| Input | SHA-256 |
|---|---|
| `castle-engine-phanes-webgl/src/scene/castlescene.pas` | `3ef53794f7f77c8a4bffcc366564aa09ab9975054d13c9c7f665c6bf86a79514` |
| `castle-engine-phanes-webgl/src/scene/castleshapeinternalrendershadowvolumes.pas` | `f165aa6f40a7059434cf54e26c3836b3ffbf730d832633e8b20f78b7a81e272d` |
| `castle-engine-phanes-webgl/src/scene/castleviewport.pas` | `7b83ca8f29574dc857ba4f7061e715f86d1bdc30a746e42ab0080bfd2f19e3b4` |
| `castle-engine-phanes-webgl/src/transform/castlefrustum.pas` | `3bc3f78bf26969754bbcbdcf3ad87f7ab9b21c174305ce49b4d151d39d8703fa` |
| `castle-engine-phanes-webgl/src/transform/castleinternalglshadowvolumes.pas` | `f06e884c998f468fdd1ca6c50e5753bba91793ed92202c7f39b7eab36479a62d` |
| `cge/code/phanes.app.view.pas` | `deccf9dace9a7ea4abf3e9562c60d0b597e1e846a8839afd72351f03db61cb26` |
| `cge/code/phanes.world.shadowbounds.pas` | `4ee73d53da0881e3aed21cafeb2e13c60bd6a2adb33beb0e580445ef63e56b38` |
| `cge/code/phanes.world.shadowcache.pas` | `ac621d9f96140c4719082680a4dc8ff14e543c3147d42bbe0d545a391ad9f362` |
| `docs/dependencies/cge-finite-shadows.patch` | `4b316b6eeabdddaa6643bb799b0b5b5f8f85d63ce9f65fd59134c945aa1f491f` |
| `docs/dependencies/CGE_FINITE_SHADOWS.md` | `49cef05bdf336a57804b58ed785a7d8810b366be0b166ba1277d1460bbd70021` |
| `build/shadow-production-candidate-03/provenance.json` | `a25ca4108022a91840e74ebff0d1dfab3c821862700996230d4eb6489b85158d` |
| `build/shadow-axis-bounds-test-01/evidence.json` | `44bcbb31ce586d867515911cc8c8c8f105c190daf77ddc5133c803e69370afc1` |
| `build/shadow-axis-fixture-01/evidence.json` | `bf69e62dc44ca3ff44aa22493783200554446cdab6ed74b43af499cdc01e2e24` |
| `build/shadow-axis-state-fixture-01/evidence.json` | `12497ad23c86ce7458f56a23682c24d1c184c49362c9f5a2878604ea8aa7501e` |
| `build/shadow-axis-state-opposite-fixture-01/evidence.json` | `ec9db3d5a95c36aec05768900df834aaa9daa425956ec5d2b379226ed398e221` |
| `build/shadow-production-candidate-03/full-world.json` | `010d7f28ea978dabb735d5d9f44375700525350a9d9cc37f6ec082bc6ee3d6a6` |
| `build/shadow-production-candidate-03/ordinary-cached-agreement.json` | `2685678c5755f92a7e9e8672deee270da13943029c1340579ef41cd07590fe0c` |
| `build/shadow-production-candidate-03/benchmark.json` | `9a4ac173e4fc8066e3655462c312fbc5600261cf48cedff358dde9536bd5137b` |
| `build/shadow-production-candidate-03/picking.json` | `e3c07662c7d49674341bcba011744699aa5cc828c6caafd164b6799f233207fc` |

`git diff --check` passed for the five-file engine worktree delta. No runtime, registry, or builder-evidence files were edited by this review.
