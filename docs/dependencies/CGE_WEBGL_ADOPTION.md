# Castle Game Engine WebGL bulk-transfer adoption

## Dependency identity

Phanes adopts Castle Game Engine changes only as an exact submodule commit. The
canonical upstream project remains
<https://github.com/castle-engine/castle-engine>. The designated delivery remote
for the reviewed WebGL numeric transfer commit is the maintained integration
fork <https://github.com/mr-highball/castle-engine>, using branch
`codex/phanes-webgl-bulk-upload`:

- reviewed commit: `25f2d98122997f8f039f759f9ffb76207b4f3cfe`
- reviewed parent and previous Phanes pin:
  `050f07edde6652d6657b4fe0d299822b9f502afa`
- changed raw source: `src/base_rendering/web/castleinternalwebgl.pas`
- isolated candidate source SHA-256 retained by the transfer report:
  `c4da0f1642a8ae3470f802a93ee647a362907d9fa18e82f0a209453e8984d081`
- adopted Git blob: `fa431aa5304c34a3fd5dbe20cd4c93530d5ffd79`
- adopted Git blob bytes SHA-256:
  `4bf06fc9dc2d80f9bf0acee277afbb75227132083db8cc4e4f10d5ad3f9e4845`

The fork does not replace the canonical project as the source of upstream
history. Keep the branch name for review and discovery, but build and publish
only the commit ID recorded by the Phanes gitlink. A branch head can move and is
not a reproducible dependency.

The fork branch advertises the reviewed commit, and a fresh sparse clone
retrieves its matching source. The Phanes gitlink and URL are staged together.
Integrated browser checks pass; independent adoption review remains pending.

## Review and adoption boundary

[CGE_WEBGL_TRANSFER.md](CGE_WEBGL_TRANSFER.md) records the isolated patch review
and its candidate evidence against the previous pin. That review established the
numeric bridge behavior without changing the Phanes dependency.

Application adoption is a separate step. It is complete only when all of these
conditions hold:

1. The reviewed commit is reachable from the submodule URL in `.gitmodules` in a
   clean clone.
2. `vendor/castle-engine` records the exact reviewed commit as its gitlink.
3. The Castle command-line tool and Phanes web application are rebuilt from that
   checkout rather than a separate engine tree or stale tool binary.
4. The final WASM, startup manifest and Pascal host binding identify the same
   build, and the required browser journeys pass against that bound output.
5. Independent review accepts this dependency change. Full Phanes publication
   remains subject to every registered feature's separate acceptance gate.

The isolated report must not be relabeled as application evidence. Candidate
build and browser evidence can be collected against the staged gitlink and URL;
publication requires them to be committed and verified together.

## Reproducing the pinned checkout

Start from a clean Phanes checkout. These commands use the URL recorded by the
repository, initialize the submodule, and verify the detached commit:

```powershell
git submodule sync -- vendor/castle-engine
git submodule update --init --recursive vendor/castle-engine
git -C vendor/castle-engine fetch origin
git -C vendor/castle-engine checkout --detach 25f2d98122997f8f039f759f9ffb76207b4f3cfe
git -C vendor/castle-engine rev-parse HEAD
git -C vendor/castle-engine merge-base --is-ancestor `
  050f07edde6652d6657b4fe0d299822b9f502afa `
  25f2d98122997f8f039f759f9ffb76207b4f3cfe
```

The first `rev-parse` output must be
`25f2d98122997f8f039f759f9ffb76207b4f3cfe`, and the ancestry check must exit
zero. Verify the reviewed file as raw Git object bytes; text decoding or newline
conversion would change this checksum:

```bash
git -C vendor/castle-engine cat-file blob \
  25f2d98122997f8f039f759f9ffb76207b4f3cfe:src/base_rendering/web/castleinternalwebgl.pas \
  | sha256sum
```

The expected first field is
`4bf06fc9dc2d80f9bf0acee277afbb75227132083db8cc4e4f10d5ad3f9e4845`.
This is the adopted commit's raw Git object checksum. The isolated transfer
report retains `c4da0f1642a8ae3470f802a93ee647a362907d9fa18e82f0a209453e8984d081`
for its earlier candidate source artifact. A working-tree checksum may also
differ when Git converts line endings, so do not substitute it for either
artifact-specific value.
Build the Castle tool from `vendor/castle-engine` and run the ordinary Phanes
build so `CASTLE_ENGINE_PATH`, the tool source and the application compiler all
refer to the same pinned checkout. CI follows this path through
`docs/PUBLISHING.md` and `build-web.ps1`.

Before committing an adoption, prove that a clean clone can fetch the gitlink.
The canonical upstream remote does not contain the reviewed commit. The
designated fork branch now provides it, so `.gitmodules` must retain that
fetchable delivery URL unless the commit is accepted by another reviewed remote.

## Rollback reference

The reviewed rollback point is
`050f07edde6652d6657b4fe0d299822b9f502afa`. A rollback is a new dependency
change: review it, update the submodule gitlink to that exact commit, and repeat
the full build, host-binding, browser and critic checks. Do not copy engine files
into Phanes or silently reuse binaries from the adopted commit. The following
commands show the intended gitlink operation for a reviewed rollback; they are a
reference and are not executed as part of adoption:

```powershell
git -C vendor/castle-engine fetch origin
git -C vendor/castle-engine checkout --detach 050f07edde6652d6657b4fe0d299822b9f502afa
git add vendor/castle-engine
git diff --cached --submodule=short -- vendor/castle-engine
```

If the submodule delivery URL is changed during adoption, review its rollback or
retention with the gitlink. The old commit is part of canonical upstream history,
but URL changes still affect clean-clone availability and CI trust boundaries.

## Application adoption evidence

A fresh sparse clone from the fork retrieves the exact commit and source in
`build/engine-adoption-remote-check-01`. This verifies remote dependency retrieval,
not a full clean-runner Phanes build. The staged Phanes gitlink is the reviewed
commit. The ordinary release build passes in
`build/logs/engine-adoption-main-build-01.log`, which records compilation of the
changed WebGL unit from the submodule. `build/engine-adoption-provenance-01.json`
binds the source, engine commit/blob, WASM, data archive, startup manifest and host.

The integrated optional-object journey passes 188 checks in
`build/engine-adoption-objects-01`: all fourteen interior models, desktop/phone
filters, exact unrelated-node preservation, Undo/Redo and actual graphics-loss
restoration. Rendered captures and a separate provenance manifest are retained.
The style journey passes 73 checks with 64 captures and 129 diagnostic timings
in `build/engine-adoption-styles-01`. It covers all 22 effects plus None,
repeated switching, exact None restoration, exterior/interior rendering, phone
layouts, shader-failure fallback and graphics recovery. These instrumented runs
are not physical-phone or populated-world performance benchmarks.
Independent adoption review remains pending. Full Phanes
release acceptance and its own Actions run are not established by AutoForge's
successful reference workflow or this local build.
