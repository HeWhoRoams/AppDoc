# AppDoc Remediation Plan — DegreeAudit audit findings (v2.8.0 / v2.9.0)

**Date:** 2026-11-20 (rev 2, same day)
**Status:** Proposed. Release sequence: 2.5.0 (in flight on branch `v2.5.0`) → 2.6.0 (tooling and Facts) → 2.7.0 (template) → **2.8.0 (security and access, template 2.8)** → **2.9.0 (integrations, CI, repository docs; no template bump)**. The split is decision Q22; §10 explains it. If Q22 is declined, every item ships in 2.8.0 as in rev 1.

**Basis:**
- `DegreeAudit/docs/appdoc/appdoc-audit-report.md` (2026-11-20). This is an independent audit of the AppDoc output for a .NET Framework 4.8 MVC 5 Target (`DegreeAudit`, commit `33168dd`): 265 entry points, 6 MVC areas, Windows authentication, and Web.config transforms.
- A line-level read of `appdoc/` on branch `v2.5.0` (`__version__ = "2.4.0"`, `facts.SCHEMA = "appdoc-facts/5"`, C14–C16 already in `check.py`). The read covered `stacks/aspnet.py`, `stacks/aspnet_core.py`, `stacks/generic.py`, `smells.py`, `check.py`, `facts.py`, `extract.py` and `scan.py`.
- `docs/remediation-plan-2.5.md`, `-2.6.md` and `-2.7.md`. Nothing here repeats an item they already ship.
- ADR 0016 (principles P1–P6, binding; supporting rules R10–R15).

**Format:** the house convention. Every item has a failing test (TDD), a corpus case, and a "why this is not a weakening" line.

**Location:** this file belongs at `docs/remediation-plan-2.8.md`, beside 2.5–2.7. The rev 1 copy at the repository root can be deleted.

---

## Rev 2 changes (review of rev 1)

| # | Change | Why |
|---|---|---|
| V1 | Rules renumbered **R16–R18**. Decisions renumbered **Q22–Q28**. | ADR 0016 already defines R10–R15 (R15 is "deterministic tie-breaks", used in 2.6 §4.2). The 2.6/2.7 decision log already uses Q1–Q21. Rev 1 reused R15 and Q21. |
| V2 | The guard model splits **mechanism** (`guard`) from **who can reach it** (`reach`). Effective protection is computed per build configuration. A **production configuration** is declared, defaulting to `Release`. | Under rev 1, the Release root rule `deny ? / allow *` gives BulletinBuilder `guard: location`, so `handler-without-guard` would **not** fire and S1 would fail acceptance. |
| V3 | New pattern **`state-change-authenticated-only`**. `handler-without-guard` now means reachable anonymously. | S1 is "any signed-in domain user can write", not "anonymous". Separate patterns keep precision honest. |
| V4 | `guard`/`reach` are computed only for stacks that declare a `guard` capability. | Rev 1 computed `guard` for every `entry_point`, so every Flask and Express route would read `guard: none` and flood the public examples with false candidates. |
| V5 | New **Facts-level finding-candidate pass** (`smells.from_facts`), 5.11 part A. | `smells.extract(path, text, stacks)` is per-file (`extract.py:94`). Six of the rev 1 patterns need cross-file Facts (guard, access rules, CI jobs, build configuration) and cannot be written in the current design. |
| V6 | The precision gate is measured on **examples only**, with a minimum hit count. The corpus is excluded. | We write the corpus to make the patterns fire, so corpus precision is 1.0 by construction. No public example is classic MVC, so rev 1's gate would pass trivially. |
| V7 | **C21 fails on handles only.** The "not reviewed" phrase test becomes an advisory. | P2: the Check never passes or fails on English wording. |
| V8 | Done-means 6 is scoped to Facts and generated blocks. | §11 requires named owners, so a rule that no *document* contains a personal identifier contradicts the template. |
| V9 | Acceptance specifics move to the private answer key. This plan keeps finding IDs and pattern names only. | Rev 1 promised "no CMU identifiers copied", yet its §11 table listed DegreeAudit config keys, class names and folder names in a file committed to the AppDoc repository. |
| V10 | **0.4 Feasibility spike**: confirm each acceptance row against DegreeAudit's real code shape before building the detector. | Several rev 1 detectors match one code shape only: constructor-argument URLs, direct config reads in file paths, and `#if DEBUG` constants used as attribute arguments. The real code may use property assignment, one-hop variables, or plain `if` checks. |
| V11 | Classic .NET integration and config gaps added: `system.serviceModel` client endpoints, property-assigned service URLs, one-hop file-drop paths, nested `Web.config` authorization (recorded, but not a guard for MVC routes), and a closed set of XDT locators. | These are the common shapes in classic MVC and WCF code. |
| V12 | The CI reader is a restricted line reader for GitLab and GitHub only. `include:`, `extends:` and anchors are disclosed, not followed. Azure Pipelines and Jenkins are deferred. | R7 allows the standard library only, and the existing `_yaml` reader skips list items, which is where `script:` steps live. Jenkinsfile is Groovy. |
| V13 | WinForms and console projects keep an `entry_point type=desktop` for `Main`. | Rev 1 removed the harness from entry points altogether, so the audit's "harness hard-coded to Production" risk would have no Fact to point at. |
| V14 | Role constant **values** are recorded when the constant is used as an auth argument. The R18 conformance test is field-aware. | Role names are not people (rev 1 Q24 already accepts group names). The rev 1 test that grepped for `DOMAIN\user` would fail on legitimate `DOMAIN\Group` roles. |
| V15 | 5.6 is corrected: `detect()` must consult `facts.is_test_path`. `fixtures`/`testdata` move from `generic._TEST_CONFIG_DIRS` into `facts` (R5). | DegreeAudit's false `aspnet-core` marker sits under `tests/`, which `is_test_path` already covers; `detect()` simply never asks. Fixtures are handled for config by `generic._TEST_CONFIG_DIRS`, not by `is_test_path` as rev 1 said. |
| V16 | **Release split** (Q22): 2.8.0 ships every template change and the security and access work. 2.9.0 fills the same blocks with integration, CI and repository-doc Facts, with no template bump. `appdoc upgrade` is recommended for 2.7.0 (Q23). | Rev 1 was about 12 days, 29 items, 5 new kinds, 4 blocks, 3 rules, an upgrade tool and a render mode. 2.9 adds only advisories, so it needs no second template bump. |
| V17 | Test projects are counted in the pipeline block. | G 6.5 is "test project exists and is undocumented" as well as "CI runs no tests". Rev 1 covered only the second. |
| V18 | `config-year-horizon` fires in a window around the commit year, and is disabled (with disclosure) when the Target has no git history. `build-config-security-mode` is broadened and renamed `conditional-security-build`, and is summary-only. | Rev 1's "≤ commit year" fires on every start year (`CatalogStartYear=2010`). P3 forbids falling back to the clock. |
| V19 | Smaller fixes: new kinds are added to `facts.KINDS` as well as `DETAIL_KEYS`; `access-model` lists are capped with N of M; `appdoc upgrade` detects 2.0 vs 2.1 and never touches `evidence.jsonl`/`notes.jsonl`; 5.10 is reconciled with 2.6 duplicate folders; C22 matches areas by folder path; `render --mermaid sibling` is independent and can ship in any release; Appendix A gains the fixture excludes and the app-team items. | Consistency with code, P4 and R4. |

---

## 0. Summary

The DegreeAudit document was produced by **AppDoc 2.1**: its `facts.json` is `appdoc-facts/2` and the document carries no template stamp. The 2.4.0 Check rejects it with one C3 problem. The audit findings fall into three groups:

| Group | Count | Disposition |
|---|---|---|
| **A. Fixed by upgrading.** Template and structure failures that 2.2–2.4 already enforce: the stamp, generated blocks, §11 rows, 5.3, 16.7, the register, C11/C12. | 11 | No skill change. Re-run DegreeAudit on the current release, ideally through `appdoc upgrade` (§8.1). Until then, Appendix A. |
| **B. Already planned** in 2.5/2.6/2.7: bare-name citations, prior AppDoc output in the scan, owner-absence advisory, CI config roles, severity order. | 7 | Cross-referenced in §1. 2.8 adds only what those items miss. |
| **C. New skill defects** that would recur on 2.4.0 even with a perfect writer. The extractor cannot see the classic ASP.NET security and integration surface, it misclassifies stacks and handlers, and nothing forces the writer to read primary config or in-repo docs. | 29 | **This plan.** 2.8.0 takes the security and access rows; 2.9.0 takes integrations, CI and repository docs (§12). |

The most serious group-C finding: on 2.4.0, AppDoc would still produce **no Fact, no finding candidate and no Check problem** for a state-changing MVC area with no role guard, a committed `machineKey`, or `authentication mode="Windows"` with a per-path `<location>` access matrix. The writer has to discover all of them by hand. 2.8.0 closes that gap.

---

## 1. Disposition of every audit finding

IDs refer to the audit report: T = template, E = error, G = gap, S = security, RC = root cause, SR = skill recommendation. The **Rel** column shows the release under Q22.

| Audit ID | Finding (short) | Disposition | Where | Rel |
|---|---|---|---|---|
| T1–T3, T5–T9, T11 | No stamp; missing entry-points / appendix-a blocks, 16.7, 5.3 line, §11 rows, Evidence Register; C8–C13 not run | **A** (2.3/2.4) | Upgrade, §8.1 | 2.7/2.8 |
| T2 | Facts schema `/2` | **A** | Re-extract | — |
| T4 | No scheduled-jobs block; batch work undocumented | **A** for the block; **C** for content (no CI or queue facts) | 5.8, 6.3 | 2.9 |
| T10 | `evidence.jsonl` missing | **A** (C11, `--require-audit`) | §8.1 | — |
| Check note | Bare `CMich.DegreeAudit.csproj` resolved "yes" | **B** (2.7 §3.7, failing on stamp 2.7) | — | — |
| Check note | `Web.config` cited with no line, inside a "not reviewed" sentence | **C** | 7.1 (handle), 7.4 (advisory) | 2.8 |
| E1 | Identity provider marked "Unknown"; Windows auth is in Web.config | **C** | 5.1, 7.1 | 2.8 |
| E2 | Perceptive Content mechanism marked "Unknown"; the UNC file drop is in code | **C** | 5.7, 7.3 | 2.9 |
| E3 | Owners marked "Unknown"; the README names them | **B** (2.5 §1.4 advisory) + **C** (README harvest) | 5.9, 7.3 | 2.9 |
| E4 | Environments marked "Unknown"; README table and CI | **C** | 5.8, 5.9, 7.3 | 2.9 |
| E5 | Troubleshooting row describes an unreachable branch (deref before null check) | **C** | 5.11, 8.3 | 2.8 |
| E6 | Email fallback that cannot fire (log4net never returns null) | **C** | 5.11, 8.3 | 2.8 |
| E7 | 7 of 10 connections listed | **C** | 6.2 | 2.8 (connections half) |
| E8 | 4 of 14 role constants | **C** | 5.3, 6.1 | 2.8 |
| E9 | `[Authorize]` / `[AllowAnonymous]` usage understated | **C** | 6.1 | 2.8 |
| E10 | "8,633 files covered" (86% data XML, 5% prior docs) | **B** (2.6 §4.3, partly) + **C** | 5.6, 5.10 | 2.8 (5.6), 2.9 (5.10) |
| E11, E12 | Cosmetic range; product-name wording | Writer-level. No skill change. | — | — |
| G 6.1 | Coverage ~30 of 265 entry points; StudentCenter area and 9 root controllers absent | **C** | 5.5, 7.2 | 2.8 |
| G 6.1 (harness row) | WinForms harness hard-coded to Production | **C** | 5.6 (`type=desktop`) | 2.8 |
| G 6.2 | Rules engine, XML config corpus, workflow definitions, data model, RDLC reports | **C** (partly writer) | 5.10, 5.12 | 2.9 |
| G 6.3 | Engage CRM, ImageNow, Boomi, Workflow entanglement, metrics, log path missing | **C** | 5.7, 5.9 | 2.9 |
| G 6.4 | appSettings uncatalogued; `MaximumBulletinYear` horizon | **C** (catalog is A via 16.6; horizon is C) | 5.11 | 2.8 |
| G 6.5 | Test project absent; CI runs no tests | **C** | 5.8, 6.3, 5.11 | 2.9 |
| G 6.6 | External Documentation, Docs_original and prior doc sets not used | **C** | 5.9, 5.10 | 2.9 |
| S1 | BulletinBuilder has no role guard; any authenticated user can write `App_Data` | **C** | 5.4, 5.11 (`state-change-authenticated-only`) | 2.8 |
| S2 | `machineKey` in Web.config | **C** | 5.1, 5.11 | 2.8 |
| S3 | Plaintext passwords in Web.config | **A** (secret locations exist), surfaced better in 6.1 | 6.1 | 2.8 |
| S4 | Named users / IDs in access rules | **C** | 5.2, 5.11 | 2.8 |
| S5 | Debug build config deployed to UAT/testing, so security "Testing" mode | **C** | 5.1, 5.8, 5.11 | 2.8 (config half), 2.9 (CI half) |
| S6 | 1 of ~72 POSTs anti-forgery protected | **C** | 5.11 | 2.8 |
| S7 | Anonymous surface undocumented | **C** | 5.2, 5.4 | 2.8 |
| S8 | Inconsistent role-exception arguments | Writer-level (needs judgment). 6.1 makes it visible. | 6.1 | 2.8 |
| S9 | SAP commit before local log | Writer-level | — | — |
| S10 | Duplicate appSettings key | **C** | 5.11 | 2.8 |
| RC1 | Web.config excluded by the writer | **C** | 7.1 | 2.8 |
| RC2 | Source reading concentrated in ~12 files | **C** | 7.2 | 2.8 |
| RC3 | Template drift between write and Check | **C** | 8.1, 8.2 | 2.7/2.8 |
| RC4 | Extractor scope unfiltered (prior docs, fixtures) | **B** (2.6 §4.3) + **C** | 5.6, 5.10 | 2.8/2.9 |
| RC5 | In-repo knowledge not harvested | **C** | 5.9, 7.3 | 2.9 |
| RC6 | No source-to-claim pass | **A** | §8.1 | — |
| SR1–SR9 | Skill recommendations | Mapped to 7.1, 7.2, 5.11, 5.10, 7.3, (2.7 §3.7), (A), 8.2, 8.4. SR2's "90% coverage threshold" is not adopted (R8: no threshold heuristic as a gate); 7.2 gates the security-relevant subset instead. | — | — |

---

## 2. Root causes (new; continuing the RC-A…RC-E series from 2.5)

| # | Root cause | Findings | Fixed by |
|---|---|---|---|
| RC-F | **Security-bearing config is optional input.** The writer may skip Web.config, and nothing checks that it was read. `generic._dotnet_config` reads only `appSettings` and `connectionStrings`, so there are no Facts for `system.web` or `system.serviceModel`. | E1, S2, S5, RC1 | 5.1, 5.2, 7.1 |
| RC-G | **Authorization is extracted as attribute hits, not as effective protection per handler.** `_AUTH_CS` knows only `Authorize` and `AllowAnonymous`. Custom guards (`SapRoleCheck`), base classes, global filters and `<location>` rules are invisible, and there is no notion of *who* can reach a handler (anonymous, any authenticated user, a role). | S1, S6, S7, E8, E9 | 5.3, 5.4 |
| RC-H | **Stack and handler classification errors.** `aspnet_core.detect` fires on any `.csproj` plus `Program.cs` (WinForms and MVC 5 included) and never consults `facts.is_test_path`. `_handlers` emits WinForms event handlers as web entry points. `_controller_actions` ignores `[RouteArea]` and area folders. | E10, false `aspnet-core` stack, 43 desktop "entry points", area-less routes | 5.5, 5.6 |
| RC-I | **Integrations by convention are not Facts.** Clients configured from a config URL (Engage), WCF endpoints in config, file drops to a UNC path from config (ImageNow) and CI pipelines produce no `external_call` or job Facts. | E2, E4, G 6.3, G 6.5, T4 | 5.7, 5.8 |
| RC-J | **In-repo documentation is not an input.** README owner and environment sections and `docs`-style folders are not surfaced, so the writer marks things Unknown that the repo answers. | E3, E4, G 6.6 | 5.9, 7.3 |
| RC-K | **Coverage is advisory and per-file.** C13 (Entry points not cited) fails only under `--strict`. Nothing requires every **area** to be documented or every **unguarded or state-changing** handler to be read. | G 6.1, RC2 | 7.2 |
| RC-L | **Scan counts mix source with data and prior documentation.** Content-data folders (7,473 XML) and v1 AppDoc or other-tool output are counted as files covered. 2.6 §4.3 prunes only *stamped* AppDoc 2.x output. | E10, RC4 | 5.10 |
| RC-M | **Upgrading is manual.** The 2.2/2.3/2.4 upgrade notes are mechanical but have no tool, so a 2.1 document sits un-upgraded. | T1–T11, RC3 | 8.1, 8.2 |
| RC-N | **Finding candidates are per-file text patterns only.** There are no candidates that combine Facts (guard × verb × config × pipeline), and none for classic .NET correctness traps: dereference before null check, dead fallback on a never-null factory, config time horizons. | S1, S5, S6, E5, E6, G 6.4 | 5.11 |

---

## 3. Rules for this release

R1–R9 (2.5) and R10–R15 (ADR 0016; 2.6/2.7) carry forward unchanged. Three additions:

- **R16 Primary runtime config is mandatory input.** Values are redacted, never skipped. A file that holds security settings, access rules or application-role keys must be cited (RC-F).
- **R17 Facts describe effective behaviour per build configuration when the Target declares transforms.** A transform file (`Web.<Config>.config`, `appsettings.<Env>.json`) produces per-configuration detail keyed by the build configuration name; it never overwrites the base Fact. Deployment environments join to build configurations only through `ci_job.build_config` (5.8), never by name guessing (R3). The **production configuration** is `Release` (the MSBuild default name, so R3 holds) unless `appdoc-context.md` declares `Production config: <name>` (RC-F, S5).
- **R18 Personal identifiers are counted, never recorded, in Facts and generated blocks.** User accounts in access rules, employee IDs in config, and names in README owner sections are recorded as counts and locations only, consistent with the existing `owner_file` rule ("entry counts only, never names or emails"). Role and group names are not personal identifiers and are recorded. The Narrative follows the existing template rules (§11 names owners).

---

## 4. Phase 0 — Reproduce and pin (do first)

**0.1 Synthetic corpus Target `mvc5-classic`** (`tests/corpus/mvc5-classic/`, inside the `tests/corpus/` layout and `tests/test_corpus.py` module that 2.5 creates). It reproduces every DegreeAudit pattern with invented names. **No CMU code or identifiers are copied** (R18; DegreeAudit is private). It has:
- three areas: one requires a role, one writes files with no guard and no `<location>` (authenticated-only once the Release transform applies), and one is reachable anonymously through `[AllowAnonymous]`;
- a custom `[RoleGate]` attribute from an external package (not defined in the Target), with arguments that are `const` role names;
- `Global.asax`, `FilterConfig` with only `HandleErrorAttribute`, and a `BaseController`;
- `Web.config` with `authentication mode="Windows"`, a root `<authorization>` with roles and two named users, four `<location>` rules, `machineKey`, `customErrors Off`, `compilation debug="true"`, a duplicate appSettings key, a `MaxCatalogYear` key equal to the corpus commit year, and a `system.serviceModel/client/endpoint`;
- `Areas/Reports/Web.config` with its own `<authorization>` (physical-path rule only);
- `Web.Release.config` that removes `debug`, sets `customErrors RemoteOnly`, and replaces root authorization with `deny ? / allow *`, using `xdt:Locator="Match(key)"`, plus one unsupported `xdt:Locator="XPath(...)"`;
- a `.gitlab-ci.yml` deploying `Debug` to UAT and testing, with no test job, one `extends:` and one `include:`;
- a client whose `Url` property is set from `ConfigurationManager.AppSettings["CrmProxyUrl"]`, and a UNC file drop whose path comes from `AppSettings["DocDropUncPath"]` through one local variable;
- a test project with five `[TestMethod]`s;
- a WinForms test-harness project (`OutputType WinExe`, `Program.cs`);
- `fixtures/sample-core-app/` (not under `tests/`) with an ASP.NET Core `.csproj`, and `tests/powershell/fixtures/sample-app/` with another;
- a README with "Business Owner" and environment tables, and an `External Documentation/` folder;
- a `docs_v1/` folder with AppDoc 1.x output (`architecture-fingerprint.json`, `evidence/evidence-graph.json`) and an `App_Data/Catalog/` folder with 400 XML files.

**0.2 Corpus cases** (all red on `v2.7.0`; `tests/test_corpus.py`). Cases marked † are 2.9.0 under Q22.

| Case | Asserts |
|---|---|
| `webconfig-security` | `security_setting` Facts for auth mode, machineKey (secret location), customErrors, debug, per build configuration |
| `xdt-locators` | `Match` transforms applied; the `XPath` transform is disclosed as `transform_unsupported`, not applied |
| `location-rules` | `access_rule` Facts: path, allow/deny, roles by name, users as a **count** |
| `nested-webconfig` | The `Areas/Reports/Web.config` rule is an `access_rule` with `applies: physical`; it does not change `reach` for routed MVC handlers |
| `custom-guard` | `RoleGate` is reported as an unclassified candidate; after `Auth attributes: RoleGate` in `appdoc-context.md`, it is an `auth_check` with the role constant name **and value** |
| `effective-guard` | Per production configuration: the role area has `reach: role`; the file-writing area has `reach: authenticated` (Release) and `reach: role` (base); the anonymous area has `reach: anonymous` |
| `guard-capability` | No `guard`/`reach` detail on `python-flask` or `node-express` sample entry points |
| `route-area` | Routes carry the `[RouteArea]` prefix and `area` detail |
| `core-false-positive` | No `aspnet-core` stack; both fixture folders are ignored; `ignored_markers: 2` |
| `winforms-handlers` | No web `entry_point` from the WinForms project; one `entry_point type=desktop` for its `Main` |
| `smells-net` | One hit for each 2.8 pattern in §5.11, and no hit on the negative fixture |
| `smells-from-facts` | The Facts-level pass produces `state-change-authenticated-only`, `handler-without-guard`, `debug-settings-deployed` and `post-without-antiforgery`, each with a stable `fid` across two runs |
| `config-not-reviewed` | C21 fails when Web.config is not cited with a line; the "not reviewed" sentence is a C20 advisory |
| `area-coverage` | C22 fails when an area folder is absent from §4.1 |
| `upgrade-2-1` | `appdoc upgrade` brings a 2.1 document to a state that fails only on content rules (only if Q23 places upgrade in 2.8) |
| `config-client` / `unc-drop` / `wcf-endpoint` † | `external_call type=service` (property-assigned and config endpoint) and `type=file_drop`, each with the config key |
| `ci-jobs` † | `ci_job` Facts with stage, trigger, environment, build configuration and step classes; `extends`/`include` disclosed; `ci-without-test` candidate; the test project is counted |
| `readme-topics` † | `doc_file` Facts with tagged headings (owner, environment); no names recorded |
| `v1-output` / `content-folder` † | Pruned as `AppDoc output (v1)`; counted as content, not source |

**0.3 Private acceptance target.** `tools/acceptance.py` runs against a local, uncommitted DegreeAudit checkout and an answer key kept outside the repo (`$APPDOC_ACCEPTANCE_KEYS/degreeaudit.json`; an R13 documented switch). Every group-C row in §1 must be produced as a Fact, a finding candidate, a generated-block line or a Check problem (§11). The key holds the DegreeAudit-specific names (config keys, classes, folders). The repository holds only finding IDs and the Fact kind or pattern expected for each.

**0.4 Feasibility spike (half a day, before Phase 1).** For each §11 row, read the DegreeAudit code that the planned detector must match. Record the shape in the private key (for example: "URL assigned to a property, not passed to the constructor"; "path from a field set in the constructor"; "security mode read in `if`, not passed to an attribute"). Then adjust the 5.x specification before writing code. Any row the closed-set rules cannot reach without guessing becomes "writer-level, made visible by block X" instead of a detector. That is cheaper than discovering it at acceptance time.

---

## 5. Phase 1 — Extractor (Facts schema `appdoc-facts/8`)

Every new kind is added to `facts.KINDS` **and** `facts.DETAIL_KEYS`, and declared in the emitting stack's `capabilities` (2.6 §4.1: class-level, typed, one lookup).

### 5.1 .NET `system.web` / `system.webServer` / `system.serviceModel` settings (RC-F → E1, S2, S5) — 2.8

**Change** (`stacks/generic.py`, `_dotnet_config`):
1. Read the closed set of security-bearing elements:
   - `authentication@mode`, `forms@requireSSL`;
   - `machineKey` (presence, and whether keys are literal or `AutoGenerate`);
   - `customErrors@mode`, `compilation@debug`, `httpCookies@requireSSL/httpOnlyCookies`;
   - `sessionState@mode/cookieless`, `trace@enabled`, `httpRuntime@requestValidationMode`;
   - `identity@impersonate`, `httpErrors@errorMode`.
2. Emit a new kind, **`security_setting`**: name `system.web/authentication@mode`, `value` from a **closed enumeration** only (`Windows|Forms|None|On|Off|RemoteOnly|true|false|literal|auto`). A literal `machineKey` sets `secret_location: true` and never records a value. A value outside the enumeration is recorded as `value: other`.
3. **Transforms (R17).** For `Web.<Config>.config`, apply the closed transform set (`Replace, Insert, Remove, RemoveAll, RemoveAttributes, SetAttributes`) and the closed locator set (none, `Match(attr[,attr])`, `Condition` restricted to `@attr='literal'`) to these elements and to `<authorization>`/`<location>` only. Emit `security_setting` with `config: <Config>`. The base Fact stays (`config: base`). Any other locator or transform gives one `security_setting` named `transform_unsupported` with `element` and line, and that element is left un-transformed for that configuration (R4: state what was read).
4. **WCF client endpoints.** `system.serviceModel/client/endpoint` gives `external_call type=service via=<contract> config_key=<endpoint name>`, with no address value recorded (the address host may be recorded when it is a literal URL, the same as existing `connection` handling). This is under 5.1 because it uses the same XML pass; it ships in 2.8 so 6.2 can list it.
5. `facts.DETAIL_KEYS["security_setting"] = {"value", "config", "secret_location", "element"}`.

**Why this is not a weakening:** these are new Facts. No existing Fact changes.

**Tests:**
- `test_generic_facts`: `::test_system_web_settings`, `::test_machinekey_secret_location_no_value`, `::test_transform_release_sets_customerrors`, `::test_transform_remove_debug`, `::test_match_locator`, `::test_unsupported_locator_disclosed`, `::test_unknown_value_is_other`, `::test_wcf_client_endpoint`.
- `test_conformance`: closed values only.

Corpus `webconfig-security`, `xdt-locators`.

### 5.2 Access rules from `<authorization>` and `<location>` (RC-F, RC-G → S4, S7) — 2.8

**Change:**
1. Emit a new kind, **`access_rule`**, per `<allow>`/`<deny>`, in document order (first match wins in ASP.NET URL authorization, so `order` is recorded), with detail:
   - `path` (`/` for root, else the `location@path`);
   - `effect` (allow/deny), `order`;
   - `roles` (group names as written);
   - `users_named` (a **count**, R18; `?` and `*` are recorded as `anonymous`/`all` flags);
   - `config`;
   - `applies`: `url` for root and `<location>` rules in the application-root `Web.config`; `physical` for rules in a nested `Web.config` (for example under `Areas/X/`). URL authorization in nested files applies to the folder's URL path, which routed MVC URLs do not use, so a `physical` rule never changes `reach` for an MVC route (5.4). It is listed in 6.1 under "Folder rules that do not apply to routed URLs".
2. Transforms apply as in 5.1, so the Release `deny ? / allow *` root rule appears with `config: Release`.

**Tests:** `test_generic_facts`: `::test_location_rules`, `::test_rule_order_recorded`, `::test_named_users_counted_not_recorded`, `::test_root_rule_transformed`, `::test_nested_webconfig_rule_physical`. Corpus `location-rules`, `nested-webconfig`.

### 5.3 Custom authorization attributes (RC-G → E8, E9) — 2.8

**Change** (`stacks/aspnet.py`, `stacks/aspnet_core.py`):
1. **In-Target guards.** An attribute class declared in the Target that derives from `AuthorizeAttribute` or `AuthorizationFilterAttribute`, or implements `IAuthorizationFilter`/`IAsyncAuthorizationFilter`, is an auth attribute. This set is defined by the framework, so R3 holds. Its uses become `auth_check` with `via: custom`.
2. **External guards.** An attribute used on ≥3 controller classes or actions that is neither framework-known nor declared in the Target is recorded as a `guard_candidate` Fact (name, use count). The facts summary lists these under **Unclassified controller attributes**. Under R3, a name people choose triggers a question, never a behaviour.
3. **Owner declaration.** An `appdoc-context.md` line `Auth attributes: RoleGate, SapRoleCheck` promotes those names to `auth_check via: declared`. Arguments are recorded:
   - a string literal: as `role`;
   - a `const` or `static readonly` string reference: as `role_ref` (the qualified name), plus `role` (its value) when the constant is a string literal in the Target. Role names are group names, not people (R18, Q25);
   - anything else: `role_ref: expression`.

**Tests:** `test_facts_aspnet`: `::test_in_target_authorize_subclass`, `::test_guard_candidate_threshold`, `::test_declared_auth_attribute`, `::test_const_role_argument_name_and_value`, `::test_non_literal_role_argument`. Corpus `custom-guard`.

### 5.4 Effective protection per handler (RC-G → S1, S6, S7, G 6.1) — 2.8

**Change** (`extract.py` post-pass, after all stacks; one implementation in `appdoc/guard.py`):
1. **Scope.** Computed only for `entry_point type=route|page` emitted by a stack whose `capabilities` include `guard` (in 2.8: `aspnet`, `aspnet_core`). Other stacks get no `guard`/`reach` keys, and 6.1 says which stacks report protection (R4, capability-aware "none").
2. **Mechanism** (`guard`, closed set), taken from the first source that applies:
   - method attributes;
   - class attributes;
   - the base-class chain within the Target (`BaseController`);
   - global filters registered in `FilterConfig.RegisterGlobalFilters` (`filters.Add(new X())`);
   - the first matching `applies: url` `access_rule` set for the most specific `path` that is a prefix of the route.

   Values: `attribute`, `declared`, `base`, `global`, `location`, `none`, or `unknown` (a `guard_candidate` is present but undeclared).
3. **Reach** (`reach`, closed set), computed **per build configuration** and stored as `reach` (production configuration, R17) plus `reach_by_config` (a sorted map, only when transforms exist):
   - `anonymous`: an explicit `AllowAnonymous`, `allow users="?"`, or `allow users="*"` before any deny for an unauthenticated request, or no rule at all with auth mode `None`;
   - `authenticated`: the only restriction is `deny users="?"` or an `[Authorize]` with no roles or users;
   - `role`: a role-bearing attribute, a declared guard, or an `access_rule` that allows roles and denies others;
   - `user`: allowed only to named users;
   - `unknown`: `guard: unknown`, or an expression role argument.
4. Also record `state_changing: true` for POST/PUT/PATCH/DELETE, or a GET that hits the existing `state-change-on-get` pattern.

**Why this is not a weakening:** this is derived detail on existing Facts. `unknown` is never collapsed into `none` or `anonymous`.

**Tests:** `test_core`: `::test_guard_method_beats_class`, `::test_guard_base_controller`, `::test_guard_global_filter`, `::test_guard_location_prefix`, `::test_guard_unknown_when_candidate`, `::test_reach_authenticated_from_release_root_rule`, `::test_reach_by_config_only_with_transforms`, `::test_production_config_declared`, `::test_physical_rule_ignored_for_routes`, `::test_no_guard_keys_without_capability`. Corpus `effective-guard`, `guard-capability`.

### 5.5 Route fidelity: areas and prefixes (RC-H → G 6.1) — 2.8

**Change** (`stacks/aspnet.py` `_controller_actions`, `_route_tables`):
1. Apply `[RouteArea("X", AreaPrefix = "p")]` to attribute routes.
2. For conventional routes, map a controller to its area by the `Areas/<X>/Controllers/` path and the `AreaRegistration` `MapRoute` URL.
3. Add `area` (the area name) and `area_path` (`Areas/<X>`) detail to every MVC `entry_point`. Collapse exact duplicates (same route, verb and handler).

**Tests:** `test_facts_aspnet`: `::test_routearea_prefix_applied`, `::test_area_from_folder_and_registration`, `::test_duplicate_route_collapsed`. Corpus `route-area`.

### 5.6 Stack and handler classification (RC-H → E10, false stack, desktop handlers) — 2.8

**Change:**
1. **`aspnet_core.detect`:** require a `.csproj` with `Sdk="Microsoft.NET.Sdk.Web"` or a `Microsoft.AspNetCore.*` package or framework reference. A `.csproj` plus `Program.cs` alone no longer qualifies.
2. **All `detect()` implementations** drop marker paths where `facts.is_test_path(p)` is true. Today no `detect()` consults it, which is why DegreeAudit's `tests/powershell/fixtures/` produced an `aspnet-core` stack. Separately, move the fixture folder set (`fixtures`, `__fixtures__`, `testdata`, `*testdata`, `e2e`) from `generic._TEST_CONFIG_DIRS` into `facts` as `is_test_data_path`, used by both `generic.config_role` and `detect()` (R5: one implementation). The `stack` Fact records `ignored_markers: N`. Expect example Facts to change where fixture folders sit outside `tests/` (the answer keys from 2.6 §7.1 are re-baselined in the same commit).
3. **`aspnet._handlers`:** emit Web Forms handlers only for code-behind of `.aspx`/`.ascx`/`.master`, or for classes deriving from `Page`/`UserControl`/`MasterPage`. In a project with `<OutputType>WinExe</OutputType>` or `Exe`, or a class deriving from `Form`:
   - forms become `ui_page type=form`;
   - the project's `static void Main` becomes one `entry_point type=desktop` (project and file), so a harness stays visible to the writer.

**Tests:**
- `test_facts_aspnet_core`: `::test_no_core_without_web_sdk`, `::test_test_path_markers_ignored`, `::test_fixture_markers_outside_tests_ignored`.
- `test_facts_aspnet`: `::test_winforms_handlers_not_entry_points`, `::test_desktop_main_entry_point`, `::test_codebehind_handlers_still_found`.
- `test_generic_facts::test_config_role_uses_facts_test_data_path`.

Corpus `core-false-positive`, `winforms-handlers`.

### 5.7 Integration Facts by convention (RC-I → E2, G 6.3) — 2.9

**Change** (`stacks/aspnet.py` `dotnet_common`, with the same pattern in `aspnet_core`, `java_spring` and `node_express` where cheap):
1. **Config-configured clients.** A config read (`AppSettings["K"]`, `WebConfigurationManager.AppSettings["K"]`, `configuration["K"]`) where `K` matches the closed suffix set `Url|Uri|Endpoint|BaseAddress|Host|Wsdl`, and the value reaches either:
   - a constructor argument of `new T(...)`;
   - an assignment to `.Url`, `.BaseAddress` or `.Endpoint.Address` on an instance of `T`;
   - `new EndpointAddress(...)` passed to `T`.

   This gives `external_call type=service via=T config_key=K`.
2. **File drops.** `File.Write*`, `File.Copy`, `Bitmap.Save`, `Image.Save` or `FileStream` writes whose path expression contains, directly or through **one** local, field or property assignment in the same file, a config read of a key matching `Unc|Path|Drop|Share|Folder|Directory`, or a literal starting `\\`. This gives `external_call type=file_drop config_key=K`. A write whose path cannot be traced in one hop gives `external_call type=file path_ref=<identifier>` and no guess. Local `App_Data` writes stay `type=file`.
3. SMTP is unchanged. WCF endpoints come from 5.1.

**Tests:** `test_facts_aspnet`: `::test_config_url_ctor_client`, `::test_config_url_property_client`, `::test_unc_file_drop_one_hop`, `::test_untraced_path_not_guessed`, `::test_app_data_write_is_local_file`. Corpus `config-client`, `unc-drop`, `wcf-endpoint`.

### 5.8 CI pipeline Facts (RC-I → E4, G 6.5, S5, T4) — 2.9

**Change** (`stacks/generic.py`, a new restricted line reader for `.gitlab-ci.yml` and `.github/workflows/*.yml`; standard library only, R7):
1. The reader understands top-level job maps, `stage`, `only`/`except`/`rules` (branch, tag, `when: manual`, merge request), `environment` (`name`, `url`), `variables` (same file only) and `script` lists. Anchors, `extends:` and `include:` are **not followed**. Each is recorded on the job as `unresolved: [extends|include|anchor]` and disclosed in the pipeline block (R4). Azure Pipelines and Jenkinsfile are deferred to a later release (Groovy is not declarative YAML); the pipeline block names them as "not read" when present.
2. Emit a new kind, **`ci_job`**, with detail:
   - `stage`;
   - `trigger` (a closed summary: `branch:<pattern>`, `tag:<pattern>`, `manual`, `mr`);
   - `environment` (name, and URL if it is a literal);
   - `build_config` (the value of `/p:Configuration=` / `-c`, resolved through pipeline variables defined in the same file);
   - `steps` (a closed classification `restore|build|test|package|deploy|other` by tool verb: `nuget restore`, `dotnet test`, `vstest`, `msbuild /p:DeployOnBuild`, …).
3. **Test projects.** A `.csproj` referencing `MSTest.TestFramework`, `xunit`, `NUnit` or `Microsoft.NET.Test.Sdk`, or holding `[TestMethod]`/`[Fact]`/`[Test]` methods, gives one `test_suite` Fact (project, framework, method count). Equivalents for pytest, JUnit and Jest come from existing test-path detection (count only).
4. These Facts feed 16.5 (Build, Test, Deploy rows) and the pipeline block (6.3). This is coordinated with 2.5 §1.5 (`ci` config role): same file list, one reader.

**Tests:** `test_generic_facts`: `::test_gitlab_ci_jobs`, `::test_build_config_resolved_from_variables`, `::test_step_classification`, `::test_github_workflow_jobs`, `::test_extends_include_disclosed`, `::test_script_list_items_read`, `::test_test_suite_counted`. Corpus `ci-jobs`.

### 5.9 In-repo documentation as input (RC-J → E3, E4, G 6.6) — 2.9

**Change** (`stacks/generic.py`):
1. Emit a new kind, **`doc_file`**, for `README*` at any depth, and for `*.md`/`*.htm*`/`*.docx` (name only for `.docx`) under folders that hold no code and are not pruned.
2. Detail:
   - `headings`, each `(line, text)` for Markdown and HTML;
   - `topics`, a closed tag set matched on heading words: `owner` (owner, contact, maintainer, support, SME, expert), `environment` (environment, server, URL, database, deploy), `authorization` (authorization, roles, access), `troubleshooting` (troubleshoot, ticket, known issue, FAQ), `operations` (runbook, backup, restore, rollback);
   - `owner_entries` (a **count** of mailto links or `Name -` patterns under an `owner` heading, R18).
3. The facts summary gains **Repository documentation** (path, topics). This pairs with 2.5 §1.4 (owner advisory) and 7.3 (answerable-by-repo advisory).

**Tests:** `test_generic_facts`: `::test_readme_topics`, `::test_owner_entries_counted_no_names`, `::test_docs_folder_with_code_not_doc_file`. Corpus `readme-topics`.

### 5.10 Scan accounting: prior documentation and content folders (RC-L → E10, RC4) — 2.9

**Change** (`scan.py`; extends 2.6 §4.2 and §4.3):
1. **`AppDoc output (v1)`:** a folder holding `architecture-fingerprint.json` and `evidence/evidence-graph.json`. This is AppDoc's own published layout, so R3 holds. It is pruned and disclosed like 2.x output.
2. **`Generated documentation candidate`** (a question, not a behaviour, R3): a folder that holds no code, has ≥20 files, and in which ≥80% of the files are `.json`/`.md`/`.html`, with ≥3 file names repeated in a sibling folder. A folder already paired in 2.6 `duplicate_folders` is reported there only, not twice. Candidates are listed in 2.1 under "Folders that look like copies of documentation (not excluded)", and C7 requires 2.1 to name them by path (a handle; same pattern as 2.4 retired candidates).
3. **Content-data folders:** a folder that holds no code, has ≥200 files, and in which ≥95% of the files share one data extension (`.xml`, `.config`, `.json`, `.csv`). Its files are counted as `content` in `target.scan` and are excluded from "files read" in the facts summary and the 2.1 block. Config-key extraction still runs. The block prints `Source F · Content C (in N folders) · Documentation D · Pruned P`.

**Tests:** `test_core`: `::test_prune_v1_output`, `::test_doc_copy_candidate_named_in_2_1`, `::test_doc_copy_not_duplicated_with_duplicate_folders`, `::test_content_folder_counted_separately`, `::test_scan_reconciles_with_content`. Corpus `v1-output`, `content-folder`.

### 5.11 Finding candidates for .NET security and correctness (RC-N → S1, S2, S4–S6, S10, E5, E6, G 6.4, G 6.5)

**Part A — Facts-level pass (new; 2.8).** `smells.from_facts(facts) -> list[Fact]` runs in `extract.py` after the 5.4 post-pass and before `facts.json` is written. It reads only Facts, never source text, so it is deterministic by construction (P3). Each hit is a `smell` Fact anchored at the most specific Fact's path and line, with `fid = fact_id("smell", pattern, path, line)` (the same scheme as the per-file pass) and `sources` listing the Fact ids it combined. Per-file patterns stay in `smells.extract`. The two passes never emit the same pattern.

**Part B — Patterns.** Each has a positive and a negative corpus fixture.

| Pattern | Pass | Fires when | Source Facts | Rel |
|---|---|---|---|---|
| `handler-without-guard` | facts | `state_changing` and `reach: anonymous` in the production configuration | 5.4 | 2.8 |
| `state-change-authenticated-only` | facts | `state_changing` and `reach: authenticated` in the production configuration, **and** the Target has at least one handler with `reach: role` (so roles exist and this area does not use them); one hit per controller | 5.4 | 2.8 |
| `machinekey-in-config` | facts | literal `machineKey` in any config | 5.1 | 2.8 |
| `debug-settings-deployed` | facts | `compilation@debug=true` or `customErrors=Off` in the effective config of a non-base configuration that a `ci_job` deploys. In 2.8, before CI Facts exist: in any non-base configuration other than `Debug` | 5.1, 5.8 | 2.8, extended 2.9 |
| `named-user-access-rule` | facts | `access_rule users_named > 0` | 5.2 | 2.8 |
| `post-without-antiforgery` | facts | ≥1 `state_changing` MVC POST in a controller without `[ValidateAntiForgeryToken]` (or a global anti-forgery filter), where auth mode is Windows or Forms, or cookie auth is configured; one hit per controller | 5.1, 5.4 | 2.8 |
| `duplicate-config-key` | text | the same key defined twice in one `appSettings` | — | 2.8 |
| `deref-before-null-check` | text | `x.M`/`x.P` on a local, then `if (x == null)` in the same block, with no reassignment between | — | 2.8 |
| `dead-null-fallback` | text | `if (x != null) … else …` where `x` comes from a closed set of never-null factories: `log4net.LogManager.GetLogger`, `NLog.LogManager.GetLogger/GetCurrentClassLogger`, `ILoggerFactory.CreateLogger` | — | 2.8 |
| `config-year-horizon` | facts | a non-secret config value that is exactly a 4-digit year Y with `commit_year − 1 ≤ Y ≤ commit_year + 1`, where `commit_year` comes from `target.history` (git). Only `value_year` is recorded. With no git history the pattern does not run, and the facts summary says so (P3: no clock fallback). | 5.1 | 2.8 |
| `conditional-security-build` | text | a file with an `auth_check` that also contains `#if DEBUG` / `#if !DEBUG` blocks assigning a field or constant. **Summary-only** (R8): it can't tell a security mode from logging. | 5.3 | 2.8 |
| `ci-without-test` | facts | a `ci_job` with `deploy`, no job with `test`, and ≥1 `test_suite` | 5.8 | 2.9 |

**Part C — Precision gate (R8; amended from rev 1).**
- `eval/smell_precision.py` measures each pattern on the **public examples only**. The corpus proves recall and the negative cases; its precision is 1.0 by construction and is not counted.
- A pattern obliges C12 (cite or dismiss) only when it has **≥5 hits** across the examples **and** precision ≥ 0.8. Otherwise it is summary-only: listed in the facts summary as a candidate and not a C12 obligation.
- The private DegreeAudit run contributes **counts only** (true and false positives judged by the private key) to the release report. It is not part of the committed gate.
- Expected outcome: none of the four public examples is classic MVC, so most 2.8 patterns ship summary-only until `examples/current/mvc5-classic` exists (Q24). `tools/release.py` prints the obligation status of each pattern.

**Why this is not a weakening:** additional candidates only. C12 already requires each obliging candidate to be cited or dismissed with a reason.

**Tests:** `test_smells`: one positive and one negative per pattern (24 tests), plus `::test_from_facts_deterministic_fid`, `::test_from_facts_reads_no_source`, `::test_year_horizon_window`, `::test_year_horizon_skipped_without_git`, `::test_never_null_factory_closed_set`, `::test_authenticated_only_needs_role_elsewhere`. `tests/test_release.py::test_obligation_needs_min_hits`. Corpus `smells-net`, `smells-from-facts`.

### 5.12 Data and report surface (G 6.2) — 2.9

**Change:**
1. **`schema_object` from EF 6 `.edmx` and `DbContext`:** `EntitySet`/`EntityType` names (`stacks/aspnet.py`).
2. **`ui_page type=report`:** for `.rdlc`/`.rdl` files (name and dataset names).
3. **`data_access type=sql`:** schema-qualified objects in `SqlCommand` text are already found. Add `schema` detail so 8.4 can group them.

**Tests:** `test_facts_aspnet`: `::test_edmx_entities`, `::test_rdlc_report_page`, `::test_sql_schema_detail`.

---

## 6. Phase 2 — Generated blocks (template 2.8)

All four block markers and their headings ship in **2.8.0**, so 2.9.0 needs no template bump: a block whose Facts arrive in 2.9 renders the R4 capability-aware "none" in 2.8 ("No supported Stack reports CI jobs yet; read `.gitlab-ci.yml`"). Each block follows R4: it states what a script read, says "N of M" for every capped list, and names which stacks could report a "none".

### 6.1 `access-model` block in 5.4 (new subsection "Effective access (generated)") — 2.8

Renders, for the production configuration and then each other configuration that differs:
- auth mode;
- the access-rule matrix (path × allow/deny roles, `users: N named`), capped at 40 rows with N of M;
- folder rules that do not apply to routed URLs (`applies: physical`);
- per area, handler counts by `reach`, listing every state-changing `reach: anonymous|authenticated|unknown` handler by route and file (capped at 60 with N of M; the full list is in `facts.json`);
- custom guard attributes (declared or candidate) with use counts;
- role names and role constants referenced by guards;
- the stacks that report protection, and those that don't.

This makes E8, E9, S1, S7 and S8 visible without the writer finding them. ADR 0019 records that this block is an attack-surface summary and that the document's distribution follows the Target's own access rules.

**Tests:** `test_fill`: `::test_access_model_block`, `::test_access_model_config_columns`, `::test_unguarded_handlers_listed`, `::test_access_model_caps_n_of_m`, `::test_access_model_capability_none`.

### 6.2 `integrations` block in 8.3 — 2.8 (connections, WCF), 2.9 (convention calls)

Groups `external_call` by `type` (`service`, `file_drop`, `smtp`, `http`, `file`), with the config key and call sites. `connection` Facts are listed with every name defined in config, so 10 of 10 connections appear (this fixes E7 by construction, in 2.8).

**Tests:** `test_fill::test_integrations_block`, `::test_connections_all_listed`.

### 6.3 `pipeline` block in 16.8 (new subsection "Pipeline (generated)") — markers 2.8, content 2.9

One row per `ci_job`: stage, trigger, environment, build configuration, and step classes. Then:
- test suites (project, framework, method count);
- the trailer `No job runs tests.` when true;
- unresolved `extends`/`include`/anchors;
- CI files present but not read (Azure, Jenkins).

**Tests:** `test_fill::test_pipeline_block`, `::test_pipeline_no_test_trailer`, `::test_pipeline_unresolved_disclosed`.

### 6.4 `repo-docs` block in 2.1 — markers 2.8, content 2.9

Lists the `doc_file` Facts with topics, plus "copies of documentation" candidates (5.10). The writer must read every file tagged `owner`, `environment` or `operations` before writing §11, §14 or §16 (SKILL rule, 8.3).

**Tests:** `test_fill::test_repo_docs_block`.

### 6.5 Scan-coverage block split (5.10) — 2.9

The source, content, documentation and pruned counts replace the single "files" number.

**Tests:** `test_fill::test_scan_split_counts`.

---

## 7. Phase 3 — Check rules

The new failing rules are gated on the document stamp (`template_spec.version_tuple(stamp) ≥ (2, 8)`). On earlier stamps they run as advisories labelled "fails from template 2.8" (Q19 precedent).

### 7.1 C21 — Mandatory inputs cited (R16 → RC1, E1) — 2.8

Every file that holds a `security_setting` or `access_rule` Fact, or an `app`-role `config_key` with `secret_location`, must be cited **with a line** at least once in sections 3–10 or 16. That is a handle check only (P2). The failure reads: `this file is mandatory input (R16); read it and cite what it shows, redacting values`.

The rev 1 "exclusion phrase" test (`not reviewed`, `not inspected`, `excluded`, `was not read`) reads English, so it moves to 7.4 as an advisory.

**Why this is not a weakening:** it is a new failure.

**Tests:** `test_check`: `::test_c21_uncited_security_config_fails`, `::test_c21_unlined_citation_fails`, `::test_c21_advisory_on_2_7_stamp`, `::test_c21_ignores_wording`. Corpus `config-not-reviewed`.

### 7.2 C22 — Area and protection coverage (RC-K → G 6.1, RC2) — 2.8

1. Every `area_path` on an `entry_point` must appear as a folder path in a §4.1 row (a handle, matched like the existing C7 4.1 folder check) and, by the existing C10, in 5.3.
2. Every handler file with a `state_changing` handler, or with `reach` of `anonymous`, `authenticated`, `user` or `unknown`, must be cited. This is the security-relevant subset of C13, promoted from advisory to failing. It is implemented as a filter on C13's existing citation map (R5: one implementation).
3. C13 stays advisory for the remaining read-only, role-guarded handlers (R8: no threshold heuristic).

**Tests:** `test_check`: `::test_c22_area_missing_from_4_1_fails`, `::test_c22_unguarded_file_uncited_fails`, `::test_c22_readonly_guarded_stays_advisory`, `::test_c22_shares_c13_map`. Corpus `area-coverage`.

### 7.3 C23 — Unknown that the repository may answer (advisory; RC-J → E3, E4, E1, E2) — 2.8 for auth, 2.9 for the rest

For each §14 row and each "Unknown - see Open questions." paragraph, match its words against the closed topic vocabulary (5.9). If a `doc_file` with that topic exists, or (for auth, integration and environment topics) a `security_setting`, `external_call type=file_drop|service` or `ci_job environment` Fact exists, the advisory names the location: `the repository may answer this: README.md:29 (owner)`. It fails only under `--strict` (R8). The audit's existing `Answerable` classification remains the binding mechanism.

**Tests:** `test_check`: `::test_c23_owner_unknown_with_readme_owner_topic`, `::test_c23_identity_unknown_with_auth_setting`, `::test_c23_strict_fails`.

### 7.4 C20 advisory: a citation to a file the document says it did not read — 2.8

For any cited file, a sentence that contains a closed exclusion phrase (`not reviewed`, `not inspected`, `excluded`, `was not read`) together with a citation of that file is a C20 advisory (2.6 §5.1 family): `this sentence cites a file it says was not reviewed`. When the file is mandatory input (7.1), the advisory adds: `C21 requires a lined citation of this file`.

**Tests:** `test_check::test_c20_cite_in_not_reviewed_sentence_advisory`, `::test_c20_mandatory_input_hint`.

### 7.5 Generated-block conformance — 2.8

C7 (blocks match `fill`) covers the four new blocks automatically. C9 adds the 5.4 and 16.8 headings to `template_spec.SECTIONS`/`REQUIRED_SUBSECTIONS`.

---

## 8. Phase 4 — Workflow, SKILL and render

### 8.1 `appdoc upgrade <target>` (RC-M → T1–T11) — 2.7.0 recommended (Q23), otherwise 2.8.0

1. Upgrades a document from any stamp to the running template by applying the **mechanical** steps of every upgrade note in sequence. A document with no stamp is treated as 2.1 when it has the 2.1 subsections (4.1, 5.1–5.3, 8.4, 8.5, 10.1/10.2, 15.1, 16.1–16.5). Otherwise it is treated as 2.0 and the 2.1 subsections are added as skeletons. The steps:
   - stamp;
   - generated-block markers;
   - new headings and subsections with `appdoc:guide` comments;
   - required-row skeletons (§11 six rows, 16.5 eight rows, §17 five rows) with `Unknown - see Open questions.`;
   - the 5.3 Restriction line;
   - the 2.2 table-header renames;
   - for 2.7: the `closed-questions` markers.
2. Re-runs `extract` and `fill`, then writes `docs/appdoc/UPGRADE-TODO.md` with the non-mechanical steps, each with the Check rule that will fail until it is done. Examples: "convert `verification.md` to `evidence.jsonl`", "write register rows for N finding candidates", "replace hand-written counts with count markers".
3. Never deletes Narrative. Unmappable content goes under a `<!-- appdoc:upgrade-orphan -->` comment that C3 fails on until it is moved.
4. Never writes `evidence.jsonl`, `notes.jsonl` or `audit-plan.json` (P4: append-only history is the auditor's, not the upgrader's).

**Tests:**
- `test_core`: `::test_upgrade_2_1_to_current_mechanical`, `::test_upgrade_2_0_adds_2_1_subsections`, `::test_upgrade_idempotent`, `::test_upgrade_never_drops_text`, `::test_upgrade_never_touches_register`, `::test_upgrade_todo_lists_failing_rules`.
- Corpus `upgrade-2-1`: the Check fails **only** on content rules after upgrade. If Q23 places this in 2.7, it subsumes 2.7's `upgrade-2-6-to-2-7` steps.

### 8.2 Version drift at write time (RC-M → RC3) — 2.8

- `extract` prints, and `facts-summary.md` heads with: `The existing document is on template X; this AppDoc writes Y. Run appdoc upgrade before editing.`
- The SKILL "Run" step 0: if the document exists and its stamp is older, run `upgrade` before `check`.

**Tests:** `test_core::test_extract_warns_old_stamp`.

### 8.3 SKILL.md and template guide changes — 2.8 (2.9 adds the repo-docs lines)

**Orient:**
- Read the `access-model` and `integrations` blocks before writing sections 3, 5, 8 and 10.
- (2.9) Read the `repo-docs` block and every `doc_file` tagged owner, environment, operations or troubleshooting.

**Writing rules (new):**
- Never list a config file as not reviewed. Read it and redact (R16).
- Write "Unknown" only after checking the facts summary and, from 2.9, the repo-docs topics.
- The Troubleshooting Matrix draws from `doc_file` troubleshooting topics as well as `message` Facts.
- Every state-changing handler with `reach` of `anonymous` or `authenticated` is a 10.1 finding or a dismissed candidate.
- Per-configuration behaviour (transforms, CI build configuration) is stated per configuration.

**Large Targets:** one subsystem per **area** (5.5), not only per folder.

**Audit checklist additions:**
- For every troubleshooting row and fallback claim, trace the error branch to its end (null guards, never-null factories).
- Check each generated-block "none" against the stacks named.

These rules are generated into SKILL.md through `gen_docs` (2.6 §6.3), so there is no hand-written drift.

### 8.4 Render weight — independent; any release

`render --mermaid sibling` writes `mermaid.min.js` once beside the HTML and references it relatively. The default (`inline`) is unchanged, so standalone HTML still works offline. This option is for teams that publish many documents to one share. It touches only `render/page.py` and has no dependency on this plan, so it can ride in 2.6.0.

**Tests:** `test_render`: `::test_mermaid_sibling_mode`, `::test_inline_default_unchanged`.

---

## 9. Phase 5 — Release and examples

- **Version (2.8.0):** `__version__ = "2.8.0"`; `facts.SCHEMA = "appdoc-facts/8"`. The schema changes: new kinds `security_setting`, `access_rule`, `guard_candidate` in `KINDS` and `DETAIL_KEYS`; new `entry_point` detail keys `guard`, `reach`, `reach_by_config`, `state_changing`, `area`, `area_path`; `type=desktop`; `stack.ignored_markers`; `smell.sources`. `TEMPLATE_VERSION = "2.8"`.
- **Version (2.9.0):** `facts.SCHEMA = "appdoc-facts/9"` (new kinds `ci_job`, `doc_file`, `test_suite`; new `external_call` types; new scan counts). `TEMPLATE_VERSION` stays `2.8`: no new failing rule and no heading change (R6).
- **Conformance** (`tests/test_conformance.py`): every new kind is in `facts.KINDS` and `facts.DETAIL_KEYS`. `aspnet`, `aspnet_core` and `generic` declare the new capabilities (`guard` included). R18 is asserted per field: no Fact detail except `roles`/`role`/`role_ref` may hold a `DOMAIN\name` shape, and no Fact anywhere may hold `@` addresses or `mailto:`.
- **Examples:** none of the four public examples is classic ASP.NET MVC with Web.config transforms. Add **`examples/current/mvc5-classic`** (the corpus Target, documented and independently audited), or adopt a public MVC 5 sample with Windows auth (Q24). Until one with real-world code exists, the 2.8 Facts-level patterns stay summary-only under §5.11 Part C.
- **ADRs:**
  - 0018 "Security-bearing configuration is mandatory input" (R16, C21).
  - 0019 "Effective protection per handler: guard and reach" (5.4, C22, the access-model distribution note).
  - 0020 "Repository documentation as input" (5.9, C23, R18), in 2.9.
  - Amend 0008 (Facts-level finding candidates, the examples-only precision gate, the minimum hit count).
- **Upgrade notes 2.7 → 2.8:**
  1. `appdoc upgrade` (adds 5.4 and 16.8 with their blocks, and the 2.1 and 8.3 block markers).
  2. Re-extract.
  3. Cite every mandatory config file with a line (C21).
  4. Add every area folder to 4.1 and cite handler files that are state-changing or not role-guarded (C22).
  5. Address the new obliging finding candidates (C12).
  6. Audit, then `build`.
- **Upgrade notes 2.8 → 2.9:** re-extract; `build`. Expect new advisories (C23) and new block content. Nothing fails that passed.

---

## 10. Decisions needed

| Q | Question | Recommendation |
|---|---|---|
| Q22 | Split this plan into **2.8.0** (security and access, every template change) and **2.9.0** (integrations, CI, repository docs, data surface; no template bump)? | **Yes.** Each release stays near the size of 2.6/2.7. The security gaps (S1, S2, S5, S6, E1) ship first. Because 2.8 carries every block marker, 2.9 adds only Facts and advisories, so there is one template bump, not two. |
| Q23 | Ship `appdoc upgrade` (8.1) in **2.7.0** instead of 2.8.0? | **Yes, if 2.7 can take about 1.5 days.** 2.7 is the release that forces every committed document to upgrade once, and it already specifies the 2.6 → 2.7 steps and an upgrade corpus test. A tool there pays off immediately and becomes the vehicle for 2.8's upgrade. Otherwise ship it in 2.8 as specified. |
| Q21-bis | Fold 2.8 template items into 2.7.0 (rev 1's Q21)? | **No.** 2.5.0 is still on its branch, and 2.6/2.7 were written as "unchanged scope". 2.8's blocks need 2.8 Facts, so folding the template would either ship empty blocks in 2.7 or pull the extractor work into 2.6. Under Q22, 2.8 is a self-contained template release. |
| Q24 | Classic MVC public example: synthetic `mvc5-classic`, or a public repository? | Synthetic now (fully controlled, no PII). Adopt a public repository with transforms and Windows auth when one is found, because §5.11 Part C needs real-world hits before the 2.8 patterns can oblige C12. |
| Q25 | Record role **names** and role-constant values in `access_rule` and `auth_check`? | Yes for groups and role constants; users only counted (R18). |
| Q26 | Should C22.2 fail on 2.7 stamps too, given it is security-relevant? | No. Advisory on 2.7 (Q19 precedent); failing on 2.8. |
| Q27 | Should `appdoc upgrade` also convert `verification.md` (2.1) to `evidence.jsonl` automatically? | No. The register needs anchors from source, so a mechanical conversion would fake audit evidence (P4). Keep it in UPGRADE-TODO. |
| Q28 | Precision rule for C12-obliging patterns. | ≥0.8 on the public examples **and** ≥5 hits; otherwise summary-only. The corpus is excluded from precision. |

---

## 11. Acceptance: the DegreeAudit run (private, `tools/acceptance.py`)

On a local DegreeAudit checkout at `33168dd`, AppDoc must produce the outputs below. DegreeAudit-specific names (config keys, classes, folders, counts) live in the private answer key, not here (V9).

| Audit finding | Must appear as | Rel |
|---|---|---|
| E1 | `security_setting authentication@mode=Windows`; `access-model` block | 2.8 |
| E5 | `deref-before-null-check` in the cited controller | 2.8 |
| E6 | `dead-null-fallback` in the base controller | 2.8 |
| E7 | `integrations` block lists every connection name defined in config (count from the key) | 2.8 |
| E8, E9 | `access-model` block: guard attributes, role constants (names and values) and counts per area; the custom role guard as candidate or declared | 2.8 |
| E10 (stack) | No `aspnet-core` stack; `ignored_markers ≥ 1` | 2.8 |
| G 6.1 | Every area in Facts (count from the key); C22 fails if any area folder is missing from 4.1; no WinForms web `entry_point`s; one `type=desktop` for the harness | 2.8 |
| G 6.4 | `config-year-horizon` on the bulletin-year key; `duplicate-config-key` | 2.8 |
| S1 | `state-change-authenticated-only` on the bulletin-builder controller (production config) | 2.8 |
| S2 | `machinekey-in-config` | 2.8 |
| S4 | `named-user-access-rule` (count only) | 2.8 |
| S5 (config) | `debug-settings-deployed` for the non-production configuration; `conditional-security-build` in the summary | 2.8 |
| S6 | `post-without-antiforgery` per controller | 2.8 |
| S7 | `access-model`: the public controller `reach: anonymous`; the status location anonymous | 2.8 |
| RC1 | C21 fails on any document that does not cite Web.config with a line | 2.8 |
| T1–T11 | `appdoc upgrade` + UPGRADE-TODO; after the writer completes it, Check PASS with `--require-audit` | 2.7/2.8 |
| E2 | `external_call type=file_drop` with the imaging config key (plus graduation drops) | 2.9 |
| E3 | `doc_file` README with `topics ∋ owner`, `owner_entries` from the key; C23 advisory if §11 says Unknown | 2.9 |
| E4 | `doc_file` README with `topics ∋ environment`; `ci_job` count and environments from the key | 2.9 |
| E10 (scan) | Scan block splits source / content / documentation; v1 output folders pruned; the other-tool folder named as a documentation-copy candidate | 2.9 |
| G 6.3 | `external_call type=service` for the CRM note client with its config key; `doc_file` for the batching document | 2.9 |
| G 6.5 | `test_suite` for the test project; `ci-without-test`; pipeline trailer "No job runs tests." | 2.9 |
| S5 (CI) | `debug-settings-deployed` names the deployed environments via `ci_job.build_config` | 2.9 |

The acceptance script asserts on Facts and Check output only. It stores no DegreeAudit content in the AppDoc repository.

---

## 12. Order and effort

**2.8.0**
```
Phase 0  corpus mvc5-classic + cases, acceptance harness                       1.0 d
0.4      feasibility spike on DegreeAudit (private key)                        0.5 d
5.6/5.5  stack/handler classification, test-data path move, route areas        0.75 d
5.1/5.2  system.web + serviceModel, access rules, transforms + locators        1.25 d
5.3/5.4  custom guards, guard/reach post-pass (guard.py), capability scope     1.5 d
5.11 A   Facts-level smell pass + fid scheme                                   0.5 d
5.11 B   9 patterns (2.8 set) + precision gate amendment                       1.25 d
§6       access-model, integrations (connections/WCF), all block markers       1.0 d
§7       C21, C22, C23 (auth topics), C20 note, spec updates                   1.0 d
8.2/8.3  drift warning, SKILL/gen_docs                                         0.5 d
§9       mvc5-classic example run + independent audit, ADRs 0018/0019, release 1.5 d
                                                              2.8.0 total about 10.75 d
```

**2.9.0**
```
5.7      integration-by-convention (ctor, property, one-hop file drop)         0.75 d
5.8      restricted CI reader (GitLab, GitHub), test suites                    1.0 d
5.9/5.10 doc_file harvest, scan accounting                                     0.75 d
5.11     ci-without-test, debug-settings-deployed CI extension                 0.25 d
5.12     edmx, rdlc, sql schema detail                                         0.5 d
§6       pipeline, repo-docs, integrations content, scan split                 0.75 d
§7       C23 remaining topics                                                  0.25 d
§9       examples, ADR 0020, release                                           0.75 d
                                                              2.9.0 total about 5.0 d
```

**Elsewhere:** 8.1 `appdoc upgrade` is about 1.5 d (in 2.7.0 under Q23, else in 2.8.0). 8.4 render sibling mode is about 0.25 d, in any release.

Rev 1 estimated 12.25 d for everything. The new total (about 17.5 d) adds the Facts-level smell pass, the feasibility spike, WCF and locator handling, test suites, and a realistic upgrade-tool estimate across four template versions.

**Order (2.8.0):**
1. Phase 0 (all cases red), then 0.4. Adjust the specifications from the spike before coding.
2. 5.6, then 5.5. Classification fixes come first because they change counts every later test depends on.
3. 5.1 → 5.2 → 5.3 → 5.4, since protection needs settings, rules and attributes.
4. 5.11 Part A, then Part B.
5. §6 blocks (all markers).
6. §7 rules.
7. 8.2, SKILL.
8. Examples, acceptance and release.

**Order (2.9.0):** 5.7, 5.8, 5.9, 5.10, 5.12 → 5.11 additions → §6 content → C23 → examples, acceptance and release.

---

## 13. Traceability

| Finding | Item | Tests (red on the previous tag, green on the release) | Corpus | Rel |
|---|---|---|---|---|
| E1, S2, S5 | 5.1 | `test_generic_facts::test_system_web_settings`, `::test_transform_release_sets_customerrors`, `::test_unsupported_locator_disclosed` | webconfig-security, xdt-locators | 2.8 |
| S4, S7 | 5.2 | `test_generic_facts::test_location_rules`, `::test_named_users_counted_not_recorded`, `::test_nested_webconfig_rule_physical` | location-rules, nested-webconfig | 2.8 |
| E8, E9 | 5.3 | `test_facts_aspnet::test_guard_candidate_threshold`, `::test_declared_auth_attribute`, `::test_const_role_argument_name_and_value` | custom-guard | 2.8 |
| S1, S6, S7 | 5.4, 5.11 | `test_core::test_reach_*`, `::test_guard_*`; `test_smells::test_state_change_authenticated_only_*`, `::test_handler_without_guard_*` | effective-guard, guard-capability, smells-from-facts | 2.8 |
| G 6.1 | 5.5, 5.6, 7.2 | `test_facts_aspnet::test_routearea_prefix_applied`, `::test_desktop_main_entry_point`; `test_check::test_c22_*` | route-area, area-coverage, winforms-handlers | 2.8 |
| False `aspnet-core` | 5.6 | `test_facts_aspnet_core::test_no_core_without_web_sdk`, `::test_test_path_markers_ignored` | core-false-positive | 2.8 |
| E7 | 5.1, 6.2 | `test_fill::test_connections_all_listed`; `test_generic_facts::test_wcf_client_endpoint` | webconfig-security | 2.8 |
| E5, E6, G 6.4, S10 | 5.11 | `test_smells::test_deref_before_null_check_*`, `::test_dead_null_fallback_*`, `::test_year_horizon_window`, `::test_duplicate_config_key_*` | smells-net | 2.8 |
| RC1 | 7.1 | `test_check::test_c21_*` | config-not-reviewed | 2.8 |
| Check note (cite in "not reviewed") | 7.4 | `test_check::test_c20_cite_in_not_reviewed_sentence_advisory` | config-not-reviewed | 2.8 |
| T1–T11, RC3 | 8.1, 8.2 | `test_core::test_upgrade_*`, `::test_extract_warns_old_stamp` | upgrade-2-1 | 2.7/2.8 |
| R18 | §9 | `test_conformance::test_no_personal_identifiers_field_aware` | location-rules, readme-topics | 2.8 |
| E2, G 6.3 | 5.7, 6.2 | `test_facts_aspnet::test_unc_file_drop_one_hop`, `::test_config_url_property_client` | unc-drop, config-client, wcf-endpoint | 2.9 |
| E4, G 6.5, T4 | 5.8, 6.3 | `test_generic_facts::test_gitlab_ci_jobs`, `::test_test_suite_counted`; `test_fill::test_pipeline_no_test_trailer` | ci-jobs | 2.9 |
| E3, G 6.6, RC5 | 5.9, 6.4, 7.3 | `test_generic_facts::test_readme_topics`; `test_check::test_c23_*` | readme-topics | 2.9 |
| E10, RC4 | 5.10, 6.5 | `test_core::test_prune_v1_output`, `::test_content_folder_counted_separately` | v1-output, content-folder | 2.9 |
| G 6.2 | 5.12 | `test_facts_aspnet::test_edmx_entities`, `::test_rdlc_report_page` | — | 2.9 |
| SR9 (HTML weight) | 8.4 | `test_render::test_mermaid_sibling_mode` | — | any |
| DegreeAudit end-to-end | §11 | `tools/acceptance.py` (local, private) | — | 2.8, 2.9 |

---

## 14. Done means

For each release (2.8.0, then 2.9.0):

1. Every test in §13 for that release is red on the previous release tag (tags exist from 2.6 §3.0) and green on the release commit, on Windows and Linux, and CI is green.
2. `tools/acceptance.py` on the local DegreeAudit checkout produces every §11 row for that release.
3. (Wherever 8.1 ships.) On a 2.1 document, `appdoc upgrade` followed by the UPGRADE-TODO steps reaches Check PASS with `--require-audit`. The corpus test `upgrade-2-1` proves the mechanical part.
4. `examples/current/mvc5-classic` passes `build --require-audit --strict` with an independent audit. In 2.8, its 10.1 contains the authenticated-only area, machineKey, debug-deployed, named-user and anti-forgery findings, or dismissals with reasons.
5. `tools/release.py` reports, per pattern, the hit count and precision on the public examples. Only patterns at ≥5 hits and ≥0.8 precision oblige C12.
6. No **Fact or generated block** produced by the release contains a personal identifier or a secret value (`test_conformance`, C6). The Narrative is governed by the existing template and C6 rules.
7. SKILL.md, README and CONTEXT.md are regenerated through `gen_docs --check` with no drift, the release's ADRs are merged, and the release tag exists with the gate pinned to it.

---

## Appendix A — Immediate operational step for DegreeAudit (no skill change)

This step doesn't wait for 2.8. It clears group A (11 findings) today on 2.4.0:

1. Add `.appdocignore` entries for `docs2/`, `docs_a/`, `docs_b/`, `docuwriter/`, `tests/powershell/fixtures/` and `Scripts/lib/` (or `!name` to keep one), until 5.6 and 5.10 ship. The fixtures entry removes the false `aspnet-core` stack.
2. `python <AppDoc>/run_appdoc.py extract C:\Github\DegreeAudit` (schema `/5`).
3. Upgrade the document by hand, following the CHANGELOG 2.2 → 2.3 → 2.4 notes in sequence. This is what `appdoc upgrade` will automate.
4. Read `Web.config` and its transforms, cite them with values redacted and with lines, and write the audit-report security findings into 10.1.
5. Run the audit in a fresh agent → `evidence.jsonl` → `build --require-audit`.

**Not a documentation task:** the audit's P0 items (S1 BulletinBuilder authorization, S2 committed `machineKey`, and the `MaximumBulletinYear` bump before the 2027 bulletin) are application defects. Raise them with the DegreeAudit team now; no AppDoc release changes them.
