# AppDoc: Multi-Language Documentation Analysis

AppDoc is a comprehensive tool for analyzing codebases across multiple programming languages to extract documentation coverage, metrics, and dependency insights. It provides both machine-readable JSON reports and human-friendly HTML visualizations.

## Key Features

- **Multi-Language Support**: Out-of-the-box support for Python and JavaScript, with an extensible analyzer framework for adding more languages.
- **Modular Architecture**: Clean plugin system for analyzers with a registry pattern for easy extension.
- **Rich Reporting**: Generate JSON summaries and interactive HTML reports with dependency graphs.
- **CLI-First Design**: Simple command-line interface for integration into CI/CD pipelines.
- **Documentation Automation**: Built with documentation generation in mind, including MkDocs support and GitHub Pages deployment.

## Quick Start

```bash
# Install dependencies
pip install -r requirements.txt -r requirements-dev.txt

# Run analysis on current directory
python -m appdoc.cli scan --path . --out ./report

# View results
open ./report/index.html
```

## What it does

AppDoc scans your codebase and provides metrics on:

- **Documentation Coverage**: Functions, classes, and modules with/without docs
- **Code Metrics**: Lines of code, complexity, dependency relationships
- **Language Breakdown**: Statistics by file type and language
- **Dependency Analysis**: Internal and external dependency graphs

## Architecture

AppDoc uses a modular analyzer system where each language has its own analyzer plugin. The system supports:

- **Python Analyzer**: AST-based parsing for accurate analysis
- **JavaScript Analyzer**: Regex-based analysis with Tree-sitter upgrade path
- **Extensible Registry**: Easy to add new language analyzers
- **Concurrent Processing**: Efficient scanning of large codebases
