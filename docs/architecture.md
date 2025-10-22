# Architecture Overview

This document describes the high-level architecture and design decisions of AppDoc.

## Core Components

```
appdoc/
├── cli/           # Command-line interface
├── analyzers/     # Language-specific analyzers
├── models/        # Data models and types
├── reporting/     # Report generation and templates
└── core/          # Core scanning and coordination logic
```

## Design Principles

### Modularity
- **Plugin Architecture**: Analyzers implement a common interface and are registered dynamically
- **Separation of Concerns**: CLI, analysis, and reporting are distinct layers
- **Extensibility**: Easy to add new languages, metrics, or output formats

### Performance
- **Concurrent Processing**: Use threading for parallel file analysis
- **Incremental Analysis**: Support for caching and selective scanning
- **Memory Efficiency**: Stream processing for large files/directories

### Reliability
- **Graceful Degradation**: Continue analysis even if some files fail
- **Progress Tracking**: Real-time feedback during long operations
- **Error Recovery**: Clear error messages and recovery suggestions

## Data Flow

1. **CLI Entry**: Parse arguments and setup configuration
2. **File Discovery**: Recursively find files matching language extensions
3. **Filtering**: Apply ignore patterns and file limits
4. **Concurrent Analysis**: Distribute work across thread pool
5. **Aggregation**: Collect and summarize metrics
6. **Report Generation**: Render templates with collected data

## Analyzer Interface

All analyzers implement this common interface:

```python
class BaseAnalyzer(ABC):
    """Abstract base class for language analyzers."""

    file_extensions: ClassVar[Set[str]]
    language_name: ClassVar[str]

    @abstractmethod
    def analyze_file(self, file_path: Path) -> FileMetric:
        """Analyze a single file and return metrics."""
        pass

    def can_analyze(self, file_path: Path) -> bool:
        """Check if this analyzer can handle the file."""
        return file_path.suffix in self.file_extensions
```

## Key Data Models

### FileMetric
Represents analysis results for a single file:

```python
@dataclass
class FileMetric:
    path: str
    language: str
    lines: int
    functions: int
    documented_functions: int
    classes: int
    documented_classes: int
    dependencies: List[str] = field(default_factory=list)
    complexity: Optional[int] = None
    # ... additional metrics
```

### LanguageSummary
Aggregated metrics for a programming language:

```python
@dataclass
class LanguageSummary:
    language: str
    files: int
    lines: int
    functions: int
    documented_functions: int
    # ... aggregates
    coverage_percentage: float
```

### ScanResult
Top-level summary of entire analysis:

```python
@dataclass
class ScanResult:
    total_files: int
    total_lines: int
    language_summaries: Dict[str, LanguageSummary]
    file_metrics: List[FileMetric]
    duration_seconds: float
    # ... metadata
```

## Extensibility Points

### New Analyzers
- Implement `BaseAnalyzer` interface
- Register in analyzer registry
- Add file extension mappings

### New Metrics
- Extend `FileMetric` dataclass
- Update all analyzers to populate new fields
- Modify reporting templates

### New Output Formats
- Implement renderer class with `render(result: ScanResult) -> bytes` method
- Register in output registry
- Add CLI options for format selection

## Future Extensions

- **Tree-sitter Integration**: Upgrade regex-based analyzers to AST parsing
- **Dependency Graph Analysis**: NetworkX-powered visualization
- **Historical Trending**: Store and compare metrics across commits
- **CI/CD Integration**: Webhooks, badges, and automated PR commenting
- **Configuration Files**: Support for project-specific analyzer settings
