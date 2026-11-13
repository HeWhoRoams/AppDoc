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

`facts.json` holds records of `{kind, stack, path, line, name, detail}`. Kinds: `file`, `stack`, `entry_point`, `data_access`, `connection`, `config_key`, `dependency`, `external_call`, `auth_check`, `message`, `ownership`, `smell`, `schema_object`, `owner_file`, `ui_page`. It contains no timestamps, no absolute paths and no secret values; entries are sorted and de-duplicated, and the Target's git commit is recorded when there is one. Schema `appdoc-facts/4` adds `target.scan` (files found = scanned + pruned + ignored, and each pruned folder with its rule), a `role` on every `config_key` (`app`, `build`, `ci`, `orchestration`) and a `use` (`define` or `read`), and `entry_point` records of `type=job` with `schedule` and `enabled`. Lockfiles and i18n message bundles produce no config keys.

Folders are pruned on evidence, not by name alone: `bin`/`obj` only under a .NET project, `target` beside `pom.xml`/`Cargo.toml`, `build` beside a Gradle or CMake file, `dist`/`out` beside `package.json`/`tsconfig.json`/`*.csproj`, `packages` when it is a NuGet cache, `vendor` when it is Go, Composer or Bundler output. VCS metadata, IDE folders, `node_modules`, `__pycache__` and virtualenvs are always pruned.

## Finding candidates

Some code patterns are worth a second look but cannot be proved by a script. The extractor records them as `smell` Facts (a finding candidate), each with a stable id shown in `facts-summary.md` and `check-report.md`. Seven patterns exist: `logger-type-mismatch`, `flash-without-redirect`, `distinct-auth-errors`, `unescaped-template-output`, `state-change-on-get`, `actuator-exposed` and `hardcoded-credential-constant`. Credential values are never recorded. C12 requires each candidate to be cited in 10.1 or dismissed in the Evidence Register with a reason. The Check never judges whether the finding's wording is right. See `docs/adr/0008-finding-candidates.md`.

## The Check

| Rule | Fails when |
|---|---|
| C1 | a Citation points to a missing file or a line past the end (folders and unique bare filenames, including `Procfile`, `Dockerfile`, `Makefile` and `MAINTAINERS`, resolve; extensionless non-existent spans are not Citations) |
| C2 | a Citation in section 10 has no line |
| C3 | a section is missing, out of order, empty or still a placeholder; or the document is not on the current template (one upgrade problem, and C8-C12 are not run) |
| C4 | section 14 is empty while Unknowns exist, or Data and Integrations is empty though Facts exist |
| C5 | a paragraph, list item or table row in sections 3 to 10 is neither cited, Inferred nor Unknown |
| C6 | secret-shaped text, or a `never-mention` term, appears in any published file (the Narrative and `evidence.jsonl`) |
| C7 | an unsupported Stack is not named in section 2; a 4.1 file count differs from the Facts; a generated block is missing or differs from what `fill` writes; a count in sections 2 to 4 ("five controllers", "30 cron tasks") differs from the Facts ("N of M" passes when M matches) |
| C8 | a required numbered subsection (4.1, 5.1-5.3, 8.1-8.5, 10.1-10.2, 15.1, 16.1-16.7) is missing, outside its section, or empty |
| C9 | a table header differs from the template; a row has the wrong number of cells; an ID, Severity, Status, Priority or Effort value is not allowed; a 16.5 step or an 11 owner row is missing; the 5.3 Restriction line is missing; a template guidance comment remains |
| C10 | an ID is defined twice or referenced but not defined; a `#anchor` link matches no heading; a 10.1 finding has no recommendation; a 10.2 control that is not Present is in neither 15 nor 14; an 8.1 or 8.3 ID has no 8.5 row; a section 4 Area is absent from 5.3; a Key in a 16.6 effect table is not a `config_key` Fact |
| C11 | `evidence.jsonl` is missing, malformed, or has a bad ID, result, ref or Citation; a 10.1 finding or workflow has no row; a row's anchor text is not in its cited lines, or is longer than 200 characters or spans lines; a section 14 question marked `Answerable` is still open; with `--require-audit`, the audit was declared not performed |
| C12 | a finding candidate (`smell` Fact) is neither cited in 10.1 nor `Dismissed` in the register with a reason |

There is no score. Each rule fails or is not reported. The template's structure (headings, table columns, ID prefixes, allowed values) is defined once in `appdoc/template_spec.py`; the Check reads it.

A Citation path may contain spaces (`` `To be deleted/App/logcall.asp:212` ``) when it has a folder and ends in a file name.

**Advisory.** `check-report.md` lists **Entry points not cited**: route, page, command and job Facts whose file the document never cites, grouped by folder. It does not fail the Check. `check --strict` fails on it.

**Scope.** The Check verifies resolution, structure, references, counts against the Facts, that each finding candidate is addressed, and that each Evidence Register anchor appears in its cited lines. It does **not** judge whether a claim's wording follows from those lines; a PASS is not an accuracy certification.

**Evidence Register.** The source-to-claim audit is recorded as data in `docs/appdoc/evidence.jsonl` (see `SKILL.md`). Line 1 declares the audit state (performed, by whom, scope; or not performed and why). Rows have a result of Supported, Corrected, Downgraded, Dismissed (a finding candidate, ref `smell/<id>`) or Answerable (a section 14 question the source can close, ref `14/Q-n`). `fill` computes the counts, per-section coverage, the register table and verification commands into the Appendix A block of the Markdown; `render` shows that block. An audit declared not performed shows as a banner at the start of Appendix A. A missing register fails C11, so the audit state is never silent.

## Docs-as-code

To keep the generated docs in lockstep with the code, add the deterministic gate (`ci/appdoc-docs-gate.yml`) to the target repo's `.github/workflows/`. On every push and pull request it regenerates the Facts and diffs them against the committed `docs/appdoc/facts.json` (change detection), then runs the AppDoc Check with `--require-audit` (C1–C12, consistency). If the code changed or the docs are broken, the gate fails until the docs are refreshed; if AppDoc itself was upgraded (a new Facts schema), the gate says so instead of blaming the code. AppDoc holds no LLM key, so the AI-written Narrative is not regenerated in CI — refresh it in a session. See `docs/docs-as-code.md` for the full process.

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
