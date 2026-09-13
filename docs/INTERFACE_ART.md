# Phanes interface art

Phanes is a world-creation instrument. Its visual identity interprets emergence,
light and first formation through opening oval arcs, a small luminous core and
branching forms. This is original project art, not a claimed historical emblem.
The ancient [Orphic hymn to Protogonus](https://sacred-texts.com/cla/hoo/hoo10.htm)
provides the name's connection to first birth, the egg and light.

## Shared visual language

Warm ivory and muted sage forms sit on deep mineral surfaces. A fine champagne
edge signals an available creation action. Asymmetric opening curves repeat in
buttons, the mark, the music heart and the first-person reticle. A castle and a
rocket keep their recognizable silhouettes within the same material language.
No theme gets a separate visual skin.

Buttons retain text labels and native semantics. Art is decorative. Keyboard
focus has a high-contrast outline; pressed camera and music modes expose
`aria-pressed`; unavailable actions retain labels and use a dashed muted edge.
Play and pause use distinct simple cut forms. Zoom and movement use custom CSS
strokes that remain clear at small sizes. Those small control shapes are authored
CSS; the semantic atlas is generated art. Motion respects reduced-motion settings.

The music islands repeat the emerging core, with style color, connection text,
strength and a visible edge supplying state. Changing the shape of a node does
not change its audio constraints. Palette and lighting constraints for the
rendered world are separate from this interface artwork.

## Asset production

Built-in imagegen mode was used. No CLI, Python, API runner, downloaded icon
library or font glyph package is used. The selected image is served from
`web/art/phanes-glyphs-v1.png`; CSS slices the atlas at runtime. Prompts below
record generation and corrections. Rejected intermediate images are not shipped.
The root MIT license is the project's distribution license for authored assets;
this provenance record does not claim a third-party license or a historical source
for the generated shapes.

The generator returned an opaque painted checkerboard for both transparency
requests. A final built-in edit supplied a black compositing background instead.
The shipped PNG is RGB, not an alpha image. Runtime CSS uses screen blending
against opaque painted dark controls and panels; black contributes no light.
Transparent isolated tiles and outer glow filters are avoided because they
expose the opaque source rectangle. Cropping offsets center
the actual glyph silhouettes rather than assuming perfectly equal gutters.
The PNG is copied unchanged from the final output, with SHA-256
`75bcf483da5dfdcafc5b52213feaf46c0486a6841bff095d3dc474a88c5094da`.
This treatment is intended for the current dark interface; a future light theme
will need a separately reviewed asset/compositing treatment.

### Final production background

```text
Change ONLY the checkerboard background to absolutely uniform pure black RGB(0,0,0). This is a game sprite atlas that will be rendered using additive screen blending, so a pure black background is required. Preserve all 24 ivory, sage and champagne glyphs, their exact 6-column 4-row order and the 1536x1024 image dimensions. Remove every white/gray checker square, also inside the open holes. Every empty pixel should be #000000, with no texture, shadow, glow, gradient or checkerboard. Keep all glyph outlines crisp. Do not add anything. Pure black production compositing background.
```

### Initial generation

```text
Use case: logo-brand.
Asset type: production game UI glyph atlas, one single transparent PNG sprite sheet.
Design an original glyph language for PHANES, a playful world-creation instrument where forests, castles, spacecraft and music can emerge from connected possibilities. The name evokes first emergence and light from an opening cosmic egg. Interpret that through asymmetric opening arcs, small luminous cores and branching incisions, not literal mythology. The emotional register is curious, tactile, sophisticated and quietly alive.

EXACT ATLAS GEOMETRY: 1536 by 1024 canvas, SIX equal columns and FOUR equal rows, each cell 256 by 256. Exactly 24 separate icons. Centers x=128,384,640,896,1152,1408; y=128,384,640,896. Every icon must fit in a centered 174 by 174 area, leaving generous transparent gutters. No frames, no captions, no background decoration, no connecting elements between cells. True transparent alpha background, not a checkerboard illustration.

GLYPH ORDER, left to right:
Row 1: original Phanes emergence mark (two opening elongated shell arcs with a small bright core, NOT a star); forest (three branching trunks and canopies); wildflowers (asymmetric three-petal bloom and leaf); fields (three gently bending cultivated lines); water (two nested flowing ripples); cabin (recognizable roof and doorway).
Row 2: castle (two towers and arched opening); modern building (offset architectural volumes and windows); outpost (small shelter with a signal mast); rocket (upright tapered craft with fins); select region (four open corners around one small cell); reimagine (open circular growth arc surrounding three differently sized emerging seeds).
Row 3: undo (curved left arrow); redo (curved right arrow); music (two resonating curved filaments joined by a small pulse); explore (open path passing through a threshold toward a light); export (up arrow emerging from an open tray); open file (folded open container).
Row 4: overhead view (four terraced cells seen from above); orbit camera (tilted elliptical orbit around a solid core); fly camera (swept pair of abstract wings); first person (small head above two shoulders); clear region (small eraser brushing away three cells); arrange nodes (three unequal cores connected by two fine filaments).

STYLE: bold sculptural silhouettes with simplified negative-space cuts, not thin stock outline icons. Warm ivory ceramic illuminated along one edge, muted champagne inlay and a tiny sage reflection, restrained believable material microdetail, all consistently lit from upper left. Roughly 14–20px minimum strokes on this canvas so icons read at 28–36px UI size. Flat orthographic graphic presentation with very shallow relief; no perspective scenes or bulky toy 3D objects. Keep visual weights consistent. Alpha edges crisp; avoid diffuse outer glow. No letters or numbers anywhere. Avoid generic AI sparkle, four-point stars, runes, ornate fantasy RPG frames, gold medallions, ancient Greek props, neon cyberpunk, stock emoji, gear icons, multicolored app icon squares. This is contemporary original game craft, not a mythology theme.
```

### Shape simplification

```text
Edit this glyph atlas for production use. Preserve exactly the same 6 columns by 4 rows, 1536 by 1024 canvas, the ordering and meaning of all 24 symbols. REPLACE THE PRESENTATION: all background must become actually transparent alpha, including empty gutters and holes through icons. No colored background, no shadow plate, no checkerboard painted in.

Simplify every icon to a sophisticated, bold, nearly-flat cut-paper / incised ceramic graphic. The current illustrated miniature buildings and glossy gold ornaments are too much like a fantasy mobile game. Remove small scenic props, cracks, miniature bushes, extra decorative beads, gold outlines and wet gloss. Keep only one strong recognizable silhouette per cell, with a few generous negative-space cuts. Colors are matte warm ivory plus a restrained muted sage shadow plane; use champagne only as a tiny core accent. No halos or cast shadows. The Phanes mark remains two asymmetric opening oval arcs and a central seed of light. Keep strokes thick and material relief extremely shallow. Calm, original contemporary world-creation interface, visually consistent castle and rocket, no historical theme. Center every icon on its exact 256px cell center; each complete icon fits within 172px square with transparent margin. No captions or text. Real transparent PNG is essential; the image will be placed over a dark game UI.
```

### Background correction

```text
Background extraction only. Preserve every glyph's exact shape, position, scale, colors and 1536x1024 six-column four-row layout. Remove the ENTIRE white and gray checkerboard background, including all holes inside the glyphs. It is currently painted into the image and must be removed. Return a PNG with a real transparent alpha channel: all background pixels must have alpha=0. Do not draw a checkerboard, white, gray, beige or any other backdrop. No shadows outside glyph silhouettes. This is a transparent UI sprite atlas, not a preview illustration. The only visible pixels must belong to the 24 glyphs.
```
