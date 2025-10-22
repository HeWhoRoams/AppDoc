# src/appdoc/__main__.py
"""
Allows `python -m appdoc` to behave the same as `python -m appdoc.cli`
"""
from appdoc.cli.main import main

if __name__ == "__main__":
    main()
