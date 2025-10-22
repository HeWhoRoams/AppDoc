"""Subcommand implementations for AppDoc CLI (JSON-based configuration)."""

from pathlib import Path
import sys
import webbrowser
import json
from appdoc.core import scanner


# ---------------------------------------------------------------------------
# scan
# ---------------------------------------------------------------------------

def run_scan(args):
    """Run a full codebase analysis and generate reports."""
    root = Path(args.path).resolve()
    out = Path(args.out).resolve()
    config_path = Path(args.config).resolve()

    if not root.exists():
        print(f"❌ Error: Path not found: {root}")
        sys.exit(1)

    # Load JSON configuration if available
    cfg = {}
    if config_path.exists():
        try:
            text = config_path.read_text(encoding="utf-8")
            cfg = json.loads(text)
            print(f"✅ Loaded configuration from {config_path}")
        except Exception as e:
            print(f"⚠️  Warning: Could not parse JSON config ({e}). Using defaults.")

    print(f"🔍 Scanning codebase: {root}")
    print(f"📁 Output directory: {out}")

    out.mkdir(parents=True, exist_ok=True)

    try:
        summary = scanner.run_scan(str(root), str(out), cfg)
        print(f"\n✅ Scan complete. Reports written to: {out}")
        print(f"   Total files scanned: {summary.get('stats', {}).get('files_scanned', 'N/A')}")
        print(f"   Time elapsed: {summary.get('stats', {}).get('elapsed_sec', 'N/A')}s")

# After the print statements for scan complete
try:
    generate_reports(
        scan_json_path=result["result_path"],
        output_dir=args.out
    )
except Exception as e:
    print(f"⚠️  Failed to generate reports: {e}")

    except Exception as e:
        print(f"❌ Scan failed: {type(e).__name__}: {e}")
        sys.exit(1)


# ---------------------------------------------------------------------------
# init
# ---------------------------------------------------------------------------

def run_init(args):
    """Create a default appdoc.config.json interactively or non-interactively."""
    default_config = {
        "ignore": ["tests/", "venv/", "node_modules/"],
        "report_format": "html",
        "include_docstrings": True,
        "extensions": [".py", ".js", ".ts", ".java", ".cs"]
    }

    cfg_path = Path("appdoc.config.json")

    if cfg_path.exists():
        confirm = input("⚠️  appdoc.config.json already exists. Overwrite? [y/N]: ").strip().lower()
        if confirm != "y":
            print("Operation cancelled.")
            return

    cfg_path.write_text(json.dumps(default_config, indent=2))
    print(f"✅ Created default configuration at {cfg_path.resolve()}")


# ---------------------------------------------------------------------------
# docs
# ---------------------------------------------------------------------------

def run_docs(args):
    """Open the documentation site in the user's browser."""
    url = "https://hewhoroams.github.io/AppDoc"
    print(f"🌐 Opening documentation: {url}")
    try:
        webbrowser.open(url)
    except Exception as e:
        print(f"⚠️  Could not open browser: {e}")
