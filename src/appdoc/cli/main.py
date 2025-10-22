"""AppDoc CLI entrypoint and argument routing."""

from appdoc.cli import commands


def main():
    """Primary entry point for AppDoc CLI."""
    parser = commands.build_parser()
    args = parser.parse_args()

    # If no subcommand was provided
    if not hasattr(args, "func"):
        parser.print_help()
        return

    # Execute the selected subcommand
    args.func(args)


if __name__ == "__main__":
    main()
