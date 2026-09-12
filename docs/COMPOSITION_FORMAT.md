# Composition document format

`phanes.composition.wire` reads and writes a standalone identity/support
document. World format 2 embeds this document as its `composition` field.
It serializes explicit container volumes in version 2. It does not serialize
surface dimensions, content slots, catalog
admission, generation requests, undo history or renderer state.

The root contains `format: "phanes.composition"`, `version: 1` or `2`,
`units: "millimetres"`, a nonnegative integer `revision`, and a `nodes` array.
Native transport is explicitly UTF-8; browser transport is JavaScript text.

Each node requires every field below, including empty optional references.

| Field         | Meaning                                                                                  |
| ------------- | ---------------------------------------------------------------------------------------- |
| `id`          | Persistent instance ID; ASCII letters, digits, dot, dash or underscore; 1–128 characters |
| `parent`      | Owning node ID, or empty for the sole root                                               |
| `support`     | Explicit supporting surface ID, or empty when unsupported                                |
| `name`        | Unicode display label, independent of identity; up to 4,096 UTF-16 code units            |
| `role`        | Nonempty ASCII semantic code; up to 256 characters                                       |
| `asset`       | ASCII asset/assembly ID; required for objects; up to 512 characters                      |
| `kind`        | `container`, `surface` or `object`                                                       |
| `x`, `y`, `z` | Signed 32-bit local millimetres in the owner's coordinate frame                          |
| `quarterTurn` | Integer 0–3, rotation around local up                                                    |
| `width`, `depth`, `height` | Version 2 only: nonnegative signed-32-bit container dimensions in millimetres |
| `seed`        | Unsigned 32-bit provenance seed                                                          |
| `locked`      | Boolean lock, propagated through ownership and support dependencies                      |

References and labels never depend on array ordering. The root is an unsupported
container. References must resolve, IDs must be unique, and the combined
ownership/support graph must be acyclic and no deeper than 128 edges. A support
reference must identify a surface. These are structural checks, not proof that
an object physically fits or that its asset is admitted.

Version 2 requires all three dimension fields on every node. They are either
all zero (geometry supplied by an implicit profile) or all positive, and only
containers may have positive dimensions. A container volume is centred on local
X/Z, extending from `-width/2` to `width/2` and `-depth/2` to `depth/2`, with floor
at Y=0 and ceiling at `height`. Positive quarter turns rotate +Z toward +X.
The structural validator transforms each explicit volume through its ownership
frames and checks full containment inside its nearest explicit ancestor.
Half-millimetre boundaries remain exact, including for odd dimensions.

Sibling separation, usable portals, furniture and supported contents fitting
inside the volume, services and actual catalog shell geometry require separate
domain admission. The integer transport range is not an admitted renderer or
solver size. Existing implicit world, groundwork, building and studio profiles
reject explicit dimensions; these fields cannot resize catalog meshes.

Changing, adding or removing explicit dimensions is a physical change for scoped
commits. Protected descendants and outside-scope support dependents conservatively
prevent that change, even if a proposed larger volume could contain them. A
display-name change does not change geometry or identity.

The writer emits version 1 when every node has implicit geometry, preserving
legacy studio exports. It emits version 2 if any node has explicit dimensions.
Version 1 rejects the presence of any dimension field, even zero or null; it
cannot silently discard newer geometry. Version 2 rejects missing, fractional,
null or out-of-range dimensions. The world envelope remains version 2 because
the embedded composition has its own version; older composition readers reject
version 2 rather than accepting and losing the new fields.

Both versions limit a document to 65,536 nodes, 16 levels of JSON nesting and 64
members per JSON object. The text limit is 16,777,216 UTF-8 bytes on both runtimes;
the browser counts the encoded size of its UTF-16 text. Duplicate JSON members,
including equivalent escaped
names, are rejected. Field names and semantic codes are ASCII; display labels
retain Unicode. Numbers and booleans are never coerced from strings.
Malformed UTF-8 and unpaired surrogate characters/escapes are rejected before
decoding can silently replace them. Supplementary characters retain their full
Unicode scalar value.

Decoding creates a private candidate, validates it, then assigns the caller's
document. A failed load preserves the previous document. Loading a document does
not increment its revision; a successful scoped edit increments it once.
Unknown format versions or units are rejected without automatic migration.

Run `tools/test-composition.ps1`, or compile with `build-web.ps1 -WithTests`
and execute `node tools/test-composition.cjs`, for the shared native/browser
regressions. The fixtures represent schema and constraint behavior, not admitted
rendering assets or a completed in-game editing journey.

## World snapshots

World exports use an envelope with `version: 2` and `world.formatVersion: 2`.
The world retains its five regional arrays and adds the composition document.
Version 1 snapshots without a composition migrate to a canonical empty `world`
container. Version 2 requires its document. A version 1 snapshot cannot smuggle
in a composition field. Both versions still undergo regional validation.

The first admitted interior profiles are described in [INTERIORS.md](INTERIORS.md).
Explicit [groundworks](GROUNDWORKS.md) use the same document contract. A supported
`site-X-Z.deck.building` container names its deck as both parent and support, uses
local position zero and follows the access quarter turn. A cabin's `.studio`
child retains its local 80 mm floor offset. Regional arrays alone cannot recover
this ownership. Whole-world admission checks the support assembly and every
building/interior descendant before restore or a scoped edit can succeed.
Their immutable profile IDs supply measured geometry and support slots. Restore
validates those profiles, ownership, exact poses, contents and regional anchors;
it does not regenerate the saved items. Runtime render versions are separate
from saved document revisions, so importing another snapshot with the same
revision still rebuilds the view. Undo history and camera state are not exported.
