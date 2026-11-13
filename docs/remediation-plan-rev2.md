# AppDoc v2.3.0 → v2.4.0 Remediation Plan (rev 2)

**Date:** 2026-11-12
**Supersedes:** `docs/remediation-plan.md` (rev 1, left unchanged for comparison)
**Basis:** rev 1 audited line by line against the v2.3.0 source (`appdoc/*.py`, `appdoc/stacks/*.py`, `template_spec.py`, the ADRs, `ci/`) and against `examples/flaskr-tdd/evidence.jsonl`.
**Goal:** fix the causes, not the five symptoms, so the same class of failure cannot come back on a new run, a new Target or a new Stack.

---

## 1. Verdict on rev 1

Rev 1 names the right five symptoms. Most of its fixes treat the symptom on the five sample Targets, two of its code snippets do nothing, and one fix makes the audit less trustworthy. Nothing in it would stop the same failures on a sixth Target.

| Rev 1 item | Verdict | Rev 2 |
|---|---|---|
| 1.1 Prose-mention heuristic | Wrong root cause; the proposed function never returns True; weakens the Check | Replaced by 1.1 (C2 per claim, no line citations into binary files) |
| 1.2 `fill --register` stubs | Pre-fills `Supported` on unaudited claims; real cause (edits after the audit) untouched | Replaced by 1.2 (claim fingerprint, one row per ID) |
| 1.3 C7 message + advisory | Cosmetic; the message already says "run fill" | Replaced by 1.3 (`appdoc build`) |
| 1.4 Deny-lists in `config_role` and `scan` | Overfits to helpweb/gitea/eShop; would prune live Classic ASP code; reverses 2.2's "prune on evidence" | Replaced by 1.4 (evidence-based role, retired folders are a recorded decision) |
| 1.5 One command per cited file | "At least one should print" is not verification; four other mismatches left in place | Replaced by 1.5 (commands generated from the location the Check verified) |
| 2.1–2.3, 3.1–3.4 | New features inside a bug-fix release; several design defects | Moved to a 2.5 plan, section 8 lists the corrections each needs |
| 4.1 Integration test | Test bodies are `pass`; uses pytest in a stdlib-only project; real-target test never runs in CI | Replaced by Phase 0 and Phase 2 |
| 4.2 Version bump | No Facts schema bump although `facts.json` changes | Phase 3 |

---

## 2. Audit findings (evidence)

**A1. 1.1 states the wrong mechanism.** A bare `` `.gitignore` `` is a Citation because `gitignore` is in `SOURCE_EXTENSIONS` (`appdoc/citations.py`), not through `_is_dotfile`, which only applies when a line is present. `tests/test_citations.py` already asserts the bare form is a Citation on purpose.

**A2. The proposed `_is_prose_mention` is a no-op.** It is called with `m.start(1)` and `m.end(1)`, which sit inside the backticks. So `before` and `after` are always `` ` ``, and `prefix.split()[-1]` always ends in `` ` `` and is never in the stop-word list. It cannot return True for any input without a `/`. The tests listed for it would fail.

**A3. Had it worked, it would weaken the Check.** A span that stops being a Citation is no longer proven to exist (C1), can flip C5, and the stop-word list is English only. `examples/flaskr-tdd/evidence.jsonl` rows E-80 and E-91 show what happened: the claim had a line (`.gitignore:5`), the auditor believed dotfiles "cannot be cited", and the same rows cite `project/flaskr.db:1`, a line number inside a binary SQLite file. C2 as written ("every Citation in section 10 has a line") can only be satisfied there by inventing a line. That is the cause; the prose mention is one of its two symptoms.

**A4. 1.2 pre-fills a verdict.** Both the "ready-to-paste" message and the stub rows carry `"result": "Supported"` before anyone has opened the source. The message also interpolates finding text into JSON without escaping. And the gap that produced the symptom is wider than "a new V-ID has no row": nothing ties a row to the text it audited. flaskr has two rows each for `10.1/V-4` (E-45 Corrected, E-77 Supported), `10.1/V-8` (E-49, E-78) and `6/UI-2` (E-21, E-83); the older rows describe wording that no longer exists, and Appendix A counts them.

**A5. 1.3 changes a message that already says the right thing** (`_c7_blocks`: "run `appdoc fill <target>`; never edit a generated block by hand"). The row-count advisory is a weaker copy of the exact comparison C7 already makes, and adds a warning to a Check whose contract is "no warnings" (`check.py` docstring, CONTEXT.md). The cause is that step order (fill, audit, fill again, fix sentences, check, render) lives in the agent's memory.

**A6. 1.4 hardcodes names from the sample Targets.**
- `scan._PRUNE_DIRS` prunes `vendor`, `_private` and `To be deleted` by name. 2.2 moved pruning to evidence (`prune_rule`) because name-based pruning dropped gitea's `packages/` and `build/`. `_private` is where FrontPage-era Classic ASP sites keep includes and data files; pruning it silently removes live code from exactly the legacy estate AppDoc is for.
- The scan match is case-sensitive; `TO BE DELETED/`, `Old/`, `backup/`, `Copy of site/` on the next Target are not covered.
- `_NEVER_CONFIG_DIRS` is compared with lowercased path parts, so its capitalised entry is dead. `.htaccess`, `.htpasswd`, `.DS_Store` and `Thumbs.db` are never read by `generic.extract`, so those entries are dead too.
- The test "`peregrine/java/ClientRes.properties` → None (i18n by name pattern)" cannot pass: nothing changes `_I18N_NAME`.
- `es-metadata.yml` is left as "add to `_BUILD_NAMES` or `_TOOLING_DIRS`".
- The deeper defect is the default: `config_role` returns `app` for anything it does not recognise, so every unknown file is asserted to be application configuration.

**A7. 1.5 leaves the trust problem in place.** In flaskr at least 11 of 91 verifiable rows print a command against the wrong file today (E-3, E-8, E-13, E-22, E-28, E-42, E-54, E-65, E-80, E-86, E-91). With one command per cite, E-80 and E-91 would grep a binary database, and a reader is told to expect some commands to print nothing. Four more mismatches between what the Check accepts and what the command does are not addressed:
1. The Check matches after whitespace normalisation and across joined lines (`_span_text`); `grep -F` and `-SimpleMatch` match one raw line.
2. `Select-String -SimpleMatch` is case-insensitive; `grep -F` is not.
3. `Select-String -Path` treats `[` and `]` as wildcards (`pages/[id].tsx`).
4. The Check resolves a bare file name to its one match in the tree; the command prints the bare name.

**A8. 2.1's footnote regex** `to.?be.?deleted|retired|deprecated|old` is unanchored and matches `threshold/`, `household/`, `holdings/`.

**A9. 2.2 puts an interpretation in a generated block.** "every 30s" derived from a `Task.Delay` near a loop is a guess: the delay may be a retry back-off, or the interval may come from options. Generated blocks hold what a script read, not what it concluded (ADR 0005).

**A10. 2.3's cap change is a no-op** (`CONFIG_CAP if len(keys) > 50 else len(keys)` yields today's output in both branches) and contradicts its own prose and test. The "Use" column changes `TABLES["16.6"]` and ADR 0009 without saying so.

**A11. Phase 3 blocks would fail the Check or mislead.**
- None is added to `OPAQUE_BLOCKS`. A generated table placed above the hand table in 4.1 or 8.1 becomes the "first table" (`docmodel.first_table`) and fails C9.
- 3.1 reads `detail["kind"]`; every extractor writes `type` (`generic._conn`, `aspnet_core`). The Kind column would be empty.
- 3.1 caps at 50 rows with no "N of M" line (ADR 0009 requires visible truncation), duplicates the hand tables 8.1/8.3, and prints "No … were extracted" on an unsupported Stack, which reads as "there are none".
- 3.3 lists "routes in the same file" beside an auth check. Co-location is not enforcement; that table invites exactly the inference the 5.3 Restriction line forbids.
- 3.4 groups by top-level folder, which collapses to one row for any `src/` layout, and repeats the top-folders table already in `scan-coverage`.

**A12. 4.1 gates nothing.** The test bodies are `pass`. `@pytest.mark.skipif` needs `import pytest`; CI runs `python -m unittest discover` and `tests/check_stdlib_only.py`, so the module would fail on import. The real-target test is skipped wherever the Targets are absent, which is CI. It lists four of the five Targets.

**A13. No Facts schema bump.** 1.4 and 2.2 change `facts.json` for unchanged code. `ci/appdoc-docs-gate.yml` tells an AppDoc upgrade from a code change by the schema string; without `appdoc-facts/5` every consuming repo that moves to v2.4.0 gets "the code changed since the docs were last generated".

**A14. Traceability and arithmetic.** The "comparative analysis of 5 generated documents" is not in the repo (`docs/standard-comparison-2026-11-11.md` covers four Targets and predates 2.3), so no finding can be traced to an item. The phase table sums to 7 days, the effort table to 29 h "(~4 days)", and Phase 1 is "~2 days" against 9 h of items. Verification step 4 is "visual inspection".

---

## 3. Root causes

| # | Root cause | Symptoms it produced | Fixed by |
|---|---|---|---|
| RC1 | **One judgment, two implementations.** The Check decides where an anchor is; the appendix prints a command from a different rule. | A.4 wrong path, A7.1–A7.4 | 1.5, 2.1 |
| RC2 | **Name lists learned from sample Targets, with a permissive default.** Unknown file → `app`; unknown folder → live code. | Config noise, retired copies in entry points | 1.4 |
| RC3 | **A rule that can only be met by inventing evidence.** C2 demands a line on every span in section 10. | Prose mention flagged; `flaskr.db:1` | 1.1 |
| RC4 | **Order and freshness held in the agent's memory.** Fill-after-edit, audit-then-edit, which AppDoc build produced the files. | Stale Appendix A, findings without rows, superseded rows | 1.2, 1.3, 2.5 |
| RC5 | **"Not extracted" reads as "not there".** Unsupported Stacks, capped lists, unresolvable schedules. | "Unknown" schedules, empty blocks | 2.4, section 8 |
| RC6 | **No regression corpus.** Unit tests are per module; the Targets that expose these failures live outside the repo and outside CI. | All five reached generated documents | Phase 0, 2.1–2.3 |

---

## 4. Rules for this release

Every item below is checked against these in review.

- **R1 Reproduce first.** No fix merges without a test that fails on the `v2.3.0` tag and names the symptom.
- **R2 Never weaken the Check to make an example pass** (SKILL.md already says this to the writer; it applies to us).
- **R3 Closed sets only.** A name may be hardcoded when an OS or tool specification defines it (`.git`, `_vti_cnf`, `desktop.ini`). A name people choose (`To be deleted`, `old`, `es-metadata.yml`) may trigger a question, never a behaviour.
- **R4 Generated blocks state what a script read.** No interpretation. Every truncated list says N of M. Every "none" says which Stacks could have produced it.
- **R5 One implementation per judgment.** Anything the tool prints for a human to run is executed by a test.
- **R6 Version honestly.** A change to `facts.json` output bumps `SCHEMA`. A change that fails committed documents bumps `TEMPLATE_VERSION` and ships upgrade notes that are mechanical.
- **R7 House constraints.** Standard library only, `unittest` only, Python 3.10+, Windows and Linux.

---

## 5. Phase 0 — Reproduce and pin (do first)

**0.1 Commit the source analysis** as `docs/comparison-2.3/` and add a table to this plan: analysis finding → item → test name. Until then the five root causes are asserted, not shown.

**0.2 Establish which build wrote `examples/`.** E-80 says a dotfile with a line "cannot be cited"; the v2.3.0 parser accepts `.gitignore:5`. Either the examples were produced by an older installed copy of the skill or the auditor guessed. Run `check` from repo HEAD against each example and compare the installed bundle hash. If it was version skew, 2.5 is confirmed as necessary; if not, the C2 message in 1.1 carries the fix.

**0.3 Build the failure corpus** under `tests/corpus/<case>/`: a Target of a few files plus, where needed, a `docs/appdoc/` with a Narrative and register. One `unittest` module, `tests/test_corpus.py`, written to the *new* expected behaviour so every case is red on v2.3.0.

| Case | Contains | Asserts |
|---|---|---|
| `c2-mention` | 10.1 row with a lined Citation and a bare `` `.gitignore` `` mention | Passes C2; the mention is still a resolved Citation in the citation register |
| `c2-binary` | Citation `data/app.db:1` into a file with NUL bytes | C1 fails: binary file, cite without a line |
| `c2-none` | 10.1 row whose only Citation is bare | C2 fails |
| `anchor-order` | Anchor in the 3rd cite; a cite by bare file name; paths `pages/[id].tsx` and `Old Site/a.asp`; anchor with `'` and `"` | A.4 names the right file and line; the printed commands run and print that line |
| `anchor-loose` | Anchor that matches only across two lines; one that differs by case | C11 fails with the specific reason |
| `stale-audit` | 10.1 row edited after sealing; a V-ID with no row; two rows for one V-ID | Three distinct C11 failures |
| `stale-block` | Register changed after `fill` | `check` fails C7; `build` repairs it and passes |
| `retired-copy` | `To be deleted/` duplicating live handlers; `OLD_site/`; `threshold/` | Two candidates recorded, `threshold/` not; nothing pruned; C7 fails until 2.1 names them |
| `config-noise` | `desktop.ini`, `_vti_cnf/x.yml`, `crowdin.yml`, `es-metadata.yml`, `ClientRes.properties` + `ClientRes_fr.properties`, `application.properties` whose key code reads | Only the last is role `app`; the rest are counted, by role, in the block trailer |
| `unsupported` | A Cargo project | Every generated block says the kind was not extracted for `rust` |

---

## 6. Phase 1 — Root-cause fixes

### 1.1 C2 judges the claim, not the span (RC3)

**Change**
1. **C1:** a Citation with a line into a file that is binary (NUL in the first 8192 bytes, the test `scan.walk` already uses; expose it as `scan.is_binary`) or over `MAX_BYTES` fails: "`x.db` is a binary file; cite it without a line". A bare path to such a file still resolves.
2. **C2, new definition:**
   - every 10.1 row's Evidence cell holds at least one Citation with a line;
   - every 10.2 row with status `Present` holds at least one Citation with a line (the other statuses record where someone looked, which is a file);
   - every other block in section 10 that holds a Citation holds at least one with a line.
3. A bare mention stays a Citation, so C1 still proves the file exists. `citations.py` does not change. No language heuristics.
4. The C2 message adds: "dotfiles and data files take a line too: `.gitignore:5`".
5. CONTEXT.md "Citation" and ADR 0006 item 4 are updated to the per-claim wording.

**Why this is not a weakening:** today's rule is met by writing `:1`. The new rule cannot be met without a line that exists in a text file, and (through 1.5) an anchor on that line.

**Tests:** corpus `c2-mention`, `c2-binary`, `c2-none`; unit tests in `tests/test_check.py` for each of the three C2 clauses.

**Decision D1** (section 10): keep per-span C2 and add only the binary rule and the message, if you would rather not relax anything.

### 1.2 The register knows which text it audited (RC4)

**Change**
1. A row may carry `claim_sha`: 12 hex characters of SHA-1 over the normalised text its `ref` points to. For an ID ref (`10.1/V-4`, `4/F-3`, `15/R-9`) that is the table row that defines the ID; for a workflow (`7.3`) the subsection; for any other section ref the section with generated blocks masked. Normalisation: comments stripped, whitespace collapsed.
2. `appdoc seal <target>` (also the first step of `build`, 1.3) writes `claim_sha` into every row that lacks one. It never overwrites one. To re-audit a row, the auditor rewrites the row without the key.
3. **C11 adds:**
   - an ID or workflow row with no `claim_sha` → "not sealed; run `appdoc build`";
   - `claim_sha` differs from the document → "the text of 10.1/V-4 changed after it was audited; re-audit it and replace the row";
   - two rows for the same ID ref → "keep the row that describes the current text".
   Section-level refs that are stale are counted in A.2 ("N rows audited an earlier text of their section") and do not fail; a section edit should not invalidate eight unrelated rows.
4. `Dismissed` and `Answerable` rows are exempt (a smell id already encodes path and line).
5. The existing C11 messages for a missing V-ID or workflow row stay as they are, plus the next free `E-n`. No stub rows, no pre-filled result. Rev 1's `fill --register` is dropped.

**Known limit:** sealing proves the text has not changed since the seal, not that the audit was careful. SKILL.md: the auditor runs `build` as the last act of the audit.

**Tests:** corpus `stale-audit`; `tests/test_register.py` for seal idempotence, key order preserved, CRLF preserved.

**Decision D2:** fail on stale section-level refs too (stricter, more re-audit churn).

### 1.3 One command for the mechanical tail (RC4)

**Change**
1. `appdoc build <target>` runs seal → fill → check → render (render only when the Check passes) and returns the Check's exit code.
2. `check` stays read-only; the docs gate keeps calling it.
3. `render` refuses, exit 2, when a generated block differs from what `fill` would write (it reuses the C7 comparison), so stale HTML cannot be published by calling `render` alone.
4. SKILL.md "Run" shrinks from nine steps to: extract, orient, write, **build until it passes**, audit in a fresh agent, **build**, report. "Run fill again after the audit" and "run check last" disappear because there is nothing to remember.

The C7 message is left alone. Rev 1's advisory is dropped.

**Tests:** corpus `stale-block`; `tests/test_launcher.py` for the new subcommands and exit codes.

### 1.4 Classify on evidence; treat retirement as a decision (RC2)

**A. Config role**
1. New role `unclassified`, the default. `config_role` returns `app` only on positive evidence:
   - a framework-defined name: `application*.{properties,yml,yaml}`, `appsettings*.json`, `web.config`, `app.config`, `.env*`, `local.settings.json`, and the `config`/`settings` JSON names already in `CONFIG_NAMES_JSON` (a closed set per framework, R3); or
   - a post-pass in `extract.py`: a file whose key name matches a `config_key` Fact with `use="read"` from code is promoted from `unclassified` to `app`.
2. Message bundles: a `.properties`/`.yml` file with a sibling `<base>_<ll>[_<CC>].<ext>` is a bundle (role None), in addition to today's names. A lone `ClientRes.properties` becomes `unclassified`, not `app`; rev 1's test expectation is corrected to that.
3. The `config-reference` trailer gains: "K keys in F files were not classified as application configuration: `desktop.ini`, … (first 5; see facts.json)". Nothing is asserted to be app config without evidence, and nothing disappears.
4. OS and authoring metadata (closed sets): files `desktop.ini`, `Thumbs.db`, `.DS_Store` and folders with the `_vti_` prefix are dropped in `scan.walk` under a named rule and counted in scan coverage ("OS and authoring metadata: N files"). `_private`, `vendor` and anything named by a person are not touched.

**B. Retired code**
1. No folder is pruned because of its name.
2. `scan` records `target.scan.retired_candidates`: a folder qualifies by **name** (its name, case-folded and split on non-alphanumerics, contains a whole token from `old, bak, backup, archive, archived, deprecated, retired, obsolete, unused, copy, trash, deleteme`, or reads `to be deleted` / `tobedeleted`) or by **content** (at least 5 files and at least half of them byte-identical to a file outside the folder). Each entry: path, signal, files, duplicate files. The list only raises a question (R3).
3. `scan-coverage` renders "Folders that look retired (not excluded)". `entry-points` states its headline both ways: "N route handler files (K under folders that look retired)".
4. **C7:** while a candidate is present, section 2.1 must name it (same mechanism as an unsupported Stack). The writer records the decision: documented as live, or excluded.
5. Exclusion is the owner's act: add the folder to `.appdocignore` and re-extract. Scan coverage lists ignored folders with file counts (today it only gives a total).
6. For helpweb: `To be deleted/` goes in helpweb's `.appdocignore`.

**Safety net for the role change:** the PR lists, per sample Target, every file that leaves role `app`, with the reason. Review that list before merging.

**Tests:** corpus `config-noise`, `retired-copy`; unit tests for the token matcher (`threshold`, `household`, `Old`, `site-old`, `OLD_site`, `To Be Deleted`).

**Decision D3:** `unclassified` as the default changes what 16.6 lists on every Target. The alternative is to keep `app` as the default and add only the metadata rule and the trailer.

### 1.5 A.4 is printed from the location the Check verified (RC1)

**Change**
1. `register.locate(root, row) -> (path, line) | None`: for each cite in order, resolve the path the way C11 does (move the resolver out of `check.py` so both import it), read the cited lines raw, and return the first line that contains the anchor exactly and case-sensitively.
2. **C11** uses `locate` for `Supported` and `Corrected` rows. `None` fails with the specific reason: not found; found only across lines or after whitespace normalisation ("copy the anchor from one line exactly"); cited file is binary; anchor is not ASCII and the file is not UTF-8; anchor contains a code-fence marker.
3. `_commands(reg, root)` prints one block per row from that location:
   ```text
   - **E-42** (`10.1/V-1`), expect line 53
   Select-String -LiteralPath 'project/templates/login.html' -SimpleMatch -CaseSensitive -Pattern '…'
   grep -nF -- '…' 'project/templates/login.html'
   ```
   and opens with "Run from the Target root." The path is the resolved Target-relative path, never a bare name.
4. `fill.run` already receives `target`; pass it in `ctx`, and have `_c7_blocks` do the same. `appendix_markdown(reg, facts, coverage, root=None)` keeps working without a root (no commands) for unit tests.
5. No register rows need rewriting: the eleven wrong flaskr commands are corrected by regeneration.
6. ADR 0007 item 2 is amended: exact single-line match replaces "after whitespace normalization".

**Tests (R5):** corpus `anchor-order` and `anchor-loose`. `tests/test_appendix_commands.py` extracts every printed command from the generated appendix and runs it with `subprocess`: `grep` where `shutil.which("grep")`, `pwsh` or `powershell` where present; asserts exit 0 and that the printed line number equals the expected one. With `APPDOC_CI=1` a missing tool on its home OS is a failure, not a skip (ubuntu must have grep, windows must have PowerShell).

---

## 7. Phase 2 — Barriers against recurrence

**2.1 Corpus in CI.** `tests/test_corpus.py` from Phase 0 runs in the existing matrix. Any future bug report gets a corpus case before its fix (R1).

**2.2 Pinned real Targets.** `eval/targets.json` holds name, git URL and commit SHA. A workflow job fetches each at depth 1, runs `extract`, compares `facts.json` byte for byte with `examples/<name>/facts.json`, copies the committed example documents into the Target and runs `check --require-audit`. flaskr-tdd and spring-petclinic run on every PR; eShop and gitea nightly and on release tags. helpweb is private: `eval/run_local.py` runs the same steps when the path exists, and the release checklist says so in words. This job, had it existed, fails on all five symptoms.

**2.3 Stack conformance test** (the "new language" guard). One `unittest` module iterates `stacks.MODULES` and `tests/samples/<stack>/` and asserts for every Fact: kind in `KINDS`; path exists in the sample; `1 <= line <= file length`; detail keys are a subset of a new `facts.DETAIL_KEYS[kind]`; no detail value has a secret shape; two extractions are byte-identical. Each Stack declares `capabilities` (the Fact kinds it can emit), emits nothing outside it, and its sample exercises every declared kind. `README.md` "Add a Stack" points here; a Stack that fails cannot merge.

**2.4 "None" names its blind spots (RC5).** Each `stack` Fact carries `capabilities` in `facts.json`. A generated block with no rows prints "No scheduled jobs were extracted. Stacks that can report them: `go`, `aspnet-core`. Not covered: `rust` (unsupported)." Every capped list prints "Shown N of M".

**2.5 Version skew is detected.** `facts.json` gains `generator` (the AppDoc version); `check-report.md` prints the version that ran. C7 fails when they differ in major.minor: "facts.json was written by AppDoc 2.3; re-run extract". `run_appdoc.py --version` prints version and bundle hash, and the SKILL.md preflight compares it with the checkout it was installed from.

**2.6 No manual verification.** "Visual inspection of the HTML" is replaced by assertions in `tests/test_render.py` that each generated block's table reaches the HTML.

---

## 8. Deferred to a 2.5 plan — capabilities (rev 1 items 2.2, 2.3, 3.1–3.4)

These are features, not remediation. They start after Phase 2 is green, each with an ADR. Corrections each needs:

| Rev 1 item | Required change before it is built |
|---|---|
| All new blocks | Listed in `GENERATED` **and** `OPAQUE_BLOCKS`; "N of M" on every cap; capability-aware "none" (2.4); covered by the conformance test |
| 2.2 Job schedules | `schedule` stays for declared schedules only (cron literal, attribute). New `interval_expr`: the literal source text of the single delay or timer expression inside the job's loop, with its line, rendered verbatim. Two candidates, or a non-literal argument → "Unknown (see `path:line`)". Never a synthesised "every 30s". Required of every Stack with the `job` capability, not only ASP.NET Core |
| 2.3 Config block | Drop the cap change (no-op) and the "Use" column. Grouping by file is fine if each group keeps the `TABLES["16.6"]` header |
| 3.1 Data-access register | Do not duplicate 8.1/8.3. Add a coverage rule like "Entry points not cited": every non-test `connection` and `external_call` Fact is cited by an 8.1/8.3 row, advisory by default, failing under `--strict`. Read `detail["type"]`. No auth or failure columns from regex |
| 3.3 Role-matrix hints | Only guards that are syntactically attached (attribute or decorator on the handler or its class; `.RequireAuthorization()` on the mapping call). List those pairs, then "guards with unresolved scope", then "routes with no attached guard (a global guard may still apply)". Never "routes in the same file" |
| 3.4 Subsystem inventory | Add Routes, Pages, Jobs columns to the existing top-folders table in `scan-coverage`, with adaptive depth (descend while one folder holds over 60% of files). No new block |
| 3.2 UI controls | Template guide only. No extractor until a generated document shows the guide is not enough |

---

## 9. Phase 3 — Release

1. `facts.SCHEMA = "appdoc-facts/5"`; `TEMPLATE_VERSION = "2.4"`; `UPGRADE_NOTES` updated; `ci/appdoc-docs-gate.yml` pins `v2.4.0`.
2. Upgrade notes for a 2.3 document, all mechanical: re-run `extract`; change the stamp to 2.4; run `appdoc build`; fix what it lists (expected: anchors not on one line, `:1` on binary files, duplicate ID rows, retired folders to name in 2.1). No headings or markers change, so nothing is re-copied from the template.
3. ADRs: amend 0006 (C2) and 0007 (exact match, `locate`, `claim_sha`); new 0010 (evidence-based classification, retired candidates). CONTEXT.md gains **Retired candidate**, **Unclassified config**, **Seal**.
4. Regenerate the five examples with v2.4.0, commit, and append a post-remediation section to the analysis from 0.1.
5. CHANGELOG 2.4.0.

---

## 10. Decisions needed

| # | Decision | Recommendation |
|---|---|---|
| D1 | C2 per claim (1.1) or keep per span and add only the binary rule | Per claim |
| D2 | Stale section-level register rows: report or fail | Report in 2.4, revisit |
| D3 | `unclassified` as the default config role | Yes, with the per-Target diff reviewed |
| D4 | Capabilities move to a separate 2.5 plan | Yes |
| D5 | `examples/helpweb/` holds findings about an internal application; confirm it belongs in a public repository before step 9.4 copies a fresh one | Confirm before release |

---

## 11. Order and effort

```
Phase 0  0.1 analysis in repo · 0.2 build provenance · 0.3 corpus (red)        1.5 d
Phase 1  1.5 locate + A.4      (all five Targets, no register edits)            5 h
         1.1 C2 + binary rule                                                   3 h
         1.3 build / render guard                                               3 h
         1.2 claim_sha + seal                                                   6 h
         1.4 role evidence + retired candidates                                10 h
Phase 2  2.3 conformance · 2.4 capability "none" · 2.5 generator · 2.2 job     2 d
Phase 3  schema/template bump, ADRs, regenerate five examples                  1.5 d
                                                                    Total  about 8.5 d
Deferred (2.5 plan): capabilities                                    about 2.5 d
```

1.5 goes first because it repairs every existing document without touching a register. 1.4 goes last in Phase 1 because it changes `facts.json` and needs the per-Target review.

---

## 12. Done means

1. Every corpus case is red on `v2.3.0` and green on the release commit.
2. CI is green on ubuntu and windows, Python 3.10 and 3.13, with `APPDOC_CI=1` (no skipped command-execution tests).
3. The pinned-Target job passes for the four public Targets; `eval/run_local.py` passes for helpweb.
4. In all five regenerated examples, every A.4 command, run from the Target root, prints the line the block names.
5. No example register has two rows for one ID; no example cites a line in a binary file.
6. `grep -rn "To be deleted\|es-metadata\|crowdin\|peregrine" appdoc/` returns only the entry already in `_BUILD_NAMES` (R3).
7. A document built with v2.3.0 fails the v2.4.0 Check with one C3 message, and passes after the four upgrade steps.
8. The traceability table from 0.1 has a test name against every finding.
