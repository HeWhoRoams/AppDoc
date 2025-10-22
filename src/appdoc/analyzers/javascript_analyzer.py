"""JavaScript analyzer using regex for function and class detection."""

import re
from pathlib import Path
from typing import List, Tuple

from . import BaseAnalyzer
from ..models import FileMetric


class JavaScriptAnalyzer(BaseAnalyzer):
    """Regex-based analyzer for JavaScript/TypeScript files."""

    file_extensions = {'.js', '.mjs', '.ts'}
    language_name = 'javascript'

    # Regex patterns for detecting functions, classes, and comments
    FUNCTION_PATTERN = re.compile(
        r'\b(?:function\s+\w+|(?:const|let|var)\s+\w+\s*=\s*(?:function|\([^)]*\)\s*=>)|\w+\s*\([^)]*\)\s*{)',
        re.MULTILINE
    )

    CLASS_PATTERN = re.compile(
        r'\bclass\s+\w+',
        re.MULTILINE
    )

    COMMENT_PATTERN = re.compile(
        r'/\*\*[\s\S]*?\*/',
        re.MULTILINE | re.DOTALL
    )

    def analyze_file(self, file_path: Path) -> FileMetric:
        """Analyze a JavaScript/TypeScript file using regex patterns."""
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()

            lines = len(content.splitlines())

            # Find all comments (potential JSDoc)
            comments = self.COMMENT_PATTERN.findall(content)

            # Find all functions (improved detection)
            functions = self._find_functions(content)

            # Find all classes
            classes = self.CLASS_PATTERN.findall(content)

            # Count documented items by looking for JSDoc comments
            documented_functions = self._count_documented_functions(content, functions)
            documented_classes = self._count_documented_classes(content, classes)

            # Extract dependencies (basic import/export detection)
            dependencies = self._extract_dependencies(content)

            return FileMetric(
                path=str(file_path),
                language=self.language_name,
                lines=lines,
                functions=len(functions),
                documented_functions=documented_functions,
                classes=len(classes),
                documented_classes=documented_classes,
                dependencies=dependencies,
            )

        except (UnicodeDecodeError, OSError):
            # Return basic metrics for files that can't be read
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

    def _find_functions(self, content: str) -> List[str]:
        """Find all function declarations/expressions in the content."""
        functions = []

        # Function declarations: function name(args) {
        func_decls = re.findall(r'function\s+(\w+)\s*\([^)]*\)\s*{', content)
        functions.extend(func_decls)

        # Arrow functions assigned to variables: const name = (args) => {
        arrow_funcs = re.findall(r'(?:const|let|var)\s+(\w+)\s*=\s*(?:\([^)]*\)\s*=>|\w+\s*=>)', content)
        functions.extend(arrow_funcs)

        # Method definitions in classes: name(args) {
        methods = re.findall(r'(\w+)\s*\([^)]*\)\s*{', content)
        # Filter out obvious non-functions (like if statements, loops, etc.)
        filtered_methods = [m for m in methods if not re.search(
            rf'\b(?:if|for|while|catch|switch|class)\s+{re.escape(m)}\s*\(',
            content
        )]
        functions.extend(filtered_methods)

        # Remove duplicates and common keywords
        functions = list(set(functions))
        functions = [f for f in functions if f not in {'if', 'for', 'while', 'catch', 'switch'}]

        return functions

    def _count_documented_functions(self, content: str, functions: List[str]) -> int:
        """Count functions that have JSDoc comments."""
        documented = 0

        for func in functions:
            # Look for JSDoc comment before function definition
            pattern = rf'/\*\*[\s\S]*?\*/\s*.*?(?:function\s+{re.escape(func)}|\w+\s+{re.escape(func)}\s*=)'
            if re.search(pattern, content, re.MULTILINE | re.DOTALL):
                documented += 1

        return documented

    def _count_documented_classes(self, content: str, classes: List[str]) -> int:
        """Count classes that have JSDoc comments."""
        documented = 0

        for cls in classes:
            # Look for JSDoc comment before class definition
            pattern = rf'/\*\*[\s\S]*?\*/\s*class\s+{re.escape(cls)}'
            if re.search(pattern, content, re.MULTILINE | re.DOTALL):
                documented += 1

        return documented

    def _extract_dependencies(self, content: str) -> List[str]:
        """Extract module dependencies from import/export statements."""
        dependencies = []

        # ES6 imports: import ... from 'module'
        import_matches = re.findall(r"from\s+['\"]([^'\"]+?)['\"]", content)
        dependencies.extend(import_matches)

        # CommonJS require: require('module')
        require_matches = re.findall(r"require\s*\(\s*['\"]([^'\"]+?)['\"]\s*\)", content)
        dependencies.extend(require_matches)

        # Remove duplicates and get base module names
        dependencies = list(set(dependencies))
        dependencies = [dep.split('/')[0] for dep in dependencies if dep and not dep.startswith('.')]

        return dependencies
