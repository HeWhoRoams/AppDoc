"""R71.D7: the import graph of appdoc/ follows the layering below, so a split (check.py -> fingerprint.py, seal.py)
cannot grow a cycle back.

An import edge `A -> B` is allowed when RANK[A] > RANK[B]. The spine, lowest first:

    textutil < template_spec < register/notes < fingerprint < fill < check < seal/audit_plan/upgrade < __main__

The other modules (facts, scan, stacks, smells, extract, render, ...) sit where their own imports put them. A new
module must be given a rank here; a new edge that points up needs an entry in EXCEPTIONS with its reason. A
function-local `from . import` is allowed only where LOCAL names it (a top-level import is the default).
Stdlib only: the edges are read from the AST, nothing is imported.
"""

import ast
import os
import unittest

from appdoc.textutil import read_text

ROOT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "appdoc")

RANK = {
    # 0: no appdoc imports
    "textutil": 0, "textnorm": 0, "docmodel": 0, "facts": 0, "citations": 0, "secrets": 0, "context": 0,
    "integration": 0,
    # shared .NET XML config reader (stdlib only, returns plain data; stacks and generic call it)
    "dotnetcfg": 0,
    # 1
    "template_spec": 1, "scan": 1, "version": 1, "stacks.base": 1, "summary": 1,
    # 2: register and notes are peers; workflow is the text tables only
    "register": 2, "notes": 2, "smells": 2, "stacks.integrations": 2, "workflow": 2,
    # 3
    "fingerprint": 3, "stacks.aspnet": 3, "stacks.classic_asp": 3, "stacks.generic": 3, "stacks.go": 3,
    "stacks.java_spring": 3, "stacks.node_express": 3, "stacks.python_flask": 3, "render.markdown": 3,
    # 4
    "fill": 4, "stacks.aspnet_core": 4,
    # 5
    "check": 5, "stacks": 5, "render.page": 5, "render": 5,
    # 6: above the Check
    "seal": 6, "audit_plan": 6, "extract": 6,
    # 7
    "upgrade": 7, "gate": 7,
    # 8
    "__main__": 8,
}

# (importer, imported) -> why an edge that does not point down is allowed.
EXCEPTIONS = {
    ("fill", "check"): "fill._appendix_a and fill.fill_counts need check.defined_ids and check.coverage_detail "
                       "(the table readers live with the rules); imported inside the two functions because the Check "
                       "imports fill. Move those readers below fill to remove this.",
    ("check", "audit_plan"): "check._c19_plan reads the plan through audit_plan; audit_plan imports the Check "
                             "(document ids, uncited smells); imported inside the function.",
    ("register", "audit_plan"): "register.appendix_markdown prints audit_plan.progress; audit_plan sits above the Check, "
                                "which imports register; imported inside the function.",
}

# (module, imported) -> why a function-local import is allowed (every one of them is also in EXCEPTIONS, or is the
# lazy command loading of __main__).
LOCAL = {
    ("fill", "check"): EXCEPTIONS[("fill", "check")],
    ("check", "audit_plan"): EXCEPTIONS[("check", "audit_plan")],
    ("register", "audit_plan"): EXCEPTIONS[("register", "audit_plan")],
}
LOCAL_MODULES = {
    "__main__": "each subcommand imports what it runs on demand, so `appdoc --help` and `version` load nothing else "
                "and an ImportError becomes 'not available yet' for that command only",
}


def _modules():
    out = {}
    for dirpath, _, files in os.walk(ROOT):
        for f in sorted(files):
            if f.endswith(".py"):
                path = os.path.join(dirpath, f)
                parts = os.path.relpath(path, ROOT)[:-3].split(os.sep)
                if parts[-1] == "__init__":
                    parts = parts[:-1]
                if parts:   # the top-level package itself holds only __version__
                    out[".".join(parts)] = (path, f == "__init__.py")
    return out


def _is_module(name: str) -> bool:
    base = os.path.join(ROOT, *name.split("."))
    return os.path.isfile(base + ".py") or os.path.isfile(os.path.join(base, "__init__.py"))


def _edges(mod: str, path: str, is_pkg: bool):
    """(imported module, inside a function) for each relative import of `path`."""
    tree = ast.parse(read_text(path))
    parts = mod.split(".")
    pkg = parts if is_pkg else parts[:-1]
    found = []

    def visit(node, in_func):
        for child in ast.iter_child_nodes(node):
            inner = in_func or isinstance(child, (ast.FunctionDef, ast.AsyncFunctionDef))
            if isinstance(child, ast.ImportFrom) and child.level:
                base = pkg[:len(pkg) - (child.level - 1)]
                tgt = base + (child.module.split(".") if child.module else [])
                names = [a.name for a in child.names]
                subs = [".".join(tgt + [n]) for n in names if _is_module(".".join(tgt + [n]))]
                if subs:
                    found.extend((s, in_func) for s in subs)
                if tgt and (not subs or len(subs) < len(names)):
                    found.append((".".join(tgt), in_func))
            visit(child, inner)

    visit(tree, False)
    return found


class LayeringTests(unittest.TestCase):
    def test_every_module_has_a_rank(self):
        self.assertEqual(sorted(set(_modules()) - set(RANK)), [], "give the new module a rank in RANK")
        self.assertEqual(sorted(set(RANK) - set(_modules())), [], "RANK names a module that is gone")

    def test_spine_order(self):
        spine = [["textutil"], ["template_spec"], ["register", "notes"], ["fingerprint"], ["fill"], ["check"],
                 ["seal", "audit_plan", "upgrade"], ["__main__"]]
        ranks = [[RANK[m] for m in layer] for layer in spine]
        for low, high in zip(ranks, ranks[1:]):
            self.assertLess(max(low), min(high))

    def test_imports_point_down(self):
        bad = []
        for mod, (path, is_pkg) in _modules().items():
            for dst, _ in _edges(mod, path, is_pkg):
                if dst not in RANK or dst == mod:
                    continue
                if RANK[mod] <= RANK[dst] and (mod, dst) not in EXCEPTIONS:
                    bad.append(f"{mod} -> {dst}")
        self.assertEqual(sorted(set(bad)), [], "an import points up or sideways; fix it or list it in EXCEPTIONS "
                                               "with a reason")

    def test_exceptions_are_still_used(self):
        used = {(m, d) for m, (p, k) in _modules().items() for d, _ in _edges(m, p, k)}
        self.assertEqual(sorted(set(EXCEPTIONS) - used), [], "an exception is no longer needed: delete it")

    def test_function_local_imports_are_named(self):
        bad = []
        for mod, (path, is_pkg) in _modules().items():
            if mod in LOCAL_MODULES:
                continue
            for dst, local in _edges(mod, path, is_pkg):
                if local and (mod, dst) not in LOCAL:
                    bad.append(f"{mod} imports {dst} inside a function")
        self.assertEqual(sorted(set(bad)), [], "import at the top, or name the reason in LOCAL")


if __name__ == "__main__":
    unittest.main()
