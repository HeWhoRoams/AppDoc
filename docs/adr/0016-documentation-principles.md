# ADR 0016: Documentation principles P1–P6

- **Status:** Accepted (2026-11-13)
- **Decision area:** Facts; Generated blocks; Check; Evidence Register; Release

## Context

The 2.4 example audit (`AppDoc-v2.4-Examples-Audit-2026-11-13.md`) found that every structural Check passed while the published documents still carried false or stale statements. Examples:
- A generated block said a stack had "no entry-point capability" while listing its routes.
- A hand-written note described a table the regeneration had already changed.
- An audit scope said "V-1 to V-10" over fourteen findings.
- Correction rows were deleted to satisfy a duplicate rule.
- The CI gate could not run.
- The version string covered two different Checks.

The common cause is not any single rule. Prose was asked to restate things the tool already knew; the Check then had to parse English to verify them; history was mutable; provenance was mixed into content; and release facts were asserted by hand.

The goal is documentation that is accurate, consistent and robust by construction and relatively deterministic: the same Target, Narrative and register produce the same bytes on every run and OS, and pass/fail never depends on English wording.

## Decision

These six principles are binding review criteria for every AppDoc change, plan item and template revision. An item that violates one is rejected or carries a recorded exception in its plan's decision log.

1. **P1: If the tool can know it, the tool writes it.** Counts, coverage, audit scope, provenance, closed questions and limitations of generated blocks are generated output. A writer may state a count only through a generated count marker (`<!-- appdoc:count V -->14<!-- /appdoc:count -->`), filled by `fill` from a closed list of count types.
2. **P2: Hand-written text references evidence only through handles.** A handle is an ID, a Citation, a block name, a count marker or a reserved label. The Check validates handles exactly and never passes or fails a document on English wording. Lints that read English (quantifiers, hand-written "N of M") are advisory and can fail only under `--strict`.
3. **P3: Every artifact is a pure function of its inputs.** No clock, PID, environment variable (except documented switches), locale or absolute path reaches an artifact. Every hash goes through one text normalization. Runs are byte-identical across repeats, locations, file-creation order and Windows/Linux, and tests prove it.
4. **P4: History is append-only.** No step may require deleting an audit row, a Fact or a finding in order to pass. Superseded records stay and are marked (`supersedes`).
5. **P5: Provenance is separate and printed.** What produced an artifact (AppDoc version, bundle hash, schema, template) lives in `provenance.json` beside it and is printed for readers. It is never part of the content that change detection diffs. `facts.json` is a pure function of the Target.
6. **P6: Release facts are generated and tested.** Version, CHANGELOG heading, gate pin, schema, rule list and command list are generated from code into marked blocks of AppDoc's own docs. A test fails when regeneration would change them, and releases are cut by `tools/release.py`, which refuses inconsistency.

Supporting rules R10–R15 (append-only history, provenance printed, release facts tested, no ambient inputs, one normalization, deterministic tie-breaks) apply alongside R1–R9.

## Consequences

- **Positive:** a passing Check means the hand-written parts agree with data the tool owns. Change detection blames code only for code changes. Two runs can be compared byte for byte. The audit record shows its own history.
- **Negative:** writers lose some freedom: counts go through markers, notes about generated blocks go in `notes.jsonl`, and audit scope prose is limited to the method. Some English-matching rules planned in 2.5 (C15) become advisory instead of failing.
- **Applied in:** `docs/remediation-plan-2.6.md` (2.6.0, tooling and Facts) and `docs/remediation-plan-2.7.md` (2.7.0, template). Both carry a decision log (Q1–Q21, 2026-11-13). `docs/remediation-plan-2.5.md` (2.5.0) predates this ADR. Its C14 and C15 fail on template 2.4, which is a recorded exception; 2.7.0 replaces C15's English matching with count markers.
- **Supporting rules R10–R15** are defined in `docs/remediation-plan-2.6.md` and `-2.7.md`.
