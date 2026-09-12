# Phanes

Phanes is a browser world creator built with Castle Game Engine and WFC.
The first working editor generates five linked regional layers and renders
real CC0 kit models. Select a region, turn it into a forest, flowering meadow,
field, cabin settlement, castle district, modern neighbourhood or sci-fi outpost,
then explore it from overhead, orbit, flight or eye level.

**This is an active demonstrator in development.** The complete objective includes
nested rooms, object-scale replacement, rich modular generation, full cross-kit
compatibility, learning and measured large-world performance. A first cabin
studio supports individual shelf/tabletop contents, and explicit groundworks
support deck/panel edits and seven measured building shells. A cabin on an
explicit deck owns the same studio and editable contents. The broader workflows remain unfinished.
Cabins also support two-, four- or six-bay room plans with independently generated
bathrooms and laboratories. Room, shelf and individual-item edits retain their
neighboring spaces. Named-room review evidence is retained; shared runtime changes
require renewed acceptance. Broader architecture and world creation remain unfinished.
Click or tap visible foundation parts and attached buildings to select them;
the outline and controls follow the same saved object. Look closer restores and
frames a selected part even after its detailed chunk has unloaded.
[Product requirements](docs/PRODUCT.md) and the
[completion roadmap](docs/ROADMAP.md) preserve that full scope.

The expanded library contains 8,365 glTF/GLB files from 108 CC0 Kenney, KayKit,
Quaternius and Base Mesh kits/collections. The original six remain in the startup bundle; 102 optional kits have
separate packages. Runtime catalog and placement admission are still pending;
see [catalog expansion](docs/CATALOG_EXPANSION.md). The initial regional corpus uses
19 asset/prefab choices; the rest are inventoried for later admission. All
source URLs, hashes and CC0 notices are retained. See [assets](docs/ASSETS.md).

## Create and explore

1. Choose a region width and seed, then **Create this world**. Each region cell
   spans 16 metres; ecology resolves at twice the regional resolution.
2. In **Create**, use **Tap**, **Box**, **Brush** or **Lasso** to select land in any
   view. Add or subtract areas, and choose regional or finer foliage cells.
   Browse a category, then a subgroup or exact item; **Apply to selection** changes
   the marked cells. **G** reimagines the selection with the current layer scope.
   [Authoring](docs/AUTHORING.md) explains boundaries and preservation.
3. Use **Undo/Redo** to compare possibilities. Failed or cancelled generation
   preserves the current world. **Export/Open** saves and validates all layers.
4. Switch views with **1–4**, or use the camera bar. Scroll to zoom. Drag to orbit
   or look; WASD moves in Fly/First person, Q/E changes altitude in Fly.
   **Tab** toggles creating and exploring while the canvas has focus. First
   person uses a 1.68 m eye height, ground following and exterior collision.
   Touch movement works in both modes; Fly adds **Rise/Descend**. **Hide tools**
   and **Tools** collapse and reopen the creation panel independently of the view.
5. Open **Foundations & launch pads** from the selection panel. Tap a plot,
   choose access and supports, then place it. Its deck plan lets you reimagine
   one rim panel or the whole deck. **Walk the approach** starts at its landing.
   Choose a building for the deck, or **Furnish this cabin** to create its studio.
   Support and panel edits preserve its rooms, furniture and individual contents.
6. Inside a studio, open a shelf or tabletop, then an individual item. Plates
   expose **On this plate** for bread, fruit and cheese. Change one appearance
   or its category count; the remaining arrangement keeps its saved identity.
7. Select a regional cabin and **Design rooms**, or open **Room layout** at the
   root of an existing interior. Pick a bay and choose **Laboratory** or
   **Bathroom**. Follow the breadcrumb into furniture, work surfaces and shelf
   tiers. **Rename this space** gives bays and rooms independent names.

Phanes is an independent demonstrator. Its units follow
`phanes.module.unit` dotted namespaces. Its creation interface, audiovisual
identity and generative systems are developed for this project.

## Build and run

```powershell
git submodule update --init --recursive
```

Provide FPC 3.3.1 with a **64-bit-host** `wasm32-wasip1` compiler and matching
RTL/packages, and configured pas2js 3.3.1 on PATH. Build the pinned Castle command
line tool by running `castle-engine_compile.ps1` from
`vendor/castle-engine/tools/build-tool/` (or the `.sh` equivalent on Linux).
The repository defaults to that build tool; `CASTLE_TOOL` can override it.

```powershell
./build-web.ps1 -Mode release -WithTests
./tools/serve.ps1
```

Open <http://localhost:4186>. `build/web/` is the development output. Run
`./tools/assets.ps1 -Action stage-pages` to prepare the bounded deployment
directory recorded in `build/pages-site-path.txt`; CI tests and publishes that
same directory. See [publishing](docs/PUBLISHING.md).
The runtime requires WebAssembly and WebGL 2. The local host is the pinned WFC
Pascal static server, compiled with native FPC. Runtime files are served locally
without a CDN. For a LAN preview, use `./tools/serve.ps1 -BindAddress <your-private-IPv4> -Port 4200`.
`-SiteRoot` can select an immutable Pages stage instead of `build/web`.

The build accepts `-CastleTool`, `-Mode debug|release`, `-WithTests`, and the worker/test
compiler overrides `-Compiler`, `-RtlRoot`, `-RuntimeJs`, `-CompilerOptions`.
Their environment equivalents are `CASTLE_TOOL`, `PAS2JS`, `PAS2JS_RTL` and
`PAS2JS_RUNTIME`. CGE also needs configured pas2js on PATH for its generated host.

On Windows, if the installed WASM compiler has a 32-bit host,
`tools/build-wasm-compiler.ps1` builds a 64-bit-host compiler using supplied
`-FpcSource`, `-Win64Compiler` and `-FpcConfig`. Prepend its ignored
`build/toolchain/` output to PATH for web builds. No installation paths are stored
in this repository. CI bootstraps pinned compilers automatically.

## Verification

New visual-style verification is Pascal throughout: native FPC drives Chromium
through WFC's CDP transport, and pas2js compiles the browser instrumentation.
With the Pascal preview host running, use `./tools/test-styles.ps1 -Browser <chromium-path>`.
The older Node browser harnesses listed below remain migration work; they are
not the supported pattern for new tooling.

Install Playwright outside the repository, make it resolvable through `NODE_PATH`,
and install its Chromium browser. `BROWSER` may specify an existing executable.
With the development server running after a build with `-WithTests`:

```powershell
./tools/assets.ps1 -Action verify-kits
./tools/assets.ps1 -Action verify-music
./tools/test-floor.ps1
node tools/test-floor.cjs
./tools/test-spaces.ps1
node tools/test-spaces.cjs
./tools/test-spaces-integration.ps1
node tools/test-spaces-integration.cjs
./tools/test-terrain.ps1
node tools/test-terrain.cjs
./tools/test-terrain-wasm.ps1
node tools/test-room-journeys.cjs
node tools/test-world.cjs
node tools/test-groundworks.cjs
node tools/test-groundworks-view.cjs
node tools/test-supported-buildings.cjs
node tools/test-groundwork-picking.cjs
node tools/test-web.cjs
```

The generator checks exercise determinism, regional brushes, frozen surroundings,
fine-grid footprint clearance, contradictory edits, exact restore and invalid
asset rejection. Browser checks cover world creation, Castle rendering, selection,
undo/redo, camera switches and desktop/phone layouts. Evidence stays in `build/`.
For project-path hosting, place the site in a physical `Phanes` subdirectory of
the served root, then use `TEST_URL=http://127.0.0.1:4186/Phanes/`.

Asset tools are native Pascal programs built with FPC 3.3.1 (the same pinned
compiler used by CI). Set `FPC_NATIVE` when the native compiler needs an explicit
path. `import-kits` restores pinned kit archives and regenerates their inventory;
`import-music` derives the WFC corpus from the preserved MIDI references.

See the [coding guide](docs/CODING_GUIDE.md), [architecture](docs/ARCHITECTURE.md),
[publishing guide](docs/PUBLISHING.md), [dependency credits](docs/CREDITS.md),
and [initial verification](docs/VERIFICATION.md).

The [local floor adapter](docs/FLOOR_PLACEMENT.md) now connects to
[named bay and room documents](docs/ROOM_PROGRAMS.md), including bathroom and
laboratory programs, complete furniture contents and scoped replacement.
Their worker/editor and rendered partition integration remain pending; the
browser currently exposes the admitted studio workflow.
