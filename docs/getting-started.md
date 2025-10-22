# Getting Started

This guide will get you up and running with AppDoc quickly.

## Prerequisites

- Python 3.8 or higher
- pip (Python package manager)

## Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/HeWhoRoams/AppDoc.git
   cd AppDoc
   ```

2. **Set up virtual environment:**
   ```bash
   python -m venv .venv
   # On Windows:
   .venv\Scripts\activate
   # On Unix/MacOS:
   source .venv/bin/activate
   ```

3. **Install dependencies:**
   ```bash
   pip install -r requirements.txt -r requirements-dev.txt
   ```

## Your First Analysis

Run a quick analysis on the AppDoc codebase itself:

```bash
python -m appdoc.cli scan --path . --out ./appdoc_output
```

This command will:

- Scan all Python files in the current directory
- Generate a summary report in JSON format (`./appdoc_output/summary.json`)
- Create an interactive HTML report (`./appdoc_output/index.html`)

## Viewing Results

Open `./appdoc_output/index.html` in your browser to explore:

- **Language Statistics**: Breakdown by programming language
- **File Metrics**: Per-file analysis with documentation coverage
- **Summary Totals**: Overall codebase metrics
- **Dependency Graph**: (Future feature) Interactive visualization of code relationships

## Understanding the Output Structure

```
appdoc_output/
├── summary.json          # Machine-readable summary data
├── index.html           # Human-readable report
├── assets/              # CSS, JS, and other assets
└── data/                # Additional data files (if needed)
```

The JSON summary contains structured data that can be used for:

- CI/CD integrations
- Custom reporting tools
- Trend analysis across commits
- Automated documentation improvement workflows

## Next Steps

- [Learn about Usage](usage.md) - Detailed command options and configuration
- [Developer Guide](dev-guide.md) - How to extend AppDoc with new analyzers
- [View Architecture](architecture.md) - Understanding the codebase structure
