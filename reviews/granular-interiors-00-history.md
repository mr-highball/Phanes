# Granular interiors: retained review history

Critic: `/root/feature_critic`; builder: `/root`; 2026-09-08.

This retains the earlier rejected states of the bounded cabin-studio workflow.
It is not an approval or a fingerprinted review of the current implementation.
The eventual registered JSON review must assess the actual revised inputs.
The complete granular world and longform audio remain on hold independently.

## Initial correctness audit

The critic executed compiled Pascal worker messages in isolated browser-runtime
VMs. Initially, room creation failed for seeds 1 through 32 before any decision.
The furniture adjacency keys used an outgoing-neighbor convention while WFC
expects incoming-neighbor rule keys. Reversing those keys in a critic-only
in-memory experiment produced an admitted composition. The builder corrected
Phanes; no WFC dependency change was needed.

Initial import admission also accepted invalid support transforms, shelf heights,
missing furniture/supports, overlapping furniture and stale regional anchors.
Strengthened profile admission subsequently rejected all 18 invalid cases and
88 one-millimetre/quarter-turn mutations, while accepting canonical, locked and
Unicode-labelled compositions. Additional message-boundary findings covered null
top-level requests, null optional fields, unknown operations and missing restore
data. Those were corrected and independently retested in 21 boundary cases.

The original 4 by 3 furniture graph did not represent a physically clear aisle.
The revised 4 by 4 graph admits all eight combinations of four bookcase anchors
and two table anchors. Diverse seeds including zero and 4294967295 were checked.
Regional cabin removal now prunes only its owned hierarchy, rejects protected
descendants and preserves all 22 records of a second cabin exactly. Default
appearance labels update, custom Unicode labels survive, and cross-role shelf
replacement retains every unrelated node.

Detailed initial findings and artifact fingerprints are retained under ignored
`build/critic/interior-correctness-01.md` and the referenced JSON evidence,
including `interior-correctness-evidence-03.json`. Later changes require fresh
verification; these historical checks do not certify arbitrary new source.

## First graded UI review: changes requested

| Category | Grade | Material finding |
| --- | --- | --- |
| Intuitiveness | B | Inherited locks left unavailable item actions enabled without a useful ancestor explanation. Hierarchy activation removed keyboard focus and left it on BODY. |
| Accuracy | B | The new interior controller was handwritten JavaScript despite the Pascal requirement. An operation whitelist also rejected the existing Rockets action. |
| Wow factor | B | Recognizable, separately editable props and scale were present, but room/furniture materials were broadly flat and lacked the agreed realistic surface detail and grounding cues. |
| Thinking out of the box | B+ | Persistent supports, individual WFC contents, scoped preservation, exact undo and lock-aware regional removal form a useful hierarchy across scales. |

The critic exercised actual desktop clicks and phone taps/swipes, shelf counts,
cross-role replacement, undo/redo and touch walking. These working paths did not
override the three grades below the required floor. The original report is
`build/critic/interior-workflow-review-02.md`.

## Controller correction review: changes requested

The builder migrated the new controller to Pascal, restored Rockets, added
recursive parent/support lock feedback and disabled actions, focused an announced
hierarchy heading, and exposed exact snapshot export on the phone. Independent
browser checks recorded those closures in
`build/critic/interior-ui-closure-evidence-04.json`.

| Category | Grade |
| --- | --- |
| Intuitiveness | B+ |
| Accuracy | B+ |
| Wow factor | B |
| Thinking out of the box | B+ |

Visual material/lighting quality still blocked acceptance. This state is retained
in `build/critic/interior-workflow-review-03.md`.

## Material and picking revision

Procedural material detail improved the room and props. The initial ceramic
metallicity was corrected; the critic inspected the revised azure glaze. A new
visible-snail picking failure was independently reproduced with the snail in its
left reserved shelf slot. The ray hit a bookcase post only 0.02068 metres from
the eye, although the 0.1-metre near plane clipped that post out of the render.
CGE's eye-origin collision ray does not itself apply the visible near plane.

The builder moved the ray origin to `PositionToCameraPlane` at `ProjectionNear`,
retaining the original ray direction, and improved close-up framing. A fresh,
cache-disabled critic browser confirmed the formerly failing oblique center hit.
An apparent failure seen after reloading an older browser context was caused by
cached old WebAssembly alongside new UI code; it is not a current-source
regression. Final center/off-center and phone checks remain required after the
floor revision. Initial evidence is in
`build/critic/interior-picking-review-05.md` and
`build/critic/interior-pick-clip-evidence-05.json`.

The critic additionally identified dashed geometric floor gaps and weak furniture
grounding. The builder introduced a continuous floor, filtered board joints and
explicitly approximate analytic contact attenuation. Its first build had a room
construction failure discovered by the builder's browser test, so final visual
acceptance was held pending correction. This historical report deliberately
does not grade that unverified correction or promote the complete world/audio
features.

## Remaining back-face finding and closure

After the corrected continuous-floor build, fresh cache-disabled desktop and
phone contexts exposed a distinct remaining failure in the same left-slot
fixture. Near clipping removed the post's front face, but the ray then hit its
back-facing exit. An independent Pascal oracle over the original GLB measured
the front face at 0.020684771 m, the back-facing exit at 0.129789306 m, and the
next front-facing shelf at 0.434357381 m. The renderer culls the exit face; the
physical triangle collision query accepts both sides. The visible snail was
therefore still incorrectly selected as its bookcase. This is a confirmed
current-build failure, distinct from the earlier stale-context observation.

The builder added a bounded traversal past culled faces, respecting mesh
double-sidedness and triangle winding. The critic's fresh final contexts passed
all 20 center/four-offset picks in frontal and prior-oblique views at desktop
1440 x 960 and touch-phone 390 x 844. Clicking a real visible post still selects
the bookcase. A critic-only fixture changed the copied bookcase GLB's material
double-sided flags using Pascal and substituted only the copied data archive
in one browser request. Its back-facing post becomes visibly opaque and remains
correctly selectable. The authored model and source archive were unchanged.

The oracle and final evidence are under `build/critic/`:
`phanes.critic.glb.ray.lpr`, `interior-07-bookcase-ray-oracle.txt`,
`phanes.critic.glb.double.sided.lpr`, and `interior-final-evidence-08.json`.
The following numbered JSON records the final bounded decision and exact
registered input fingerprints. Historical rejected states remain above.
