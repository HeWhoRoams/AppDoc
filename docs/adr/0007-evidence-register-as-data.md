# ADR 0007: The Evidence Register is data, and the audit state is always declared

- **Status:** Accepted (2026-11-11)
- **Decision area:** Source-to-claim audit; Check; Render

## Context

In 2.1 the audit lived in `verification.md`, free Markdown written by the same AI that wrote the
document. In the four examples its summary counts disagreed with its own table, its Corrections
read as a changelog, a hand-escaped re-run command was broken, and large parts of the document had
no row. It was never secret-scanned, though `render` published it. A missing file was "a noted
gap", so deleting the audit was the easy way to pass.

## Decision

1. The register is JSON Lines: `docs/appdoc/evidence.jsonl`. Line 1 is the audit record
   (`performed`, `auditor`: `independent` or `same-session`, `scope`). Each other line is one claim:
   `id`, `ref` (a heading number, optionally with a document ID: `10.1/V-2`, `7.3`), `claim`,
   `result` (Supported, Corrected, Downgraded), `cites`, `anchor`, `limitation`.
2. **C11** fails when the file is missing, a row is malformed, an ID repeats, a result is not
   allowed, a ref or Citation does not resolve, a 10.1 finding or a workflow has no row, or a row's
   **anchor** (a literal string copied from the cited lines) is not found in those lines after
   whitespace normalization. This is the one accuracy control the Check adds: it turns "the
   citation resolves" into "the cited lines contain what the row says", and in CI it names which
   audited claims a code change made stale.
3. Coverage beyond the mandatory rows is reported per section, not failed; a per-section quota
   produces filler rows.
4. The audit state is always declared. `{"type": "audit", "performed": false, "scope": "<why>"}` is
   allowed and shows as a banner at the top of the HTML; `check --require-audit` makes it a failure
   for CI. A silent absence fails.
5. `render` builds Appendix A from the register: counts, coverage, the table and a literal
   re-check recipe. Nothing in it is hand-written, so there is no summary line to drift and no
   free-text Corrections section.
6. Independence is defined by inputs: the auditor receives the document and the Target, not the
   writer's notes. Without sub-agents, a new session does the audit; the record says which.
7. C6 scans every published file, including the register.

## Consequences

- Supersedes the 2.1 `verification.md` format; 2.1 documents must convert (CHANGELOG upgrade notes).
- An anchor shows the cited lines still contain the evidence; it does not prove the claim's
  wording is right. That judgment stays with the auditor.

## Amendment (2026-11-13): exact single-line match, and the register knows which text it audited

The 2.3 anchor check matched after whitespace normalisation and across joined lines, while the
verification command a reader ran matched one raw line case-sensitively — so a row could pass the
Check yet print a command that found nothing. The Check and the command now share one rule, and the
register records the text it was audited against.

1. **Exact single-line match.** `register.locate(root, row)` resolves each cite the way C11 does,
   reads the cited lines raw, and returns the first line that contains the anchor exactly and
   case-sensitively. C11 uses it for `Supported` and `Corrected` rows; `None` fails with the
   specific reason (not found; found only across lines or after whitespace normalisation; cited
   file is binary; anchor not ASCII and the file not UTF-8; anchor holds a code-fence marker). The
   A.4 verification commands are printed from that same location, so the command a reader runs is
   the line the Check verified.
2. **`claim_sha` sealing.** A row may carry `claim_sha`: 12 hex characters of SHA-1 over the
   normalised text its `ref` points to (the table row that defines an ID, the workflow subsection,
   or the section with generated blocks masked; comments stripped, whitespace collapsed).
   `appdoc seal` (the first step of `build`) writes it into every row that lacks one and never
   overwrites one; to re-audit, the auditor rewrites the row without the key. C11 adds: an ID or
   workflow row with no `claim_sha` → "not sealed; run `appdoc build`"; a `claim_sha` that differs
   from the document → "the text of 10.1/V-4 changed after it was audited; re-audit it and replace
   the row"; two rows for the same ID ref → "keep the row that describes the current text".
   `Dismissed` and `Answerable` rows are exempt (a smell id already encodes path and line).

## Amendment (2026-11-23, 2.7.0): rows are superseded, not deleted, and a seal says who vouched for it

Decisions 1 and 2 of the 2.4 amendment ("two rows for the same ID ref", "`appdoc seal` writes `claim_sha` into every row that lacks one") are changed as follows. ADR 0015 holds the reasoning.

1. **`supersedes`.** A row may carry `supersedes` (an `E-<n>` or a list naming older rows of the same `ref`). A row that no later row supersedes is **live**. The duplicate-ref rule now counts live rows only; the message becomes `add "supersedes": "<older id>" to the newer row; do not delete the older row`. Seals, anchors, `locate`, coverage and the readers of C11, C12 and C14 use live rows. A superseded row keeps full validation of id, ref, result and Citations.
2. **`sealed_by`.** Each `claim_sha` that `seal` writes comes with `sealed_by`: `"audit"` or `"upgrade"`. `appdoc seal --audit --date YYYY-MM-DD` writes the audit provenance on line 1 and seals unsealed rows `"audit"`; a plain `seal` or `build` seals `"audit"` only when the audit record's `doc_sha` equals the document's current fingerprint and `"upgrade"` otherwise. `claim_sha` is still never overwritten, and a row is still re-audited by writing a new row (now with `supersedes`, not by removing the old one).
3. **Audit record fields.** Line 1 gains `audited_on`, `audited_with`, `audited_bundle` and `doc_sha`, required on template 2.7 under `--require-audit`, and an `exclusions` object for declared gaps. The anchor and result rules above are unchanged, and `Answerable` rows on 2.7 carry `answered_in`.
