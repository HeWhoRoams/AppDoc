# AppDoc

[![Documentation Status](https://img.shields.io/badge/docs-MkDocs-blue)](https://HeWhoRoams.github.io/AppDoc/)
[![CI](https://img.shields.io/github/actions/workflow/status/HeWhoRoams/AppDoc/build-docs.yml)](https://github.com/HeWhoRoams/AppDoc/actions)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)

AppDoc is a multi-language code documentation analysis tool that scans codebases to extract documentation coverage, metrics, and dependency insights. It provides both machine-readable JSON reports and interactive HTML visualizations.

## ✨ Key Features

- **🔍 Multi-Language Support**: Out-of-the-box support for Python (AST-based) and JavaScript/TypeScript (regex-based)
- **🧩 Modular Architecture**: Plugin system for easy addition of new programming languages
- **📊 Rich Reporting**: JSON summaries + responsive HTML reports with Chart.js visualizations
- **⚡ Concurrent Processing**: Fast analysis using Python's ThreadPoolExecutor
- **🎯 Documentation Focus**: Specialized in measuring documentation coverage and gaps
- **🔧 CLI-First Design**: Simple command-line interface for CI/CD integration

## 🛠️ Supported Languages

### Currently Supported
- **Python** (AST-based analysis, full docstring extraction and coverage)
- **JavaScript/TypeScript** (Regex-based JSDoc/TSDoc extraction)

### Planned Languages
See our [roadmap](ROADMAP.md) for upcoming language support including Go, Rust, Java, C#, Ruby, and more.

### Adding New Languages
Adding support for a new language is straightforward - see the [Developer Guide](docs/dev-guide.md) for instructions.

## 🚀 Quick Start

### System Requirements
- **Python**: 3.8 or higher
- **OS**: Linux, macOS, Windows
- **Dependencies**: See [requirements.txt](requirements.txt)

### Installation & Usage

```bash
# Install dependencies
pip install -r requirements.txt -r requirements-dev.txt

# Analyze a codebase
python -m appdoc.cli scan --path . --out ./report

# View results in browser
open ./report/index.html
```

## 📈 What It Measures

- **Documentation Coverage**: Functions/classes with/without docstrings or JSDoc comments
- **Code Metrics**: Lines of code, function counts, class counts per file
- **Language Breakdown**: Statistics segmented by programming language
- **Dependency Analysis**: Import/export relationships (expandable with NetworkX)

## 🏗️ Architecture

```
appdoc/
├── cli/           # Command-line interface with Rich console output
├── analyzers/     # Language-specific analyzers (Python AST, JS regex)
├── core/          # Concurrent scanning and coordination logic
├── models/        # Data classes for metrics and results
├── reporting/     # Jinja2 HTML reports + JSON summaries
└── templates/     # HTML report templates with Chart.js
```

## 📚 Documentation

Full documentation is available at [https://HeWhoRoams.github.io/AppDoc/](https://HeWhoRoams.github.io/AppDoc/)

- [Getting Started](docs/getting-started.md) - Installation and first analysis
- [Usage Guide](docs/usage.md) - CLI options and configuration
- [Developer Guide](docs/dev-guide.md) - Adding new language analyzers
- [Architecture](docs/architecture.md) - System design and extensibility

## 🔌 Adding New Languages

Adding support for a new language (e.g., Go, Rust, C#) is straightforward:

1. **Create an analyzer** in `src/appdoc/analyzers/newlang_analyzer.py`
2. **Implement the interface**:
   ```python
   from .base import BaseAnalyzer

   class NewLangAnalyzer(BaseAnalyzer):
       file_extensions = {'.nl'}
       language_name = 'newlang'
   ```
3. **Register** in `src/appdoc/analyzers/__init__.py`
4. **Add extension mapping** to `EXTENSION_TO_LANGUAGE`

## 📊 Sample Output

**HTML Report Features:**
- Interactive charts showing language distribution
- Documentation coverage visualization
- Per-file breakdown with coverage percentages
- Responsive design with mobile support

**JSON Summary:**
```json
{
  "scan_info": {
    "total_files": 42,
    "total_lines": 3456,
    "overall_coverage": 67.8
  },
  "languages": {
    "python": {"files": 23, "coverage_percentage": 85.2},
    "javascript": {"files": 19, "coverage_percentage": 45.1}
  }
}
```

## 🛠️ Development

```bash
# Set up pre-commit hooks
pre-commit install

# Run documentation locally
mkdocs serve

# Format code
black src/ && isort src/
```

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for detailed information on:

- Development workflow and coding standards
- Adding new language analyzers
- Testing and documentation guidelines
- Conventional commit messages

### Quick Links
- [Contributing Guidelines](CONTRIBUTING.md)
- [Code of Conduct](CODE_OF_CONDUCT.md)
- [Roadmap](ROADMAP.md)
- [Issue Tracker](https://github.com/HeWhoRoams/AppDoc/issues)
- [Discussions](https://github.com/HeWhoRoams/AppDoc/discussions)

## 🆘 Getting Help

- **Documentation**: Full docs at [https://HeWhoRoams.github.io/AppDoc/](https://HeWhoRoams.github.io/AppDoc/)
- **Questions**: Use [GitHub Discussions](https://github.com/HeWhoRoams/AppDoc/discussions) for questions
- **Issues**: Report bugs via [GitHub Issues](https://github.com/HeWhoRoams/AppDoc/issues)
- **Community**: Follow along with the [ROADMAP.md](ROADMAP.md) for upcoming features

## 📄 License

MIT License - see [LICENSE](LICENSE) file for details.

---
**AppDoc** - Understanding what your codebase actually documents. 🚀
