"""Hash every generated artifact so CI can prove the bytes are the same on every OS and Python.

    python tools/artifact_hashes.py                  # print {"<target>/<file>": sha256} as sorted JSON
    python tools/artifact_hashes.py --compare A.json B.json ...   # exit 1 when the files differ

Targets: every tests/samples/* (extract) and tests/corpus/trivial (extract, seal, fill, check, render).
Text is hashed after CRLF -> LF, so a checkout with autocrlf does not matter; the bytes AppDoc writes
are LF already. provenance.json and the cache file are not hashed (they name the build, not the Target).
Stdlib only.
"""

from __future__ import annotations

import contextlib
import hashlib
import io
import json
import os
import shutil
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, ROOT)

ARTIFACTS = ("facts.json", "facts-summary.md", "application-documentation.md", "check-report.md",
             "application-documentation.html")


def _digest(path: str) -> str:
    with open(path, "rb") as fh:
        return hashlib.sha256(fh.read().replace(b"\r\n", b"\n")).hexdigest()


def collect() -> dict:
    from appdoc import __main__ as cli
    out: dict = {}
    samples = os.path.join(ROOT, "tests", "samples")
    targets = [(n, os.path.join(samples, n), False) for n in sorted(os.listdir(samples))
               if os.path.isdir(os.path.join(samples, n)) and n != "docs"]
    targets.append(("trivial", os.path.join(ROOT, "tests", "corpus", "trivial"), True))
    for name, src, full in targets:
        with tempfile.TemporaryDirectory() as tmp:
            target = os.path.join(tmp, name)
            shutil.copytree(src, target, ignore=shutil.ignore_patterns("__pycache__"))
            with contextlib.redirect_stdout(io.StringIO()):
                cli.main(["extract", target, "--workers", "0", "--no-cache", "--no-ownership"])
                if full:
                    cli.main(["build", target])
            docs = os.path.join(target, "docs", "appdoc")
            for fname in ARTIFACTS:
                p = os.path.join(docs, fname)
                if os.path.isfile(p):
                    out[f"{name}/{fname}"] = _digest(p)
    return dict(sorted(out.items()))


def compare(paths: list) -> int:
    if len(paths) < 2:
        print("artifact_hashes: --compare needs at least two hash files", file=sys.stderr)
        return 1
    docs = []
    for p in paths:
        with open(p, encoding="utf-8") as fh:
            docs.append((p, json.load(fh)))
    base_path, base = docs[0]
    bad = 0
    for p, doc in docs[1:]:
        for key in sorted(set(base) | set(doc)):
            if base.get(key) != doc.get(key):
                bad += 1
                print(f"DIFFERS {key}: {base_path} {base.get(key)} != {p} {doc.get(key)}")
    if bad:
        print(f"artifact_hashes: {bad} artifact hash(es) differ", file=sys.stderr)
        return 1
    print(f"artifact_hashes: {len(docs)} files agree on {len(base)} artifacts")
    return 0


def main(argv: list) -> int:
    if argv and argv[0] == "--compare":
        return compare(argv[1:])
    sys.stdout.write(json.dumps(collect(), indent=1, sort_keys=True) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
