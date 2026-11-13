"""Command line: python -m appdoc <extract|fill|check|render> <target> [--out DIR]."""

from __future__ import annotations

import argparse
import hashlib
import os
import sys

from . import __version__

DEFAULT_OUT = os.path.join("docs", "appdoc")


def bundle_hash() -> str:
    """A deterministic SHA-1 over the appdoc package files (path + content)."""
    pkg_dir = os.path.dirname(os.path.abspath(__file__))
    h = hashlib.sha1()
    for dirpath, dirnames, filenames in os.walk(pkg_dir):
        dirnames.sort()
        for fname in sorted(filenames):
            full = os.path.join(dirpath, fname)
            rel = os.path.relpath(full, pkg_dir).replace(os.sep, "/")
            h.update(rel.encode("utf-8"))
            h.update(b"\0")
            with open(full, "rb") as fh:
                h.update(fh.read())
            h.update(b"\0")
    return h.hexdigest()


def _resolve_out(target: str, out: str | None) -> str:
    target = os.path.abspath(target)
    out_abs = os.path.abspath(out if out and os.path.isabs(out) else os.path.join(target, out or DEFAULT_OUT))
    if os.path.commonpath([target, out_abs]) != target:
        raise SystemExit(f"appdoc: --out must be inside the target ({target})")
    return out_abs


def main(argv=None) -> int:
    p = argparse.ArgumentParser(prog="appdoc", description="Document an unfamiliar codebase.")
    p.add_argument("--version", action="version",
                   version=f"appdoc {__version__} (bundle {bundle_hash()})")
    sub = p.add_subparsers(dest="cmd", required=True)
    for name in ("extract", "fill", "check", "render", "seal", "build"):
        sp = sub.add_parser(name)
        sp.add_argument("target", help="Target repository root")
        sp.add_argument("--out", help=f"output folder inside the target (default {DEFAULT_OUT})")
        if name == "render":
            sp.add_argument("--css", help="CSS file replacing the default theme")
        if name == "check":
            sp.add_argument("--require-audit", action="store_true",
                            help="fail when the source-to-claim audit was declared not performed")
            sp.add_argument("--strict", action="store_true",
                            help="fail when an entry point file is not cited anywhere in the document")
        if name == "build":
            sp.add_argument("--require-audit", action="store_true",
                            help="fail when the source-to-claim audit was declared not performed")
            sp.add_argument("--strict", action="store_true",
                            help="fail when an entry point file is not cited anywhere in the document")
    args = p.parse_args(argv)

    if not os.path.isdir(args.target):
        print(f"appdoc: target not found: {args.target}", file=sys.stderr)
        return 1
    out_dir = _resolve_out(args.target, args.out)
    try:
        if args.cmd == "extract":
            from . import extract
            for path in extract.write(args.target, out_dir):
                print(f"wrote {path}")
            return 0
        if args.cmd == "fill":
            from . import fill
            return fill.run(args.target, out_dir)
        if args.cmd == "check":
            from . import check
            return check.run(args.target, out_dir, args.require_audit, args.strict)
        if args.cmd == "seal":
            from . import check
            n = check.seal_register(args.target, out_dir)
            print(f"sealed {n} row(s)")
            return 0
        if args.cmd == "build":
            from . import check, fill
            from .render import page
            n = check.seal_register(args.target, out_dir)
            if n:
                print(f"sealed {n} row(s)")
            rc = fill.run(args.target, out_dir)
            if rc != 0:
                return rc
            rc = check.run(args.target, out_dir, args.require_audit, args.strict)
            if rc != 0:
                return rc
            return page.run(args.target, out_dir, None)
        from .render import page
        return page.run(args.target, out_dir, args.css)
    except ImportError as exc:
        print(f"appdoc: {args.cmd} is not available yet ({exc})", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
