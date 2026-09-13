# Browser build and GitHub Pages

`.github/workflows/pages.yml` builds pushes to `main` and `hello-phanes`, pull requests
to `main`, and manual runs. Only successful `main` runs outside pull requests
deploy the verified static Pages stage to the `github-pages` environment.

Publishing also requires the independent [critic gate](CRITIC_WORKFLOW.md).
Builds retain their evidence while reviews are pending, but `critic-gate` fails
and Pages upload/deployment stays on hold until every registered feature has a
current critic report with at least B+ in every category. Run
`./tools/reviews.ps1 -WithTests` locally for the same check and per-feature reasons.

The Ubuntu 24.04 runner installs an FPC bootstrap, builds pinned FPC and pas2js
revisions using `tools/ci-toolchain.sh`, and caches the toolchain by script hash.
It checks out both submodules from the URLs in `.gitmodules` at their recorded
commits, builds the Castle tool from that source, then verifies the imported asset
corpus and compiles the web target, Pascal world worker and dependency smoke check.
The Castle fork, exact commit, canonical upstream ancestry, clean-clone check and
reviewed rollback point are recorded in
[the WebGL adoption guide](dependencies/CGE_WEBGL_ADOPTION.md). A dependency
gitlink is publishable only when its recorded submodule URL can serve that commit;
an isolated engine checkout or moving branch name cannot satisfy CI provenance.
No application binary or developer installation is required on the runner.
The build script invalidates authored `phanes.*` compiled-unit artifacts together
before Castle compilation. This prevents stale indirect callers from retaining
an incompatible returned-record layout after a shared Pascal type changes.

The compiler bootstrap is shared with AutoForge commit
`bf5fce2108266cc84c86336ba06f533350e682e8`. Its
`tools/ci-toolchain.sh` is byte-identical to the Phanes script at SHA-256
`1b884dcf316f798fde968966f777402796ac98ae6fb03a5244c7523432761c31`.
Phanes follows the cache sequence demonstrated by
[AutoForge Actions run 34160777525](https://github.com/mr-highball/AutoForge/actions/runs/34160777525):
restore the compiler cache, build on a miss, save immediately after a successful
toolchain build, and then run application verification. This ordering preserves
a verified compiler installation when a later application check fails, while a
failed toolchain build never populates the cache.

`tools/assets.ps1 -Action stage-pages` prepares an immutable, content-hashed
directory under `build/pages/`. It copies ordinary application files and the
exact current catalog manifests/blobs, while keeping bulk kit ZIPs and obsolete
catalog generations in developer output. The Pascal stager verifies source and
destination hashes, inventory membership, notices and file paths. It enforces a
900,000,000-byte budget below the [1 GB published-site limit](https://docs.github.com/en/pages/getting-started-with-github-pages/github-pages-limits).
The accepted 8,365-model checkpoint staged to 769,373,882 bytes across 9,123 files.
Its independent closure review is `build/critic/catalog-files-review-05.md`.

Startup uses the current verified 512 KiB runtime parts. The stager checks their
ordered reconstruction against both original files and requires the successful
build's host/manifest hash binding. It excludes the duplicate raw WASM/ZIP and
obsolete parts. A failed host rebuild, changed manifest or orphan binding cannot
silently publish an inconsistent startup. See [STARTUP.md](STARTUP.md).

Successful staging writes `build/pages-evidence.json` and a relative directory
path in `build/pages-site-path.txt`. Failed staging preserves the previous path;
partial stages remain in ignored build output for diagnosis. Previous completed
stages remain available. CI serves and uploads the same staged directory.
For local preview, pass that directory to `./tools/serve.ps1 -SiteRoot <directory>`.
The wrapper compiles and runs `vendor/wfc/tools/wfc_serve.lpr` with native FPC.
`-BindAddress` accepts a literal private LAN address; the default is loopback.
To exercise `/Phanes/`, copy the immutable stage into a physical `Phanes`
subdirectory of a separate hosting root. WFC serves that directory directly.

The independent Pascal staging fixture now passes 667 checks, including
runtime ordering, short parts, corrupt/missing parts, stale host/manifest
bindings and orphan bindings, as well as altered model/texture/notice closures, unsupported metadata,
budget failures, changed output, preserved previous publication and actual
Windows junctions. Run it with `tools/test-kits.ps1`; the same fixture runs in CI.
Evidence is retained in `build/critic/pages-staging-review-01.md`. Both local
hosting paths also pass 240 HTTP hash checks against the staged catalog.
These checks certify publication integrity, not playable catalog admission.

Generator contract checks and the established browser interaction checks run at
`/` and `/Phanes/`, with desktop and phone viewports, against the staged site.
The workflow also discovers the installed Chromium, native FPC and pas2js paths
explicitly, then runs the current Pascal startup suite at `/`. The full retained
interior journey runs next at both paths, so import/editing failures are diagnosed
before the longer visual suites. Import failures retain application state and a
screenshot. The style, catalog-object and named-room recovery suites then run at
`/Phanes/`; the style suite compiles the shared probe used by those later suites.
Build logs and flat PNG, JSON and text browser evidence are retained even on
failure; transient browser profiles are excluded. These build checks can pass
while the separate critic gate remains on its expected review hold, and that
hold continues to prevent Pages upload and deployment.
The host reconstructs the standard WASM from verified static parts. Optional `wasm-opt` is not installed
by CI; validate browser startup before introducing it into the toolchain.

## Repository setup

In GitHub **Settings > Pages**, choose **GitHub Actions** as the source. Ensure
the `github-pages` environment permits deployment from `main`. Once enabled and
deployed, the expected URL is <https://mr-highball.github.io/Phanes/>.
This initialization supplies the workflow; it does not change repository
settings or publish a deployment.

Build jobs have read-only repository permissions. The deploy job uses the
built-in `GITHUB_TOKEN` with `pages: write` and `id-token: write`; no personal
token or hosting secret belongs in the repository. Changing the publishing
branch requires changing triggers, deployment conditions and environment policy.
