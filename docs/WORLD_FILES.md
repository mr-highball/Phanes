# World files

Export writes a JSON envelope containing `version` and `world`. The envelope
version matches the world's format, including format 4 for relative terrain
elevation. Open accepts versions 1–4 and files up to 8 MiB. Missing world format
is treated as legacy version 1; an explicit format must match its envelope.

The Pascal `phanes.worldfile.ui` unit owns the existing Export/Open controls.
The phone Export control is in the scrollable tools panel. The controller
checks the envelope before passing the world to the existing worker restore
and optional-catalog publication path. The worker validates the complete world
before publication changes the live scene or history. Legacy version 1 receives
the composition supplied by the existing world reader and normalizes to version 2.

A newer file selection supersedes an older unfinished read. Invalid envelopes,
malformed JSON and browser file-read errors show a visible error; rejected
worlds preserve the current world and history. Import may update the recorded
solve duration, which is excluded from semantic round-trip comparisons.

## Verification

After building and serving a candidate site, run:

```powershell
./tools/test-world-file.ps1 -Browser $env:BROWSER -TestUrl http://127.0.0.1:4186/
```

The wrapper uses the configured native FPC, pas2js and RTL paths. The Pascal
driver creates an independently admitted relative-elevation world through an
actual selection and land edit. It verifies real browser downloads, file-input
restoration, legacy versions, visible rejection and history preservation, and
controlled out-of-order file reads on desktop and phone layouts.

The 2026-09-13 candidate passed 33 checks through the wrapper in
`build/world-file-candidate-04/evidence.json`; source, compiled bundle, downloads
and screenshot fingerprints are bound by the adjacent `provenance.json`.
The wrapper compiled both Pascal components and completed the desktop/phone
journey. A real 8 MiB-plus-one-byte file was rejected without calling `text()`
or changing the world/history. Phone results are browser emulation, not a new
physical-device test. The new remote CI invocations remain to be verified.

The harness supplies a normalized native download directory. A controlled
Windows comparison in `build/download-path-ab-02/evidence.json` downloaded the
same 2,327-byte payload with native separators and failed with mixed separators;
earlier download timeouts did not establish an application export defect.

These checks do not clear the full feature or release gates. The separate full
interior CI journey still has an unresolved optional-book publication timeout.
Its worker finishes while the catalog remains busy, so complete imported-world
publication remains under investigation.
