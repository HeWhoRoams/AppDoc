"""Command-line interface for AppDoc."""

import os
import sys
import webbrowser
from pathlib import Path
from typing import List, Optional

import click
import questionary
import yaml
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
def init():
    """Initialize a new AppDoc configuration interactively.

    This command will prompt you for configuration options and create
    a .appdoc.yml config file in the current directory.
    """
    console.print("[bold blue]AppDoc Configuration Wizard[/bold blue]")
    console.print("Let's set up your AppDoc configuration.\n")

    try:
        # Gather configuration options
        output_dir = questionary.text(
            "Output directory for reports:",
            default="./appdoc_output"
        ).ask()

        if not output_dir:
            console.print("[red]Cancelled by user.[/red]")
            return

        max_files = questionary.text(
            "Maximum number of files to process (leave empty for unlimited):",
            validate=lambda text: text.isdigit() or text == ""
        ).ask()

        max_files = int(max_files) if max_files else None

        threads = questionary.text(
            "Number of threads (leave empty for auto-detect):",
            validate=lambda text: text.isdigit() or text == ""
        ).ask()

        threads = int(threads) if threads else None

        languages_input = questionary.text(
            "Languages to analyze (comma-separated, leave empty for all):"
        ).ask()

        languages = [lang.strip() for lang in languages_input.split(',')] if languages_input else None

        ignore_patterns_input = questionary.text(
            "Ignore patterns (comma-separated globs):",
            default="*.pyc,__pycache__/,node_modules/"
        ).ask()

        ignore_patterns = [pattern.strip() for pattern in ignore_patterns_input.split(',')] if ignore_patterns_input else []

        verbose = questionary.confirm("Enable verbose output?", default=False).ask()

        # Generate config dict
        config = {}

        if output_dir and output_dir != "./appdoc_output":
            config['output'] = output_dir

        if max_files:
            config['max_files'] = max_files

        if threads:
            config['threads'] = threads

        if languages:
            config['languages'] = languages

        if ignore_patterns:
            config['ignore'] = ignore_patterns

        if verbose:
            config['verbose'] = verbose

        # Write config file
        config_file = Path('.appdoc.yml')
        with open(config_file, 'w') as f:
            yaml.dump(config, f, default_flow_style=False, sort_keys=False)

        console.print(f"\n[green]✓[/green] Configuration saved to {config_file}")
        console.print("You can now run [bold]appdoc scan .[/bold] to analyze your project.")

    except KeyboardInterrupt:
        console.print("\n[red]Configuration cancelled.[/red]")
        return
    except Exception as e:
        console.print(f"[red]Error creating configuration:[/red] {e}")
        return


@cli.command()
def docs():
    """Open the AppDoc documentation site.

    This command opens the MkDocs documentation site in your default browser.
    If the docs are not currently being served, it will attempt to start a
    development server.

    Examples:
        appdoc docs                      # Open docs in browser
        cd docs && mkdocs serve --open   # Start server manually if needed
    """
    docs_url = "http://localhost:8000"

    # Try to open in browser first
    try:
        webbrowser.open(docs_url)
        console.print(f"[green]Opening documentation at:[/green] {docs_url}")
    except Exception as e:
        console.print(f"[yellow]Could not open browser automatically:[/yellow] {e}")
        console.print(f"Please visit: {docs_url}")

    # Optionally suggest running mkdocs serve
    console.print(
        "\n[dim]If docs don't load, ensure MkDocs is running:[/dim]\n"
        "  [blue]mkdocs serve[/blue]  # Start development server\n"
        "  [blue]mkdocs build[/blue]   # Build static site\n"
    )


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

    Examples:
        appdoc scan . ./reports                    # Scan current dir, output to ./reports
        appdoc scan /path/to/project output_dir    # Scan specific project
        appdoc scan . out --languages python,js   # Only analyze Python and JavaScript
        appdoc scan . out --ignore "*.tmp" --ignore "__pycache__/" --verbose
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
