# AppDoc Framework Development Roadmap

**Last Updated:** November 14, 2025  
**Current Version:** 1.0.0  
**Target Audience:** Developers enhancing the AppDoc framework

---

## Overview

This roadmap outlines planned enhancements to transform AppDoc from a solid .NET-focused documentation generator into a comprehensive, multi-framework legacy codebase documentation system. Items are prioritized by impact and feasibility.

**Current Framework Effectiveness: 6.5/10** for legacy .NET codebases  
**Target Framework Effectiveness: 9.0/10** for all major legacy frameworks

---

## High Priority Features

### HP-1: Document PowerShell Core Requirement

**Summary:** Add prominent documentation about PowerShell Core (pwsh) requirement to prevent immediate user failures.

**Implementation Details:**
1. Update `README.md` with a Prerequisites section at the top
2. Add banner in `appdoc.begin.prompt.md` stating PowerShell Core requirement
3. Create troubleshooting guide for Windows PowerShell vs PowerShell Core issues
4. Add version check to `run-all-generators.ps1` that detects PowerShell version and warns if < 7.0
5. Include installation instructions for PowerShell Core across platforms (Windows, macOS, Linux)

**Definition of Done:**
- [ ] README.md contains Prerequisites section with PowerShell Core requirement
- [ ] All prompt files mention PowerShell Core in first paragraph
- [ ] `run-all-generators.ps1` checks `$PSVersionTable.PSVersion` and exits with clear error if < 7.0
- [ ] TROUBLESHOOTING.md created with common PowerShell compatibility issues
- [ ] Installation guide includes `winget install Microsoft.PowerShell` and equivalent for other platforms

---

### HP-2: Add Self-Diagnostic Script

**Summary:** Create a diagnostic script that tests AppDoc framework health on target codebase before running generators.

**Implementation Details:**
1. Create `test-appdoc-environment.ps1` script that validates:
   - PowerShell version (>= 7.0)
   - Template files exist in `.appdoc/templates/`
   - All generator scripts are present and parseable
   - Target codebase path is accessible
   - Output directory is writable
   - Sample pattern detection (run quick regex tests on known file patterns)
2. Add to `appdoc.begin.prompt.md` as Phase 0.5 (before analysis)
3. Output diagnostic report showing:
   - ✅ Environment checks passed
   - ⚠️ Warnings (e.g., no test files detected)
   - ❌ Critical failures (e.g., PowerShell version mismatch)
4. Include `--fix` flag to auto-remediate common issues (create missing dirs, etc.)

**Definition of Done:**
- [ ] `test-appdoc-environment.ps1` script created and added to `scripts/powershell/`
- [ ] Script validates all environment prerequisites
- [ ] Script produces color-coded report (Green/Yellow/Red)
- [ ] `--fix` flag implemented for auto-remediation
- [ ] Integrated into `appdoc.begin.prompt.md` workflow
- [ ] Unit tests validate diagnostic checks work correctly

---

### HP-3: Improve Error Reporting

**Summary:** Distinguish between "not found" vs "detection failed" errors to help users understand what's missing vs what's broken.

**Implementation Details:**
1. Define error categories:
   - `NOT_FOUND` - Expected content type not present in codebase (acceptable)
   - `DETECTION_FAILED` - Script error or parsing failure (needs investigation)
   - `TEMPLATE_ERROR` - Template file missing or malformed (critical)
   - `IO_ERROR` - File system access issues (critical)
2. Update all generator scripts to use structured error reporting:
   ```powershell
   Write-AppDocError -Category NOT_FOUND -Message "No API endpoints detected" -Severity Info
   Write-AppDocError -Category DETECTION_FAILED -Message "Failed to parse $file" -Severity Warning
   ```
3. Create `error-reporting.psm1` module with error categorization functions
4. Add summary report at end of workflow showing:
   - Count of each error category
   - List of files that failed to parse
   - Actionable recommendations for each error type
5. Include `--verbose` flag to show detailed stack traces for debugging

**Definition of Done:**
- [ ] `error-reporting.psm1` module created with error categorization
- [ ] All 11 generator scripts updated to use structured error reporting
- [ ] Error summary displayed at end of `run-all-generators.ps1`
- [ ] `--verbose` flag implemented for debugging
- [ ] Documentation updated with error category reference
- [ ] Validation scripts distinguish false positives from real issues

---

### HP-4: Add Framework Detection Matrix

**Summary:** Create a support matrix document showing which frameworks/patterns AppDoc can detect.

**Implementation Details:**
1. Create `FRAMEWORK_SUPPORT.md` documenting:
   - ✅ Fully Supported (with version ranges)
   - ⚠️ Partially Supported (with limitations)
   - ❌ Not Supported (with planned date if applicable)
   - 🔬 Experimental (beta features)
2. Include detection patterns for each framework:
   - File patterns (e.g., `*Controller.cs` for ASP.NET)
   - Code patterns (e.g., `[HttpGet]` attributes)
   - Config patterns (e.g., `web.config`, `appsettings.json`)
3. Add language support matrix:
   - C# (.NET Framework, .NET Core)
   - JavaScript/TypeScript (Express, NestJS)
   - Python (Django, Flask, FastAPI)
   - Java (Spring Boot, JAX-RS)
   - Ruby (Rails, Sinatra)
   - Go (Gin, Echo)
4. Link from README.md and all prompt files
5. Include "Request Framework Support" section with contribution guide

**Definition of Done:**
- [ ] `FRAMEWORK_SUPPORT.md` created with current support status
- [ ] Support matrix covers 20+ major frameworks
- [ ] Each framework entry includes detection patterns and examples
- [ ] Document linked from README.md and prompt files
- [ ] Contribution guide included for adding framework support
- [ ] Automated test validates support matrix accuracy

---

## Medium Priority Features

### MP-1: Implement AST Parsing for C#/TypeScript

**Summary:** Replace regex-based parsing with Abstract Syntax Tree parsing for accurate code analysis.

**Implementation Details:**
1. **C# AST Parsing:**
   - Integrate Roslyn compiler APIs via PowerShell
   - Create `parse-csharp-ast.ps1` utility script
   - Extract: classes, interfaces, methods, properties, attributes, XML doc comments
   - Parse: method signatures, parameter types, return types, access modifiers
2. **TypeScript AST Parsing:**
   - Use `ts-morph` library (requires Node.js)
   - Create `parse-typescript-ast.ps1` wrapper calling Node.js script
   - Extract: interfaces, classes, decorators, JSDoc comments, exported symbols
3. **Integration:**
   - Update `generate-api-inventory.ps1` to use AST for C#/TS files
   - Update `generate-data-model.ps1` to use AST for entity extraction
   - Fall back to regex for languages without AST support
4. **Performance:**
   - Cache AST results to avoid re-parsing unchanged files
   - Add `--no-cache` flag to force full re-parse

**Definition of Done:**
- [ ] `parse-csharp-ast.ps1` script created using Roslyn APIs
- [ ] `parse-typescript-ast.ps1` script created using ts-morph
- [ ] AST parsing integrated into `generate-api-inventory.ps1`
- [ ] AST parsing integrated into `generate-data-model.ps1`
- [ ] Cache mechanism implemented for performance
- [ ] Accuracy validation shows 95%+ improvement over regex
- [ ] Documentation includes AST parser usage examples

---

### MP-2: Add Spring Boot/Django/Flask Detection

**Summary:** Extend framework support to popular Java and Python web frameworks.

**Implementation Details:**
1. **Spring Boot Detection:**
   - Scan for `@RestController`, `@RequestMapping`, `@GetMapping`, etc. annotations
   - Parse `pom.xml` and `build.gradle` for Spring dependencies
   - Extract endpoint paths, HTTP methods, parameter bindings (`@RequestParam`, `@PathVariable`)
   - Detect Spring Security configurations (`@PreAuthorize`, etc.)
2. **Django Detection:**
   - Parse `urls.py` for URL patterns and view mappings
   - Extract views from `views.py` (function-based and class-based views)
   - Detect Django REST Framework serializers and viewsets
   - Parse `settings.py` for middleware and authentication backends
3. **Flask Detection:**
   - Scan for `@app.route()` decorators
   - Extract route parameters from URL patterns
   - Detect Flask-RESTful resources
   - Parse `config.py` for Flask configuration
4. **Integration:**
   - Update `generate-api-inventory.ps1` with new detection patterns
   - Add framework-specific sections in generated docs
   - Include example code snippets for each framework

**Definition of Done:**
- [ ] Spring Boot endpoint detection implemented (Java 8+)
- [ ] Django URL pattern and view extraction implemented (Python 3.7+)
- [ ] Flask route detection implemented (Python 3.7+)
- [ ] All three frameworks validated against real-world projects
- [ ] `FRAMEWORK_SUPPORT.md` updated with new framework support
- [ ] API inventory template includes framework-specific sections
- [ ] Test suite includes sample projects for each framework

---

### MP-3: Create Diagram Generators

**Summary:** Automatically generate architecture diagrams, data flow diagrams, and dependency graphs.

**Implementation Details:**
1. **Architecture Diagram Generator (`generate-architecture-diagram.ps1`):**
   - Use Mermaid.js syntax to create component diagrams
   - Show: Frontend ↔ Backend ↔ Database ↔ External Services
   - Auto-detect layers from folder structure and namespace analysis
   - Output: `docs/diagrams/architecture.mmd` and rendered PNG/SVG
2. **Data Flow Diagram Generator (`generate-dataflow-diagram.ps1`):**
   - Trace request flow from API endpoint through services to data layer
   - Show data transformations and validation points
   - Highlight external API calls and message queue interactions
   - Output: `docs/diagrams/dataflow.mmd`
3. **Dependency Graph Generator (enhance existing `generate-dependency-graph.ps1`):**
   - Create visual dependency graph using Graphviz DOT format
   - Show project dependencies, NuGet/npm packages, and module relationships
   - Highlight circular dependencies and version conflicts
   - Output: `docs/diagrams/dependencies.dot` and rendered PNG
4. **Diagram Rendering:**
   - Add optional `--render` flag to convert Mermaid/DOT to images
   - Use mermaid-cli or Graphviz if available, otherwise just output source
   - Fall back to online rendering links if tools not installed
5. **Template Integration:**
   - Update all templates to embed diagram images
   - Add "Diagrams" section to `overview.md`

**Definition of Done:**
- [ ] `generate-architecture-diagram.ps1` creates Mermaid component diagrams
- [ ] `generate-dataflow-diagram.ps1` creates Mermaid sequence diagrams
- [ ] `generate-dependency-graph.ps1` enhanced to output Graphviz DOT
- [ ] `--render` flag implemented with mermaid-cli/Graphviz integration
- [ ] All templates updated to include diagram sections
- [ ] Diagrams validated against 3+ real-world projects
- [ ] Documentation includes diagram customization guide

---

### MP-4: Add Incremental Update Mode

**Summary:** Preserve manual edits when regenerating documentation by implementing incremental updates.

**Implementation Details:**
1. **Change Detection:**
   - Create `.appdoc/cache/` directory to store previous generation state
   - Hash codebase files and compare against cached hashes
   - Identify: new files, modified files, deleted files
2. **Selective Regeneration:**
   - Add `--incremental` flag to all generators
   - Only regenerate sections affected by changed files
   - Preserve manually edited content outside of `<!-- AUTO-GENERATED -->` blocks
3. **Protected Regions:**
   - Introduce comment markers in generated docs:
     ```markdown
     <!-- AUTO-GENERATED: DO NOT EDIT -->
     [generator content]
     <!-- END AUTO-GENERATED -->
     
     <!-- MANUAL EDIT: PRESERVED -->
     [user content]
     <!-- END MANUAL EDIT -->
     ```
4. **Merge Strategy:**
   - When conflicts detected, create `.conflict` file with both versions
   - Prompt user to resolve conflicts manually or accept auto-generated version
5. **Audit Trail:**
   - Log all changes to `.appdoc/history/generation-log.json`
   - Include: timestamp, files changed, user who ran generation

**Definition of Done:**
- [ ] `--incremental` flag implemented in all generators
- [ ] Cache mechanism stores file hashes and previous state
- [ ] Protected region markers added to all templates
- [ ] Merge logic preserves manual edits correctly
- [ ] Conflict resolution workflow implemented
- [ ] Audit trail logged to `generation-log.json`
- [ ] Documentation includes incremental mode usage guide

---

## Low Priority Features

### LP-1: Add GraphQL/gRPC Detection

**Summary:** Extend API detection to modern RPC and query languages.

**Implementation Details:**
1. **GraphQL Detection:**
   - Scan for `.graphql`, `.gql` schema files
   - Parse `schema.graphql` for types, queries, mutations, subscriptions
   - Detect GraphQL server implementations (Apollo Server, graphql-yoga, Hot Chocolate)
   - Extract resolver functions from TypeScript/C# code
   - Document GraphQL schema in API inventory with type definitions
2. **gRPC Detection:**
   - Scan for `.proto` files (Protocol Buffer definitions)
   - Parse service definitions and RPC methods
   - Detect gRPC server implementations (gRPC .NET, grpc-node, grpc-go)
   - Extract message types and field definitions
   - Document gRPC services in API inventory with request/response schemas
3. **Integration:**
   - Add "GraphQL Schema" section to `api-inventory.md`
   - Add "gRPC Services" section to `api-inventory.md`
   - Cross-reference with data model for shared types

**Definition of Done:**
- [ ] GraphQL schema parsing implemented
- [ ] gRPC .proto file parsing implemented
- [ ] Resolvers and RPC implementations detected in code
- [ ] API inventory template includes GraphQL/gRPC sections
- [ ] Tested against Apollo Server, Hot Chocolate, grpc-node projects
- [ ] Documentation includes GraphQL/gRPC examples

---

### LP-2: Build Documentation Quality Scoring System

**Summary:** Create automated scoring to measure documentation completeness and quality.

**Implementation Details:**
1. **Quality Metrics Module (`quality-framework.psm1`):**
   - Completeness Score (0-100): % of required sections populated
   - Accuracy Score (0-100): % of code references verified
   - Freshness Score (0-100): days since last update vs code change frequency
   - Readability Score (0-100): Flesch-Kincaid grade level analysis
2. **Scoring Criteria:**
   - Completeness: Count populated vs empty sections, placeholders remaining
   - Accuracy: Cross-check API endpoints exist in code, configs match files
   - Freshness: Compare doc timestamps to git commit history
   - Readability: Analyze sentence structure, jargon usage, example coverage
3. **Dashboard Generator (`generate-quality-dashboard.ps1`):**
   - Create HTML dashboard showing scores for each doc
   - Trend charts showing quality over time
   - Recommendations for improvement
   - Link to specific sections needing attention
4. **CI Integration:**
   - Add GitHub Action to run quality checks on PRs
   - Block merge if quality score drops below threshold
   - Comment on PR with quality report

**Definition of Done:**
- [ ] `quality-framework.psm1` module calculates all 4 quality metrics
- [ ] `generate-quality-dashboard.ps1` creates HTML dashboard
- [ ] Scoring thresholds configurable via `.appdoc/config.json`
- [ ] GitHub Action workflow created for CI integration
- [ ] Documentation includes quality scoring guide
- [ ] Dashboard validated against 5+ real projects

---

### LP-3: Create VS Code Extension

**Summary:** Build VS Code extension for inline documentation generation and navigation.

**Implementation Details:**
1. **Extension Features:**
   - Command Palette: "AppDoc: Generate Documentation"
   - Right-click menu: "Generate Docs for This File"
   - Inline code lens: "📄 View Documentation" above classes/functions
   - Quick fix: "Add Missing Documentation" for undocumented symbols
   - Status bar: Show current doc coverage %
2. **Navigation:**
   - "Go to Documentation" jumps from code to relevant doc section
   - Breadcrumb trail showing code → doc relationship
   - Hover tooltips showing doc excerpts
3. **Real-time Updates:**
   - Watch mode: Auto-regenerate docs on file save
   - Preview pane: Live Markdown preview with diagrams
   - Diff view: Show changes before accepting
4. **Configuration:**
   - `.vscode/appdoc.json` for extension settings
   - Configurable generators to run
   - Custom template directory support
5. **Publishing:**
   - Package as VSIX
   - Publish to VS Code Marketplace
   - Include telemetry (opt-in) for usage analytics

**Definition of Done:**
- [ ] VS Code extension project created with TypeScript
- [ ] All 5 core features implemented and tested
- [ ] Navigation and linking working correctly
- [ ] Watch mode implemented with debouncing
- [ ] Configuration schema defined and validated
- [ ] Extension published to VS Code Marketplace
- [ ] Documentation includes extension usage guide
- [ ] Telemetry dashboard shows user adoption metrics

---

## Experimental Features

### EX-1: AI-Powered Documentation Enhancement

**Summary:** Use LLM to automatically improve generated documentation quality and completeness.

**Implementation Details:**
1. **LLM Integration:**
   - Support OpenAI, Anthropic Claude, Azure OpenAI APIs
   - Configurable API keys in `.appdoc/config.json`
   - Add `--ai-enhance` flag to generators
2. **Enhancement Pipeline:**
   - Generate base documentation using existing scripts
   - Pass to LLM with context: code snippets, config files, existing docs
   - LLM tasks:
     - Fill placeholder sections with inferred content
     - Generate human-friendly descriptions from code
     - Create usage examples from test files
     - Suggest architecture improvements based on patterns
3. **Guardrails:**
   - Mark AI-generated content with `<!-- AI-GENERATED: Review Required -->`
   - Include confidence scores for each AI suggestion
   - Require human review before accepting AI content
   - Log all AI interactions to audit trail
4. **Cost Controls:**
   - Token budget limits to prevent runaway costs
   - Cache LLM responses to avoid redundant calls
   - Local model support (Ollama, llama.cpp) for offline use

**Definition of Done:**
- [ ] LLM integration module supports OpenAI and Claude
- [ ] `--ai-enhance` flag implemented in generators
- [ ] AI-generated content clearly marked and requires review
- [ ] Token budget and caching implemented
- [ ] Local model support (Ollama) working
- [ ] Cost tracking dashboard shows API usage
- [ ] Documentation includes AI enhancement guide with examples

---

### EX-2: Multi-Repository Documentation Aggregation

**Summary:** Generate unified documentation across multiple related repositories (microservices, monorepo subprojects).

**Implementation Details:**
1. **Repository Discovery:**
   - Accept config file listing related repositories
   - Auto-discover repos by naming convention or git submodules
   - Clone/pull repositories to local cache
2. **Cross-Repo Analysis:**
   - Detect service-to-service API calls
   - Map shared data models across services
   - Identify duplicated configuration
   - Show deployment dependencies
3. **Unified Documentation:**
   - Generate master index linking all service docs
   - Create cross-service architecture diagram
   - Show request flow across service boundaries
   - Aggregate dependency graphs
4. **Sync Strategy:**
   - Incremental updates when any repo changes
   - Parallel generation for multiple repos
   - Conflict resolution for shared components

**Definition of Done:**
- [ ] Repository config schema defined (`.appdoc/repos.json`)
- [ ] Multi-repo analysis pipeline implemented
- [ ] Cross-service API call detection working
- [ ] Master documentation index generated correctly
- [ ] Parallel generation reduces total time by 50%+
- [ ] Tested with 5+ microservice architectures
- [ ] Documentation includes multi-repo setup guide

---

## Success Metrics

Track these KPIs to measure AppDoc improvement:

| Metric | Current | Target | Timeline |
|--------|---------|--------|----------|
| Framework Coverage | 5 frameworks | 20+ frameworks | Q2 2026 |
| Detection Accuracy | ~70% | 95%+ | Q1 2026 |
| User Setup Time | 30+ min | <5 min | Q4 2025 |
| PowerShell Errors | High | Near-zero | Q4 2025 |
| Documentation Completeness | 60% | 90%+ | Q2 2026 |
| GitHub Stars | 0 | 100+ | Q3 2026 |
| Active Users | 1 | 50+ | Q4 2026 |

---

## Contributing

Want to help build these features? See [CONTRIBUTING.md](CONTRIBUTING.md) for:
- Development environment setup
- Coding standards and patterns
- Pull request process
- Feature proposal templates

**Priority Areas for Contributors:**
1. Adding framework support (Spring, Django, Rails)
2. Improving error handling and diagnostics
3. Creating diagram generators
4. Building the VS Code extension

---

## Versioning Strategy

- **v1.x**: Current state + High Priority features
- **v2.x**: Medium Priority features (AST parsing, incremental updates)
- **v3.x**: Low Priority + Experimental features (AI enhancement, multi-repo)

---

**Questions or suggestions?** Open an issue at https://github.com/HeWhoRoams/AppDoc/issues
