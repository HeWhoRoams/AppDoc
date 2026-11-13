# ADR 0008: Finding candidates are Facts, and the Check requires each one to be addressed

- **Status:** Accepted (2026-11-11)
- **Decision area:** Facts; Check; Source-to-claim audit

## Context

The P7 evaluation of the 2.2 documents (`docs/p7-evaluation-2026-11-11.md`) found that every missed
answer-key item was a specific code property that no Fact pointed to: a copy-pasted logger type, a
flash attribute lost on a non-redirect return, distinct "invalid username" and "invalid password"
messages, a `|safe` filter, a GET route that deletes, an actuator exposure set to `*`. Writers do
not open lines that nothing points to. Guidance in SKILL.md ("look for logging mistakes") cannot
fix that: it asks for attention the writer has no reason to spend, and nothing notices when it is
skipped.

## Decision

1. The extractor records **finding candidates** as `smell` Facts: `pattern`, `path`, `line`, and a
   stable id, `sha1(kind, pattern, path, line)[:8]`, printed in `facts-summary.md` and
   `check-report.md`. A candidate is a prompt to read the code, not a verdict.
2. **C12** fails when a non-test `smell` is neither (a) cited in a 10.1 row by `path:line` (or a
   range covering the line) nor (b) `Dismissed` in the Evidence Register with ref `smell/<id>` and a
   reason in `limitation`.
3. The auditor reviews each undismissed candidate: confirm it (the writer adds a 10.1 finding) or
   dismiss it with a reason. The writer does not dismiss their own candidates.
4. Seven patterns ship in 2.3: `logger-type-mismatch`, `flash-without-redirect`,
   `distinct-auth-errors`, `unescaped-template-output`, `state-change-on-get`, `actuator-exposed`,
   `hardcoded-credential-constant`. The last records a location only; the value is never stored.
5. **Precision rule.** A pattern ships only with a positive test, a negative test, and a precision
   run on real Targets with every hit labeled true or false by hand. A pattern under 80% precision
   is cut before release. A pattern that fires more than 20 times on one Target without a true
   positive is dropped.
6. The Check never judges whether a finding's wording or severity is right. Whether a candidate is a
   real defect, and how it is described, stays with the writer and the auditor. The glossary rule
   (a 10.1 identifier that is not a common word has a section 13 row) is auditor judgment and is not
   enforced, because "common word" is not machine-decidable.

## Consequences

- A Target in a Stack with no patterns produces no candidates, so C12 cannot fire there. The 2.1
  block should say so.
- Every pattern is a maintenance cost: a regex that stops matching after a framework change fails
  silently. The precision run is repeated when a pattern changes.
- A dismissed candidate is recorded in Appendix A with its reason, so a later reader can disagree.
- An absent candidate is not evidence that the code is clean.
