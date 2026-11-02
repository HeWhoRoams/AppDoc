# AppDoc

**Deterministic, evidence-traceable documentation for legacy and unknown codebases.**

![version](https://img.shields.io/badge/version-1.1.0-6a0032)
![PowerShell](https://img.shields.io/badge/PowerShell-7.2%2B-5391FE?logo=powershell&logoColor=white)
![platforms](https://img.shields.io/badge/platforms-Windows%20%7C%20Linux-informational)
![license](https://img.shields.io/badge/license-MIT-green)

AppDoc scans a codebase and writes an onboarding documentation package for it:

- a 20-section master document;
- per-artifact catalogs;
- a machine-readable evidence layer;
- Mermaid architecture diagrams;
- a self-contained HTML report that works offline.

Every claim cites its source (`file:line`). Anything AppDoc can't ground is tagged `Unknown` rather than filled in.

There are two layers:

- **The core is deterministic.** One PowerShell command, no LLM, no network calls, no API key. A validation gate scores the output, and the build reports the result in its exit code.
- **AI enrichment is optional and quarantined.** The AI session that runs the skill can fill owner-knowledge gaps such as purpose and data flows, but only through a quarantine that fails closed. It never overrides a verified fact, and secrets never reach it.

> **Status:** 1.1.0 is on branch `remediation/skill-portability` and not yet tagged. A code audit (2026-10-28) is being worked through on the same branch: secrets in free text and the slow scope filter are fixed, and the remaining items are listed under [Known limitations](#known-limitations). See [CHANGELOG.md](CHANGELOG.md) for what changed and [ROADMAP.md](ROADMAP.md) for what's next.

---

## Contents

- [How it works](#how-it-works)
- [Quick start](#quick-start)
- [Exit codes](#exit-codes)
- [What you get](#what-you-get)
- [Framework support](#framework-support)
- [Configuration](#configuration)
- [Security and secret handling](#security-and-secret-handling)
- [The enrichment layer](#the-enrichment-layer)
- [Verification and CI](#verification-and-ci)
- [Repository layout](#repository-layout)
- [Known limitations](#known-limitations)
- [Contributing](#contributing) · [License](#license)

---

## How it works

AppDoc is a **harness-agnostic skill**. [`SKILL.md`](SKILL.md) is the entry point, and any AI tool that can read it and run `pwsh` can drive AppDoc. [`references/`](references/) holds the detailed contracts. GitHub Copilot slash-command wrappers live in [`.github/prompts/`](.github/prompts/).

```mermaid
flowchart LR
    T[(Target codebase)] --> L1
    C[".appdoc/config.json<br/>(optional)"] --> L1
    subgraph L1["Layer 1 · deterministic core (no LLM)"]
        direction TB
        D[Framework detection] --> E[Evidence extractors]
        E --> G[Evidence graph +<br/>canonical metrics]
        G --> M[20-section composer]
        M --> V{Validation gate}
    end
    V --> O[(docs/ package)]
    O -. opt-in .-> L2
    subgraph L2["Layer 2 · quarantined enrichment"]
        direction TB
        R[Redacted pending-field<br/>envelope] --> S[Surrounding AI session<br/>fills gaps]
        S --> Q{Quarantine:<br/>Verified-fact lock,<br/>no fabrication}
    end
    Q --> O
```

### The build pipeline

`run-appdoc-build.ps1` is the only supported entry point. One build passes through seven stages. Each stage has its own page, and the gate criteria are written once, in [gates.md](docs/pipeline/gates.md).

```mermaid
---
title: "L0 · AppDoc build pipeline overview"
---
flowchart LR
  accTitle: AppDoc build pipeline overview
  accDescr: One build run passes through seven stages. Stop gates G1, G4 and G5 end the run with exit code 1 or 3. Score gates G2 and G3 record an outcome and let the run continue; the close-out stage turns them into exit code 0, 1 or 2. Enrichment is optional. Filter gate G6 refuses individual unsafe values and the run continues.

  S1("1 Configure") --> G1{"G1 STOP<br/>config and redaction<br/>patterns valid"}
  G1 --> S2("2 Collect evidence") --> G2{{"G2 SCORE<br/>generator crash<br/>recorded"}}
  G2 --> S3("3 Compose") --> S4("4 Validate") --> G3{{"G3 SCORE<br/>gate status"}}
  G3 --> S5("5 Finalize") --> G4{"G4 STOP<br/>redaction sweep"}
  G4 -->|"default"| S7("7 Close out<br/>exit 0, 1 or 2")
  G4 -->|"enrichment on"| S6("6 Enrich<br/>optional") --> G5{"G5 STOP<br/>secret gate on<br/>LLM input"}
  G5 --> G6[/"G6 FILTER<br/>quarantine merge"/] --> S7
  G1 -.->|"exit 1 or 3"| STOP(["Run stops"])
  G4 -.->|"exit 3"| STOP
  G5 -.->|"exit 3"| STOP
```

Start at the [pipeline overview](docs/pipeline/README.md) and drill down: [Configure](docs/pipeline/01-configure.md), [Collect evidence](docs/pipeline/02-collect-evidence.md), [Compose](docs/pipeline/03-compose.md), [Validate](docs/pipeline/04-validate.md), [Finalize](docs/pipeline/05-finalize.md), [Enrich](docs/pipeline/06-enrich.md), [Close out](docs/pipeline/07-close-out.md). Every step in execution order is on the [run order](docs/pipeline/detail/run-order.md) page.

Every evidence producer runs **before** the steps that summarise evidence, so the overview and the master document see everything that was found. Each shared artifact (API inventory, data model, build cookbook) has **one owner per target**. On a Classic ASP target with `.asp`/`.inc` sources, the Classic ASP generators own it. On any other target, the generic generators do.

---

## Quick start

**Prerequisites**

- PowerShell **7.2+** (`pwsh`) on Windows or Linux. Windows PowerShell 5.1 is not supported.
- Optional: the .NET SDK. With it, C# is parsed with Roslyn; without it, AppDoc falls back to regex.
- Run AppDoc on a **scratch copy** of the target, so its committed `docs/` is never overwritten by accident.

```bash
# from the AppDoc repo root
pwsh -NoProfile -File ./.appdoc/scripts/powershell/run-appdoc-build.ps1 -Path <target-repo>
```

| Parameter | Default | Purpose |
|---|---|---|
| `-Path` | *(required)* | The target repository root. |
| `-QualityThreshold` | `80` | Minimum gate score (1–100). |
| `-StrictValidation` | off | Treat `pass-with-weak-coverage` as a failure. |
| `-SkipDiagrams` | off | Skip the C4 and flow diagrams (faster). |
| `-SkipSyntaxGate` | off | Skip the PowerShell syntax pre-check. |
| `-Profile` | `default` | Generation profile. |
| `-EnableSemanticEnrich` | off | Run the optional Layer 2 enrichment stage. |
| `-AllowGateFail` | off | For exploratory runs: log a failed gate but exit 0. Never use it in CI. |

To change where the output goes, set `outputDir` in the target's `.appdoc/config.json`. There is no command-line option for it.

## Exit codes

The build reports its outcome in the exit code ([ADR 0003](docs/adr/0003-sub-validator-failure-policy.md)). **Treat any non-zero code as "not done".**

The decision is made in the last stage. [Close out](docs/pipeline/07-close-out.md) shows it step by step, and [gates.md](docs/pipeline/gates.md#exit-codes) lists every path that sets each code.

| Code | Meaning |
|---|---|
| `0` | The gate passed. Without `-StrictValidation`, `pass-with-weak-coverage` also exits 0, as does any run with `-AllowGateFail`. |
| `1` | Tool error: bad path, missing module, invalid config JSON, a generator in the main pipeline crashed, or no validation report was produced. |
| `2` | The gate failed: the docs were written but are not trustworthy. |
| `3` | Fail-closed stop: the redaction sweep could not run, a vendor-shaped secret (an AWS or GitHub key, say) was still in a generated file after the sweep, a `redactionRegexes` entry is invalid, or the secret-redaction gate blocked enrichment. |

A sub-validator that fails lowers the gate score. One that crashes forces the gate to `fail`. The gate result also depends on blocking **policy** checks (for example `provenance-missing`), so read `validation-report.json`, not just the score.

---

## What you get

Everything is written to the target's `docs/` folder, or the configured `outputDir`:

```text
docs/
├── application-documentation.md     # the 20-section master document
├── report.html                      # self-contained themed report (offline by default)
├── overview.md · start-here.md · task-guides.md · index.md
├── api-inventory.md (+ .appendix.md) · data-model.md · config-catalog.md
├── build-cookbook.md · test-catalog.md · debt-register.md · dependencies-catalog.md
├── extcalls.md · security.md · procdict.md          # where the framework supports them
├── git-ownership.md · source-docs.md · evidence-register.md · verification-appendix.md
├── pristine-report.md               # per-section source-groundedness
├── validation-report.json (+ .summary.md)   # the gate verdict
├── diagnostics-report.json          # warnings, generator failures, run metadata
├── diagrams/                        # Mermaid C4 context/container, data flow, lineage, sequences
└── evidence/                        # *.evidence.json per artifact, evidence graph, manifest
    └── semantic/                    # only when enrichment is enabled
```

<details>
<summary><b>The 20 sections of <code>application-documentation.md</code></b></summary>

| # | Section | # | Section |
|---|---|---|---|
| 1 | Application Index | 11 | Security and Operational Risks |
| 2 | Coverage and Executive Overview | 12 | Ownership and Maintenance |
| 3 | Architecture | 13 | Architecture and Data-Flow Diagrams |
| 4 | Functional Inventory | 14 | Glossary |
| 5 | Roles and Access Model | 15 | Evidence Register |
| 6 | UI Catalog | 16 | Open Questions and Documentation Gaps |
| 7 | Operational Workflows | 17 | Recommendations |
| 8 | Data and Integrations | 18 | Operations Runbook |
| 9 | External Call Register *(+ stored-procedure data dictionary)* | 19 | Verification Appendix |
| 10 | Troubleshooting Matrix | 20 | Provenance |

</details>

**Provenance and honesty**

- Every claim carries an epistemic tag: `Verified`, `Partly verified`, `Inferred`, `Unknown`, or `Operator-supplied` (for overlay content).
- Every generated file ends with a single `## Provenance` footer. JSON files carry a `provenance` object instead.
- Hand-written files are never stamped, normalised or rewritten. That covers `docs/adr/` and any file containing `<!-- appdoc:hand-authored -->`.
- Generated text is UTF-8 without a BOM, with LF line endings.
- No host path appears in the output. Paths inside the target are relative; any other path is written as `<external>/<file name>`.
- Source files are read in ordinal path order, so the output does not depend on the operating system's file listing order.
- Re-running on the same target gives the same content and the same gate result. Only timestamps change.

**Docs as code ([ADR 0002](docs/adr/0002-generated-docs-as-code.md)).** `docs/` is a stable, committed home. Generated files are overwritten in place, and hand-written material is preserved. AppDoc's own `docs/` folder is a dogfood run of AppDoc on itself, and CI checks it stays in sync with a fresh build.

---

## Framework support

Each framework class has a fixture and a golden regression suite in `tests/powershell/`.

| Framework class | Extraction | Golden suite |
|---|---|---|
| Classic ASP | Regex (Classic ASP extractors) | `test-golden-classic-asp.ps1` |
| ASP.NET Web Forms | Regex + C# | `test-golden-csharp-webforms.ps1` |
| C# ASP.NET Core | **AST (Roslyn)**, regex fallback without .NET | `test-golden-csharp-core-api.ps1` |
| Python Flask | Regex | `test-golden-python-flask.ps1` |
| Node / Express (TypeScript) | Regex | `test-golden-node-express.ps1` |
| Java Spring | Regex | `test-golden-java-spring.ps1` |

ASP.NET MVC 5 has also been tested on a real convention-routed target.

Gate scores on the fixtures at 1.1.0, with every fixture built twice and both runs identical:

```mermaid
xychart-beta
    title "Gate overallScore by fixture (threshold 80)"
    x-axis ["Classic ASP", "Core API", "Web Forms", "Java Spring", "Node/Express", "Flask", "AppDoc (self)"]
    y-axis "score" 0 --> 100
    bar [93, 92, 99, 97, 100, 99, 99]
    line [80, 80, 80, 80, 80, 80, 80]
```

A passing gate is a **floor, not a ceiling**. It proves the output is non-empty and grounded in the source, not that every extractor found the full surface. If a section looks thin, read the per-surface coverage metrics (for example `apiCoverage`).

Not yet supported: Django, Go, Ruby, Rust, and polyglot or microservice repos. Treat output for these as low-confidence until each has a fixture and a golden suite (see [ROADMAP.md](ROADMAP.md)). To request a framework, open an issue with the framework and version, a minimal sample project, and the routing, config and model patterns it uses.

---

## Configuration

Configuration is optional and lives in `<target>/.appdoc/config.json`. Without a config file, AppDoc uses its defaults. A config file that isn't valid JSON stops the build. The full reference is [`references/config-schema.md`](references/config-schema.md).

```json
{
  "schemaVersion": "appdoc-config/v1",
  "outputDir": "docs",
  "theme": "cmu",
  "redactionPatterns": ["svc-report-user"],
  "redactionRegexes": ["AKIA[0-9A-Z]{16}"],
  "opaqueTokenPattern": "@@APP_[A-Z0-9_]+@@",
  "overlays": { "Operational Workflows": ".appdoc/overlays/operational-workflows.md" },
  "ownership": { "showEmails": false },
  "pristineFloor": 80
}
```

| Key | What it does |
|---|---|
| `outputDir` | Output folder inside the target (default `docs`). Excluded from scanning. A path outside the target is ignored with a warning. |
| `theme` / `themeFile` | `cmu` (maroon/gold, the default), `navy-teal`, or your own theme JSON. An unknown name logs a warning; a missing `themeFile` is an error. |
| `assets` *(in the theme)* | `inline` (default) makes `report.html` fully offline, with Mermaid inlined and system fonts (about 3.5 MB). `cdn` makes a smaller file that needs internet. |
| `redactionPatterns` | Exact secret **values**, matched literally. |
| `redactionRegexes` | Regex patterns, case-insensitive. An invalid regex stops the build with exit 3. |
| `opaqueTokenPattern` | Placeholder tokens left verbatim in a pre-sanitised source, instead of being redacted. |
| `overlays` | Owner-written narrative per section. It is rendered as **Operator-supplied context** and never counted as `Verified`. The default location is `.appdoc/overlays/<section-slug>.md`. |
| `ownership.showEmails` | Show author emails in `git-ownership.md`. Off by default: names only, `.mailmap` honoured. |
| `pristineFloor`, `minCommitsForOwnership` | Thresholds for the pristine report and ownership rows. |

**Scope policy.** Which files each artifact reads is set in `.appdoc/policies/scope.v1.json`: exclusions (`node_modules`, `bin`, `obj`, tests, fixtures, the output folder, and so on) and, per artifact, named `patternSets` of file names (for example the `source` set of the debt register). A target can ship its own `<target>/.appdoc/policies/scope.v1.json`, which takes precedence over the one in AppDoc. A target policy without `patternSets` falls back to the built-in sets. Excluded folders are skipped during the walk, not listed and then filtered.

**Branding.** AppDoc is CMU-first: reports default to the CMU theme and mark. Another organisation can copy `.appdoc/templates/html/theme.json`, change its colours, fonts and `masthead`, set `masthead.logoSvg` to `none` or its own SVG, and point `themeFile` at it.

**Target narrative belongs to the target.** AppDoc ships no knowledge of any particular application. Workflow descriptions, business context and internal system names go in that target's overlay files ([ADR 0001](docs/adr/0001-redaction-externalize-per-target-secrets.md) amendment).

---

## Security and secret handling

```mermaid
flowchart LR
    SRC[Target source] --> X1["Extractors<br/>redact by shape and key name"]
    X1 --> X2["Operator redaction<br/>redactionPatterns · redactionRegexes"]
    X2 --> X3["Final sweep over docs/<br/>free-text + vendor shapes<br/>(fail-closed, skips vendored + hand-written files)"]
    X3 --> DOCS[(docs/)]
    DOCS -. enrichment .-> X4{"Secret-redaction gate<br/>scans raw strings and JSON"}
    X4 -- clean --> LLM[AI session]
    X4 -- secret found --> STOP([exit 3])
```

- **Shape patterns only in the tool.** AppDoc recognises high-entropy, base64, named-key and URI-credential (`user:pass@`) shapes. It never contains a target's real secret values ([ADR 0001](docs/adr/0001-redaction-externalize-per-target-secrets.md)).
- **Free text is redacted too.** Comment text (TODO, FIXME, HACK) and every generated file in the final sweep pass through `Protect-AppDocFreeText`. It removes vendor-shaped secrets (AWS, GitHub, Slack, Stripe and Google keys, JWTs, PEM private keys) and the value of any `name = value` pair whose name looks like a secret (`password`, `token`, `apiKey`, …). After the sweep, any vendor shape still present stops the build with exit 3, and the gate's redaction score counts leaks in generated Markdown.
- **The secret's location is shown, never its value.** The key name and location appear in the docs; the value renders as `[REDACTED]`.
- **Per-target secrets come from the operator.** Supply them through `redactionPatterns` and `redactionRegexes` in the config, or through the `-RedactionPatterns` and `-RedactionRegexes` options of `generate-source-docs.ps1` and `run-appdoc-semantic-enrich.ps1`.
- **Fail-closed by default.** These conditions stop the build with exit 3 instead of continuing with weaker redaction:
  - the redaction module is missing;
  - a regex is invalid;
  - a vendor-shaped secret survives the final sweep;
  - a known secret appears in the LLM envelope (including secrets that contain `"` or `\`).

---

## The enrichment layer

Enrichment is opt-in with `-EnableSemanticEnrich`. It fills owner-knowledge fields that parsing the source can't, using the **surrounding** AI session. AppDoc itself holds no API key and makes no LLM network calls.

```mermaid
sequenceDiagram
    autonumber
    participant B as run-appdoc-build.ps1
    participant G as Secret-redaction gate
    participant S as Surrounding AI session
    participant Q as Quarantine (apply)
    B->>B: Deterministic build (Layer 1)
    B->>G: Pending-field envelope (null / Unknown / low-confidence only)
    G-->>B: Secret found → exit 3
    G->>S: Redacted envelope written to evidence/semantic/input
    S->>S: Fill fields, write evidence/semantic/output
    S->>B: Re-run build
    B->>Q: Apply output
    Q->>Q: Refuse overrides of Verified facts (logged)
    Q->>Q: Tag each field llm / deterministic / open
    Q-->>B: Applied values, re-rendered docs
    Note over Q: Unchanged inputs come from the cache.<br/>An edited output is re-applied (superseded).
```

- **A tiered Verified-fact lock.** The LLM may only fill `null`, `Unknown` or low-confidence fields, and can never override a source-grounded fact.
- **No fabrication.** Fields the LLM doesn't provide stay `Unknown`.
- **An input-hash cache.** Unchanged records are skipped, but an output file you corrected is always re-applied.

The contracts are in [`references/enrichment-contract.md`](references/enrichment-contract.md) and [`references/enrichment-operations.md`](references/enrichment-operations.md). The Copilot wrapper is `/appdoc.enrich`.

---

## Verification and CI

```mermaid
flowchart LR
    PR([push / pull request]) --> H[hygiene]
    PR --> L[lint]
    H --> T[tests]
    H --> D[drift]
    H -.- H1["tracked-but-ignored files · harness and target names in core ·<br/>#requires + CmdletBinding · referenced scripts exist ·<br/>no host paths / CR in docs · syntax + integrity gates · pipeline docs gate"]
    L -.- L1["PSScriptAnalyzer: approved verbs, trailing whitespace,<br/>no empty catch in .appdoc/ (others reported)"]
    T -.- T1["Pester unit + golden suites on Ubuntu and Windows,<br/>plus Ubuntu without .NET · quarantine proof harness ·<br/>output snapshot harness (Ubuntu without .NET)"]
    D -.- D1["rebuild AppDoc's own docs/ and compare catalogs,<br/>section headings and gate result"]
```

What each job checks (see also [what CI checks on this repository](docs/pipeline/ci.md)):

- **Pipeline docs gate:** `ci-pipeline-docs-gate.ps1` checks the pages under [`docs/pipeline/`](docs/pipeline/README.md): diagram size and accessibility, links, gate IDs, and the code they name.
- **Gate:** `validate-documentation.ps1` computes a composite score from 18 components ([how it is scored](docs/pipeline/detail/validation-scoring.md)) and applies blocking policy checks.
- **Golden suites:** one per framework class, each locking extractor output to its committed baseline.
- **Unit tests:**
  - gate validator failures and build exit codes;
  - re-run determinism;
  - operator redaction and leak prevention for target-specific text;
  - free-text redaction, and a full build of a fixture with planted secrets (`tests/fixtures/secret-in-comments-sample`) that must leak none;
  - the scope filter (same files as list-then-filter, excluded folders never entered, ordinal order) and policy pattern sets;
  - the shared value accessor `Get-AppDocValue`;
  - provenance footer, git ownership, `outputDir`, themes;
  - module import (approved verbs).
- **Output snapshot harness:** builds every fixture and checks that each generated file, the exit code and the gate result match the committed baseline ([how it works](docs/pipeline/ci.md#the-output-snapshot-harness)):
  ```bash
  pwsh -NoProfile -File tests/powershell/test-output-snapshot.ps1
  ```
  Baselines exist only for the `no-dotnet` profile, so run it with `dotnet` off `PATH` and `node` on it (the profile is picked from `PATH`). An intended output change is taken with `-Update` and reviewed with `-SaveTree` / `-CompareTree`.
- **Scope benchmark** (run by hand, not in CI): `.appdoc/scripts/powershell/bench-scope.ps1` times source-file selection on 10,000 generated files and exits 1 if it takes longer than 1 s.
- **Quarantine proof harness:** run as a plain script, not under Pester:
  ```bash
  pwsh -NoProfile -File tests/powershell/test-semantic-quarantine.ps1
  ```

---

## Repository layout

```text
SKILL.md                         # the skill contract (entry point for any AI harness)
references/                      # config schema, verification, enrichment contract + operations
.appdoc/policies/scope.v1.json   # scope policy: exclusions and per-artifact file patternSets
.appdoc/scripts/powershell/      # run-appdoc-build.ps1, run-all-generators.ps1, generate-*, validate-*, ci-*
.appdoc/scripts/powershell/modules/   # AppDoc.*.psm1 shared modules (Config, Paths, Scope, Values, SecretPolicy,
                                      #   SemanticRedaction, Provenance, ClassicAsp, EvidenceGraph, …)
.appdoc/templates/               # Markdown templates, HTML themes, vendored Mermaid (templates/html/vendor)
.github/prompts/                 # Copilot wrappers: /appdoc.begin, /appdoc.enrich, /appdoc.diagrams
.github/workflows/appdoc-ci.yml  # CI (hygiene, lint, tests, drift)
docs/                            # AppDoc's own generated docs (dogfood) + docs/adr/
tests/powershell/                # Pester suites, golden suites, quarantine and output snapshot harnesses
tests/powershell/snapshots/      # committed snapshot baselines (no-dotnet profile)
tests/fixtures/                  # one sample target per framework class, plus a planted-secrets fixture
```

Coding conventions are in [`.github/copilot-instructions.md`](.github/copilot-instructions.md) and [`PSScriptAnalyzerSettings.psd1`](PSScriptAnalyzerSettings.psd1).

## Troubleshooting

- **Environment check:** `pwsh ./.appdoc/scripts/powershell/appdoc.diagnose.ps1 -RootPath <target> -Fix`
- **Non-zero exit:** see [Exit codes](#exit-codes). Start with `validation-report.json` (status, score, failed validators, `validatorInternalErrors`), then `diagnostics-report.json` (`metadata.scriptFailures`).
- **A thin section on a passing gate:** check that framework's coverage metric. The gate is a floor.
- **The report renders without diagrams when emailed:** make sure the theme uses `"assets": "inline"`, which is the default.

## Known limitations

These are open items from the 2026-10-23 review and the 2026-10-28 audit, tracked for 1.1.x / 1.2.0:

- If the C4 generator, the diagram suite or the HTML report crashes, the build still exits 0. Only crashes in the main generator pipeline give exit 1. Check `diagnostics-report.json` (`metadata.scriptFailures`) until this is fixed.
- The doc-integrity CI gate runs the diagram stability gate, which rewrites `docs/diagrams/` and `docs/evidence/diagram-truth-pack.json` in the repository it checks. Run it on a copy.
- A `|` inside a table cell is escaped by the renderers, but several readers (the HTML report, the unified master, the validator and the pristine report) still split rows on every `|`.
- TypeScript property types with a union, a literal or a space are cut short (`owner: string | null` becomes `owner: string`).
- JSON files built from plain hashtables can write their keys in a different order on each run. The content is the same, and the snapshot harness compares canonical JSON.
- Whether some evidence files carry a `determinism` block depends on which modules happen to be loaded.
- Free-text redaction runs in the debt register and in the final sweep. The other extractors that copy free text rely on the sweep, and the enrichment redaction module does not yet share the vendor shapes.
- Generated catalogs repeat their content exactly between runs, but their timestamps change.
- The `/appdoc.diagrams` Copilot prompt edits generated diagrams in place, so the next build overwrites those edits.
- Many internal error paths fall back to defaults or `Write-Verbose` instead of reporting a diagnostic.
- Pester has not yet been run against the 1.1.0 changes; the first CI run will be the first. The snapshot harness covers only the path without .NET, so the Roslyn C# parser path is checked by the golden suites alone.

## Contributing

Fork the repo, create a branch, and open a pull request. CI must be green.

**The gate is how AppDoc stays accurate.** Never lower a threshold or relax a policy check to make output pass. When a stricter check turns something red, fix the cause.

## License

MIT. See [LICENSE](LICENSE) and [NOTICE](NOTICE) (vendored Mermaid). Copyright (c) 2026 Tim Niles.

For support, open an issue on GitHub.
