"""Fail if any module under appdoc/ imports something outside the standard library."""
import ast
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
bad = []
for path in sorted((ROOT / "appdoc").rglob("*.py")):
    for node in ast.walk(ast.parse(path.read_text(encoding="utf-8"))):
        if isinstance(node, ast.Import):
            mods = [a.name.split(".")[0] for a in node.names]
        elif isinstance(node, ast.ImportFrom) and node.level == 0 and node.module:
            mods = [node.module.split(".")[0]]
        else:
            continue
        bad += [(str(path.relative_to(ROOT)), m) for m in mods if m not in sys.stdlib_module_names and m != "appdoc"]
if bad:
    print("Non-stdlib imports:", *bad, sep="\n  ")
    sys.exit(1)
print("ok: appdoc/ imports only the standard library")
