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
3. **The audit record (line 1) carries the provenance.** On template 2.7 it holds `audited_on` (the date given), `audited_with` (AppDoc version), `audited_bundle` (12-hex bundle hash, ADR 0013) and `doc_sha`: the 12-hex SHA-1 of the normalized Narrative with the **opaque** generated blocks (`template_spec.OPAQUE_BLOCKS`: entry-points, scheduled-jobs, closed-questions, appendix-a), count markers and comments masked. `doc_sha` uses the same masked text as the row seals, so `fill` never changes it. The non-opaque generated blocks (scan-coverage, config-reference) are **not** masked, on purpose: they are text the auditor reads and rows cite, and masking them would let their content change without invalidating an audit. The price is that a change to the Facts that alters one of them changes `doc_sha` and reseeds the audit sample (`test_core::test_audit_plan_changes_with_doc`); this is intended. Because they are read as Narrative, `seal` (plain and `--audit`) and `build` first fill them from the Facts, and the fingerprint is that of the filled document (S6.1).
4. **Appendix A prints the history.** A.1 prints `Audited on <date> with AppDoc <v> (bundle ...)` and, when any exist, `N rows were sealed at upgrade; their text was not re-audited.` A.2 shows total rows with the superseded count and lists missing E-IDs (which, under this ADR, only deleted rows leave). A.3 marks `superseded by E-n`; A.4 skips superseded rows.
5. **C17** needs the line-1 fields under `--require-audit`, and `--require-audit --strict` fails on any `sealed_by: "upgrade"` row. A document may ship with upgrade seals, but a pipeline can refuse it.

## Consequences

- **Positive:** a correction is visible and costs nothing; the Check cannot be satisfied by deleting evidence; a reader can tell a row an auditor read from a row a tool carried over; the examples' provenance lines are computed.
- **Negative:** the register only grows, and a long-lived document accumulates superseded rows (A.2 counts them so the growth is visible). An auditor must write `supersedes` correctly, or C11 fails until they do. A re-run of `build` after any edit to audited text turns new rows `"upgrade"`, which is deliberate: only `seal --audit` vouches for text.
- **Not decided here:** whether to prune superseded rows after a release. They stay; P4 allows no step that requires deleting them.

## Amendment (2.7.1, recorded after the 2.7.0 code review)

Three behaviours shipped in 2.7.0 without an entry here. They are accepted as implemented.

1. **Fill before seal (S6.1).** `seal` fills the non-opaque generated blocks from the Facts before it computes the fingerprint (`test_core::test_seal_audit_fingerprints_the_filled_document`). Without it, a stale block was filled after the seal, `doc_sha` moved, and rows were sealed `upgrade` against text the auditor had read. This is the mechanism that keeps `doc_sha` reproducible while those blocks stay unmasked (decision 3).
2. **Percent floor syntax.** `appdoc-context.md` may say `Audit floor: 40%, 8` as well as `0.4, 8`. A percent is divided by 100; the value must be above 0 and at most 1. An organization may only raise the default floor (25%, minimum 5); a lower value is ignored and reported as an advisory.
3. **The sample is a floor.** The audit plan names the least an auditor must cover. An auditor may cover more, and after any Narrative edit must cover every row of the sampled sections (4, 6, 8.1, 8.3, 9, 15), because the edit changes `doc_sha` and reseeds the sample. C19 still checks only that every planned ID has a live row.

## Amendment (2.7.1, per-row coverage and seal scope)

4. **Per-row keys.** The audit plan names one key per row for 10.2 (controls with Status Present), 16.5 and 17 (rows that are not Unknown or Not applicable) and the sampled section 9 rows: `<section>/<slug>`, the slug being the first cell (lower-cased, runs of non-alphanumerics to `-`, repeats suffixed `-2`, `-3` in row order). A row's register `ref` is its key, still one live row per ref, so C19 now enforces coverage per row, not per section. Renaming a first cell re-keys the row, which is a changed claim. A register that keeps one section-level row (`10.2`) stays valid for C11 but no longer satisfies C19; it counts as `extra` in A.2.
5. **What `seal` stamps.** `claim_sha` and `sealed_by` go on ID rows, workflow (7.x) rows and per-row keys (the claim is the table row). Other section-level rows, Answerable rows and Dismissed rows are never sealed, so they carry no `sealed_by`; C17 `--strict` fails only on `sealed_by: upgrade`, never on an absent key. Appendix A says so.
