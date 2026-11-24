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

## Amendment (2.8.0): Facts-level candidates and the obligation gate

- **Status:** Accepted (2.8.0). Items 1 to 4 above stand; this adds to them.

1. **A second pass reads Facts.** `smells.extract` still reads one file's text (cached per file). `smells.from_facts` runs in `extract.py` after the W4 post-pass and reads only Facts, so it is deterministic for every worker count and cache state. A `smell` Fact carries `sources`, `(path, line, kind, name)` tuples of the Facts it came from, and its id stays `sha1(kind, pattern, path, line)[:8]`. A per-controller hit is anchored on the controller class line, not the first action, so adding an action does not change the id and break a `Dismissed` row. The two passes never emit the same pattern; `hardcoded-production-mode` is found in text and kept only when `from_facts` confirms the project's output type.
2. **Not every candidate obliges.** C12 (item 2 above) applies only to patterns in `smells.OBLIGING`. Every other smell is printed in the Facts summary as "candidate (not an obligation)" and C12 never fails on it. `smells.pattern_class` names each pattern `deterministic` (a read of a declared value), `heuristic` or `summary-only`.
3. **Deterministic reads oblige from the release that ships them:** `machinekey-in-config`, `named-user-access-rule`, `duplicate-config-key`, `debug-setting-in-nondebug-config`, `identifier-list-in-config`. They are reads, not guesses, so the precision rule of item 5 does not gate them.
4. **A heuristic obliges only through a labelled set.** The set is `eval/labels/<pattern>.json`: hand-labelled sites, at least five positives and three negatives, including the false-positive shapes seen in the spike. `eval/smell_precision.py` runs both passes, reads the labels and prints precision. **No heuristic obliges until a second labeller exists** (`second_labeller` in the file names someone other than the author; a set labelled by the author alone does not count) **and precision is at least 0.8.** Until then it stays a candidate. `tools/release.py` prints class, hits, precision and obligation status per pattern and refuses a release in which an obliging pattern breaks the rule. This replaces the "precision run on real Targets" wording of item 5 for new patterns, because a pattern that occurs one to three times per Target cannot reach a hit threshold and a public classic-MVC example does not exist; the corpus Targets enter measurement only through the labelled set, which carries negatives.
5. **Seven 2.7 patterns are grandfathered.** `logger-type-mismatch`, `flash-without-redirect`, `distinct-auth-errors`, `unescaped-template-output`, `state-change-on-get`, `actuator-exposed` and `hardcoded-credential-constant` (`smells.GRANDFATHERED`) keep their obligation without a labelled set, so a document that passed C12 on 2.7 does not fail it on 2.8. They are heuristics and are listed as such. A change to one of them ships as a new pattern with a new id, never as an edit.
6. **The 2.8 heuristics are summary-only.** `handler-without-guard`, `state-change-authenticated-only`, `post-without-antiforgery`, `deref-before-null-check`, `deref-in-null-branch`, `dead-null-fallback` and `hardcoded-production-mode` have author-labelled sets on invented code and no second labeller, so none obliges in 2.8.0. `config-year-horizon` and the debug-in-Debug patterns are summary-only by class.
7. **Detector accountability.** The Facts summary prints "none" for the patterns of a Stack whose detector ran and found nothing, so an empty list is not read as an unrun detector.

Consequences: C12 cannot fail on a pattern nobody has measured, so the Check stays something a writer can satisfy; the cost is that a real heuristic hit is only a prompt until its labelled set is re-labelled. A reader should treat "candidate (not an obligation)" as a prompt, as item 1 above says of all candidates.
