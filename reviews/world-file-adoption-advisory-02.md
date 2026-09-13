# Luna bounded world-file adoption review 02

- **Critic:** Luna (independent critic)
- **Date:** 2026-09-13
- **Repository:** `Phanes`, workspace HEAD `8970895aacbf15ae7bea74674ff1480cc327f932`
- **Engine context:** adopted Castle checkout `e52f3ee` unchanged.
- **Scope:** renewal of the bounded format-4 world-file import/export correction. Runtime source, activation, editor bridge, staged bundle and WASM were checked against review 01 and are unchanged. This report does not clear the registered `world-creator` scope, optional catalog publication, physical-device behavior, or release gates.

## Decision

**Bounded development adoption recommended.** The two prior findings are resolved by the focused test delta and the completed wrapper invocation. The 33-check candidate passes the format-4 desktop/phone-emulated round trip, legacy 1/2/3 imports, invalid and worker-rejected input preservation, stale-read ordering, and an actual 8 MiB + 1 byte File rejected before `text()` is called. The wrapper compiled both components and completed the journey with exit code 0. Remote CI invocations remain unverified and are a release qualification limitation, not a blocker to this bounded development correction.

## Grades

- **Intuitiveness — A-:** Existing Export/Open controls and the forwarded mobile Export remain discoverable, with visible success and rejection states. The evidence checks phone hit bounds and successful file interaction.
- **Accuracy — A-:** Pascal ownership accepts matching world/envelope versions 1–4, validates size and structural fields before worker restore, catches Pascal/native failures, and guards stale asynchronous reads. The new regression constructs an actual 8 MiB + 1 byte `File`, spies on `text()`, and proves rejection before reading with exact world/history/future preservation.
- **Wow factor — B+:** The fix restores practical format-4 relative-elevation save/load while retaining legacy compatibility and exact semantics. The retained desktop and phone-emulated captures support the bounded user outcome; no broader visual or device claim is made.
- **Thinking out of the box — A-:** The request-token race defense, worker-only publication path, native/mixed download-path diagnosis, and direct pre-read size spy address failure modes that the old JavaScript handlers did not isolate.

## Findings and limits

1. The review-01 size-bound evidence gap is closed. `CheckOversizedImport` dispatches `Uint8Array(8*1024*1024+1)`, records a `text()` spy, verifies rejection and visible error, and compares world/history/future snapshots. Candidate evidence records all four assertions as passed.
2. The review-01 wrapper reproducibility gap is closed for the retained host run. `tools/test-world-file.ps1` compiled the landform probe and native browser checker, ran against `http://127.0.0.1:4321/`, reported `orchestrationIssue: null`, and exited 0 with 33/33 checks. The new Pages-host/project-host CI calls have not completed a remote run, so they remain a follow-up for CI qualification.
3. Runtime fingerprints are unchanged from review 01, including the Pascal unit, browser entry, navigation forwarding, editor JavaScript, HTML, staged interiors bundle, staged editor JavaScript, and adopted WASM. The mobile path still flows through `mobile-save-world` → `save-world` → Pascal export.
4. This bounded recommendation does not approve the full registered world creator or release. Phone results are desktop browser emulation; the separate optional-book publication timeout remains unresolved; full catalog/publication and device performance remain outside this report.

## Verification evidence

- `build/world-file-candidate-04/evidence.json`: 33/33 passed.
- `build/world-file-candidate-04/provenance.json`: wrapper exit 0, `orchestrationIssue: null`, actual oversized-file proof, unchanged staged WASM, desktop/phone captures and downloads. Raw SHA-256: `15208db5d1c7e1267571fc2f2a29ce7e1c9cf51ca91514f2424e08e890656439`.
- `build/logs/world-file-wrapper-candidate-04.log`: clean wrapper build and all 33 PASS lines; only the two existing `wfc_atomic_new_file` warnings remain.
- `build/download-path-ab-02/evidence.json`: normalized native download path succeeds for the 2,327-byte payload; mixed separators fail, supporting the harness correction.
- `docs/WORLD_FILES.md`: updated 33-check contract and explicit remote-CI/full-scope limits.

## Reviewed input fingerprints

Hashes below were obtained with `build/tools/phanes.reviews.exe hash` for the exact current inputs. Candidate artifact hashes are retained from its provenance record.

```
src/phanes.worldfile.ui.pas                 d84bac9ffd326de923f5fbcfff36206f84a0d276cb25eff50cf920684a694ca1
src/phanes.interiors.browser.lpr            260b48d5b466452b6684fad95ac6bb622055d97bc1f572748dbbd280ea81964a
src/phanes.navigation.ui.pas                6009e8d63534716c5b0f0fe013b51e02da27da16c67d67e1db5d9c6d17e18990
web/phanes.editor.js                         895c344031188353fd6087ab9adaf1b2e96724e584316d54eef485be2f652517
web/index.html                               bd64e03128df9742aa6aa5dbff650fff10acf2c2a540303c97cef9905fc1a233
tests/phanes.tests.world.file.browser.lpr   850aebcc95ca90e06993566d81225387371eb1e4bd0f54afb87c90e984d9fc26
tools/test-world-file.ps1                    0d6a853d7f5c49cdbc8ed5411123224c356231a114e68491e16ee2f9b587f2e2
docs/WORLD_FILES.md                          50f907288c712b84bfe7f7856f3ce04c16254af88c91adfe23f9fa8d2ead94d3
.github/workflows/pages.yml                  e022b944bf3c457ae097f1df61ca907d3af53ad587e263b6c8fe1576564e6e5e
build/world-file-candidate-04/evidence.json  d3728520ead3af3b0a51e41331aa130260525348fd0e44b500d5f1501064b903
build/world-file-candidate-04/provenance.json 15208db5d1c7e1267571fc2f2a29ce7e1c9cf51ca91514f2424e08e890656439
build/logs/world-file-wrapper-candidate-04.log 7189c97d2c013035a22f969ae23df767724ff82fe4f9c7c42931c8a2dd4b7b59
build/download-path-ab-02/evidence.json     98c9b6c26bd61460d56f9ff19dfa9210eefe4724e49f0e03a89c8aaf91d8a9c4
```

No runtime, registry, workflow, or prior critic report was edited by this review.

