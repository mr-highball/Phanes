# Mobile rendering and workspace recovery

The shared material bump shader uses high-precision eye coordinates, derivatives
and gradient arithmetic. It normalizes a well-scaled vector, bounds the surface
gradient, and retains the geometry normal for degenerate calculations. The former
tiny-vector normalization could underflow on mobile fragment hardware as the
camera moved. This is a numerical defect; the reported phone artifact still
needs confirmation on that device.

The sun explicitly uses CGE's minus-Z light orientation. Four unshadowed fill
directions provide soft sky/ground coverage in world space. This is an inexpensive
direct-light approximation, not global illumination. The earlier sign-only
diagnosis was incorrect: CGE transforms default to plus-Z model orientation.
Balanced density stays between 1.5 and 2 on high-density screens; Smooth and
native Detail remain player choices. Performance sampling counts completed CGE
frames, resets after visibility/freeze changes and clears unavailable metrics.

## Recovery contract

The Pascal session controller keeps a per-tab IndexedDB checkpoint every ten
seconds, after world publication, and on background/page-hide/freeze. It retains
the exact world, both history stacks, selection, camera, editing mode, interior
return camera, groundwork context, quality setting, tool visibility and visual
style. An unfinished interior-entry request is cancelled before background saving
so its temporary targeting selection cannot replace the player's authoring mask.

Pinned CGE's web animation callback raises on lost WebGL and cannot safely reopen
its graphics state in place. Phanes saves the current checkpoint, then loads a
fresh engine page. A Pascal worker validates every saved world in Undo and Redo,
selection bounds, camera and controller context before publication. Recovery
finishes after the new scene and camera have rendered. Repeated context loss
offers an explicit retry and export instead of an automatic reload loop. Storage
failures retain the existing checkpoint; rejected data can be exported without
publishing it. Browser storage is best-effort; a process killed before a write
commits can retain the earlier checkpoint. Export remains the portable save.

World admission and selection admission are separate: a saved brush/lasso mask
does not become authority for a new world operation. Regional masks, fine foliage
masks and cleared selections retain their exact state. Stale worker success and
error callbacks cannot publish or alter recovery after that worker was cancelled
or timed out.

## Traversal

Near a generated cabin, **Enter cabin** opens its admitted studio or room plan
in First person. The first visit can generate the studio through the Pascal WFC
worker, including while exploring. **Return outside** restores the exterior pose
and authoring selection. The Gabled house and Courtyard house also offer **Enter
house**, both as regional instances and on groundworks. Exact exterior asset IDs
own their contents: a regional edit replacing one house model with another in the
same category removes its interior, preserves other houses, and rejects protected
descendants.
On a foundation, the editor requires removing a furnished shell before choosing
another; editing the deck or its supports retains the interior.

`phanes.interiors.profiles` admits the original 9.4 × 9.4 m cabin studio and a
separate 8.8 × 7.8 m house studio, both 2.7 m high. The imported models contain
exterior shells only; their rooms are explicit portal instances with authored
geometry and WFC furniture/contents. They are not inferred layouts or physical
reconstructions of the imported shell. In particular, the gabled house's roof
bounds overstate its body depth, and the courtyard house is L-shaped. Their
portal room does not claim to fit those raw meshes. Player and furniture sizes
remain physical; room dimensions control the floor, walls, collision and spawn.
Cabin room-plan editing remains cabin-specific. Studio walking uses full walls
and a ceiling; orbit retains the editing cutaway. Other catalog buildings do not
acquire an interior merely by sharing a category.

Indoor object publication leaves the player's local position out of exterior
terrain/collision reconciliation. When changing from Fly or Orbit to First
person, the active interior admits the existing position or finds a clear
position using its own room dimensions, walls and furniture. The entrance is
tried first, followed by a bounded floor grid. If none is admitted, Fly remains
available with an explanation; the former fixed cabin-depth fallback could leave
a player outside the smaller house's walking bounds.

## Evidence and limits

Run `tools/test-renderer.ps1 -Browser <Chromium> -TestUrl <preview>` with the
Pascal compiler/runtime parameters used by the other browser test wrappers.

`tests/phanes.tests.renderer.browser.lpr` uses the Pascal WFC browser driver and
actual WebGL context loss. `tests/phanes.tests.session.probe.lpr` checks admission
of malformed selections, camera/controller records and independently corrupted
Undo/Redo worlds. Generated evidence is retained under `build/renderer-recovery-*`.
Run 10 passes 22 browser checks covering an enclosed interior, exact
world/history/selection/Explore and visual-style recovery, exterior return,
Undo/Redo, nine checkpoint validation cases (one valid and eight malformed),
freeze/resume and keyboard-accessible manual retry after repeated context loss.
Runs 07/08 exposed the headless driver's still-hidden tab after activation;
the final driver explicitly emulates foreground focus after activation.
`tools/test-renderer.ps1 -Case storage-denied` tests unavailable browser storage
without preventing world creation, including explicit export after graphics loss.
The separate `build/mobile-controls-10` suite passes all 48 existing checks,
including refreshed portrait and short-landscape layouts after keeping Export
available in specialized Tools panels.
House additions compile in `build/logs/mobile-renderer-build-07.log`, with the
later recovery-controller guard in `session-compile-13.log` and mask admission in
`session-worker-15.log`. `session-compile-16.log` adds the phone Tools drawer's
**Export world** action using the existing portable-save format.
`mobile-renderer-build-08.log` records the successful release build fixing indoor
publication/collision reconciliation; `mobile-renderer-build-09.log` records the
subsequent successful release build with profile-aware walking fallback and its
Pascal notification. Both include the normal compile checks.
Native `phanes.tests.house.interiors.lpr` checks both
house assets over eight seeds, measured furniture bounds, exact shell ownership,
protected replacement and preservation outside the selection, plus both houses
on all four foundation rotations. The 3,966 assertions include per-cell/per-node
equality checks, not 3,966 distinct journeys (`house-interiors-03.log`).
Existing composition and groundwork suites also pass after the profile change.
`tools/test-renderer.ps1 -Case houses` exercises both imported-house entries and
recovery with both history stacks populated and a nested shelf selected;
`-Case supported-house` exercises a house on a rotated foundation. The original
house run exposed the mask/restore incompatibility and is retained as failed
evidence. House run 02 found a test-probe BOM injection error; run 03 passes all
19 checks, including recovery of both populated histories, a nonrectangular
selection and a selected shelf tier. The session probe now has 15 cases (four
valid, eleven malformed), including valid regional, foliage and cleared masks.
`build/renderer-supported-house-02` repeats all eight checks on release build 09
after the camera corrections: entry from Fly on a
rotated foundation, indoor walking, actual context loss, exact world and selected
deck/rotation recovery, a selected shelf tier and return to the original Fly pose.

The independent critic's Pascal fault fixtures exercise real IndexedDB write
boundaries and recovery-worker timing. `-Case put-throw` and `-Case abort` retain
the complete previous checkpoint while the newer live world and both histories
remain usable, download that newer world through the real Export action, and
commit it after a successful retry. `-Case late-error` and `-Case late-success`
verify that a timed-out worker cannot change the recovered state or status and
that the original rejected checkpoint can actually be downloaded. The four
desktop runs pass 56 checks in `build/critic-recovery-put-throw-04`,
`build/critic-recovery-abort-01`, `build/critic-recovery-late-error-01` and
`build/critic-recovery-late-success-01`. The additional `-Case put-throw-phone`
passes 18 checks in `build/critic-recovery-put-throw-phone-02`, including a visible,
hit-tested touch target and validation of the actual downloaded world. These
cases are available through `tools/test-renderer.ps1` with the same compiler and
browser parameters. Earlier download-harness failures are retained: a separate
Blob-download control isolated the driver's mixed-separator output path, which
the final native driver normalizes before configuring Chromium downloads.
Phone run 01 exposed a warning obscured by the interaction hint; run 02 verifies
the same journey after raising and centering notifications. The overlay does not
intercept pointer input, and its message remains visible above world controls.

The common top Export also remains visible in interior and groundwork tools;
the older interior-specific Export remains available. The initial
`put-throw-house-phone` run verified actual indoor downloads but caught an indoor
camera change after reimagining an ornament. The exterior collision guard fixes
that defect: run 02 passes 24 checks, including separately recorded, exactly
equal poses before editing, after editing, before Export and after Export.
`tools/test-renderer.ps1 -Case put-throw-house-phone` run 03 passes 27 checks
on release build 09. Actual touch flight leaves the house footprint, First
person finds a valid position within the smaller room, and forward walking
continues. The same run retains the strict edit/save/export camera comparisons,
active interior and nested selection, and validates the actual 25,797-byte
furnished-world download. Its evidence is in
`build/critic-recovery-put-throw-house-phone-03`.

Desktop touch emulation does not establish phone GPU precision,
physical-phone FPS or recovery after OS process termination.

For code-only iterations after catalog packaging succeeds, `build-web.ps1
-SkipCatalogPackaging` rebuilds the runtime without repackaging unchanged optional
assets. CI and normal builds still package the catalog. This option does not
replace asset verification when catalog inputs change. Critic and device gates
remain open until their evidence passes.
