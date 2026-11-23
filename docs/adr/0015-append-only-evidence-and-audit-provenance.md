# ADR 0015: The register is append-only, and every seal says who vouched for it

- **Status:** Accepted (2026-11-23, 2.7.0)
- **Decision area:** Evidence Register; Check; Audit; Template 2.7
- **Builds on:** ADR 0007 (register as data, `claim_sha`), ADR 0016 (P4 append-only history, P5 provenance)

## Context

ADR 0007 made the audit data and sealed each row with `claim_sha`. Two defects remained, both found in the 2.4 example audit.

1. **Correcting a row meant deleting it.** C11 failed two rows on one ref ("keep the row that describes the current text"), so the quickest way to pass was to delete the older row. The correction history was lost, and Appendix A showed an audit that had never been wrong.
2. **A seal did not say what it certified.** `seal` wrote `claim_sha` into any row that lacked one, against whatever text the document held at that moment. After an upgrade or a hand edit, rows were sealed against text nobody had re-audited, and nothing in the register told the two cases apart.

## Decision

1. **Rows are never deleted; a newer row `supersedes` an older one.** A row may carry `supersedes` (an `E-<n>` or a list). The target must exist, share the `ref`, and not form a cycle. A **live** row is one no other row supersedes. C11's duplicate-ref rule, seals, anchors, `locate`, coverage, C12, C14 and the check-report Verification read live rows only. Superseded rows keep full validation of id, ref, result and Citations, so a bad Citation in history still fails. Two live rows on one ref fail with `add "supersedes": "<older id>" to the newer row; do not delete the older row`. There is no `register merge`; a deleted row is restored from git history and marked superseded.
2. **Every seal records its provenance.** A row sealed by `claim_sha` also carries `sealed_by`: `"audit"` or `"upgrade"`.
   - `appdoc seal --audit --date YYYY-MM-DD` is the command that ends an audit. It writes the audit provenance on line 1 and seals the unsealed rows `"audit"`. `--date` is required and is never read from the clock (P3).
   - A plain `seal` (and so `build`) seals an unsealed row `"audit"` only when the audit record's `doc_sha` equals the document's current fingerprint, so the text is the text the auditor read. Otherwise it seals `"upgrade"`: the row exists, but the text was not re-audited.
3. **The audit record (line 1) carries the provenance.** On template 2.7 it holds `audited_on` (the date given), `audited_with` (AppDoc version), `audited_bundle` (12-hex bundle hash, ADR 0013) and `doc_sha`: the 12-hex SHA-1 of the normalized Narrative with generated blocks, count markers and comments masked. `doc_sha` uses the same masked text as the row seals, so `fill` never changes it.
4. **Appendix A prints the history.** A.1 prints `Audited on <date> with AppDoc <v> (bundle ...)` and, when any exist, `N rows were sealed at upgrade; their text was not re-audited.` A.2 shows total rows with the superseded count and lists missing E-IDs (which, under this ADR, only deleted rows leave). A.3 marks `superseded by E-n`; A.4 skips superseded rows.
5. **C17** needs the line-1 fields under `--require-audit`, and `--require-audit --strict` fails on any `sealed_by: "upgrade"` row. A document may ship with upgrade seals, but a pipeline can refuse it.

## Consequences

- **Positive:** a correction is visible and costs nothing; the Check cannot be satisfied by deleting evidence; a reader can tell a row an auditor read from a row a tool carried over; the examples' provenance lines are computed.
- **Negative:** the register only grows, and a long-lived document accumulates superseded rows (A.2 counts them so the growth is visible). An auditor must write `supersedes` correctly, or C11 fails until they do. A re-run of `build` after any edit to audited text turns new rows `"upgrade"`, which is deliberate: only `seal --audit` vouches for text.
- **Not decided here:** whether to prune superseded rows after a release. They stay; P4 allows no step that requires deleting them.
