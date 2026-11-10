"""Install the AppDoc skill bundle into an AI skills directory."""

from __future__ import annotations

import argparse
import shutil
import sys
from pathlib import Path

REQUIRED_FILES = (
    Path("SKILL.md"),
    Path("CONTEXT.md"),
    Path("run_appdoc.py"),
    Path("appdoc/assets/template.md"),
    Path("appdoc/assets/mermaid.min.js"),
)
SKILL_FILES = (Path("SKILL.md"), Path("CONTEXT.md"), Path("run_appdoc.py"))


def install(source: Path, skills_root: Path) -> Path:
    source = source.resolve()
    destination = (skills_root.expanduser().resolve() / "appdoc")
    missing = [str(path) for path in REQUIRED_FILES if not (source / path).is_file()]
    if missing:
        raise FileNotFoundError("incomplete AppDoc source bundle; missing: " + ", ".join(missing))
    if destination == source or source in destination.parents:
        raise ValueError(f"refusing to install inside the AppDoc source directory: {destination}")

    destination.mkdir(parents=True, exist_ok=True)
    for path in SKILL_FILES:
        shutil.copy2(source / path, destination / path)
    shutil.copytree(
        source / "appdoc",
        destination / "appdoc",
        dirs_exist_ok=True,
        ignore=shutil.ignore_patterns("__pycache__", "*.pyc"),
    )
    return destination


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Install the complete AppDoc skill bundle.")
    parser.add_argument("skills_root", type=Path, help="directory containing skills; appdoc/ is created inside")
    args = parser.parse_args(argv)
    try:
        destination = install(Path(__file__).parent, args.skills_root)
    except (OSError, ValueError) as exc:
        print(f"appdoc installer: {exc}", file=sys.stderr)
        return 1
    print(f"Installed AppDoc skill in {destination}")
    return 0


if __name__ == "__main__":
    sys.exit(main())