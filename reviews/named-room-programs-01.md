Retained original build02 narrative. The same critic records its four-category
baseline assessment in named-room-programs-01.json; the text below preserves
what was known before the final re-review. Corrections are reviewed separately.

# Named-room rendered review 01

Critic /root/feature_critic; builder /root; 2026-09-08.
Served runtime: rooms-integration-web-build-02. Root host.
Early rendered feedback against the full named-room-programs scope. No feature
grades or pass are issued: corrections and complete rendered evidence remain.

## Blocking observations

1. Shelf close-ups ignore accumulated room/furniture rotation. The independent
   Bay 5 lab journey framed Shelf 4 from its side, putting three books behind
   one another. Two were nearly hidden by the foreground cover. Repeated in
   both the builder's screenshot and an independent current-page capture:
   rooms-ui-01-desktop-shelf4.png. Resolve the support's accumulated plan-relative
   facing and verify all four facings with individually visible/pickable books.
   Builder reports a source correction, but it was not served during this run.
2. The primary phone purpose action is initially hidden. Selecting Bay 5 resets
   the 390 by 844 phone panel to scrollTop 0. The panel has only 311 px height
   but 884 px content. Laboratory starts at screen y866.8, below the viewport;
   Room layout and naming consume the initially visible area. A real touch swipe
   scrolls 205 px and reveals the purpose buttons, proving scrolling works,
   but it obscures the main next step when a player chooses an empty bay.
   Prioritize purpose before secondary layout/name controls or provide a visible
   purpose entry. Evidence: rooms-ui-01-phone-bay5.png,
   rooms-ui-01-phone-purpose-scrolled.png and rooms-ui-01-evidence.json.

## Verified current interactions

The independent desktop session used visible controls to create a size-4 world,
apply the cabin brush, open Design rooms, choose six bays, choose Bay 5 and
create a laboratory. A one-cell selection at (1,1) was assigned as a fixture;
subsequent room operations used the visible controls and real compiled worker.

The rendered plan acknowledged each scene before capture. Floor-contact shading
now includes room-owned furniture through the explicit ancestor transforms.
Source resolves each immediate BoundingBox into plan coordinates before viewport
attachment. InteriorFloorDetail dynamically creates one contact uniform per
supplied footprint; there is no four-item cap. Its old comment was stale.

Desktop First person entered at eye y1.68 and z3.8. Actual keyboard movement
followed the corridor to (0,0.008), then crossed the Bay 5 doorway to
(1.434,0.008). This verifies one complete rendered portal crossing, not every
layout, door, fixture approach or controller edge case.

A separate touch context used 390 by 844 CSS pixels, DPR2, and the current valid
world imported through the visible file input. The visible Open interior control
opened the plan. Actual screen taps selected an empty Bay 1 room and the visible
Bay 5 bench correctly through CGE ray picking. A Bay 6 bathroom was created with
the purpose control, and its basin, toilet and shower enclosure rendered.

The phone has no horizontal page overflow. Real CDP touch events scrolled the
panel, and the layout dialog fits without internal scrolling: x16, y122.9,
width358, height598.2, ending at y721.1. Escape closes it. No page errors were
recorded in either independent context. All browser processes were then closed.

## Evidence and limits

Current independent screenshots and structured evidence are retained under
build/critic/rooms-ui-01-*. The saved world fixture is rooms-ui-01-world.json.
The builder's first rendered suite independently reached the lab, shelf edits,
six-slot bench and neighbor bathroom but stopped on its own hidden desktop
export selector; that is a test error, not a demonstrated export product defect.
Desktop uses the visible header Export control.

The new layout chooser is readable and accurately depicts two/four/six bays.
The cutaway makes adjacent purpose-specific rooms understandable. Large selected
volumes use corner brackets at their real ceiling boundary; this is visible
feedback, not a false physical wall. Full wall view remains reserved for walking.

Still required before acceptance: corrected facing and purpose priority, all
four shelf orientations/direct item picks, phone movement, supported-building
hosted room journey, import/undo/locks and repeated-edit recovery in the full UI,
and final complete registered input coverage. Larger plan/room views must reset
prior close-up angles. Existing studio and supported-building regressions must
remain valid. No narrowing of the named-room or wider world scope is implied.

Separately, the world and wall probes have been promoted to critic-owned durable
tests: tests/phanes.tests.spaces.world.critic.pas,
tests/phanes.tests.spaces.walls.critic.pas, and
tests/phanes.tests.spaces.integration.lpr. Native run: 1,159 world + 10,071 wall
checks. Compiled Chromium: 1,163 world + 10,071 wall checks in 10.65 s; the extra
four cover browser world save/read. These are domain regressions and cannot
substitute for the remaining rendered review.
