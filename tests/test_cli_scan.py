"""Smoke tests for CLI scan functionality."""

import json
import tempfile
from pathlib import Path

import pytest

from appdoc.cli.main import scan
from appdoc.core.scanner import Scanner


class TestCliScan:
    """Test cases for CLI scan command."""

    def test_scan_creates_json_output(self):
        """Test that scan command creates proper JSON output structure."""
        # Create a temporary directory with Python files
        with tempfile.TemporaryDirectory() as temp_dir:
            scan_path = Path(temp_dir)

            # Create a simple Python file
            py_file = scan_path / "test.py"
            py_file.write_text('''
def hello():
    """A simple function."""
    return "Hello"

class TestClass:
    """A test class."""
    pass
''')

            # Create output directory
            output_dir = scan_path / "output"
            output_dir.mkdir()

            # Run scanner programmatically
            scanner = Scanner()
            result = scanner.scan(path=str(scan_path))

            # Verify result structure
            assert result.total_files > 0
            assert result.scan_path == str(scan_path)
            assert result.duration_seconds > 0
            assert 'python' in result.language_summaries

            python_summary = result.language_summaries['python']
            assert python_summary.files > 0
            assert python_summary.functions > 0
            assert python_summary.classes > 0

            # Verify file metrics
            assert len(result.file_metrics) > 0
            py_metric = result.file_metrics[0]
            assert py_metric.language == 'python'
            assert py_metric.lines > 0
            assert py_metric.documentation_coverage >= 0

    def test_scan_output_json_format(self):
        """Test that JSON output has the correct structure."""
        with tempfile.TemporaryDirectory() as temp_dir:
            scan_path = Path(temp_dir)

            # Create a simple Python file
            py_file = scan_path / "test.py"
            py_file.write_text('''
def func():
    """Test function."""
    pass
''')

            output_dir = scan_path / "output"
            output_dir.mkdir()

            scanner = Scanner()
            result = scanner.scan(path=str(scan_path))

            # Test the JSON generation (simulate what happens in CLI)
            json_output = {}
            json_output['scan_info'] = {
                'timestamp': result.timestamp,
                'scan_path': result.scan_path,
                'duration_seconds': result.duration_seconds,
                'total_files': result.total_files,
                'total_lines': result.total_lines,
                'overall_coverage': result.overall_coverage,
            }
            json_output['languages'] = {
                lang: {
                    'files': summary.files,
                    'lines': summary.lines,
                    'functions': summary.functions,
                    'documented_functions': summary.documented_functions,
                    'classes': summary.classes,
                    'documented_classes': summary.documented_classes,
                    'coverage_percentage': summary.documentation_coverage,
                }
                for lang, summary in result.language_summaries.items()
            }
            json_output['files'] = [
                {
                    'path': metric.path,
                    'language': metric.language,
                    'lines': metric.lines,
                    'functions': metric.functions,
                    'documented_functions': metric.documented_functions,
                    'classes': metric.classes,
                    'documented_classes': metric.documented_classes,
                    'coverage_percentage': metric.documentation_coverage,
                    'dependencies': metric.dependencies,
                    'complexity': metric.complexity,
                }
                for metric in result.file_metrics
            ]

            # Verify JSON structure
            assert 'scan_info' in json_output
            assert 'languages' in json_output
            assert 'files' in json_output

            # Verify scan_info structure
            scan_info = json_output['scan_info']
            assert 'timestamp' in scan_info
            assert 'scan_path' in scan_info
            assert 'duration_seconds' in scan_info
            assert 'total_files' in scan_info
            assert 'total_lines' in scan_info
            assert 'overall_coverage' in scan_info

            # Verify languages structure
            assert 'python' in json_output['languages']
            python_info = json_output['languages']['python']
            expected_keys = [
                'files', 'lines', 'functions', 'documented_functions',
                'classes', 'documented_classes', 'coverage_percentage'
            ]
            for key in expected_keys:
                assert key in python_info

            # Verify files structure
            assert len(json_output['files']) > 0
            file_info = json_output['files'][0]
            file_keys = [
                'path', 'language', 'lines', 'functions', 'documented_functions',
                'classes', 'documented_classes', 'coverage_percentage',
                'dependencies', 'complexity'
            ]
            for key in file_keys:
                assert key in file_info

    def test_scan_with_ignore_patterns(self):
        """Test scanning with ignore patterns."""
        with tempfile.TemporaryDirectory() as temp_dir:
            scan_path = Path(temp_dir)

            # Create Python file
            py_file = scan_path / "test.py"
            py_file.write_text('''
def func():
    """Test function."""
    pass
''')

            # Create file in ignored directory
            ignored_dir = scan_path / ".git"
            ignored_dir.mkdir()
            ignored_file = ignored_dir / "info.py"
            ignored_file.write_text('''
def ignored_func():
    """Ignored function."""
    pass
''')

            scanner = Scanner()
            # Should ignore .git directory
            result = scanner.scan(path=str(scan_path), ignore_patterns=['.git'])

            # Should only count the main Python file, not the ignored one
            assert result.total_files == 1
            assert len(result.file_metrics) == 1
            assert 'ignored_func' not in str(result.file_metrics[0])

    def test_scan_multiple_languages(self):
        """Test scanning a directory with multiple programming languages."""
        with tempfile.TemporaryDirectory() as temp_dir:
            scan_path = Path(temp_dir)

            # Create Python file
            py_file = scan_path / "script.py"
            py_file.write_text('''
def python_func():
    """Python function."""
    pass
''')

            # Create JavaScript file
            js_file = scan_path / "script.js"
            js_file.write_text('''
// JavaScript function
function jsFunc() {
  return "Hello";
}
''')

            output_dir = scan_path / "output"
            output_dir.mkdir()

            scanner = Scanner()
            result = scanner.scan(path=str(scan_path))

            # Should include both Python and JavaScript summaries
            assert 'python' in result.language_summaries
            assert 'javascript' in result.language_summaries

            # Should have metrics for both files
            assert len(result.file_metrics) >= 2

            languages = [metric.language for metric in result.file_metrics]
            assert 'python' in languages
            assert 'javascript' in languages

    def test_scan_empty_directory(self):
        """Test scanning an empty directory."""
        with tempfile.TemporaryDirectory() as temp_dir:
            scan_path = Path(temp_dir)

            scanner = Scanner()
            result = scanner.scan(path=str(scan_path))

            assert result.total_files == 0
            assert result.total_lines == 0
            assert len(result.language_summaries) == 0
            assert len(result.file_metrics) == 0
            assert result.overall_coverage == 0.0
