# tests/conftest.py
# Keep pytest from recursing into scratch-output and non-test directories that
# live under tests/ but are not Python test modules.
collect_ignore = [
    "test-output",  # scratch output from extraction runs (gitignored; can hold 50k+ files)
]
