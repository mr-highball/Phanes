# Local room floor placement

The `phanes.spaces.floor.*` adapter supplies a reusable WFC furniture floor
solver. It is an implementation step toward named bays, bathrooms and laboratories;
the current browser still uses the admitted cabin studio. Room partitioning,
named-bay editing, model admission, worker transactions and rendered room-program
journeys remain required before the named-room feature can pass its critic gate.

## Physical contract

A request describes one rectangular room in millimetres, an opening in its +Z
wall, a player radius, available service capabilities, eligible fixture assets,
role quotas and preserved placements. Fixture bounds are upright, centred in X/Z
and grounded at Y=0. An admitted model represents one independently addressable
object; `TContentAsset.FSingleInstance` retains that meaning. Several copies of
the same chair or bench are allowed. Counts refer to distinct placed identities.

Quarter turns follow the existing composition/Castle convention: positive
quarter-turn maps local +Z to +X. A fixture's operating-front orientation is
separate from its placement turn. Water, drainage and power names filter fixture
eligibility; they do not claim that utility networks have been constructed.

The floor pitch is an even integer, normally 750 mm. It must exceed the player
diameter by at least 20 mm. Objects reserve their complete rounded-up rectangular
footprint in that local lattice. Free-cell centres consequently have at least
half a pitch of clearance from occupied cell edges; the validator also measures
the actual swept disk against fixture envelopes. A table's smaller support graph,
individual shelf tiers and food on a plate retain their own finer local scales.

Each room currently has 2–32 cells per side and at most 256 cells. Catalog metadata
is bounded at 32 eligible assets and 32 role quotas. The active token count cannot
exceed 128, and `cellCount * tokenCount * tokenCount` cannot exceed 100,000.
These are local structural work allowances, not a measured response-time
guarantee or a global limit on world/catalog size. Narrowing eligible shapes or
dividing a room can reduce work. Search has a separate caller backtrack allowance
of 0–4096. Exhaustion does not prove that the requested room is impossible.

## Constraint encoding and acceptance

Each non-free WFC value names one offset inside one asset/orientation footprint.
Reciprocal adjacency requires exactly the other offsets of that same fixture.
Per-cell domains exclude footprints truncated by the room boundary, entrances
or preserved objects. Only the offset at (0,0) enters role quotas, so a six-cell
bench counts as one bench. A selected front-edge offset requires a free operating
cell. All free floor must connect to the entrance through cardinal neighbours.

The adapter builds the complete reciprocal rule matrix before assigning it
through WFC's public bulk `Rules` API, as the pinned library's model adapters
already do. Repeated `NewRule` calls synchronize the whole inverse-rule graph
after every pair and made larger fixture catalogs impractically slow. Each
group/direction owns a detached array. Empty directional sets use explicit
`DenyAll`; a legacy empty list would otherwise allow any neighbour.

Generation stages a candidate and calls the independent decoded-layout
validator before publishing it. The validator reconstructs occupied cells from
fixture dimensions, rejects overlap and partial footprints, checks measured
envelopes, counts actual instances and compares all preserved IDs/assets/poses.
It checks the reported free floor against that reconstruction and floods only
routes whose swept player disk clears the physical envelopes and room walls.
Entry uses the doorway centreline followed by a turn inside the first row;
the split front wall includes both jamb endpoints in its clearance check.
Operating-side standing cells must be reached by that physical flood.

Preserved placements pin their full footprint tokens. New identities derive
from the floor scope and anchor cell; domains prevent them from taking an
existing preserved identity elsewhere. Failed validation or search leaves the
caller's committed result unchanged. Preservation here covers fixture roots.
Production callers must also retain composition subtrees and apply complete
assembly-envelope, scope, lock and revision validation before publishing any
world edit; the floor adapter cannot replace those checks.

Callers may reserve new fixture IDs through `FUnavailableNewIds`. These IDs
are excluded before solving, while matching fixed instances may retain them.
The room composition bridge reserves a whole potential root namespace when
any preserved document node already owns its root or a descendant identity.
See [ROOM_PROGRAMS.md](ROOM_PROGRAMS.md) for named-room document integration.

## Asset admission findings

The synthetic regression rooms use measured candidate envelopes, not newly
admitted browser models. Independent Castle probes found that the source
computer desks are sloped consoles, with an operating front at local -Z.
They cannot expose a full-footprint flat tabletop. The existing 0.75 m table is
a possible laboratory bench. The source shower has closed door geometry and a
raised tray; reachable exterior standing space does not establish walk-in entry.
The console and stool geometry also needs ergonomic evidence before claiming a
usable seated workstation.

These distinctions belong in fixture capability and support admission. A role
name or a free cell beside a bounding box cannot establish a usable interior.

## Reproduction

Run `./tools/test-floor.ps1` for native Pascal checks. The web build with
`-WithTests` compiles `tests/phanes.tests.floor.lpr` through pas2js;
`node tools/test-floor.cjs` executes that Pascal in Chromium and stores its
evidence under ignored `build/`. CI runs both.

The browser orchestration has a 60-second suite watchdog and closes its own
Chromium on failure. The permanent independent critic suite includes actual
solves near the token/area limits, as well as the request-admission boundaries.

The suites cover multi-cell counts, whole footprints, several copies of one
asset, deterministic variation, preserved fixtures, invalid and over-budget
requests, service/height eligibility, operating-front rotation, physical
clearance, off-centre doorways and atomic rejection. The critic independently
exercises the encoding and actual source geometry. These checks do not pass the
unimplemented named-room browser journey.
