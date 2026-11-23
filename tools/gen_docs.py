"""Write the generated parts of AppDoc's own docs from code (remediation plan 2.6, 6.3).

    python tools/gen_docs.py            # rewrite the blocks
    python tools/gen_docs.py --check    # exit 1 when any block is stale (CI, release)

A block is the text between `<!-- appdoc-self:generated NAME -->` and `<!-- /appdoc-self:generated NAME -->`
(Markdown) or the same markers after a `# ` (YAML). Blocks:

    README.md                 commands, rules, facts-schema
    SKILL.md                  run-commands
    ci/appdoc-docs-gate.yml   gate-header, gate-pin

The sources are `__main__.build_parser()`, `check.RULES`,
`facts.SCHEMA`/`KINDS`, `workflow.SKILL_STEPS` and `gate`'s exit codes. The gate pin is `v<version>` for a release
version; a `.dev` version keeps the pin it has (the last tag that exists). Stdlib only.
"""

from __future__ import annotations

import argparse
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, ROOT)

from appdoc import __version__, check, facts, gate, workflow  # noqa: E402
from appdoc import __main__ as cli  # noqa: E402
from appdoc import template_spec as spec  # noqa: E402
from appdoc.textnorm import normalize_newlines  # noqa: E402

BLOCK_RE = re.compile(
    r"^(?P<indent>[ \t]*)(?P<open>(?:<!-- |# )appdoc-self:generated (?P<name>[\w-]+)(?: -->)?)[ \t]*\n"
    r"(?P<body>.*?)"
    r"^(?P<close>[ \t]*(?:<!-- |# )/appdoc-self:generated (?P=name)(?: -->)?)[ \t]*$",
    re.S | re.M)
PIN_RE = re.compile(r"APPDOC_REF: (v\d+\.\d+\.\d+)")


def is_release(version: str | None = None) -> bool:
    version = __version__ if version is None else version
    return ".dev" not in version and bool(re.fullmatch(r"\d+\.\d+\.\d+", version))


def _cell(text: str) -> str:
    return text.replace("|", "\\|")


# ----------------------------------------------------------------------------- README

def _subparsers():
    parser = cli.build_parser()
    for action in parser._actions:
        if isinstance(action, argparse._SubParsersAction):
            return action.choices
    raise RuntimeError("no subcommands")


def _option(action) -> str:
    flag = action.option_strings[0]
    if action.nargs == 0:
        return f"`{flag}`"
    return f"`{flag} {(action.metavar or action.dest).upper()}`"


def commands(_current: str) -> str:
    rows = ["| Command | Options | What it does |", "|---|---|---|"]
    for name, sp in _subparsers().items():
        opts = [_option(a) for a in sp._actions if a.option_strings and "-h" not in a.option_strings]
        rows.append(f"| `appdoc {name} <target>` | {', '.join(opts) or ''} | {_cell(sp.description or '')} |")
    return "\n".join(rows)


def _kind(rule: str) -> str:
    flags = next(r.flags for r in check.RULES if r.id == rule)
    if flags == ("advisory",):
        return "advisory before template 2.7; fails from 2.7"
    if "advisory" in flags and "strict" in flags:
        return "advisory; fails under `--strict`"
    if "strict" in flags:
        return "part fails only under `--strict`"
    return "fails"


def rules(_current: str) -> str:
    out = [f"Rules {check.RULE_RANGE}. Each rule fails or is not reported; there is no score.", "",
           "| Rule | Name | Fails when | Kind |", "|---|---|---|---|"]
    for r in check.RULES:
        out.append(f"| {r.id} | {r.title} | {_cell(r.summary)} | {_kind(r.id)} |")
    out += ["", "Previews of template 2.7 rules. On a template 2.4 document these are advisories, listed in "
            "`check-report.md` as \"fails from template 2.7\"; they fail only on a document stamped 2.7:", ""]
    out += [f"- {r.id}: {r.preview}" for r in check.RULES if r.preview]
    return "\n".join(out)


def facts_schema(_current: str) -> str:
    return (f"Schema `{facts.SCHEMA}`. Kinds: " + ", ".join(f"`{k}`" for k in facts.KINDS)
            + ". The allowed `detail` keys of each kind are `facts.DETAIL_KEYS`.")


# ----------------------------------------------------------------------------- SKILL.md

def run_commands(_current: str) -> str:
    out = ["Commands, in order (generated from `appdoc/workflow.py`):", ""]
    for n, (name, command, note) in enumerate(workflow.run_commands(), 1):
        out.append(f"{n}. {name}: `{command}` ({note})")
    return "\n".join(out)


# ----------------------------------------------------------------------------- gate YAML

def gate_header(_current: str) -> str:
    return "\n".join([
        f"#   Pinned release writes Facts schema {facts.SCHEMA}; the Check runs rules {check.RULE_RANGE}.",
        "#   `appdoc gate` regenerates the Facts in memory (no cache) and compares them with the committed",
        "#   docs/appdoc/facts.json, then runs the Check. Exit codes:",
        f"#     {gate.EXIT_OK}  the Facts match and the Check passes",
        f"#     {gate.EXIT_ERROR}  tool error (for example the committed facts.json is missing)",
        f"#     {gate.EXIT_CHANGED}  Facts changed (the code changed since the docs were generated; prints a diff of at "
        f"most {gate.DIFF_CAP} lines), or the Check failed",
        f"#     {gate.EXIT_UPGRADED}  AppDoc upgraded (the committed Facts schema differs from the pinned AppDoc's; "
        "re-extract and refresh the docs)",
        "#   A difference in the AppDoc version recorded in provenance.json is informational only.",
    ])


def gate_pin(current: str) -> str:
    m = PIN_RE.search(current)
    if is_release():
        return f"APPDOC_REF: v{__version__}"
    if not m:
        raise SystemExit("gen_docs: the gate pin must be APPDOC_REF: vX.Y.Z (a dev version keeps the existing pin)")
    return m.group(0)


GENERATORS = {
    "README.md": {"commands": commands, "rules": rules, "facts-schema": facts_schema},
    "SKILL.md": {"run-commands": run_commands},
    os.path.join("ci", "appdoc-docs-gate.yml"): {"gate-header": gate_header, "gate-pin": gate_pin},
}


def render_file(text: str, relpath: str, generators: dict) -> str:
    seen = set()

    def repl(m):
        name = m.group("name")
        gen = generators.get(name)
        if gen is None:
            raise SystemExit(f"gen_docs: {relpath} has a block '{name}' with no generator")
        seen.add(name)
        indent = m.group("indent")
        body = gen(re.sub(r"^" + re.escape(indent), "", m.group("body"), flags=re.M))
        body = "\n".join((indent + line) if line else line for line in body.split("\n"))
        return f"{indent}{m.group('open')}\n{body}\n{m.group('close')}"

    new = BLOCK_RE.sub(repl, text)
    missing = set(generators) - seen
    if missing:
        raise SystemExit(f"gen_docs: {relpath} lacks the block(s): {', '.join(sorted(missing))}")
    return new


def generate(root: str = ROOT) -> dict:
    """{relative path: (current text, generated text)} for every file with blocks."""
    out = {}
    for rel, generators in GENERATORS.items():
        path = os.path.join(root, rel)
        with open(path, encoding="utf-8", newline="") as fh:
            current = fh.read()
        crlf = "\r\n" in current
        text = render_file(normalize_newlines(current), rel, generators)
        out[rel] = (current, text.replace("\n", "\r\n") if crlf else text)
    return out


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description="Write the generated blocks of README.md, SKILL.md and the gate YAML.")
    ap.add_argument("--check", action="store_true", help="exit 1 when a block is stale; write nothing")
    args = ap.parse_args(argv)
    stale = []
    for rel, (current, new) in generate().items():
        if current != new:
            stale.append(rel)
            if not args.check:
                with open(os.path.join(ROOT, rel), "w", encoding="utf-8", newline="") as fh:
                    fh.write(new)
    if args.check and stale:
        print("gen_docs: stale generated blocks in: " + ", ".join(stale) + " (run python tools/gen_docs.py)",
              file=sys.stderr)
        return 1
    for rel in stale:
        print(f"updated {rel}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
