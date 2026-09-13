# Luna bounded world-file adoption review

- **Critic:** Luna (independent critic)
- **Date:** 2026-09-13
- **Repository:** `Phanes`, workspace HEAD `8970895aacbf15ae7bea74674ff1480cc327f932`
- **Engine context:** adopted Castle checkout `e52f3ee` unchanged; no engine input is part of this correction.
- **Reviewed scope:** the format-4 world-file import/export correction, Pascal UI ownership and browser activation, mobile forwarding path, focused driver/wrapper, and the frozen candidate artifacts. This is a development-adoption review for this bounded correction. It does not review or clear the registered `world-creator` scope, optional catalog publication, full release, or physical-device behavior.

## Decision

**Changes requested before treating the bounded correction as fully verified.** The implementation is suitable for development adoption: it fixes the format-4 rejection while retaining versions 1–3, validates the envelope before worker submission, protects current state from stale reads and worker rejection, and preserves the existing mobile path. The direct candidate journey is strong, but the 8 MiB contract is source-reviewed rather than exercised by a boundary case, and the new wrapper/CI invocations have not completed an end-to-end run. Those are evidence follow-ups, not a demonstrated runtime defect.

## Grades

- **Intuitiveness — A-:** The existing Export/Open controls remain in place, the mobile Export control forwards to the same action, and rejection messages are visible. The 29-check journey covers desktop and phone-emulated reachability, including 44 px hit bounds.
- **Accuracy — B+:** `phanes.worldfile.ui` accepts envelope/world versions 1–4, requires matching explicit format metadata, checks size/layers before worker restore, catches Pascal and native JavaScript failures, and makes publication go through the existing worker. The candidate restores exact format-4 terrain and world/history semantics, validates legacy 1/2/3, and proves an older delayed read cannot replace a newer one. A direct over-8-MiB rejection assertion is missing.
- **Wow factor — B+:** The user-visible value is a real format-4 relative-elevation round trip with legacy compatibility and exact state preservation on desktop and phone-emulated layouts. The captures are representative of the world editor and the evidence does not claim visual spectacle beyond this fix.
- **Thinking out of the box — A-:** The request-generation guard covers an otherwise easy-to-miss asynchronous File.text race; the separate native/mixed download-path differential isolated the original harness cause; and the Pascal/native exception split gives browser failures a controlled visible state.

## Findings

1. **Follow-up evidence: add a focused size-bound case.** `Changed` rejects `File.size > 8 * 1024 * 1024` before calling `text()` and clears the input, which is the correct ordering. The 29 checks cover malformed, unsupported, worker-rejected, legacy and stale files, but do not submit an over-limit file or assert that `text()` was not called. Add one focused case at 8 MiB plus one byte, checking rejected status, visible message, unchanged world/history and no read invocation. This is the only material verification gap I found in the bounded controller.

2. **Follow-up evidence: execute the prepared wrapper in CI or an equivalent clean host.** `tools/test-world-file.ps1` compiles the landform probe needed by the driver, compiles the native checker, and runs it against a caller-supplied URL; the Pages workflow now invokes it for both the project and Pages hosts. The frozen direct candidate run passed 29/29, but the wrapper and newly added CI calls were prepared after that run and are not themselves successful end-to-end evidence yet. This limits reproducibility confidence; it does not invalidate the frozen candidate artifact.

3. **No source defect found in mobile forwarding or stale-read handling.** `phanes.navigation.ui` attaches `mobile-save-world` and forwards a permitted click to `save-world`; the Pascal world-file unit then performs export. `ImportFile` checks the request token immediately after the awaited read and before parsing or cancelling the worker. The staged bundle contains both paths, and the candidate evidence records a visible, hit-tested 360x48 phone control and successful format-4 download/import.

4. **Full-scope limitation remains explicit.** The candidate uses an unchanged adopted WASM and browser emulation for phone checks. The separate full interior CI optional-book publication timeout remains unresolved. Neither fact is evidence against this controller, but neither permits clearing `world-creator`, full catalog/publication, physical Android/Brave performance, or Pages release gates.

## Evidence reviewed

- `build/world-file-candidate-03/evidence.json`: 29 checks passed, including format-4 export/import, legacy 1/2/3, invalid and worker-rejected inputs, stale reads, desktop and phone-emulated download/import.
- `build/world-file-candidate-03/provenance.json`: frozen candidate stage `build/web-world-file-01`, unchanged WASM, source/artifact bindings, and phone reachability. Raw SHA-256: `56a012cfb8627761f1c04a9edf13e0388d481c1ca9ed17bdd179c85fb73d876d`.
- `build/download-path-ab-02/evidence.json`: the 2,327-byte payload succeeds with normalized native separators and fails with mixed separators, supporting the harness path correction.
- `build/world-file-candidate-03/desktop-imported.png` and `phone-imported.png`: representative restored editor views; both show the expected selected terrain and validation toast, with the phone controls reachable in the captured emulation.
- `docs/WORLD_FILES.md`: current contract and explicit wrapper/full-scope limitations.

## Normalized fingerprints

The following are from `build/tools/phanes.reviews.exe hash` for authored review inputs; artifact fingerprints use the same checker where listed.

```
src/phanes.worldfile.ui.pas                 d84bac9ffd326de923f5fbcfff36206f84a0d276cb25eff50cf920684a694ca1
src/phanes.interiors.browser.lpr            260b48d5b466452b6684fad95ac6bb622055d97bc1f572748dbbd280ea81964a
src/phanes.navigation.ui.pas                6009e8d63534716c5b0f0fe013b51e02da27da16c67d67e1db5d9c6d17e18990
web/phanes.editor.js                         895c344031188353fd6087ab9adaf1b2e96724e584316d54eef485be2f652517
web/index.html                               bd64e03128df9742aa6aa5dbff650fff10acf2c2a540303c97cef9905fc1a233
tests/phanes.tests.world.file.browser.lpr   37d9f3db55cf5e47d4b7c2fc468da65bef8d7ee2dbaff407ac0d8a1fbb5f6ced
tools/test-world-file.ps1                    0d6a853d7f5c49cdbc8ed5411123224c356231a114e68491e16ee2f9b587f2e2
docs/WORLD_FILES.md                          26556cf929ea3964398f419d6d880bce76acf87c1bbef84006b4b11068ea7e90
.github/workflows/pages.yml                  e022b944bf3c457ae097f1df61ca907d3af53ad587e263b6c8fe1576564e6e5e
build/world-file-candidate-03/evidence.json  1e060c2f7c2cf9a890a73176f3e8c21761997d19504a9e19b8d55b62890898f4
build/world-file-candidate-03/provenance.json 339fe35bbd13b0704787294fd35c3643d0572b4a63a747f2cc2a3882b20ea41c
build/download-path-ab-02/evidence.json     98c9b6c26bd61460d56f9ff19dfa9210eefe4724e49f0e03a89c8aaf91d8a9c4
```

The report preserves the raw provenance SHA above because the checker’s text normalization produces a different normalized fingerprint for that JSON artifact. No implementation, test, registry or prior critic report was edited.
