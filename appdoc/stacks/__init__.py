"""Stack registry. Order is fixed; every detected Stack runs, and ``generic`` always runs."""

from __future__ import annotations

import importlib

# Every module exposes a module-level ``STACK`` instance.
MODULES = (
    "classic_asp",
    "aspnet",
    "aspnet_core",
    "java_spring",
    "python_flask",
    "node_express",
)


def load() -> list:
    return [importlib.import_module(f"{__package__}.{name}").STACK for name in MODULES]
