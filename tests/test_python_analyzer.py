"""Tests for Python analyzer functionality."""

import tempfile
from pathlib import Path

import pytest

from appdoc.analyzers.python_analyzer import PythonAnalyzer


class TestPythonAnalyzer:
    """Test cases for PythonAnalyzer."""

    def test_basic_analysis(self):
        """Test basic analysis of a simple Python file."""
        sample_code = '''
def hello():
    """A simple function with documentation."""
    return "Hello, World!"

class SampleClass:
    """A sample class with documentation."""

    def method(self):
        """A method."""
        pass
'''
        analyzer = PythonAnalyzer()

        with tempfile.NamedTemporaryFile(mode='w', suffix='.py', delete=False) as f:
            f.write(sample_code)
            temp_path = Path(f.name)

        try:
            result = analyzer.analyze_file(temp_path)

            assert result.language == 'python'
            assert result.functions == 2  # hello() and method()
            assert result.classes == 1   # SampleClass
            assert result.lines > 0
            assert result.documentation_coverage > 0
            assert result.documented_functions == 2  # both have docstrings
            assert result.documented_classes == 1    # SampleClass has docstring

        finally:
            temp_path.unlink()

    def test_import_detection(self):
        """Test that imports are correctly detected."""
        sample_code = '''
import os
import sys
from pathlib import Path
from typing import List, Dict

def func():
    pass
'''
        analyzer = PythonAnalyzer()

        with tempfile.NamedTemporaryFile(mode='w', suffix='.py', delete=False) as f:
            f.write(sample_code)
            temp_path = Path(f.name)

        try:
            result = analyzer.analyze_file(temp_path)

            assert 'os' in result.dependencies
            assert 'sys' in result.dependencies
            assert 'pathlib' in result.dependencies
            assert 'typing' in result.dependencies

        finally:
            temp_path.unlink()

    def test_lines_of_code_counting(self):
        """Test that lines of code are correctly counted."""
        sample_code = '''# This is a comment
import os  # inline comment

def func():
    """
    Multi-line docstring.
    """
    pass

# Blank line


class Test:
    pass
'''

        analyzer = PythonAnalyzer()

        with tempfile.NamedTemporaryFile(mode='w', suffix='.py', delete=False) as f:
            f.write(sample_code)
            temp_path = Path(f.name)

        try:
            result = analyzer.analyze_file(temp_path)

            # Should count all lines including comments and blank lines
            assert result.lines == len(sample_code.splitlines())

        finally:
            temp_path.unlink()

    def test_documentation_coverage_calculation(self):
        """Test that documentation coverage is calculated correctly."""
        sample_code = '''
def documented_func():
    """This function is documented."""
    pass

def undocumented_func():
    pass

class DocumentedClass:
    """This class is documented."""
    pass

class UndocumentedClass:
    pass
'''

        analyzer = PythonAnalyzer()

        with tempfile.NamedTemporaryFile(mode='w', suffix='.py', delete=False) as f:
            f.write(sample_code)
            temp_path = Path(f.name)

        try:
            result = analyzer.analyze_file(temp_path)

            # 2 functions, 2 classes = 4 total items
            # 1 documented function, 1 documented class = 2 documented
            expected_coverage = (2 / 4) * 100  # 50%
            assert result.documentation_coverage == expected_coverage
            assert result.functions == 2
            assert result.classes == 2
            assert result.documented_functions == 1  # documented_func only
            assert result.documented_classes == 1    # DocumentedClass only

        finally:
            temp_path.unlink()

    def test_empty_file(self):
        """Test analysis of an empty file."""
        analyzer = PythonAnalyzer()

        with tempfile.NamedTemporaryFile(mode='w', suffix='.py', delete=False) as f:
            f.write('')
            temp_path = Path(f.name)

        try:
            result = analyzer.analyze_file(temp_path)

            assert result.lines == 0
            assert result.functions == 0
            assert result.classes == 0
            assert result.documentation_coverage == 0.0

        finally:
            temp_path.unlink()

    def test_syntax_error_handling(self):
        """Test that syntax errors are handled gracefully."""
        sample_code = '''
def broken_function(
    """Incomplete syntax."""

        pass
'''

        analyzer = PythonAnalyzer()

        with tempfile.NamedTemporaryFile(mode='w', suffix='.py', delete=False) as f:
            f.write(sample_code)
            temp_path = Path(f.name)

        try:
            result = analyzer.analyze_file(temp_path)

            # Should return basic metrics even with errors
            assert result.lines > 0
            assert result.language == 'python'
            assert result.functions == 0  # Cannot parse, so no functions detected
            assert result.classes == 0

        finally:
            temp_path.unlink()
