"""Score an AppDoc document against a hand-verified answer key.

    python eval/score.py <repo-key> <application-documentation.md> [--out eval/results]
    python eval/score.py --all [--root DIR] [--require-clones] [--update-baseline]

`--all` is the release gate (tools/release.py): it scores the committed example of every narrative key
(`examples/current/<repo>/`; `examples/previous/<repo>/` when there is no current) against `eval/narrative-baseline.json` and
exits 1 when an item scores below its baseline or a key cites a file or line the clone does not have. It needs
local clones of the example repositories under `--root` (or `APPDOC_EVAL_ROOT`), one folder per key name; with
no root or no clone it prints why and exits 0 without scoring, or exits 1 with `--require-clones` (the release run). `--update-baseline` rewrites the baseline from the
examples and needs no clones.

An item is Present when a Citation covering `must_cite` and every `must_contain` term occur in the
same section block (the item's `section` or one of its `alt_sections`). It is Partial when only the
Citation, or only the terms, occur somewhere in the document. Otherwise it is Absent. Items with
`"status": "retired"` are skipped.

A term may list alternatives joined by " OR ". `must_not_contain` terms veto Present for a block.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from datetime import date

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))

from appdoc import docmodel as dm  # noqa: E402
from appdoc.citations import find_citations, parse_span  # noqa: E402

PRESENT, PARTIAL, ABSENT, RETIRED = "Present", "Partial", "Absent", "Retired"
RANK = {ABSENT: 0, PARTIAL: 1, PRESENT: 2}
KEYS_DIR = os.path.join(HERE, "answer-keys")
NARRATIVE_BASELINE = os.path.join(HERE, "narrative-baseline.json")
EVAL_ROOT_ENV = "APPDOC_EVAL_ROOT"


def _has_term(haystack: str, term: str) -> bool:
    return any(alt.strip().casefold() in haystack for alt in term.split(" OR "))


def _covers(cite, path: str, start: int | None, end: int | None) -> bool:
    if cite.path != path:
        return False
    if start is None:
        return True
    return cite.start is not None and cite.start <= end and cite.end >= start


class Document:
    def __init__(self, raw: str):
        self.lines = dm.strip_comments(raw).splitlines()
        self.heads = dm.headings(self.lines)
        self.cites = find_citations("\n".join(self.lines))

    def block(self, key: str):
        """(text casefolded, citations) of a numbered section including its subsections."""
        h = self.heads.get(key)
        if h is None:
            return "", []
        text = "\n".join(self.lines[h.idx:h.end]).casefold()
        return text, [c for c in self.cites if h.idx < c.doc_line <= h.end]


def score_item(item: dict, doc: Document) -> dict:
    res = {"id": item["id"], "section": item["section"], "status": ABSENT, "found_in": None, "detail": ""}
    if item.get("status") == "retired":
        res["status"] = RETIRED
        return res
    cite_key = parse_span(item["must_cite"]) if item.get("must_cite") else None
    terms = item.get("must_contain", [])
    vetoes = item.get("must_not_contain", [])
    if not cite_key and not terms:
        raise ValueError(f"{item['id']}: needs must_cite or must_contain")

    def cite_ok(cites) -> bool:
        return cite_key is None or any(_covers(c, *cite_key) for c in cites)

    for sec in [item["section"], *item.get("alt_sections", [])]:
        text, cites = doc.block(sec)
        if (cite_ok(cites) and all(_has_term(text, t) for t in terms)
                and not any(_has_term(text, v) for v in vetoes)):
            res.update(status=PRESENT, found_in=sec)
            return res

    whole = "\n".join(doc.lines).casefold()
    cite_any = cite_key is not None and cite_ok(doc.cites)
    terms_any = bool(terms) and all(_has_term(whole, t) for t in terms)
    parts = []
    if cite_any:
        parts.append("citation found elsewhere")
    if terms_any:
        parts.append("terms found elsewhere")
    missing = [t for t in terms if not _has_term(whole, t)]
    if missing:
        parts.append("terms absent: " + "; ".join(missing[:4]) + ("..." if len(missing) > 4 else ""))
    if cite_key and not cite_any:
        parts.append("no covering citation")
    res["detail"] = ", ".join(parts)
    if cite_any or terms_any:
        res["status"] = PARTIAL
    return res


def score(key: list[dict], raw: str) -> dict:
    doc = Document(raw)
    items = [score_item(it, doc) for it in key]
    counts = {s: sum(i["status"] == s for i in items) for s in (PRESENT, PARTIAL, ABSENT, RETIRED)}
    counts["scorable"] = len(items) - counts[RETIRED]
    return {"summary": counts, "items": items}


def narrative_keys(keys_dir: str = KEYS_DIR) -> dict:
    """{repo: key} for the narrative keys (JSON lists); extractor keys (JSON objects) are not read here."""
    keys = {}
    for fn in sorted(os.listdir(keys_dir)):
        if fn.endswith(".json"):
            with open(os.path.join(keys_dir, fn), encoding="utf-8") as fh:
                data = json.load(fh)
            if isinstance(data, list):
                keys[fn[:-5]] = data
    return keys


def example_document(repo: str, examples_dir: str | None = None) -> str:
    """Path of the committed example Narrative scored for `repo` (examples/current/<repo> wins over examples/previous/<repo>)."""
    base = examples_dir or os.path.join(os.path.dirname(HERE), "examples")
    for rel in (os.path.join("current", repo), os.path.join("previous", repo)):
        path = os.path.join(base, rel, "application-documentation.md")
        if os.path.isfile(path):
            return path
    raise FileNotFoundError(f"no example Narrative for {repo!r} under {base}")


def score_examples(keys: dict | None = None, examples_dir: str | None = None) -> dict:
    """{repo: {item id: status}} for every narrative key against its committed example."""
    out = {}
    for repo, key in (narrative_keys() if keys is None else keys).items():
        with open(example_document(repo, examples_dir), encoding="utf-8") as fh:
            out[repo] = {i["id"]: i["status"] for i in score(key, fh.read())["items"]}
    return out


def narrative_regressions(baseline: dict, current: dict) -> list[str]:
    """One message per item that scores below its baseline, or that the baseline has and the key lost."""
    bad = []
    for repo, items in baseline.items():
        for item_id, was in items.items():
            now = current.get(repo, {}).get(item_id)
            if now is None:
                bad.append(f"{repo} {item_id}: in the baseline ({was}) but no longer in the key")
            elif was != RETIRED and now != RETIRED and RANK[now] < RANK[was]:
                bad.append(f"{repo} {item_id}: {now}, was {was} in the baseline")
    return bad


def citation_problems(key: list[dict], clone: str) -> list[str]:
    """Items whose `must_cite` names a file the clone lacks or a line past its end."""
    bad = []
    for item in key:
        if not item.get("must_cite"):
            continue
        path, start, end = parse_span(item["must_cite"])
        full = os.path.join(clone, *path.split("/"))
        if not os.path.isfile(full):
            bad.append(f"{item['id']}: {path} is not in the clone")
            continue
        if start is not None:
            with open(full, "rb") as fh:
                n = sum(1 for _ in fh)
            if end > n:
                bad.append(f"{item['id']}: {path} has {n} lines, the key cites up to {end}")
    return bad


def run_all(root: str | None, update: bool = False, examples_dir: str | None = None,
            require_clones: bool = False) -> int:
    keys = narrative_keys()
    current = score_examples(keys, examples_dir)
    if update:
        with open(NARRATIVE_BASELINE, "w", encoding="utf-8", newline="\n") as fh:
            json.dump(current, fh, indent=2, sort_keys=True)
            fh.write("\n")
        print(f"wrote {os.path.relpath(NARRATIVE_BASELINE, os.path.dirname(HERE))}: "
              f"{sum(len(v) for v in current.values())} items in {len(current)} keys")
        return 0
    if require_clones:
        absent = [r for r in keys if not root or not os.path.isdir(os.path.join(root, r))]
        if absent:
            print(f"narrative eval FAILED: --require-clones is set and {EVAL_ROOT_ENV}"
                  f"{'=' + root if root else ' is not set'} has no clone of: {', '.join(absent)}")
            return 1
    if not root:
        print(f"narrative eval skipped: {EVAL_ROOT_ENV} is not set. Point it at the folder holding local clones of "
              f"{', '.join(keys)} (one folder per name) to score the narrative answer keys.")
        return 0
    clones = {r: os.path.join(root, r) for r in keys if os.path.isdir(os.path.join(root, r))}
    if not clones:
        print(f"narrative eval skipped: no clone of {', '.join(keys)} under {root}; nothing was scored.")
        return 0
    with open(NARRATIVE_BASELINE, encoding="utf-8") as fh:
        baseline = json.load(fh)
    bad = []
    for repo in keys:
        if repo not in clones:
            print(f"narrative eval: {repo}: no clone under {root}; skipped")
            continue
        bad += [f"{repo} {m}" for m in citation_problems(keys[repo], clones[repo])]
        bad += narrative_regressions({repo: baseline.get(repo, {})}, {repo: current[repo]})
        counts = {s: sum(v == s for v in current[repo].values()) for s in (PRESENT, PARTIAL, ABSENT, RETIRED)}
        print(f"narrative eval: {repo}: Present {counts[PRESENT]}, Partial {counts[PARTIAL]}, "
              f"Absent {counts[ABSENT]}, Retired {counts[RETIRED]}")
    for m in bad:
        print(f"REGRESSION {m}")
    print(f"narrative eval: {len(clones)} of {len(keys)} keys checked, {len(bad)} problems")
    return 1 if bad else 0


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("repo", nargs="?", help="answer-key name, e.g. gitea")
    ap.add_argument("document", nargs="?", help="path to application-documentation.md")
    ap.add_argument("--out", default=os.path.join(HERE, "results"), help="directory for the JSON result")
    ap.add_argument("--all", action="store_true", help="release gate: every key against its committed example")
    ap.add_argument("--root", default=os.environ.get(EVAL_ROOT_ENV), help=f"folder holding the clones (${EVAL_ROOT_ENV})")
    ap.add_argument("--update-baseline", action="store_true", help="with --all: rewrite eval/narrative-baseline.json")
    ap.add_argument("--require-clones", action="store_true",
                    help="with --all: exit 1 instead of skipping when the root or a clone is missing")
    args = ap.parse_args(argv)
    if args.all:
        return run_all(args.root, args.update_baseline, require_clones=args.require_clones)
    if not args.repo or not args.document:
        ap.error("give <repo-key> and <document>, or --all")

    with open(os.path.join(HERE, "answer-keys", args.repo + ".json"), encoding="utf-8") as fh:
        key = json.load(fh)
    with open(args.document, encoding="utf-8") as fh:
        result = score(key, fh.read())
    result.update(repo=args.repo, document=os.path.abspath(args.document), date=date.today().isoformat())

    print(f"{args.repo}: {args.document}")
    print(f"{'ID':<7}{'Section':<9}{'Status':<9}Detail")
    for i in result["items"]:
        where = f"in {i['found_in']}" if i["found_in"] else i["detail"]
        print(f"{i['id']:<7}{i['section']:<9}{i['status']:<9}{where}")
    s = result["summary"]
    print(f"Present {s[PRESENT]}, Partial {s[PARTIAL]}, Absent {s[ABSENT]}, Retired {s[RETIRED]} "
          f"(of {s['scorable']} scorable)")

    os.makedirs(args.out, exist_ok=True)
    path = os.path.join(args.out, f"{result['date']}-{args.repo}.json")
    with open(path, "w", encoding="utf-8", newline="\n") as fh:
        json.dump(result, fh, indent=2)
        fh.write("\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
