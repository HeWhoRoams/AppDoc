***REMOVED*** Developer Guide

This guide covers extending AppDoc with new analyzers, customizing output, and contributing to the codebase.

***REMOVED******REMOVED*** Modifying the Codebase

***REMOVED******REMOVED******REMOVED*** Code Style

AppDoc follows these conventions:

- **Python**: Black code formatting, isort import sorting, flake8 linting
- **Documentation**: Google docstring format in Python
- **Commits**: Conventional commits format

***REMOVED******REMOVED******REMOVED*** Development Setup

After cloning:

```bash
***REMOVED*** Set up pre-commit hooks
pre-commit install

***REMOVED*** Run tests (when available)
***REMOVED*** TBD

***REMOVED*** Build docs locally
mkdocs serve
```

***REMOVED******REMOVED*** Adding a New Language Analyzer

The analyzer system is modular and extensible. Each language analyzer implements a common interface.

***REMOVED******REMOVED******REMOVED*** 1. Create Analyzer Class

Create a new file in `src/appdoc/analyzers/`:

```python
from appdoc.analyzers.base import BaseAnalyzer
from appdoc.models import FileMetric

class MyLanguageAnalyzer(BaseAnalyzer):
    """Analyzer for MyLanguage files."""

    file_extensions = {'.mylang', '.ml'}
    language_name = 'mylang'

    def analyze_file(self, file_path: Path) -> FileMetric:
        """Analyze a single file and return metrics."""
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()

        ***REMOVED*** Your analysis logic here
        lines = len(content.splitlines())
        functions = count_functions(content)
        ***REMOVED*** ... more metrics

        return FileMetric(
            path=str(file_path),
            language=self.language_name,
            lines=lines,
            functions=functions,
            ***REMOVED*** ... other fields
        )
```

***REMOVED******REMOVED******REMOVED*** 2. Register Analyzer

Add your analyzer to `src/appdoc/analyzers/registry.py`:

```python
from .my_language import MyLanguageAnalyzer

***REMOVED*** Add to ANALYZER_REGISTRY
ANALYZER_REGISTRY['mylang'] = MyLanguageAnalyzer
```

***REMOVED******REMOVED******REMOVED*** 3. Update File Extensions

Add new extensions to the global registry in `__init__.py`:

```python
EXTENSION_TO_LANGUAGE = {
    ***REMOVED*** ... existing mappings
    '.mylang': 'mylang',
    '.ml': 'mylang',
}
```

***REMOVED******REMOVED*** Customizing HTML Report

***REMOVED******REMOVED******REMOVED*** Modifying Templates

The HTML report uses Jinja2 templates in `src/appdoc/templates/`. Key templates:

- `index.html.jinja`: Main report page
- `file_detail.html.jinja`: Individual file details
- `language_summary.html.jinja`: Language breakdowns

Update these with additional metrics or styling.

***REMOVED******REMOVED******REMOVED*** Adding New Metrics

1. Add fields to `FileMetric` dataclass in `models.py`
2. Update all analyzers to populate the new fields
3. Modify templates to display the new data
4. Update JSON summary structure

***REMOVED******REMOVED*** Enhancing CLI

***REMOVED******REMOVED******REMOVED*** Adding Command Options

Extend `src/appdoc/cli/main.py`:

```python
@click.option('--new-option', help='Description of new option')
def scan(path, out, new_option=None):
    ***REMOVED*** Update scanning logic
    pass
```

***REMOVED******REMOVED******REMOVED*** Adding Subcommands

For major features, add subcommands:

```python
@cli.group()
def analyze():
    """Advanced analysis commands."""
    pass

@analyze.command()
def complexity():
    """Analyze code complexity."""
    click.echo("Running complexity analysis...")
```

***REMOVED******REMOVED*** Testing

Currently testing framework is under development. For now:

- Manual testing with known codebases
- Validate output formats match expectations
- Check edge cases and error handling

Future: pytest-based unit and integration tests.

***REMOVED******REMOVED*** Contributing

1. Fork the repository
2. Create a feature branch
3. Make changes with tests
4. Ensure docs are updated
5. Submit pull request

***REMOVED******REMOVED******REMOVED*** Pull Request Checklist

- [ ] Pre-commit hooks pass
- [ ] Documentation updated
- [ ] No breaking changes without discussion
- [ ] New analyzers include example usage
