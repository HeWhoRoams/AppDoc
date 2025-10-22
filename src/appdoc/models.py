"""Data models for AppDoc analysis results."""

from dataclasses import dataclass, field
from typing import Dict, List, Optional


@dataclass
class FileMetric:
    """Metrics for a single analyzed file."""
    path: str
    language: str
    lines: int
    functions: int = 0
    documented_functions: int = 0
    classes: int = 0
    documented_classes: int = 0
    dependencies: List[str] = field(default_factory=list)
    complexity: Optional[int] = None

    @property
    def documentation_coverage(self) -> float:
        """Calculate documentation coverage percentage."""
        total_items = self.functions + self.classes
        if total_items == 0:
            return 0.0
        documented_items = self.documented_functions + self.documented_classes
        return (documented_items / total_items) * 100


@dataclass
class LanguageSummary:
    """Aggregated metrics for a programming language."""
    language: str
    files: int = 0
    lines: int = 0
    functions: int = 0
    documented_functions: int = 0
    classes: int = 0
    documented_classes: int = 0

    @property
    def documentation_coverage(self) -> float:
        """Calculate documentation coverage percentage for the language."""
        total_items = self.functions + self.classes
        if total_items == 0:
            return 0.0
        documented_items = self.documented_functions + self.documented_classes
        return (documented_items / total_items) * 100


@dataclass
class ScanResult:
    """Results of a complete scan operation."""
    total_files: int
    total_lines: int
    language_summaries: Dict[str, LanguageSummary]
    file_metrics: List[FileMetric]
    duration_seconds: float
    scan_path: str
    timestamp: str

    @property
    def total_functions(self) -> int:
        """Total functions across all languages."""
        return sum(summary.functions for summary in self.language_summaries.values())

    @property
    def total_documented_functions(self) -> int:
        """Total documented functions across all languages."""
        return sum(summary.documented_functions for summary in self.language_summaries.values())

    @property
    def total_classes(self) -> int:
        """Total classes across all languages."""
        return sum(summary.classes for summary in self.language_summaries.values())

    @property
    def total_documented_classes(self) -> int:
        """Total documented classes across all languages."""
        return sum(summary.documented_classes for summary in self.language_summaries.values())

    @property
    def overall_coverage(self) -> float:
        """Calculate overall documentation coverage percentage."""
        total_items = self.total_functions + self.total_classes
        if total_items == 0:
            return 0.0
        documented_items = self.total_documented_functions + self.total_documented_classes
        return (documented_items / total_items) * 100
