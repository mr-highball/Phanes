# Phanes audio feature critic — review 1

Scope: the complete generative soundtrack / sound studio increment, its Pascal
corpus tools, and the affected creation interactions. This is not a review or
completion claim for the full world creator. Reviewed source on 2026-09-07 while
the builder was still completing browser compilation and playback evidence.

Decision: **FAIL / changes and evidence required**. Each category must reach B+
individually. These are provisional grades of the currently evidenced feature;
they do not certify untested playback.

| Category | Grade | Reason |
| --- | --- | --- |
| Intuitiveness | C | Clear studio vocabulary and controls are present, but Evolve discards the state needed by locks. Global Tab handling interferes with keyboard access to the studio. Desktop and phone journeys remain untested. |
| Accuracy | C | Independently verified 135 distinct licensed, hashed scores and reproducible extraction. Real learned WFC sequence generation is present, but audible lock semantics, the full secondary-style blend endpoint, and learned cross-voice relationships do not meet their contracts yet. |
| Wow factor | C | Ten differentiated arrangement definitions and a custom synthesizer are implemented. Actual sound, seams, interaction polish and perceptible style quality have no listening or rendered evidence yet; source inspection cannot establish the desired dreamy/synth/techno result. |
| Thinking out of the box | B | Four reference-derived dimensions, independently lockable evolution, inspectable source anchors and style mixing are useful original combinations. The central interaction is currently broken, and the dimensions do not yet negotiate learned voice relationships. |

## Blocking corrections

1. `TAudioPlayer.Evolve` invokes `Restart`, which terminates and initializes a
   fresh generator. Its `FHasPrevious` is false, so all requested locks are
   ignored. On automatic generation the saved previous section is also the
   queued section, not necessarily the audible one the creator intends to keep.
   Preserve the actual audible baseline through edits and test each lock with
   all other layers free, including repeated Evolve and changes during pending
   generation.
2. `ArrangeMusic.Pitch` always uses `LPrimary.FMode`. A blend of 100% secondary
   style therefore keeps the primary harmonic mode. Make endpoint behavior
   consistent and verify composition as well as tempo and instrument identity.
3. Four independent learned sequence lanes provide no learned cross-voice
   constraint. Strong-beat triad remapping is an authored lossy arrangement rule.
   Implement and independently validate useful learned voice compatibility;
   document the extraction and transformations honestly.
4. World keydown handling hijacks Tab from buttons, summaries and links once a
   world exists. Restrict game shortcuts appropriately, preserve standard focus
   traversal, and provide predictable panel opening and closing focus. Exercise
   keyboard and phone journeys with music running and world editing active.
5. Meaningful SFX coverage is incomplete: generic click notes and a world-render
   chime do not establish the required navigation and creation action feedback.
   Exercise pointer and keyboard action parity, rejection and recovery, and
   independent effects/music control.

## Evidence still needed

- Browser build, actual initialization and playback, desktop and phone layouts,
  root and project-subpath loading, error-free operation with the Castle scene.
- Live pause/resume and background/foreground behavior; locks against audible
  state; blend endpoints; repeated rapid control changes and pending requests.
- Measured scheduling with long-enough playback to cover multiple seams, world
  edits during playback, no unacceptable dropouts, and bounded voice/state use.
- Rendered samples of every style plus meaningful blends and multi-section
  evolution. Actual listening is required to assess coherence, differentiation,
  texture, mix and transitions. Waveform statistics alone do not prove quality.
- Generator fixtures for all styles/blends with independently checked events,
  source anchors, learned compatibility, seam behavior and invalid requests.
- Concise docs describing the admitted corpus, extraction losses, arrangement
  rules, source participation, musical claims and reproducible verification.

## Independent checks completed

- Read source tools, generator, wire protocol, worker, synthesizer, player,
  current editor shortcuts, studio HTML/CSS and native music test source.
- Ran `build/tools/phanes.assets.exe verify-music .`: **passed**, 135 distinct
  scores / 393 WFC excerpts / 233043 corpus JSON bytes.
- Inspected existing `build/music-evidence.json`: native coverage and source
  anchors for all 135 references in each lane, one initial determinism fixture,
  locks against generator previous state, and ten arrangement fixtures exist.
  These tests do not test the live player's audible-lock or pause semantics.
- No authored Python scripts/dependencies or other-project branding found in
  the searched authored tree. Existing JavaScript remains in browser host/QA;
  the new musical implementation and corpus extraction are Pascal.

The builder has acknowledged the first four code blockers and is implementing
corrections. Re-review the actual revised result; do not promote these grades by
promise or by averaging.
