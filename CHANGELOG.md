# Changelog

## Unreleased

### Added — the integration picture (content Phases 6a + 6b)
- **Widened the `connection.type` vocabulary** (an *additive convention* change — `KINDS` and `SCHEMA` in `facts.py` are unchanged). A shared catalog (`appdoc/stacks/integrations.py`) now detects the non-database system connections the per-stack extractors previously missed: `cache` (Redis/Memcached), `queue` (Kafka, RabbitMQ, SQS, pika, kombu, MassTransit, Confluent), `object_storage` (S3, Azure Blob, GCS), `grpc`, `ldap`, and `search` (Elasticsearch/OpenSearch), wired into the python, java, node and dotnet Stacks. Each yields a `connection` Fact with the correct `type`; `external_call.type` also accepts `grpc`.
- **A `System Connections` view** (`appdoc/integration.py`): a deterministic post-pass (not the AI Narrative) that aggregates the raw `connection`/`external_call`/`dependency` Facts into a system-to-system summary — per-type distinct drivers, counts, file/line provenance, a compact integration map, and the manifest dependencies. Rendered near the top of the Facts summary, and (when a Narrative is present) of the HTML page. It is a pure function of the Facts, so it is byte-identical across runs.
- Fixture `tests/samples/integrations/` plus `tests/test_integration_catalog.py` and `tests/test_integration_view.py`.

> **Extraction changelog note:** Phases 6a/6b are **additive** and on by default (no flag). Existing Samples' `facts.json` is byte-identical to before; `facts.json` only changes for Targets that actually use the newly-detected integrations. This is a *content* change, not a silent change to the default output of existing codebases — documented here so it is not mistaken for a regression.

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
