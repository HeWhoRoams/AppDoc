"""Report generation module with JSON and HTML output."""

from pathlib import Path
from typing import Dict, Any
import json
from jinja2 import Environment, FileSystemLoader, select_autoescape

from ..models import ScanResult


def generate_reports(result: ScanResult, output_dir: Path):
    """Generate both JSON summary and HTML report.

    Args:
        result: Scan results to report on
        output_dir: Directory to write reports to
    """
    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    # Generate JSON summary
    json_path = output_dir / "summary.json"
    _generate_json_report(result, json_path)

    # Generate HTML report
    html_path = output_dir / "index.html"
    _generate_html_report(result, html_path)


def _generate_json_report(result: ScanResult, output_path: Path):
    """Generate JSON summary report."""
    data = {
        "scan_info": {
            "timestamp": result.timestamp,
            "scan_path": result.scan_path,
            "duration_seconds": result.duration_seconds,
            "total_files": result.total_files,
            "total_lines": result.total_lines,
            "overall_coverage": result.overall_coverage,
        },
        "languages": {
            lang: {
                "files": summary.files,
                "lines": summary.lines,
                "functions": summary.functions,
                "documented_functions": summary.documented_functions,
                "classes": summary.classes,
                "documented_classes": summary.documented_classes,
                "coverage_percentage": summary.documentation_coverage,
            }
            for lang, summary in result.language_summaries.items()
        },
        "files": [
            {
                "path": metric.path,
                "language": metric.language,
                "lines": metric.lines,
                "functions": metric.functions,
                "documented_functions": metric.documented_functions,
                "classes": metric.classes,
                "documented_classes": metric.documented_classes,
                "coverage_percentage": metric.documentation_coverage,
                "dependencies": metric.dependencies,
                "complexity": metric.complexity,
            }
            for metric in result.file_metrics
        ]
    }

    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=2, ensure_ascii=False)


def _generate_html_report(result: ScanResult, output_path: Path):
    """Generate HTML report using Jinja2 templates."""
    # Set up Jinja2 environment
    template_dir = Path(__file__).parent / "templates"
    env = Environment(
        loader=FileSystemLoader(template_dir),
        autoescape=select_autoescape(['html', 'xml'])
    )

    # Load template
    template = env.get_template("report.html.jinja")

    # Prepare template data
    template_data = {
        "result": result,
        "chart_data": _prepare_chart_data(result),
    }

    # Render and write
    html_content = template.render(**template_data)
    with open(output_path, 'w', encoding='utf-8') as f:
        f.write(html_content)


def _prepare_chart_data(result: ScanResult) -> Dict[str, Any]:
    """Prepare data for charts in the HTML report."""
    # Language distribution
    language_labels = []
    language_data = []

    for lang, summary in result.language_summaries.items():
        language_labels.append(lang.title())
        language_data.append(summary.files)

    # Documentation coverage by language
    coverage_labels = []
    coverage_data = []

    for lang, summary in result.language_summaries.items():
        coverage_labels.append(lang.title())
        coverage_data.append(round(summary.documentation_coverage, 1))

    return {
        "language_labels": language_labels,
        "language_data": language_data,
        "coverage_labels": coverage_labels,
        "coverage_data": coverage_data,
    }
