"""Command line entry point; the module docstring is assigned below from COMMANDS."""

from __future__ import annotations

import argparse
import os
import sys

from . import __version__
from .version import bundle_hash

DEFAULT_OUT = os.path.join("docs", "appdoc")
COMMANDS = ("extract", "fill", "check", "render", "seal", "build", "gate")
COMMAND_HELP = {
    "extract": "write facts.json, facts-summary.md and provenance.json",
    "fill": "write the generated blocks of the Narrative from the Facts and the register",
    "check": "verify the Narrative; exit 0 pass, 2 problems, 1 tool error",
    "render": "write application-documentation.html",
    "seal": "write claim_sha into the register rows that lack one; --audit --date records the audit",
    "build": "seal (rows and notes), fill, check and render in one step",
    "gate": "CI gate: regenerate the Facts and compare with the committed facts.json, then check; "
            "exit 0 pass, 1 tool error, 2 Facts changed, 3 AppDoc upgraded",
}
__doc__ = f"Command line: python -m appdoc <{'|'.join(COMMANDS)}> <target> [--out DIR]."


def _resolve_out(target: str, out: str | None) -> str:
    target = os.path.abspath(target)
    out_abs = os.path.abspath(out if out and os.path.isabs(out) else os.path.join(target, out or DEFAULT_OUT))
    if os.path.commonpath([target, out_abs]) != target:
        raise SystemExit(f"appdoc: --out must be inside the target ({target})")
    return out_abs


def build_parser() -> argparse.ArgumentParser:
    """The argument parser; tools/gen_docs.py reads the README command list from it."""
    p = argparse.ArgumentParser(prog="appdoc", description="Document an unfamiliar codebase.")
    p.add_argument("--version", action="version",
                   version=f"appdoc {__version__} (bundle {bundle_hash()})")
    sub = p.add_subparsers(dest="cmd", required=True)
    for name in COMMANDS:
        sp = sub.add_parser(name, help=COMMAND_HELP[name], description=COMMAND_HELP[name])
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
        if name == "seal":
            sp.add_argument("--audit", action="store_true",
                            help="record that the audit just finished: write the audit provenance on line 1 "
                                 "of the register and seal the unsealed rows as audited (needs --date)")
            sp.add_argument("--date", help="the audit date, YYYY-MM-DD (required with --audit)")
        if name == "render":
            sp.add_argument("--css", help="CSS file replacing the default theme")
        if name == "check":
            sp.add_argument("--require-audit", action="store_true",
                            help="fail when the source-to-claim audit was declared not performed")
            sp.add_argument("--strict", action="store_true",
                            help="fail when an entry point file is not cited anywhere in the document")
        if name == "gate":
            sp.add_argument("--workers", type=int, default=None,
                            help="process-pool workers for the regeneration; default min(cpu,8); 0 = serial")
        if name in ("build", "gate"):
            sp.add_argument("--require-audit", action="store_true",
                            help="fail when the source-to-claim audit was declared not performed")
            sp.add_argument("--strict", action="store_true",
                            help="fail when an entry point file is not cited anywhere in the document")
    return p


def main(argv=None) -> int:
    p = build_parser()
    args = p.parse_args(argv)

    if not os.path.isdir(args.target):
        print(f"appdoc: target not found: {args.target}", file=sys.stderr)
        return 1
    out_dir = _resolve_out(args.target, args.out)
    if args.cmd == "seal":
        if args.audit and not args.date:
            p.error("seal --audit needs --date YYYY-MM-DD (the audit date is supplied, never read from the clock)")
        if args.date and not args.audit:
            p.error("--date is only for seal --audit")
        if args.date:
            import datetime
            try:
                datetime.date.fromisoformat(args.date)
                ok = len(args.date) == 10
            except ValueError:
                ok = False
            if not ok:
                p.error(f"--date must be a real date, YYYY-MM-DD (got {args.date})")
        if args.audit:
            from . import check, register
            reg_path = os.path.join(out_dir, register.REGISTER)
            if not (os.path.isfile(reg_path) and os.path.isfile(os.path.join(out_dir, check.NARRATIVE))):
                print(f"appdoc: seal --audit needs {check.NARRATIVE} and {register.REGISTER} in {out_dir}",
                      file=sys.stderr)
                return 1
            if register.parse(check._read_text(reg_path)).audit is None:
                print(f"appdoc: line 1 of {register.REGISTER} must be the audit record", file=sys.stderr)
                return 1
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
        if args.cmd == "gate":
            from . import gate
            return gate.run(args.target, out_dir, args.require_audit, args.strict, args.workers)
        if args.cmd == "seal":
            from . import check
            n = check.seal_register(args.target, out_dir, args.audit, args.date)
            print(f"sealed {n} row(s)")
            return 0
        if args.cmd == "build":
            from . import check, fill
            from .render import page
            n = check.seal_register(args.target, out_dir)
            if n:
                print(f"sealed {n} row(s)")
            n = check.seal_notes(args.target, out_dir)
            if n:
                print(f"sealed {n} note(s)")
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
