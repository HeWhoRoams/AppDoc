# AppDoc Remediation Plan — DegreeAudit audit findings (v2.8.0 / v2.9.0)

**Date:** 2026-11-20 (rev 3), updated 2026-11-23 (rev 4)
**Status:** Proposed. Not started. The base question (Q30) is resolved: `main` is the single line. Blocked only on 2.5–2.7 landing (see §0.1).
**Release sequence:** 2.5.0 (in flight, branch `v2.5.0`) → 2.6.0 (tooling and Facts) → 2.7.0 (template) → **2.8.0 (security and access, template 2.8)** → **2.9.0 (integrations, CI, repository docs; no template bump)**. The split is Q22.

**Basis**
- `DegreeAudit/docs/appdoc/appdoc-audit-report.md` (2026-11-20): independent audit of the AppDoc 2.1 output for a .NET Framework 4.8 MVC 5 Target (commit `33168dd`; 265 entry points; 6 MVC areas; Windows authentication; `Web.config` transforms).
- A line-level read of `appdoc/` on branch `v2.5.0` (`__version__ = "2.4.0"`, `facts.SCHEMA = "appdoc-facts/5"`).
- Plans 2.5, 2.6 and 2.7 and ADR 0016 (principles P1–P6; rules R10–R15).
- `origin/main` at `2e59393` (2026-11-23) for the current state of the code and of plans 2.5–2.7.
- Three independent reviews of rev 2, folded into this revision: **A** ASP.NET/IIS/XDT semantics, **B** consistency with code, earlier plans and ADRs, **C** a feasibility spike against the real Target.

**Format:** the house convention. Each item has failing tests (TDD), a corpus case, and a "why this is not a weakening" line.

**Naming.** Work items are **W1–W15**, not section numbers, so they do not collide with template sections. Template sections are written "template §5.4". The audit's finding IDs are prefixed **DA-** (DA-E1, DA-S2, …) so they do not collide with AppDoc register IDs (E-n) or this plan's change list (V-n). The plan's Q numbers are Q22–Q32.

**Confidentiality.** DegreeAudit is private. This file names finding IDs, Fact kinds and patterns only. Application class names, config keys, folder names, host names and counts live in the private answer key (`$APPDOC_ACCEPTANCE_KEYS/degreeaudit.json`) and never in the repository.

**Location:** `docs/remediation-plan-2.8.md`. The rev 1 file `remediation-plan-2.8-2026-11-20.md` at the repository root can be deleted.

---

## Rev 4 changes (2026-11-23: main is the base)

| # | Change | From |
|---|---|---|
| V38 | **Q30 resolved.** `main` (`2e59393`) is the single line: the `v2.5.0` branch is merged with the performance and integration work, 475 tests pass, and no tag exists after `v2.0.0`. §0.1 records the state of 2.5–2.7. | main check |
| V39 | **Per-file Facts must be cache-safe.** `main` has a content-hash cache keyed on `(file bytes, detected stack ids, sibling names, SCHEMA, extractor version)`, a process pool (`--workers`) and a cache that stores **pre-promotion** per-file Facts. A raw Fact therefore may depend only on its own file's content, the detected stack ids and sibling *names*; anything that needs another file's content is a post-pass. Every W13 raw Fact meets this, and a test proves it (`test_core::test_raw_facts_warm_equals_cold`). New rule **R21** (from the 2.5 amendment): extractor changes bump the cache salt (2.6 §4.6 derives it from the bundle hash). | main `extract.py` |
| V40 | **`aspnet.detect_in` extends an existing hook.** `extract.extract` already calls `st.detect_in(paths, root)` when a Stack defines it; `node_express` implements it (it already requires `express` to be *declared* in `package.json` and used in source). Rev 3 said no Stack implements it and listed a false `node-express` stack as a defect to fix. W6.3 shrinks to a regression test against a tooling-only manifest. | main `node_express.py` |
| V41 | **Reuse `integration.py` for the connections and integrations blocks (R5).** `main` has `appdoc/integration.py`, a deterministic aggregation of `connection`, `external_call` and `dependency` Facts into the `System Connections` view (in `facts-summary.md` and the HTML page), with `connection.type` widened to `cache`, `queue`, `object_storage`, `grpc`, `ldap`, `search` and `smtp`. §6.2's blocks build on that aggregation rather than a second one, and the `external_call type=file_drop|share` additions are added to its vocabulary. | main `integration.py` |
| V42 | **Code references by function name**, not line number, for `extract.py` (the performance refactor moved everything). `check.py` references stay (unchanged since `8deea1b`). | main |
| V43 | **Capability plumbing moves to 2.6** (2.6 B-5: dotted detail capabilities, the shared-emitter attribution rule and `GENERIC_KINDS`). W13 here only *uses* it. Effort −0.25 d. | 2.6 rev 2 |
| V44 | **`appdoc-context.md` already has a parser fragment** (`check._never_mention` reads a ```` ```never-mention ```` block) and 2.5 §1.4 adds `Ownership:`. W13's `appdoc/context.py` is the single parser for all of them; 2.5 A-5 asks 2.5 to introduce it. | 2.5 rev 2 |
| V45 | **`appdoc upgrade` lives in 2.7 if Q23 is accepted** (2.7 rev 2 §3.11 now contains the specification); W15 here covers only the 2.8 steps. | 2.7 rev 2 |

---

## Rev 3 changes (reviews A, B, C)

| # | Change | From |
|---|---|---|
| V20 | **URL authorization is evaluated as a merged, ordered rule chain** for three archetype principals (`anon`, `auth`, `role:<R>`) and a verb, not as "the most specific set". Handles `verbs`, `<clear/>`, `<remove>`, `location` path forms, the implicit machine `allow *`, and a URL set per handler. | A C-1, I-1 |
| V21 | **MVC filters are ANDed** with each other and with URL authorization. `guard` is a sorted list of mechanisms. `[AllowAnonymous]` overrides filter-level `Authorize` only. `[OverrideAuthorization]` clears outer filters. Unresolved external base types give `unknown`, never `none`. | A C-2, I-3; B I3 |
| V22 | **Reach labels are application-layer only** (`no_app_restriction`, `signed_in_any`, `role_restricted`, `denied`, `unknown`), always printed with the per-principal triple and a mandatory disclosure line. IIS, OWIN and external SSO are disclosed through `host_auth` and `owin_auth`. Rev 2's `allow *` = `anonymous` is removed. | A C-3; C 2.1 |
| V23 | **An unsupported transform makes the effective value `unknown`** (never "un-transformed"). Transform set widened to recognise `InsertBefore/After/IfMissing`. `Insert` appends. Transforms apply to the project-root `Web.config` only, at publish or package time. Configurations are enumerated from the csproj and sln as well as from transform files, so a configuration with no transform inherits the base. | A C-4; C 2.1 |
| V24 | **Nested `Web.config` rules are scoped by URL prefix.** The `applies: url\|physical` split is dropped. | A C-5 |
| V25 | **Parsing is hardened and line-accurate**: bytes into `xml.parsers.expat`, DOCTYPE and ENTITY rejected, size and depth caps, namespaces stripped for config names, BOM-safe, case-insensitive file names, commented XML never becomes a Fact. | A I-7; C 2.1 |
| V26 | **Secrets cannot leak through guard arguments.** A constant that is a `secret_location` Fact, or whose name matches the secret-key rule, is never value-resolved. Argument arity is recorded. Roles from `Roles=` only; emails and SIDs are counted, not recorded. WCF addresses, CI URLs and CI `variables` are stripped to scheme and host or to key names. | C 2.1/G-2; A I-9, I-10 |
| V27 | **Role coverage without name guessing.** A method that receives ≥2 constants that are also arguments of a guard attribute is promoted to an `auth_method` candidate, so in-body checks count and all role constants are listed. A generated table of **guard argument shapes** makes inconsistent arguments visible. A **secret-location table** is added to the access block. | C G-3, G-4 |
| V28 | **Raw per-file Facts** are specified for every cross-file input; the joins happen only in post-passes that read Facts (§5, W13). `reach_by_config` and similar values are sorted lists of strings, never dicts. Post-passes rebuild frozen Facts with `Fact.make`. | B1, B2 |
| V29 | **Check fixes.** C21 is evaluated on text with generated blocks masked and no longer accepts section 16. Files that produced only `config_unparsed` need a path citation, not a line. The "advisory on 2.7 stamps" mode and Q26 are removed (the Check runs no structure rules on a stale stamp). C22 area coverage reuses the 4.1 folder parse, not C10. | B3, I1, I2; A I-7 |
| V30 | **Generated blocks are opaque and registered correctly.** Each new block gets its own template subsection (so `GENERATED` stays one block per key), is added to `OPAQUE_BLOCKS`, and the connections list moves to an 8.1 block. | B4 |
| V31 | **The C12 gate is rebuilt** around a code constant `smells.OBLIGING`: deterministic config reads oblige from the release that ships them; text and structure heuristics need a measured precision on an in-repo hand-labelled set (positives and negatives), not on the public examples. | B I4; C Part C |
| V32 | **Pattern fixes.** `debug-settings-deployed` becomes `debug-setting-in-nondebug-config` in 2.8 and treats every configuration, including `Debug`, by its computed effective value. `conditional-security-build` is replaced by `conditional_const` and `mode_branch` Facts. `config-year-horizon` takes a reference year from `appdoc-context.md`, needs a key-name token, and is summary-only. The null-check patterns get scope and short-circuit rules. `post-without-antiforgery` and `state-change-authenticated-only` are narrowed. | A I-5, I-8, I-13..15; B I6; C 2.1 |
| V33 | **ASP.NET Core gets mechanism Facts only** (`guard_mechanism`); `guard_reach` is declared by `aspnet` alone. | A I-4 |
| V34 | **Release arithmetic is corrected.** Both releases rotate all examples; 2.9's "nothing fails that passed" is withdrawn; effort is re-estimated (about 31 working days in all, not 17.5). `summary.py`, `gen_docs` and `upgrade` step tables are in scope. | B I8, I9, I12, I14 |
| V35 | **Rule and ID hygiene.** C20's family is not stretched. Rules R16–R18 keep their numbers. R18 scope is stated and `ownership` is exempted. ADR 0020 ships in 2.8. Schema numbers are "next after 2.7's". | B M1, M2, I11 |
| V36 | **Corpus layout follows 2.5 §0.2**: one directory per case, with shared Target directories under `tests/corpus/_targets/`. | B I7 |
| V37 | **Gaps found by the spike** (new items): identifier lists in config, hard-coded production mode in a harness, stale access rules, anonymous surface in full, detector accountability line, the `node-express` false stack, project-file-based stack detection, 5.10 "code" definition. 2.9 adds the multi-hop file-drop rule and `share` Fact, topic vocabulary, cross-source advisories and XSD descriptions. | C Part 3 |

---

## 0. Summary

The DegreeAudit document was produced by **AppDoc 2.1** (`facts.json` is `appdoc-facts/2`, no template stamp). The 2.4.0 Check rejects it with one C3 problem. The audit findings fall into three groups:

| Group | Count | Disposition |
|---|---|---|
| **A. Fixed by upgrading.** Template and structure failures that 2.2–2.4 already enforce. | 11 | No skill change. Re-run on the current release, ideally through `appdoc upgrade` (W15). Until then, Appendix A. |
| **B. Already planned** in 2.5/2.6/2.7. | 7 | Cross-referenced in §1. |
| **C. New skill defects** that recur on 2.4.0 even with a perfect writer: the extractor cannot see the classic ASP.NET security and integration surface, it misclassifies stacks and handlers, and nothing forces the writer to read primary config or in-repo docs. | 29 | **This plan.** |

The most serious group-C finding: on 2.4.0 AppDoc would produce **no Fact, no finding candidate and no Check problem** for a state-changing MVC area that any signed-in user can reach, a committed `machineKey`, or `authentication mode="Windows"` with a per-path `<location>` access matrix. 2.8.0 closes that gap, and states honestly what the repository cannot show.

### 0.1 Base and prerequisites

**Base (resolved 2026-11-23).** `origin/main` is at `2e59393`: version 2.4.0, schema `appdoc-facts/5`, `template_spec.py`, `register.py`, `fill.py`, ADRs 0001–0010 and 0016, C1–C16, plus the performance phases (process pool, content-hash cache, `--skip-tests`, ownership isolation) and the integration catalog and `System Connections` view. There is no tag after `v2.0.0`. A separate branch `ws1/foundation-standardize-output` exists on the remote and is not part of `main`.

**State of the prerequisites on `main`:**

| Prerequisite | State |
|---|---|
| 2.5.0 | **Partly done**: C14–C16 only. Env/CI config roles, owner-context detection, the Razor/EF/HttpClient/Go/Flask extractors, the failure corpus (`tests/corpus/`), schema `/6`, ADRs 0011/0012 and the example regeneration are open (2.5 plan, "Status and amendments"). |
| 2.6.0 | **Not started**: typed class-level capabilities, `version_tuple`, provenance sidecar, determinism harness, `tools/`, `appdoc gate`, tags, answer keys, example rotation. |
| 2.7.0 | **Not started**: append-only register, count markers, audit plan, §17; `appdoc upgrade` proposed (2.7 rev 2, §3.11, Q23). |

**On disk today (so the plan does not assume them):** no `tests/corpus/`, no `tests/test_corpus.py`, no `tools/`, no `tests/test_determinism.py`, no `tests/test_release.py`, no `appdoc gate`, no `appdoc upgrade`, and no class-level typed `capabilities` (stack capabilities are module-level sets). `appdoc-context.md` is read only for its `never-mention` block. The performance work is merged, so the per-file raw-Fact design (V28, V39) is compatible with the process pool and the cache, and must stay so.

**This plan starts after 2.7.0.** The first slice in §12 (config reader, access rules, guards, route fidelity, C21) depends on 2.5's corpus layout and 2.6's capability model, so it cannot start before them either. The only work that stands alone on `main` today is the `.config` reader and its tests (W13, W1, W2), which can be built and unit-tested without the corpus and handed over as a patch.

---

## 1. Disposition of every audit finding

**Rel** is the release under Q22. "Spike" is review C's result against the real code shape.

| Audit ID | Finding (short) | Disposition | Where | Rel |
|---|---|---|---|---|
| DA-T1–T3, T5–T9, T11 | No stamp; missing blocks, 16.7, 5.3 line, §11 rows, register; C8–C13 not run | **A** (2.3/2.4) | W15 upgrade | 2.7/2.8 |
| DA-T4 | No scheduled-jobs block; batch work undocumented | **A** for the block; **C** for content. Batch work is **not** CI. Content: README `scheduled` topic and a multi-sink handler list (W9). A classic-.NET job detector (Windows service, Quartz, Task Scheduler) is **not** in this plan. | W9 | 2.9 |
| DA-T10 | `evidence.jsonl` missing | **A** (C11, `--require-audit`) | — | — |
| Check note 1 | Bare file name resolved "yes" | **B** (2.7 §3.7) | — | — |
| Check note 2 | `Web.config` cited with no line inside a "not reviewed" sentence | **C** | C21 (handle), C20-family advisory | 2.8 |
| DA-E1 | Identity provider "Unknown"; Windows auth is in `Web.config` | **C** | W1, C21, access block | 2.8 |
| DA-E2 | File-drop mechanism "Unknown" (UNC share written from code; the write path is 2–3 local hops from the config read) | **C** | W7 (taint rule plus config-only `share` Fact) | 2.9 |
| DA-E3 | Owners "Unknown"; README names them (two live entries, two inside HTML comments) | **B** (2.5 §1.4) + **C** | W9 (strip HTML comments) | 2.9 |
| DA-E4 | Environments "Unknown" | **C** | W8, W9 | 2.9 |
| DA-E5 | Troubleshooting row describes an unreachable branch | **C** | W11 | 2.8 |
| DA-E6 | Email fallback that cannot fire | **C** | W11 | 2.8 |
| DA-E7 | 7 of 10 connections listed | **C** | W1 + connections block (group by name across base, transform and test configs) | 2.8 |
| DA-E8 | 4 of 14 role constants (only 3 are attribute-referenced; the rest go through a base-class helper) | **C** | W3 (`auth_method` promotion), access block | 2.8 |
| DA-E9 | `[Authorize]` usage understated | **C** | W4, access block | 2.8 |
| DA-E10 | "8,633 files covered" | **B** (2.6 §4.3) + **C** | W6 (stack), W10 (scan) | 2.8 / 2.9 |
| DA-E11 | Cosmetic `:42-42` range | Writer-level, but a deterministic advisory is cheap | C20-family advisory | 2.8 |
| DA-E12 | "also known as" vs "formerly" | Writer-level (the README says both) | — | — |
| DA-G 6.1 | Coverage ~30 of 265; one area and 9 root controllers absent; attribute routes in three `RouteArea` styles | **C** | W5, C22 | 2.8 |
| DA-G 6.1 (harness) | Desktop harness hard-coded to production mode | **C** | W6 (`type=desktop`), W11 `hardcoded-production-mode` | 2.8 |
| DA-G 6.1 (feature list) | README feature absent from the functional inventory | **C**, advisory | W9 cross-source (G-9) | 2.9 |
| DA-G 6.1 (batch queue) | Queue-table write from a handler | Writer-level; no closed signature (not by name) | — | — |
| DA-G 6.2 | Rules library, XML config corpus, workflow definitions, data model, RDLC reports | **C** (partly writer). XSD element names describe the config corpus and workflows (W12). The library domain logic is writer-level. | W10, W12 | 2.9 |
| DA-G 6.3 | CRM client, file drop, platform batch, log path, metrics, workflow entanglement | **C** (clients, drops, log path), writer-level (entanglement, metrics) | W7, W9 (`logging_target`) | 2.9 |
| DA-G 6.4 | appSettings uncatalogued; expiry horizon key; a yearly maintenance checklist has no template row | **C** | W11 `config-year-horizon` (summary-only), template §16.x maintenance row, W9 `maintenance` topic | 2.8 / 2.9 |
| DA-G 6.5 | Test project absent; CI runs no tests | **C** | W8 | 2.9 |
| DA-G 6.6 | External docs, original docs folder, prior doc sets | **C** | W9, W10 | 2.9 |
| DA-S1 | A state-changing area has no role guard; any signed-in user can write | **C** | W4, W11 | 2.8 |
| DA-S2 | `machineKey` in `Web.config` (both keys literal) | **C** | W1, W11 | 2.8 |
| DA-S3 | Plaintext passwords in `Web.config`; the real exposure is larger (credentials in connection strings in the base file and every transform file) | **C** | W1, secret-location table | 2.8 |
| DA-S4 | Named users and IDs in access rules; also employee-ID and tester lists in appSettings (and the Release transform) | **C** | W2, W11 `identifier_list` | 2.8 |
| DA-S5 | Debug configuration deployed to lower environments; a compile-time mode constant used as a guard argument; ~30 runtime mode comparisons | **C** | W1 (effective config per configuration), W11 (`conditional_const`, `mode_branch`), W8 (CI half) | 2.8 / 2.9 |
| DA-S6 | 1 of ~72 POSTs anti-forgery protected | **C** | W11 | 2.8 |
| DA-S7 | Anonymous surface undocumented | **C** | W4 (all `no_app_restriction` handlers listed), stale-rule list | 2.8 |
| DA-S8 | Inconsistent role-exception arguments | Visible through the **guard argument shapes** table (V27) | access block | 2.8 |
| DA-S9 | External commit before local log | Writer-level; a cue (`multi_sink_handler`) is in W9 | W9 | 2.9 |
| DA-S10 | Duplicate appSettings key | **C** (transform files excluded) | W11 | 2.8 |
| DA-RC1 | `Web.config` excluded by the writer | **C** | C21 | 2.8 |
| DA-RC2 | Reading concentrated in ~12 files | **C** | C22 | 2.8 |
| DA-RC3 | Template drift between write and Check | **C** | W15, drift warning | 2.7/2.8 |
| DA-RC4 | Extractor scope unfiltered; false `node-express` stack from a front-end tooling manifest | **B** + **C** | W6 (server-dependency requirement), W10 | 2.8 / 2.9 |
| DA-RC5 | In-repo knowledge not harvested | **C** | W9, C23 | 2.9 |
| DA-RC6 | No source-to-claim pass | **A** | — | — |
| DA-SR1–SR9 | Skill recommendations | Mapped to C21, C22, W11, W10, W9, 2.7 §3.7, (A), drift, W14. SR2's 90% coverage threshold is not adopted (R8); C22 gates the security-relevant subset. | — | — |

**Known limit (state it in the README and ADR 0019).** The security work is .NET Framework and ASP.NET Core mechanism only. The same failure class (an access matrix in config, an external guard, an environment-switched mode) exists in Spring and Express, and nothing here detects it. R16 is generic in wording only.

---

## 2. Root causes (continuing RC-A…RC-E of 2.5)

| # | Root cause | Findings | Fixed by |
|---|---|---|---|
| RC-F | **Security-bearing config is optional input.** `generic._dotnet_config` reads only `appSettings` and `connectionStrings`. | DA-E1, S2, S3, S5, RC1 | W1, W2, W13, C21 |
| RC-G | **Authorization is extracted as attribute hits, not as effective protection.** Custom guards, base classes, filters, URL rules and the principals they admit are invisible, and absence is asserted in an open world. | DA-S1, S6, S7, E8, E9 | W3, W4 |
| RC-H | **Stack and handler classification errors.** `aspnet_core.detect` fires on any `.csproj` plus `Program.cs` and never consults `facts.is_test_path`; `node-express` fires on a tooling manifest; WinForms event handlers become web entry points; `[RouteArea]` is ignored. | DA-E10, false stacks, desktop "entry points", area-less routes | W5, W6 |
| RC-I | **Integrations by convention are not Facts.** | DA-E2, E4, G 6.3, G 6.5 | W7, W8 |
| RC-J | **In-repo documentation is not an input.** | DA-E3, E4, G 6.6 | W9, C23 |
| RC-K | **Coverage is advisory and per-file.** C13 fails only under `--strict`. | DA-G 6.1, RC2 | C22 |
| RC-L | **Scan counts mix source with data and prior documentation.** | DA-E10, RC4 | W10 |
| RC-M | **Upgrading is manual.** | DA-T1–T11, RC3 | W15 |
| RC-N | **Finding candidates are per-file text patterns only,** and none exists for classic .NET traps. | DA-S1, S5, S6, E5, E6, G 6.4 | W11 |
| RC-O | **Silent closed-set misses.** When a detector does not match a shape, the Facts say nothing, so "none" and "the detector ran and recognised nothing" look the same. | DA-E2 (spike) | detector accountability line (§6.6) |

---

## 3. Rules for this release

R1–R9 (2.5) and R10–R15 (ADR 0016; R13 no ambient inputs, R14 one normalisation, R15 deterministic tie-breaks) carry forward. Additions:

- **R16 Primary runtime config is mandatory input.** Values are redacted, never skipped. A file that holds security settings, access rules, external-config references or application-role keys must be cited with a line (RC-F). A file that could not be parsed must still be cited by path.
- **R17 Facts describe effective behaviour per build configuration.** A transform produces per-configuration detail; it never overwrites the base Fact. Configurations come from transform file names, the csproj and the sln. A configuration with no transform is the base (`config_status: base`). An effective value that depends on anything the extractor cannot evaluate is `unknown`, never the base value. The **production configuration** is `Release` (the MSBuild default name) unless `appdoc-context.md` declares `Production config: <name>`. Transforms run at publish or package time only, and only on the project-root `Web.config` (`effective_on: publish_or_package`). Deployment environments join to build configurations only through `ci_job.build_config` or a `publish_profile`, never by name (R3).
- **R18 Personal identifiers are counted, never recorded, in the new Fact kinds and in generated blocks.** User accounts in access rules, employee IDs in config, and names in README owner sections are counts and locations. Role and group names are recorded; role strings that look like an email or a SID are counted. The existing `ownership` Fact (git author names) predates R18 and is exempt; its removal is scheduled with the performance plan. Heading text is recorded only when it matches a closed topic. Secrets follow R18's twin, **R19**.
- **R19 Secret values and credential-bearing strings are never recorded or resolved.** A constant that is a `secret_location` Fact or whose name matches the secret-key rule is not value-resolved. URLs are recorded as `scheme://host[:port]`. CI `variables` are recorded by key name only. Unclassified script steps record the first token only. A conformance test asserts that no Fact detail equals the value of any `secret_location` Fact in the same run.
- **R20 Absence claims need a closed world.** "No guard", "no job runs tests" and "no application-layer restriction" are emitted only when every place the thing could live was read. Otherwise the Fact says `unknown` with a reason code. (A, I-3, I-9.)

- **R21 Extractor changes bump the cache salt** (from the 2.5 amendment; 2.6 §4.6 derives the salt from the bundle hash). Raw per-file Facts depend only on their own file, the detected stack ids and sibling names (V39).

Each of R16–R21 is a documented rule in ADR 0018/0019/0020 (§9).

---

## 4. Phase 0 — Reproduce and pin (do first, after 2.5/2.6 land)

### 4.1 Corpus layout (V36)

2.5 §0.2 defines `tests/corpus/<case>/`: a small Target plus a `docs/appdoc/` with a Narrative and register, red on the previous tag. This plan follows it.

- **Shared Targets** live in `tests/corpus/_targets/`, referenced by cases through one helper in `tests/test_corpus.py`. `mvc5-classic` is one, with variants as overlays (`+owin`, `+core`, `+webapi`) so a case does not copy the whole tree.
- **Extractor cases** (assert Facts) point at a Target and a variant.
- **Check cases** (assert Check output; `config-not-reviewed`, `area-coverage`, `upgrade-2-1`) carry their own `docs/appdoc/` with Narrative, register and stamp.
- The invented Target copies **no** CMU code or identifiers.

### 4.2 `mvc5-classic` Target

Invented names, reproducing the real shapes found by the spike:
- Areas in three `RouteArea` styles (positional name plus `AreaPrefix`; `AreaPrefix` only; empty name and empty prefix on a root controller), plus conventional area registration. One area writes files with no guard and no `<location>` rule; one is role-gated by a `<location>` rule; one uses class-level `[AllowAnonymous]`; one has a controller whose namespace names a different area than its folder.
- An external custom guard attribute (not declared in the Target) with 5 positional arguments (role const, build-mode const, group const, service-account name const, **service-account credential const**) or 4; used on ≥3 controllers; also stacked with `[Authorize]`. A base-controller helper `HasRole(user, roleA, groupB)` called in bodies, passing the same constants. A second external attribute used on ≥3 controllers that is *not* a guard (layout injection).
- A compile-time mode constant selected by `#if DEBUG / STAGING` in the application class (which has no `auth_check`) and used as a guard argument elsewhere; `#if DEBUG` blocks assigning locals in handler files; a `Mode == Production` comparison wrapping a role check.
- `Global.asax`, `FilterConfig` with only the error filter, an in-Target `BaseController` deriving from an **external** base class, a base `OnActionExecuting` that only redirects.
- `Web.config` (UTF-8 **with BOM**; a lower-case `web.config` in one area): `authentication mode="Windows"`, root `<authorization>` (roles, two named users, `deny *`), 15 `<location>` blocks (four `allow *` only; four `allow ?` then `allow *`; four `deny ?` then `allow *`; three roles plus users then `deny *`; two naming folders that no longer exist), literal `machineKey`, `customErrors Off`, `compilation debug="true"`, a duplicate appSettings key, 7 identifier-list keys, an expiry-year key, a connection string with a literal credential, and one `system.serviceModel/client/endpoint` (address with userinfo and query, to prove stripping).
- `Web.Debug.config` (changes no security element), `Web.Staging.config` (removes debug only), `Web.Release.config` (removes debug, `RemoteOnly`, replaces root authorization with `deny ? / allow *`; `SetAttributes` with and without an attribute list; `RemoveAll` with no locator; `Insert`; `Match(name)`, `Match(key)`), and `Web.Odd.config` (an `XPath(...)` locator and an `InsertAfter`, to prove `unknown`). Transforms use the `xdt` namespace under a non-`xdt` prefix in one file.
- `Areas/Reports/Web.config` with its own `<authorization>`; a `Web.config` under a folder that routed URLs *do* use.
- A csproj with `DefineConstants` per configuration, a `Properties/PublishProfiles/*.pubxml` (and a `*.pubxml.user` that must never be read), a configuration with no transform file.
- An OWIN `Startup` variant (`+owin`, auth mode `None`), an ASP.NET Core variant (`+core`, `AddAuthorization` present) and a Web API variant (`+webapi`).
- A WinForms harness project (`OutputType WinExe`, `[STAThread] static void Main`, hard-coded production-mode assignment), a console `Exe` that is a Core web app (must **not** be desktop), and a test project (old-style `Reference`+HintPath, `[TestMethod]`).
- `fixtures/sample-core-app/` (not under `tests/`), `tests/powershell/fixtures/sample-app/`, and a front-end tooling `package.json` with only type-definition dev dependencies.
- (2.9) `.gitlab-ci.yml` (8 jobs, `only:` lists with regex literals, trailing comments after keys, `$env:NAME` configuration variables, one undefined variable, `Debug` deployed to two environments, no test job; a second file with `extends:`/`include:`), a README with owner and environment tables and two HTML-commented placeholder owners, a "Logging Information" heading and a README table of branches the CI file does not use, an `External Documentation/` folder, a `docs_v1/` folder with v1 output, a content folder of 400 XML files plus an XSD, and a sibling folder of scripts copied from another tool.

### 4.3 Corpus cases (all red on the previous tag)

Cases marked † are 2.9. The full test list for each item is in the item.

| Case | Asserts |
|---|---|
| `webconfig-security` | `security_setting` Facts per configuration with `config_status`; machineKey class; secret locations with no value; BOM and CRLF line numbers |
| `xdt-effective` | Supported transforms applied (`Insert` order, first-match `Replace`, no-argument `SetAttributes`, locator-less `RemoveAll`); `Web.Odd.config` gives `unknown_transform` and no derived claim; prefix-independent namespace; a configuration with no transform is `base` |
| `url-auth-merge` | Chain evaluation: allow-roles-only falls through; first match wins; child before parent; location before own authorization; `verbs`; `<clear/>`/`<remove>`; implicit `allow *`; named user gives `unknown` |
| `location-paths` | `path` forms (`.`, empty, absent, `~/`, case, segment boundary); `allowOverride`; `<location>` with only `system.webServer` not read as authorization |
| `nested-webconfig` | A nested rule applies to routed URLs by prefix; a `Areas/X/Web.config` rule does not apply to the area's routed URL; `.aspx` by file URL |
| `route-aliases` | Default-route alias URLs all checked; open route gives `url_set_open` |
| `filter-composition` | Method, class, base and global filters ANDed; `[AllowAnonymous]` on a controller disables action `Authorize` but not a URL deny; `[OverrideAuthorization]`; unresolved base gives `unknown`; `Roles` plus `Users` on one attribute |
| `custom-guard` | External guard is a candidate; declared via `appdoc-context.md` it is `auth_check via=declared` with arity; **the credential constant is never resolved**; `auth_method` promotion lists all role constants; argument-shape table |
| `windows-auth-iis` / `owin-none` | IIS anonymous `unknown` is disclosed; OWIN with mode `None` is `unknown`; csproj IIS Express values never used |
| `core-fallback-policy` | `aspnet_core` has mechanism Facts and no reach; absence claim only when no auth services are registered |
| `verbless-actions` | Verb-less action is `any`; `state_changing` is tri-state; Web API name convention |
| `route-area` | Three `RouteArea` styles; empty name is root (no `area_path`); registration literal, not folder name; tilde routes; `[Route]` excludes conventional |
| `core-false-positive` / `stack-markers` | No `aspnet-core` or `node-express` stack from the sample projects; project-file based detection; `ignored_markers` |
| `winforms-handlers` | No web `entry_point` from WinForms; one `type=desktop` for `WinExe`; Core web `Exe` is not desktop |
| `build-defines` / `publish-profile` | `DefineConstants` per configuration; `.pubxml` maps configuration to host only; `.pubxml.user` never read |
| `antiforgery-variants` | Custom attribute calling `AntiForgery.Validate`, in-body validation, inherited class-level, `ApiController` excluded, MVC 5 has no built-in global filter |
| `smells-net` | One hit per 2.8 pattern and none on the negative fixtures (the false-positive shapes from the spike: read-only POST, redirect-only stub, `allow *` data API) |
| `smells-from-facts` | Facts-level pass: stable `fid` across two runs; reads no source |
| `secrets-never-recorded` | No Fact, block or summary contains a secret value; roles with email or SID are counted |
| `config-not-reviewed` | C21 fails when `Web.config` is cited without a line, or only via section 16.6; passes with a lined citation outside generated blocks |
| `area-coverage` | C22 fails when an `mvc_area_path` is missing from 4.1 |
| `upgrade-2-1` | `appdoc upgrade` brings a 2.1 document to a state that fails only on content rules |
| `config-client`, `unc-drop`, `share-key`, `ci-jobs`, `ci-fail-safe`, `readme-topics`, `v1-output`, `content-folder`, `xsd-format` † | See W7–W10, W12 |

### 4.4 Private acceptance target

`tools/acceptance.py` (stdlib only; local, private; not in CI) runs against a local DegreeAudit checkout and the answer key outside the repository. Every group-C row in §1 must be produced as a Fact, a candidate, a block line or a Check problem (§11). The environment variable uses the one prefix `APPDOC_` (`APPDOC_ACCEPTANCE_KEYS`) and is listed with the other documented switches (R13).

### 4.5 Feasibility spike (done; the work is folded in)

Review C read the real code for every acceptance row. Its results are in this revision (V20–V37). Four planned detectors did not match the real shape and were redesigned: the file-drop rule, the compile-time mode rule, `debug-settings-deployed` and the role-coverage list. Spike notes with DegreeAudit specifics stay in a private file. Remaining spike work (0.25 d) is to re-run the spike on any detector whose specification changes again.

---

## 5. Phase 1 — Extractor (schema: next after 2.7's, expected `appdoc-facts/8`; re-check at start)

Every new kind is added to `facts.KINDS` **and** `facts.DETAIL_KEYS`. **Detail values are scalars or sorted lists of scalars; dicts are rejected** (`Fact.make` raises; test `test_facts::test_dict_detail_rejected`). A post-pass that adds detail **rebuilds** the Fact with `Fact.make`, as the config-role promotion in `extract.extract`'s post-pass does.

**Capability attribution (B I5).** `generic` is not a registered Stack and emits no `stack` Fact, so it can declare no capability. The rule:
- Kinds emitted by `generic.extract` (`project`, `build_define`, `publish_profile`, `config_external`, `config_unparsed`, `context_directive`, and in 2.9 `ci_job`, `doc_file`, `test_suite`, `xsd_schema`, `logging_target`, `share`) are exempt from the per-stack capability conformance, listed once in `tests/test_conformance.py::GENERIC_KINDS`, like `dependency` and `config_key` today. Blocks fed by them say "read by the generic reader", not "no supported Stack".
- `security_setting`, `access_rule`, `config_transform`, `auth_check`, `guard_candidate`, `entry_point.*` detail and `type=desktop` are emitted through the `aspnet` and `aspnet_core` stacks (the `.config` reader is a shared module called by them, R5) and declared as 2.6 §4.1 class-level capabilities: `entry_point.guard_mechanism` (both), `entry_point.guard_reach` (`aspnet` only), `entry_point.desktop` (`aspnet`), `security_setting`, `access_rule`, `config_transform` (`aspnet`).
- `aspnet.detect_in(paths, root)` (the hook `extract.extract` already calls; `node_express` implements it as the model) reads project files so a Web.config-only or Web API-only classic project is detected. **Detect state is returned explicitly**, never stashed on `self` (`ignored_markers`, project info), so the performance plan's process pool needs no rework.

### W13 Foundation: raw per-file Facts and the shared config reader

Stack extraction is per file (`Stack.extract(path, text)`); `guard.py` and `smells.from_facts` read Facts only. Every cross-file input must therefore be a **raw Fact emitted per file**, and joins happen only in post-passes. Because `dumps` sorts all Facts by `sort_key` and dedupes, post-pass order cannot change bytes (P3).

| Raw Fact (per file) | Carries | Used by |
|---|---|---|
| `entry_point.inherits` (controllers) and a `controller_class` marker (class line, base list, `base_external`) | base-class chain, anchor line for per-controller hits | W4, W11 |
| `auth_check mechanism=global-filter` | `filters.Add(new X())` from any method that receives `GlobalFilterCollection`, `GlobalFilters.Filters.Add(...)` in `Global.asax.cs`, Web API `config.Filters.Add(...)` | W4 |
| `guard_class` | a Target class deriving from an authorization-capable type, with base list, and whether it overrides `AuthorizeCore`/`OnAuthorization` | W3, W4 |
| `guard_use` | attribute name, scope (method/class), arity, argument kinds, `role_ref`, the namespace resolved by `using` | W3, W4, shapes table |
| `const_def` | `const`/`static readonly` string, qualified name, `value` **unless** the constant is a secret (R19), `under_if: [symbols]` | W3, W11 |
| `method_call` for promoted helpers | a call whose arguments include ≥2 constants that also appear as guard-attribute arguments | W3 |
| `project` | path, `output_type`, `sdk`, kind (`web|winforms|console|test|library`), test-framework flag, web-framework flag; from `generic._csproj`, which today yields only dependencies | W6, W1, W8 |
| `build_define` | per-configuration `DefineConstants` tokens; `inherits: true` for `$(DefineConstants)` | W11 |
| `publish_profile` | name, `build_config`, method, **host only** (never user, password, tokens, path, query; `*.pubxml.user` is never read) | W1, W8 |
| `config_transform` | per transform element: operation, locator kind, target path, and for the closed security elements the attribute values; recognised-but-unsupported operations flagged | W1, W2 |
| `config_external` | `configSource` or `appSettings file=`: element, target file, resolved yes/no | W1 |
| `config_unparsed` | `reason` in `dtd|oversize|malformed|encoding` | W1, C21 |
| `context_directive` | one per `appdoc-context.md` directive (`Ownership:`, `Auth attributes:`, `Production config:`, `Reference year:`, and 2.7's `Audit floor:`) | W3, W11, 2.5, 2.7 |

**`appdoc/context.py`** is the single parser for `appdoc-context.md` (today only the `OWNER_CONTEXT` constant exists). It runs in `extract.py` before the post-pass, emits `context_directive` Facts, and is shared with 2.5 §1.4 and 2.7. A directive naming a thing that does not exist gives a disclosed `context_unmatched` note, not an error (R3).

**`appdoc/dotnetcfg.py`** (stdlib, R7) is the shared reader for `Web*.config`, transforms, `app.config`, csproj and pubxml:
- Reads **bytes** into `xml.parsers.expat` (`namespace_separator=" "`), honours BOM and the XML declaration, and records `CurrentLineNumber` in the start handler. Fact lines point to the **start tag**.
- Rejects the file with `config_unparsed reason=dtd` when the raw bytes contain `<!DOCTYPE` or `<!ENTITY`; caps size (2 MiB; 8 MiB hard) and depth; never uses `minidom` or `lxml`; malformed XML yields one `config_unparsed` and no partial tree.
- Strips the namespace from config element names (old `xmlns=".NetConfiguration/v2.0"` files), matches XDT attributes by namespace URI (both `http` and `https` forms), never by the literal prefix `xdt`.
- Comments and CDATA never become elements (a commented-out rule is not a Fact).
- File names are matched case-insensitively (`web.config`).
- Values are lower-cased before the **per-attribute** closed enumeration test (`sessionState@mode`: `off|inproc|stateserver|sqlserver|custom`; `httpRuntime@requestValidationMode`: `2.0|4.0|4.5`; `authentication@mode` adds `passport`).
- `Fact.line` for a missing attribute points to the element.

**Tests:** `test_facts::test_dict_detail_rejected`; `test_context::test_directives_parsed_once`, `::test_unmatched_directive_disclosed`; `test_dotnetcfg::test_doctype_rejected`, `::test_entity_bomb_not_expanded`, `::test_oversize_skipped_with_reason`, `::test_line_number_of_multiline_start_tag`, `::test_commented_rule_not_a_fact`, `::test_line_numbers_survive_crlf_and_bom`, `::test_namespaced_config_read`, `::test_xdt_namespace_not_prefix`, `::test_filename_case_insensitive`, `::test_malformed_gives_one_unparsed`, `::test_enumeration_per_attribute`; `test_conformance::test_generic_kinds_listed`, `::test_no_hidden_detect_state`. No new `self` state in any `detect()` (B M6).

### W1 .NET configuration settings (RC-F → DA-E1, S2, S3, S5) — 2.8

**Change.** The reader (W13) emits **`security_setting`**: `name` (`system.web/authentication@mode`), `value` (closed per-attribute enumeration or `other` or `absent`), `config` (a configuration name), `config_status` in `base|transformed|unknown_transform|unknown_external`, `secret_location`, `reason`, `local_only` (for `trace`).

1. **Closed element set.** `authentication@mode`; `forms@requireSSL` and `forms/credentials`; `machineKey`; `customErrors@mode`; `compilation@debug`; `httpCookies@requireSSL/httpOnlyCookies`; `sessionState@mode/cookieless/sqlConnectionString`; `trace@enabled/localOnly`; `httpRuntime@requestValidationMode`; `identity@impersonate/userName/password`; `httpErrors@errorMode`; `system.net/mailSettings/smtp/network@password`; `processModel@userName/password`.
2. **Missing is not off.** An absent element records `value: absent`; framework defaults appear only in the block's "Defaults (documentation, not a Fact)" note with the caveat that machine-level config can change them.
3. **`machineKey` class**: `autogenerate | literal_hex (^[0-9A-Fa-f]{32,128}$) | placeholder (#{...}, ${X}, $(X), __X__) | absent_keys | other`. Only `literal_hex` is `secret_location` and feeds `machinekey-in-config`. No value is ever recorded.
4. **Credential carriers.** Any attribute above that can hold a password or connection string sets `secret_location: true` with no value. Connection strings with a literal `Password=` or `User ID=` are counted per file (feeds the secret-location table, W11/§6.1).
5. **External config.** `configSource` and `appSettings file=` produce `config_external`. The target is read when inside the Target and relative; otherwise everything derived from that element is `unknown_external`. An external `appSettings file=` value wins over the inline value (so `duplicate-config-key` is skipped for a key that the external file may override).
6. **Configurations (R17).** The set is: transform file names, csproj `Condition="'$(Configuration)|$(Platform)'=='X|Y'"` groups, and the sln `SolutionConfigurationPlatforms`. For each configuration, effective values are computed by applying `config_transform` Facts to the base in the order below. A configuration with no transform is `config_status: base`. The `Debug` configuration is a configuration like any other.
7. **Transform semantics (closed, V23).**
   - Supported operations: `Replace`, `Remove`, `RemoveAll`, `RemoveAttributes`, `SetAttributes` (with **and without** an attribute list: all attributes), `Insert`.
   - Recognised and **unsupported** (result `unknown_transform`): `InsertBefore(XPath)`, `InsertAfter(XPath)`, `InsertIfMissing`, any locator other than none, `Match(a[,b])`, `Condition` (restricted to a single `@attr='literal'`; `and`-joined conditions are unsupported), and any `XPath(...)`.
   - `Insert` **appends at the end of the sibling collection**; for `<authorization>` the inserted rule lands after existing rules, including after `allow *`. `Replace` and `Remove` act on the **first** match; `RemoveAll` on all matches. A transform element without a locator targets the element at the same path. `Match` compares attribute strings **exactly**; URL evaluation (W4) normalises paths separately.
   - When any transform that touches an element cannot be applied, the effective value of that element and everything derived from it is `unknown_transform` for that configuration. The base Fact stays `config: base`.
   - `ProjectConfigTransformFileName` in a csproj makes transform lookup `unknown`.
   - Transforms apply only to the **project-root** `Web.config`, at publish or package time. A nested `Web.config` gets none (SlowCheetah or custom targets are not read). The block prints "effective on publish or package only".
   - Transform-file elements alone are never a configuration (they feed the computation, not patterns).
8. **Per-configuration non-security values.** For every `Match(key)` or `Match(name)` target the reader emits `overridden_in: [configs]` (no values) on the base `config_key` or `connection`, so the writer knows which keys differ per configuration.
9. **WCF client endpoints.** `system.serviceModel/client/endpoint` gives `external_call type=service via=<contract> config_key=<endpoint name>`. The address is recorded as `scheme://host[:port]` only (userinfo, path and query dropped). `clientCredentials` elements are `secret_location` with no value.
10. **Host and OWIN disclosure (A C-3).**
    - `host_auth`: `iis_anonymous: unknown|enabled|disabled` with `source: none|config|csproj_dev_only`. `enabled|disabled` only when a read file literally sets `system.webServer/security/authentication/anonymousAuthentication@enabled`. csproj `IISExpress*` and `.vs/config/applicationhost.config` are recorded as `csproj_dev_only` and never used in reach.
    - `owin_auth: true|false`: `Microsoft.Owin` packages or an `IAppBuilder`/`Startup` class calling `UseCookieAuthentication|UseOpenIdConnectAuthentication|UseWsFederationAuthentication|UseOAuthBearerAuthentication|UseWindowsAzureActiveDirectoryBearerAuthentication|UseJwtBearerAuthentication`.
    - `iis_authorization_present` when a `<location>` or file contains `system.webServer/security/authorization` (read as IIS rules, not evaluated).
11. `facts.DETAIL_KEYS["security_setting"] = {"value","config","config_status","secret_location","reason","local_only","overridden_in"}`.

**Why this is not a weakening:** new Facts only.

**Tests** (`test_dotnetcfg`/`test_generic_facts`): `::test_system_web_settings`, `::test_machinekey_classes`, `::test_machinekey_literal_no_value`, `::test_missing_element_is_absent_not_default`, `::test_transform_release_sets_customerrors`, `::test_transform_remove_debug`, `::test_setattributes_no_arglist`, `::test_removeall_no_locator`, `::test_insert_appends_after_existing_rules`, `::test_replace_first_match_only`, `::test_unsupported_transform_makes_effective_unknown`, `::test_insertbefore_after_unknown`, `::test_config_without_transform_is_base`, `::test_configs_from_csproj_and_sln`, `::test_debug_config_computed_like_any_other`, `::test_nested_webconfig_no_transform`, `::test_transform_file_alone_not_a_configuration`, `::test_configsource_unknown_external`, `::test_appsettings_file_override`, `::test_overridden_in_keys_no_values`, `::test_wcf_address_stripped_to_scheme_host`, `::test_wcf_client_credentials_secret_location`, `::test_host_auth_unknown_by_default`, `::test_iis_express_csproj_not_used`, `::test_owin_auth_detected`, `::test_trace_local_only_recorded`. Corpus `webconfig-security`, `xdt-effective`, `windows-auth-iis`, `owin-none`, `build-defines`, `publish-profile`.

### W2 Access rules from `<authorization>` and `<location>` (RC-F, RC-G → DA-S4, S7) — 2.8

**Change.** Emit **`access_rule`** per `<allow>`/`<deny>`/`<clear/>`/`<remove>` with detail: `scope_path` (the URL-space prefix: the file's folder prefix joined with `location@path`), `effect`, `order` (document order within its file), `verbs` (list; empty = all), `roles` (names as written, lower-cased for matching), `anon` and `all` flags (a set; `users="?,*"` is legal), `users_named` (a **count**, split on `,`, trimmed, deduplicated case-insensitively), `config`, `config_status`, `allow_override`, `inherit_in_child_apps`, `file` (the config file), `reason_codes`.

1. **`location@path` forms.** Relative to the config file's folder; `/` separators; may name a folder, a file, or a route-like path with no folder on disk. `.`, empty and an absent `path` mean "this folder and below". Strip a leading `~/` or `/` and a trailing `/`. Case-insensitive; matching is on **segment boundaries** (`Admin` does not match `/AdminTools`). No wildcards.
2. **No `applies: url|physical` split (V24).** ASP.NET resolves configuration from the request URL path. A nested `Web.config` in folder `Admin/` applies to every URL under `/Admin/`, including routed MVC URLs; a `Web.config` in `Areas/X/` applies to `/Areas/X/…` and **not** to the area's routed URL `/X/…`. W4 builds the chain by prefix-matching each rule's `scope_path` against the handler's URL set.
3. **`allowOverride="false"`.** Nested rules below that path are not merged for that section; if a nested rule exists below a locked path the result is `unknown`. `inheritInChildApplications="false"` is recorded and disclosed (it cannot be evaluated from the repository).
4. **A `<location>` without `<system.web>`**, or with `<system.webServer>` only, is not read as ASP.NET rules (`iis_authorization_present` records IIS rules).
5. **Stale rules.** `access_rule_unmatched`: a rule whose `scope_path` matches no route prefix and no folder in the Target (summary-only, DA-G 11 in the spike).
6. **Role and user hygiene (R18).** Role strings that contain `@` or match a SID shape (`S-1-5-21-…`) are counted as users and not recorded. `DOMAIN\X` role values are recorded with `domain_qualified: true`.

**Tests:** `::test_location_rules`, `::test_rule_order_recorded`, `::test_verbs_recorded`, `::test_clear_and_remove_recorded`, `::test_named_users_counted_not_recorded`, `::test_users_flags_set`, `::test_roles_email_or_sid_counted_not_recorded`, `::test_root_rule_transformed`, `::test_location_path_dot_and_absent`, `::test_location_segment_boundary`, `::test_location_case_insensitive`, `::test_allow_override_false_marks_unknown`, `::test_location_system_webserver_not_read_as_authorization`, `::test_unmatched_rule_listed`. Corpus `location-paths`, `nested-webconfig`.

### W3 Authorization attributes and guard methods (RC-G → DA-E8, E9) — 2.8

**Change** (`stacks/aspnet.py`, `stacks/aspnet_core.py`; raw Facts from W13).
1. **In-Target guards.** A Target class deriving from `AuthorizeAttribute`, `AuthorizationFilterAttribute`, or implementing `IAuthorizationFilter`/`IAsyncAuthorizationFilter` is a `guard_class`. Its uses are `auth_check via=custom`. **A custom or declared guard is a role guard only if** the use carries a literal `Roles=` or `Users=` argument **and** the class does not override `AuthorizeCore`/`OnAuthorization`/`AuthorizeAttribute` members; otherwise its filter result is `unknown`. An owner declaration claims the attribute is a guard, not what it admits.
2. **External guards.** An attribute used on ≥3 controller classes or actions that is neither framework-known nor declared in the Target is a `guard_candidate` (name, use count, arity set). The summary lists them under **Unclassified controller attributes**. A non-guard attribute used on ≥3 controllers (layout injection) appears here too; the question is the point (R3).
3. **Owner declaration** (`appdoc-context.md`, `Auth attributes: A, B`, parsed by W13's `context.py`) promotes names to `auth_check via=declared`.
4. **Arguments.** String literal → `role` (only from `Roles=` or a positional role argument; `Users=` gives `users_named: N` only). `const`/`static readonly` reference → `role_ref` (qualified name), plus `role` (value) **only when** the constant is a string literal in the Target, **is not a `secret_location` Fact, and its name does not match the secret-key rule**. A secret constant gets `arg_kind: secret` and **no value** (R19; this is the leak the spike found). Anything else: `role_ref: expression`. Record **arity** per use. Email and SID values are counted, not recorded.
5. **`auth_method` promotion (no name guessing).** A method is an `auth_method` candidate when a call to it passes ≥2 constants that are also arguments of a guard attribute (shape `Helper(user, ROLE_A, ROLE_B)` next to `[Guard(ROLE_A, mode, ROLE_B, …)]`). All its calls are `auth_check via=call`; every constant they reference is listed (so all role constants, not only the three that appear in attributes); in-body checks count in W4 as mechanism `inbody`, never `none`.
6. **Guard argument shapes.** Generated table (§6.1): distinct `(attribute, argument-kind tuple)` with use counts; a method-level use that overrides a class-level use with a different arity is marked. This makes inconsistent role arguments (DA-S8) visible.
7. **Web API vs MVC.** `System.Web.Http.AuthorizeAttribute` and `System.Web.Mvc.AuthorizeAttribute` are told apart by `using`. `[Authorize]` on an `ApiController` under bearer-token auth is a separate pipeline (`api_pipeline: true`) and is not mixed with MVC.

**Tests:** `::test_in_target_authorize_subclass`, `::test_subclass_overriding_authorizecore_is_unknown`, `::test_guard_candidate_threshold`, `::test_nonguard_attribute_listed_as_candidate`, `::test_declared_auth_attribute`, `::test_declared_guard_without_args_is_unknown_reach`, `::test_const_role_argument_name_and_value`, `::test_secret_constant_not_resolved`, `::test_users_argument_counted_only`, `::test_arity_recorded`, `::test_non_literal_role_argument`, `::test_auth_method_promotion_lists_all_constants`, `::test_argument_shapes_table_rows`, `::test_webapi_vs_mvc_authorize_by_using`; `test_conformance::test_no_auth_value_equals_secret_location`. Corpus `custom-guard`, `secrets-never-recorded`.

### W4 Effective protection per handler (RC-G → DA-S1, S6, S7, G 6.1) — 2.8

**Change** (`extract.py` post-pass; one implementation in `appdoc/guard.py`; reads Facts only).

**Scope (V33).** `guard_mechanism` (a sorted list) is reported for `aspnet` and `aspnet_core`. `guard_reach` is computed for the `aspnet` stack only. For `aspnet_core` and every other stack, no `reach` and no `guard: none`; only mechanism Facts and `allow_anonymous`. For `aspnet_core`, an absence claim ("no authentication or authorization services registered") is made only when none of these tokens exists in the Target: `AddAuthorization|AddAuthentication|UseAuthorization|UseAuthentication|RequireAuthorization|FallbackPolicy|AuthorizeFolder|AuthorizePage|AuthorizeAreaFolder|AuthorizeFilter|AddMicrosoftIdentityWebApp|AddJwtBearer|AddNegotiate|AddCookie`. Web Forms `.aspx` and `.ashx`/`.asmx`/`.svc` handlers: URL authorization applies by file URL (and `MapPageRoute` URLs, which are checked against both the route URL and the physical URL); `.ashx/.asmx/.svc` handlers are not evaluated and the block says so.

**Entries evaluated.** Only entries whose `handler` resolves to a class in the Target. Conventional `MapRoute` Facts with no controller file get no reach. An action with any `[Route]` is reachable only by its attribute routes; otherwise by conventional routes. `[NonAction]`, `[ChildActionOnly]`, private and protected methods are not entry points.

**Step 1: the URL set.** One MVC action can be reachable at several URLs (the default route `controller=Home, action=Index` reaches `/`, `/Home`, `/Home/Index`; extra path segments still match a prefix rule; a rule on `Home/Index` does not protect `/Home`). Reach must hold for **all** URLs and the most permissive result wins. If a route template has a non-literal leading segment that cannot be expanded (`{*path}`, `{culture}/…`, regex constraints, custom `IRouteConstraint`, `MapMvcAttributeRoutes` with tokens), `url_set: open` and the result is `unknown` (`reason: url_set_open`).

**Step 2: URL authorization, evaluated as a chain (V20).** For a (principal, verb, URL):
1. Build the rule chain, nearest first. For each config file whose folder prefix is a prefix of the URL, deepest folder first: that file's `<location>` blocks whose resolved path is a segment prefix of the URL (more segments first; ties by document order, R15), then the file's own un-located `<authorization>`. Apply `<clear/>` and `<remove …/>` as they occur in that merged order. Append the implicit machine rule `allow *` as `implicit_default` (not a Fact from a file).
2. Principals (closed): `anon` (unauthenticated); `auth` (authenticated, in no role the repository names, not a named user); `role:<R>` for every role name R that appears in an `access_rule` or an auth attribute (capped, N of M).
3. Verbs: the handler's verb set (below); `any` evaluates `GET` and `POST`.
4. Walk the chain. A rule matches when its `verbs` includes the verb (or is absent) and its `users`/`roles` match the principal: `?` matches `anon`; `*` matches all; a role entry matches `role:<R>` by case-insensitive equality; a named user matches **no** archetype, and a named-user rule before the first decisive rule makes the result `unknown`. **First match decides.** A rule that cannot be evaluated for the archetype (a role not in the probe set) gives `unknown` unless an earlier rule decided.
5. The result is `unknown` when the effective config for the URL depends on an unsupported transform, an unread `configSource`, a locked `allowOverride`, or an unparsed file.
6. Result per (principal, verb, URL): `allow|deny|unknown`.

**Step 3: filters, ANDed (V21).** The filter-level result is the AND of every applicable `AuthorizeAttribute`-family attribute on the method, the class and **every in-Target base class**, and the global filters (an authorization-capable type; `HandleErrorAttribute` is a global filter that is not a guard). Within one attribute, `Roles="A,B"` is OR; `Roles` plus `Users` on one attribute are AND. `[AllowAnonymous]` on the action **or the controller** disables only `AuthorizeAttribute`-family checks (MVC 5). `[OverrideAuthorization]` clears outer authorization filters at its scope. A custom or declared guard follows W3.1. Global registrations are found in `FilterConfig.RegisterGlobalFilters`, in `Global.asax.cs`, and in any method receiving `GlobalFilterCollection`.

**Step 4: unknowns (R20).** `guard_mechanism` gains `unknown` (with a reason) and the filter result is `unknown` when: the class or an in-Target base class has an **unresolved base type** not declared in the Target and not a framework `Controller`/`ApiController`/`ControllerBase` (`base_external: true`); the class or any in-Target base overrides `OnActionExecuting|OnAuthorization|Initialize|OnResultExecuting|Execute|BeginExecute` with a body that is not a pure redirect; the method body contains `User.IsInRole(`, `User.Identity.IsAuthenticated`, `HttpUnauthorizedResult`, `Roles.IsUserInRole(`, `WindowsPrincipal` or `[PrincipalPermission]` (promoted `auth_method` calls count as mechanism `inbody`); or the Target has `FilterProviders.`, `IFilterProvider` or DI filter-provider registration outside the parsed registrations. **An undeclared `guard_candidate` stacked with `[Authorize]` is `unknown`, never downgraded to `authenticated`.**

**Step 5: reach.** Per principal, `reach_<p>` = AND of the URL result and the filter result: `allow` only if both allow, `deny` if either denies, else `unknown`. The summary label (closed): `no_app_restriction` iff `reach_anon=allow`; else `signed_in_any` iff `reach_auth=allow`; else `role_restricted` iff some `reach_role` allows; else `unknown` if any result is `unknown`; else `denied`. "Possible", never "is". The block prints the three archetype results, not only the label.

**Step 6: host and OWIN.** The label's wording and `reasons` carry `iis_anonymous_unknown`, `owin_present` or `host_auth_set`. When `owin_auth` is true, auth mode `None` and "no rule" do not produce `no_app_restriction` from the mode: the label is `unknown` (`reason: owin`). With Windows or Forms mode, no rule and no attribute, the label is `no_app_restriction` with `reason: iis_anonymous_unknown`.

**Step 7: verbs and writes.** `verbs` is a closed list and `verbs_declared: true|false`. A verb-less MVC 5 action accepts every verb (`any`). `state_changing` is tri-state: `true` (declared POST/PUT/PATCH/DELETE; or `any` with a write hit), `false` (declared GET/HEAD only and no write hit), `unknown` (verb-less with no write hit). A write hit is the existing `state-change-on-get` smell Fact, joined on `(path, handler)` through the controller anchor. Web API maps verbs by method-name prefix (`Get|Post|Put|Delete|Patch|Head|Options`) as a closed table. `writes: true` when the handler's line span contains an `external_call` (file, SMTP, service) or a `data_access` write; used to rank candidates (the spike found many read-only JSON POSTs).

**Detail keys.** `guard_mechanism` (list), `reach`, `reach_anon`, `reach_auth` (`allow|deny|unknown`), `reach_roles` (names allowed), `reach_by_config` (sorted list of `"<config>=<label>"`, only when more than one configuration is evaluable), `reasons` (list), `state_changing`, `verbs`, `verbs_declared`, `writes`, `url_set`, `base_external`. All are scalars or sorted lists.

**Why this is not a weakening:** derived detail on existing Facts; `unknown` is never collapsed into `none` or `allow`.

**Tests** (`test_core`): `::test_url_auth_allow_roles_only_falls_through`, `::test_url_auth_first_match_wins`, `::test_url_auth_child_before_parent`, `::test_url_auth_location_before_own_authorization`, `::test_url_auth_tie_break_document_order`, `::test_url_auth_verbs`, `::test_url_auth_clear_remove`, `::test_url_auth_default_allow_star`, `::test_url_auth_named_user_precedes_gives_unknown`, `::test_nested_webconfig_applies_to_matching_route_prefix`, `::test_area_folder_webconfig_does_not_apply_to_area_route`, `::test_nested_webconfig_applies_to_aspx_by_file_url`, `::test_mappageroute_both_urls`, `::test_default_route_alias_urls_all_checked`, `::test_open_route_gives_unknown`, `::test_filters_and_class_and_method_are_anded`, `::test_allow_anonymous_on_controller_disables_action_authorize`, `::test_allow_anonymous_does_not_override_url_deny`, `::test_override_authorization_clears_outer`, `::test_unresolved_base_gives_unknown`, `::test_authorize_roles_and_users_on_one_attribute`, `::test_two_authorize_attributes_anded`, `::test_global_filter_in_global_asax_found`, `::test_inbody_isinrole_gives_unknown_not_none`, `::test_base_onactionexecuting_override_gives_unknown`, `::test_undeclared_candidate_with_authorize_is_unknown`, `::test_filterprovider_registration_gives_unknown`, `::test_reach_iis_anonymous_unknown_is_disclosed`, `::test_owin_none_mode_is_unknown`, `::test_windows_mode_no_rules_label_with_reason`, `::test_reach_authenticated_from_release_root_rule`, `::test_reach_by_config_only_with_several_configs`, `::test_production_config_declared`, `::test_core_reach_not_computed`, `::test_core_absence_only_without_auth_services`, `::test_verbless_action_is_any_not_post`, `::test_state_changing_tristate`, `::test_webapi_name_convention_verb`, `::test_acceptverbs_enum_and_string_forms`, `::test_writes_flag_from_span`, `::test_mapped_route_without_controller_gets_no_reach`, `::test_no_guard_keys_without_capability`. Corpus `url-auth-merge`, `nested-webconfig`, `route-aliases`, `filter-composition`, `core-fallback-policy`, `verbless-actions`.

### W5 Route fidelity: areas and prefixes (RC-H → DA-G 6.1) — 2.8

**Change** (`stacks/aspnet.py` `_controller_actions`, `_route_tables`).
1. Parse `[RouteArea]` in all three shapes: positional name plus `AreaPrefix`; `AreaPrefix` only; **empty name and empty prefix** (root: no `area_path`, and C22 must not demand an `Areas/` row). Tolerate spacing variants.
2. Conventional area routes come from the `AreaRegistration` `MapRoute` **`url:` literal**; do not prepend the folder name. A controller whose namespace names a different area than its folder uses the **folder**.
3. Normalise `[RoutePrefix]`, `[Route("~/x")]` (tilde overrides prefixes), optional and constrained parameters. An action with any `[Route]` is not reachable by conventional routes. `[ActionName("x")]` renames.
4. Add `mvc_area` (the area name) and `mvc_area_path` (`Areas/<X>`) to every MVC `entry_point`. These names avoid the template's `Area` column. Collapse exact duplicates.

**Tests:** `::test_routearea_prefix_applied`, `::test_routearea_prefix_only`, `::test_routearea_empty_is_root`, `::test_area_url_from_registration_literal`, `::test_area_from_folder_not_namespace`, `::test_tilde_route_ignores_prefix`, `::test_attribute_route_excludes_conventional`, `::test_actionname_rename`, `::test_duplicate_route_collapsed`. Corpus `route-area`.

### W6 Stack and handler classification (RC-H → DA-E10, false stacks, desktop handlers) — 2.8

1. **`aspnet_core.detect`** requires a project (via `detect_in`) with `Sdk="Microsoft.NET.Sdk.Web"` (or `.Razor`), a `Microsoft.AspNetCore.*` package, or a framework reference. A `.csproj` plus `Program.cs` no longer qualifies. Classic projects (`System.Web.Mvc`/`System.Web`, `Global.asax`, `Web.config`) are `aspnet`. A solution can hold both: emit both stacks with a `project` attribution.
2. **Markers** under `facts.is_test_path` are dropped by every `detect()`. A marker inside a project that references `Microsoft.NET.Test.Sdk`/`MSTest.TestFramework`/`xunit`/`NUnit` is also a test marker. For the spike Target the false marker files are **real project files** (three old-style projects and one WinForms `Program.cs`), so project-content detection (step 1) is the fix and `is_test_path` is the secondary fix for the sample project. `fixtures`, `__fixtures__`, `testdata`, `*testdata`, `e2e` move from `generic._TEST_CONFIG_DIRS` into `facts` as `is_test_data_path`, used by `generic.config_role` and every `detect()` (R5). `stack.ignored_markers: N` (an explicit return from `detect`, B M6). Example Facts change where fixture folders sit outside `tests/`; the answer keys are re-baselined in the same commit.
3. **`node-express`** already requires `express` to be declared in `package.json` and used in source (`node_express.detect_in`). The false stack in the audited output came from AppDoc 2.1. Add a regression test only (a tooling manifest with type-definition dev dependencies yields no stack); widen to `fastify`, `koa`, `hapi` and `@nestjs/core` only if a Stack for them is added.
4. **`aspnet._handlers`** emits Web Forms handlers only for code-behind of `.aspx/.ascx/.master` or classes deriving from `Page`/`UserControl`/`MasterPage`. A `Controller`-named class needs `using System.Web.Mvc|Microsoft.AspNetCore.Mvc` or a resolvable known base. VB classes are not parsed (`classes = []` for VB today): the block says "VB code-behind is not evaluated" when VB files exist.
5. **Desktop.** Desktop only when `OutputType` is `WinExe`, or `Exe` **and** a class deriving `System.Windows.Forms.Form`/`System.Windows.Window` **and** no web SDK or AspNetCore reference (a Core web app is an `Exe`). Forms become `ui_page type=form`; the project's `static void Main` is one `entry_point type=desktop`. `desktop` is **not** in `check.ENTRY_TYPES` and is not a C13/C22 obligation; the harness stays visible through the entry-points block rows. `fill.entry_point_counts` counts it separately.
6. Old-style csproj `<Reference>`+HintPath yields no `dependency` Facts (they come from `packages.config`); the `project` Fact records the test-framework flag from references and from `[TestMethod]|[Fact]|[Test]` methods.

**Tests:** `test_facts_aspnet_core`: `::test_no_core_without_web_sdk`, `::test_test_path_markers_ignored`, `::test_fixture_markers_outside_tests_ignored`, `::test_marker_in_test_project_ignored`. `test_facts_node_express`: `::test_no_express_from_tooling_manifest`. `test_facts_aspnet`: `::test_winforms_handlers_not_entry_points`, `::test_desktop_main_entry_point`, `::test_core_web_exe_main_not_desktop`, `::test_codebehind_handlers_still_found`, `::test_controller_named_class_needs_mvc_base`, `::test_both_stacks_with_project_attribution`. `test_generic_facts::test_config_role_uses_facts_test_data_path`, `::test_csproj_project_fact`. Corpus `core-false-positive`, `stack-markers`, `winforms-handlers`.

### W7 Integration Facts by convention (RC-I → DA-E2, G 6.3) — 2.9

1. **Config-configured clients.** A config read whose key matches the closed suffix set `Url|Uri|Endpoint|BaseAddress|Host|Wsdl`, reaching a `new T(...)` argument (the regex spans lines and takes the first argument; the spike's real shape is a multi-line argument list), an assignment to `.Url`, `.BaseAddress` or `.Endpoint.Address`, or `new EndpointAddress(...)`: `external_call type=service via=T config_key=K`. SMTP precedence: a `new T(...)` whose key ends `Host` and whose type is the SMTP client is `smtp`, reported once.
2. **File drops, bounded taint rule (replaces "one hop").** Inside one method, a name is *tainted* when assigned from a config read or from `Path.Combine`, `+`, interpolation or `string.Format` of tainted names (up to **4** assignments). A tainted name used as the first argument of `File.Write*`, `Bitmap.Save`, `Image.Save`, `File.Copy` or `FileStream` is `external_call type=file_drop config_key=K`. `Save(Stream)` is not a drop (first argument must be a path expression). An untraced write is `external_call type=file path_ref=<identifier>`. Local `App_Data` writes stay `type=file`. Records `\\host\share` (first two segments only), never deeper.
3. **Config-only `share` Fact** (needs no code analysis): any config key whose **value starts with `\\`** is `share` with `key` and `unc: true` (no host or value), joined to the lines that read the key (`config_key use=read`). This finds the share keys regardless of how the path is built.
4. WCF endpoints come from W1.

**Tests:** `::test_config_url_ctor_client_multiline`, `::test_config_url_property_client`, `::test_smtp_not_double_reported`, `::test_file_drop_two_hops`, `::test_file_drop_three_hops`, `::test_file_drop_four_assignment_cap`, `::test_save_stream_not_a_drop`, `::test_untraced_path_not_guessed`, `::test_app_data_write_is_local_file`, `::test_share_fact_from_unc_value`, `::test_unc_path_recorded_to_share_only`. Corpus `config-client`, `unc-drop`, `share-key`.

### W8 CI pipeline Facts (RC-I → DA-E4, G 6.5, S5) — 2.9

**Change** (`stacks/generic.py`; a restricted line reader for GitLab and GitHub only, stdlib, R7). Azure Pipelines and Jenkinsfile are deferred and named "not read" in the block.
1. **Fail-safe.** Any line not matching a recognised construct inside a job sets `parse_confidence: partial` for that job and suppresses negative claims (R20). Recognised: job maps, `stage`, `only`/`except`/`rules` (list **or** map `refs:`), `when`, `environment` (scalar or map), `variables`, `script`/`before_script` (including block scalars and flow sequences), trailing `#` comments after keys, regex literals in `only:`, `---` documents. **Not followed and disclosed** as `unresolved`: `include`, `extends`, anchors and merge keys, `!reference`, `default:`, `workflow:rules`, child pipelines, `needs`, reusable workflows, composite actions, matrix strategies.
2. **`ci_job`**: `stage`; `trigger` (`branch:<pattern>|tag:<pattern>|manual|mr|other`); `environment` (name; URL as `scheme://host` only); `build_config` (a **sorted list**; `multiple` where they differ); `steps` (closed classes `restore|build|test|package|deploy|other`); `unclassified` (the **first token only** of unclassified steps, never a full script line); `unresolved`; `parse_confidence`.
3. **Configuration resolution.** `/p:Configuration=`, `-p:Configuration=`, `/property:Configuration=`, `-c`, `--configuration`, quoted forms, `$NAME`, `${NAME}`, `$env:NAME`, `$(NAME)`, `${NAME:-Release}`. A variable resolves only if defined in the same file at global or job level; otherwise `unresolved: [variable]` (the value may come from the UI). `build_config` joins to `environment` only within the **same job**. `/p:PublishProfile=X` maps to a `publish_profile`, not to a configuration.
4. **Secrets (R19).** `variables` are recorded by key name only (except the single resolved Configuration literal). Test verbs for unclassified tools are recognised by first token: `nuget`, `dotnet test`, `vstest.console`, `nunit3-console`, `xunit.console`, `mstest`, `Invoke-Pester`, `psake`, `cake`, `nuke`, `./build.ps1`.
5. **Negative claims.** `No job runs tests.` is printed only when every job and file is fully resolved. Otherwise: `Test steps not determined: N unresolved references.` With unclassified steps present it reads `No step matched the test verbs (first tokens: …)`.
6. **`test_suite`**: a project referencing `MSTest.TestFramework|xunit|NUnit|Microsoft.NET.Test.Sdk`, or holding `[TestMethod]|[Fact]|[Test]`, gives project, framework, method count. Pytest, JUnit and Jest come from existing test-path detection (count only).
7. Feeds template §16.5 (Build, Test, Deploy) and the pipeline block. Whether `ci_job.steps` also feed template §17 (Build/Test commands) is decided in 2.7's §17 spec; this plan feeds §16.5 only.

**Tests:** `::test_gitlab_ci_jobs`, `::test_block_scalar_script_lines_read`, `::test_flow_sequence_on_trigger`, `::test_only_as_map_refs`, `::test_rules_if_stored_as_trigger_other`, `::test_trailing_comment_after_key`, `::test_regex_literal_in_only`, `::test_build_config_env_powershell_form`, `::test_build_config_resolved_from_variables`, `::test_undefined_variable_unresolved`, `::test_config_joins_environment_same_job_only`, `::test_publishprofile_not_a_configuration`, `::test_extends_include_disclosed`, `::test_partial_parse_suppresses_no_test_trailer`, `::test_include_suppresses_no_test_trailer`, `::test_unclassified_step_first_token_only`, `::test_environment_url_userinfo_and_query_stripped`, `::test_variables_values_not_stored`, `::test_script_line_with_password_not_stored`, `::test_github_workflow_jobs`, `::test_test_suite_counted_old_style_project`. Corpus `ci-jobs`, `ci-fail-safe`.

### W9 In-repo documentation as input (RC-J → DA-E3, E4, T4, G 6.6) — 2.9

1. **`doc_file`** for `README*` at any depth and `*.md`/`*.htm*` under folders that hold no code and are not pruned; `.docx`, `.csv`, `.xlsx` by name only.
2. Detail: `headings` as `(line, level)` only; **heading text is recorded only when it matches a closed topic** (R18: "Contact: Jane Doe" never lands in a Fact); `topics` from a closed set matched on heading words; `owner_entries` (a **count** of mailto links or `Name -` patterns under an `owner` heading, with **HTML comments stripped first**; placeholders inside comments are not entries).
3. **Topic vocabulary** (closed; widened by the spike): `owner`, `environment`, `authorization`, `troubleshooting`, `operations`, **`logging`** (log, logs, logging), **`maintenance`** (maintenance, annual, yearly, release process), **`scheduled`** (job, schedule, daily, nightly, hourly, cron, batch, ETL, SSIS, load), **`integration`** (interface, API, feed, import, export, share), **`testing`** (test, coverage).
4. **`logging_target`**: logging-framework config sections (appender type, file path literal, level), with transform overrides. This is the audit's missing log path.
5. **Cross-source advisories** (deterministic, advisory only): README branch tokens that no CI `only:` references; a README coverage badge with no `test` job; README feature bullets under `summary|features|functionality` whose first noun phrase matches no §4 row title by substring; `doc_mentions_config_key` (an exact config key token present in a `doc_file`), which joins `config-year-horizon` to "documented as annual maintenance at README:line".
6. **`multi_sink_handler`**: handlers whose line span contains an external write and a data write, with line order (the cue for DA-S9; the judgement stays with the writer).
7. The facts summary gains **Repository documentation** (path, topics).

**Tests:** `::test_readme_topics`, `::test_topic_vocabulary_logging_maintenance_scheduled`, `::test_owner_entries_counted_no_names`, `::test_owner_entries_ignore_html_comments`, `::test_heading_text_only_when_closed_topic`, `::test_docs_folder_with_code_not_doc_file`, `::test_logging_target_with_transform_override`, `::test_readme_branches_vs_ci_advisory`, `::test_feature_bullet_without_row_advisory`, `::test_doc_mentions_config_key`, `::test_multi_sink_handler_order`. Corpus `readme-topics`.

### W10 Scan accounting (RC-L → DA-E10, RC4) — 2.9

(`scan.py`; extends 2.6 §4.2–4.3.)
1. **"Code" is defined** by one extension list shared with the stacks (R5); `.bat`, `.xsl` and `.ps1` count as code. The rules below use it.
2. **`AppDoc output (v1)`**: a folder holding `architecture-fingerprint.json` and `evidence/evidence-graph.json`. Pruned and disclosed like 2.x output.
3. **`Generated documentation candidate`** (a question, R3): recursive; the topmost qualifying folder; a folder with ≥20 files (≥3 if ≥3 file names repeat in a sibling copy), ≥80% `.json/.md/.html`, and a code test that tolerates scripts only when they are a minority and repeated in a sibling. Folders paired in `duplicate_folders` are reported there only. Listed in 2.1 and required by C7 as a handle.
4. **Content-data folders:** no code, ≥200 files, ≥95% one data extension. Counted as `content`, excluded from "files read". Config-key extraction still runs.
5. **Vendored libraries:** closed rule on `*.min.js` and the known vendor folder names (`lib`, `vendor`, `third_party`, `node_modules`) holding large single-file scripts; reported as a candidate.
6. **Tool-state dot folders** (a `.docuwriter`-style folder) are reported as a disclosed candidate, not excluded.

**Tests:** `::test_prune_v1_output`, `::test_code_definition_shared_with_stacks`, `::test_doc_copy_candidate_topmost_recursive`, `::test_doc_copy_with_repeated_names_lower_threshold`, `::test_doc_copy_not_duplicated_with_duplicate_folders`, `::test_content_folder_counted_separately`, `::test_vendored_min_js_candidate`, `::test_scan_reconciles_with_content`. Corpus `v1-output`, `content-folder`.

### W11 Finding candidates (RC-N → DA-S1, S2, S4–S6, S10, E5, E6, G 6.4) — 2.8 (2.9 additions marked)

**Part A: Facts-level pass.** `smells.from_facts(facts) -> list[Fact]` runs in `extract.py` after the W4 post-pass. It reads only Facts, so it is deterministic (P3). A hit is a `smell` Fact anchored at a stable position, with `fid = fact_id("smell", pattern, path, line)` and `sources` as **`(path, line, kind, name)` tuples** (only smell Facts have ids; other kinds do not). Per-file patterns stay in `smells.extract`; the two passes never emit the same pattern. `smells.extract` gains `.config` dispatch for `duplicate-config-key`. **Per-controller hits are anchored on the controller class line** (the `controller_class` raw Fact), not the first action, so a new action does not change the `fid` and break C11 dismissals.

**Part B: patterns.** Each has a positive and a negative corpus fixture. Messages never echo names or values.

| Pattern | Pass | Fires when | Class | 2.x |
|---|---|---|---|---|
| `machinekey-in-config` | facts | a `machineKey` of class `literal_hex` in any config | deterministic | 2.8 |
| `named-user-access-rule` | facts | `access_rule users_named > 0` | deterministic | 2.8 |
| `duplicate-config-key` | text | the same key twice in one `appSettings`; transform files excluded; skipped if an external `file=` may override | deterministic | 2.8 |
| `debug-setting-in-nondebug-config` | facts | `compilation@debug=true` or `customErrors=Off` in the **effective** value of any configuration whose `config_status` is `base` or `transformed` (the `Debug` configuration is listed summary-only; a configuration with no transform inherits the base). **Not** "deployed": that word is reserved for the CI-joined pattern | deterministic | 2.8 |
| `debug-settings-deployed` | facts | the above, joined to a `ci_job` or `publish_profile` that deploys that configuration | heuristic | 2.9 |
| `identifier-list-in-config` | facts | an appSettings value that is a comma list of ≥3 tokens of one shape (digits, or lower-case alphanumerics) under a key whose last word is in `Users|Admins|Testers|Owners|Allowed|Exempt|Ignore|Ids|Positions`; **count only** (R18); also reports keys overridden per configuration | deterministic | 2.8 |
| `handler-without-guard` | facts | `state_changing: true`, `reach_anon=allow` with `writes: true`; message "no application-layer restriction" and the `reasons` codes | heuristic | 2.8 |
| `state-change-authenticated-only` | facts | `state_changing: true`, label `signed_in_any` in the production configuration, and a sibling controller **in the same area** has `role_restricted` handlers; ranked by `writes` | heuristic | 2.8 |
| `post-without-antiforgery` | facts | one **Target-level** hit with a per-controller table (N of M); a `System.Web.Mvc.Controller` derivative with a `state_changing` POST not protected by `[ValidateAntiForgeryToken]` (own, class-level or inherited from an in-Target base), by a Target attribute whose body calls `AntiForgery.Validate(`, by a global `filters.Add(new <that class>())`, or by an in-body `AntiForgery.Validate(`. Not `ApiController`, not Web Forms. Unresolved external base gives no hit. MVC 5 has no built-in global filter; Core has `[AutoValidateAntiforgeryToken]` (stack-specific token sets) | heuristic | 2.8 |
| `deref-before-null-check` | text | see "null patterns" | heuristic | 2.8 |
| `deref-in-null-branch` | text | a member of `x` accessed inside the `if (x == null)` branch (cheap sibling) | heuristic | 2.8 |
| `dead-null-fallback` | text | see "null patterns" | heuristic | 2.8 |
| `conditional_const` / `mode_branch` | facts | **Facts, not a pattern**: a `const_def` under `#if` whose name is referenced by a guard-attribute argument; `mode_branch` counts `X == Enum.Production` comparisons inside a handler that also contains an auth-method call; the summary names the configurations whose `DefineConstants` define the symbol | summary-only | 2.8 |
| `conditional-security-build` | text | **Replaced** by the two Facts above; the `#if DEBUG` pattern widens to blocks assigning **locals** in files that contain handlers, summary-only | summary-only | 2.8 |
| `hardcoded-production-mode` | text | in a `WinExe`/`Exe` project, an assignment of a mode property to an enum member named `Production` in `Main`'s file | heuristic | 2.8 |
| `config-year-horizon` | facts | a non-secret appSettings key whose name contains a token from `Year|Fiscal|FY|Horizon|Through|Until|Expire|Expiry|End|Max`, with a 4-digit value Y, and `Reference year − 1 ≤ Y ≤ Reference year + 1`. The **reference year comes from `appdoc-context.md` (`Reference year: 2026`)**; with no directive the pattern is off and the summary says so (no clock, no git year; P3/P5). Wording: "within one year of the declared reference year; if it is a limit, confirm with the owner". Ports and timeouts are excluded by the key-token rule | summary-only | 2.8 |
| `ci-without-test` | facts | `ci_job` with `deploy`, no job with `test`, ≥1 `test_suite`, and a fully resolved file graph | heuristic | 2.9 |

**Null patterns (soundness rules, A I-13).** `deref-before-null-check` fires only when: `x` is a local or parameter declared in the same method; the dereference is member access without a call (`x.Prop`, `x.Field`, `x[...]`) or a closed object-method (`ToString|Equals|GetType|GetHashCode`) — extension methods are excluded because they are legal on null; it is a direct statement-level child of block B and precedes, in B, an `if` whose condition is exactly `x == null`, `x is null`, `null == x`; and no statement between assigns `x` or contains `?.x`, `x ??=`, `goto`, a label, `return`, `throw`, `break` or `continue`; and the dereference is not inside a short-circuit that already tests `x` (`x == null || x.P`, `x != null && x.P`). Comments and string literals are stripped first. `Nullable<T>.Value` is described without claiming a `NullReferenceException`. Message: "a member of x is accessed on line L before the null check on line M (no assignment between)". `dead-null-fallback` requires the file's `using log4net|NLog|Common.Logging` (or fully qualified use), no Target type named `LogManager|ILog|Logger`, and a variable that is a local, or a `private (static) readonly` field whose only assignment in the file is the factory call; it matches **unqualified** calls with an explicitly typed local (the real shape). `ILoggerFactory.CreateLogger` is dropped. Message: "no assignment in this file gives x a null value".

**Part C: the C12 gate (V31).** Rev 2's "≥5 hits on the examples" could never oblige patterns that occur 1–3 times per Target, and no public example is classic MVC.
- A code constant **`smells.OBLIGING`** (frozenset) names the patterns that oblige C12 (cite or dismiss). `check._c12_smells` filters on it; `summary.finding_candidates` labels every other smell "candidate (not an obligation)"; the summary prints "none" for patterns of a stack whose detector ran with no hits (detector accountability, §6.6); `DETAIL_KEYS["smell"]` gains `sources`.
- **Deterministic config reads oblige from the release that ships them**: `machinekey-in-config`, `named-user-access-rule`, `duplicate-config-key`, `debug-setting-in-nondebug-config`, `identifier-list-in-config`. They are reads of declared values, not heuristics (R8 does not require a precision gate for them).
- **Heuristics oblige only after a measured precision ≥ 0.8** on an in-repo **hand-labelled set**: `eval/labels/<pattern>.json` (a list of `{path, line, label: tp|fp, reason}`), with ≥5 positives and ≥3 negatives per pattern, labelled by someone other than the author, **including the false-positive shapes the spike found** (read-only POST, redirect-only stub, `allow *` data API, extension-method dereference, deref in an inner block). `eval/smell_precision.py` is reworked to run **both passes** (`extract` and `from_facts`; today it runs only the per-file pass and prints hits), read the labels, and print precision. The corpus Targets re-enter measurement deliberately, but only through the labelled set, which carries negatives.
- Until a heuristic meets the bar it is summary-only. `tools/release.py` prints, per pattern, class, hits, precision and obligation status. The private DegreeAudit run adds counts only to the release report and does not gate.

**Tests:** `test_smells`: one positive and one negative per pattern, plus `::test_from_facts_deterministic_fid`, `::test_from_facts_reads_no_source`, `::test_per_controller_anchor_stable_when_action_added`, `::test_config_dispatch_for_duplicate_key`, `::test_duplicate_key_skips_transform_and_external`, `::test_debug_pattern_uses_effective_config`, `::test_debug_pattern_lists_debug_config_summary_only`, `::test_unlisted_config_name_not_special_cased`, `::test_year_horizon_needs_reference_year`, `::test_year_horizon_requires_key_token`, `::test_year_horizon_ignores_ports_and_timeouts`, `::test_authenticated_only_requires_role_sibling_in_same_area`, `::test_antiforgery_*` (the six cases in W11 table), `::test_deref_extension_method_not_flagged`, `::test_deref_conditional_access_not_flagged`, `::test_deref_in_branch_not_flagged`, `::test_deref_field_not_flagged`, `::test_deref_comment_and_string_not_flagged`, `::test_deref_reassigned_between_not_flagged`, `::test_deref_short_circuit_not_flagged`, `::test_dead_null_fallback_requires_using`, `::test_dead_null_fallback_unqualified_call`, `::test_dead_null_fallback_target_declared_logmanager_not_flagged`, `::test_dead_null_fallback_nonreadonly_field_not_flagged`, `::test_conditional_const_joined_to_guard_argument`, `::test_hardcoded_production_mode_in_main_file`, `::test_obliging_constant_filters_c12`, `::test_summary_labels_non_obliging`. `tests/test_release.py::test_obligation_needs_precision_on_labelled_set`, `::test_deterministic_patterns_oblige_without_labels`. Corpus `smells-net`, `smells-from-facts`, `antiforgery-variants`.

### W12 Data and report surface (DA-G 6.2) — 2.9

1. `schema_object` from EF 6 `.edmx` and `DbContext` (`EntitySet`/`EntityType` names).
2. `ui_page type=report` for `.rdlc`/`.rdl` (name and dataset names).
3. `data_access type=sql`: add `schema` detail.
4. **`xsd_schema`**: top-level `element` and `complexType` names and counts from `.xsd`. This describes the XML config corpus and workflow definitions deterministically.

**Tests:** `::test_edmx_entities`, `::test_rdlc_report_page`, `::test_sql_schema_detail`, `::test_xsd_element_names`. Corpus `xsd-format`.

### W14 Config-key context for the writer (small; 2.8)

The same reader that emits `security_setting` emits the existing `config_key` Facts for `Web.config` with `overridden_in` (W1.8). `connection` Facts are grouped by name across the base, transform and test configs so the connections block prints one row per name (never dozens). In 2.9, a **per-configuration connection-target matrix** (server token and database name only, never credentials) can be added; whether server tokens may be recorded is an owner decision (Q31).

---

## 6. Phase 2 — Generated blocks (template 2.8)

All four new block markers and headings ship in **2.8.0**, so 2.9.0 needs no template bump: a block whose Facts arrive in 2.9 renders the R4 capability-aware "none" in 2.8.

**Registry (V30; B4).** `template_spec.GENERATED` is one block name per key. To avoid changing it, each new block gets its own subsection:

| Block | Template subsection | Notes |
|---|---|---|
| `access-model` | 5.4 "Application-layer access (generated)" | new subsection after the 5.3 Restriction line |
| `connections` | 8.1 | lists `connection` Facts (C- IDs section); E7 is an 8.1 finding |
| `integrations` | 8.3 | external calls only (X- IDs) |
| `pipeline` | 16.8 "Pipeline (generated)" | markers 2.8, content 2.9 |
| `repo-docs` | **2.2** "Repository documentation (generated)" | not in 2.1, which already holds `scan-coverage`. **Verify 2.2 is free in `template_spec` at the start of the work.** |

All five are added to `template_spec.OPAQUE_BLOCKS` and the same step updates `check._c7_blocks`, `check._claim_sha` masking, `fill.RENDERERS`, and 2.7's `doc_sha`. Without opacity, (a) block tables and IDs are parsed as Narrative by C1/C9/C10, and (b) a register row sealed against section 5.4 or 8.3 would change its seal when 2.9 fills the block, and C11 would fail "the text changed after it was audited". Tests: `test_check::test_new_blocks_are_opaque`, `::test_seal_survives_block_content_change`, `test_template_spec::test_generated_keys_unique`. C9 gains the 5.4, 2.2 and 16.8 headings.

**R4 wording.** Each block states what a script read, says "N of M" for every capped list (the first 60 / 40 rows), and says which reader produced a "none": a Stack for stack-fed content, "the generic reader" for generic-fed content (CI, documents, projects). Prefer closed phrases for "none" sentences so 2.9 can change content without rewriting a pinned sentence.

### 6.1 `access-model` (template §5.4) — 2.8

Heading and mandatory disclosure line (a C7-covered text):

> Application-layer evaluation only: ASP.NET `<authorization>`, MVC filters and the declared authentication mode. IIS authentication settings, server-level configuration, network exposure, group membership and effective permissions are not in the repository.

For the production configuration, then each configuration that differs (and "N of M configurations could not be evaluated"):
- authentication mode; `host_auth`, `owin_auth`; `iis_authorization_present`; "effective on publish or package only";
- the access-rule matrix (scope × effect, roles as written, `users: N named`; first 40 rows, N of M), and rules whose `scope_path` matches nothing;
- per area (by `mvc_area`), handler counts by label, with the **three archetype results**; every `state_changing` handler whose label is `no_app_restriction`, `signed_in_any` or `unknown` listed by route and file (first 60, N of M); **all** `no_app_restriction` handlers are listed, not only state-changing ones; verb-less actions counted separately ("N verb-less actions");
- guard attributes (declared, candidate) with use counts; undeclared candidates counted; **guard argument shapes** (V27); role names and **all** role constants referenced by guards or `auth_method` calls ("names as written");
- a **secret-location table**: per file, counts of secret-location config keys, connection strings with literal credentials, literal `machineKey`s and secret-named constants; N of M; never values;
- a "Defaults" note (documentation, not a Fact);
- which stacks report protection and which do not; for `aspnet_core` the mechanism-only note.

ADR 0019 records that this block is an attack-surface summary and that the document's distribution follows the Target's own access rules.

**Tests:** `test_fill`: `::test_access_model_block`, `::test_access_model_disclosure_line`, `::test_access_model_archetype_triple`, `::test_access_model_config_columns`, `::test_unguarded_handlers_listed`, `::test_all_no_app_restriction_listed`, `::test_access_model_caps_n_of_m`, `::test_access_model_capability_none`, `::test_secret_table_no_values`, `::test_argument_shapes_table`, `::test_role_constants_all_listed`, `::test_unevaluable_configs_counted`.

### 6.2 `connections` (8.1) and `integrations` (8.3) — 2.8 (connections, WCF), 2.9 (convention calls)

Both blocks build on the aggregation in `appdoc/integration.py` (R5; V41), which already groups `connection`, `external_call` and `dependency` Facts for the `System Connections` view, and extend its vocabulary with `file_drop`, `share` and `service`. `connections`: every `connection` name defined in config, grouped by name across base, transform and test configs, with `overridden_in` (10 of 10). `integrations`: `external_call` grouped by `type` (`service`, `file_drop`, `smtp`, `http`, `file`), with config key and call sites, and the `share` keys.

**Tests:** `::test_connections_all_listed_grouped_by_name`, `::test_integrations_block`, `::test_integrations_none_phrase_stable`.

### 6.3 `pipeline` (16.8) — markers 2.8, content 2.9

One row per `ci_job` (stage, trigger, environment, build configuration, step classes, `parse_confidence`); test suites; the negative-claim trailer under the W8.5 rules; unresolved references; CI files present but not read. **Tests:** `::test_pipeline_block`, `::test_pipeline_no_test_trailer`, `::test_pipeline_partial_suppresses_trailer`, `::test_pipeline_unresolved_disclosed`.

### 6.4 `repo-docs` (2.2) — markers 2.8, content 2.9

`doc_file` Facts with topics, copies-of-documentation candidates, and `doc_mentions_config_key`. The SKILL rule requires reading every file tagged `owner`, `environment`, `operations`, `logging`, `maintenance` or `scheduled` before writing §11, §14 or §16. **Test:** `::test_repo_docs_block`.

### 6.5 Scan-coverage split — 2.9

`Source F · Content C (in N folders) · Documentation D · Pruned P`. **Test:** `::test_scan_split_counts`.

### 6.6 Detector accountability line — 2.8 (each 2.9 detector adds its own)

For each detector family the facts summary prints **"sites seen / recognised / unrecognised"** (guard attributes seen vs classified; config reads seen vs matched; in 2.9 file writes seen vs file-drop recognised). A zero-recognised result reads as "ran, found no match", not "none exist" (RC-O). `summary.py` is in scope for this and for **Unclassified controller attributes**, **Repository documentation** and `ignored_markers`; `tests/test_core` summary tests are updated.

### 6.7 Count markers

2.7 §3.5 defines a closed list of count markers. Add: areas, state-changing handlers by label, access rules, role constants, guard shapes, secret-location files, configurations, and (2.9) CI jobs and test suites, so writers can state these counts without hand-typing (P1).

---

## 7. Phase 3 — Check rules

C21–C23 are free in 2.6/2.7 (C17–C20 are taken). **They run when the stamp equals the running template, like C7–C13.** The Check runs no structure rules on a stale stamp (C3 fails and the `if current:` block is skipped), so rev 2's "advisory on 2.7 stamps" mode and Q26 are withdrawn. Add C21–C23 to `check.RULE_TITLES`, `RULE_SUMMARIES` and the `RULE_CAP` list, and update the module docstring.

### 7.1 C21 — Mandatory inputs cited (R16 → DA-RC1, E1) — 2.8

Every file that holds a `security_setting`, `access_rule` or `config_external` Fact, or an `app`-role `config_key` with `secret_location`, must be cited **with a line** at least once in text with **every generated block masked** (`fill.mask_blocks(raw, all GENERATED names)`, as `check.py:1019-1021` does for section 2). Without masking, the generated 16.6 `config-reference` block already cites every app config file with a line, so C21 was vacuous (B3). Section 16 is **not** an accepted location. A file whose only Fact is `config_unparsed` must be cited by path (any citation); this keeps the rule satisfiable. Handle check only (P2). Failure text: `this file is mandatory input (R16); read it and cite what it shows, redacting values`.

**Tests:** `::test_c21_uncited_security_config_fails`, `::test_c21_unlined_citation_fails`, `::test_c21_generated_16_6_citation_does_not_satisfy`, `::test_c21_unparsed_file_needs_path_only`, `::test_c21_ignores_wording`. Corpus `config-not-reviewed`.

### 7.2 C22 — Area and protection coverage (RC-K → DA-G 6.1, RC2) — 2.8

1. **Areas.** Every non-root `mvc_area_path` must be the folder cited in some 4.1 row (reuse the `_c7_counts` 4.1 folder parse, `check.py:383-404`). C10 is **not** relied on: it checks the section 4 `Area` column against 5.3, which is a different thing (B I2). If 5.3 or 5.4 must also name each area, that is a new explicit check, not an inherited one.
2. **Handler files.** Every handler file with a `state_changing: true` handler, or a label of `no_app_restriction`, `signed_in_any` or `unknown`, must be cited. This is a filter on C13's citation map, which needs a named refactor: `_uncited_entry_points` (`check.py:518-527`) today groups by top-level folder, keeps five paths and restricts to `ENTRY_TYPES = ("route","page","command","job")`; it is changed to return per-path data so C13 and C22 share one implementation (R5). With undeclared guard candidates present nearly every handler file is `unknown` and so mandatory; this cost is accepted and stated in the failure text.
3. **Undeclared guard candidates.** An outcome `N undeclared guard candidates; declare with "Auth attributes:" in appdoc-context.md`: advisory in CI, failing under `--strict`.
4. C13 stays advisory for read-only, role-restricted handlers (R8: no threshold heuristic). `desktop` entries are not obligations.

**Tests:** `::test_c22_area_missing_from_4_1_fails`, `::test_c22_root_area_not_demanded`, `::test_c22_unguarded_file_uncited_fails`, `::test_c22_readonly_guarded_stays_advisory`, `::test_c22_shares_c13_map`, `::test_c22_undeclared_candidates_strict_only`. Corpus `area-coverage`.

### 7.3 C23 — Unknown that the repository may answer (advisory) — 2.8 auth topics, 2.9 the rest

For each §14 row and each "Unknown - see Open questions." paragraph, match its words against the closed topic vocabulary (W9). If a `doc_file` with that topic exists, or a `security_setting`, `external_call type=file_drop|service` or `ci_job environment` Fact exists, the advisory names the location (`the repository may answer this: README.md:29 (owner)`). Fails only under `--strict` (R8). The audit's `Answerable` classification remains the binding mechanism. **Tests:** `::test_c23_owner_unknown_with_readme_owner_topic`, `::test_c23_identity_unknown_with_auth_setting`, `::test_c23_strict_fails`.

### 7.4 C20-family advisories — 2.8

Two advisories in the 2.6 §5.1 family (citation precision; same file list), labelled as an addition to that family rather than as a new meaning for C20's title:
- a citation of a file inside a sentence that contains a closed exclusion phrase (`not reviewed`, `not inspected`, `excluded`, `was not read`): "this sentence cites a file it says was not reviewed"; if the file is mandatory input it adds "C21 requires a lined citation";
- a range `a-a` (DA-E11): "write `:a`".

**Tests:** `::test_c20_cite_in_not_reviewed_sentence_advisory`, `::test_c20_mandatory_input_hint`, `::test_c20_single_line_range_advisory`.

### 7.5 Spec updates

`template_spec`: headings, `REQUIRED_SUBSECTIONS`, `OPAQUE_BLOCKS` (§6), the maintenance row in 16.x (DA-G 6.4), an `UPGRADE_STEPS` table (W15), `UPGRADE_NOTES` text. 2.7's audit plan samples sections 4, 6, 8.1, 8.3, 9, 15; section 5 and the new blocks are **not audited** and the plan says so: they are generated and opaque.

---

## 8. Phase 4 — Workflow, SKILL and render

### W15 `appdoc upgrade <target>` (RC-M → DA-T1–T11) — 2.7.0 recommended (Q23), otherwise 2.8.0

1. Upgrades a document from any stamp to the running template by applying a **machine-readable per-version step table**, `template_spec.UPGRADE_STEPS[version]` (list of operations: add block markers at a given `GENERATED` position, add headings with `appdoc:guide` comments, add required-row skeletons, rename table headers). Today `UPGRADE_NOTES` is prose; the table is new and is part of the cost. A document with no stamp is treated as 2.1 when it has the 2.1 subsections, else 2.0.
2. Re-runs `extract` and `fill`, then writes `docs/appdoc/UPGRADE-TODO.md` with the non-mechanical steps, each with the Check rule that fails until it is done.
3. Never deletes Narrative; unmappable content goes under an `appdoc:upgrade-orphan` comment that C3 fails on. Never writes `evidence.jsonl`, `notes.jsonl` or `audit-plan.json` (P4).
4. **2.7 amendment (done).** 2.7 rev 2 contains §3.11 (the command, the step table, `upgrade-2-1`, `upgrade-2-6-to-2-7`) pending Q23.

**Tests:** `test_core::test_upgrade_2_1_to_current_mechanical`, `::test_upgrade_2_0_adds_2_1_subsections`, `::test_upgrade_idempotent`, `::test_upgrade_never_drops_text`, `::test_upgrade_never_touches_register`, `::test_upgrade_todo_lists_failing_rules`, `::test_upgrade_step_table_covers_every_version`. Corpus `upgrade-2-1`.

### 8.2 Version drift at write time — 2.8

`extract` **prints a warning to stderr** and `check-report.md` carries it: "The existing document is on template X; this AppDoc writes Y. Run appdoc upgrade before editing." It is **not** written into `facts-summary.md`, which is a pure function of `facts.json` (rev 2's line made it depend on the Narrative and would break P3 and the 2.6 determinism harness). The SKILL "Run" step 0 (edit `workflow.SKILL_STEPS`): if the document exists and its stamp is older, run `upgrade` before `check`. **Test:** `test_core::test_extract_warns_old_stamp_on_stderr`, `::test_facts_summary_independent_of_narrative`.

### 8.3 SKILL.md and guide changes — 2.8 (2.9 adds the repo-docs lines)

`gen_docs` generates only README `commands`, `rules`, `facts-schema`, SKILL `run-commands` and the gate header (2.6 §6.3). The writing rules, Orient and Audit checklist are **hand-written** (2.6 §6.4). This plan adds a `SKILL_RULES` constant and a generated block in `gen_docs` (cost in §12) so these rules are generated and cannot drift; `test_generated_docs_current` covers them.

**Orient:** read the `access-model`, `connections` and `integrations` blocks before writing template sections 3, 5, 8 and 10; (2.9) read `repo-docs` and every `doc_file` with the listed topics.
**Writing rules (new):** never list a config file as not reviewed (read and redact; R16); write "Unknown" only after checking the facts summary and, from 2.9, repo-docs; the Troubleshooting Matrix draws from `doc_file` troubleshooting topics as well as `message` Facts; every `state_changing` handler labelled `no_app_restriction`, `signed_in_any` or `unknown` is a 10.1 finding or a dismissed candidate; per-configuration behaviour is stated per configuration; **state "application layer only" wherever access is described**; do not write "anonymous users can" unless `reason` includes explicit anonymity.
**Large Targets:** one subsystem per **area** (W5).
**Audit checklist:** trace every troubleshooting row and fallback claim to its end (null guards, never-null factories); check each block "none" against the reader named.

### 8.4 Render weight — independent; any release

`render --mermaid sibling` writes `mermaid.min.js` once beside the HTML. The default (`inline`) is unchanged. Touches `render/page.py` only; can ride in 2.6.0. **Tests:** `test_render::test_mermaid_sibling_mode`, `::test_inline_default_unchanged`.

---

## 9. Phase 5 — Release and examples

- **2.8.0.** `__version__ = "2.8.0"`; `facts.SCHEMA` is the next schema after 2.7's (expected `/8`; re-check at the start). New kinds `security_setting`, `access_rule`, `config_transform`, `guard_candidate`, `guard_class`, `guard_use`, `const_def`, `project`, `build_define`, `publish_profile`, `config_external`, `config_unparsed`, `context_directive`, `controller_class`; new `entry_point` detail keys (W4, W5); `type=desktop`; `stack.ignored_markers`; `smell.sources`. `TEMPLATE_VERSION = "2.8"`.
- **2.9.0.** Next schema (expected `/9`): kinds `ci_job`, `doc_file`, `test_suite`, `share`, `logging_target`, `xsd_schema`, `multi_sink_handler`, new `external_call` types, new scan counts. `TEMPLATE_VERSION` stays `2.8`: no new failing rule and no heading change (R6).
- **Conformance** (`tests/test_conformance.py`): every new kind is in `KINDS` and `DETAIL_KEYS`; `GENERIC_KINDS` is listed; `aspnet`/`aspnet_core` declare their capabilities in 2.6 §4.1 terms and `test_sample_exercises_every_capability` passes; `test_dict_detail_rejected`; **R18/R19 tests**: an email-shaped regex over the **new kinds** and generated blocks only (existing `message` Facts hold verbatim error strings and `dependency` names include npm scopes such as `@types/node`, so they get an allow-list rather than a blanket `@` ban); no detail equals a `secret_location` value; no URL with userinfo, path or query; `ownership` is exempt.
- **Examples (V34).** Each release changes Facts, and 2.8 also changes the template. Per 2.6 §3 and 2.7 §5.2, a template release is a **fresh run plus independent audit for all four examples** (eShop, flaskr, gitea, petclinic); 2.9 is a mechanical regeneration. Both update `tests/test_release.py::test_examples_current_and_previous`, answer keys and `eval/baseline.json`. Add **`examples/current/mvc5-classic`** (the corpus Target, documented and audited; Q24).
- **ADRs.** On disk 0001–0010 and 0016; 2.5 owns 0011/0012, 2.6 0013/0014, 2.7 0015/0017. This plan: **0018** "Security-bearing configuration is mandatory input" (R16, R19, C21); **0019** "Effective protection: application-layer evaluation" (R17, R20, W4, the disclosure line, C22, the known .NET-only limit); **0020** "Personal identifiers and repository documentation" (R18, C23, W9), **shipping in 2.8** with R18/C23 (rev 2 dated it 2.9). Amend 0008 (Facts-level candidates, `smells.OBLIGING`, the labelled-set gate).
- **Upgrade notes 2.7 → 2.8:** run `appdoc upgrade`; re-extract (schema exits the gate with code 3 until then); cite every mandatory config file with a line (C21); add every area folder to 4.1 and cite security-relevant handler files (C22); address the obliging candidates (C12); audit; `build`.
- **Upgrade notes 2.8 → 2.9 (corrected).** Re-extract (the schema bump exits the gate with code 3) and `build`. **Things can fail that passed:** `debug-setting-in-nondebug-config` is unchanged but `debug-settings-deployed` is new (new id); block content changes so C7 fails until `fill`; any 2.9 obligation fails passing documents. To keep this small, 2.9 changes to an existing pattern are shipped as **new patterns with new ids**, not edits, and no 2.9 pattern oblige is added without a note.

---

## 10. Decisions needed

| Q | Question | Recommendation |
|---|---|---|
| **Q30** | **Resolved 2026-11-23: `main` is the base.** (Was: base reconciliation, blocking.) The plan builds on the `v2.5.0` line; GitHub `main` is a separate 2.0.0 line with the performance and integration work. Merge the performance line onto `v2.5.0` (or the reverse), or choose another base? | Done: the `v2.5.0` branch and the performance and integration work are merged on `main` (`2e59393`). |
| Q22 | Split into **2.8.0** (security and access, every template change) and **2.9.0** (integrations, CI, repository docs; no template bump)? | **Yes.** Each release stays near the size of 2.6/2.7 and the security gaps ship first. (Under rev 3's estimates 2.8 is still large; the first slice is in §12.) |
| Q23 | Ship `appdoc upgrade` in **2.7.0**? | **Yes if 2.7 can take about 2 days.** 2.7 rev 2 §3.11 now holds the specification; W15 here covers only 2.8's steps. Otherwise 2.8 carries all of it. Decide before 2.7 starts. **DECIDED 2026-11-23: 2.7.0.** |
| Q24 | Classic MVC public example: synthetic `mvc5-classic`, or a public repository? | Synthetic now. Adopt a real public repository with transforms and Windows auth when one is found, to supply real-world false-positive data. **DECIDED 2026-11-23: synthetic now.** |
| Q25 | Record role names and role-constant values? | Yes for groups and `Roles=` constants (never `Users=`, never secrets, never emails or SIDs). Users counted (R18). |
| ~~Q26~~ | ~~C22 advisory on 2.7 stamps~~ | **Withdrawn** (the Check runs no structure rules on a stale stamp). |
| Q27 | `appdoc upgrade` converts `verification.md` to `evidence.jsonl`? | No (P4; the register needs source anchors). |
| Q28 | The C12 gate | `smells.OBLIGING` plus the rule in W11 Part C: deterministic reads oblige on shipping; heuristics need ≥0.8 on the hand-labelled set. |
| Q29 | Fold 2.8 template work into 2.7 (rev 1's "Q21")? | No (2.5 is still on its branch; 2.8's blocks need 2.8 Facts). |
| Q31 | May the per-configuration **connection target matrix** (server token, database name) be recorded? (Spike G-13; it answers "does testing touch production data".) | Owner decision; recommend a yes behind an `appdoc-context.md` opt-in (`Record connection targets: yes`), off by default. **DECIDED 2026-11-23: yes, opt-in, off by default.** |
| Q32 | `ownership` Facts record git author names, which R18 says should not be Facts. Remove them now or schedule with the performance work? | Schedule; exempt in R18 for now. **DECIDED 2026-11-23: remove in 2.6.0 (task T26.66); R18 exempts `ownership` until then.** |

---

## 11. Acceptance: the DegreeAudit run (private, `tools/acceptance.py`)

On a local checkout at `33168dd`, AppDoc must produce the rows below. DegreeAudit specifics live in the private key. After a perfect implementation the plan still does **not** make the failure class impossible; the residual risks are listed after the table.

| Audit finding | Must appear as | Rel |
|---|---|---|
| DA-E1 | `security_setting authentication@mode=windows`; access block with the disclosure line | 2.8 |
| DA-E5 / E6 | `deref-before-null-check` in the cited controller; `dead-null-fallback` at two sites in the base controller (unqualified call, typed local) | 2.8 |
| DA-E7 | connections block lists every connection name once (count from the key), with `overridden_in` | 2.8 |
| DA-E8 / E9 | All role constants (count from the key; **not just those in attributes**) listed via `auth_method` promotion; guard shapes table; `[Authorize]` counts per area; the external guard as candidate or declared | 2.8 |
| DA-E10 (stack) | No `aspnet-core` stack from the real WinForms/old-style project files; no `node-express` stack; `ignored_markers ≥ 1` | 2.8 |
| DA-G 6.1 | Every area (count from the key) with `mvc_area_path`; the root-controller empty-`RouteArea` case has no area row demanded; no WinForms web entry points; one `type=desktop`; `hardcoded-production-mode` on the harness | 2.8 |
| DA-G 6.4 | `duplicate-config-key`; `config-year-horizon` summary-only **only if** the key-name token and a declared reference year are present; the maintenance row exists in the template | 2.8 |
| DA-S1 | `state-change-authenticated-only` for the area with no role guard (production configuration; `writes: true` ranking), with 1–2 real hits expected among the 5 the spike predicted | 2.8 |
| DA-S2 / S3 | `machinekey-in-config`; the secret-location table lists the two plaintext keys, the connection strings with literal credentials (base **and** transform files), the machineKey pair and the secret constant, **no values** | 2.8 |
| DA-S4 | `named-user-access-rule` (counts); `identifier-list-in-config` for the identifier-list keys (counts, and the keys overridden in the Release transform) | 2.8 |
| DA-S5 (config) | `debug-setting-in-nondebug-config` lists **every** configuration's effective debug and `customErrors`: the `Debug` configuration inherits the base, `Staging` removes debug only, `Release` is clean; `conditional_const` names the configurations that define the symbol; `mode_branch` count | 2.8 |
| DA-S6 | `post-without-antiforgery` (one Target-level hit, per-controller table) | 2.8 |
| DA-S7 | Access block lists all `no_app_restriction` handlers (public controller via `[AllowAnonymous]`, the explicit `allow ?` locations) and the `allow *` data API labelled with `iis_anonymous_unknown`; stale rules listed | 2.8 |
| DA-RC1 | C21 fails on any document that does not cite `Web.config` with a line outside generated blocks | 2.8 |
| DA-T1–T11 | `appdoc upgrade` plus UPGRADE-TODO; after the writer completes it, Check PASS with `--require-audit` | 2.7/2.8 |
| DA-E2 | `share` Facts for the share keys; `external_call type=file_drop` at both multi-hop write sites; `path_ref` for untraced writes | 2.9 |
| DA-E3 | `doc_file` README with `owner` topic and `owner_entries` = live entries (placeholders in comments not counted); C23 advisory | 2.9 |
| DA-E4 | `ci_job` count and environments (uat/testing/staging/production) with `build_config` resolved through `$env:NAME`, one variable `unresolved` | 2.9 |
| DA-E10 (scan) | Source / content / documentation split; v1 output pruned; the other-tool folder named as a candidate; vendored library as a candidate | 2.9 |
| DA-G 6.3 | `external_call type=service` for the config-configured client (multi-line constructor); `doc_file` for the batching doc tagged `scheduled`; `logging_target` with the Release override | 2.9 |
| DA-G 6.5 | `test_suite` (old-style project via `[TestMethod]`); `ci-without-test`; pipeline trailer under W8.5 | 2.9 |
| DA-S5 (CI) | `debug-settings-deployed` names the deployed environments via `ci_job.build_config` (UAT and testing deploy `Debug`) | 2.9 |

**Residual risk after perfect implementation (documented in ADR 0019):** unclassified external guards (`unknown`, which suppresses `state-change-authenticated-only`); guards in method bodies and runtime mode checks (counted, not evaluated); web-server configuration outside the repository; closed-set misses (mitigated by §6.6); writer prose that contradicts a generated block (advisory by P2); non-.NET Targets (no detector); cross-source contradictions beyond the W9 advisories.

The acceptance script asserts on Facts and Check output only and stores no DegreeAudit content in the repository.

---

## 12. Order and effort

**Rev 2's 17.5 d omitted:** the raw-Fact foundation, the expat reader and URL-chain evaluator, `summary.py`, the registry and opacity change, the C13 refactor, template and `upgrade` step tables, the example rotation, the `eval/smell_precision.py` rework and `gen_docs`. The estimates below include them.

**2.8.0**
```
Phase 0  corpus (per-case layout, shared Targets, labelled set), harness        1.5 d
spike    re-run for changed specs                                               0.25 d
W6/W5    stack/handler classification, route areas                              1.0 d
W13      raw Facts, expat reader, context.py, detect_in (capabilities: 2.6)     1.0 d
W1       settings, transforms, configurations, host/OWIN                        2.0 d
W2       access rules                                                           1.0 d
W3       guards, auth_method, argument shapes, secret safety                    1.5 d
W4       URL chain, filters, URL set, reach, verbs                              2.5 d
W11 A/B  Facts-level pass, 2.8 patterns, null rules, OBLIGING, labelled gate    2.0 d
spike G  identifier lists, harness mode, conditional consts, stale rules        1.0 d
§6       five blocks, registry/opacity, summary.py, accountability line         1.25 d
§7       C21, C22 (+C13 refactor), C23 auth topics, C20 advisories              1.25 d
8.2/8.3  drift warning, SKILL_RULES / gen_docs                                  0.75 d
§9       4-example rotation + audit, mvc5-classic, ADRs, release                3.0 d
                                                          2.8.0 total about 20.0 d
```
**2.9.0**
```
W7   taint rule, share Fact, clients                                           1.25 d
W8   hardened CI reader, test suites                                           1.5 d
W9   docs, vocabulary, comments, cross-source, multi_sink                      1.0 d
W10  scan accounting                                                           1.0 d
W12  edmx, rdlc, sql, xsd                                                      0.5 d
§6   pipeline, repo-docs, integrations content, scan split                     0.75 d
§7   C23 remaining                                                             0.25 d
§9   mechanical example regen, ADR amendments, release                         1.5 d
                                                          2.9.0 total about 7.75 d
```
**Elsewhere:** W15 `upgrade` about 2.0 d (2.7.0 under Q23); render sibling 0.25 d. **Grand total about 30 d**, plus the Q30 reconciliation, which is not estimated here.

**First slice (if 2.8 must be cut):** Phase 0 + W6/W5 + W13 + W1/W2 + W3 + C21 (about 9 d). It ships the settings, rules, guards, route fidelity and the mandatory-input check, and defers reach (W4), the pattern gate and the blocks to a second drop. It is self-contained and can be delivered as a patch against the `v2.5.0` line once Q30 is decided.

**Order (2.8.0):** Phase 0 → W6, W5 → W13 → W1 → W2 → W3 → W4 → W11 A then B → spike-G items → §6 → §7 → 8.2/8.3 → examples, acceptance, release. **Order (2.9.0):** W7, W8, W9, W10, W12 → W11 additions → §6 content → C23 → regen, acceptance, release.

---

## 13. Traceability

| Finding | Item | Representative tests (red on the previous tag) | Corpus | Rel |
|---|---|---|---|---|
| DA-E1, S2, S3, S5 | W1 | `test_dotnetcfg::test_system_web_settings`, `::test_unsupported_transform_makes_effective_unknown`, `::test_config_without_transform_is_base` | webconfig-security, xdt-effective | 2.8 |
| DA-S4, S7 | W2, W11 | `::test_location_rules`, `::test_named_users_counted_not_recorded` | location-paths, nested-webconfig | 2.8 |
| DA-E8, E9 | W3 | `::test_auth_method_promotion_lists_all_constants`, `::test_secret_constant_not_resolved` | custom-guard, secrets-never-recorded | 2.8 |
| DA-S1, S6, S7 | W4, W11 | `test_core::test_url_auth_*`, `::test_filters_and_class_and_method_are_anded`; `test_smells::test_authenticated_only_requires_role_sibling_in_same_area` | url-auth-merge, filter-composition, windows-auth-iis | 2.8 |
| DA-G 6.1 | W5, W6, C22 | `::test_routearea_empty_is_root`, `::test_desktop_main_entry_point`; `test_check::test_c22_*` | route-area, area-coverage, winforms-handlers | 2.8 |
| False stacks | W6 | `::test_no_core_without_web_sdk`, `::test_no_express_without_server_dependency` | core-false-positive, stack-markers | 2.8 |
| DA-E7 | W1, §6.2 | `test_fill::test_connections_all_listed_grouped_by_name` | webconfig-security | 2.8 |
| DA-E5, E6, G 6.4, S10 | W11 | `test_smells::test_deref_*`, `::test_dead_null_fallback_*`, `::test_year_horizon_*`, `::test_duplicate_key_*` | smells-net | 2.8 |
| DA-S5 | W1, W11 | `::test_debug_pattern_uses_effective_config`, `::test_conditional_const_joined_to_guard_argument` | build-defines | 2.8 |
| DA-RC1, Check note 2 | C21, §7.4 | `test_check::test_c21_*`, `::test_c20_*` | config-not-reviewed | 2.8 |
| DA-T1–T11, RC3 | W15, 8.2 | `test_core::test_upgrade_*`, `::test_extract_warns_old_stamp_on_stderr` | upgrade-2-1 | 2.7/2.8 |
| R18, R19 | §9 | `test_conformance::test_no_personal_identifiers_in_new_kinds`, `::test_no_auth_value_equals_secret_location` | secrets-never-recorded | 2.8 |
| DA-E2, G 6.3 | W7, W9 | `::test_file_drop_three_hops`, `::test_share_fact_from_unc_value` | unc-drop, share-key, config-client | 2.9 |
| DA-E4, G 6.5, T4 | W8, W9 | `::test_build_config_env_powershell_form`, `::test_partial_parse_suppresses_no_test_trailer` | ci-jobs, ci-fail-safe | 2.9 |
| DA-E3, G 6.6, RC5 | W9, C23 | `::test_owner_entries_ignore_html_comments`, `test_check::test_c23_*` | readme-topics | 2.9 |
| DA-E10, RC4 | W10 | `::test_prune_v1_output`, `::test_doc_copy_candidate_topmost_recursive` | v1-output, content-folder | 2.9 |
| DA-G 6.2 | W12 | `::test_edmx_entities`, `::test_xsd_element_names` | xsd-format | 2.9 |
| DA-SR9 | 8.4 | `test_render::test_mermaid_sibling_mode` | — | any |
| End to end | §11 | `tools/acceptance.py` (local, private) | — | 2.8, 2.9 |

---

## 14. Done means

For each release (2.8.0, then 2.9.0):

1. Every test in §13 and in the items for that release is red on the previous tag (tags exist from 2.6 §3.0) and green on the release commit, on Windows and Linux, and CI is green.
2. `tools/acceptance.py` on the local DegreeAudit checkout produces every §11 row for that release. This is a **local, private** run and is not part of CI.
3. (Wherever W15 ships.) On a 2.1 document, `appdoc upgrade` plus the UPGRADE-TODO steps reaches Check PASS with `--require-audit`.
4. All four existing examples and `examples/current/mvc5-classic` pass `build --require-audit --strict` with an independent audit (2.8: fresh runs; 2.9: mechanical regeneration).
5. `tools/release.py` reports, per pattern, class, hits, precision and obligation status; every obliging pattern is deterministic or meets the labelled-set bar.
6. No **Fact or generated block** from the release contains a personal identifier (new kinds), a secret value, a URL with userinfo, path or query, or a script line (`test_conformance`, C6). The Narrative is governed by the existing template and C6 rules.
7. `tools/` and `tools/acceptance.py` follow R7 (stdlib, `unittest`, Python 3.10+, Windows and Linux); `APPDOC_*` switches are in the documented list.
8. SKILL.md, README and CONTEXT.md regenerate with `gen_docs --check` and no drift; the release's ADRs are merged; the tag exists with the gate pinned to it.

---

## Appendix A — Immediate operational step for DegreeAudit (no skill change)

This clears group A (11 findings) today on 2.4.0:

1. Add `.appdocignore` entries for the prior-documentation folders, the test-fixture project folders and the vendored script library (or `!name` to keep one) until W6 and W10 ship. The fixtures entry removes the false `aspnet-core` stack.
2. `python <AppDoc>/run_appdoc.py extract C:\Github\DegreeAudit` (schema `/5`).
3. Upgrade the document by hand following the CHANGELOG 2.2 → 2.3 → 2.4 notes in sequence (what `appdoc upgrade` will automate).
4. Read `Web.config` and its transforms, cite them with values redacted and with lines, and write the audit's security findings into 10.1.
5. Run the audit in a fresh agent, produce `evidence.jsonl`, then `build --require-audit`.

**Not a documentation task:** the audit's P0 items (the unguarded write area, the committed `machineKey`, plaintext credentials in config, and the expiry-year key before it lapses) are application defects. Raise them with the DegreeAudit team now; no AppDoc release changes them. The credentials in the transform files and connection strings are a larger exposure than the audit listed.
