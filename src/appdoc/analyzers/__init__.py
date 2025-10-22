"""Language analyzers for AppDoc."""

from abc import ABC, abstractmethod
from typing import ClassVar, Set
from pathlib import Path

class BaseAnalyzer(ABC):
    """Abstract base class for language analyzers."""

    file_extensions: ClassVar[Set[str]]
    language_name: ClassVar[str]

    @abstractmethod
    def analyze_file(self, file_path: Path) -> 'FileMetric':
        """Analyze a single file and return metrics."""
        pass

    def can_analyze(self, file_path: Path) -> bool:
        """Check if this analyzer can handle the file."""
        return file_path.suffix in self.file_extensions

# Import analyzers for registry
from .python_analyzer import PythonAnalyzer
from .javascript_analyzer import JavaScriptAnalyzer

# Language extension mapping
EXTENSION_TO_LANGUAGE = {
    '.py': 'python',
    '.js': 'javascript',
    '.mjs': 'javascript',
    '.ts': 'javascript',  # Will be upgraded to TypeScript analyzer
}

__all__ = [
    'BaseAnalyzer',
    'PythonAnalyzer',
    'JavaScriptAnalyzer',
    'EXTENSION_TO_LANGUAGE',
]
