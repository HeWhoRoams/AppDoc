# AppDoc v2.6.0 → v2.7.0 Remediation Plan: Template release

**Date:** 2026-11-13, rev 2 2026-11-23 (formerly drafted as `remediation-plan-2.6.md` revs 1–3; renumbered after 2.5.0 turned out to be in flight)
**Status:** Phase after next. Release sequence: 2.5.0 (`remediation-plan-2.5.md`, in flight, unchanged) → 2.6.0 (`remediation-plan-2.6.md`, tooling and Facts) → **2.7.0 (this plan, template)**.
**Basis:**
- the 2.4 example audit (`AppDoc-v2.4-Examples-Audit-2026-11-13.md`, AppDoc project);
- a line-level read of `appdoc/` at `db2589e`;
- ADR 0016 (principles P1–P6, binding);
- `docs/remediation-plan-2.6.md` (2.6.0, which must ship first).

**What 2.7.0 is:** the single release that changes what a document must contain. It brings:
- template **2.7**;
- the evidence and audit model (append-only register, audit provenance, a tool-selected audit plan);
- prose that refers to evidence only through handles (count markers, notes as data, computed scope, closed questions);
- rules enforced on stamp 2.7 that 2.6.0 already previewed as advisories;
- §17.

Users upgrade each document once, and the examples get a fresh run and a fresh audit once.

**Not in this plan:**
- everything 2.5.0 ships: C14, C15 (English matching, failing), C16, the owner advisory, env/CI config roles, extractor coverage;
- everything 2.6.0 ships: tags, the provenance sidecar and `version_tuple`, the determinism harness, capabilities, duplicate folders and pruning, config and secret naming, `appdoc gate`, generated AppDoc docs, the release script, answer keys, example rotation, C20, and previews of the rules below.

**Format:** house convention. Every item has a failing test (TDD), a corpus case where a Target is needed, and a "why this is not a weakening" line.

---

## Status and amendments (rev 2, 2026-11-23)

**Not started**, and it cannot start until 2.5.0 (partly done; see its status table) and 2.6.0 (not started) ship. Amendments:

| # | Amendment |
|---|---|
| **C-1 Name collision** | The rows "Q5 eShop chatbot PII flow" and "Q6 No 'how to run it' section" in §2 and §7 are **audit questions**, not decisions, and they reuse the numbers of decisions Q5 and Q6 in §1 (2.6 uses them too). Rename them **AQ5** and **AQ6** everywhere in this plan. |
| **C-2 Block registry** | The `closed-questions` block (§3.8) is added to `template_spec.OPAQUE_BLOCKS` as well as `GENERATED` (key `"14"`), so that `doc_sha`, the seals (`_claim_sha`) and the audit plan mask it like the other generated blocks. 2.8 adds five more blocks the same way and needs each to be opaque; a block that is not opaque makes a sealed register row fail C11 when its content changes between releases. Test: `test_check::test_closed_questions_is_opaque`. |
| **C-3 Count-marker classes** | The closed `CLASS` list in §3.5 is extended in 2.8 (areas, state-changing handlers by label, access rules, role constants, guard shapes, secret-location files, configurations; 2.9 adds CI jobs and test suites). Implement the list as one constant in `template_spec` so 2.8 adds to it without changing the marker syntax. |
| **C-4 Audit plan scope** | §3.4 samples sections 4, 6, 8.1, 8.3, 9 and 15 and covers 10.1, 7, 14, smells, 10.2, 16.5 and §17 fully. Generated and opaque blocks (including 2.8's access model in template §5.4) are **not audited**; say so in the A.1 line and in SKILL.md, so the omission is stated rather than assumed. |
| **C-5 `appdoc upgrade` (proposed; decision Q23, take before 2.7 starts)** | 2.7 is the release that makes every committed document change template once, and it has no tool for it. §5.1's eight steps are mostly mechanical. If Q23 is accepted, add **§3.11** below (about 2 d, taking the total to about 8.5 d). If not, 2.8 carries it (its W15). |
| **C-6 Schema** | §5.1's "schema stays `/7`" depends on 2.6 landing at `/7` (2.5 `/6`, 2.6 `/7`). 2.8 therefore writes its schema as "the next after 2.7's" and re-checks at its start. |
| **C-7 Rules** | C21–C23 are free after C17–C20 and are reserved for 2.8 (mandatory inputs, area and protection coverage, unknowns the repository may answer). C20 stays advisory. |

### 3.11 `appdoc upgrade <target>` (proposed, pending Q23)

1. Add `template_spec.UPGRADE_STEPS[version]`, a **machine-readable** list of operations for each template version: add block markers at a given `GENERATED` position, add headings with `appdoc:guide` comments, add required-row skeletons with `Unknown - see Open questions.`, rename table headers. Today `UPGRADE_NOTES` is prose and cannot be applied. 2.7 supplies the 2.4 to 2.7 steps (stamp, `closed-questions` markers, §17 skeleton, the 2.2 to 2.4 header renames and block markers); 2.8 adds its own.
2. A document with no stamp is treated as 2.1 when it has the 2.1 subsections (4.1, 5.1–5.3, 8.4, 8.5, 10.1/10.2, 15.1, 16.1–16.5), otherwise as 2.0.
3. After the mechanical steps it re-runs `extract` and `fill` and writes `docs/appdoc/UPGRADE-TODO.md` listing the non-mechanical steps (convert `verification.md` to `evidence.jsonl`, write register rows for new finding candidates, replace hand-written counts with markers), each with the Check rule that fails until it is done.
4. It never deletes Narrative (unmappable text goes under an `appdoc:upgrade-orphan` comment that C3 fails on) and never writes `evidence.jsonl`, `notes.jsonl` or `audit-plan.json` (P4). It does not convert `verification.md` automatically (the register needs source anchors).

**Tests:** `test_core::test_upgrade_2_1_to_current_mechanical`, `::test_upgrade_2_0_adds_2_1_subsections`, `::test_upgrade_idempotent`, `::test_upgrade_never_drops_text`, `::test_upgrade_never_touches_register`, `::test_upgrade_todo_lists_failing_rules`, `::test_upgrade_step_table_covers_every_version`. Corpus `upgrade-2-1`, and `upgrade-2-6-to-2-7` replaces the hand-run §5.1 corpus test.

---

## 1. Decision log (2026-11-13)

| Q | Decision | Effect here |
|---|---|---|
| Q1 | P1–P6 binding (ADR 0016) | All items |
| Q2 / Q12 | Hand-written counts use paired markers `<!-- appdoc:count V -->14<!-- /appdoc:count -->`; English "N of M" stays advisory | §3.5 (C15) |
| Q3 / Q11 | Tooling + Facts first, then one template release (amended: 2.6.0 tooling, 2.7.0 template, because 2.5.0 was in flight) | This plan |
| Q7 | The audit sample is tool-selected | §3.4 (C19) |
| Q8 | `build --expand-citations` is opt-in | §3.7 |
| Q9 / Q17 | §17 Build, Run and Test Locally; rows hold a command, Unknown, or "Not applicable" plus a citation | §3.9 |
| Q13 | Notes about generated blocks live in `notes.jsonl` | §3.2 (C18) |
| Q14 | Audit floor: 25% of IDs (at least 5, never more than the section has); full coverage of key sections; organizations may only raise it | §3.4 |
| Q15 | No `register merge`; the upgrade notes cover restoring deleted rows | §3.1, §5.1 |
| Q16 / Q18 / Q20 | Rotation: 2.6.0 moves to `previous`; 2.7.0 becomes `current` with a fresh run and a fresh audit | §5.2 |
| Q19 | Rules previewed in 2.6.0 become failures on stamp 2.7 | §3.3, §3.6, §3.7 |

---

## 2. Findings addressed in 2.7.0

| ID | Finding | Item |
|---|---|---|
| MAJ-01 | Stale "Known extractor limitation" notes contradict regenerated blocks | 3.2 |
| MAJ-04 | Superseded register rows deleted, so correction history is lost | 3.1 |
| NEW-04 | `seal` certifies pre-existing rows against text no one re-audited | 3.1 |
| MAJ-05 | Audit-scope prose contradicts the register | 3.3 |
| MAJ-09 | Audit depth thin and auditor-selected | 3.4 |
| MAJ-10 | §10.1 not ordered by severity | 3.6 |
| MIN-01 | Bare-name citations | 3.7 |
| MIN-03 | Audit vs generated-block provenance (2.6.0 prints blocks; 2.7 makes audit provenance required) | 3.1 |
| MIN-05 | Q-/E-ID gaps unexplained | 3.8 |
| F2 (diagnostic) | §14/register reconciliation uses live rows | 3.10 |
| F4 (diagnostic) | Stale hand-written counts | 3.5 |
| AQ5 | eShop chatbot PII flow | 5.2 |
| AQ6 | No "how to run it" section | 3.9 |

---

## 3. Template 2.7 items

**Gating:** each rule below fails when the **document's** stamp is ≥ (2, 7) through `template_spec.version_tuple` (shipped in 2.6.0). The C3 rule that the stamp equals the running template is unchanged, so every 2.6 document must upgrade once (§5.1).

### 3.1 Append-only register with audit provenance (P4/P5 → MAJ-04, NEW-04, MIN-03)

1. **Row keys** (`register.OPTIONAL_KEYS`): `supersedes` (`E-<n>` or a list) and `sealed_by` (`"audit"` | `"upgrade"`).
2. **Audit record (line 1)**, required on 2.7:
   - `audited_on` (`YYYY-MM-DD`, supplied explicitly);
   - `audited_with` (version);
   - `audited_bundle` (12-hex);
   - `doc_sha`: 12-hex SHA-1 of `normalize_text(Narrative with the opaque generated blocks and count markers masked, comments stripped)`, the same text C11 uses. **Only the opaque blocks** (`template_spec.OPAQUE_BLOCKS`: `entry-points`, `scheduled-jobs`, `closed-questions`, `appendix-a`) are masked. `scan-coverage` and `config-reference` are not opaque: they are text the auditor reads and register rows cite, so a change to them changes `doc_sha` (decision D3 of the 2.7.1 plan). A Facts change therefore reseeds the audit sample by design (`test_core::test_audit_plan_changes_with_doc`). Fill-before-seal (S6.1, see "Changes made during implementation") is what keeps the fingerprint reproducible.
3. **C11 superseding:**
   - The duplicate-ref rule (`check.py:731-735`) counts **live** rows only. Two live rows on one ref fail with `add "supersedes": "<older id>" to the newer row; do not delete the older row`.
   - A `supersedes` target must exist, share the `ref`, and not form a cycle.
   - Seals, anchors, `locate` and coverage use live rows.
   - Superseded rows keep full validation of id, ref, result and cites.
4. **Seal provenance:**
   - `appdoc seal --audit --date YYYY-MM-DD` (`--date` required; R13) writes the line-1 provenance and seals unsealed rows `sealed_by: "audit"`.
   - Plain `seal`/`build` seals unsealed rows `"audit"` only when `doc_sha` matches the current fingerprint; otherwise it seals them `"upgrade"`.
5. **Appendix A** (generated):
   - A.1 adds `Audited on <date> with AppDoc <v> (bundle …).` next to the 2.6.0 blocks line.
   - A.1 adds `N rows were sealed at upgrade; their text was not re-audited.` when any exist.
   - A.2 shows `{total} rows ({superseded} superseded). Current: … As first audited: …`.
   - A.3 marks `superseded by E-n`; A.4 skips superseded rows.
6. **C17 (provenance):**
   - `--require-audit` needs the line-1 fields.
   - `--require-audit --strict` fails on any `sealed_by: "upgrade"` row.
7. ADR 0015 "Append-only evidence and audit provenance"; amend 0007.

**Why this is not a weakening:** it adds required provenance and removes the only way to pass by deleting evidence.

**Tests:**
- `test_register`: `::test_supersedes_parsed`, `::test_superseded_rows_counted_separately`, `::test_a3_marks_superseded`, `::test_a4_skips_superseded`, `::test_a1_audit_provenance_line`, `::test_a1_upgrade_sealed_note`.
- `test_check`: `::test_c11_two_live_rows_fail_with_supersedes_fix`, `::test_c11_supersedes_unknown_or_cycle_fails`, `::test_c17_require_audit_needs_provenance`, `::test_c17_strict_fails_on_upgrade_seal`.
- `test_core`: `::test_seal_audit_requires_date`, `::test_seal_marks_upgrade_without_matching_doc_sha`.

Corpus `superseded`, `upgrade-seal`.

### 3.2 Notes about generated blocks are data (P1/P2 → MAJ-01; Q13)

1. **`docs/appdoc/notes.jsonl`**, one line per note: `{"block", "text", "cites", "block_sha"}`.
2. **`fill` renders notes inside their block**, after the generated rows: `Known extractor limitation: <text> (<cites>)`.
3. **`build`** fills an empty `block_sha` with the hash of the block's generated body (notes excluded) and never overwrites an existing one.
4. **C18 "Notes match their block":**
   - an unknown block fails;
   - a `block_sha` that differs from the current body fails: `the <block> block changed after this note was written; re-read the block, rewrite or delete the note, and clear block_sha`;
   - note cites must resolve (C1);
   - the reserved label `Known extractor limitation:` in hand-written Narrative outside a block fails: `move this note to notes.jsonl`.
5. ADR 0017 "Generated limitations, computed scope and counts".

**Tests:** `test_fill::test_notes_rendered_in_block`; `test_check::test_c18_stale_note_fails`, `::test_c18_unknown_block_fails`, `::test_c18_label_in_prose_fails`, `::test_c18_build_seals_empty_sha`; `test_determinism::test_notes_seal_idempotent`. Corpus `note-stale`, `label-in-prose`.

### 3.3 Audit scope is computed (P1/P2 → MAJ-05)

1. **A.1 prints a computed coverage line** from `coverage(...)` and the audit plan (3.4): `Register rows cover: 10.1 V-1–V-14 (14 of 14) · workflows 7.1–7.10 (10 of 10) · …`.
2. **C17 (scope):** the line-1 `scope` may not contain an ID token (`_ID_REF_RE`) or any digit. The check is `re.search(r"\d", scope)`, so a single digit (for example `2.7` or `10`) fails, not only a digit sequence; the same rule applies to each `exclusions` reason. Accepted as implemented (2.7.1 decision, review finding S-c3): a scope that names a number is a coverage claim, and coverage is computed. Fix: `describe only the method; coverage is computed`. This was previewed in 2.6.0.
3. **`exclusions`:** `{"<section>": "<reason>"}`. Keys are section refs; values follow the same token rule; each is printed verbatim in A.1.

**Tests:** `test_check::test_c17_scope_ids_fail`, `::test_c17_scope_digits_fail`, `::test_c17_method_only_passes`, `::test_c17_exclusions_keys_are_sections`; `test_register::test_a1_computed_scope_line`. Corpus `scope-ids`.

### 3.4 Tool-selected audit plan and floor (MAJ-09; Q7, Q14)

1. **`appdoc audit-plan <target>`** writes `docs/appdoc/audit-plan.json`, a pure function of the Narrative:
   - **Full coverage:** every 10.1 V-ID, every §7 workflow, every §14 Q-ID, every finding candidate, every 10.2 control marked Present, every 16.5 and §17 row that is not Unknown/Not applicable.
   - **Sampled sections** (4, 6, 8.1, 8.3, 9, 15): `k = min(n, max(5, ceil(0.25 * n)))`, chosen by sorting IDs on `sha1(doc_sha + id)`.
   - **Organization override:** `appdoc-context.md` line `Audit floor: <fraction>, <minimum>` is applied only when stricter than both defaults. The fraction is a decimal or a percent (`0.4, 8` and `40%, 8` are the same floor; see "Changes made during implementation"). A looser value is ignored and reported as an advisory.
2. **C19 "Audit follows the plan"** (stamp 2.7, `--require-audit`):
   - `audit-plan.json` must equal a fresh computation;
   - every planned ID has a live row;
   - exclusions are printed.
3. A.2 shows `planned / audited / extra` per section.
4. **SKILL.md audit step:** run `audit-plan`, audit every planned ID (more if useful), then `seal --audit --date …`.

**Tests:** `test_core::test_audit_plan_deterministic`, `::test_audit_plan_changes_with_doc`, `::test_audit_plan_floor_math`, `::test_audit_floor_override_only_raises`; `test_check::test_c19_missing_planned_row_fails`, `::test_c19_stale_plan_fails`, `::test_c19_exclusion_printed`. Corpus `audit-plan`.

### 3.5 Count markers (P1 → diagnostic F4; Q2, Q12)

1. **Syntax:** `<!-- appdoc:count CLASS -->N<!-- /appdoc:count -->`, where `CLASS` comes from a closed set:
   - `V F UI C X Q R` (defined IDs);
   - `rows superseded` (register);
   - `routes jobs pages commands config-keys` (Facts, through `fill.entry_point_counts` and the config reference, R5).
2. **`fill`** writes `N`; the marker stays.
3. **C15 (enforced on 2.7; replaces the English-matching C15 that 2.5.0 ships as a failure):**
   - a marker whose `N` is stale fails;
   - an unknown `CLASS` fails;
   - hand-written `N of M <noun>` becomes an **advisory**: `use a count marker`. This is a recorded exception to R2 (never weaken the Check): a stronger structural rule replaces the English one, per P2 and Q2.
4. `test_determinism`: `fill` is idempotent with markers present.

**Tests:** `test_fill::test_count_marker_filled`, `::test_count_marker_idempotent`; `test_check::test_c15_stale_marker_fails`, `::test_c15_unknown_class_fails`, `::test_c15_handwritten_count_advisory`.

### 3.6 Severity order (MAJ-10)

`template_spec.SEVERITY_ORDER = ("Critical", "High", "Medium", "Low")`. C9 fails a §10.1 or §15 row that outranks the previous row: `move the row; keep its ID`. This was previewed in 2.6.0.

**Tests:** `test_check::test_c9_10_1_severity_order`, `::test_c9_15_severity_order`. Corpus `severity-order`.

### 3.7 Full-path citations (MIN-01; Q8)

1. **C1:** a bare name that resolves to a non-root file outside `KNOWN_BARE_FILES` fails, and the fix text prints the unique full path. The same rule applies to register and note cites. This was previewed in 2.6.0.
2. **`appdoc build --expand-citations`** (opt-in) rewrites those spans outside fences and generated blocks. It is deterministic and idempotent.

**Tests:** `test_check::test_c1_bare_name_fails_on_2_7`, `::test_c1_root_and_known_bare_allowed`; `test_core::test_expand_citations_unique_only`, `::test_expand_citations_idempotent`. Corpus `bare-cite`.

### 3.8 Closed questions block (MIN-05)

1. Answerable rows require `answered_in` (a section ref).
2. New generated block **`closed-questions`** under the §14 table: `Closed by the audit and answered in the body: Q-11 (16.3), …` or `No questions were closed by the audit.`
3. A.2 lists missing E-IDs. Under 3.1 these occur only if rows were deleted.

**Tests:** `test_fill::test_closed_questions_block`; `test_check::test_c11_answerable_needs_answered_in`; `test_register::test_a2_lists_missing_ids`.

### 3.9 §17 Build, Run and Test Locally (Q6 → Q9, Q17)

```
## 17. Build, Run and Test Locally
<!-- appdoc:guide Fed by: build files, runtime pins, README, CI steps. Every command cited where it is defined.
All five rows required (C9). Status values: a cited command; Unknown (the repository does not show it); Not applicable (cite the evidence, e.g. no project file). -->

| Step | Command | Working directory | Evidence |
|---|---|---|---|
| Prerequisites | | | |
| Restore dependencies | | | |
| Build | | | |
| Run | | | |
| Test | | | |
```

- `template_spec.SECTIONS` gains 17, and `REQUIRED_ROWS["17"]` lists the five steps.
- C9 accepts in the Command cell only:
  - a backticked command;
  - `Unknown - see Open questions.`;
  - `Not applicable`.
- Rows other than Unknown need a lined Citation in Evidence (C2 style).
- SKILL.md: "keep all 17 headings".
- The audit plan covers §17 fully.

**Tests:** `test_check::test_c9_section_17_rows`, `::test_c9_17_not_applicable_needs_citation`, `::test_template_2_7_sections`.

### 3.10 C14 (no change)

C14 already fails from 2.5.0 (shipped before Q19). It needs no change here beyond using the live-row definition from 3.1 when it reads the register.

**Tests:** `test_check::test_c14_uses_live_rows`.

---

## Changes made during implementation (2.7.0, recorded in 2.7.1)

The 2.7.0 code review (2026-11-24, review findings S-b1 to S-b6) found six additions that this plan did not list. Each came from a failure met while running the 2.7 audits, and each is accepted (decision D5 of the 2.7.1 plan). ADR 0015 carries the amendment for the three that touch audit semantics.

| # | Addition | Why it was added |
|---|---|---|
| 1 | **Section 3.7 C1 extensions** (`citations.py`): `go rs rb php kt kts proto tf tfvars` are Citation extensions, `mod` and `sum` are line-only, `go.mod go.sum go.work go.work.sum` are Citations by exact name, and a bare `.ext` (such as `.proto`) without a line is prose naming a file type, not a file. `expand_bare` leaves fenced code and HTML comments alone. | The Go and protobuf examples cited files the C1 extension list did not know, and prose such as `.go` and `math.mod` was read as a Citation. |
| 2 | **`audit-plan --check`**: read-only; prints the planned IDs on disk and from a fresh computation; exit 0 when equal, 2 when the plan is stale or missing. | An auditor under a read-only mandate could not tell whether the plan was current without rewriting it. |
| 3 | **"Fix advisories" run step** (SKILL.md, before `audit-plan`): run `check --strict` and fix every advisory first. | The sample is seeded by `doc_sha`, so an advisory fix made after the plan reshuffled the sample and forced another audit pass. |
| 4 | **Auditors cover every row of a sampled section after any edit.** The sample is a floor, not a ceiling: an auditor may cover more, and after any Narrative edit must cover every row of sections 4, 6, 8.1, 8.3, 9 and 15, because the edit reseeds the sample. | A late edit changed which rows were planned, and a planned row had never been read. |
| 5 | **`Audit floor:` percent syntax**: `Audit floor: 40%, 8` is accepted as well as `0.4, 8`; the percent is divided by 100 and the result must be above 0 and at most 1. Only a stricter value than 25% / 5 applies; a looser one is an advisory (section 3.4). | Organizations write a floor as a percent; the decimal-only form was rejected silently. |
| 6 | **Section 6.1, fill before seal**: `seal` (plain and `--audit`) first fills the non-opaque generated blocks (`scan-coverage`, `config-reference`) from the Facts, so the fingerprint is that of the filled document. | A stale block was filled after the seal, so `doc_sha` changed and rows sealed `upgrade` against text the auditor had read (`test_core::test_seal_audit_fingerprints_the_filled_document`). |

Related decision recorded here (2.7.1, review finding S-c3): the C17 scope rule rejects any single digit, not only a digit sequence (section 3.3).

---

## 4. Documentation and ADRs

- **SKILL.md Run** (only the generated command block changes, through `gen_docs`):
  1. Extract.
  2. Orient.
  3. Write.
  4. Build until it passes.
  5. **Audit-plan.**
  6. Audit in a fresh agent covering every planned ID, then `seal --audit --date`.
  7. Build.
  8. Report.
- **SKILL.md writing rules:**
  - counts only through count markers;
  - limitations of generated blocks in `notes.jsonl`;
  - order §10.1 and §15 by severity;
  - cite full paths;
  - set `answered_in`;
  - never delete register rows (use `supersedes`);
  - keep the audit `scope` to the method;
  - fill §17.
- **Template CONVENTIONS:** handles (IDs, Citations, count markers, notes, reserved labels) and the §17 status values.
- **CONTEXT.md:** Superseded row, Seal provenance, Note, Audit plan, Count marker.
- **ADRs:**
  - 0015 Append-only evidence and audit provenance;
  - 0017 Generated limitations, computed scope and counts;
  - amend 0007.

---

## 5. Release

### 5.1 Versions and upgrade notes

- `TEMPLATE_VERSION = "2.7"`.
- `facts.SCHEMA` stays `appdoc-facts/7` unless a 2.7 item changes Facts output. None is planned; `audit-plan.json`, `notes.jsonl` and register keys are separate files. If one does, bump to `/8` (R6).

**Upgrade 2.6 → 2.7:** a 2.6 document fails C3 until step 1.
1. Change the stamp to 2.7, add the `closed-questions` markers under §14, and add §17.
2. Move any "Known extractor limitation" paragraphs to `notes.jsonl`.
3. Replace hand-written counts with count markers. C15 advisories list them.
4. Shorten the audit `scope` to the method; move per-section caveats to `exclusions`.
5. `build --expand-citations`.
6. Fix what the Check lists: severity order, `answered_in`, §17 rows, two live rows on one ref. If rows were deleted under 2.4, restore them from git history and add `supersedes` (Q15).
7. `audit-plan`; audit the planned IDs; `seal --audit --date`.
8. `build`.

A corpus test (`upgrade-2-6-to-2-7`) runs exactly these steps on a 2.6 fixture.

### 5.2 Examples: fresh run and rotation (Q16, Q18, Q20)

1. `tools/release.py 2.7.0` rotates: `examples/current` (2.6.0) moves to `previous`, and the new run becomes `current`.
2. **Fresh run, not an upgrade.** For each app, from a clean clone at the recorded commit:
   1. template 2.7, copied fresh;
   2. write the Narrative;
   3. `build` until it passes;
   4. `audit-plan`;
   5. an independent audit in a fresh agent;
   6. `seal --audit --date`;
   7. `build`.
3. **Content items:**
   - eShop: assess the chatbot `GetUserInfo` flow (name, address, email and phone sent to the model host) as a V-finding, or record it as a 10.2 control row "PII to third-party model host" (Q5).
   - gitea: say in 2.1 which copy of each duplicate pair is live.
   - flaskr and gitea: order §10.1 by severity.
4. **Determinism proof:** extract/fill/render twice on Windows and Linux; the hashes go in `docs/diagnostic-2.7.0-comparison.md`.
5. The diagnostic, generated from `current` vs `previous`, reports:
   - planned vs audited per section;
   - superseded and upgrade-sealed counts (expected 0 for a fresh run);
   - count markers;
   - bare names 0;
   - severity order;
   - the §17 fill rate;
   - narrative answer-key scores;
   - extractor precision and recall.

### 5.3 CHANGELOG and tag

Write `CHANGELOG 2.7.0`, then run `tools/release.py 2.7.0` (which runs tests, evals, rotation and the tag). Push the tag yourself.

---

## 6. Order and effort

```
3.1 register history + audit provenance + seal --audit                         1 d
3.2 notes.jsonl + C18 4 h · 3.3 computed scope + C17 3 h · 3.5 count markers 4 h  1.4 d
3.4 audit-plan + C19 + floor override                                          6 h
3.6 severity · 3.7 bare names + --expand-citations · 3.8 closed questions ·
3.10 C14 enforcement                                                           6 h
3.9 template 2.7 + §17 + C9                                                    4 h
docs, ADRs 0015/0017, upgrade corpus test                                      5 h
fresh regeneration of four examples + audits, diagnostic, release              2 d
                                                                    Total about 6.5 d
```

**Order:**
1. 3.1, because `doc_sha` and the seal are used by 3.2–3.5.
2. 3.5 and 3.2. They share the masked-text helper.
3. 3.3 and 3.4. The computed coverage feeds the plan.
4. The rule items.
5. The template.
6. The examples.

---

## 7. Traceability

| Finding | Item | Tests (red on 2.6.0, green on 2.7.0) | Corpus |
|---|---|---|---|
| MAJ-01 | 3.2 | `test_check::test_c18_*`; `test_fill::test_notes_rendered_in_block` | note-stale, label-in-prose |
| MAJ-04 | 3.1 | `test_register::test_superseded_rows_counted_separately`; `test_check::test_c11_two_live_rows_fail_with_supersedes_fix` | superseded |
| NEW-04 | 3.1 | `test_core::test_seal_marks_upgrade_without_matching_doc_sha`; `test_check::test_c17_strict_fails_on_upgrade_seal` | upgrade-seal |
| MAJ-05 | 3.3 | `test_check::test_c17_scope_ids_fail`; `test_register::test_a1_computed_scope_line` | scope-ids |
| MAJ-09 | 3.4 | `test_core::test_audit_plan_deterministic`; `test_check::test_c19_*` | audit-plan |
| MAJ-10 | 3.6 | `test_check::test_c9_10_1_severity_order` | severity-order |
| MIN-01 | 3.7 | `test_check::test_c1_bare_name_fails_on_2_7`; `test_core::test_expand_citations_idempotent` | bare-cite |
| MIN-03 | 3.1 | `test_register::test_a1_audit_provenance_line` | — |
| MIN-05 | 3.8 | `test_fill::test_closed_questions_block` | — |
| F2 | 3.10 | `test_check::test_c14_uses_live_rows` | unknowns-leak |
| F4 | 3.5 | `test_check::test_c15_stale_marker_fails` | stale-count |
| AQ5 | 5.2 | eShop 2.7 example: V-finding or 10.2 row present | — |
| AQ6 | 3.9 | `test_check::test_c9_section_17_rows` | — |
| Upgrade path | 5.1 | `test_corpus::test_upgrade_2_5_to_2_7` | upgrade-2-6-to-2-7 |

---

## 8. Done means

1. Every test in §7 is red on `v2.6.0` and green on the release commit. CI (including cross-OS hashes) is green.
2. A 2.6 document fails C3 on 2.7.0, and passes after exactly the §5.1 steps (corpus test).
3. In all four `examples/current` (2.7.0) documents:
   - A.1 shows the audit date and version, the block version, a computed scope with no IDs or digits in the free text, and no upgrade-sealed rows;
   - every planned audit ID has a live row;
   - notes live in blocks with current seals;
   - every count in prose is a marker;
   - closed questions are generated;
   - §10.1 and §15 are ordered by severity;
   - there are no bare names outside root files;
   - §17 is filled with cited commands, Unknown, or Not applicable plus a citation.
4. `examples/previous` holds 2.6.0, and `docs/diagnostic-2.7.0-comparison.md` is generated from the pair.
5. `gen_docs --check` is clean, and the `v2.7.0` tag exists with the gate pinned to it.
