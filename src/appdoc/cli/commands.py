"""AppDoc CLI command implementations."""

import argparse
import json
from pathlib import Path
from appdoc.core.scanner import run_scan


def load_config(config_path: Path) -> dict:
    """Load configuration JSON file if it exists, otherwise return defaults."""
    default_cfg = {
        "ignore": ["__pycache__", "node_modules", ".git", "venv", ".venv"],
        "output_formats": ["json", "html", "markdown"]
    }

    if not config_path.exists():
        print(f"⚠️  No configuration file found at {config_path}, using defaults.")
        return default_cfg

    try:
        with config_path.open("r", encoding="utf-8") as f:
            data = json.load(f)
            print(f"✅ Loaded configuration from {config_path}")
            return {**default_cfg, **data}
    except Exception as e:
        print(f"⚠️  Failed to load configuration: {e}")
        return default_cfg


def command_scan(args):
    """Run a full scan against the given codebase and generate reports."""
    cfg_path = Path("appdoc.config.json")
    config = load_config(cfg_path)

    path = Path(args.path)
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)

    print(f"🔍 Scanning codebase: {path}")
    print(f"📁 Output directory: {out}")

    summary = run_scan(path, out, config)

    print(f"\n✅ Scan complete. Reports written to: {out}")
    print(f"   Total files scanned: {summary.get('stats', {}).get('files_scanned', 'N/A')}")
    print(f"   Time elapsed: {summary.get('stats', {}).get('elapsed_sec', 'N/A')}s")

    # ------------------------------------------------------------------
    # Generate HTML + Markdown reports
    # ------------------------------------------------------------------
    from appdoc.core.report_generator import generate_reports

    try:
        generate_reports(
            scan_json_path=summary["result_path"],
            output_dir=out
        )
    except Exception as e:
        print(f"⚠️  Failed to generate reports: {e}")


def command_init(_args):
    """Create a new default configuration interactively."""
    default = {
        "ignore": ["__pycache__", "node_modules", ".git", "venv", ".venv"],
        "output_formats": ["json", "html", "markdown"]
    }
    path = Path("appdoc.config.json")
    if path.exists():
        print("⚠️  appdoc.config.json already exists. Overwrite? [y/N]")
        if input().strip().lower() != "y":
            print("❌ Cancelled.")
            return
    with path.open("w", encoding="utf-8") as f:
        json.dump(default, f, indent=2)
    print(f"✅ Configuration written to {path}")


def command_docs(_args):
    """Open documentation site."""
    import webbrowser
    print("🌐 Opening AppDoc documentation site...")
    webbrowser.open("https://github.com/HeWhoRoams/AppDoc")


def build_parser():
    """Construct CLI argument parser."""
    parser = argparse.ArgumentParser(
        prog="appdoc",
        description="AppDoc — analyze and document legacy or poorly documented codebases."
    )
    subparsers = parser.add_subparsers(dest="command")

    # --- Scan command ---
    scan_parser = subparsers.add_parser("scan", help="Run an analysis on a local codebase.")
    scan_parser.add_argument("--path", required=True, help="Path to the codebase to scan.")
    scan_parser.add_argument("--out", required=True, help="Output directory for reports.")
    scan_parser.set_defaults(func=command_scan)

    # --- Init command ---
    init_parser = subparsers.add_parser("init", help="Launch interactive configuration creation.")
    init_parser.set_defaults(func=command_init)

    # --- Docs command ---
    docs_parser = subparsers.add_parser("docs", help="Open AppDoc documentation site in your browser.")
    docs_parser.set_defaults(func=command_docs)

    return parser


def main():
    """Entry point for the AppDoc CLI."""
    parser = build_parser()
    args = parser.parse_args()

    if not hasattr(args, "func"):
        parser.print_help()
        return

    args.func(args)
