# Browser startup

`phanes.startup.browser.lpr` starts before the other browser controllers. It
shows the current download or startup step, records bounded local diagnostic
text, and catches script, promise and graphics-context startup errors. Details
remain on the device; the user can select the text to copy it on LAN HTTP.

`phanes.host.engine.lpr` uses the pinned pas2js WASI host and JOB bridge to start
the Castle WebAssembly library. It replaces CGE's generated application host,
without changing the engine, dependency sources or native entry point. Its
steps are the data ZIP download, engine download, instantiation, native
initialization, and first rendered view. Each file has its own byte progress;
finishing the small ZIP is not presented as finishing startup.

Both files are reconstructed from verified 512 KiB parts by the Pascal
`phanes.startup.parts` unit. The native `phanes.tools.webparts` publisher emits
content-addressed files; their ordered manifest is compiled into the host.
Each Fetch request supplies a strictly validated SHA-256 integrity value, which
works on same-origin LAN HTTP without secure-context-only crypto APIs. The host
checks exact part lengths, including the final short part. It allocates one
destination buffer and retains only the current response, then advances progress
for verified bytes. A failed part receives up to four attempts with bounded
backoff; earlier completed parts stay in memory during those retries.

The ZIP remains available through
CGE's `document.CastleApplicationData` contract. The WASM buffer is instantiated
directly, without a Blob or a second download. The first prepared instance is
run once; the host's re-instantiation helper is deliberately not used. The
host checks `PreparedStartDescriptor.RunExceptionClass/RunExceptionMessage`
because the WASI run method catches initialization errors internally and its
promise can otherwise resolve despite failure.

Create remains gated by three separate conditions: the first-render callback,
successful native initialization, and the required palette. The first frame
can occur synchronously before initialization returns, so it is provisional
until the host has checked for a caught run exception. A delayed palette keeps
the catalog label after a rendered view. A startup failure cannot enable
Create. Pending downloads abort when another required startup step fails.
Open uses the same readiness gate. The status label has a Phanes-owned DOM
identifier, because CGE hides its legacy loading elements after the first frame;
pending catalog messages and late initialization failures must remain visible.
A slow step offers retry and
details after 30 seconds without claiming that compilation failed. Network
requests time out after 30 seconds per part attempt; compilation has no synthetic deadline.
Retry reloads the page, rebuilding the environment. A rejected WebGL2 creation
attempt is recorded without blocking CGE's WebGL1 fallback. Context loss before
readiness is a visible failure.

`tools/build-host.ps1` compiles the native part publisher and both Pascal browser
programs, and supplies generated content-hash asset URLs. After successful host
publication, the publisher writes `data/runtime-host.json`, binding the actual
host bytes to the ordered manifest. Pages rejects a stale host, changed manifest,
or missing binding, and stages only current parts instead of duplicate raw
WASM/ZIP files or obsolete parts. It adapts the generated JOB CacheStorage registration
for LAN HTTP, where that optional API can be absent. `build-web.ps1` invokes it
after compiling the Castle application. The host continues to use the original
global RTL registry required by `phanes.host.js`; the diagnostic controller
has an isolated registry like the other Phanes browser controllers.

## Verification and limits

Run `tools/test-startup.ps1 -Browser <Chromium> -TestUrl <preview>`. Its Pascal
driver uses pinned WFC CDP; the Pascal probe supplies controlled compile/init
failures. It verifies normal four-cell creation, interrupted assets/engine
downloads and retry, a missing required palette, compilation rejection, an
internally caught WASI initialization errors both before and after first render,
a delayed palette, selectable HTTP diagnostics, and slow compilation that
later succeeds. Additional cases verify recovery on the third attempt without
restarting earlier parts, rejection of actual corrupt HTTP bytes by native Fetch
integrity, readable exhausted-retry errors, and cancellation of active requests.
Phone and desktop screenshots accompany
these checks. Fixtures are injected only into owned test browsers.

The current run in `build/startup-parts-suite-02` passes 67 assertions across
12 cases against the actual LAN origin. Earlier ordering/visibility evidence in
`build/startup-suite-03` passed 45 assertions, with phone and desktop screenshots
inspected, including late initialization errors and delayed catalog status.
The immutable Pages stage also passes normal startup and four-cell creation
with the raw WASM/ZIP absent (`build/startup-parts-staged-01`). It contains
9,250 files totaling 769,973,760 bytes; the current part closure, host binding
and rejected publication cases pass 667 native staging checks.
`build/logs/web-startup-build-01.log` records a successful complete release build;
the current host rebuild is `build/logs/startup-parts-build-04.log`. The critic's
bounded retests retain the ordering/visibility findings and their corrections
under `build/critic/startup-implementation-review-*`. The review checker passes
all 26 synthetic fixtures while the actual product gate remains HOLD.

The Android diagnostics isolated an interrupted engine transfer at 13,060,453
of 58,174,201 bytes before initialization. The pinned WFC server has an aggregate
send deadline and a short socket send timeout. A rate-limited full-file request
reproduced truncation locally: 5,767,168 bytes before curl reported an incomplete
response (`build/logs/startup-server-cutoff-01.log`). No dependency edits were
needed: short static requests use the existing server API and also suit Pages.

The native Pascal transfer test slows actual HTTP consumption to 524,288 bytes/s.
All 123 parts reconstructed the original files exactly: the ZIP in 11.6 seconds,
the engine in 111.1 seconds (`build/logs/startup-transfer-01.log`). To repeat it
after browser checks, pass `-TransferBytesPerSecond 524288` to
`tools/test-startup.ps1` against a local preview of the current build.

On 2026-09-09 the user retested the Android LAN preview and confirmed, “Yes loads
now.” This closes the reported startup blocker. It does not establish mobile
movement, editing, frame-rate or music/BPM acceptance; those remain separate
requirements under the full mobile feature review.
