"""Command line: python -m appdoc <extract|fill|check|render> <target> [--out DIR]."""

from __future__ import annotations

import argparse
import os
import sys

from . import __version__
from .version import bundle_hash

DEFAULT_OUT = os.path.join("docs", "appdoc")


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
        if name == "extract":
            sp.add_argument("--workers", type=int, default=None,
                            help="process-pool workers for extraction; default min(cpu,8); 0 = serial")
            sp.add_argument("--skip-tests", action="store_true",
                            help="prune test files (removes test-code Facts)")
            sp.add_argument("--no-cache", action="store_true",
                            help="disable the content-hash cache (cache is on by default)")
            sp.add_argument("--no-ownership", action="store_true",
                            help="skip git ownership Facts")
            sp.add_argument("--ownership-top", type=int, default=None,
                            help="cap ownership to the top-N top-level folders by file count")
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
            for path in extract.write(args.target, out_dir, workers=args.workers,
                                      skip_tests=args.skip_tests, use_cache=not args.no_cache,
                                      no_ownership=args.no_ownership,
                                      ownership_top=args.ownership_top):
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
