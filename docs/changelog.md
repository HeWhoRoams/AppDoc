# Changelog

All notable changes to AppDoc will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
