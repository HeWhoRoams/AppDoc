# ADR 0017: Counts are markers, limitations are notes, and the template gate is strict

- **Status:** Accepted (2026-11-23, 2.7.0)
- **Decision area:** Check (C3, C15, C17, C18); Generated blocks; Audit; Template 2.7; `appdoc upgrade`
- **Builds on:** ADR 0016 (P1, P2), ADR 0005 (generated blocks), ADR 0006 (template spec)

## Context

Three kinds of hand-written prose kept contradicting what the tool knew.

- **Counts.** A sentence such as "11 of 14 findings" was checked by reading English. The 2.5 C15 matched "N of M <noun>" against the register, so it depended on wording and still missed counts it could not parse.
- **Limitations of generated blocks.** A writer noted next to a block "the extractor does not see X". The next regeneration changed the block and the note became false. Nothing tied the note to the text it described.
- **Older templates.** The 2.4 template stayed accepted beside 2.7 through a window, so a document could pass a Check written for a template it did not follow.

## Decision

1. **Count markers.** A writer states a count only as `<!-- appdoc:count CLASS -->N<!-- /appdoc:count -->`; `fill` writes `N` and the marker stays. `CLASS` is a closed list held in one constant (`template_spec.COUNT_CLASSES`): the defined IDs `V F UI C X Q R`, the register's `rows` (live) and `superseded`, and the Facts' `routes jobs pages commands config-keys`. The syntax is fixed so later releases only add classes. C15 on a 2.7 document fails a marker whose number `fill` would not write, and fails an unknown class.
2. **The R2 exception.** R2 says the Check is never weakened. On 2.7 a hand-written "N of M <noun>" stops failing and becomes an **advisory** ("use a count marker"), listed in `check-report.md` and never failing. This is a recorded exception, not a loosening: the English rule is replaced by a stricter structural one (a stale number cannot survive `fill`), and the advisory still lists every hand-written count with its line. A document on an older stamp keeps the old failing C15.
3. **Notes about generated blocks are data.** `docs/appdoc/notes.jsonl` holds `{block, text, cites, block_sha}`. `fill` prints each note inside its block as `Known extractor limitation: <text> (<cites>)`; `build` fills an empty `block_sha` with the hash of the block's generated body (notes excluded) and never overwrites one. C18 fails a note for an unknown block, for a `block_sha` that no longer matches the block (the block changed after the note was written), and for a note Citation that does not resolve; it also fails the reserved label in hand-written Narrative, which belongs in `notes.jsonl`.
4. **Notes live in blocks the audit does not cover.** Generated and opaque blocks are not audited (the audit plan skips them; SKILL.md and the audit-plan module say so). A note inside one is validated by C18's hash and Citation checks, not by an audit row, so it needs no register row and the seal never depends on it.
5. **Computed scope.** A.1 prints the coverage line from the register and the audit plan. The line-1 `scope` describes the method only and C17 fails an ID token or a digit sequence in it; per-section caveats go in `exclusions` (`{"<section>": "<reason>"}`, same token rule), printed verbatim.
6. **Strict C3 with `appdoc upgrade`, not an older-stamp window.** C3 requires the stamp to equal the running template. A 2.4 document fails C3 on 2.7 and is brought forward once with `appdoc upgrade <target>` (the steps are `template_spec.UPGRADE_STEPS`, machine-readable). The command only adds or renames, keeps every line of text (what it cannot place sits under an `appdoc:upgrade-orphan` comment that C3 fails), never writes `evidence.jsonl`, `notes.jsonl` or `audit-plan.json`, and writes `UPGRADE-TODO.md` listing what a person must do, each with the Check rule that fails until it is done. The older-stamp window that 2.7 first shipped as a stopgap is removed.

## Consequences

- **Positive:** a number in prose cannot be stale after `fill`; a note cannot outlive the block text it describes; a passing Check on a 2.7 document means the template is the 2.7 template.
- **Negative:** writers lose free-form counts and must learn the marker; every 2.6 document pays a one-time upgrade (steps 1 to 8 of the 2.7 upgrade notes); the closed class list grows with each release that adds Facts worth counting (template 2.8 adds classes without changing the syntax). Hand-written "N of M" no longer breaks the build, so a team that ignores advisories keeps it.
- **Rejected:** accepting the old and new template side by side through a window (it let documents pass a Check they did not meet); making a stale note a warning (the failure of the 2.4 examples was a warning nobody read).
