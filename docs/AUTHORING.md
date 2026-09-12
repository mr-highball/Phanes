# Regional authoring

Create mode offers Tap, Box, Brush, Lasso and Look in Overhead, Orbit, Fly and
First person. Browsing a category, subgroup or exact model stages an intent;
Apply to selection performs the edit. Back or entering another subgroup clears
the former intent. Search filters the current category without modifying the
world. The selected model and affected layer remain visible beside Apply.

The current browser covers the 19 admitted regional palette choices. A group
request lets WFC choose only from that displayed group; an individual request
pins the chosen model in each selected cell. Cluster entries explicitly describe
their per-cell cluster behavior. This does not grant optional inventory models
placement capabilities or make regional clusters individually addressable.
The separate cabin tools address rooms, furniture, support surfaces and items.

## Selection contract

- Regional cells are 16 metres; foliage cells are 8 metres. Fine selection can
  edit ecology and vegetation only. Changing precision clears the old selection.
- Replace, Add and Subtract produce sorted, unique cell IDs. Disconnected islands
  and holes remain exact masks; their enclosing rectangle is never authorization
  to edit its holes. Select world is explicit.
- Brush strokes use continuous capsules so sparse pointer events leave no gaps.
  Box and Lasso project captured screen points onto the terrain, then select
  cells whose centres lie inside the closed ground contour or whose interior
  the contour crosses. An edge exactly on a cell boundary does not select the
  adjacent row. The resulting terrain outline is the scope shown before Apply.
  A collapsed point behaves as a tap; an out-and-back line selects crossed cells.
- These are ground-region tools. They do not select foreground object silhouettes.
  Perspective and uneven terrain can change the projected shape. A contour with
  a point that misses the land is refused, preserving the former selection.
- A gesture retains its original camera and world revision. Pending picks are
  sequential. Interruption, view/publication changes, loss of capture, another
  touch, Escape and opening Music cancel it. The 256-point limit refuses an
  oversized stroke rather than truncating it. Add supports successive strokes.

Layer scope is checked before publication. Exact models require their matching
layer. A landscape intent uses the current compatible Change setting. A mismatch
disables Apply with an explanation; a stored choice cannot silently override it.
Explore blocks generation and hides the authoring toolbar.

## Worker and renderer

`phanes.world.selection` maps the requested mask into WFC pass domains and pins
every unselected or unrelated value. `phanes.world.edit.validate` independently
maps the mask and checks the decoded result, saved elevation, appearance seed,
composition records and revisions. Partial plot removal refuses; a mask hole
cannot authorize plot removal. Failed worker requests preserve the baseline.

The renderer draws exposed edges of the actual mask, including islands and holes,
with one indexed, terrain-following ribbon. The maximum is 32,768 segments; dense
masks reduce height samples per edge while retaining all boundary edges. The old
rectangular post-effect cue is suppressed for masks. Strong shader legibility
and extreme-mask visual cost still need review.

Array preservation does not yet guarantee unchanged rendered terrain everywhere
outside a water edit: the analytic shoreline grading has a neighbourhood kernel.
Integration of transactional WFC heights remains required for that physical
surface guarantee. See [TERRAIN.md](TERRAIN.md).

## Verification

`tools/test-authoring.ps1 -Browser <Chromium> -TestUrl <preview>` compiles Pascal
browser instrumentation, the portable selection checks and the driver using
pinned WFC CDP. It sends real mouse/touch events. Click targets are checked for
occlusion so a covered button cannot accidentally exercise a different action.

The native selection suite currently passes 538 checks. The latest complete
browser checkpoint is `build/authoring-browser-10`: 41 interaction assertions
cover category drill-down, exact Oak application with unrelated layer/cell
equality, islands, box, brush and nonempty lassos in all cameras, cancellation,
plot precision and focus recovery. It also exercises a landscape intent after
changing scope, incompatible exact-item scope, and opening/closing Music while
terrain rays remain pending. All 538 portable assertions and 35 music worker
protocol checks pass in Chromium too. The probe records no browser errors.

Desktop GPU touch emulation is not physical-phone performance evidence. The
critic reports under `build/critic/masked-edit-*.md` retain unresolved rendered,
lifecycle, full-catalog and performance work. The complete world-creator feature
remains held for independent review.
