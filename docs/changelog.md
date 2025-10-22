# Changelog

All notable changes to AppDoc will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-10-22

### Added
- **Testing Layer**: Comprehensive test suite with pytest and coverage reporting
  - Unit tests for Python analyzer (LOC, doc density, import detection)
  - Integration tests for CLI scan execution and JSON output validation
  - Continuous integration with GitHub Actions and status badge
- **Dependency Graph Visualization**: Interactive graph showing file dependencies
  - NetworkX-based graph construction from import relationships
  - D3.js visualization in HTML reports with zoomable node-link diagrams
  - Node size represents lines of code, colors indicate programming language
- **Output Schema Versioning**: Versioned JSON outputs with `schema_version` field
  - Updated JSON schema documentation with dependency graph structure
  - Backward-compatible schema design for future extensions
- **Performance & Profiling Metrics**: Enhanced reporting with runtime statistics
  - Time elapsed, files scanned, and ignored patterns in HTML footer
  - Performance metrics exported to JSON for benchmarking
- **Language Analyzer Foundations**: Stubs for TypeScript and C# analyzers
  - Extensible analyzer architecture for multi-language support
  - TypeScript analyzer stub with `.ts`/`.tsx` support
  - C# analyzer stub with `.cs` support for future Roslyn integration

### Changed
- **Major version bump** from 0.1.0 to 1.0.0 reflecting stable production-ready features
- Updated development status classifier to reflect v1.0.0 milestone
- Enhanced HTML report template with interactive dependency graph section

### Performance
- Optimized dependency graph building using NetworkX algorithms
- Maintained concurrent file processing performance with new analyzers
- Added performance metrics collection during scan operations

## [0.1.0] - 2025-10-22

### Added
- **Initial release** of AppDoc, a multi-language code documentation analysis tool
- **Python analyzer** with AST-based parsing for accurate docstring extraction
- **JavaScript/TypeScript analyzer** with regex-based JSDoc/TSDoc parsing
- **CLI interface** with concurrent processing using ThreadPoolExecutor
- **JSON output** with comprehensive metrics and per-file breakdown
- **HTML reports** with Chart.js visualizations and responsive design
- **Modular architecture** with extensible analyzer plugin system
- **Cross-platform support** (Linux, macOS, Windows)
- **Documentation site** using MkDocs with comprehensive guides

### Features
- Documentation coverage analysis (functions, classes, modules)
- Code metrics (lines of code, function/class counts)
- Dependency analysis and import tracking
- Language-specific statistics and breakdowns
- Concurrent scanning for performance
- Configurable analysis with glob patterns for exclusions

### Development
- Pre-commit hooks for code quality
- Comprehensive test setup (pytest, coverage)
- Black formatting and isort import sorting
- Type hints throughout codebase
- Conventional commits workflow

### Documentation
- Complete user documentation with examples
- Developer guides for extending with new languages
- API reference and JSON schema documentation
- Installation and usage tutorials
- Contribution guidelines and code of conduct

For installation instructions, see the [Getting Started](getting-started.md) guide.

For a complete list of features and usage examples, check out the [README](../README.md).

---
