# Named rooms and bays

The Pascal composition bridge now connects bounded room volumes to the local
WFC floor solver and the existing finer contents graphs. Its hierarchy is
`building / floor plan / named bay / room / furniture / support / item`.
Bathroom and laboratory programs and two-, four- and six-bay cabin scaffolds
are now connected to the world worker, Pascal editor controller and rendered
plan. Feature acceptance is recorded by the independent critic gate in
`reviews/features.json`; it does not establish completion of the wider world
creation objective.

## Identity, volumes and operations

`phanes.spaces.programs` supplies immutable purpose profiles:
`phanes.space.empty.v1`, `phanes.space.bathroom.v1` and
`phanes.space.laboratory.v1`. Display names remain independent of purpose,
identity and geometry. `phanes.spaces.rooms` admits full room contents and
stages one scoped composition transaction. `phanes.spaces.plans` supplies
the authored cabin subdivisions and admits all rooms in a complete plan.

An explicit room volume uses the version 2 millimetre contract in
[COMPOSITION_FORMAT.md](COMPOSITION_FORMAT.md). Width/depth are 2.5–9.4 m and
height is 2.2–3.5 m for the standalone program adapter. A valid volume does not
guarantee that a requested furniture set can be solved inside it.
Pitch is 750 mm while the corresponding floor has at most 56 cells, otherwise
1000 mm. This rule is part of the v1 profile; contents keep their own independent
millimetre supports and slots. The largest laboratory floor has 81 cells and
29 active tokens, below the adapter's combined work limit.

Changing purpose explicitly replaces the selected room's contents. A locked
descendant prevents that replacement, including when a whole building or plan
is selected. Ordinary reimagination preserves furniture that owns supports or
contents, along with its entire subtree, and preserves every locked fixture.
Bare, unlocked fixtures may move. This is deliberately conservative; an explicit
assembly-moving workflow remains to be implemented.

New root namespaces are reserved before solving when any preserved document
node already owns the potential root ID or any descendant ID. WFC can select
another anchor instead of encountering a late shelf/support collision. Fixed
instances retain their existing IDs. Failed solves, stale requests and rejected
commits preserve the caller's output, including when output aliases the baseline.
Nested content generation consumes private revisions; the final room operation
increments the public revision once.

## Programs and measured models

The bathroom requires one basin, toilet and closed shower enclosure. The
laboratory requires one workbench, screened console and four-tier bookcase.
WFC chooses complete footprints and quarter turns, while exact quotas count
individual fixtures. Connected free floor and each operating side must admit
a 280 mm player radius through a centred 1000 mm doorway on local +Z.

| Instance | Source model | Uniform scale | Conservative width × depth × height, mm | Operating front |
| --- | --- | --- | --- | --- |
| Basin | Furniture / bathroomSink | 1.6 | 546 × 466 × 898 | +Z |
| Toilet | Furniture / toilet | 1.65 | 516 × 788 × 745 | +Z |
| Shower enclosure | Furniture / shower | 2 | 1124 × 1164 × 2189 | +Z, exterior approach |
| Screened console | Space / desk_computerScreen | 2 | 1052 × 452 × 1276 | −Z |
| Laboratory workbench | Furniture / table | 0.75 / raw scene height | 1933 × 1028 × 750 | +Z |
| Four-tier bookcase | Furniture / bookcaseOpen | 2 | 800 × 500 × 1760 | +Z |

The raw scene is uniformly scaled, centred in X/Z and bottom-aligned at Y=0
before instance rotation. The screened console's total height is not normalized
to table height. Its sloped body is not admitted as a general flat support.
The closed shower has no walk-in or door interaction contract. Water/drain/power
are logical program eligibility declarations, not simulated utility networks.

The lab workbench uses the existing measured table mesh with a separate support
profile, `phanes.support.bench.v1`: a 1500 × 800 mm work surface at Y=750,
700 mm headroom and six non-overlapping slots for individual books/ornaments.
The room UI exposes that six-slot capacity. Each shelf retains
its existing exact support profile; Shelf 4 starts with three books and Shelf 2
with one ceramic snail. These are individually editable nodes.

The room validator reconstructs floor placement from saved poses, independently
checks the floor solve, and validates complete supported assembly envelopes.
Every required furniture support must exist. Every nested item must fit its
support and slot, and the full assembly must fit the room height and its base
X/Z footprint. Unknown geometry cannot be treated as empty space. A child edit
must be followed by whole-room and whole-plan admission before world publication.

## Cabin subdivisions

The current profiles are authored partition scaffolds, not WFC-generated walls.
They share a 9400 × 9400 × 2700 mm plan, at Y=80 inside the existing cabin.
Each wing has one, two or three rows, for two, four or six bays. Their usable
local widths are respectively 9200, 4550 and 3000 mm; depth is 3900 mm.
Left/right wings are centred at X=−2700/+2700 with quarter turns 1/3.
Bay numbering runs down the left wing then the right wing. Rooms are distinct
children occupying their bay volume, so a laboratory can belong to Bay 5.

The 3900 mm depth reserves the existing shell and inward window-trim clearance.
The separate interior view renders perimeter and 100 mm corridor partitions,
leaving 1300 mm clear in the central corridor. In the six-bay profile, row
partitions fit the 100 mm gaps at Z=±1550. Room portals are 1000 mm wide and
2200 mm high. The portable `phanes.spaces.geometry` rectangles drive both meshes
and player clearance. Editing views cut walls to 750 mm; first person shows
their full 2700 mm height. The existing exterior door remains closed; entering
and returning use explicit UI actions rather than seamless traversal.

## Player controls and publication

Select one regional cabin and choose **Design rooms**, or enter a cabin on a
foundation and choose **Room layout**. The layout dialog previews two, four or
six bays and explains that changing it replaces the current interior. Select a
bay, assign its purpose, then drill into its room, furniture, support and items.
Bay and room names are independent; the breadcrumb retains their relationship.
Purpose replacement preserves every other room. Ordinary room reimagination
retains supported assemblies and locked fixtures as described above.

The worker operations are `create-plan`, `room-purpose`, `room-reimagine` and
`rename-space`. Optional request fields are `planProfile`, `roomProgram` and
`spaceName`; an explicit `objectId` addresses a supported cabin or existing
space. A plan request without an ID uses the selected one-cell regional cabin.
Names must be nonblank, at most 80 UTF-16 code units, contain no control
characters and have correctly paired surrogates. Invalid names fail before
serialization. Every operation validates the previous whole world, stages its
edit and admits the complete candidate before publication. Nested content edits
also revalidate the enclosing room and plan. Existing studios remain readable.

Profile validation rejects overlapping bays, altered bay dimensions/frames,
missing rooms and a studio coexisting with the plan. Arbitrary resizing,
room subdivision, connected enclosures, vertical stacking and modular walls
remain product requirements. The composition format can carry explicit extents;
that alone does not admit an arbitrary changed building.

## Sources and verification

All models already belong to the imported CC0 Furniture and Space kits.
No new download or mesh alteration is required. Original notices, source URLs,
archive hashes and per-model SHA-256 values remain in `data/kits.lock.json`
and `data/asset-inventory.json`. The transformation and support contracts above
are authored Phanes catalog rules. Visual and interaction acceptance requires
the independent critic gate.

`tools/test-spaces.ps1` runs the native composition/program checks.
`build-web.ps1 -WithTests` compiles the same suite through pas2js, and
`node tools/test-spaces.cjs` executes it in Chromium. CI runs both alongside
the generic floor and composition suites. Generated logs and independent critic
probes are retained under ignored `build/`.

`tools/test-spaces-integration.ps1` and `node tools/test-spaces-integration.cjs`
run the separate critic-owned world/portal suite. It checks whole-world scope
preservation and rejection, Unicode names, supported and regional hosts, exact
wall clearance and browser serialization. `node tools/test-room-journeys.cjs`
uses the actual worker and Castle renderer for desktop/phone creation, names,
contents, neighbors, protection, export/restore and both cabin entry paths.
CI runs rendered journeys at root and project URLs. Passing these regressions
does not replace the independent visual and interaction grades.
