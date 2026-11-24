"""Run AppDoc from any directory:  python <skill folder>/run_appdoc.py <command> <target> [options]  (python -m appdoc --help lists the commands)"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from appdoc.__main__ import main  # noqa: E402

if __name__ == "__main__":
    sys.exit(main())
