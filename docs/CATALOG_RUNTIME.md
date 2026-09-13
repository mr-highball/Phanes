# Optional catalog runtime contract

This is the integration contract for the accepted catalog expansion, not a claim
that optional assets are already playable. Acquisition is complete enough to
proceed. The existing 19 regional choices and fixed interior profiles remain
the only admitted choices until the path below is implemented and reviewed.

## Existing interfaces and ownership

`phanes.tools.catalog` already publishes `data/library-files.json`, hashed kit
manifests and shared `library/blobs/<sha256>` files. Each manifest binds the
inventory, model ID, original relative filename, complete dependency closure,
byte lengths and original license notice. Preserve these original bytes and
relative filenames; rewriting glTF URIs is unnecessary.

The Pascal browser controller owns asynchronous fetch, cancellation, integrity
verification and progress. Use fetch integrity as the startup downloader does,
including on plain HTTP LAN previews where Web Crypto may be unavailable.
Manifest lengths describe decoded bytes. GitHub Pages may gzip a response and
retain its compressed `Content-Length` header while Fetch exposes a decoded
stream. The loader checks the streamed byte count and Fetch integrity instead
of comparing that header to the manifest. `tools/test-catalog-fetch.ps1` covers
compressed transfer headers with real GLB/glTF closures and rejects truncated
decoded bodies; the index and file stream limits remain enforced.
The native Castle renderer owns decoded scenes and material treatment. Its
existing `RawAsset` currently loads only `castle-data:/kits/<id>.glb` and caches
each template until view shutdown; that is not a bounded optional-asset cache.

The pinned engine exposes `TCastleMemoryFileSystem.RegisterUrlProtocol`, writable
streams through `CastleDownload`, and JOB `IJSArrayBuffer.CopyToMemory`. This
supports passing verified files into a temporary model filesystem with original
relative paths, then loading a normal Castle scene from its root model URL.
No dependency edit is justified by the interfaces inspected so far. A browser
proof must exercise both a self-contained GLB and a glTF with external texture
and buffer dependencies before this becomes the production loading path.

## Atomic load and placement

1. The player chooses an admitted item in category, subcategory and item controls.
   Its admission record binds a stable ID and exact source hash to function,
   theme, metre transform, contact bounds, support/connector requirements and
   advertised capabilities. Static bounds or a kit name cannot confer a role.
2. Resolve the kit's small manifest and verify its hash and inventory binding.
   Validate the exact model, dependency and notice paths, lengths and hashes.
   Resolve publication-relative URLs against the application base so Pages
   project paths and LAN root paths behave identically.
3. Fetch only missing files, with bounded concurrency, size and time limits.
   Show item-specific progress and cancellation while the current world remains
   editable. Identical content can share downloaded bytes. A new request or world
   edit invalidates the pending placement's revision; late completion cannot
   apply to a newer selection or overwrite a newer world.
4. Stage the complete verified closure in an isolated Castle filesystem. Load and
   measure the scene, apply the common surface treatment, and check the admission
   transform and bounds. Failed decode or missing dependencies discard staging.
5. Run WFC and the independent decoded placement validator using the admitted
   physical profile. Commit the model lease and world/history change together
   only after rendering resources are ready and the request revision is current.
   Failure or cancellation leaves world, history, selection and resident assets
   intact. No placeholder is silently committed as the selected item.

## Lifetime, saves and acceptance

Bound network buffers, staged filesystem bytes and decoded/GPU resources
separately; compressed download size is not a memory bound. Release staging bytes
after safe scene preparation only when Castle no longer needs the original files.
Scene references in resident world chunks retain leases. Cache eviction may
remove unused templates, never live scene dependencies. Budget pressure must
produce a useful response instead of unbounded accumulation or repeated thrashing.

Saves retain stable admission IDs and source revisions, not temporary URLs or
downloaded bytes. Import, Undo/Redo and renderer recovery resolve required assets
before swapping the visible world. Missing or unavailable assets preserve the
previous valid world and explain how to retry. Source notices remain accessible.

Acceptance requires actual optional-model placement across the requested
categories, coherent scale/materials, context-aware WFC constraints, searchable
desktop/phone controls, preservation tests, adverse network/cancellation tests,
save/recovery tests, and sustained measured memory/frame behavior. A loader proof
or a few admitted samples are milestones within the full catalog feature, not
a replacement for its required coverage or independent B+ review.

## First bounded implementation

Implement and test the verified per-model fetch transaction independently of
world mutation, then connect its completed file bundle to the existing Castle
APIs in a small browser proof. This is suitable for a Sol builder with Medium
reasoning because asynchronous cancellation, shared bytes and revision checks
need explicit invariants. Astra retains the cross-layer commit/lifetime design.
Use the existing manifests and two real optional models; do not create a second
publication format or download the full library to demonstrate this path.

## Adapter checkpoint

`cge/code/phanes.catalog.files.pas` now stages a model closure in its own Castle
memory filesystem with a 64 MiB maximum source budget, a 4,096-file maximum,
canonical relative paths and an immutable sealed root URL. Each bundle remains
owned by its caller until its scene no longer needs source resources. It does
not yet implement the global decoded/GPU cache budget or commit world edits.
Case-only filename collisions are rejected because the pinned memory filesystem
does not configure its internal string list for case-sensitive lookup.

The WASI adapter consumes the browser fetcher's completed
`{generation, rootPath, files: [{path, buffer}]}` object with a bounded bulk copy
per file. The caller supplies the expected fetch generation and must separately
check its world/selection revision before commit. Complete staging precedes
release of the browser lease. Original paths and source bytes are retained.

`tools/test-catalog-files.ps1` runs 42 native checks, including real optional
GLB/glTF decode parity, byte budgets, path/case checks, isolated namespaces and
destruction. The soy-sauce fixture retains all 60 triangles and 11,880 source
bytes; the rug fixture retains all 44 triangles and its complete 20,376-byte,
three-file closure. Both transformed geometry hashes equal direct source loads.
The optional `-WebCompiler` argument also compiles the WASI ArrayBuffer adapter.
Current logs are `build/logs/catalog-files-native-test.log` and
`build/logs/catalog-files-web-build.log`. This proves native decode and web
compilation; actual browser texture/render verification and independent review
remain required before integration is accepted.

The subsequent isolated Castle browser probe now passes 12 checks in
`build/catalog-runtime-browser-03/evidence.json`, with desktop food/rug captures
and a phone-layout rug capture. The rug's original material uses a color texture,
with no base-color-factor override; the captured gold surface verifies that the
external PNG is used. Neither browser runtime errors nor resource warnings were
reported. Source, host and WASM hashes are in
`build/catalog-runtime-provenance-01.json`; this probe uses the unchanged pinned
engine, not the experimental transfer checkout.

The probe's startup archive is 676 bytes and contains no models. GLB staging uses
36,249 bytes including its 24,369-byte source notice; the glTF uses 21,203 bytes
including its 827-byte notice. After copying, the test releases the fetch lease,
clears unpinned cache entries and removes the browser's bundle reference. The
Castle scene retains its own filesystem. A later stale-generation request leaves
the displayed rug intact. These are browser fetch/copy/render observations, not
proof of world placement, global scene budgeting or save/recovery integration.

`tools/test-catalog-fetch.ps1` separately passes real root/project-path fetch,
cache reuse, cancellation, stale-generation and corrupt/missing/oversized/invalid
publication cases in `build/catalog-fetch-clean-proof`. Its driver uses the
freshly served probe compiled by that invocation, without another build folder.
The combined loader still requires independent review before integration.

The reusable browser render entry point is `tools/test-catalog-runtime.ps1`.
It generates and builds the isolated Castle probe against the pinned engine,
compiles a fresh Pascal fetch probe, stages only the two fixtures' dependency and
notice closures, starts an owned Pascal server, runs the native browser driver,
and stops its server afterward. Put the prepared WASI compiler/toolchain on PATH
for Castle, and pass `-NativeCompiler`, `-Compiler` (pas2js), `-Browser` and an
optional `-EvidenceDirectory`. Published `build/web/data/library-files.json` and
its referenced fixture files must already exist. Its build directory is separate
from the manually inspected preview to avoid rebuilding an actively served tree.

The fresh wrapper run in `build/catalog-runtime-wrapper-02` passed all 12 browser
checks, retained all three captures, reported no server errors and stopped its
owned listener. Its `provenance.json` binds the current wrapper, renderer/fetch
sources and generated runtime files. This is the reproducible successor to the
manual `catalog-runtime-browser-03` run; use the wrapper build as the retained
runtime stage. Independent cache-ownership review remains open, so the adapter
is not yet connected to live world mutations.

The bounded review in `reviews/catalog-runtime-bounded-02.json` found that cache
eviction could discard a staged unpinned entry without reserving its reinsertion,
and that duplicate hashes could be downloaded twice within a transaction. The
corrected fetcher deduplicates transaction entries, recomputes unique missing
bytes after the final await, protects incoming hashes during eviction and commits
synchronously within its budget. Its default and maximum remain 96 MiB; a smaller
constructor budget exercises the same algorithm without large test allocations.

The fresh complete fetch run in `build/catalog-fetch-bounded-root-01` passed;
`build/logs/catalog-fetch-bounded-root-01.log` retains the execution output. It
includes 13 focused assertions for a 12-byte cache: cold duplicate paths share one
download/buffer, pending-file staging survives a deterministic clear, near-budget
eviction preserves incoming data, failed/cancelled transactions preserve existing
leases, and releasing duplicate paths balances all pins. The fixture publisher
is native Pascal. Existing real-model root/project and invalid-publication cases
also pass, with an empty server error log and the owned listener stopped. This
correction is awaiting independent re-review. Earlier Castle rendering evidence
uses the previous fetcher; its unchanged filesystem adapter and renderer evidence
do not alone verify these new cache invariants.

## Production publication handoff

`cge/code/phanes.catalog.scene.pas` now owns a decoded scene and its source
filesystem as one lease. It consumes a sealed source bundle before decoding;
constructor failure releases both resources. Invalid or unsealed input remains
with its caller. It rejects empty or non-finite geometry and uses the viewport's
public `PrepareResources(scene)` API with an open graphics context before the
probe replaces the visible model. Borrowed viewport/template references must be
removed before lease destruction; the scene is destroyed before its files.
The lease itself does not establish decoded or GPU memory budgets.

The current native suite passes 49 checks, including constructor-failure cleanup
of the registered source protocol and both real models' geometry parity. The
combined Castle run `build/catalog-runtime-lease-02/evidence.json` passes 18
checks: successful replacement, stale generation, failed decode preserving the
previous model, and successful retry. The phone rug/retry captures were inspected;
there are no browser errors or resource warnings. Draw acknowledgment now comes
from `RenderOverChildren`, after the viewport actually draws, rather than from an
assumed number of update frames. These results use the streamed fetcher before
its subsequent cancellation-promise cleanup. The complete successor run in
`build/catalog-runtime-lease-final` also passes all 18 checks with no browser
errors or warnings. Its generated `provenance.json` binds the current input files
and runtime artifacts with raw SHA-256 hashes and records the pinned engine
commit. The wrapper checks that input hashes remain unchanged during the run.

The current complete fetch suite passes 67 checks in
`build/logs/catalog-fetch-cleanup-test.log`, with fixtures retained in
`build/catalog-fetch-cleanup-final`. The shared response reader checks each chunk
against the remaining allowance before copying. Oversized chunked index,
manifest and model responses cancel without partial cache state. Real-stream
read failure preserves the original error and existing leases; its cancellation
promise is consumed and the reader lock released without an uncaught rejection.
Exact-size responses allocate their final destination once; the 256 KiB index
may additionally own a trimmed copy. Browser-internal Fetch/SRI buffers and the
chunk supplied by the browser are outside this application-owned copy bound.
Independent review of this correction and the scene lease remains pending.

The current call-site audit finds four publication paths: worker success,
Undo, Redo in `web/phanes.editor.js`, and `TSessionUI.Apply` in
`src/phanes.session.ui.pas`. Import uses worker success. Session recovery calls
the exported `publish` action directly and also restores selection, history,
tools and camera; changing only the worker callback would leave it unprotected.

Introduce the asynchronous preparation coordinator in Pascal. Keep the existing
synchronous editor publication as the final commit binding. Each candidate owns
its proposed world, post-commit UI state and history operation without modifying
the current editor state. Undo/Redo must peek at their destination snapshots;
their current pop/push operations move inside the successful commit. Recovery
must stage the entire checkpoint before applying its selection or tool state.
The worker callback's create/import selection reset and `interiorAssets`
assignment also move inside that commit.

Resolve every distinct optional admission referenced by the candidate's regional
layers and composition. Historical snapshots retain IDs and resolve on use;
they do not pin decoded models indefinitely. Request identity includes the world
revision and selection revision, independently of the fetcher's generation.
A new edit, selection change, replacement request or recovery cancels obsolete
preparation. Camera movement alone may continue. Check identity after each
asynchronous boundary and immediately before the synchronous commit.

Castle must acknowledge complete decode, measured admission bounds and prepared
rendering resources before a candidate can commit. Prepared scenes and their
source files belong to a candidate lease until activation. A failed preparation
destroys only that lease. Download-byte limits do not establish decoded mesh,
texture or GPU limits; admission and resource accounting must cover these before
the production path can accept a model. The main view's current `ApplyWorld`
changes appearance and landscape state as it runs, so it cannot serve as this
preparation acknowledgment.

On activation, retain the previous world's model leases while its old chunks or
interior still reference templates. `BuildChunk` destroys the replaced chunk
only after constructing its successor. `phanesWorldRendered(revision)` currently
acknowledges a drawn frame with zero pending chunks; pair that current-revision
acknowledgment with interior replacement before retiring old leases. Free derived
interior/assembly templates before their raw models, and raw scenes before their
isolated filesystems. Do not insert optional scenes into the existing unbounded
`FTemplates` cache without explicit ownership and eviction for these references.

Production acceptance must exercise failures through all four publication paths,
including checkpoint restoration. Verify exact preservation of world, selection,
history/future, tool state and active leases on failure; then verify successful
retry, cancellation after an intervening edit, appearance changes, chunk turnover
and renderer recovery with the same admitted source revisions.
