# Live visual styles

The player can choose at least 20 distinct visual treatments through Castle's
shader framework. None is the default regular rendered view, with no extra
post-processing pass. Style changes are view preferences and must not regenerate
or modify the world, selection, camera, undo history or music transport.

The current implementation defines 22 named effects plus None in
`phanes.styles.catalog`. A single Castle `TScreenEffectNode`, attached directly
to the existing viewport, receives style, intensity and detail uniforms. It is
created lazily and reused across choices. None and zero intensity disable the
node; no neutral full-screen shader remains active. The viewport owns its node
graph, and the Phanes controller removes it during view shutdown.

The shader uses the normal color buffer and no depth texture, animation/history
buffer or geometric screen warp. The effects include toon/ink/drawing treatments,
print and pixel patterns, diffuse lighting treatments and spectral palettes.
Thermal palette is a false-color appearance, not simulated temperature.
Post-processing deliberately changes detail; small-object visibility, picking
and selection feedback need actual browser review in every family.
The selected item's projected bounds receive light/dark corner markers after
the shader pass. Those cues remain readable under coarse pixel and false-color
treatments. They indicate selection bounds, not a visible-surface silhouette.
The normal None view retains its existing selection rendering. Pattern sizing
tracks the actual viewport drawing-buffer/CSS ratio, including browser zoom.

The Pascal HTML controller provides a compact Style trigger, searchable grouped
choices, intensity/detail sliders, Restore original, and a comparison toggle.
The panel stays separate from the world shader. Its palette swatches are
illustrative motifs, not captured previews of the rendered world. Applied state
is acknowledged only after the viewport frame; shader failure restores None.
The view state is session-only and a new page starts at None.

The complete browser journey passed 73 checks and retained 64 captures in
`build/engine-style-fallback-full-01/evidence.json`. It exercises all 22 effects
plus None in populated exterior/interior scenes, repeated live-switch cycles,
exact None round trips, four phone viewport layouts, picking and preservation of
world/history/selection/camera. Real GLSL compilation failure restores None with
a useful explanation; graphics recovery reloads the renderer and preserves the
exact saved world, Undo/Redo, style and session before subsequent style changes.

The runtime explicitly prepares the screen effect using Castle's public API and
enables its render pass only after positive shader validity. This also handles
the pinned WASI renderer's compilation-failure path, which does not reliably
raise an exception or publish negative validity. Focused before/after evidence
is retained in `build/style-focused-frozen-01/failureDiagnostics.json` and
`build/style-focused-fixed-01/evidence.json`.

The tested build is an isolated development candidate, with exact WASM/host/data
bindings in `build/web-style-fallback-01-evidence.json`. Dependency pins have not
changed. Resource probes retain stable live texture/framebuffer counts through
repeated switching; heap observations do not establish a bound on total GPU or
WASM memory. Scene load and hardware still affect responsiveness: the separate
large-world engine comparison reaches approximately 15 FPS in Orbit on the
development machine, so this is not proof of the full mobile performance goal.
Phone viewport checks are automated desktop-browser evidence. The user's actual
phone confirmation covers improved shadows and Orbit on the earlier engine
candidate, not the full style/failure/recovery journey on this build.

Independent Luna report `reviews/visual-styles-01.json` found the runtime evidence
complete and requested this documentation update. The registry must point to a
fresh passing review of the current inputs before feature acceptance. The design
matrix remains in `build/critic/visual-styles-design-01.md`.

Local previews use the pinned WFC Pascal static server through `tools/serve.ps1`.
New browser verification uses native Pascal and WFC's CDP transport, with real
Chromium pointer/keyboard input and screenshots. The older repository browser
harnesses still need migration; they are not a precedent for new Node tooling.
