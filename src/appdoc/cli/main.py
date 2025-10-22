"""Command-line interface for AppDoc."""

import os
import sys
from pathlib import Path
from typing import List, Optional

import click
from rich.console import Console
from rich.progress import Progress, SpinnerColumn, TextColumn
from rich.table import Table

from ..core.scanner import Scanner
from ..reporting import generate_reports


console = Console()


@click.group()
@click.version_option()
def cli():
    """AppDoc: Multi-language documentation analysis tool."""
    pass


@cli.command()
@click.argument('path', type=click.Path(exists=True))
@click.argument('out', type=click.Path())
@click.option(
    '--max-files',
    type=int,
    help='Maximum number of files to process'
)
@click.option(
    '--threads',
    type=int,
    help='Number of concurrent threads (default: CPU count)'
)
@click.option(
    '--languages',
    help='Comma-separated list of languages to analyze (default: all)'
)
@click.option(
    '--ignore',
    multiple=True,
    help='Glob patterns to ignore (can be used multiple times)'
)
@click.option(
    '--verbose/--quiet',
    default=False,
    help='Enable verbose output'
)
def scan(path: str, out: str, max_files: Optional[int], threads: Optional[int],
         languages: Optional[str], ignore: List[str], verbose: bool):
    """Scan a codebase and generate documentation analysis reports.

    PATH is the directory to scan.

    OUT is the directory where reports will be generated.
    """
    try:
        # Parse languages
        languages_list = None
        if languages:
            languages_list = [lang.strip() for lang in languages.split(',')]

        # Set up console output
        if verbose:
            console.print(f"Scanning path: {path}")
            console.print(f"Output directory: {out}")
            if languages_list:
                console.print(f"Languages: {', '.join(languages_list)}")
            if ignore:
                console.print(f"Ignore patterns: {', '.join(ignore)}")

        # Create output directory
        output_path = Path(out)
        output_path.mkdir(parents=True, exist_ok=True)

        # Initialize scanner
        with console.status("[bold green]Initializing scanner...") as status:
            scanner = Scanner(max_files=max_files, threads=threads)

        # Perform scan
        with Progress(
            SpinnerColumn(),
            TextColumn("[progress.description]{task.description}"),
            console=console,
        ) as progress:
            task = progress.add_task("Scanning codebase...", total=None)

            result = scanner.scan(
                path=path,
                ignore_patterns=list(ignore) if ignore else None,
                languages=languages_list
            )

            progress.update(task, completed=True)

        # Display summary
        if verbose:
            _display_scan_summary(result)

        # Generate reports
        with console.status("[bold green]Generating reports...") as status:
            generate_reports(result, output_path)

        # Success message
        console.print(f"[green]✓[/green] Analysis complete! Reports generated in: {out}")
        console.print(f"[blue]→[/blue] Open [link=file://{output_path}/index.html]{output_path}/index.html[/link] to view results")

    except Exception as e:
        console.print(f"[red]Error:[/red] {e}", err=True)
        sys.exit(1)


def _display_scan_summary(result):
    """Display a summary of the scan results in the console."""
    table = Table(title="Scan Summary")
    table.add_column("Metric", style="cyan")
    table.add_column("Value", style="magenta")

    table.add_row("Total Files", str(result.total_files))
    table.add_row("Total Lines", str(result.total_lines))
    table.add_row("Duration", ".2f")
    table.add_row("Overall Coverage", ".1f")

    console.print(table)

    # Language breakdown
    if result.language_summaries:
        lang_table = Table(title="Language Breakdown")
        lang_table.add_column("Language", style="cyan")
        lang_table.add_column("Files", style="yellow")
        lang_table.add_column("Lines", style="yellow")
        lang_table.add_column("Functions", style="green")
        lang_table.add_column("Coverage %", style="green")

        for lang, summary in result.language_summaries.items():
            lang_table.add_row(
                lang.title(),
                str(summary.files),
                str(summary.lines),
                f"{summary.documented_functions}/{summary.functions}",
                ".1f"
            )

        console.print(lang_table)


if __name__ == '__main__':
    cli()
