"""Precision check for finding-candidate (smell) patterns: list every hit on a Target.

Usage: python eval/smell_precision.py <target> [<target> ...]
Prints pattern counts, then every hit as ``path:line name`` (the sentence, never a secret value).
"""

from __future__ import annotations

import collections
import os
import sys
import time

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))

from appdoc import scan, smells  # noqa: E402

_STACK_BY_EXT = {
    ".py": "python-flask", ".js": "node-express", ".ts": "node-express", ".ejs": "node-express",
    ".java": "java-spring", ".properties": "java-spring", ".yml": "java-spring", ".yaml": "java-spring",
    ".cs": "aspnet-core", ".cshtml": "aspnet-core", ".razor": "aspnet-core",
    ".asp": "classic-asp", ".aspx": "aspnet", ".vb": "aspnet",
}


def run(root: str) -> list:
    t0 = time.perf_counter()
    hits = []
    for sf in scan.walk(root):
        if sf.skipped:
            continue
        stack = _STACK_BY_EXT.get(sf.ext)
        text, _ = scan.read_text(root, sf.path)
        hits.extend(smells.extract(sf.path, text, [stack] if stack else []))
    print(f"== {root}  ({time.perf_counter() - t0:.2f}s)")
    return sorted(hits, key=lambda f: (f.detail_dict()["pattern"], f.path, f.line or 0))


def main(argv: list[str]) -> int:
    if not argv:
        print(__doc__)
        return 2
    for root in argv:
        hits = run(root)
        counts = collections.Counter(h.detail_dict()["pattern"] for h in hits)
        for pattern, n in sorted(counts.items()):
            print(f"{pattern}: {n}")
        for h in hits:
            print(f"{h.path}:{h.line} [{h.detail_dict()['pattern']}] {h.name}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
