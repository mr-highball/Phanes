# Phanes: world creation through constraints

Phanes is an MIT open source WFC demonstrator, built and rendered with Castle
Game Engine, targeting the browser and the repository's GitHub Pages site.
The creator is an omnipotent designer, moving effortlessly between a whole
world, regions, structures, rooms, furniture and individual objects. Creation
should feel powerful and immediate. Useful shorthands are a core interaction,
not a secondary convenience.

The full objective is a compelling, technically exceptional example of 3D world
generation with WFC. Comparative superiority requires reproducible evidence;
the project must not describe ambition or a narrow smoke check as proof of a
state-of-the-art result.

## Required experience

The required terrain-to-individual-object granularity, named-container model,
catalog contracts and acceptance journeys are specified in
[GRANULAR_COMPOSITION.md](GRANULAR_COMPOSITION.md). These include independent
foundations, connected routes, Bay 5, shelf tiers, exact object counts and
replacement of a single object without changing neighboring contents.

- Start above the world with a top-down overlay and a creator-chosen region
  size. Refine selections progressively, using consistent world coordinates.
- Switch easily among overhead, orbit/multiple perspectives, fly-through and
  first-person views. Toggle editing and viewing without losing selections.
- Paint intent: fields here, flowers above them, shrubs there, a castle here.
  Reach inside an existing cabin to furnish a table with a full dining set.
- Select and replace any scale with WFC, from a whole region to a bookshelf.
  Preserve creator locks, unaffected surroundings and parent/child contracts.
- Offer expressive shortcuts and presets with inspectable, editable results.
  Undo/redo, cancellation and useful conflict feedback keep experimentation cheap.
- Build dedicated Phanes UI/input tooling wherever generic controls feel clunky.
  The creator should feel like they are playing and wielding creation abilities.
- Include creation and interaction sound effects, plus an evolving WFC-generated
  soundtrack built from at least 100 distinct references and at least 10 styles
  blending dreamy, synth and techno directions. See [AUDIO.md](AUDIO.md).
- Include many open 3D build kits, organized by medieval, modern, sci-fi,
  fantasy and other themes. Allow all themes to blend through a shared semantic
  compatibility system. A theme is a preference, not an arbitrary separation.
- Supply an explicit, versioned corpus describing every admitted asset's size,
  support, placement, adjacency, clearances and compositional relationships.
  Separate authored rules from learned observations. Preserve provenance and
  licenses. Unknown compatibility must not silently mean compatible.
- Apply WFC's layers, spatial mappings, learning, quotas, connectivity, scoped
  repair, negotiation, determinism, diagnostics and replay where they solve a
  concrete requirement. Show the actual constraint system behind the result.
- Scale generation and CGE rendering for web: worker isolation, bounded work,
  cancellation, reusable geometry, spatial chunks, culling and measured budgets.
- Publish tested builds using GitHub Actions to the owned Pages site. Runtime
  operation must not require a backend or an external asset CDN.

The possibilities should feel expansive through composable systems and rich
content. A fixed authored scene or a few random object arrangements cannot
fulfill this objective.

## Common world and interface identity

Use stylized forms with realistic surface detail. Establish a shared treatment
of palette, light, roughness and detail density across every theme: a castle
beside a rocket must belong to the same world. Preserve meaningful material
differences within that treatment. A photographic ground texture alone cannot
meet the required visual quality.

Buttons and glyphs must be custom Phanes work, aligned with emergence, light
and creation in the name's origin. Avoid stereotypical mythology decoration
and generic sparkle symbols. Keep actions recognizable, text legible and
interaction states explicit. See [INTERFACE_ART.md](INTERFACE_ART.md) for the
art direction, generation prompts and implementation boundaries.
