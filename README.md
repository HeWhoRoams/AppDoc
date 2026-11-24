# AppDoc

Documentation for legacy and unfamiliar codebases, written for the developer who has to pick them up.

AppDoc is a **skill** for any AI harness that can read `SKILL.md` and run Python. Small scripts extract reproducible **Facts** from the code. The AI writes a cited document from a fixed template. A pass/fail **Check** verifies it. A renderer produces an offline HTML page.

- **Deterministic where it matters.** The Facts file is byte-identical across runs.
- **Grounded.** Every claim carries a `file:line` Citation, or is marked *Inferred* or *Unknown*.
- **Safe.** Extractors never record secret values. The Check fails on secret-shaped text.
- **Small.** Python 3.10+, standard library only, no packages to install.

## Install as a skill

To install through an AI agent, point it to this full repository (a local folder or GitHub URL) and say **"Install this skill globally."** The agent should obtain the full checkout, choose the current runtime's skills directory, run the installer, and verify the installed launcher. A standalone `SKILL.md` is not a complete install. If the agent cannot access the repository or run Python, use the command directly.

From this checkout, run the installer with the parent skills directory. It creates or repairs the `appdoc/` skill folder and copies `SKILL.md`, `CONTEXT.md`, `run_appdoc.py`, and the complete `appdoc/` package, including its template and renderer assets.

No npm command or additional package installation is needed.

```powershell
py -3 install_skill.py "$HOME\.copilot\skills"
```

For other runtimes, pass their skills directory instead, such as `python install_skill.py ~/.claude/skills`. Re-running the installer updates an existing AppDoc skill. The installed launcher works from any current directory; no packages are needed.

## Quick start

```
python -m appdoc extract <target>     # writes docs/appdoc/facts.json and facts-summary.md
# the AI writes docs/appdoc/application-documentation.md from appdoc/assets/template.md (see SKILL.md)
python -m appdoc fill <target>        # writes the generated blocks (scan coverage, entry points, configuration reference, scheduled jobs, Appendix A)
# an auditor writes docs/appdoc/evidence.jsonl (the source-to-claim audit, see SKILL.md); run fill again afterwards
python -m appdoc check <target>       # exit 0 pass, 2 problems, 1 tool error; --require-audit and --strict for CI
python -m appdoc render <target>      # writes application-documentation.html
```

All commands:

<!-- appdoc-self:generated commands -->
| Command | Options | What it does |
|---|---|---|
| `appdoc extract <target>` | `--out OUT`, `--workers WORKERS`, `--skip-tests`, `--no-cache`, `--no-ownership`, `--ownership-top OWNERSHIP_TOP` | write facts.json, facts-summary.md and provenance.json |
| `appdoc fill <target>` | `--out OUT` | write the generated blocks of the Narrative from the Facts and the register |
| `appdoc check <target>` | `--out OUT`, `--require-audit`, `--strict` | verify the Narrative; exit 0 pass, 2 problems, 1 tool error |
| `appdoc render <target>` | `--out OUT`, `--css CSS` | write application-documentation.html |
| `appdoc seal <target>` | `--out OUT`, `--audit`, `--date DATE` | write claim_sha into the register rows that lack one; --audit --date records the audit |
| `appdoc build <target>` | `--out OUT`, `--expand-citations`, `--require-audit`, `--strict` | seal (rows and notes), fill, check and render in one step |
| `appdoc gate <target>` | `--out OUT`, `--workers WORKERS`, `--require-audit`, `--strict` | CI gate: regenerate the Facts and compare with the committed facts.json, then check; exit 0 pass, 1 tool error, 2 Facts changed, 3 AppDoc upgraded |
| `appdoc audit-plan <target>` | `--out OUT`, `--check` | write docs/appdoc/audit-plan.json: the ids and per-row keys the independent audit must cover (a sample is chosen by the tool) |
| `appdoc upgrade <target>` | `--out OUT`, `--workers WORKERS`, `--no-ownership` | bring a document of an older template to the running one: add the missing headings, blocks, columns and rows, keep every line of text, then extract and fill; the rest is for a person |
<!-- /appdoc-self:generated commands -->

Run these from the AppDoc folder (or call `python run_appdoc.py ...` from anywhere). On Windows use `py -3 -m appdoc ...` if `python` is not on PATH. Run on a **scratch copy** of the Target if you do not want files added to its `docs/appdoc/`. All output goes to `<target>/docs/appdoc/` (override with `--out`, which must stay inside the Target).

## What you get

```
docs/appdoc/
  facts.json                       reproducible Facts file
  facts-summary.md                 map of the Facts (read first on large Targets)
  application-documentation.md     the Narrative: 16 sections, cited, ending with Appendix A (audit state, coverage, register, verification commands)
  evidence.jsonl                   the Evidence Register (source-to-claim audit), one JSON row per claim
  check-report.md                  PASS/FAIL, problems, advisories, Citation register
  application-documentation.html   single offline file, Mermaid inlined, rendered from the Markdown
```

The 16 sections: Application Index, Coverage and Overview, Architecture, Functional Inventory, Roles and Access Model, UI Catalog, Workflows, Data and Integrations, Troubleshooting Matrix, Security and Operational Risks, Ownership and Maintenance, Architecture and Data-Flow Diagrams, Glossary, Open Questions, Recommendations, Operations Runbook.

## Supported Stacks

| Stack id | Detected from | Facts extracted |
|---|---|---|
| `classic-asp` | `*.asp`, `global.asa` | pages and inputs, includes, SQL and stored procedures, connections, COM/HTTP/mail/file calls, Session auth checks, error messages |
| `aspnet` | `*.aspx`, `Global.asax` (Web Forms, MVC 5) | pages, handlers, controller actions and routes, SQL, EF entities, calls, authorize checks, messages |
| `aspnet-core` | `*.csproj` + `Program.cs`/`Startup.cs` | attribute and minimal-API routes, Razor Pages, MVC views returned by controller actions, XAML pages, EF Core and Dapper, `GetConnectionString`, authorize policies |
| `java-spring` | `pom.xml`/`build.gradle` + `*.java` | Spring MVC mappings, Struts, web.xml, JSP, JPA/JDBC/MyBatis SQL, datasource beans, security rules |
| `python-flask` | `requirements*.txt`/`pyproject.toml` + `*.py` | routes and blueprints, SQLAlchemy and raw SQL, connections, config definitions (`from_object`) and reads, role decorators |
| `node-express` | `package.json` with an `express` dependency + `*.js`/`*.ts` | routes and middleware, Sequelize/Mongoose/knex/SQL, connections, `process.env` reads |
| `go` | `go.mod` + `*.go` | routes (`net/http`, chi, gin, echo, gorilla, gitea-style groups), CLI commands, cron and scheduled jobs, config reads |

Every Target also gets the **generic** extractor: files, dependency manifests, config keys (never values), connection and secret locations, DDL tables and indexes, ownership files (counts only, never names or emails), optional git ownership, and a `stack` fact marked unsupported for ecosystems AppDoc does not read yet (Ruby, Rust, PHP, Django, and others). Section 2 of the document names them, so the Reader knows which parts have less extracted backing.

## The Facts file

`facts.json` holds records of `{kind, stack, path, line, name, detail}`.

<!-- appdoc-self:generated facts-schema -->
Schema `appdoc-facts/7`. Kinds: `file`, `stack`, `entry_point`, `data_access`, `connection`, `config_key`, `dependency`, `external_call`, `auth_check`, `message`, `ownership`, `smell`, `schema_object`, `owner_file`, `ui_page`, `security_setting`, `access_rule`, `access_rule_unmatched`, `config_transform`, `config_external`, `config_unparsed`, `guard_class`, `guard_use`, `guard_candidate`, `const_def`, `project`, `build_define`, `publish_profile`, `context_directive`, `controller_class`, `host_auth`, `method_call`. The allowed `detail` keys of each kind are `facts.DETAIL_KEYS`.
<!-- /appdoc-self:generated facts-schema -->

It contains no timestamps, no absolute paths and no secret values; entries are sorted and de-duplicated, and the Target's git commit is recorded when there is one. `target.scan` records the files found (scanned + pruned + ignored) and each pruned folder with its rule, plus retired and duplicate folder candidates; every `config_key` has a `role` (`app`, `build`, `ci`, `orchestration`, `env`) and a `use` (`define` or `read`); `entry_point` records of `type=job` carry `schedule` and `enabled`. Lockfiles and i18n message bundles produce no config keys. `provenance.json` beside it records which AppDoc wrote the Facts (version, bundle hash, schema); `facts.json` itself carries no generator, so an AppDoc patch release that changes no Facts changes no Facts file.

Folders are pruned on evidence, not by name alone: `bin`/`obj` only under a .NET project, `target` beside `pom.xml`/`Cargo.toml`, `build` beside a Gradle or CMake file, `dist`/`out` beside `package.json`/`tsconfig.json`/`*.csproj`, `packages` when it is a NuGet cache, `vendor` when it is Go, Composer or Bundler output. VCS metadata, IDE folders, `node_modules`, `__pycache__` and virtualenvs are always pruned.

## Finding candidates

Some code patterns are worth a second look but cannot be proved by a script. The extractor records them as `smell` Facts (a finding candidate), each with a stable id shown in `facts-summary.md` and `check-report.md`. Seven patterns exist: `logger-type-mismatch`, `flash-without-redirect`, `distinct-auth-errors`, `unescaped-template-output`, `state-change-on-get`, `actuator-exposed` and `hardcoded-credential-constant`. Credential values are never recorded. C12 requires each candidate to be cited in 10.1 or dismissed in the Evidence Register with a reason. The Check never judges whether the finding's wording is right. See `docs/adr/0008-finding-candidates.md`.

`connection` Facts carry a `type` in `detail` — `database` plus the non-database integration vocabulary `cache`, `queue`, `object_storage`, `grpc`, `ldap`, `search` (detected by the shared catalog in `appdoc/stacks/integrations.py`), and `external_call` adds `grpc`. The Facts summary leads with a deterministic **System Connections** section (`appdoc/integration.py`) that groups these Facts by type into a system-to-system map — the integration picture, rendered near the top of the summary and the HTML page.

## The Check

<!-- appdoc-self:generated rules -->
Rules C1-C23. Each rule fails or is not reported; there is no score.

| Rule | Name | Fails when | Kind |
|---|---|---|---|
| C1 | Citations resolve | a Citation points to a missing file or a line past the end (folders and unique bare filenames resolve; extensionless non-existent spans are not Citations) | fails |
| C2 | Security lines | a Citation in section 10 has no line | fails |
| C3 | Sections complete | a section is missing, out of order, empty or a placeholder, the stamp is not the running template, or an `appdoc:upgrade-orphan` comment from `appdoc upgrade` is left | fails |
| C4 | Gaps declared | section 14 is empty while Unknowns exist, or Data and Integrations is empty though Facts exist | fails |
| C5 | Claims grounded | a paragraph, list item or table row in sections 3 to 10 is neither cited, Inferred nor Unknown | fails |
| C6 | No secrets | secret-shaped text, or a `never-mention` term, appears in a published file | fails |
| C7 | Coverage honest | an unsupported Stack is not named in section 2; a count or a generated block differs from the Facts; facts.json was written by another major.minor of AppDoc | part fails only under `--strict` |
| C8 | Structure complete | a required numbered subsection is missing, outside its section or empty | fails |
| C9 | Tables conform | a table differs from the template (header, cell count, ID prefix, allowed value, required row), the 5.3 Restriction line is missing, a section 17 (2.7) Command cell is not a backticked command, Unknown or Not applicable or lacks a lined Citation, or a guidance comment remains | fails |
| C10 | References resolve | an ID is defined twice or referenced but not defined, or a reference between sections does not resolve | fails |
| C11 | Register valid | `evidence.jsonl` is missing, malformed or does not cover the document; an anchor is not in its cited lines | fails |
| C12 | Finding candidates addressed | a finding candidate is neither cited in 10.1 nor Dismissed in the register | fails |
| C13 | Entry points not cited | an entry point file is not cited anywhere in the document | advisory; fails under `--strict` |
| C14 | Unknowns match the register | section 14 lists a question the register resolved, or its unknown count disagrees with the register | fails |
| C15 | Register counts in prose | a register count written in prose disagrees with the register; from template 2.7 a count marker holds a stale number or an unknown class (a hand-written "N of M" is then only an advisory: use a count marker) | fails |
| C16 | Universal claims cite single lines | a universal claim (all, every, never) cites only single lines | advisory; fails under `--strict` |
| C17 | Audit scope names the method only | the audit record's scope text holds an ID or a digit; with `--require-audit` the record lacks `audited_on`, `audited_with`, `audited_bundle` or `doc_sha`, and with `--strict` a row was sealed at upgrade (all fail from template 2.7) | advisory before template 2.7; fails from 2.7 |
| C18 | Notes match their block | a note in `notes.jsonl` names an unknown block, was written about an older version of its block (`block_sha`), or cites a file that does not resolve; the label `Known extractor limitation:` is written in the Narrative outside a generated block (fails from template 2.7) | advisory before template 2.7; fails from 2.7 |
| C19 | Audit follows the plan | with `--require-audit` on template 2.7, `audit-plan.json` is missing or differs from a fresh computation, or a planned id or per-row key has no live register row (a section listed under `exclusions` is not required) | fails |
| C20 | Citation precision | a range over 100 lines is a claim's only lined Citation in section 4, 7 or 10, or a section 4 or 10.1 table cell holds more than 5 Citations | advisory; fails under `--strict` |
| C21 | Mandatory inputs cited | a file holding a security setting, access rule, external config reference or secret-bearing application key is not cited with a line in text outside the generated blocks (a file that could not be parsed needs its path) | fails |
| C22 | Area and protection coverage | an MVC area is not the folder of a 4.1 row, or a handler file that changes state or has no application-layer restriction (or an unknown one) is not cited; with `--strict`, a guard candidate is not declared | part fails only under `--strict` |
| C23 | Unknown the repository may answer | an Unknown about identity, authentication, authorization or roles while the repository holds a security setting or access rule that may answer it | advisory; fails under `--strict` |

Previews of template 2.7 rules. On a template 2.4 document these are advisories, listed in `check-report.md` as "fails from template 2.7"; they fail only on a document stamped 2.7:

- C1: a bare file name (in the Narrative, a register row or a note) that resolves to a file in a folder: cite the full path
- C9: a section 10.1 or 15 row that outranks the row before it (Critical, High, Medium, Low)
- C11: an Answerable register row without `answered_in`, the section that answers the question
- C15: a count marker holds a stale number or an unknown class
- C17: the audit record's scope text holds an ID or a digit
- C18: a note in `notes.jsonl` that does not match its block, or the reserved label written by hand
<!-- /appdoc-self:generated rules -->

There is no score. The template's structure (headings, table columns, ID prefixes, allowed values) is defined once in `appdoc/template_spec.py`; the Check reads it.

A Citation path may contain spaces (`` `To be deleted/App/logcall.asp:212` ``) when it has a folder and ends in a file name.

**Advisory.** `check-report.md` lists **Entry points not cited**: route, page, command and job Facts whose file the document never cites, grouped by folder. It does not fail the Check. `check --strict` fails on it. Other advisories: universal claims that cite single lines (C16), citations broader than the claim needs (C20), duplicate folders not named in section 2, and the previews of template 2.7 rules above.

**Scope.** The Check verifies resolution, structure, references, counts against the Facts, that each finding candidate is addressed, and that each Evidence Register anchor appears in its cited lines. It does **not** judge whether a claim's wording follows from those lines; a PASS is not an accuracy certification.

**Evidence Register.** The source-to-claim audit is recorded as data in `docs/appdoc/evidence.jsonl` (see `SKILL.md`). Line 1 declares the audit state (performed, by whom, scope; or not performed and why). Rows have a result of Supported, Corrected, Downgraded, Dismissed (a finding candidate, ref `smell/<id>`) or Answerable (a section 14 question the source can close, ref `14/Q-n`). `fill` computes the counts, per-section coverage, the register table and verification commands into the Appendix A block of the Markdown; `render` shows that block. An audit declared not performed shows as a banner at the start of Appendix A. A missing register fails C11, so the audit state is never silent.

## Docs-as-code

To keep the generated docs in lockstep with the code, add the deterministic gate (`ci/appdoc-docs-gate.yml`) to the target repo's `.github/workflows/`. On every push and pull request it clones the pinned AppDoc release outside the workspace and runs `appdoc gate`: the Facts are regenerated and compared with the committed `docs/appdoc/facts.json` (exit 2 "Facts changed" with a short diff, or exit 3 "AppDoc upgraded" when the Facts schema differs), then the Check runs with `--require-audit`. A patch release of AppDoc with the same schema never trips the gate. AppDoc holds no LLM key, so the AI-written Narrative is not regenerated in CI; refresh it in a session. See `docs/docs-as-code.md` for the full process.

## Configuration

All optional, all in the Target:

- `appdoc-context.md`: owner notes (purpose, owners, environments). Cited as owner-supplied. A ```` ```never-mention ```` block lists internal terms that must not appear in the output.
- `.appdocignore`: folder names and `*` globs to skip; `!name` re-includes a folder AppDoc would prune (for example `!build` when `build/` holds source).
- `docs/appdoc/theme.css`, or `render --css FILE`: replaces the CMU theme. The default theme is built on CSS custom properties (`--brand`, `--accent`, `--text`, `--bg`, `--font`, ...); override the variables to re-brand.

## Add a Stack

1. Create `appdoc/stacks/<name>.py` with a `Stack` subclass (see `appdoc/stacks/base.py`): `id`, `extensions`, `detect(paths)` returning marker files, and `extract(path, text)` yielding `Fact.make(...)` records. Never record a secret value; config files and dependency manifests belong to `generic.py`.
2. Expose a module-level `STACK = YourStack()` and add the module name to `MODULES` in `appdoc/stacks/__init__.py`.
3. Add a small sample Target at `tests/samples/<id>/` and a `tests/test_facts_<name>.py` that asserts the expected Facts, that no sample secret appears in the output, and that two runs are identical.

## Tests

```
python -m unittest discover -s tests -t .
```

Standard library only. CI runs them on Ubuntu and Windows with Python 3.10 and 3.13.

## Known limitations

- Extraction is regex-based per file. Prefixes applied in another file (blueprint and router mounts, Spring `parent=` beans) are flagged `prefix_unresolved` or missed.
- SQL assembled from variables is only seen where its leading literal is visible.
- Hard-coded secrets are found by the AI reading source and by the Check's scan; the `hardcoded-credential-constant` finding candidate flags the location only, never the value.
- Finding candidates are regex heuristics: a candidate may be a false alarm (dismiss it with a reason in the register), and an absent candidate is not proof of absence.
- The Check proves Citations resolve and that each Evidence Register anchor appears in its cited lines; it does not judge whether a claim's wording follows from them. Neither the Check nor the audit validates Mermaid syntax.
- Ownership Facts need full git history; shallow clones get none. Facts from test code carry `test: true` and are left out of the summary lists.
- Section prose is grounded but not byte-identical between runs; only the Facts file is.

## History

AppDoc 1.x was a PowerShell program that tried to generate the whole document deterministically. It is kept in `v1.1.0`. See `docs/adr/0004-facts-plus-narrative.md` for why 2.0 changed.

## License

MIT. See `LICENSE` and `NOTICE` (vendored Mermaid in `appdoc/assets/`). Copyright (c) 2026 Tim Niles.
