"""Python analyzer using AST parsing for accurate analysis."""

import ast
from pathlib import Path
from typing import Set

from . import BaseAnalyzer
from ..models import FileMetric, FunctionDetail, ClassDetail


class PythonAnalyzer(BaseAnalyzer):
    """AST-based analyzer for Python files."""

    file_extensions = {'.py'}
    language_name = 'python'

    def analyze_file(self, file_path: Path) -> FileMetric:
        """Analyze a Python file using AST parsing."""
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()

            # Parse the file with AST
            tree = ast.parse(content, filename=str(file_path))

            # Count lines
            lines = len(content.splitlines())

            # Analyze AST for functions and classes
            analyzer = ASTAnalyzer()
            analyzer.visit(tree)

            # The analyzer now tracks functions with their parent class info
            function_details = [
                FunctionDetail(
                    name=node.name,
                    line_number=node.lineno,
                    is_documented=self._has_docstring(node),
                    type=node.func_type
                )
                for node in analyzer.functions
            ]

            class_details = [
                ClassDetail(
                    name=node.name,
                    line_number=node.lineno,
                    is_documented=self._has_docstring(node)
                )
                for node in analyzer.classes
            ]

            return FileMetric(
                path=str(file_path),
                language=self.language_name,
                lines=lines,
                functions=len(analyzer.functions),
                documented_functions=sum(1 for fd in function_details if fd.is_documented),
                classes=len(analyzer.classes),
                documented_classes=sum(1 for cd in class_details if cd.is_documented),
                dependencies=analyzer.imports,
                function_details=function_details,
                class_details=class_details,
            )

        except (SyntaxError, UnicodeDecodeError, OSError) as e:
            # Return basic metrics for files that can't be parsed
            lines = 0
            try:
                with open(file_path, 'r', encoding='utf-8') as f:
                    lines = len(f.read().splitlines())
            except:
                pass

            return FileMetric(
                path=str(file_path),
                language=self.language_name,
                lines=lines,
                functions=0,
                documented_functions=0,
                classes=0,
                documented_classes=0,
            )

    def _has_docstring(self, node: ast.AST) -> bool:
        """Check if an AST node has a docstring."""
        if not hasattr(node, 'body') or not node.body:
            return False

        first_stmt = node.body[0]
        return (isinstance(first_stmt, ast.Expr) and
                isinstance(first_stmt.value, ast.Constant) and
                isinstance(first_stmt.value.value, str))


class ASTAnalyzer(ast.NodeVisitor):
    """AST visitor to collect functions, classes, and imports."""

    def __init__(self):
        self.functions = []
        self.classes = []
        self.imports = []
        self.current_class = None

    def visit_FunctionDef(self, node):
        """Visit function definitions."""
        node.func_type = 'method' if self.current_class else 'function'
        self.functions.append(node)
        self.generic_visit(node)

    def visit_AsyncFunctionDef(self, node):
        """Visit async function definitions."""
        node.func_type = 'method' if self.current_class else 'function'
        self.functions.append(node)
        self.generic_visit(node)

    def visit_ClassDef(self, node):
        """Visit class definitions."""
        self.classes.append(node)
        prev_class = self.current_class
        self.current_class = node.name
        self.generic_visit(node)
        self.current_class = prev_class

    def visit_Import(self, node):
        """Visit import statements."""
        for alias in node.names:
            self.imports.append(alias.name.split('.')[0])
        self.generic_visit(node)

    def visit_ImportFrom(self, node):
        """Visit from import statements."""
        if node.module:
            self.imports.append(node.module.split('.')[0])
        self.generic_visit(node)
