# Luna bounded interior frame-request advisory

- **Critic:** Luna (independent critic)
- **Date:** 2026-09-13
- **Repository:** `Phanes`, reviewed HEAD `cdf3562cc4cd721f581c142325593a0968066d14`
- **Engine:** `e52f3eeb40ad5a1e3dad1380cf6ec0902ec68379`, unchanged
- **Scope:** explicit interior “Look closer” frame-target retention, Castle bounds/orientation handoff, focused browser regression, existing interior harness diagnostics, and CI wiring. This is bounded adoption advice for the framing fix. It does not approve the full granular-interiors feature, physical-device behavior, performance, Pages, or release.
- **Method:** focused source and test inspection plus retained build, JSON, log and representative desktop/phone-emulated capture review; no duplicate browser, GPU or build run.

## Decision

**Bounded development adoption recommended.** `TInteriorUI.SendSelection` records the selected ID at the explicit framing action and carries it beside the monotonically increasing frame version. Later selection updates therefore cannot replace the target before Castle consumes the request. `TMainView.ApplyInterior` resolves bounds from that target, while `TInteriorUI.Frame` uses the same target to derive support orientation and camera pose. The focused 36-check run deliberately pauses animation, proves the old camera-only acknowledgement can arrive while the interior acknowledgement is still pending, changes selection to the parent, then compares the delayed callback and camera pose with a normally acknowledged frame. Both 1440x960 and 390x844 cases pass, including real fruit picking and exact world preservation.

## Grades

- **Intuitiveness — A-:** The frame target is an explicit field with a clear comment at the browser/native handoff. The focused driver names the acknowledgement conditions and stores target, versions, callback arguments, pose and errors in inspectable snapshots.
- **Accuracy — A-:** The production code uses the captured target for both Castle `BoundsFor` and Pascal orientation, and the test requires exact interior, room, scene and camera acknowledgements. Delayed and normal bounds arguments and complete camera poses are byte-for-byte equal in the retained desktop and phone-emulated cases.
- **Wow factor — B+:** This is a reliability correction rather than a visual feature, but it removes a subtle selection/render race that otherwise frames a different object while appearing ready. The retained desktop and narrow viewport captures show the intended fruit and book views with the surrounding interior intact.
- **Thinking out of the box — A-:** The regression controls `requestAnimationFrame`, keeps the callback pending through a parent selection, checks the old false-positive camera condition, and then resumes to compare the actual delayed result against a clean acknowledgement. The existing harness also preserves callback/version diagnostics on pick failures.

## Findings and limits

1. **No bounded implementation blocker found.** `FFrameTargetId` is assigned only for an explicit frame action; ordinary selection changes update `selectedId` without overwriting it. Castle reads `frameTargetId` when the new frame version is applied, and the browser callback feeds the resulting bounds to `Frame`, which resolves the same target and its support chain for yaw/pitch. The retained fruit and book delayed snapshots show a parent selected while the frame callback still reports the child target bounds.
2. **Acknowledgement coverage is meaningful and correctly scoped.** The focused test requires room, interior version, scene version and rendered camera version to agree. It separately observes that camera-only readiness can be true while the interior acknowledgement is pending, so a stale camera cannot satisfy the new check. Delayed and normal callback arguments and full `phanesCamera` poses are compared, then world JSON and a real center-canvas fruit pick are checked at desktop and touch-emulated phone sizes.
3. **Diagnostics remain failure preserving.** The existing `test-interiors.cjs` wrapper now records its base URL and, for fruit-pick failures, selection, pick request versions/coordinates, rendered interior/camera state and callback trace before taking a screenshot. It rethrows the original failure. The focused driver captures a failure snapshot as well; neither path converts an unmet assertion into a pass.
4. **Qualification remains bounded.** The full retained interior journey passes at `/Phanes/` on desktop and phone emulation with zero runtime errors, while the focused run passes 36 checks and the fresh app/pas2js builds succeed. These are local Chromium/emulated-phone results. Earlier setup failures and the paused-RAF witness remain retained evidence; remote CI timing/cause and physical-device framing/performance are not established here. The full granular-interiors gate and release/Pages acceptance remain held.

## Evidence reviewed

- `build/interior-frame-app-01/provenance.json`: canonical source/runtime/evidence index; fresh app and pas2js build bindings, WFC and pinned engine references.
- `build/interior-frame-regression-03/result.txt`: `PASS 36 checks`; focused desktop and phone-emulated run.
- `build/interior-frame-regression-03/desktop-1440x960-fruit-delayed.json` and `phone-390x844-book-delayed.json`: delayed snapshots show parent selection alongside the retained child `frameTargetId`, exact callback bounds and no errors.
- `build/interior-frame-regression-03/desktop-1440x960-fruit-delayed.png`, `phone-390x844-fruit-delayed.png`, `desktop-1440x960-book-delayed.png` and `phone-390x844-book-delayed.png`: representative actual captures with visible target geometry, interior controls and responsive narrow layout.
- `build/interior-full-pages-frame-01/interior-browser-evidence.json` and `run.log`: retained full journey at both viewports, including framing, nested content, import/restore, picking and walking; CGE Effect/EffectPart warnings remain disclosed.
- `build/interior-frame-witness-01/run-01`: retained old paused-RAF counterexample used to define the regression; it does not prove the complete remote failure cause.
- `docs/INTERIORS.md`, `docs/PUBLISHING.md` and `docs/VERIFICATION.md`: current contract, CI invocation and bounded-qualification wording.

## Reviewed input fingerprints

Source fingerprints were generated with `build/tools/phanes.reviews.exe hash`; artifact fingerprints are raw SHA-256.

```
.github/workflows/pages.yml                         098bbd5ae8ad429978c554b81d0f19da18df855a2f64b80964b2c9d9bdcd5810
cge/code/phanes.app.view.pas                       f9a616fb684712ad016c746ed7214cab57b380ca6eb24a6d5219d1b4cd64596b
src/phanes.interiors.ui.pas                        5a1fae865a8e867dc3afcf4f37d1538a4c4c305a560b145b4505e2f4790bc4d0
tools/test-interiors.cjs                            0253dee6794dc4358ddd7b009a00ede64e98d4b15f9e2cc92a397a0a51721d79
tests/phanes.tests.interior.frame.browser.lpr       dc1b0f967769bf796da7b8d8cb1040b2a90317a7ff1eb1e08b956c486c8f634e
tools/test-interior-frame.ps1                       b1b6238655e51744f285e5e3e7282bd128509f425e0adac3c4c3a4aa3c37491d
docs/INTERIORS.md                                   772f2e06884342a2d2b692cb0a7fe7c609b9c753f318ce9a1b30dcc431d70e0b
docs/PUBLISHING.md                                  04631fb27e78328ab58d993c9b0316a4a7b9c54917cabb5f4d2d148bd632cf97
docs/VERIFICATION.md                                859319bc9fddc80acf0dee200737ca6eed1ef5dc674f40ce6dd5d5b70d86af8a
reviews/features.json                               59b6134bf8e018a2d3c3be818f554ebb6e99cef902a99692fc827eaa5c928b1d
build/interior-frame-app-01/provenance.json         28066faa4bdc160ca4f64a2ecbf436b6fef52f4ab7a9418885a3871ff895dc01
build/interior-frame-regression-03/result.txt       4fde0cd1fa68a9b4b74e58df875cd2a1cf59e06c44edcfb14e774f600ec2c650
build/interior-frame-regression-03/desktop-1440x960-fruit-delayed.png 290fdfc043ab810f3259a9f3e5e03831b2ab4f71ae8c27bdb71042fc9ff82998
build/interior-frame-regression-03/phone-390x844-fruit-delayed.png fb11fc5d1874fe41c7373befdf3163a9deca76f2d304677a5a37ea73bff82f68
build/interior-frame-regression-03/desktop-1440x960-book-delayed.png 225be3f26ea5ded604fbfb46385f333641ccdca6a49a6a9ebacf66201b5fc8d0
build/interior-frame-regression-03/phone-390x844-book-delayed.png 21bb2c2c682b916c1d5ebc25d9502b8ef9bea02861bc677becf1bafcae39fe17
build/interior-full-pages-frame-01/interior-browser-evidence.json 227de21c46485dfb1d0899d196816bbe57dcc52cd2df3e771608747f9ed7c9d9
build/interior-full-pages-frame-01/run.log                  0478e12f8327187b1462d532db4fd07d1b37d298ccee3c4d929c0e0d82f25fe7
```

No implementation, registry, prior critic report or builder evidence was edited by this review.
