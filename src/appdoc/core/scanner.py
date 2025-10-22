"""Core scanning functionality for analyzing codebases."""

import time
import os
from pathlib import Path
from typing import Dict, List, Optional, Set
from concurrent.futures import ThreadPoolExecutor, as_completed

from ..analyzers import (
    EXTENSION_TO_LANGUAGE,
    PythonAnalyzer,
    JavaScriptAnalyzer,
    BaseAnalyzer
)
from ..models import (
    FileMetric,
    LanguageSummary,
    ScanResult
)
from ..reporting import generate_reports


class Scanner:
    """Main scanner class that coordinates codebase analysis."""

    def __init__(self, max_files: Optional[int] = None, threads: Optional[int] = None):
        """Initialize the scanner.

        Args:
            max_files: Maximum number of files to process (None for unlimited)
            threads: Number of threads to use (default: CPU count)
        """
        self.max_files = max_files
        self.threads = threads or os.cpu_count()

        # Initialize analyzers
        self.analyzers: Dict[str, BaseAnalyzer] = {
            'python': PythonAnalyzer(),
            'javascript': JavaScriptAnalyzer(),
        }

        self.analyzer_instances = list(self.analyzers.values())

    def scan(self, path: str, ignore_patterns: Optional[List[str]] = None,
             languages: Optional[List[str]] = None) -> ScanResult:
        """Scan a directory and generate analysis results.

        Args:
            path: Directory path to scan
            ignore_patterns: Glob patterns to ignore
            languages: Specific languages to analyze (None for all)

        Returns:
            ScanResult with analysis data
        """
        start_time = time.time()

        scan_path = Path(path).resolve()
        if not scan_path.is_dir():
            raise ValueError(f"Path {path} is not a directory")

        # Filter analyzers by language if specified
        analyzers_to_use = self.analyzer_instances
        if languages:
            analyzers_to_use = [
                analyzer for analyzer in self.analyzer_instances
                if analyzer.language_name in languages
            ]

        # Discover files to analyze
        files_to_analyze = self._discover_files(
            scan_path, analyzers_to_use, ignore_patterns
        )

        # Limit files if specified
        if self.max_files and len(files_to_analyze) > self.max_files:
            files_to_analyze = files_to_analyze[:self.max_files]

        # Analyze files concurrently
        file_metrics = self._analyze_files_concurrently(files_to_analyze)

        # Aggregate results
        language_summaries = self._aggregate_results(file_metrics)

        # Calculate totals
        total_files = len(file_metrics)
        total_lines = sum(metric.lines for metric in file_metrics)

        duration = time.time() - start_time

        return ScanResult(
            total_files=total_files,
            total_lines=total_lines,
            language_summaries=language_summaries,
            file_metrics=file_metrics,
            duration_seconds=duration,
            scan_path=str(scan_path),
            timestamp=time.strftime('%Y-%m-%d %H:%M:%S'),
        )

    def _discover_files(self, root_path: Path, analyzers: List[BaseAnalyzer],
                       ignore_patterns: Optional[List[str]] = None) -> List[Path]:
        """Discover all files that can be analyzed."""
        files = []

        ignore_set = set(ignore_patterns or [])

        for analyzer in analyzers:
            for ext in analyzer.file_extensions:
                # Find all files with this extension
                files.extend(root_path.rglob(f'*{ext}'))

        # Remove duplicates
        files = list(set(files))

        # Apply ignore patterns
        filtered_files = []
        for file_path in files:
            # Convert to relative path for pattern matching
            rel_path = file_path.relative_to(root_path)

            # Check if file should be ignored
            should_ignore = False
            for ignore_pattern in ignore_set:
                if self._matches_pattern(str(rel_path), ignore_pattern):
                    should_ignore = True
                    break

            if not should_ignore:
                filtered_files.append(file_path)

        return filtered_files

    def _matches_pattern(self, path_str: str, pattern: str) -> bool:
        """Check if a path matches an ignore pattern."""
        from fnmatch import fnmatch

        # Handle directory patterns ending with /
        if pattern.endswith('/'):
            return Path(path_str).is_relative_to(pattern.rstrip('/'))

        # Handle glob patterns
        return fnmatch(path_str, pattern) or fnmatch(str(Path(path_str).parent), pattern)

    def _analyze_files_concurrently(self, file_paths: List[Path]) -> List[FileMetric]:
        """Analyze files using thread pool."""
        results = []

        with ThreadPoolExecutor(max_workers=self.threads) as executor:
            # Submit all analysis tasks
            future_to_file = {
                executor.submit(self._analyze_single_file, file_path): file_path
                for file_path in file_paths
            }

            # Collect results as they complete
            for future in as_completed(future_to_file):
                file_path = future_to_file[future]
                try:
                    metric = future.result()
                    results.append(metric)
                except Exception as exc:
                    # Log error and continue with partial results
                    print(f"Error analyzing {file_path}: {exc}")
                    # Add a basic metric to maintain consistency
                    results.append(FileMetric(
                        path=str(file_path),
                        language="unknown",
                        lines=0,
                    ))

        return results

    def _analyze_single_file(self, file_path: Path) -> FileMetric:
        """Analyze a single file using the appropriate analyzer."""
        # Find the right analyzer
        analyzer = None
        for candidate in self.analyzer_instances:
            if candidate.can_analyze(file_path):
                analyzer = candidate
                break

        if analyzer:
            return analyzer.analyze_file(file_path)
        else:
            # Fallback: count lines only
            lines = 0
            try:
                with open(file_path, 'r', encoding='utf-8') as f:
                    lines = len(f.read().splitlines())
            except:
                pass

            return FileMetric(
                path=str(file_path),
                language="unknown",
                lines=lines,
            )

    def _aggregate_results(self, file_metrics: List[FileMetric]) -> Dict[str, LanguageSummary]:
        """Aggregate file metrics into language summaries."""
        language_data: Dict[str, Dict] = {}

        for metric in file_metrics:
            lang = metric.language

            if lang not in language_data:
                language_data[lang] = {
                    'files': 0,
                    'lines': 0,
                    'functions': 0,
                    'documented_functions': 0,
                    'classes': 0,
                    'documented_classes': 0,
                }

            language_data[lang]['files'] += 1
            language_data[lang]['lines'] += metric.lines
            language_data[lang]['functions'] += metric.functions
            language_data[lang]['documented_functions'] += metric.documented_functions
            language_data[lang]['classes'] += metric.classes
            language_data[lang]['documented_classes'] += metric.documented_classes

        # Convert to LanguageSummary objects
        return {
            lang: LanguageSummary(language=lang, **data)
            for lang, data in language_data.items()
        }
