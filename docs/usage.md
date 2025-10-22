# Usage Guide

This guide covers the command-line interface and configuration options for AppDoc.

## Command Overview

```bash
python -m appdoc.cli scan [OPTIONS]

Required:
  --path PATH    Directory path to scan (use . for current directory)
  --out PATH     Output directory for reports

Optional:
  --max-files N  Maximum number of files to process (default: unlimited)
  --threads N    Number of concurrent threads (default: CPU count)
  --languages L  Comma-separated list of languages to analyze (default: all)
  --ignore PAT   Glob patterns to ignore (can be used multiple times)
  --verbose      Enable verbose output
  --help         Show help message
```

## Basic Usage Examples

### Scan current directory
```bash
python -m appdoc.cli scan --path . --out ./report
```

### Scan a specific project
```bash
python -m appdoc.cli scan --path ../my-project --out ./analysis
```

### Limit analysis scope
```bash
# Only process 100 files
python -m appdoc.cli scan --path . --out ./report --max-files 100

# Use 4 concurrent threads
python -m appdoc.cli scan --path . --out ./report --threads 4
```

### Language-specific analysis
```bash
# Only analyze Python files
python -m appdoc.cli scan --path . --out ./report --languages python

# Multiple languages
python -m appdoc.cli scan --path . --out ./report --languages python,javascript
```

### Exclude directories
```bash
# Ignore test files and node_modules
python -m appdoc.cli scan --path . --out ./report --ignore "tests/*" --ignore "node_modules/**"
```

## Configuration

AppDoc supports configuration through environment variables or a config file (future feature).

Currently supported environment variables:

- `APPDOC_MAX_FILES`: Default maximum files to process
- `APPDOC_THREADS`: Default number of threads
- `APPDOC_DEFAULT_LANGUAGES`: Comma-separated default languages

## Reports and Output

### JSON Summary (`summary.json`)

The machine-readable summary contains:

```json
{
  "total_files": 150,
  "total_lines": 12543,
  "languages": {
    "python": {
      "files": 45,
      "lines": 8123,
      "documented_functions": 234,
      "total_functions": 345
    },
    "javascript": {
      "files": 23,
      "lines": 2204,
      "documented_functions": 67,
      "total_functions": 89
    }
  },
  "files": [
    {
      "path": "src/main.py",
      "language": "python",
      "lines": 234,
      "functions": 12,
      "documented_functions": 10,
      "classes": 3,
      "documented_classes": 2
    }
  ]
}
```

### HTML Report (`index.html`)

The human-readable report includes:

- **Overview Dashboard**: Summary statistics and charts
- **Language Breakdown**: Detailed metrics by programming language
- **File Listing**: Individual file analysis with coverage percentages
- **Interactive Elements**: Expandable sections and filtering

## Integration with CI/CD

### GitHub Actions Example

```yaml
- name: Analyze codebase
  run: python -m appdoc.cli scan --path . --out ./appdoc-report

- name: Upload report
  uses: actions/upload-artifact@v3
  with:
    name: appdoc-report
    path: ./appdoc-report/
```

### Pre-commit Hook

Add to `.pre-commit-config.yaml`:

```yaml
repos:
  - repo: local
    hooks:
      - id: appdoc-scan
        name: AppDoc scan
        entry: python -m appdoc.cli scan
        language: system
        pass_filenames: false
        args: [--path, ., --out, ./appdoc-report]
```

## Exit Codes

- `0`: Success
- `1`: Command-line error
- `2`: Analysis error
- `3`: Output error

## Troubleshooting

### Common Issues

**No files found to analyze:**
- Check if `--path` points to a directory containing code files
- Verify supported file extensions are present (`.py`, `.js`, `.ts`, etc.)

**Permission denied:**
- Ensure read permissions on the target directory
- On Windows, you may need to run as Administrator for some directories

**Empty reports:**
- Check for excluded files (use `--verbose` to see what's being processed)
- Verify analyzer configurations are correct
