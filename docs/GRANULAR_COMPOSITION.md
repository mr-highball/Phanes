# Granular world composition

This is the required architecture and acceptance specification. It records the
user's terrain-to-individual-object requirement; it is not a claim that the
current browser implements these scopes.

## Implemented document foundation

`phanes.composition.types` and `phanes.composition.document` now provide the
portable Pascal document and transaction primitives. Nodes have persistent IDs,
parent/support references, container/surface/object kinds, semantic roles, asset
IDs, local millimetre coordinates, quarter turns, names, seeds and locks. Storage
order and display names are independent of identity. A sorted ID index supports
lookup; validation rejects duplicate IDs, orphans, invalid transforms, multiple
roots and combined ownership/support cycles. The 128-edge depth bound is
independent of node storage order.

Scoped commits require matching baseline/candidate/expected revisions, preserve
the selected scope's parent/support boundary, protect outside records and reject
new external dependencies. They also protect locked or outside objects from
indirect movement through changed supports/ancestors. Labels may change without
altering those physical dependencies. Output is assigned only after validation;
failed edits preserve it, including when the caller aliases output with an input.
Lock protection follows both ownership and support edges, including contents
owned elsewhere but resting on a locked surface.

The standalone versioned [composition format](COMPOSITION_FORMAT.md) retains all
node fields, Unicode labels and revisions in native and browser round trips.
It is embedded in world format 2; version 1 worlds migrate to an empty root.

## Implemented local contents adapter

`phanes.composition.contents.*` now generates individual objects on one explicit
support surface. A small WFC graph indexes reserved usable volumes in that
surface's local frame. Its first pass chooses object roles with per-surface
minimum/maximum quotas; its second maps those roles to admitted asset choices.
Physical width, depth, height and quarter-turn rotation constrain each slot's
domain. Optional per-slot asset filters allow one specific item to change while
all other slots retain their choices. Slots may be empty. One occupied anchor
counts as one independently editable object; grouped meshes are rejected.

The graph freezes out-of-scope and locked items. It stages its decoded instances,
checks them independently against measurements, roles, quotas and complete
surface coverage, then uses the scoped transaction above. Seed replay is
deterministic. Search is bounded at 2,048 backtracks; exhaustion is not proof of
impossibility. Linear graph adjacency is deliberately unconstrained because
the physical slots already have disjoint reserved volumes; array neighbors do
not imply physical neighbors.

The adapter requires objects to be owned by their supporting surface and
supports at most 256 slots and 128 asset entries per solve. Content assets may
declare optional named support profiles with exact contact poses, usable volumes
and allowed roles. `phanes.composition.contents.assembly` reads the complete
transformed descendant envelope before admitting a parent replacement. It checks
support identity, contact, nested fit and sibling separation. The parent's outer
envelope is not treated as a solid collider: a declared cavity may hold contents.

Ordinary surrounding regeneration preserves occupied assembly identities and
child records. Explicit removal and movement require separate request intent;
descendant locks still apply. Candidate domains reserve generated support IDs
against the saved document and every requested root before solving. Optional
supports keep older leaf-object saves valid. A local contents solve proves fit
on its requested surface; the world adapter must also validate all ancestor
surfaces before publishing a deeper edit.

The tests use explicit synthetic measurements and fixture asset IDs. They do
not admit production models or certify collisions with other surfaces, room
clearance or traversability. The first production integration now connects the
document, contents adapter and save codec to a cabin studio, measured furniture,
four real shelf tiers and individual props. [INTERIORS.md](INTERIORS.md) specifies
that limited catalog and its local WFC graphs. Pascal owns its controller and
generation; CGE renders the cutaway. The plate profile extends this path through
tabletop / plate / inner support / individual bread, fruit and cheese. Broader
room programs, catalog admission and the full journeys below remain required.
The old room prototype remains unintegrated.

The separate [named-room bridge](ROOM_PROGRAMS.md) now connects explicit bay and
room volumes to measured bathroom/laboratory floor programs, furniture supports
and individual contents. Two-, four- and six-bay cabin plans have real doorways,
cutaway/full-height views and scoped worker operations. A laboratory can occupy
Bay 5 while another bay becomes a bathroom; edits to Shelf 4 or an individual
snail preserve their neighboring rooms. Names remain independent of purpose.
Both regional cabins and cabins on explicit foundations use this hierarchy.
These authored subdivision profiles do not yet provide arbitrary room resizing,
modular enclosures, vertical stacking or the full catalog/route workflows below.

## Present gap

The new [groundwork adapter](GROUNDWORKS.md) supplies persistent plots,
decks, substructures, access ramps and individual WFC material panels. Its
geometry, scoped changes and save codec run in native and browser tests. Worker
placement, original Castle geometry, ground contact/navigation and Pascal
desktop/phone controls are integrated. Seven measured static shells now have
explicit deck ownership. A supported cabin retains its complete studio hierarchy
during compatible material/support edits. The broader support workflow remains
required below.

The same saved identities now connect exterior part picking, selection outlines
and panel controls. A deck panel, support body, ramp, graded landing or attached
building can be selected without changing its parent or the world revision.
Detailed geometry can unload while the selection remains; framing the part
restores its owning chunk before resolving its visible bounds.

The running world has five fixed regional arrays: terrain, architecture, ecology,
buildings and vegetation. They choose regional roles and asset/prefab placements.
The height surface is analytic, not a WFC landform solve. Leveled building pads
remain part of that surface for legacy regional buildings. New explicit plots
provide separately selectable foundations and launch pads with an explicitly
supported building container. Arbitrary modular structures remain pending.

The unintegrated `phanes.room.generate` prototype has a fixed 5 by 5 dining room,
paired table cells, chair quotas, a connected free floor, appearance and tableware
passes. It is not compiled into the current browser path. Its bookshelf edit
changes a furniture appearance, not a shelf's individual contents. Neither those
arrays nor a brush for each new noun can represent the required hierarchy.

## Two kinds of granularity

**Layers describe interacting systems:** ground shape and material, water/heat,
routes, supports, structure, vegetation, room use, furniture, contents and shared
appearance. They can have different spatial resolutions and overlap physically.
A bridge occupies space above a stream; a lava channel excludes combustible
supports; foliage yields to a road and a building's clearance envelope.

**Containers describe addressable places:** world, region, plot, structure,
floor, bay/room, furniture, support surface, slot and individual object. Each
container owns a local frame and a bounded generation problem. The renderer
may instance a model many times; every placed instance still has its own identity.
A room's purpose is semantic data (bathroom, laboratory, dining), not its theme.

These axes work together. A laboratory inside Bay 5 can have walls, service
connections, furniture, walkable clearance, shelf supports and small contents.
Do not allocate a centimetre-resolution graph for an entire kilometre-wide world.

## Required passes and contracts

| System             | Decisions                                                    | Required relations                                                                           |
| ------------------ | ------------------------------------------------------------ | -------------------------------------------------------------------------------------------- |
| Landform           | elevation bands, slopes, cut/fill and ground type            | continuous edges, feasible grade, erosion/shoreline boundary contract                        |
| Water and heat     | stream/lava channels, direction, level and hazard            | connected route, downhill or declared engineered flow, water/lava exclusion, bank clearances |
| Routes             | road/path class, width, turns, junctions and entrances       | reciprocal ports, traversable grade, destination reachability, crossings                     |
| Ground support     | house foundation, launch pad, piers, retaining edges         | complete footprint support, level tolerance, load category, access and hazard clearance      |
| Structure          | floors, walls, roofs, openings, fences and bridges           | snapped sockets, multi-cell footprint, support chain, enclosure and connectivity             |
| Ecology            | tree, shrub, grass, flowers and understory                   | soil/light/wetness preference, canopy/root volume and route/structure exclusion              |
| Space use          | stable named bays and rooms, including Bay 5                 | containment, room program, entrances, floor and required utilities                           |
| Furniture          | table, shelf, sanitary fixture, laboratory bench             | use compatibility, collision volume, reach/access clearance and support                      |
| Surfaces and slots | tabletop, plate surface, each shelf tier, each book position | explicit local transform, usable area, height, capacity and accepted roles                   |
| Contents           | individual fork, plate, food serving, book or ceramic snail  | fit, support, orientation, exact per-container counts, exclusions and locks                  |
| Appearance         | shared palette, lighting, roughness/detail profile           | cross-theme consistency while preserving meaningful material distinctions                    |

Terrain routes must be traced across region boundaries. A painted cell color is
not sufficient evidence for a connected stream, road or bridge. Visual light,
particles and physics consume the validated semantic result; they do not replace
its support and connectivity checks.

## Addressing and local change

Assign persistent IDs to placed instances and their containers. Display a
breadcrumb such as `World / Launch complex / Bay 5 / Lab / Shelf unit / Shelf 4`.
Labels and order can change without changing identity. A shelf's ordinal belongs
to its unit; it is not a flat world-array index. Serialization must retain IDs,
parent IDs, local transforms, named support surfaces, locks and revisions.

A change request contains a target ID, operation, editable layers/descendants,
required counts, preserved IDs, seed and baseline revision. It may target one
object, the contents of one surface, a room program or a whole region. Explicit
support surfaces permit nested arrangements such as food on a plate on a table.
Containment and support are separately validated relationships.

1. Find the target and its dependency boundary. Reject missing/stale IDs.
2. Build small local graphs at suitable resolutions; freeze unrelated domains.
3. Project parent sockets, support, exclusion volumes, route endpoints and locks
   into the graphs. Restrict domains to reviewed compatible catalog entries.
4. Solve with bounded search and, where needed, bounded cross-pass negotiation.
   Validate the staged result independently of rule construction.
5. Atomically publish all affected instances. Preserve unrelated IDs, transforms,
   contents and seeds exactly. Cancellation/failure leaves the baseline visible.
6. Record an undoable edit with its dependency explanation and reproduction data.

If changing a parent invalidates a locked child, report the specific conflict and
offer a concrete scope expansion. Do not silently move the child or delete a
neighbor. Moving a shelf with its contents preserves their local relationships;
replacing only its material preserves both geometry and contents.

## WFC encoding

Use the pinned library's existing mapped passes, per-cell domains, reciprocal
adjacency, value quotas, connectivity and negotiated regeneration where they fit.
Same-frame integer lattices may use the mapped-pass API at different pitches.
Different container frames need an explicit projection/adapter; arbitrary rotated
3D support must not be treated as an implicit integer-lattice mapping.

Each placed object has one anchor decision plus explicit footprint/clearance
occupancy. Count anchors, not occupied cells, when enforcing "three books".
A book spanning two cells is still one book. A grouped `books.glb` mesh cannot
satisfy three independently editable books without separate reviewed sub-assets
or an authored assembly exposing those three instances.

Use graph resolution appropriate to the task: terrain in metres, room planning
in decimetres, a table or shelf in centimetres (or a sparse socket graph). Smaller
props can use finer local units. Define units, origin, bounds and quantization
explicitly at every projection. Rendering scale must not silently change support
or occupancy contracts. Hard constraints and aesthetic preferences are distinct;
weights cannot guarantee exact counts or valid access.

## Catalog expansion and admission

The current 905-file inventory is a source inventory, not 905 admitted semantic
objects. It includes candidate modular walls, bridges, fences, platform pieces,
road segments, bathroom fixtures and bookcases. Examples include
`castle-kit/bridge-straight`, `nature-kit/fence_gate`,
`space-kit/platform_center`, `space-kit/terrain_roadStraight`,
`furniture-kit/toilet`, `furniture-kit/bookcaseOpen` and
`furniture-kit/books`. These names identify candidates, not verified sockets,
interiors, shelf tiers or single-book meshes. Current regional admission remains
far smaller than the inventory.

For each admitted asset record source/license/hash, semantic roles, real units,
origin/orientation, complete bounds, support surfaces, footprint and clearance
volumes, connection ports, allowed parents/children, material channels and LOD
policy. Separate raw source geometry, a reviewed assembly and a placed instance.
Keep functional category, room purpose, material and theme as independent tags.
Unknown compatibility must stay unknown; a filename match is not admission.

Expand against a coverage matrix: terrain/flow modules; modular foundations and
launch pads; interoperable road/fence/wall/bridge ports; architectural shells and
named interiors; sanitary and laboratory furniture; surfaces with individual
shelf tiers; discrete cutlery, dishes, food, books and ornamental objects including
a ceramic snail. Missing art needs a licensed source or original authored asset,
then the same measurement and review pipeline. Imported file count alone does not
close a category gap.

## UX and acceptance journeys

The browser needs progressive selection, an inspectable hierarchy, breadcrumbs,
isolation/cutaway views, hover outlines, count/role filters, locks and local
reimagination. A preview explains what will change and which support relations
prevent a requested change. Players should be able to select a visible item or
find it by name when it is hidden behind a wall. On a phone, drill into one scope
and provide a clear parent/back action instead of a permanently expanded tree.

The full world-creator critic gate remains held until these are exercised in
actual rendered desktop and phone journeys:

- Generate landform, add foliage and preserve it outside a selected plot.
- Place a supported house foundation and a distinct launch pad with a rocket.
- Connect a road, stream and lava channel with appropriate crossings, banks,
  hazard clearances and boundary continuity.
- Construct connected walls/fences and a traversable bridge over a stream.
- Name Bay 5, assign a laboratory inside it, add a table and retain other bays;
  independently furnish a bathroom and a house.
- Place a plate, food and fork on the table with real support/clearance checks.
- Put exactly three independent books on Shelf 4 and one ceramic snail on
  Shelf 2. Replace only the snail, preserving the books and their IDs/transforms.
- Undo, save/restore and replay that edit; reject an invalid support change and
  prove cancellation/stale worker results cannot alter the baseline.

Each journey must expose real decisions, validation and preservation evidence.
Authored geometry recipes and candidate catalog items must remain clearly
identified. This specification expands the existing full objective; it does not
approve the current regional demonstrator as complete.
