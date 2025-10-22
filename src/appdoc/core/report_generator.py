"""AppDoc report generator — builds both Markdown and HTML summaries."""

import json
from pathlib import Path
from jinja2 import Template
import datetime


HTML_TEMPLATE = """<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>AppDoc Report - {{ project_name }}</title>
  <style>
    body { font-family: Arial, sans-serif; background: #fafafa; color: #222; padding: 2em; }
    h1, h2 { color: #333; }
    table { width: 100%; border-collapse: collapse; margin-top: 1em; }
    th, td { border: 1px solid #ccc; padding: 6px 10px; text-align: left; }
    th { background: #333; color: white; }
    tr:nth-child(even) { background: #f0f0f0; }
    .summary { margin: 1em 0; }
    .summary div { margin-bottom: 0.3em; }
    footer { margin-top: 2em; font-size: 0.8em; color: #666; }
  </style>
</head>
<body>
  <h1>📊 AppDoc Codebase Report</h1>
  <div class="summary">
    <div><b>Project:</b> {{ project_name }}</div>
    <div><b>Total Files:</b> {{ total_files }}</div>
    <div><b>Total Lines:</b> {{ total_lines }}</div>
    <div><b>Duration:</b> {{ duration }}s</div>
    <div><b>Generated:</b> {{ timestamp }}</div>
    <div><b>Source:</b> {{ scan_path }}</div>
  </div>

  <h2>Language Breakdown</h2>
  <table>
    <thead>
      <tr>
        <th>Language</th>
        <th>Files</th>
        <th>Lines</th>
        <th>Functions</th>
        <th>Classes</th>
      </tr>
    </thead>
    <tbody>
      {% for lang, info in languages.items() %}
      <tr>
        <td>{{ lang }}</td>
        <td>{{ info.files }}</td>
        <td>{{ info.lines }}</td>
        <td>{{ info.functions }}</td>
        <td>{{ info.classes }}</td>
      </tr>
      {% endfor %}
    </tbody>
  </table>

  <footer>
    Generated automatically by AppDoc on {{ timestamp }}
  </footer>
</body>
</html>
"""


def generate_reports(scan_json_path: str, output_dir: str):
    """Generate both Markdown and HTML reports from scan_results.json."""
    scan_path = Path(scan_json_path)
    if not scan_path.exists():
        raise FileNotFoundError(f"Scan result file not found: {scan_path}")

    output_dir = Path(output_dir)
    data = json.loads(scan_path.read_text(encoding="utf-8"))

    # ---------- Markdown ----------
    md_path = output_dir / "report.md"
    lines = [
        f"# 📊 AppDoc Codebase Report — {Path(data['scan_path']).name}",
        "",
        f"**Total Files:** {data['total_files']}",
        f"**Total Lines:** {data['total_lines']}",
        f"**Duration:** {data.get('duration_seconds', 0)}s",
        f"**Generated:** {data['timestamp']}",
        "",
        "## Language Breakdown",
        "| Language | Files | Lines | Functions | Classes |",
        "|-----------|-------|-------|------------|----------|",
    ]
    for lang, info in data["language_summaries"].items():
        lines.append(
            f"| {lang} | {info['files']} | {info['lines']} | "
            f"{info['functions']} | {info['classes']} |"
        )
    md_path.write_text("\n".join(lines), encoding="utf-8")

    # ---------- HTML ----------
    template = Template(HTML_TEMPLATE)
    rendered = template.render(
        project_name=Path(data["scan_path"]).name,
        total_files=data["total_files"],
        total_lines=data["total_lines"],
        duration=data.get("duration_seconds", 0),
        timestamp=datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        scan_path=data["scan_path"],
        languages=data["language_summaries"],
    )

    html_path = output_dir / "report.html"
    html_path.write_text(rendered, encoding="utf-8")

    print(f"✅ Reports written to:\n   {md_path}\n   {html_path}")
    return {"markdown": str(md_path), "html": str(html_path)}
