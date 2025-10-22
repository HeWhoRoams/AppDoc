"""Core scanning engine for AppDoc with progress bar and proper path resolution."""

from pathlib import Path
import time
import json
from tqdm import tqdm
from appdoc.models import ScanResult, FileMetric, LanguageSummary


def analyze_file(file_path: Path) -> FileMetric:
    """Lightweight static analyzer for code metrics."""
    try:
        lines = file_path.read_text(encoding="utf-8", errors="ignore").splitlines()
    except Exception:
        lines = []

    func_count = sum(1 for l in lines if "def " in l or "function " in l)
    class_count = sum(1 for l in lines if "class " in l)
    language = file_path.suffix.lower().lstrip(".") or "unknown"

    return FileMetric(
        path=str(file_path),
        language=language,
        lines=len(lines),
        functions=func_count,
        documented_functions=0,
        classes=class_count,
        documented_classes=0,
        dependencies=[],
        complexity=None,
        function_details=[],
        class_details=[],
    )


def run_scan(path: str, out: str, cfg: dict):
    """Scan a codebase and write JSON summary output with progress bar."""
    start = time.time()

    # Normalize paths to absolute form
    root = Path(path).expanduser().resolve(strict=False)
    output_dir = Path(out).expanduser().resolve(strict=False)
    output_dir.mkdir(parents=True, exist_ok=True)

    print(f"📍 Normalized scan root: {root}")
    print(f"📁 Output directory: {output_dir}")

    ignored = [str(Path(i).resolve()) if Path(i).exists() else i for i in cfg.get("ignore", [])]

    # Collect files recursively under target directory
    files = [
        p for p in root.rglob("*")
        if p.is_file()
        and "AppDoc" not in str(p)  # prevent self-scan
        and not any(ignore in str(p) for ignore in ignored)
    ]

    print(f"📊 Found {len(files)} files to scan.\n")

    metrics = []
    for f in tqdm(files, desc="Scanning files", unit="file", ncols=80):
        try:
            metrics.append(analyze_file(f))
        except Exception as e:
            tqdm.write(f"⚠️  Skipped {f}: {e}")

    # Aggregate by language
    lang_summary = {}
    for fm in metrics:
        lang = fm.language
        if lang not in lang_summary:
            lang_summary[lang] = LanguageSummary(language=lang)
        lang_summary[lang].files += 1
        lang_summary[lang].lines += fm.lines
        lang_summary[lang].functions += fm.functions
        lang_summary[lang].classes += fm.classes

    # Build result
    duration = round(time.time() - start, 2)
    scan_result = ScanResult(
        total_files=len(metrics),
        total_lines=sum(fm.lines for fm in metrics),
        language_summaries=lang_summary,
        file_metrics=metrics,
        duration_seconds=duration,
        scan_path=str(root),
        timestamp=time.strftime("%Y-%m-%d %H:%M:%S"),
        dependency_graph={},
        files_scanned=len(metrics),
        ignored_patterns=cfg.get("ignore", []),
    )

    # Write results to JSON
    result_path = output_dir / "scan_results.json"
    with result_path.open("w", encoding="utf-8") as f:
        json.dump(scan_result, f, default=lambda o: o.__dict__, indent=2)

    print(f"\n✅ Wrote scan summary to {result_path}")
    print(f"📁 Total files: {len(metrics)} | Duration: {duration}s")

    return {
        "stats": {
            "files_scanned": len(metrics),
            "elapsed_sec": duration,
        },
        "result_path": str(result_path),
    }
