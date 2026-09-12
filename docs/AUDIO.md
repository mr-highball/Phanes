# Phanes generative audio

Audio is part of the creation experience. Interaction feedback should make
selection, creation, replacement, undo and movement feel responsive and playful.
Music should combine dreamy atmosphere, synthesizer textures and techno motion.

## Current implementation and provenance

The admitted library contains **135 distinct scores**: 112 public-domain editions
from the [Mutopia Project](https://www.mutopiaproject.org/legal.html), plus 23 CC0
MIDI pieces from [Aureolus_Omicron](https://opengameart.org/content/15-melodic-rpg-chiptunes),
[Roppy Chop Studios](https://opengameart.org/content/original-midi-album), and
[Alex McCulloch](https://opengameart.org/content/rewind). The score library supplies
symbolic musical material; the dreamy/synth/techno arrangements and synthesis
are Phanes code. These references are not claims to imitate named performers.

`data/music/references.json` records each source, composer/editor, license,
download location, original file and SHA-256 hash. Preserved MIDI, LilyPond
editions and source license pages are in `data/music/sources/`. Their public
domain/CC0 status is retained; the root MIT license applies to authored code.

The native Pascal tool `tools/phanes.assets.lpr`, invoked through
`tools/assets.ps1 -Action import-music`, derives `data/music/corpus.json`.
`verify-music` recomputes it and requires an exact match. Deduplication ignores
encoding, track separation, velocity, PPQ resolution and absolute transposition,
using normalized onset/duration/pitch tuples. It does not count alternative
encodings or transpositions as additional references.

## Extraction contract

The Pascal MIDI parser accepts formats 0/1 with PPQ timing. It pairs note-on/off
gates by track, channel and pitch, including running-status events. Percussion
channel 10 is excluded. Tempo, instrument programs, sustain controllers and
expressive MIDI controls do not enter the learned samples. Key-down duration is
not the same as a pedal-sustained performance.

Each score is fitted to a major/minor scale using a duration-weighted pitch-class
histogram, with small tonic/fifth preferences. This is a deterministic estimate,
not an authoritative key analysis. Pitches are projected to seven scale degrees;
chromatic detail can be lost. Up to three distinct eight-bar windows are sampled
near the beginning, middle and end, yielding **393 excerpts**. Their starting
beat offsets are retained.

At each quarter-note beat, the extractor records the highest sounding degree,
the lowest sounding degree, a four-bit sixteenth-note onset mask, and a coarse
note-density value. A lowest note is only a harmonic proxy, not a chord label.
The renderer's chord voicings and musical modes are explicit arrangement rules.

## Generation and arrangement

Every reference trains the harmony, melody, rhythm and density sequence models.
Each model has order two, retaining one preceding token. Four different source
anchors are rotated through the dimensions: every unlocked dimension visits all
135 references once per 135 sections at a fixed style and seed in the coverage
fixture. Live tracks use fresh entropy for each section and sample that shared
pool; one track does not promise to anchor every source. The anchored four-beat
excerpt and generated neighboring material have distinct meanings: the former
is traceable borrowing, while the latter follows combined corpus frequencies
and observed transitions. This process can reproduce recognizable phrases.

Harmony and melody share a negotiated WFC graph with learned paired-degree and
relative-interval passes. The order-one paired-degree pass checks simultaneous
pair membership; it does not preserve observed transitions between pairs. The
order-two interval sequence checks changes in their relation. Broad corpora can
admit many combinations; these checks do not prove musical quality. Rhythm and
density resolve their own learned sequences. Ordinary two-style generation
requires both connected arrangements to appear in its eight bars.
Each solve is bounded; failure is reported without silently dropping a lock.

Ten styles vary tempo, scale mode, lead stride/arpeggiation, bass spacing, pad
length, drum patterns and filter character. The strongest connected style anchors
the harmonic mode (the first style by index breaks a tie). Pads, triad alignment on strong beats,
bass voicing, drum synthesis and ornamentation are authored transforms. They are
not recordings or exact reproductions of source MIDI performances.

The Pascal browser player compiles through pas2js, runs generation in a worker,
and schedules Web Audio nodes ahead of the audio clock. Music and interaction
effects use separate contexts so pausing music can preserve its scheduled notes
while effects remain available. Original scores are development inputs; the
browser loads the compact derived corpus and source manifest.

The feature remains under critic review. Initial native generation, source
coverage and browser startup checks are evidence of working components, not a
passing quality grade or a completed soundtrack milestone.

## Tracks and the music dimension

The player identified Slow Aurora, Liquid Machines, Dawn Spiral and Glass Tides
as the strongest listening examples and confirmed the intended musical direction.
Keep those as quality references while retaining all ten groups.

Every new track has a WFC-generated macro form: arrival, drift, flow, crest and
landing. These forms are authored musical constraints; the phrases still come
from the shared score corpus. Complete eight-bar movements total at least 304
seconds before their release tail, giving headroom over the five-minute minimum.
At the supported 60–160 BPM, plans contain 10–28 movements and last up to 390
seconds. The browser draws fresh cryptographic entropy for each new track and
its phrases; it does not replay a fixed seed or loop a rendered recording.
Pause/resume preserves the current composition and audio clock. New track,
style/strength changes and lock changes start a fresh composition. Playback
automatically creates another fresh track after the current one completes.

Floating style nodes connect to a central mixer in the music dimension. Their
strengths supply WFC arrangement weights. One featured bar per movement rotates
through the connected groups, so every connected group participates in the
track; remaining bars use the relative weights. Strength is influence, not an
exact duration quota. The central BPM pulse and highlighted connectors follow
the actual playing beat and arrangement. Tempo can follow the weighted blend
or be set explicitly. Dragging a node rearranges the workspace; connecting it
or changing its strength changes the sound. Desktop keyboard navigation and
phone transport controls are part of this feature.

The player schedules the current and next complete phrase into Web Audio, so
ordinary main-thread scene work does not interrupt their notes. At most two
phrases plus release tails are scheduled; scheduled nodes have a fixed cap and
ended nodes disconnect. Active voices are measured separately from future
scheduled voices. Tests must include world editing during full-length playback.

## Required soundtrack

- Acquire at least **100 distinct musical references** with attributable source
  URLs, version/content hashes and redistribution-compatible licenses. Alternate
  encodings, duplicated files and trivial transpositions do not count as new
  references. Preserve the original material and document training extraction.
- Use WFC to learn and combine musical constraints across those references.
  Mix melody, rhythm, harmony, voice relationships and evolving section
  constraints in multiple ways. A shuffled playlist or synth presets applied
  to one composition does not fulfill this requirement.
- Provide at least **10 musically differentiated styles** spanning and blending
  dreamy, synth and techno directions. Style changes should affect composition,
  arrangement and sound design, not only names or tempo.
- Let the soundtrack evolve through new constrained sections while keeping
  transitions coherent. Make source participation inspectable and verify that
  all admitted references can contribute across the system's combinations.
- Provide complete WFC tracks of at least five minutes with fresh variations
  for each new playback, and a spatial music dimension whose style connectors,
  blend strengths and visible BPM genuinely control the generated soundtrack.
- Generate locally in a worker, schedule audio smoothly, and retain bounded
  frontier/history state. Keep the UI responsive during learning and generation.
- Provide music and effects volume/mute, pause/resume, style/blend selection,
  and understandable credits. Start audio through a creator gesture and respect
  browser lifecycle behavior.
- Add authored/synthesized sound effects for meaningful creation and navigation
  actions. Mix them with music so feedback remains clear and comfortable.

## Completion evidence

The audio milestone requires a deduplicated 100-reference manifest; source and
license validation; reproducible extraction; WFC generation and cross-reference
participation tests; at least 10 arrangement/style fixtures; measured generation
and audio-scheduling behavior; rendered listening samples; and actual listening
review. Statistical recombination can repeat or reproduce phrases: novelty and
quality must not be asserted from successful generation alone.

This requirement is part of the full world-creation goal, alongside nested
world generation, UI/UX, rendering performance and publication.
