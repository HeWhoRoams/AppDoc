# Demo Project

Welcome to the AppDoc demo! This page walks you through analyzing a sample codebase to see AppDoc in action.

## Overview

The demo project is a simple multi-language application that demonstrates common documentation practices across different programming languages. It includes:

- Python web service
- JavaScript/React frontend components
- TypeScript utilities
- C# business logic

## Running the Demo

```bash
# Run AppDoc on the demo project (from the repository root)
appdoc scan docs/assets/demo demo_results

# Open the generated report
open demo_results/index.html
```

## Expected Output

After running the scan, AppDoc will generate:

1. **Documentation Coverage Report**: Shows which parts of the code have documentation
2. **Function Analysis**: Lists all functions and their documentation status
3. **Language Statistics**: Breakdown by programming language
4. **Interactive HTML Report**: Browseable web interface with all results

## Demo Project Structure

```
demo/
├── python/
│   ├── app.py          # Flask web service
│   ├── utils.py        # Helper functions
│   └── models.py       # Data models
├── javascript/
│   ├── components/
│   │   ├── Button.jsx
│   │   └── Modal.jsx
│   └── utils.js
├── typescript/
│   ├── types.ts        # Type definitions
│   └── helpers.ts      # Utility functions
└── csharp/
    ├── Models.cs       # Entity models
    └── Services.cs     # Business logic
```

## Try It Yourself

1. Clone this repository
2. Install AppDoc: `pip install .`
3. Run: `appdoc scan docs/assets/demo demo_results`
4. Open `demo_results/index.html` in your browser

The demo showcases how AppDoc can help you:

- **Identify documentation gaps**: See which functions need docstrings
- **Track coverage metrics**: Monitor documentation completeness
- **Analyze multi-language projects**: Get unified reports across languages
- **Improve code quality**: Use insights to enhance documentation practices

## Sample Report Preview

The HTML report includes:

- **Overview Dashboard**: Summary statistics and charts
- **File-by-File Breakdown**: Detailed analysis of each source file
- **Function Listings**: All functions with documentation status
- **Trend Analysis**: Coverage improvements over time

Check out the [sample JSON output](assets/sample-summary.json) for an example of the raw analysis data.

!!! tip "Pro Tip"
    Use `appdoc init` to create configuration files for complex projects, or run `appdoc docs` to view detailed usage documentation.
