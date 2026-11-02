"""Command line: python -m appdoc <extract|check|render> <target> [--out DIR]."""

from __future__ import annotations

import argparse
import os
import sys

DEFAULT_OUT = os.path.join("docs", "appdoc")


def _resolve_out(target: str, out: str | None) -> str:
    target = os.path.abspath(target)
    out_abs = os.path.abspath(out if out and os.path.isabs(out) else os.path.join(target, out or DEFAULT_OUT))
    if os.path.commonpath([target, out_abs]) != target:
        raise SystemExit(f"appdoc: --out must be inside the target ({target})")
    return out_abs


def main(argv=None) -> int:
    p = argparse.ArgumentParser(prog="appdoc", description="Document an unfamiliar codebase.")
    sub = p.add_subparsers(dest="cmd", required=True)
    for name in ("extract", "check", "render"):
        sp = sub.add_parser(name)
        sp.add_argument("target", help="Target repository root")
        sp.add_argument("--out", help=f"output folder inside the target (default {DEFAULT_OUT})")
        if name == "render":
            sp.add_argument("--css", help="CSS file replacing the default theme")
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
        if args.cmd == "check":
            from . import check
            return check.run(args.target, out_dir)
        from .render import page
        return page.run(args.target, out_dir, args.css)
    except ImportError as exc:
        print(f"appdoc: {args.cmd} is not available yet ({exc})", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
