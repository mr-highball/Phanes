# Shared foundation and dependencies

- Phanes code, development tooling and authored composition rules are MIT,
  copyright 2026 mr-highball.
- [Castle Game Engine](https://github.com/castle-engine/castle-engine) is pinned
  at `050f07edde6652d6657b4fe0d299822b9f502afa` for initialization. Its license
  notices and bundled resource attribution remain in `vendor/castle-engine`.
- [WFC](https://github.com/mr-highball/wfc) is pinned at
  `47fa3d8cb8f0f72bf53943eb5eb79758c8f22ce4` for initialization. Its MIT notice
  remains in `vendor/wfc/LICENSE` and its source headers.
- Free Pascal and pas2js are build dependencies. Their source revisions are
  pinned in `tools/ci-toolchain.sh`; their original licenses apply.

The current dependency revisions are always the Git submodule entries. Preserve
third-party notices when distributing runtime resources.

The six Kenney CC0 model kits are credited in [ASSETS.md](ASSETS.md), with exact
source URLs, archive hashes and per-model hashes in the asset manifests. Their
license notices remain under `cge/data/kits/`. Phanes code and authored placement
recipes are MIT; imported assets retain CC0.

The generative soundtrack's 135 source scores and their public-domain/CC0
attribution are documented in [AUDIO.md](AUDIO.md) and individually listed in
`data/music/references.json`. Original source materials and license evidence
remain in `data/music/sources/`. Phanes synthesis, arrangement and extraction
code is MIT.
