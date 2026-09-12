# Granular interiors — corrective review 02 (build04 evidence)

Critic /root/feature_critic, builder /root, 2026-09-08.

Exact existing scope: Cabin interior creation using local WFC furniture and contents graphs, measured four-tier shelves, individually editable books and ornaments, tabletop props, safe snapshot import/undo and usable desktop/phone inspection.

Decision: changes requested. Historical grades for this build04 review are intuitiveness B+, accuracy B, wow factor B, thinking out of the box A-. Every category must reach B+; no averaging applies. This report does not replace the older recorded report or approve the full world/music requirements.

- **Intuitiveness B+:** The hierarchy now continues from table to plate to its actual usable surface and individual food. Desktop/phone builder journeys demonstrate framing, actual food picks, scoped replacements, exact undo and count operations. The explicit Prepare this plate for food action resolves the original old-save discoverability gap without automatic migration or changing the saved plate appearance. Ancestor/descendant locks disable protected plate appearance edits; a sibling remains available. The count action keeps neighbors unchanged. The large outline is assessed below as a visual issue.
- **Accuracy B:** Independent generic adapter probes pass79 geometry/contact cases and192 candidate solves in native and executed pas2js, after two documented identity-domain defects were corrected. Actual native CGE measurement proves six food envelopes, top/bottom visible-ray hits, y0food contact, and a13,689-ray sweep of the116mmplate square at y6mm with only0.000006mm numerical error. The original3mmplate/table gap was corrected by an annular foot to y0 without shifting its food surface. Independent full world count checks pass96native and12executed pas2js remove/re-add pairs in two furnished cabins, preserving every other complete node and consuming one revision per operation. However, the registered full-scope inputs omitted groundwork assembly/geometry and elevation dependencies used by current whole-world interior admission; changing those could bypass fingerprint invalidation. Add these relevant contracts and supported-path inputs before full acceptance.
- **Wow factor B:** Build04 screenshots at1440x960 and390x844 show food clearly after correcting the camera pitch sign. Bread has visible crumb detail and the plate has a shaped glazed rim. The pale herbed cheese is almost featureless and blends into the ivory plate; its source shader has no herb-specific treatment. The apple's sharply peaked crown under a straight stem reads more like an onion in lower-angle inspection. Tall full olive selection boxes cross the food silhouettes and dominate the small arrangement. Give cheese visible semantic surface detail and separation, shape an apple crown/shoulders, and use restrained readable selection that leaves the contents visible. Correct physical dimensions alone do not close these rendered-quality gaps.
- **Thinking out of the box A-:** This is a generic recursive assembly-envelope adapter, exercised by a non-food carrier/tray/specimen/support/badge hierarchy as well as actual nested food. Existing parent appearance changes and surrounding WFC solves preserve compatible supported subtrees; explicit removal/count changes remain atomic and lock-aware. It extends the existing persistent support model in a practical reusable way.

Evidence: nested-contents-correctness-review-02.md and its retained failure/closure files; food-native-evidence-02.txt (original plate gap), food-native-evidence-03.txt (corrected contact), food-state-native-evidence-01.txt (96pairs), food-state-pas2js-evidence-03.json (12pairs). Two earlier combined setup+execution VM runs exceeded50seconds and were not counted as passing; separating completed fixture setup from the unchanged generated comparison procedure allowed all12pairs to finish in37seconds. This VM timing is not a browser performance benchmark. Builder evidence inspected separately: build/nested-contents-interiors-root-evidence-04.json and project04 full functional log; no independent CGE browser was launched during the builder's sequential suite.

Copied build04 visual evidence is retained as food-build04-{plate,plate-contents,fruit}-{1440,390}.png. Builder has subsequently proposed build05 fixes; these grades describe the prior evidence only. A new review is required after actual corrected mesh/visual/interaction checks and stable full input coverage. Earlier passes remain stale and full world/audio holds remain unchanged.


---

# Granular interiors — corrective review03 (build05 evidence)

Critic: /root/feature_critic. Builder: /root. Date:2026-09-08.

Exact unchanged scope: Cabin interior creation using local WFC furniture and contents graphs, measured four-tier shelves, individually editable books and ornaments, tabletop props, safe snapshot import/undo and usable desktop/phone inspection.

Decision: changes requested. Grades: intuitiveness B+; accuracy B+; wow factor B; thinking out of the box A-. No category averaging. Full world and audio holds remain unchanged.

This follows granular-interiors-corrective-review-02.md, retaining its failed evidence rather than treating corrections as if the original result passed.

## Closed findings

- The registry now includes the relevant whole-world groundwork/elevation/supported-building admission dependencies. Current candidate fingerprints are in granular-interiors-candidate-inputs-03.json; this is not a final passing fingerprint certification.
- The actual apple mesh has rounded shoulders and a recessed crown; its tilted stem remains inside the conservative40×40×48mm catalog envelope (measured maximum y45.16178mm). The herbed cheese has visible green flecks and a warmer rind, preserving its42×44×22mm envelope and separating it from the plate.
- The plate remains grounded at y0, and all13,689plate contact rays still meet its y6mm usable surface to0.000006mm numerical error. All six food variants retain valid top/bottom visible rays and catalog containment.
- The full crossing boxes were replaced by48short corner marks. Independent native CGE inspection verifies they stay outside physical bounds, do not cast shadows or intercept picking/collision, and repeated selection does not leave orphan outlines. Evidence: food-native-evidence-05.txt.
- Root05 full worker and desktop/phone journeys pass, including legacy preparation, protected parent controls and editable sibling food. Builder evidence is build/nested-contents-interiors-root-evidence-05.json. The critic independently inspected current desktop and phone images, copied here as food-build05-*.png. Native/pas2js state and generic adapter correctness evidence from the preceding report still applies.

## Remaining blocker

**Individual selection loses legibility on the phone.** In food-build05-fruit-390.png the current fruit markers appear as tiny, broken flecks. The implementation uses world/object-relative thickness with a0.35mm minimum, so a40mm-wide fruit rendered about40CSSpixels wide receives roughly0.35CSSpixel gold strokes and0.19CSSpixel dark strokes. Their separation is also subpixel. This makes the two-tone treatment unreliable even at the provided Look closer framing; the phone's hierarchy label identifies a selected item, but the world marker should also identify the visible object clearly.

Use camera projection and canvas CSS size to maintain a minimum readable stroke around1.5–2.25CSSpixels for selected small objects, following the already exercised groundwork approach. Preserve ordinary depth testing, unpickability/collision exclusion, actual bounding-box padding and short corner geometry. Retest the framed fruit at390×844 and a reasonable zoom change; the marks should form recognizable corners rather than scattered pixels. Plate-wide markers and the new food materials no longer block this review.

The wow-factor B grade describes this material remaining rendering/feedback gap. Intuitiveness B+ reflects the working reversible hierarchy/count/pick flow; accuracy B+ reflects the corrected generic identities, exact-state and actual-geometry evidence plus complete admission input coverage; thinking-out-of-the-box A- reflects the reusable nested assembly model. No final passing report is issued while the phone marker defect remains.
