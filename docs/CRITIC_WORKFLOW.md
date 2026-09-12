# Feature critic workflow

Every produced feature goes through a builder/critic cycle. The critic is an
independent agent with access to the implementation, requirements and evidence.
It reviews the actual behavior and user journey, including feasibility on the
web target. A description of intended behavior is not evidence that it works.

## Assignment and independent review

The delegator/integrator uses GPT-6 Astra with High reasoning. Before assigning
work, it records a short complexity assessment: ambiguity, architectural reach,
numerical or concurrency risk, dependency familiarity and available verification.
Bounded implementation work goes to GPT-5.6 Sol when that assessment
supports it. Briefs identify relevant files, constraints, acceptance criteria,
permitted edits and required evidence without forwarding the full conversation.

The user's 2026-09-12 usage constraint supersedes the earlier requirement to
create a new builder for every task. Run at most one active subagent at a time,
including the critic. Reuse a relevant builder for closely related follow-ups;
start a fresh, context-limited assignment only when its existing context is no
longer useful. Builders must not delegate further. Use Sol Low for straightforward
implementation and orchestration, Medium for bounded multi-file work, and High
only after documenting a concrete correctness risk. Stop failed approaches after
two attempts and return a compact diagnosis for reassessment.

Batch related implementation and verification into one handoff. Deliver evidence
to Luna once the candidate is stable and required checks pass; subsequent reviews
focus on changed inputs and prior findings while preserving the full acceptance
scope. Avoid duplicate investigations, repeated successful tests, speculative
polish and agent turns that merely poll another agent's progress. Astra retains
High reasoning for integration but should minimize routine coordination turns.
Keep the B+ gate: the usage audit did not identify Luna as a material cost driver.

Astra retains unresolved engine behavior, cross-layer architecture, difficult
constraint correctness and audio-quality design, while delegating separable
implementation. A builder that discovers a deeper problem returns its evidence
and attempts for reassessment instead of repeating an unsuccessful approach.

GPT-5.6 Luna independently reviews every feature, including work built by Astra.
Previous critic identities or model choices do not establish compliance with this
assignment. The critic owns reports, grades and input fingerprints. A failed
category returns to the builder for correction and another Luna review; no grade
may be averaged away or replaced by the builder.

GPU/browser performance measurements run serially. Search explicit source and
evidence directories; avoid recursively scanning generated sites, browser profiles
or entire toolchain drives. Broad asset scans can distort both build and benchmark
timings. These working practices do not reduce any feature's acceptance scope.

## Required grades

The critic assigns a separate grade to each category. **All four grades must be
B+ or higher** to pass; averaging strong and weak categories is not allowed.

| Category                | What the critic assesses                                                                                                                                                  |
| ----------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Intuitiveness           | Discoverability, useful defaults, feedback, input effort, accessibility, phone/desktop operation and recovery from mistakes.                                              |
| Accuracy                | Fidelity to the user requirements, correctness of constraints and outputs, honest claims, provenance, deterministic behavior where required, and sufficient verification. |
| Wow factor              | The visible or audible quality of the experience, polish, coherence and whether the feature delivers a compelling result worth demonstrating.                             |
| Thinking out of the box | Useful, original combinations of capabilities that make creation more powerful or easier; novelty must have a practical benefit.                                          |

| Grade | Standard                                                                                      |
| ----- | --------------------------------------------------------------------------------------------- |
| A     | Exceptional execution with convincing evidence and no material gaps in the reviewed scope.    |
| A-    | Excellent execution with only small refinements remaining.                                    |
| B+    | Strong, complete and feasible execution; requirements are met and remaining issues are minor. |
| B     | Useful and working, but a material gap or friction point remains.                             |
| C     | Partial or uneven implementation; substantial correction is needed.                           |
| D     | Major requirements or the intended user journey do not work.                                  |
| F     | Missing, fundamentally incorrect, or unusable.                                                |

## Review cycle

1. The builder identifies the feature scope, acceptance requirements, known
   limitations, changed files and reproducible evidence. Scope cannot be reduced
   merely to omit a failed requirement from the user's requested feature.
2. The critic independently inspects the code and exercises or examines the
   relevant results. UI features require desktop and phone journeys. Audio and
   visual quality require actual playback/rendered evidence; compilation alone
   cannot establish their quality.
   Evidence is proportionate to the feature: developer tooling is assessed for
   clear commands, useful diagnostics and demonstrated behavior, without an
   artificial requirement for visual spectacle or musical playback.
3. The critic returns the four grades, evidence for each, a pass/fail decision,
   and concrete changes needed to reach at least B+ in each category. Missing
   evidence must be identified explicitly and cannot receive a passing grade.
4. The builder fixes the findings, repeats relevant checks and asks the critic
   to review the revised result. The critic owns its grades; the builder must
   not replace them with a self-assessment or request lenient grading.
5. Retain the critic's reports under `reviews/`, including failed reviews, agent
   identities, reviewed scope, date, file fingerprints and evidence references.
   Register every produced feature in `reviews/features.json` and point its
   `review` field at the latest report, or leave it null while review is pending.
   Summarize the result in verification documentation. Material changes to scope,
   implementation or dependencies invalidate the affected acceptance and require
   re-review. Do not delete a failing feature from the registry to obtain a pass.
   Do not label the feature complete, pass it to the next release gate, or claim
   the full product goal achieved until its critic gate has passed.

The critic should distinguish blockers from minor refinements and should not
award points for unnecessary complexity. Astra may continue independent work
during a review, but the one-active-subagent limit also applies to builders and
critics. This gate does not authorize unrelated external changes.

## Applying the gate

Run `./tools/reviews.ps1 -WithTests` from PowerShell. The wrapper compiles the
Pascal checker and its regression fixtures using `FPC_NATIVE` (or `fpc`). The
checker returns a nonzero result for pending, rejected, incomplete or stale
reviews. Its output identifies each held feature and the reason. Test fixtures
use synthetic grades only in ignored `build/review-tests`; they never approve
real features.

CI retains build/test evidence even while features need work. The separate
`critic-gate` job must pass before Pages publishing. A successful compiler or
browser test run cannot override a failed critic gate.

The builder declares each feature's complete repository-relative `inputs` in the
registry. The critic verifies that these cover the implementation and relevant
contracts, dependencies and tests, then records their SHA-256 fingerprints in
`reviewedFiles`. Use `build/tools/phanes.reviews hash <file>` (`.exe` on Windows)
to obtain the same fingerprints as CI. Authored source/document text uses LF
normalization; other files are hashed as bytes. A changed input or scope requires
a fresh critic review, even when the builder believes the change is minor.

The checker enforces recorded decisions and fingerprints. It cannot authenticate
an agent's identity or discover deliberately omitted scope. Independent critic
inspection and honest feature registration remain mandatory; the builder must
never invent a critic identity, grade or evidence to satisfy the checker.

## Critic report format

Reports are JSON with `schemaVersion: 1`, `feature`, the exact registered `scope`,
`criticAgent`, `builderAgent`, `reviewedAt`, and `decision` (`pass`,
`changes_requested` or `pending`). Add `grades` with these four keys:

- `intuitiveness`
- `accuracy`
- `wowFactor`
- `thinkingOutOfTheBox`

Each category contains a `grade` and specific `evidence`. Also include
`blockingFindings` (an array of actionable corrections), `verification` (a nonempty
string containing commands, results and artifact references), and `reviewedFiles` (a path-to-SHA-256 object
covering the declared inputs). Failed or pending reports may identify missing
evidence explicitly; a passing report may not. Retain prior reports and create
a new numbered report for the next review. Link longer narratives or generated
artifacts from the report rather than copying large outputs into it.
