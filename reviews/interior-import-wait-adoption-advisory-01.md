# Luna bounded interior-import wait adoption review

- **Critic:** Luna (independent critic)
- **Date:** 2026-09-13
- **Repository:** `Phanes`, reviewed HEAD `8e5c1ac6bacf839d263a14d9a3b2881377792eb5`
- **Scope:** the `tools/test-interiors.cjs` harness change that aligns imported-world readiness with the existing 180-second optional-catalog contract and adds failure replay diagnostics. This is a harness adoption review. It does not approve the full catalog/interiors feature, product performance, physical phones, Pages, or release.
- **Method:** focused diff/source-contract review and retained CI artifact/image inspection; no browser, GPU, or new suite run.

## Decision

**Bounded harness adoption recommended.** The change correctly distinguishes worker completion from complete imported-world readiness. It waits for worker idle, catalog loading to finish, an advanced scene revision, and the rendered revision to match. The 180-second deadline matches `TCatalogRuntime.CheckRequest` and the existing catalog browser checks. The retained CI failure shows why the old 30-second assertion was inconsistent: at the timeout the worker had finished and the requested book was staged and acknowledged, with no pending requests or errors; the retained screenshot then shows the world ready and validated. The harness still throws the original assertion and does not turn the failed run into a pass. A subsequent retained local run completed all four imports at both 1440x960 and 390x844, including the legacy import that exposed the old timeout.

## Grades

- **Intuitiveness — A-:** The readiness predicate is readable, commented at its point of use, and names the observable conditions that constitute a published render. Failure output now includes baseline state, attempted envelope, timing, camera/history context, request state and a bounded late observation.
- **Accuracy — A-:** The wait uses the same 180,000 ms functional deadline as the runtime catalog preparation path and other catalog browser tests. It prevents a worker-idle snapshot from being mistaken for a completed render. The retained snapshot and later capture support the diagnosis without claiming that every import succeeds.
- **Wow factor — B+:** This is a focused reliability improvement rather than a product-facing feature. The diagnostic replay turns a misleading timeout into actionable evidence while preserving the original failure semantics.
- **Thinking out of the box — A-:** Capturing exact world/history/future/camera/selection before input, recording request timing, and observing up to 15 seconds after failure isolates late publication without masking the assertion or rerunning the whole journey.

## Findings

1. **No harness correctness blocker found.** The changed `importWorld` creates a cloned attempted envelope, waits with the established 180-second limit, requires `!phanesEditor.worker`, `!window.phanesCatalogLoading`, `phanesSceneVersion > prior`, and exact rendered revision, then retains the existing `lastSolve === 'passed'` assertion.
2. **The timeout alignment is justified, not a product timeout relaxation.** `TCatalogRuntime.CheckRequest` already uses 180 seconds for optional model preparation, and the catalog object/world browser tests use 180,000 ms for the same rendered-publication condition. The change only adjusts the test harness and does not alter runtime deadlines, physical-device expectations, or performance claims.
3. **Diagnostics preserve failure semantics.** On timeout the harness writes the initial failure evidence, screenshot and replay/late-observation data when possible, logs diagnostic failures separately, and rethrows the original Playwright error. A late completion therefore remains evidence about timing, not a converted pass.
4. **Qualification remains open outside this bounded harness change.** CI run 34750694159 still failed the original 30-second assertion and did not exercise this new code. The retained artifact demonstrates the prior boundary and late visible completion. A later retained local run (`build/logs/interior-import-wait-01.log`) completed all eight desktop/phone import cases, with readiness waits of 6325, 684, 1172 and 656 ms on desktop and 2602, 636, 996 and 695 ms on phone emulation. Full catalog/interior behavior, optional-book reliability under remote CI, physical phone performance and release gates require their own successful runs.

## Evidence reviewed

- `build/ci-interior-publication-assessment-03.md`: records CI 34750694159, the 30-second failure state, stage acknowledgement/request matching, no pending requests/errors, and the rationale for the final predicate.
- `build/actions-8e5c1ac6-verification/interior-import-failure-1440-evidence.json`: desktop 1440x960 snapshot at the old failure boundary; worker inactive, scene/rendered revisions still 11, catalog loading true, stage revision/acknowledgement 5, requested book ready, no pending requests or errors.
- `build/actions-8e5c1ac6-verification/interior-import-failure-1440.png`: later retained capture visibly shows `World 4294967295`, `World ready`, and `Created in 5828 ms. World validated.` This supports late completion but does not establish a complete successful journey.
- `build/logs/interior-import-wait-01.log`: retained local run completed four imports at each desktop/phone-emulated viewport, including the prior legacy-import case; no critic rerun was performed.
- `src/phanes.catalog.runtime.pas`: `CheckRequest` 180-second preparation deadline and cancellation/context contract.
- `tests/phanes.tests.catalog.objects.browser.lpr` and `tests/phanes.tests.world.file.browser.lpr`: existing 180-second rendered-publication waits used as the comparison contract.

## Reviewed input fingerprints

Fingerprints were generated with `build/tools/phanes.reviews.exe hash` for source inputs and with SHA-256 for retained binary/text artifacts.

```
tools/test-interiors.cjs                                      bb5bea52e5d8a3bfa4257a04b0ed00924e53f3572dc27d34bb5053dc1516aed9
src/phanes.catalog.runtime.pas                              c11c589d3f8d42ebdce33524c409831e2dc0c9cd7852d1fb28b65e30461183cc
tests/phanes.tests.catalog.objects.browser.lpr               9751787a781a347f7ec6da558fd208e0f159d72de29f8ac20925956d0e4a7060
build/ci-interior-publication-assessment-03.md               6de64e30046fcb3bdba44286ad2b6e8c9ed7224403771abc68dbd5e23e401684
build/actions-8e5c1ac6-verification/interior-import-failure-1440-evidence.json f2c4c3852cfba0127800e0c29fc72fd82d2243f4a36d470f57b3c7ba42f6eb48
build/actions-8e5c1ac6-verification/interior-import-failure-1440.png          21dabc2b240f61d82bad2c5c4fb764fca1ac7cfc0f751a82fa6bbe60c68b2cd8
build/interior-import-wait-01/provenance.json                                 78052ec67f25d1e2e6c92b649b18aba77f1f7f673242185da06c6b68f33e355a
build/logs/interior-import-wait-01.log                                         7e5fac9f18605d36a5138bc44e774294b3b86c2190de2a777ce984ad07ef2ebc
```

`git diff --check -- tools/test-interiors.cjs` and `node --check tools/test-interiors.cjs` passed. No runtime, test, registry, or builder-evidence files were edited by this review.
