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
    "go",
)


def load() -> list:
    return [importlib.import_module(f"{__package__}.{name}").STACK for name in MODULES]


def capabilities_of(stack) -> frozenset:
    """The only capability lookup. ``stack`` is a Stack instance, or a Stack id or module name.

    Dotted detail capabilities (``entry_point.job``) are part of the set. Unknown stacks give an empty set.
    """
    if isinstance(stack, str):
        for st in load():
            if stack in (st.id, st.id.replace("-", "_")):
                return st.capabilities
        return frozenset()
    return frozenset(getattr(type(stack), "capabilities", frozenset()))
