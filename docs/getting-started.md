***REMOVED*** Getting Started

This guide will get you up and running with AppDoc quickly.

***REMOVED******REMOVED*** Prerequisites

- Python 3.8 or higher
- pip (Python package manager)

***REMOVED******REMOVED*** Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/HeWhoRoams/AppDoc.git
   cd AppDoc
   ```

2. **Set up virtual environment:**
   ```bash
   python -m venv .venv
   ***REMOVED*** On Windows:
   .venv\Scripts\activate
   ***REMOVED*** On Unix/MacOS:
   source .venv/bin/activate
   ```

3. **Install dependencies:**
   ```bash
   pip install -r requirements.txt -r requirements-dev.txt
   ```

***REMOVED******REMOVED*** Your First Analysis

Run a quick analysis on the AppDoc codebase itself:

```bash
python -m appdoc.cli scan --path . --out ./appdoc_output
```

This command will:

- Scan all Python files in the current directory
- Generate a summary report in JSON format (`./appdoc_output/summary.json`)
- Create an interactive HTML report (`./appdoc_output/index.html`)

***REMOVED******REMOVED*** Viewing Results

Open `./appdoc_output/index.html` in your browser to explore:

- **Language Statistics**: Breakdown by programming language
- **File Metrics**: Per-file analysis with documentation coverage
- **Summary Totals**: Overall codebase metrics
- **Dependency Graph**: (Future feature) Interactive visualization of code relationships

***REMOVED******REMOVED*** Understanding the Output Structure

```
appdoc_output/
├── summary.json          ***REMOVED*** Machine-readable summary data
├── index.html           ***REMOVED*** Human-readable report
├── assets/              ***REMOVED*** CSS, JS, and other assets
└── data/                ***REMOVED*** Additional data files (if needed)
```

The JSON summary contains structured data that can be used for:

- CI/CD integrations
- Custom reporting tools
- Trend analysis across commits
- Automated documentation improvement workflows

***REMOVED******REMOVED*** Next Steps

- [Learn about Usage](usage.md) - Detailed command options and configuration
- [Developer Guide](dev-guide.md) - How to extend AppDoc with new analyzers
- [View Architecture](architecture.md) - Understanding the codebase structure
