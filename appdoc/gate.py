"""`appdoc gate`: the CI tripwire for docs-as-code (remediation plan 2.6, 6.1).

Regenerates the Facts and compares them with the committed ``facts.json``; only when they agree does it run
the Check. Exit codes: 0 pass, 1 tool error (no committed facts.json, unreadable), 2 Facts changed (or the Check
failed), 3 AppDoc upgraded (the Facts schema differs).

The regeneration runs in memory with the committed output folder excluded from the scan, exactly as the run that
wrote ``facts.json`` excluded it, so the comparison sees the same files. ``<target>/.appdoc-regen/`` is the fixed
scratch name AppDoc reserves: a leftover one is removed before the scan (it would be scanned as AppDoc output)
and again in ``finally``. The cache is never used, so a stale ``.appdoc-cache.json`` cannot mask a code change.

Compared bytes are the canonical Facts text with the fields that belong to the checkout, not the code, neutralised
on both sides: ``target.commit``, ``target.history`` and the git ``ownership`` Facts (a CI clone is usually
shallow, and the docs are committed after the commit they describe). A version difference in ``provenance.json``
is informational only.
"""

from __future__ import annotations

import difflib
import json
import os
import shutil
import sys

from . import __version__, check, extract, version

REGEN = ".appdoc-regen"
FACTS = "facts.json"
DIFF_CAP = 200

EXIT_OK, EXIT_ERROR, EXIT_CHANGED, EXIT_UPGRADED = 0, 1, 2, 3


def comparable(doc: dict) -> str:
    """The Facts text the gate compares: canonical, without the checkout-dependent fields."""
    doc = json.loads(json.dumps(doc))
    target = doc.get("target")
    if isinstance(target, dict):
        target["commit"] = None
        target["history"] = "none"
    doc["facts"] = [f for f in doc.get("facts", []) if f.get("kind") != "ownership"]
    return json.dumps(doc, sort_keys=True, indent=1, ensure_ascii=False) + "\n"


def _diff(committed: str, regenerated: str, name: str) -> list[str]:
    lines = list(difflib.unified_diff(committed.splitlines(), regenerated.splitlines(),
                                      f"committed {name}", f"regenerated {name}", n=1, lineterm=""))
    if len(lines) > DIFF_CAP:
        return lines[:DIFF_CAP] + [f"... {len(lines) - DIFF_CAP} more diff lines not shown"]
    return lines


def _say(msg: str) -> None:
    print(msg, flush=True)


def run(target: str, out_dir: str, require_audit: bool = False, strict: bool = False,
        workers: int | None = None) -> int:
    target = os.path.abspath(target)
    facts_path = os.path.join(out_dir, FACTS)
    rel = os.path.relpath(out_dir, target).replace(os.sep, "/")
    if not os.path.isfile(facts_path):
        print(f"appdoc gate: the committed {rel}/{FACTS} is missing. Generate the AppDoc docs in a session and "
              f"commit {rel}/ before enabling the gate.", file=sys.stderr)
        return EXIT_ERROR
    try:
        with open(facts_path, encoding="utf-8") as fh:
            committed = json.load(fh)
        if not isinstance(committed, dict):
            raise ValueError("not a JSON object")
    except (OSError, ValueError) as exc:
        print(f"appdoc gate: the committed {rel}/{FACTS} is not readable: {exc}", file=sys.stderr)
        return EXIT_ERROR

    regen_dir = os.path.join(target, REGEN)
    shutil.rmtree(regen_dir, ignore_errors=True)
    try:
        regen_text, _ = extract.extract(target, out_dir, workers=workers, use_cache=False, no_ownership=True)
        regenerated = json.loads(regen_text)
        if committed.get("schema") != regenerated.get("schema"):
            _say(f"appdoc gate: AppDoc upgraded: the committed Facts are {committed.get('schema')}, "
                 f"AppDoc {__version__} writes {regenerated.get('schema')}. This is not a code change. "
                 f"Re-run `appdoc extract`, refresh the docs to the current template (see the CHANGELOG upgrade "
                 f"notes) and commit {rel}/.")
            return EXIT_UPGRADED
        a, b = comparable(committed), comparable(regenerated)
        if a != b:
            _say(f"appdoc gate: Facts changed: the code changed since the docs were last generated. Re-run the "
                 f"AppDoc skill in a session to refresh the docs, then commit the updated {rel}/ files.")
            for line in _diff(a, b, FACTS):
                _say(line)
            return EXIT_CHANGED
    finally:
        shutil.rmtree(regen_dir, ignore_errors=True)

    prov = version.read_provenance(out_dir)
    if prov:
        now = version.provenance()
        if (prov.get("generator"), prov.get("bundle")) != (now["generator"], now["bundle"]):
            _say(f"appdoc gate: informational: the committed Facts were written by AppDoc {prov.get('generator')} "
                 f"(bundle {prov.get('bundle')}); this is AppDoc {now['generator']} (bundle {now['bundle']}). "
                 "The Facts are identical, so no action is needed.")
    _say("appdoc gate: the Facts match the committed facts.json; running the Check.")
    return check.run(target, out_dir, require_audit, strict)
