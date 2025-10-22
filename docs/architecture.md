***REMOVED*** Architecture Overview

This document describes the high-level architecture and design decisions of AppDoc.

***REMOVED******REMOVED*** Core Components

```
appdoc/
├── cli/           ***REMOVED*** Command-line interface
├── analyzers/     ***REMOVED*** Language-specific analyzers
├── models/        ***REMOVED*** Data models and types
├── reporting/     ***REMOVED*** Report generation and templates
└── core/          ***REMOVED*** Core scanning and coordination logic
```

***REMOVED******REMOVED*** Design Principles

***REMOVED******REMOVED******REMOVED*** Modularity
- **Plugin Architecture**: Analyzers implement a common interface and are registered dynamically
- **Separation of Concerns**: CLI, analysis, and reporting are distinct layers
- **Extensibility**: Easy to add new languages, metrics, or output formats

***REMOVED******REMOVED******REMOVED*** Performance
- **Concurrent Processing**: Use threading for parallel file analysis
- **Incremental Analysis**: Support for caching and selective scanning
- **Memory Efficiency**: Stream processing for large files/directories

***REMOVED******REMOVED******REMOVED*** Reliability
- **Graceful Degradation**: Continue analysis even if some files fail
- **Progress Tracking**: Real-time feedback during long operations
- **Error Recovery**: Clear error messages and recovery suggestions

***REMOVED******REMOVED*** Data Flow

1. **CLI Entry**: Parse arguments and setup configuration
2. **File Discovery**: Recursively find files matching language extensions
3. **Filtering**: Apply ignore patterns and file limits
4. **Concurrent Analysis**: Distribute work across thread pool
5. **Aggregation**: Collect and summarize metrics
6. **Report Generation**: Render templates with collected data

***REMOVED******REMOVED*** Analyzer Interface

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

***REMOVED******REMOVED*** Key Data Models

***REMOVED******REMOVED******REMOVED*** FileMetric
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
    ***REMOVED*** ... additional metrics
```

***REMOVED******REMOVED******REMOVED*** LanguageSummary
Aggregated metrics for a programming language:

```python
@dataclass
class LanguageSummary:
    language: str
    files: int
    lines: int
    functions: int
    documented_functions: int
    ***REMOVED*** ... aggregates
    coverage_percentage: float
```

***REMOVED******REMOVED******REMOVED*** ScanResult
Top-level summary of entire analysis:

```python
@dataclass
class ScanResult:
    total_files: int
    total_lines: int
    language_summaries: Dict[str, LanguageSummary]
    file_metrics: List[FileMetric]
    duration_seconds: float
    ***REMOVED*** ... metadata
```

***REMOVED******REMOVED*** Extensibility Points

***REMOVED******REMOVED******REMOVED*** New Analyzers
- Implement `BaseAnalyzer` interface
- Register in analyzer registry
- Add file extension mappings

***REMOVED******REMOVED******REMOVED*** New Metrics
- Extend `FileMetric` dataclass
- Update all analyzers to populate new fields
- Modify reporting templates

***REMOVED******REMOVED******REMOVED*** New Output Formats
- Implement renderer class with `render(result: ScanResult) -> bytes` method
- Register in output registry
- Add CLI options for format selection

***REMOVED******REMOVED*** Future Extensions

- **Tree-sitter Integration**: Upgrade regex-based analyzers to AST parsing
- **Dependency Graph Analysis**: NetworkX-powered visualization
- **Historical Trending**: Store and compare metrics across commits
- **CI/CD Integration**: Webhooks, badges, and automated PR commenting
- **Configuration Files**: Support for project-specific analyzer settings
