"""Determinism harness (P3, R13, R14): the same Target gives the same bytes, wherever and however it runs.

1. run twice            facts.json and facts-summary.md are byte-identical (every sample and corpus Target)
2. idempotence          fill(fill(x)) == fill(x); seal twice is a no-op; build on a passing doc changes no
                        file; render twice gives identical HTML
3. order independence   files created in reverse order give the same Facts
4. location independence two absolute paths give the same Facts
5. no ambient inputs    appdoc/**/*.py reads no clock, pid, uuid, random or environment (R13), except the
                        allow-list below
6. one normalization    LF and CRLF Narratives give equal seals (appdoc/textnorm.py)
7. extras               --workers 1 vs 2, cold vs warm cache, are byte-identical

Cross-OS bytes are checked in CI by tools/artifact_hashes.py.
"""
import ast
import contextlib
import io
import json
import os
import inspect
import shutil
import subprocess
import tempfile
import unittest

from appdoc import __main__ as cli
from appdoc import check, extract, fill
from appdoc import textnorm
from tests.template_pin import run_as_stamped
from tests.test_corpus import CORPUS, run_case

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
SAMPLES = os.path.join(HERE, "samples")
SAMPLE_NAMES = sorted(d for d in os.listdir(SAMPLES) if os.path.isdir(os.path.join(SAMPLES, d)) and d != "docs")
CORPUS_NAMES = sorted(d for d in os.listdir(CORPUS) if os.path.isdir(os.path.join(CORPUS, d)))
TARGETS = [(n, os.path.join(SAMPLES, n)) for n in SAMPLE_NAMES] + [(n, os.path.join(CORPUS, n)) for n in CORPUS_NAMES]


def quiet(fn, *a, **kw):
    with contextlib.redirect_stdout(io.StringIO()):
        return fn(*a, **kw)


def copy_target(src, dst, reverse=False):
    """Copy a tree creating directories and files in sorted (or reverse-sorted) order."""
    entries = []
    for dirpath, dirnames, filenames in os.walk(src):
        dirnames[:] = [d for d in dirnames if d != "__pycache__"]
        rel = os.path.relpath(dirpath, src)
        entries.append((rel, sorted(filenames)))
    entries.sort(reverse=reverse)
    os.makedirs(dst, exist_ok=True)
    for rel, names in entries:
        os.makedirs(os.path.join(dst, rel), exist_ok=True)
        for n in (reversed(names) if reverse else names):
            shutil.copyfile(os.path.join(src, rel, n), os.path.join(dst, rel, n))
    return dst


def snapshot(root):
    snap = {}
    for dirpath, _, names in os.walk(root):
        for n in names:
            p = os.path.join(dirpath, n)
            with open(p, "rb") as fh:
                snap[os.path.relpath(p, root)] = fh.read()
    return snap


class Tmp(unittest.TestCase):
    def tmp(self):
        d = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, d, True)
        return d

    def target_copy(self, src, name=None, reverse=False):
        return copy_target(src, os.path.join(self.tmp(), name or os.path.basename(src)), reverse)


class RunTwice(Tmp):
    def test_facts_and_summary_are_byte_identical(self):
        for name, src in TARGETS:
            with self.subTest(target=name):
                t = self.target_copy(src, name)
                out = os.path.join(t, "docs", "appdoc")
                a = extract.extract(t, out, workers=0, use_cache=False, no_ownership=True)
                b = extract.extract(t, out, workers=0, use_cache=False, no_ownership=True)
                self.assertEqual(a, b)

    def test_written_files_are_byte_identical(self):
        t = self.target_copy(os.path.join(SAMPLES, "python-flask"))
        out = os.path.join(t, "docs", "appdoc")
        quiet(extract.write, t, out, workers=0, no_ownership=True)
        first = snapshot(out)
        quiet(extract.write, t, out, workers=0, no_ownership=True)
        second = {k: v for k, v in snapshot(out).items() if k != ".appdoc-cache.json"}
        self.assertEqual({k: v for k, v in first.items() if k != ".appdoc-cache.json"}, second)
        self.assertIn("provenance.json", first)


class Idempotence(Tmp):
    def case(self, name):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        return run_case(name, tmp=tmp)

    def test_fill_twice_is_fill_once(self):
        for name in CORPUS_NAMES:
            r = self.case(name)
            if r.fill_code is None:
                continue
            with self.subTest(case=name):
                md = os.path.join(r.out, check.NARRATIVE)
                with open(md, "rb") as fh:
                    once = fh.read()
                quiet(fill.run, r.target, r.out)
                with open(md, "rb") as fh:
                    self.assertEqual(fh.read(), once)

    def test_seal_twice_is_a_no_op(self):
        for name in CORPUS_NAMES:
            r = self.case(name)
            if r.fill_code is None:
                continue
            with self.subTest(case=name):
                reg = os.path.join(r.out, check.REGISTER)
                with open(reg, "rb") as fh:
                    once = fh.read()
                self.assertEqual(check.seal_register(r.target, r.out), 0)
                with open(reg, "rb") as fh:
                    self.assertEqual(fh.read(), once)

    def test_build_on_a_passing_doc_changes_no_file(self):
        from appdoc.__main__ import main
        seen = 0
        for name in CORPUS_NAMES:
            r = self.case(name)
            if r.code != 0:
                continue
            with self.subTest(case=name):
                seen += 1
                build = lambda: run_as_stamped(r.narrative, quiet, main, ["build", r.target])   # 2.4 cases: 2.4-era Check
                self.assertEqual(build(), 0)
                before = snapshot(r.target)
                self.assertEqual(build(), 0)
                self.assertEqual(snapshot(r.target), before)
        self.assertGreater(seen, 0)

    def test_notes_seal_idempotent(self):
        """notes.jsonl: build seals an empty block_sha once, a second build changes no file, and fill with notes is stable."""
        from appdoc.__main__ import main
        r = self.case("trivial")
        self.assertEqual(r.code, 0, r.report)
        note = {"block": "entry-points", "text": "Routes registered by decorator are not listed",
                "cites": ["app/main.py:1"], "block_sha": ""}
        notes = os.path.join(r.out, "notes.jsonl")
        with open(notes, "w", encoding="utf-8", newline="\n") as fh:
            fh.write(json.dumps(note) + "\n")
        self.assertEqual(quiet(main, ["build", r.target]), 0)
        with open(notes, encoding="utf-8") as fh:
            sealed = json.loads(fh.read())
        self.assertRegex(sealed["block_sha"], r"^[0-9a-f]{12}$")
        before = snapshot(r.target)
        self.assertEqual(quiet(main, ["build", r.target]), 0)
        self.assertEqual(snapshot(r.target), before)
        self.assertEqual(check.seal_notes(r.target, r.out), 0)
        md = before[os.path.join("docs", "appdoc", check.NARRATIVE)].decode("utf-8")
        self.assertEqual(md.count("Known extractor limitation:"), 1)

    def test_render_twice_is_identical(self):
        from appdoc.render import page
        r = self.case("trivial")
        self.assertEqual(quiet(page.run, r.target, r.out, None), 0)
        html = os.path.join(r.out, "application-documentation.html")
        with open(html, "rb") as fh:
            first = fh.read()
        self.assertEqual(quiet(page.run, r.target, r.out, None), 0)
        with open(html, "rb") as fh:
            self.assertEqual(fh.read(), first)


class OrderAndLocation(Tmp):
    def test_reverse_creation_order_gives_the_same_facts(self):
        for name, src in TARGETS:
            with self.subTest(target=name):
                a = self.target_copy(src, name)
                b = self.target_copy(src, name, reverse=True)
                ra = extract.extract(a, os.path.join(a, "docs", "appdoc"), workers=0, use_cache=False, no_ownership=True)
                rb = extract.extract(b, os.path.join(b, "docs", "appdoc"), workers=0, use_cache=False, no_ownership=True)
                self.assertEqual(ra, rb)

    def test_two_absolute_paths_give_the_same_facts(self):
        for name, src in TARGETS:
            with self.subTest(target=name):
                a = self.target_copy(src, name)
                b = self.target_copy(src, name)
                self.assertNotEqual(a, b)
                ra = extract.extract(a, os.path.join(a, "docs", "appdoc"), workers=0, use_cache=False, no_ownership=True)
                rb = extract.extract(b, os.path.join(b, "docs", "appdoc"), workers=0, use_cache=False, no_ownership=True)
                self.assertEqual(ra, rb)
                self.assertNotIn(os.path.dirname(a), ra[0])
                self.assertNotIn(os.path.dirname(b), ra[1])


# R13: nothing in appdoc/ may read the clock, the process, a random source or the environment.
# Allow-list: os.environ["APPDOC_CI"] (a test-harness switch that cannot change output) and
# os.cpu_count() in extract.py's `if workers is None:` default (the pool size cannot change output).
AMBIENT_CALLS = {"datetime.now", "datetime.utcnow", "datetime.today", "date.today", "time.time", "time.time_ns",
                 "time.monotonic", "time.perf_counter", "os.getpid", "os.getppid", "os.environ", "os.getenv",
                 "os.urandom", "os.cpu_count", "os.getlogin", "getpass.getuser", "socket.gethostname",
                 "platform.node"}
AMBIENT_MODULES = {"random", "uuid", "secrets"}   # `appdoc/secrets.py` is a local module, imported as `from . import`


def _dotted(node):
    parts = []
    while isinstance(node, ast.Attribute):
        parts.append(node.attr)
        node = node.value
    if isinstance(node, ast.Name):
        parts.append(node.id)
        return ".".join(reversed(parts))
    return None


def _has_run(parts, run):
    return any(parts[i:i + len(run)] == run for i in range(len(parts) - len(run) + 1))


def ambient_offenders(pkg_dir):
    found = []
    for dirpath, dirnames, names in os.walk(pkg_dir):
        dirnames[:] = [d for d in dirnames if d != "__pycache__"]
        for n in sorted(names):
            if not n.endswith(".py"):
                continue
            path = os.path.join(dirpath, n)
            rel = os.path.relpath(path, pkg_dir).replace(os.sep, "/")
            with open(path, encoding="utf-8") as fh:
                tree = ast.parse(fh.read(), path)
            parent = {}
            for p in ast.walk(tree):
                for c in ast.iter_child_nodes(p):
                    parent[c] = p

            def ancestors(node):
                while node in parent:
                    node = parent[node]
                    yield node

            for node in ast.walk(tree):
                where = f"{rel}:{getattr(node, 'lineno', 0)}"
                if isinstance(node, ast.Import):
                    for a in node.names:
                        if a.name.split(".")[0] in AMBIENT_MODULES - {"secrets"}:
                            found.append(f"{where} import {a.name}")
                elif isinstance(node, ast.ImportFrom) and node.level == 0 and node.module:
                    root = node.module.split(".")[0]
                    if root in AMBIENT_MODULES - {"secrets"}:
                        found.append(f"{where} from {node.module} import ...")
                    for a in node.names:
                        if f"{root}.{a.name}" in AMBIENT_CALLS or f"{node.module}.{a.name}" in AMBIENT_CALLS:
                            found.append(f"{where} from {node.module} import {a.name}")
                elif isinstance(node, ast.Attribute):
                    d = _dotted(node)
                    if d is None or isinstance(parent.get(node), ast.Attribute):
                        continue                       # report the longest chain once
                    hit = next((c for c in sorted(AMBIENT_CALLS) if _has_run(d.split("."), c.split("."))), None)
                    if hit is None and d.split(".")[0] in ("random", "uuid"):
                        hit = d
                    if hit is None:
                        continue
                    if hit == "os.environ" and _is_appdoc_ci(node, parent):
                        continue
                    if hit == "os.cpu_count" and rel == "extract.py" and any(
                            isinstance(a, ast.If) and ast.unparse(a.test) == "workers is None" for a in ancestors(node)):
                        continue
                    found.append(f"{where} {d}")
    return found


def _is_appdoc_ci(node, parent):
    """os.environ.get("APPDOC_CI"...) or os.environ["APPDOC_CI"] and nothing else. node is the outermost chain."""
    d = _dotted(node)
    p = parent.get(node)
    if d == "os.environ":
        return (isinstance(p, ast.Subscript) and p.value is node
                and isinstance(p.slice, ast.Constant) and p.slice.value == "APPDOC_CI")
    if d == "os.environ.get":
        return (isinstance(p, ast.Call) and p.func is node and bool(p.args)
                and isinstance(p.args[0], ast.Constant) and p.args[0].value == "APPDOC_CI")
    return False


class AmbientInputs(unittest.TestCase):
    def test_no_ambient_inputs_in_appdoc(self):
        self.assertEqual(ambient_offenders(os.path.join(ROOT, "appdoc")), [])

    def test_the_scan_catches_offenders_and_honours_the_allow_list(self):
        d = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, d, True)
        bad = ("import os, time, datetime, uuid\nfrom datetime import date\n"
               "a = time.time()\nb = datetime.datetime.now()\nc = date.today()\nd = os.environ['HOME']\n"
               "e = os.environ.get('X')\nf = os.getpid()\ng = uuid.uuid4()\nh = os.cpu_count()\n")
        ok = ("import os\nx = os.environ.get('APPDOC_CI')\ny = os.environ['APPDOC_CI']\ns = 'time.time() os.environ'\n")
        with open(os.path.join(d, "bad.py"), "w") as fh:
            fh.write(bad)
        with open(os.path.join(d, "ok.py"), "w") as fh:
            fh.write(ok)
        got = ambient_offenders(d)
        self.assertTrue(all(g.startswith("bad.py") for g in got), got)
        for needle in ("time.time", "datetime.datetime.now", "date.today", "os.environ", "os.getpid", "uuid.uuid4",
                       "os.cpu_count", "import uuid"):
            self.assertTrue(any(needle in g for g in got), (needle, got))
        self.assertEqual(len([g for g in got if "os.environ" in g]), 2)


class OneNormalization(unittest.TestCase):
    def test_no_inline_newline_replace(self):
        """R14: exactly one newline rule; no module but textnorm.py spells the replacement."""
        offenders = []
        for top in ("appdoc", "tools"):
            for dirpath, _dirs, files in os.walk(os.path.join(ROOT, top)):
                for f in sorted(files):
                    if not f.endswith(".py") or (top == "appdoc" and f == "textnorm.py" and dirpath.endswith("appdoc")):
                        continue
                    with open(os.path.join(dirpath, f), encoding="utf-8") as fh:
                        for i, line in enumerate(fh, 1):
                            if 'replace("\\r\\n"' in line or 'replace(b"\\r\\n"' in line:
                                offenders.append(f"{os.path.relpath(os.path.join(dirpath, f), ROOT)}:{i}")
        self.assertEqual(offenders, [])

    def test_normalize_text(self):
        n = textnorm.normalize_text
        self.assertEqual(n("a  \r\nb\t\rc\n\n"), "a\nb\nc")
        self.assertEqual(n("é"), "é")                  # NFC
        self.assertEqual(n("a\r\nb"), n("a\nb"))
        self.assertEqual(n(""), "")
        self.assertEqual(n(n("x \r\ny \n")), n("x \r\ny \n"))     # idempotent

    def test_lf_vs_crlf_equal_seals(self):
        def seals(newline):
            tmp = tempfile.TemporaryDirectory()
            self.addCleanup(tmp.cleanup)
            r = run_case("trivial", tmp=tmp)
            md = os.path.join(r.out, check.NARRATIVE)
            with open(md, encoding="utf-8", newline="") as fh:
                text = fh.read().replace("\r\n", "\n")
            with open(md, "w", encoding="utf-8", newline="") as fh:
                fh.write(text.replace("\n", newline))
            reg = os.path.join(r.out, check.REGISTER)
            with open(reg, encoding="utf-8") as fh:
                rows = [json.loads(l) for l in fh if l.strip()]
            for row in rows:
                row.pop("claim_sha", None)
            with open(reg, "w", encoding="utf-8", newline="\n") as fh:
                fh.write("".join(json.dumps(o) + "\n" for o in rows))
            quiet(check.seal_register, r.target, r.out)
            with open(reg, encoding="utf-8") as fh:
                return [json.loads(l).get("claim_sha") for l in fh if l.strip()][1:]
        lf, crlf = seals("\n"), seals("\r\n")
        self.assertTrue(lf and all(lf), lf)
        self.assertEqual(lf, crlf)


class Extras(Tmp):
    def big_target(self):
        from tests.test_parallel import _large_target
        root = os.path.join(self.tmp(), "big")
        os.makedirs(root)
        _large_target(root)
        return root

    def test_workers_1_vs_2_are_byte_identical(self):
        root = self.big_target()
        out = os.path.join(root, "docs", "appdoc")
        one = extract.extract(root, out, workers=1, use_cache=False, no_ownership=True)
        two = extract.extract(root, out, workers=2, use_cache=False, no_ownership=True)
        self.assertEqual(one, two)
        sample = self.target_copy(os.path.join(SAMPLES, "java-spring"))
        so = os.path.join(sample, "docs", "appdoc")
        self.assertEqual(extract.extract(sample, so, workers=1, use_cache=False, no_ownership=True),
                         extract.extract(sample, so, workers=2, use_cache=False, no_ownership=True))

    def test_cold_vs_warm_cache_are_byte_identical(self):
        root = self.big_target()
        out = os.path.join(root, "docs", "appdoc")
        nocache = extract.extract(root, out, workers=0, use_cache=False, no_ownership=True)
        cold = extract.extract(root, out, workers=0, use_cache=True, no_ownership=True)
        self.assertTrue(os.path.isfile(os.path.join(out, ".appdoc-cache.json")), "the cold run wrote no cache")
        warm = extract.extract(root, out, workers=0, use_cache=True, no_ownership=True)
        self.assertEqual(nocache, cold)
        self.assertEqual(cold, warm)


GIT = shutil.which("git")
_STAMPS = ("2024-01-15T10:00:00+0000", "2024-03-02T12:30:00+0000")


def _git_env(n):
    """A fixed identity and fixed dates, and no user or system git config: the commit hashes are reproducible."""
    env = {k: v for k, v in os.environ.items() if not k.startswith("GIT_")}
    who = ("Fixed Author", "author@example.invalid") if n == 0 else ("Other Author", "other@example.invalid")
    env.update(GIT_AUTHOR_NAME=who[0], GIT_AUTHOR_EMAIL=who[1], GIT_COMMITTER_NAME=who[0], GIT_COMMITTER_EMAIL=who[1],
               GIT_AUTHOR_DATE=_STAMPS[n], GIT_COMMITTER_DATE=_STAMPS[n],
               GIT_CONFIG_GLOBAL=os.devnull, GIT_CONFIG_NOSYSTEM="1")
    return env


def make_git_repo(root):
    """Two commits with fixed identities and dates; the second touches only `pkg/`."""
    def run(n, *args):
        subprocess.run(["git", "-C", root, "-c", "commit.gpgsign=false", "-c", "core.autocrlf=false", *args],
                       env=_git_env(n), check=True, capture_output=True)
    run(0, "init", "-q")
    run(0, "add", "-A")
    run(0, "commit", "-q", "-m", "first")
    with open(os.path.join(root, "pkg", "mod000.py"), "a") as fh:
        fh.write("# touched\n")
    run(1, "add", "-A")
    run(1, "commit", "-q", "-m", "second")


class SkipTestsDefault(Tmp):
    def test_skip_tests_default_off_and_changes_output(self):
        self.assertFalse(inspect.signature(extract.extract).parameters["skip_tests"].default)
        self.assertFalse(inspect.signature(extract.write).parameters["skip_tests"].default)
        ns = cli.build_parser().parse_args(["extract", "somewhere"])
        self.assertFalse(ns.skip_tests)
        root = self.tmp()
        os.makedirs(os.path.join(root, "app"))
        os.makedirs(os.path.join(root, "tests"))
        with open(os.path.join(root, "app", "main.py"), "w") as fh:
            fh.write("import requests\nrequests.get('http://svc.example/api')\n")
        with open(os.path.join(root, "tests", "test_main.py"), "w") as fh:
            fh.write("import requests\nrequests.get('http://other.example/api')\n")
        out = os.path.join(root, "docs", "appdoc")
        default = extract.extract(root, out, workers=0, use_cache=False, no_ownership=True)
        explicit_off = extract.extract(root, out, workers=0, use_cache=False, no_ownership=True, skip_tests=False)
        skipped = extract.extract(root, out, workers=0, use_cache=False, no_ownership=True, skip_tests=True)
        self.assertEqual(default, explicit_off)
        self.assertNotEqual(default, skipped)
        self.assertIn("tests/test_main.py", default[0])
        self.assertNotIn("other.example", skipped[0])


@unittest.skipUnless(GIT, "git is not installed: the ownership determinism tests need it")
class OwnershipDeterminism(Tmp):
    def repo(self, name="big"):
        from tests.test_parallel import _large_target
        root = os.path.join(self.tmp(), name)
        os.makedirs(root)
        _large_target(root)
        make_git_repo(root)
        return root

    def run_extract(self, root, **kw):
        out = os.path.join(root, "docs", "appdoc")
        return extract.extract(root, out, **{"use_cache": False, **kw})

    def test_ownership_is_present_and_has_no_wall_clock(self):
        facts = json.loads(self.run_extract(self.repo(), workers=0)[0])["facts"]
        own = [f for f in facts if f["kind"] == "ownership" and f["detail"].get("source") == "git"]
        self.assertEqual([f["name"] for f in own], ["pkg"])
        d = own[0]["detail"]
        self.assertEqual((d["commits"], d["contributors"], d["first_commit"], d["last_commit"]),
                         (2, 2, "2024-01-15", "2024-03-02"))

    def test_run_twice_and_two_repos_are_byte_identical(self):
        a, b = self.repo(), self.repo()  # same name, two parents, two absolute paths
        self.assertEqual(self.run_extract(a, workers=0), self.run_extract(a, workers=0))
        self.assertEqual(self.run_extract(a, workers=0), self.run_extract(b, workers=0))

    def test_workers_1_vs_2_with_ownership(self):
        root = self.repo()
        self.assertEqual(self.run_extract(root, workers=1), self.run_extract(root, workers=2))

    def test_cold_vs_warm_cache_with_ownership(self):
        root = self.repo()
        nocache = self.run_extract(root, workers=0)
        cold = self.run_extract(root, workers=0, use_cache=True)
        self.assertTrue(os.path.isfile(os.path.join(root, "docs", "appdoc", ".appdoc-cache.json")))
        warm = self.run_extract(root, workers=0, use_cache=True)
        self.assertEqual(nocache, cold)
        self.assertEqual(cold, warm)


if __name__ == "__main__":
    unittest.main()
