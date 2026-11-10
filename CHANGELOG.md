# Changelog

## 2.0.0

AppDoc is rebuilt as a small, portable skill. See `docs/adr/0004-facts-plus-narrative.md`.

### Changed
- Scripts now extract **Facts** only; the AI writes the **Narrative** from a fixed Template and may read source, citing every claim.
- Python 3.10+ (standard library only) replaces PowerShell 7.2+.
- One entry point, `SKILL.md`, and three commands: `extract`, `check`, `render`.
- Output is one Markdown document in 16 sections plus the Facts file, the Facts summary, a Check report and a rendered HTML page, under `docs/appdoc/`.
- Claim labels reduced from five to three: Cited, Inferred, Unknown.
- Config files are never read for values; extractors record key names and locations only.
- Theming is a replaceable CSS file (CMU theme by default).

### Added
- `check`: pass/fail problem list (rules C1 to C7), including a secret scan, with a Citation register.
- Facts summary for large Targets.
- Optional `appdoc-context.md` owner notes and `.appdocignore`.
- Stack extractors for Classic ASP, ASP.NET (Web Forms and MVC 5), ASP.NET Core, Java Spring (with Struts, JSP and MyBatis), Python Flask and Node/Express, with a generic fallback for everything else.

### Fixed after first install test
- C1 accepts folders and unique bare filenames; ignores extensionless spans that are not files.
- Facts summary says empty lists are not proof of absence, shows git history, and excludes test-code Facts.
- Ownership only with full git history; `target.history` recorded.

### Removed
- The scored validation gate and its 15 components, the pristine report, the evidence graph and canonical metrics.
- The redaction subsystem and exit-3 path, semantic enrichment and quarantine, generation profiles, theme JSON and masthead options.
- Golden-output test suites, Copilot prompt wrappers, the self-generated `docs/` and its drift check.
- Roslyn and TypeScript AST parsers.

1.x (PowerShell) remains available at the `v1.1.0` tag.
