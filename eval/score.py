"""Score an AppDoc document against a hand-verified answer key.

    python eval/score.py <repo-key> <application-documentation.md> [--out eval/results]

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


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("repo", help="answer-key name, e.g. gitea")
    ap.add_argument("document", help="path to application-documentation.md")
    ap.add_argument("--out", default=os.path.join(HERE, "results"), help="directory for the JSON result")
    args = ap.parse_args(argv)

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
