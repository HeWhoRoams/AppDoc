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
python -m appdoc check <target>       # exit 0 pass, 2 problems, 1 tool error
python -m appdoc render <target>      # writes application-documentation.html
```

Run these from the AppDoc folder (or call `python run_appdoc.py ...` from anywhere). On Windows use `py -3 -m appdoc ...` if `python` is not on PATH. Run on a **scratch copy** of the Target if you do not want files added to its `docs/appdoc/`. All output goes to `<target>/docs/appdoc/` (override with `--out`, which must stay inside the Target).

## What you get

```
docs/appdoc/
  facts.json                       reproducible Facts file
  facts-summary.md                 map of the Facts (read first on large Targets)
  application-documentation.md     the Narrative: 16 sections, cited
  check-report.md                  PASS/FAIL, problems, Citation register
  application-documentation.html   single offline file, Mermaid inlined
```

The 16 sections: Application Index, Coverage and Overview, Architecture, Functional Inventory, Roles and Access Model, UI Catalog, Workflows, Data and Integrations, Troubleshooting Matrix, Security and Operational Risks, Ownership and Maintenance, Architecture and Data-Flow Diagrams, Glossary, Open Questions, Recommendations, Operations Runbook.

## Supported Stacks

| Stack id | Detected from | Facts extracted |
|---|---|---|
| `classic-asp` | `*.asp`, `global.asa` | pages and inputs, includes, SQL and stored procedures, connections, COM/HTTP/mail/file calls, Session auth checks, error messages |
| `aspnet` | `*.aspx`, `Global.asax` (Web Forms, MVC 5) | pages, handlers, controller actions and routes, SQL, EF entities, calls, authorize checks, messages |
| `aspnet-core` | `*.csproj` + `Program.cs`/`Startup.cs` | attribute and minimal-API routes, Razor Pages, EF Core and Dapper, `GetConnectionString`, authorize policies |
| `java-spring` | `pom.xml`/`build.gradle` + `*.java` | Spring MVC mappings, Struts, web.xml, JSP, JPA/JDBC/MyBatis SQL, datasource beans, security rules |
| `python-flask` | `requirements*.txt`/`pyproject.toml` + `*.py` | routes and blueprints, SQLAlchemy and raw SQL, connections, config reads, role decorators |
| `node-express` | `package.json` + `*.js`/`*.ts` | routes and middleware, Sequelize/Mongoose/knex/SQL, connections, `process.env` reads |

Every Target also gets the **generic** extractor: files, dependency manifests, config keys (never values), connection and secret locations, optional git ownership, and a `stack` fact marked unsupported for ecosystems AppDoc does not read yet (Go, Ruby, Rust, PHP, Django, and others). Section 2 of the document names them, so the Reader knows which parts have less extracted backing.

## The Facts file

`facts.json` holds records of `{kind, stack, path, line, name, detail}`. Kinds: `file`, `stack`, `entry_point`, `data_access`, `connection`, `config_key`, `dependency`, `external_call`, `auth_check`, `message`, `ownership`. It contains no timestamps, no absolute paths and no secret values; entries are sorted and de-duplicated, and the Target's git commit is recorded when there is one.

## The Check

| Rule | Fails when |
|---|---|
| C1 | a Citation points to a missing file or a line past the end (folders and unique bare filenames resolve; extensionless non-existent spans are not Citations) |
| C2 | a Citation in section 10 has no line |
| C3 | a section is missing, out of order, empty or still a placeholder |
| C4 | section 14 is empty while Unknowns exist, or Data and Integrations is empty though Facts exist |
| C5 | a paragraph, list item or table row in sections 3 to 10 is neither cited, Inferred nor Unknown |
| C6 | secret-shaped text, or a `never-mention` term, appears |
| C7 | an unsupported Stack is not named in section 2 |

There is no score. Each rule fails or is not reported.

**Scope.** The Check verifies resolution and structure — Citations resolve, sections are present and populated, and no secret-shaped text appears. It does **not** verify that the cited line supports the claim; a PASS is not an accuracy certification.

**Source-to-claim audit and Verification.** Before the Check, the workflow re-reads each cited claim against its source and records the result in `docs/appdoc/verification.md` (see `SKILL.md`). The check report surfaces that record, or notes the gap when it is absent. An absent `verification.md` is a noted gap, never a failure — the Check's exit code is unaffected.

## Docs-as-code

To keep the generated docs in lockstep with the code, add the deterministic gate (`ci/appdoc-docs-gate.yml`) to the target repo's `.github/workflows/`. On every push and pull request it regenerates the Facts and diffs them against the committed `docs/appdoc/facts.json` (change detection), then runs the AppDoc Check (C1–C7, consistency). If the code changed or the docs are broken, the gate fails until the docs are refreshed. AppDoc holds no LLM key, so the AI-written Narrative is not regenerated in CI — refresh it in a session. See `docs/docs-as-code.md` for the full process.

## Configuration

All optional, all in the Target:

- `appdoc-context.md`: owner notes (purpose, owners, environments). Cited as owner-supplied. A ```` ```never-mention ```` block lists internal terms that must not appear in the output.
- `.appdocignore`: folder names and `*` globs to skip.
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
- Hard-coded secrets are found by the AI reading source and by the Check's scan, not recorded as Facts.
- The Check proves Citations resolve, not that the cited line supports the claim; the source-to-claim audit (recorded in `verification.md`) covers the support check. Neither verifies section 1 links or Mermaid syntax.
- Ownership Facts need full git history; shallow clones get none. Facts from test code carry `test: true` and are left out of the summary lists.
- Section prose is grounded but not byte-identical between runs; only the Facts file is.

## History

AppDoc 1.x was a PowerShell program that tried to generate the whole document deterministically. It is kept in `v1.1.0`. See `docs/adr/0004-facts-plus-narrative.md` for why 2.0 changed.

## License

MIT. See `LICENSE` and `NOTICE` (vendored Mermaid in `appdoc/assets/`). Copyright (c) 2026 Tim Niles.
