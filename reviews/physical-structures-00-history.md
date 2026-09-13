# Structure scale and cabin shell — bounded critic review 01

Critic: /root/feature_critic. Builder: /root. Date: 2026-09-08.
Decision: changes requested; this is an intermediate review of an actively changing prerequisite, not a release certificate.

The inspected scope is physical normalization of the existing regional assets, the original Pascal cabin shell, their collision implications and actual desktop/phone player-eye presentation. Full terrain earthworks, access, persistent foundations/launch pads, complete world composition and longform audio remain held. Prior approved interior review history is preserved; its changed input fingerprints need a later re-review.

| Category | Grade | Evidence and remaining work |
| --- | --- | --- |
| Intuitiveness | B | Both desktop and phone render at the actual 1.68m eye and retain the control journey. The close-door view in Create mode clips the header and provides poor scale context; phone Explore gives a complete doorway view. Verify the effective new projection and a usable approach view on both layouts. The earlier approach from the adjacent high terrace cannot descend to the cabin; that remains an explicit foundation/access requirement. |
| Accuracy | B | Actual CGE bounds confirm centered, grounded 7.2m × 11.6m × 7.2m rocket and 12m-wide modern house. The cabin has10m wall span/9.4m clear interior and correctly human-sized door leaf; the first trim overlap was corrected in source. The normalized rock collision regression is independently closed. Correct collision profiles for the enlarged tree variants and their full jitter interval are still being implemented/verified. |
| Wow factor | B | The original segmented cabin creates credible proportions and a coherent muted palette, but the repeated broad vertical door/gable grain reads as corrugation at walking distance, and the two plain roof sheets need more readable construction detail. This is a visual polish assessment of the shell, not a request for unrelated spectacle. |
| Thinking out of the box | B+ | An authored segmented shell around explicit physical clearances solves the incompatibility between stretched kit walls, a9.4m room and human-scale doors. Normalizing the complete reference assembly, retaining original source assets and measuring actual CGE instances is a useful practical foundation for future support composition. |

All four grades must reach B+ independently. This snapshot does not pass.

## Verified geometry and preserved findings

Independent cache-disabled Chromium contexts at1440×960 and390×844 loaded the current worker/world fixture. Both actual player states were x=-1.5,y=5.904325008,z=-8,ground4.224325008,eyeHeight1.68. Render/camera revision acknowledgements passed; initial recorded contexts had no page errors and the phone had no horizontal overflow.

Actual reference bounds matched the builder evidence: cabin min(-5.320323,0,-5.300000),max(5.320323,4.636453,5.300000), including roof/trim; rocket centered at ±3.6 in XZ and height11.599998; modern house centered with max XZ width12. Door leaf1.155×2.175×0.065. The wall opening/trim source now gives1.20×2.20 clear; this remains a closed facade and does not establish traversable doors.

The earlier approach fixture at x=.5,z=-8 stands at terrain5.747174, while the cabin base is4.224325. The eye is correctly1.68m above its own terrain, but3.20m above the cabin base. Holding the actual movement pad forward produced input1 and no movement. Initial y=6 did not cause this: UpdateWalk grounds the actual camera each frame. The parent now explicitly tracks earthworks/access separately; a dry building datum alone does not establish those requirements.

The initial rock oracle used the real CGE rock_largeA mesh at the exact current normalization, index82 jitter1.15 and quarter-turn2. It found1,379 positions where CanStand accepted a player center within the mesh, including rock0.594799m above the player's feet. After the shared profile/jitter collision fix, the identical scan finds0. Both result files are retained.

## Tree measurements supplied to the builder

These measurements use loaded CGE scene-space triangles with exact edge clipping, not raw accessor bounds or filenames. At base normalization width×2, clipping through height2/0.85 covers the0..2m band across every placement jitter0.85..1.15. Multiply these outward-rounded radii by the actual placement jitter and add the player radius according to the collision model.

| Exact source ID | Identified woody shape | Base radius, outward mm |
| --- | --- | --- |
| nature-kit/tree_oak | Primitive1, material woodBark | 1566 |
| nature-kit/tree_pineRoundA | Primitive0, material woodBarkDark | 621 |
| nature-kit/tree_default_fall | Primitive0, material woodBirch | 973 |
| fantasy-town-kit/tree | Single colormap primitive: all low geometry, not a separately identified bark mesh | 1078 |

The pine leafsDark primitive enters the player's height band and reaches radius2.400000095m before jitter. A bark-only collider requires an explicit foliage interaction policy; do not call the crown empty space or silently infer that all low geometry is woody. The fantasy source has one material/primitive for both trunk and crown, so material-based separation is unavailable. These profiles are relative to the model support datum; future steep terrain and player height differences require a corresponding vertical admission policy.

## Required next evidence

1. Verify all four tree variants across the placement jitter interval and quarter-turns with the same renderer/collision policy. Preserve the source identity and measured profile provenance.
2. Verify the effective walking projection after the new build. Capture the whole door with a little ground/header context at a natural stance on desktop and phone, retaining the measured1.68m eye. The source now sets70°, but that value was not exposed in my reviewed browser state, so I do not certify the effective FOV from source alone.
3. Refine the large wood surfaces so their grain reads as varied surface detail rather than regular corrugated bands. Give the roof construction edges/seams that remain coherent in the overview. Recheck the actual rendered results on both sizes.
4. Keep foundation datum/dryness, earthworks, hazard/access and the persistent support layer explicitly unfinished until independently exercised. Closed cabin doors are not evidence of completed exterior-to-interior traversal.

Evidence: build/critic/structure-scale-01-evidence.json; structures-02-*-world/door.png; structures-03-door-{1440,390}.png; structures-03-explore-{1440,390}.png; scaled-collision-evidence.txt and scaled-collision-retest-evidence.txt; tree-profiles-evidence.txt; tree-bands-evidence.txt; tree-jitter-evidence.txt; tree-original-materials.json. Corresponding ignored Pascal probes are retained in this directory. No authored implementation or previous approved report was edited by the critic.


## Closure review, 2026-09-08

The original grades and findings above are retained unchanged. The subsequent surfaces build exposed a new timing defect: the first walking camera acknowledgement published the prior orbit45-degree effective projection because the parent view Render ran before its child viewport. RenderOverChildren now publishes the acknowledgements after the viewport; independently retested first walking frames report70-degree minimum effective FOV on both sizes and the project path.

The tree collision revision passed an independent native CGE triangle oracle for all four exact assets at all31 placement scales, including clipping triangle edges through the occupied height band. Pine deliberately includes its dense low foliage, and the mixed fantasy primitive uses its whole lower envelope. Independent native84238 landscape checks and905-model/19-choice asset verification passed. The prior submerged restore now rejects; all five explicit architectural operations reject that same invalid datum. Three freshly generated48x48 seeds contained592 buildings, all passing a separately calculated dry-height threshold.

The roof now has physical standing seams/fascia, and the painted timber uses restrained irregular detail. Fresh desktop/phone Create/Explore views and a closer roof view close the shell-specific polish findings. All19 regional models independently loaded through actual project-path CGE instances with centered/grounded bounds and the intended maximum horizontal size. Keyboard and touch walking stopped outside the closed cabin; releases, retreat and phone look worked.

The resulting bounded pass is in physical-structures-01.json. It does not close the terrain earthworks/access, explicit foundation/launch-pad, full-world visual, seamless doorway or longform audio holds. The older interior report remains historical and stale after its input changes.
