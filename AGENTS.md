# Phanes

Phanes is a Castle Game Engine project targeting the browser through FPC
WebAssembly and CGE's pas2js host. Read [docs/CODING_GUIDE.md](docs/CODING_GUIDE.md)
before authoring code and [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) before
changing project boundaries.

- Use Delphi mode and dotted, lowercase Pascal unit names rooted at `phanes`,
  such as `phanes.app.initialize` and `phanes.app.view`. Match filenames to unit
  names. External APIs and generated CGE files retain their original names.
- Pascal is the project language, including importers, validators, asset processing
  and other project tooling. Do not introduce Python scripts or a Python build/CI
  dependency. Use shell scripts only to orchestrate compiler and platform tools.
  Preview hosting and new browser automation use Pascal tooling from the pinned
  WFC dependency. Do not add Node servers or authored Node test harnesses.
- Follow [docs/PRODUCT.md](docs/PRODUCT.md) for the world creation objective and
  [docs/ROADMAP.md](docs/ROADMAP.md) for its completion evidence. Build original
  Phanes behavior and maintain this demonstrator's own identity and art direction.
- The application target is web. Native compiler/build tools are development
  dependencies, not additional application targets.
- `vendor/castle-engine` and `vendor/wfc` are pinned Git submodules. Do not edit
  their files here. Develop dependency fixes in separate checkouts, then update
  reviewed pins. Do not record contributors' absolute local paths.
- Explain non-obvious WFC cell/domain meanings, constraints, search limits and
  validation. Keep acceptance checks independent of rule construction. Exhausted
  search does not prove impossibility; weights do not prove optimality.
- Keep future numerical logic deterministic and independent of rendering and
  wall-clock time. Version data/message contracts deliberately.
- Include the complete root MIT notice in authored source and scripts. Preserve
  third-party notices. Record sources, licenses and transformations for imports.
- Build the web target and run relevant browser checks after runtime changes.
  Inspect desktop and phone layouts after UI changes. Store generated evidence
  under ignored `build/` and concise verification notes in documentation.
- Follow [docs/PUBLISHING.md](docs/PUBLISHING.md) for CI and Pages deployment.
- Treat responsive game-like interaction as a product requirement. Build Phanes
  UI/input tooling where generic controls make creation feel clumsy.
- Follow [docs/AUDIO.md](docs/AUDIO.md) for the generative soundtrack: at least
  100 traceable musical references, at least 10 dreamy/synth/techno styles,
  WFC-based cross-reference evolution, and creation/interaction sound effects.
- Feature completion requires an independent critic agent review following
  [docs/CRITIC_WORKFLOW.md](docs/CRITIC_WORKFLOW.md). The critic grades
  intuitiveness, accuracy, wow factor and thinking out of the box from F to A.
  Every category must reach B+ or higher before the builder may pass the feature.
  Address feedback and request another critic review until that gate is met.
  An untested or blocked requirement is not a passing result.
  Register produced features in `reviews/features.json`; retain critic-owned
  reports under `reviews/`. Changed scope or implementation needs a new review.
  Run `tools/reviews.ps1 -WithTests` before release. Do not bypass a hold or
  rewrite the critic's grades. Successful builds alone do not pass this gate.
