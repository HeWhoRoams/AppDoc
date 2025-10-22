"""Main command-line interface for AppDoc."""

import argparse
import sys
from appdoc.cli import commands


def build_parser() -> argparse.ArgumentParser:
    """Build the main argument parser and all subcommands."""
    parser = argparse.ArgumentParser(
        prog="appdoc",
        description="AppDoc — analyze and document legacy or poorly documented codebases.",
    )

    subparsers = parser.add_subparsers(dest="command", required=True)

    # ------------------------------------------------------------------
    # scan
    # ------------------------------------------------------------------
    scan_parser = subparsers.add_parser(
        "scan", help="Run an analysis on a local codebase."
    )
    scan_parser.add_argument(
        "--path",
        required=True,
        help="Path to the root of the codebase to scan."
    )
    scan_parser.add_argument(
        "--out",
        required=True,
        help="Output directory for reports (JSON + HTML). Will be created if missing."
    )
    scan_parser.add_argument(
        "--config",
        default="appdoc.config.json",
        help="Optional path to configuration file (JSON). Defaults to appdoc.config.json."
    )
    scan_parser.set_defaults(func=commands.run_scan)

    # ------------------------------------------------------------------
    # init
    # ------------------------------------------------------------------
    init_parser = subparsers.add_parser(
        "init", help="Launch interactive configuration creation."
    )
    init_parser.set_defaults(func=commands.run_init)

    # ------------------------------------------------------------------
    # docs
    # ------------------------------------------------------------------
    docs_parser = subparsers.add_parser(
        "docs", help="Open AppDoc documentation site in your browser."
    )
    docs_parser.set_defaults(func=commands.run_docs)

    return parser


def main(argv: list[str] | None = None):
    """Entry point for AppDoc CLI."""
    parser = build_parser()
    args = parser.parse_args(argv)

    try:
        if hasattr(args, "func"):
            args.func(args)
        else:
            parser.print_help()
    except KeyboardInterrupt:
        print("\nInterrupted by user.")
        sys.exit(130)
    except Exception as e:
        print(f"❌ Error: {type(e).__name__}: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
