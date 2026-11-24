import contextlib
import io
import json
import os
import tempfile
import unittest

from appdoc import docmodel as dm, extract, fill, fingerprint


def fact(kind, path, line, name, stack="s", **detail):
    return {"kind": kind, "stack": stack, "path": path, "line": line, "name": name, "detail": detail}


def route(path, line=1, **kw):
    return fact("entry_point", path, line, f"h{line}", type="route", method="GET", **kw)


def cfg(path, line, name, **kw):
    return fact("config_key", path, line, name, **kw)


def doc(*facts):
    return {"stacks": [], "facts": list(facts)}


class EntryPointTests(unittest.TestCase):
    def setUp(self):
        self.doc = doc(
            route("web/a.py", 1), route("web/a.py", 5), route("web/b.py", 2),
            route("web/t.py", 9, test=True),
            fact("entry_point", "web/pages.py", 3, "home", type="page"),
            fact("entry_point", "cli.py", 4, "run", type="command"),
            fact("entry_point", "jobs.py", 6, "nightly", type="job", schedule="0 2 * * *", enabled=True),
            fact("entry_point", "web/a.py", 8, "A", type="handler"),
            fact("file", "web/a.py", None, "web/a.py"))

    def test_counts_skip_tests_and_unlisted_types(self):
        self.assertEqual(fill.entry_point_counts(self.doc),
                         {"files": 2, "routes": 3, "pages": 1, "commands": 1, "jobs": 1})

    def test_counts_empty(self):
        self.assertEqual(fill.entry_point_counts(doc()),
                         {"files": 0, "routes": 0, "pages": 0, "commands": 0, "jobs": 0})

    def test_block_totals_and_rows_sorted_by_routes_then_path(self):
        out = fill.render_block("entry-points", self.doc).splitlines()
        self.assertEqual(out[0], "2 route handler files; 3 routes; 1 page; 1 command; 1 job.")
        self.assertEqual(out[2:4], ["| Handler file | Kinds | Routes | Pages | Jobs | Commands |", "|---|---|---|---|---|---|"])
        self.assertEqual(out[4:], [
            "| `web/a.py` | handler, route | 2 | 0 | 0 | 0 |",
            "| `web/b.py` | route | 1 | 0 | 0 | 0 |",
            "| `cli.py` | command | 0 | 0 | 0 | 1 |",
            "| `jobs.py` | job | 0 | 0 | 1 | 0 |",
            "| `web/pages.py` | page | 0 | 1 | 0 | 0 |"])

    def test_block_cap_states_n_of_m(self):
        many = doc(*[route(f"r/f{i:03}.py") for i in range(fill.ENTRY_CAP + 20)])
        out = fill.render_block("entry-points", many).splitlines()
        self.assertEqual(sum(1 for l in out if l.startswith("| `")), fill.ENTRY_CAP)
        self.assertEqual(out[-1], f"Shown {fill.ENTRY_CAP} of {fill.ENTRY_CAP + 20} handler files.")
        self.assertTrue(out[0].startswith(f"{fill.ENTRY_CAP + 20} route handler files; "))  # totals count them all

    def test_block_under_the_cap_has_no_shown_line(self):
        self.assertNotIn("Shown", fill.render_block("entry-points", self.doc))

    def test_block_empty_and_test_only(self):
        self.assertEqual(fill.render_block("entry-points", doc()), "No entry points were extracted.")
        self.assertEqual(fill.render_block("entry-points", doc(route("t.py", 1, test=True))),
                         "No entry points were extracted.")

    def test_block_is_idempotent(self):
        once = fill.render_block("entry-points", self.doc)
        self.assertEqual(once, fill.render_block("entry-points", json.loads(json.dumps(self.doc))))


def stack(name, *caps, supported=True):
    return {"name": name, "detail": {"supported": supported, "capabilities": sorted(caps), "file_count": 1}}


class StacksReportingTests(unittest.TestCase):
    def setUp(self):
        self.doc = {"stacks": [stack("go", "entry_point.job", "entry_point.route"),
                               stack("python-flask", "entry_point.route"),
                               stack("classic-asp", supported=False)], "facts": []}

    def test_exact_capability_and_supported_only(self):
        self.assertEqual(fill._stacks_reporting(self.doc, "entry_point.job"), ["go"])
        self.assertEqual(fill._stacks_reporting(self.doc, "entry_point.route"), ["go", "python-flask"])

    def test_bare_kind_matches_any_subtype(self):
        self.assertEqual(fill._stacks_reporting(self.doc, "entry_point"), ["go", "python-flask"])

    def test_no_stacks(self):
        self.assertEqual(fill._stacks_reporting(doc(), "entry_point.job"), [])


class NonePhraseTests(unittest.TestCase):
    def test_none_phrase_names_the_reader(self):
        self.assertEqual(fill.none_phrase(("config_key",)), "read by the generic reader")
        self.assertEqual(fill.none_phrase(("dependency", "connection")), "read by the generic reader")
        self.assertEqual(fill.none_phrase(("entry_point.job",), "jobs"), "No supported Stack reports jobs")
        self.assertEqual(fill.none_phrase(("entry_point", "config_key"), "entry points"),
                         "No supported Stack reports entry points")


class ScheduledJobTests(unittest.TestCase):
    def test_16_7_no_supported_stack_reports_jobs(self):
        d = {"stacks": [stack("python-flask", "entry_point.route")], "facts": [route("a.py")]}
        self.assertEqual(fill.render_block("scheduled-jobs", d),
                         "No supported Stack reports jobs (`python-flask`); read the source for job runners.")

    def test_16_7_names_the_stacks_that_report_jobs(self):
        d = {"stacks": [stack("go", "entry_point.job"), stack("python-flask", "entry_point.route")], "facts": []}
        out = fill.render_block("scheduled-jobs", d)
        self.assertTrue(out.startswith("No scheduled or background jobs were extracted."))
        self.assertIn("Stacks that report jobs: `go`.", out)
        self.assertNotIn("No supported Stack", out)
        self.assertNotIn("no entry-point capability", out)

    def test_entry_points_empty_never_says_no_capability(self):
        d = {"stacks": [stack("go", "entry_point.route"), stack("x", "config_key")], "facts": []}
        out = fill.render_block("entry-points", d)
        self.assertIn("`go`", out)
        self.assertNotIn("no entry-point capability", out)

    def test_rows_unknowns_and_no_test_jobs(self):
        d = doc(
            fact("entry_point", "b.go", 9, "sync", "go", type="job", schedule="@every 1h", enabled=False),
            fact("entry_point", "a.go", 3, "clean", "go", type="job", schedule=None, enabled=None),
            fact("entry_point", "a.go", 7, "tick", "go", type="job", schedule="*/5 * * * *", enabled=True),
            fact("entry_point", "t.go", 1, "fake", "go", type="job", test=True),
            route("a.go", 1))
        self.assertEqual(fill.render_block("scheduled-jobs", d).splitlines(), [
            "| Job | Schedule | Enabled by default | Defined at | Stack |", "|---|---|---|---|---|",
            "| clean | Unknown | Unknown | `a.go:3` | go |",
            "| tick | `*/5 * * * *` | yes | `a.go:7` | go |",
            "| sync | `@every 1h` | no | `b.go:9` | go |"])

    def test_no_cap(self):
        d = doc(*[fact("entry_point", f"j{i}.go", 1, f"job{i}", "go", type="job", schedule="@daily", enabled=True)
                  for i in range(400)])
        out = fill.render_block("scheduled-jobs", d).splitlines()
        self.assertEqual(len(out), 2 + 400)
        self.assertNotIn("Shown", "\n".join(out))

    def test_empty(self):
        self.assertEqual(fill.render_block("scheduled-jobs", doc(route("a.py"))),
                         "No scheduled or background jobs were extracted.")

    def test_pipe_in_schedule_is_escaped(self):
        d = doc(fact("entry_point", "a.py", 1, "j", "py", type="job", schedule="a|b", enabled=True))
        self.assertIn("`a\\|b`", fill.render_block("scheduled-jobs", d))


class ConfigReferenceTests(unittest.TestCase):
    def test_flaskr_like_define_beats_read(self):
        d = doc(
            cfg("project/app.py", 23, "USERNAME", use="define", role="app"),
            cfg("project/app.py", 80, "USERNAME", use="read", role="app"),
            cfg("project/app.py", 25, "SECRET_KEY", use="define", role="app", secret_location=True),
            cfg("project/app.py", 60, "SECRET_KEY", use="read", role="app", secret_location=True),
            cfg("project/app.py", 40, "DATABASE_URL", use="read", role="app"))
        self.assertEqual(fill.render_block("config-reference", d).splitlines(), [
            "| Key | Defined at | Secret location |", "|---|---|---|",
            "| SECRET_KEY | `project/app.py:25` | yes |",
            "| USERNAME | `project/app.py:23` | no |",
            "| DATABASE_URL | `project/app.py:40` | no |",
            "", "Shown 3 of 3 application keys."])

    def test_define_chosen_even_when_a_read_comes_first_in_the_file(self):
        d = doc(cfg("a.py", 3, "K", use="read"), cfg("a.py", 90, "K", use="define"))
        self.assertIn("| K | `a.py:90` | no |", fill.render_block("config-reference", d))

    def test_keys_without_use_count_as_defines(self):
        d = doc(cfg("a.ini", 2, "K"), cfg("b.py", 1, "K", use="read"))
        self.assertIn("| K | `a.ini:2` | no |", fill.render_block("config-reference", d))

    def test_500_commented_keys_are_counted_not_listed(self):
        commented = [cfg("custom/conf/app.example.ini", i, f"KEY_{i}", role="app", commented=True) for i in range(1, 501)]
        d = doc(cfg("custom/conf/app.example.ini", 600, "APP_NAME", role="app", use="define"), *commented)
        out = fill.render_block("config-reference", d)
        self.assertEqual(sum(1 for l in out.splitlines() if l.startswith("| KEY_")), 0)
        self.assertIn("| APP_NAME | `custom/conf/app.example.ini:600` | no |", out)
        self.assertEqual(out.splitlines()[-1],
                         "Shown 1 of 1 application key; 500 commented defaults in 1 file "
                         "are not listed (see facts.json).")

    def test_only_commented_keys(self):
        d = doc(cfg("a.ini", 1, "A", role="app", commented=True), cfg("b.ini", 1, "B", role="app", commented=True))
        self.assertEqual(fill.render_block("config-reference", d).splitlines()[-1],
                         "No application config keys were extracted. 2 commented defaults in 2 files "
                         "are not listed (see facts.json).")

    def test_ci_and_test_keys_are_excluded(self):
        d = doc(cfg(".github/workflows/ci.yml", 1, "on", role="ci"), cfg("tests/app.ini", 1, "X", test=True))
        out = fill.render_block("config-reference", d)
        self.assertIn("No application config keys were extracted.", out)
        self.assertTrue(out.endswith("0 env-var keys and 1 CI key are excluded from the application table (see facts.json)."))

    def test_secret_locations_first_then_path_and_line(self):
        d = doc(cfg("a.ini", 1, "PLAIN", role="app"), cfg("z.ini", 9, "PASSWD", role="app", secret_location=True),
                cfg("b.ini", 5, "TOKEN", role="app", secret_location=True))
        rows = [l.split(" | ")[0] for l in fill.render_block("config-reference", d).splitlines()[2:5]]
        self.assertEqual(rows, ["| TOKEN", "| PASSWD", "| PLAIN"])

    def test_cap_states_n_of_m(self):
        d = doc(*[cfg("a.ini", i, f"K{i:04}", role="app") for i in range(1, fill.CONFIG_CAP + 31)])
        out = fill.render_block("config-reference", d).splitlines()
        self.assertEqual(sum(1 for l in out if l.startswith("| K0")), fill.CONFIG_CAP)
        self.assertEqual(out[-1], f"Shown {fill.CONFIG_CAP} of {fill.CONFIG_CAP + 30} application keys.")

    def test_secret_keys_survive_the_cap(self):
        d = doc(*[cfg("a.ini", i, f"K{i:04}", role="app") for i in range(1, fill.CONFIG_CAP + 31)],
                cfg("zzz.ini", 1, "DB_PASSWORD", role="app", secret_location=True))
        self.assertIn("| DB_PASSWORD | `zzz.ini:1` | yes |", fill.render_block("config-reference", d))

    def test_one_row_per_key_name(self):
        d = doc(cfg("a.ini", 1, "K", use="define"), cfg("b.ini", 1, "K", use="define"))
        out = fill.render_block("config-reference", d)
        self.assertEqual(out.count("| K |"), 1)
        self.assertTrue(out.endswith("Shown 1 of 1 application key."))

    def test_unclassified_keys_are_not_listed_but_trailered(self):
        d = doc(cfg("a.ini", 1, "K", role="app"),
                cfg("custom/ClientRes.properties", 1, "X", role="unclassified"),
                cfg("custom/ClientRes.properties", 2, "Y", role="unclassified"))
        out = fill.render_block("config-reference", d)
        self.assertIn("| K | `a.ini:1` | no |", out)
        self.assertNotIn("`X`", out)
        self.assertIn("2 keys in 1 file were not classified as application configuration", out)
        self.assertIn("`custom/ClientRes.properties`", out)

    def test_unclassified_trailer_alone_when_no_app_keys(self):
        d = doc(cfg("custom/ClientRes.properties", 1, "X", role="unclassified"))
        out = fill.render_block("config-reference", d)
        self.assertIn("No application config keys were extracted.", out)
        self.assertIn("1 key in 1 file was not classified", out)


def scan_doc(**scan):
    d = doc()
    d["target"] = {"scan": {"found": 3, "scanned": 3, "pruned_files": 0, "ignored": 0, **scan}}
    return d


class ScanCoverageListTests(unittest.TestCase):
    def test_scan_coverage_duplicate_heading(self):
        d = scan_doc(retired_candidates=[{"path": "old/", "signal": "name", "files": 1}],
                     duplicate_folders=[{"a": "alpha/", "b": "beta/", "files": 5}])
        out = fill.render_block("scan-coverage", d)
        self.assertIn("Folders that look retired by name (not excluded):\n- `old/` (1 file)", out)
        self.assertIn("Folders that duplicate another folder (not excluded; say in 2.1 which copy is live):\n"
                      "- `alpha/` and `beta/` (5 files)", out)

    def test_lists_are_capped_at_ten_each(self):
        d = scan_doc(retired_candidates=[{"path": f"old{i:02}/", "signal": "name", "files": 2} for i in range(13)],
                     duplicate_folders=[{"a": f"a{i:02}/", "b": f"b{i:02}/", "files": 6} for i in range(11)])
        out = fill.render_block("scan-coverage", d)
        self.assertEqual(out.count("- `old"), 10)
        self.assertIn("- 3 more folders; see facts.json", out)
        self.assertEqual(out.count("` and `"), 10)
        self.assertIn("- 1 more pair; see facts.json", out)

    def test_no_lists_when_empty(self):
        out = fill.render_block("scan-coverage", scan_doc(retired_candidates=[], duplicate_folders=[]))
        self.assertNotIn("not excluded", out)

    def test_pruned_appdoc_items_are_disclosed_in_2_1(self):
        d = scan_doc(pruned=[{"path": "previous-docs/", "rule": "AppDoc output", "files": 3},
                             {"path": "tools/skill/", "rule": "AppDoc skill bundle", "files": 9},
                             {"path": "web/dist/", "rule": "JavaScript/.NET build output", "files": 4}])
        out = fill.render_block("scan-coverage", d)
        self.assertIn("AppDoc's own files were not scanned: `previous-docs/` (AppDoc output), "
                      "`tools/skill/` (AppDoc skill bundle). Add `!name` to .appdocignore to scan one.", out)
        plain = fill.render_block("scan-coverage", scan_doc(pruned=[
            {"path": "web/dist/", "rule": "JavaScript/.NET build output", "files": 4}]))
        self.assertNotIn("AppDoc's own files", plain)


class GeneratedCopyTests(unittest.TestCase):
    def test_generated_copy(self):
        self.assertEqual(fill.plural(1, "file"), "1 file")
        self.assertEqual(fill.plural(0, "file"), "0 files")
        self.assertEqual(fill.plural(2, "entry", "entries"), "2 entries")
        d = doc(route("web/a.py"),
                fact("entry_point", "web/p.py", 3, "home", type="page"),
                fact("entry_point", "cli.py", 4, "run", type="command"),
                fact("entry_point", "jobs.py", 6, "n", type="job", schedule="@daily", enabled=True))
        self.assertEqual(fill.render_block("entry-points", d).splitlines()[0],
                         "1 route handler file; 1 route; 1 page; 1 command; 1 job.")
        # nothing under a retired-looking folder: no "(0 under ...)"
        self.assertNotIn("under folders", fill.render_block("entry-points", d))
        d["target"] = {"scan": {"retired_candidates": [{"path": "web/", "signal": "name", "files": 1}]}}
        self.assertIn("(2 under folders that look retired)", fill.render_block("entry-points", d))
        d["target"] = {"scan": {"retired_candidates": [{"path": "zzz/", "signal": "name", "files": 1}]}}
        self.assertNotIn("under folders", fill.render_block("entry-points", d))

    def test_no_optional_plural_marker_in_any_block(self):
        d = doc(cfg("a.ini", 1, "A", role="app", commented=True), cfg("b.ini", 1, "B", role="unclassified"),
                cfg("c.py", 1, "C", role="ci"), cfg("d.py", 1, "D", role="env"), route("a.py"))
        d["target"] = {"scan": {"found": 1, "scanned": 1, "pruned_files": 0, "ignored": 0, "metadata": 1,
                                "pruned": [{"path": "x/", "rule": "always", "files": 1}]}}
        d["facts"].append(fact("file", "a.py", None, "a.py"))
        text = "\n".join(fill.render_block(n, d) for n in ("scan-coverage", "entry-points", "config-reference",
                                                           "scheduled-jobs"))
        self.assertNotIn("(s)", text)
        self.assertIn("1 file dropped", text)
        self.assertIn("1 commented default in 1 file is not listed", text)


class ConfigGuardTests(unittest.TestCase):
    def test_config_trailer_never_lists_app_file(self):
        d = doc(cfg("conf/app.ini", 1, "A", role="app"), cfg("conf/other.ini", 1, "B", role="unclassified"))
        out = fill.render_block("config-reference", d)
        self.assertIn("`conf/other.ini`", out.split("not classified")[1])
        self.assertNotIn("`conf/app.ini`", out.split("not classified")[1])
        bad = doc(cfg("conf/app.ini", 1, "A", role="app"), cfg("conf/app.ini", 2, "B", role="unclassified"))
        with self.assertRaises(RuntimeError):
            fill.render_block("config-reference", bad)


class ConfigInvariantTests(unittest.TestCase):
    def test_config_reference_invariant_unreachable(self):
        here = os.path.dirname(__file__)
        targets = []
        for top in ("samples", "corpus"):
            base = os.path.join(here, top)
            for name in sorted(os.listdir(base)):
                full = os.path.join(base, name)
                if os.path.isdir(os.path.join(full, "target")):
                    full = os.path.join(full, "target")
                if os.path.isdir(full):
                    targets.append(full)
        self.assertGreater(len(targets), 20)
        for t in targets:
            with tempfile.TemporaryDirectory() as out:
                text, _ = extract.extract(t, out)
            try:
                fill.render_block("config-reference", json.loads(text))
            except RuntimeError as e:  # pragma: no cover - the failure being proved impossible
                self.fail(f"{t}: {e}")


class AppendixTests(unittest.TestCase):
    def test_no_register_file(self):
        with tempfile.TemporaryDirectory() as tmp:
            out = fill.render_block("appendix-a", doc(), {"out_dir": tmp})
        self.assertIn("### A.1", out)
        self.assertEqual(out, fill.render_block("appendix-a", doc()))  # no ctx behaves like a missing file

    def test_register_beside_facts(self):
        rows = [{"type": "audit", "performed": True, "auditor": "independent", "scope": "all"},
                {"id": "E-1", "ref": "10.1/V-1", "claim": "A claim", "result": "Supported",
                 "cites": ["a.py:1"], "anchor": "x", "limitation": "none"}]
        with tempfile.TemporaryDirectory() as tmp:
            with open(os.path.join(tmp, "evidence.jsonl"), "w") as fh:
                fh.write("\n".join(json.dumps(r) for r in rows) + "\n")
            out = fill.render_block("appendix-a", doc(), {"out_dir": tmp})
        self.assertIn("E-1", out)
        self.assertIn("A claim", out)


class ClosedQuestionsTests(unittest.TestCase):
    """The closed-questions block under section 14 (T27.23): which Answerable rows closed a question, and where."""

    def render(self, *rows, notes=()):
        audit = {"type": "audit", "performed": True, "auditor": "independent", "scope": "method"}
        with tempfile.TemporaryDirectory() as tmp:
            if rows is not None:
                with open(os.path.join(tmp, "evidence.jsonl"), "w", encoding="utf-8") as fh:
                    fh.write("\n".join(json.dumps(r) for r in (audit, *rows)) + "\n")
            return fill.render_block("closed-questions", doc(), {"out_dir": tmp})

    @staticmethod
    def q(n, eid, answered_in="16.3", result="Answerable", **kw):
        row = {"id": f"E-{eid}", "ref": f"14/Q-{n}", "claim": f"question {n}", "result": result,
               "cites": ["a.py:1"], "anchor": "", "limitation": "", **kw}
        if answered_in:
            row["answered_in"] = answered_in
        return row

    def test_closed_questions_block(self):
        none = "No questions were closed by the audit."
        self.assertEqual(self.render(), none)                                    # a register without such rows
        self.assertEqual(fill.render_block("closed-questions", doc()), none)     # and no register at all
        out = self.render(self.q(11, 3), self.q(2, 4, "7.2"), self.q(5, 5, result="Supported"))
        self.assertEqual(out, "Closed by the audit and answered in the body: Q-2 (7.2), Q-11 (16.3).")
        # a superseded row is history; a row with no answered_in is listed without a section (C11 asks for it)
        out = self.render(self.q(2, 3, "7.2"), self.q(2, 4, "7.3", supersedes="E-3"), self.q(9, 5, None))
        self.assertEqual(out, "Closed by the audit and answered in the body: Q-2 (7.3), Q-9.")

    def test_closed_questions_block_is_filled_and_idempotent(self):
        text = "# T\n## 14. Open\n<!-- appdoc:generated closed-questions -->\n<!-- /appdoc:generated closed-questions -->\n"
        audit = {"type": "audit", "performed": True, "auditor": "independent", "scope": "method"}
        with tempfile.TemporaryDirectory() as tmp:
            with open(os.path.join(tmp, "evidence.jsonl"), "w", encoding="utf-8") as fh:
                fh.write(json.dumps(audit) + "\n" + json.dumps(self.q(3, 1)) + "\n")
            once, filled = fill.fill_text(text, doc(), {"out_dir": tmp})
            self.assertEqual(fill.fill_text(once, doc(), {"out_dir": tmp})[0], once)
        self.assertEqual(filled, ["closed-questions"])
        self.assertIn("Closed by the audit and answered in the body: Q-3 (16.3).", once)


class Block28Tests(unittest.TestCase):
    """T28.92, T28.93: the connections, integrations, pipeline and repo-docs blocks (and the access-model stub)."""

    def conns(self):
        return [
            fact("connection", "web/Web.config", 12, "PrimaryDb", type="database", secret_location=True,
                 overridden_in=["Staging", "Release"]),
            fact("connection", "web/Web.Release.config", 5, "PrimaryDb", type="database", secret_location=True),
            fact("connection", "web/Web.config", 14, "ReportsDb", type="database", secret_location=False),
            fact("connection", "tests/App.config", 3, "PrimaryDb", type="database", test=True),
            fact("connection", "svc/App.config", 8, "SessionCache", type="cache"),
        ]

    def test_connections_all_listed_grouped_by_name(self):
        d = doc(*self.conns())
        out = fill.render_block("connections", d)
        rows = [l for l in out.splitlines() if l.startswith("| `")]
        self.assertEqual([r.split("|")[1].strip() for r in rows], ["`PrimaryDb`", "`ReportsDb`", "`SessionCache`"])
        primary = rows[0]
        self.assertIn("`web/Web.config:12`", primary)
        self.assertIn("`web/Web.Release.config:5`", primary)
        self.assertIn("`tests/App.config:3` (test)", primary)
        self.assertIn("Release, Staging", primary)           # overridden_in, sorted
        self.assertIn("yes", primary)                         # a secret location in any definition
        self.assertIn("Listed 3 of 3 connection names.", out)
        shuffled = doc(*reversed(self.conns()))
        self.assertEqual(fill.render_block("connections", shuffled), out)    # deterministic, input order is no input
        many = doc(*[fact("connection", "a.config", i, f"Db{i:03d}", type="database") for i in range(1, 66)])
        capped = fill.render_block("connections", many)
        self.assertEqual(sum(1 for l in capped.splitlines() if l.startswith("| `")), fill.CONNECTION_CAP)
        self.assertIn(f"Listed {fill.CONNECTION_CAP} of 65 connection names.", capped)

    def test_connections_none_names_the_reader(self):
        self.assertEqual(fill.render_block("connections", doc()),
                         "No connections were extracted (read by the generic reader).")

    def calls(self):
        return [
            fact("external_call", "web/Web.config", 40, "https://billing.example.org:8443", type="service",
                 via="IBillingContract", config_key="BillingEndpoint"),
            fact("external_call", "web/Web.config", 44, "https://user:hunter2@api.example.org/v1/x?token=abc", type="http"),
            fact("external_call", "app/Mailer.cs", 9, "smtp.example.org", type="smtp"),
            fact("external_call", "app/Export.cs", 30, "\\\\files01\\drop", type="file_drop", config_key="DropShare"),
            fact("external_call", "app/Log.cs", 7, "App_Data/log.txt", type="file"),
            fact("external_call", "app/Mailer.cs", 21, "smtp.example.org", type="smtp"),
            fact("external_call", "tests/T.cs", 2, "https://test.example.org", type="http", test=True),
            fact("share", "web/Web.config", 50, "ExportShare", unc=True),
            fact("config_key", "app/Export.cs", 31, "ExportShare", use="read"),
        ]

    def test_integrations_block(self):
        d = doc(*self.calls())
        out = fill.render_block("integrations", d)
        rows = [l for l in out.splitlines() if l.startswith("| ") and not l.startswith("| Type") and "---" not in l]
        types = [r.split("|")[1].strip() for r in rows if r.split("|")[1].strip() not in ("",)]
        self.assertEqual(types[:5], ["service", "file_drop", "smtp", "http", "file"])
        service = rows[0]
        self.assertIn("`https://billing.example.org:8443`", service)
        self.assertIn("`BillingEndpoint`", service)
        self.assertIn("`IBillingContract`", service)
        smtp = next(r for r in rows if r.startswith("| smtp"))
        self.assertIn("`app/Mailer.cs:9`", smtp)
        self.assertIn("`app/Mailer.cs:21`", smtp)
        self.assertNotIn("test.example.org", out)                       # test-code calls are not listed
        # R18/R19: no userinfo, path or query
        self.assertIn("`https://api.example.org`", out)
        for leak in ("hunter2", "token=abc", "/v1/x", "user:"):
            self.assertNotIn(leak, out)
        self.assertIn("Listed 5 of 5 external call targets.", out)
        self.assertIn("| `ExportShare` | `web/Web.config:50` | 1 |", out)   # the share key and its read count
        self.assertEqual(fill.render_block("integrations", doc(*reversed(self.calls()))), out)

    def test_integrations_caps_state_n_of_m(self):
        many = doc(*[fact("external_call", "a.cs", i, f"host{i:03d}.example.org", type="http") for i in range(1, 80)])
        out = fill.render_block("integrations", many)
        self.assertEqual(sum(1 for l in out.splitlines() if l.startswith("| http")), fill.INTEGRATION_CAP)
        self.assertIn(f"Listed {fill.INTEGRATION_CAP} of 79 external call targets.", out)

    def test_integrations_none_phrase_stable(self):
        none = "No external calls were extracted (no supported Stack reports external calls)."
        self.assertEqual(fill.render_block("integrations", doc()), none)
        # a Stack that reports the kind changes the sentence only by naming it; the closed phrase stays
        d = {"stacks": [stack("aspnet", "external_call")], "facts": []}
        out = fill.render_block("integrations", d)
        self.assertTrue(out.startswith("No external calls were extracted. "), out)
        self.assertIn("Stacks that report them: `aspnet`.", out)
        # test-only calls count as none
        self.assertEqual(fill.render_block("integrations", doc(fact("external_call", "t.cs", 1, "h", type="http", test=True))), none)

    def test_pipeline_block_none_in_2_8(self):
        out = fill.render_block("pipeline", doc())
        self.assertEqual(out, "No pipeline jobs were extracted (no supported Stack reports CI jobs).")
        # the closed phrase follows the capability table: once the generic reader feeds the kind it says so
        from unittest import mock
        from appdoc.stacks import generic
        with mock.patch.object(generic, "GENERIC_KINDS", generic.GENERIC_KINDS | {"ci_job"}), \
                mock.patch.object(fill, "GENERIC_KINDS", generic.GENERIC_KINDS | {"ci_job"}):
            self.assertEqual(fill.render_block("pipeline", doc()),
                             "No pipeline jobs were extracted (read by the generic reader).")

    def test_repo_docs_block_none_in_2_8(self):
        self.assertEqual(fill.render_block("repo-docs", doc()),
                         "No repository documentation files were extracted "
                         "(no supported Stack reports repository documentation).")

    def test_every_2_8_block_has_a_renderer(self):
        from appdoc import template_spec as spec
        for name in spec.GENERATED_2_8.values():
            self.assertIsNotNone(fill.render_block(name, doc()), name)


# ----------------------------------------------------------------------------------------------- access-model (T28.91)

STACKS = [{"name": "aspnet", "detail": {"supported": True, "capabilities": [
    "entry_point.route", "entry_point.guard_mechanism", "entry_point.guard_reach", "access_rule"]}}]


def handler(url, label="unknown", path="web/C.cs", line=10, anon="deny", auth="deny", area=None, state="false",
            verbs=("GET",), declared=True, **kw):
    d = dict(type="route", handler=f"C.{url.strip('/').replace('/', '_') or 'Index'}", reach=label, reach_anon=anon,
             reach_auth=auth, state_changing=state, verbs=list(verbs), verbs_declared=declared)
    if area:
        d["mvc_area"] = area
    d.update(kw)
    return fact("entry_point", path, line, url, stack="aspnet", **d)


def rule(scope, effect, order, config="base", path="web/Web.config", line=5, status="base", **kw):
    return fact("access_rule", path, line, f"{effect} /{scope}", stack="aspnet", scope_path=scope, effect=effect, order=order,
                config=config, config_status=status, file=path, **kw)


def setting(name, value, config="base", path="web/Web.config", line=3, status="base", secret=False):
    return fact("security_setting", path, line, name, stack="aspnet", value=value, config=config, config_status=status,
                secret_location=secret)


def amdoc(*facts, stacks=None):
    return {"stacks": STACKS if stacks is None else stacks, "facts": list(facts)}


def am(*facts, **kw):
    return fill.render_block("access-model", amdoc(*facts, **kw))


class AccessModelTests(unittest.TestCase):
    def test_access_model_block(self):
        out = am(handler("/open", "no_app_restriction", anon="allow", auth="allow", state="true", verbs=("POST",)),
                 setting("system.web/authentication@mode", "windows"), rule("", "allow", 1, all=True))
        for part in ("**Configurations.**", "**Access rules**", "**Handlers by area**", "**Guard attributes.**",
                     "**Role names referenced", "**Secret locations.**", "**Defaults**", "**Stacks.**"):
            self.assertIn(part, out)
        self.assertEqual(out, am(handler("/open", "no_app_restriction", anon="allow", auth="allow", state="true",
                                         verbs=("POST",)), setting("system.web/authentication@mode", "windows"),
                                 rule("", "allow", 1, all=True)))

    def test_access_model_disclosure_line(self):
        out = am()
        self.assertEqual(out.split("\n")[0], fill.ACCESS_DISCLOSURE)
        self.assertEqual(out.split("\n")[0],
                         "Application-layer evaluation only: ASP.NET `<authorization>`, MVC filters and the declared "
                         "authentication mode. IIS authentication settings, server-level configuration, network exposure, "
                         "group membership and effective permissions are not in the repository.")

    def test_access_model_archetype_triple(self):
        out = am(handler("/a", "no_app_restriction", anon="allow", auth="allow", area="Billing"),
                 handler("/b", "signed_in_any", anon="deny", auth="allow", area="Billing"),
                 handler("/c", "role_restricted", anon="deny", auth="deny", area="Billing", reach_roles=["Admins"]),
                 handler("/d", "unknown", anon="unknown", auth="unknown", area="Billing"),
                 handler("/e", "denied", anon="deny", auth="deny", area="Billing"))
        self.assertIn("| Billing | 5 | 1 | 1 | 1 | 1 | 1 |", out)
        # anon allow/deny/unknown, auth, role (allow = a named role, or any signed-in user, is allowed)
        self.assertIn("| Billing | 5 | 1/3/1 | 2/2/1 | 3/1/1 |", out)
        self.assertIn("| all areas | 5 |", out)

    def test_access_model_config_columns(self):
        out = am(setting("system.web/authentication@mode", "windows"),
                 setting("system.web/authentication@mode", "forms", config="Release", status="transformed"),
                 setting("system.web/authentication@mode", "windows", config="Debug"),
                 fact("host_auth", "web/Web.config", 1, "host", stack="aspnet", iis_anonymous="unknown",
                      iis_authorization_present=False, owin_auth=False, source="csproj_dev_only"),
                 rule("", "allow", 1, config="Release", status="transformed", all=True),
                 rule("", "allow", 1, config="Debug", all=True),
                 {"kind": "project", "stack": "aspnet", "path": "web/web.csproj", "line": 1, "name": "web",
                  "detail": {"kind": "web", "configs": ["Debug", "Release", "Test"]}})
        self.assertIn("Production configuration: `Release` (default).", out)
        self.assertIn("| `Release` (production) | forms | false | unknown | false | 1 | yes |", out)
        self.assertIn("| `Debug` | windows | false | unknown | false | 1 | no |", out)
        self.assertIn("Effective on publish or package only", out)
        self.assertIn("`owin_auth`", out)
        self.assertIn("`iis_authorization_present`", out)

    def test_production_config_can_be_declared(self):
        out = am(setting("system.web/authentication@mode", "windows", config="Live"),
                 fact("context_directive", "appdoc-context.md", 2, "Production config", directive="production_config", value="live"),
                 rule("", "deny", 1, config="Live", anon=True))
        self.assertIn("Production configuration: `Live` (declared in appdoc-context.md).", out)

    def test_unevaluable_configs_counted(self):
        out = am(rule("", "allow", 1, config="Release", all=True),
                 rule("", "allow", 1, config="Odd", status="unknown_transform", all=True, reason_codes=["xpath"]),
                 setting("system.web/authentication@mode", "unknown", config="Odd", status="unknown_transform"),
                 rule("", "allow", 1, config="Debug", all=True))
        self.assertIn("1 of 3 configurations could not be evaluated: `Odd`.", out)
        self.assertIn("`Odd` (not evaluated)", out)
        self.assertNotIn("could not be evaluated: `Release`", out)
        self.assertIn("0 of 1 configurations could not be evaluated.", am(rule("", "allow", 1, all=True)))

    def test_access_rule_matrix_unmatched_and_caps(self):
        rules = [rule("Area", "allow", 1, roles=["Staff", "CONTOSO\\Ops"]), rule("Area", "deny", 2, all=True),
                 rule("Hr", "allow", 3, users_named=3), fact("file", "web/Area/x.txt", None, "web/Area/x.txt")]
        out = am(*rules, fact("file", "web/Web.config", None, "web/Web.config"))
        self.assertIn("| `Area` | 1 | allow | roles: `Staff`, `CONTOSO\\Ops` | all |", out)
        self.assertIn("users: 3 named", out)
        self.assertIn("Listed 3 of 3 access rules.", out)
        self.assertIn("| allow | `Hr` | `web/Web.config:5` |", out)       # no route, no folder: unmatched
        self.assertNotIn("| allow | `Area` |", out.split("Rules whose path")[1])
        many = [rule(f"S{i:03}", "allow", i, line=i + 1, all=True) for i in range(fill.access_model.RULE_CAP + 7)]
        out = am(*many)
        self.assertIn(f"Listed {fill.access_model.RULE_CAP} of {fill.access_model.RULE_CAP + 7} access rules.", out)
        self.assertEqual(sum(1 for l in out.splitlines() if l.startswith("| `S0")), fill.access_model.RULE_CAP)
        self.assertIn(f"Listed {fill.access_model.RULE_CAP} of {fill.access_model.RULE_CAP + 7} unmatched rules.", out)

    def test_unguarded_handlers_listed(self):
        hs = [handler("/post-any", "signed_in_any", state="true", verbs=("POST",), line=1, anon="deny", auth="allow"),
              handler("/post-unk", "unknown", state="true", verbs=("POST",), line=2, anon="unknown", auth="unknown"),
              handler("/post-role", "role_restricted", state="true", verbs=("POST",), line=3, reach_roles=["Admins"]),
              handler("/get-any", "signed_in_any", state="false", line=4, anon="deny", auth="allow"),
              handler("/verbless", "unknown", state="unknown", declared=False, verbs=("any",), line=5, anon="deny", auth="unknown")]
        out = am(*hs)
        tail = out.split("**State-changing handlers that are not role-restricted**")[1].split("**Guard attributes")[0]
        self.assertIn("`/post-any`", tail)
        self.assertIn("`/post-unk`", tail)
        for gone in ("/post-role", "/get-any", "/verbless"):
            self.assertNotIn(f"`{gone}`", tail.split("verb-less")[0].split("Listed")[0])
        self.assertIn("Listed 2 of 2 handlers.", out)
        self.assertIn("1 verb-less action (they accept every verb); 1 of them have no write hit", out)
        self.assertLess(tail.index("/post-unk"), tail.index("/post-any"))      # unknown before signed_in_any

    def test_all_no_app_restriction_listed(self):
        n = fill.access_model.HANDLER_CAP + 15
        hs = [handler(f"/open{i:03}", "no_app_restriction", anon="allow", auth="allow", line=i + 1,
                      state="true" if i % 2 else "false") for i in range(n)]
        out = am(*hs)
        head = out.split("**Handlers with no application restriction**")[1].split("**State-changing handlers")[0]
        self.assertEqual(sum(1 for l in head.splitlines() if l.startswith("| `/open")), n)
        self.assertIn(f"{n} handlers", head.splitlines()[0])
        self.assertIn("None.", am(handler("/x", "denied")).split("**Handlers with no application restriction**")[1])

    def test_access_model_caps_n_of_m(self):
        n = fill.access_model.HANDLER_CAP + 9
        hs = [handler(f"/w{i:03}", "signed_in_any", anon="deny", auth="allow", line=i + 1, state="true", verbs=("POST",))
              for i in range(n)]
        out = am(*hs)
        self.assertIn(f"Listed {fill.access_model.HANDLER_CAP} of {n} handlers.", out)
        self.assertEqual(sum(1 for l in out.splitlines() if l.startswith("| `/w")), fill.access_model.HANDLER_CAP)
        files = [fact("const_def", f"c/F{i:03}.cs", 1, f"K.P{i}", secret=True) for i in range(fill.access_model.FILE_CAP + 5)]
        out = am(*files)
        self.assertIn(f"Listed {fill.access_model.FILE_CAP} of {fill.access_model.FILE_CAP + 5} files.", out)
        shapes = [fact("guard_use", "c/A.cs", i + 1, f"G{i:03}", arg_kinds=["literal"], arity=1, applies_to="A")
                  for i in range(fill.access_model.SHAPE_CAP + 3)]
        self.assertIn(f"Listed {fill.access_model.SHAPE_CAP} of {fill.access_model.SHAPE_CAP + 3} argument shapes.", am(*shapes))

    def test_access_model_capability_none(self):
        out = am(stacks=[{"name": "node", "detail": {"supported": True, "capabilities": ["entry_point.route"]}}])
        self.assertIn("No supported Stack reports effective protection (`entry_point.guard_reach`) or a guard mechanism", out)
        self.assertIn("supported Stacks without it: `node`.", out)
        self.assertIn("No handler protection was evaluated (No supported Stack reports effective protection", out)
        core = am(stacks=[{"name": "aspnet-core", "detail": {"supported": True,
                                                              "capabilities": ["entry_point.guard_mechanism"]}}])
        self.assertIn("Mechanism only (no reach, and no claim that a handler is unguarded): `aspnet-core`", core)
        self.assertIn("reported by no Stack", core)
        both = am(stacks=STACKS + [{"name": "aspnet-core", "detail": {"supported": True,
                                                                       "capabilities": ["entry_point.guard_mechanism"]}},
                                    {"name": "go", "detail": {"supported": True, "capabilities": ["entry_point.route"]}}])
        self.assertIn("reported by `aspnet`. Mechanism only", both)
        self.assertIn("Supported Stacks that do not report protection: `go`.", both)

    def test_mechanism_only_handlers_are_counted_not_labelled(self):
        out = am(fact("entry_point", "c/A.cs", 3, "/a", stack="aspnet-core", type="route", guard_mechanism=["attribute"]),
                 stacks=[{"name": "aspnet-core", "detail": {"supported": True, "capabilities": ["entry_point.guard_mechanism"]}}])
        self.assertIn("(1 handler with a guard mechanism)", out)
        self.assertNotIn("| Area |", out)                              # no label or archetype table: no reach was computed

    def test_secret_table_no_values(self):
        out = am(fact("config_key", "web/Web.config", 9, "ApiToken", secret_location=True),
                 fact("config_key", "web/Web.config", 10, "Title", secret_location=False),
                 setting("connectionStrings/add@connectionString", "literal", line=21, secret=True),
                 fact("connection", "web/Web.config", 21, "Db", secret_location=True, type="database"),
                 fact("connection", "web/Web.Release.config", 8, "Db", secret_location=True, type="database"),
                 setting("system.web/machineKey", "literal_hex", line=31, secret=True),
                 setting("system.web/machineKey", "literal_hex", config="Release", line=31, secret=True),
                 fact("const_def", "web/K.cs", 22, "Accounts.Password", secret=True),
                 fact("config_key", "web/K.cs", 22, "Password", secret_location=True),
                 fact("const_def", "web/K.cs", 23, "Accounts.Name", value="svc-account"))
        self.assertIn("| `web/K.cs` | 0 | 0 | 0 | 1 | 0 |", out)               # a constant counted once
        self.assertIn("| `web/Web.Release.config` | 0 | 1 | 0 | 0 | 0 |", out)
        self.assertIn("| `web/Web.config` | 1 | 1 | 1 | 0 | 0 |", out)          # configs of one key counted once
        self.assertIn("Listed 3 of 3 files.", out)
        self.assertNotIn("svc-account", out)
        self.assertIn("a value is never recorded", out)

    def test_argument_shapes_table(self):
        out = am(fact("guard_use", "c/A.cs", 3, "Guard", arg_kinds=["const", "const"], arity=2, applies_to="A"),
                 fact("guard_use", "c/B.cs", 3, "Guard", arg_kinds=["const", "const"], arity=2, applies_to="B"),
                 fact("guard_use", "c/B.cs", 9, "Guard", arg_kinds=["literal"], arity=1, applies_to="B.M", arity_override=True),
                 fact("guard_candidate", "c/A.cs", 3, "Guard", uses=3, arity_set=[1, 2]),
                 fact("guard_use", "c/A.cs", 5, "Authorize", arg_kinds=[], arity=0, applies_to="A", namespace="System.Web.Mvc"),
                 fact("guard_use", "c/T.cs", 5, "Guard", arg_kinds=["literal"], arity=1, applies_to="T", test=True))
        self.assertIn("| `Guard` | const, const | 2 | 2 | 0 |", out)
        self.assertIn("| `Guard` | literal | 1 | 1 | 1 |", out)
        self.assertIn("| `Authorize` | none | 0 | 1 | 0 |", out)
        self.assertIn("| `Guard` | candidate, undeclared | 3 |", out)
        self.assertIn("| `Authorize` | framework | 1 |", out)
        self.assertIn("1 undeclared guard candidate: `Guard`.", out)

    def test_role_constants_all_listed(self):
        facts = [fact("guard_use", "c/A.cs", i + 1, "Guard", arg_kinds=["const"], arity=1, applies_to="A", role=r, role_ref=c)
                 for i, (r, c) in enumerate([("Admins", "Roles.Admin"), ("Staff", "Roles.Staff"), ("Admins", "Roles.Admin")])]
        facts.append(fact("guard_use", "c/B.cs", 1, "Guard", arg_kinds=["literal"], arity=1, applies_to="B", role=["Ops", "Dev"]))
        facts.append(fact("auth_check", "c/B.cs", 7, "HasRole()", via="call", roles=["CONTOSO\\Ops", "Staff"],
                          role_refs=["Groups.Ops", "Roles.Staff"], applies_to="B.M", mechanism="inbody"))
        facts.append(fact("auth_check", "c/B.cs", 8, "IsInRole()", via="body", mechanism="inbody"))
        facts.append(fact("guard_use", "c/B.cs", 2, "Guard", arg_kinds=["literal"], arity=1, applies_to="B", role="pat@contoso.test"))
        out = am(*facts)
        self.assertIn("| `Admins` | `Roles.Admin` | 2 | 0 |", out)
        self.assertIn("| `Staff` | `Roles.Staff` | 1 | 1 |", out)
        self.assertIn("| `CONTOSO\\Ops` | `Groups.Ops` | 0 | 1 |", out)
        self.assertIn("| `Dev` | none | 1 | 0 |", out)
        self.assertIn("| `Ops` | none | 1 | 0 |", out)
        self.assertIn("Listed 6 of 6 role names.", out)
        self.assertNotIn("pat@contoso.test", out)                   # an e-mail address is withheld, never printed
        self.assertIn("(e-mail address withheld)", out)

    def test_ashx_asmx_svc_not_evaluated_line(self):
        out = am(fact("file", "web/a.ashx", None, "web/a.ashx"), fact("file", "web/b.svc", None, "web/b.svc"),
                 fact("file", "web/c.ashx", None, "web/c.ashx"), fact("file", "t/x.asmx", None, "t/x.asmx", test=True))
        self.assertIn("Not evaluated: `.ashx`, `.asmx` and `.svc` handler files exist in the Target (2 `.ashx`, 1 `.svc`)", out)
        self.assertNotIn("Not evaluated:", am(fact("file", "web/a.cs", None, "web/a.cs")))

    def test_defaults_note_is_labelled_documentation(self):
        self.assertIn("**Defaults** (documentation of ASP.NET behaviour, not a Fact about this Target)", am())

    def test_no_url_userinfo_or_pipes_in_names(self):
        out = am(handler("/a|b", "unknown", state="true", verbs=("POST",)),
                 fact("guard_use", "c/A.cs", 1, "Guard", arg_kinds=["literal"], arity=1, applies_to="A",
                      role="https://user:pw@host.test/x"))
        self.assertNotIn("user:pw", out)
        self.assertNotIn("a|b", out.replace("\\|", ""))

    def test_end_to_end_mvc5_classic(self):
        import re
        target = os.path.join(os.path.dirname(os.path.abspath(__file__)), "corpus", "_targets", "mvc5-classic")
        with tempfile.TemporaryDirectory() as tmp:
            text, _ = extract.extract(target, os.path.join(tmp, "out"), workers=0, use_cache=False, no_ownership=True)
        d = json.loads(text)
        md = ("# Doc\n\n### 5.4 Application-layer access (generated)\n\n<!-- appdoc:generated access-model -->\n"
              "<!-- /appdoc:generated access-model -->\n")
        new, filled = fill.fill_text(md, d)
        self.assertEqual(filled, ["access-model"])
        self.assertEqual(fill.fill_text(new, d)[0], new)                                 # idempotent
        self.assertIn("Application-layer evaluation only:", new)
        self.assertIn("Production configuration: `Release` (default). 1 of 5 configurations could not be evaluated: `Odd`.", new)
        self.assertIn("| `ContosoGuard` | candidate, undeclared | 4 |", new)
        self.assertIn("| `Auditors` | `Roles.Auditor` | 1 | 0 |", new)
        self.assertIn("| `CONTOSO\\FinanceGroup` | `Groups.FinanceGroup` | 0 | 1 |", new)
        self.assertIn("| `Contoso.Portal/Web.config` | 2 | 1 | 1 | 0 | 0 |", new)
        raw = ""
        for n in ("Web.config", "Infrastructure/Constants.cs"):
            with open(os.path.join(target, "Contoso.Portal", n), encoding="utf-8") as fh:
                raw += fh.read()
        for secret in re.findall(r"(?:not-a-real-\w+-\d{4}|0123456789ABCDEF{2,}|FEDCBA98\w+)", raw):
            self.assertNotIn(secret, new)
        for svc in ("svc-portal", "CONTOSO\\pat", "sql01.contoso.test"):
            self.assertNotIn(svc, new)


class AccessCountMarkerTests(unittest.TestCase):
    """T28.94: the access-model count classes are filled from `access_model.count`, the same helpers the block uses."""

    CLASSES = tuple(c for c in __import__("appdoc.template_spec", fromlist=["x"]).COUNT_CLASSES
                    if c in ("areas", "access-rules", "role-constants", "guard-shapes", "secret-location-files",
                             "configurations") or c.startswith("state-changing-"))

    def facts(self):
        return amdoc(
            handler("/a", "no_app_restriction", state="true", area="Admin", verbs=("POST",)),
            handler("/b", "no_app_restriction", state="true", line=11, verbs=("POST",)),
            handler("/c", "signed_in_any", state="true", line=12, area="Admin", verbs=("POST",)),
            handler("/d", "unknown", state="false", line=13, area="Billing"),
            handler("/e", "role_restricted", state="true", line=14, area="Billing", verbs=("POST",)),
            rule("", "allow", 1, all=True), rule("admin", "deny", 2, anon=True),
            rule("", "deny", 1, config="Release", anon=True),
            setting("system.web/authentication@mode", "windows", config="Debug"),
            fact("guard_use", "web/C.cs", 3, "SiteGuard", arg_kinds=["const"], arity=1, applies_to="C", role=["Admin"],
                 role_ref=["Roles.Admin"]),
            fact("guard_use", "web/C.cs", 9, "SiteGuard", arg_kinds=["literal", "literal"], arity=2, applies_to="C.Save"),
            fact("const_def", "web/K.cs", 1, "K.Pw", secret=True), fact("const_def", "web/K2.cs", 1, "K.Pw2", secret=True))

    def test_count_markers_2_8_values(self):
        d = self.facts()
        want = {"areas": 2, "state-changing-no_app_restriction": 2, "state-changing-signed_in_any": 1,
                "state-changing-role_restricted": 1, "state-changing-unknown": 0, "state-changing-denied": 0,
                "access-rules": 2, "role-constants": 1, "guard-shapes": 2, "secret-location-files": 2,
                "configurations": 2}
        self.assertEqual({c: fill.count_marker_value(c, d, {}, None) for c in self.CLASSES}, want)
        self.assertEqual(set(self.CLASSES), set(want))

    def test_markers_are_filled_idempotently(self):
        d = self.facts()
        text = " ".join(f"<!-- appdoc:count {c} -->0<!-- /appdoc:count -->" for c in self.CLASSES)
        with tempfile.TemporaryDirectory() as t:
            once = fill.fill_counts(text, d, {"out_dir": t})
            self.assertIn("<!-- appdoc:count areas -->2<!-- /appdoc:count -->", once)
            self.assertEqual(fill.fill_counts(once, d, {"out_dir": t}), once)

    def test_markers_agree_with_the_access_model_block(self):
        import re
        d = self.facts()
        block = fill.render_block("access-model", d)
        n = lambda c: fill.count_marker_value(c, d, {}, None)
        self.assertEqual(n("access-rules"), int(re.search(r"Listed (\d+) of \d+ access rule", block).group(1)))
        self.assertEqual(n("guard-shapes"), int(re.search(r"Listed \d+ of (\d+) argument shape", block).group(1)))
        self.assertEqual(n("secret-location-files"), int(re.search(r"Listed \d+ of (\d+) file", block).group(1)))
        self.assertEqual(n("role-constants"), int(re.search(r"Listed (\d+) of \d+ role names", block).group(1)))
        self.assertIn(f"of {n('configurations')} configurations could not be evaluated", block)
        area_rows = re.findall(r"^\| (\w[^|]*?) \| \d+ \| \d+ \|", block, re.M)
        self.assertEqual(n("areas"), len([a for a in set(area_rows) if a in ("Admin", "Billing")]))
        row = re.search(r"^\| all areas \| \d+ \| (\d+) \| (\d+) \| (\d+) \| (\d+) \| (\d+) \|", block, re.M).groups()
        self.assertEqual(row[0], str(sum(1 for f in d["facts"] if f["kind"] == "entry_point"
                                         and f["detail"]["reach"] == "no_app_restriction")))

    def test_accountability_line_agrees_with_the_access_model_block(self):
        import re
        from appdoc import summary
        d = self.facts()
        seen = summary.accountability_counts(d["facts"])["guard_attributes"]["seen"]
        block = fill.render_block("access-model", d)
        uses = sum(int(m) for m in re.findall(r"^\| `SiteGuard` \| [^|]+ \| (\d+) \|$", block, re.M))
        self.assertEqual(seen, uses)
        self.assertEqual(seen, len([f for f in d["facts"] if f["kind"] == "guard_use"]))


class NotesTests(unittest.TestCase):
    """docs/appdoc/notes.jsonl: limitations of a generated block live as data and `fill` renders them inside it."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.doc = doc(route("web/a.py", 1))

    def write_notes(self, *notes):
        with open(os.path.join(self.tmp.name, "notes.jsonl"), "w", encoding="utf-8", newline="\n") as fh:
            fh.write("".join(json.dumps(n) + "\n" for n in notes))

    NOTE = {"block": "entry-points", "text": "Routes registered by decorator are not listed",
            "cites": ["web/a.py:1"], "block_sha": ""}

    def test_notes_rendered_in_block(self):
        self.write_notes(self.NOTE, dict(self.NOTE, block="scheduled-jobs", text="elsewhere", cites=[]),
                         dict(self.NOTE, text="A second note", cites=["web/a.py:1", "web/b.py"]))
        ctx = {"out_dir": self.tmp.name}
        plain = fill.render_block("entry-points", self.doc)
        out = fill.render_block("entry-points", self.doc, ctx)
        self.assertEqual(out, plain + "\n\nKnown extractor limitation: Routes registered by decorator are not listed "
                                     "(`web/a.py:1`)\n\nKnown extractor limitation: A second note (`web/a.py:1`, `web/b.py`)")
        self.assertNotIn("elsewhere", out)                   # a note belongs to its own block only
        self.assertIn("Known extractor limitation: elsewhere", fill.render_block("scheduled-jobs", self.doc, ctx))
        self.assertEqual(fill.render_block("config-reference", self.doc, ctx),
                         fill.render_block("config-reference", self.doc))
        # the generated body is what block_sha hashes: the notes are not part of it
        self.assertEqual(fill.generated_body("entry-points", self.doc, ctx), plain)

    def test_notes_survive_fill_and_fill_is_idempotent(self):
        self.write_notes(self.NOTE)
        text = "# T\n<!-- appdoc:generated entry-points -->\n<!-- /appdoc:generated entry-points -->\n"
        ctx = {"out_dir": self.tmp.name}
        once, _ = fill.fill_text(text, self.doc, ctx)
        self.assertIn("Known extractor limitation: Routes registered", once)
        self.assertEqual(fill.fill_text(once, self.doc, ctx)[0], once)

    def test_no_notes_file_or_no_out_dir_changes_nothing(self):
        self.assertEqual(fill.render_block("entry-points", self.doc, {"out_dir": self.tmp.name}),
                         fill.render_block("entry-points", self.doc))


class CountMarkerTests(unittest.TestCase):
    """`<!-- appdoc:count CLASS -->N<!-- /appdoc:count -->`: fill writes N, the marker stays (T27.17)."""

    CLASSES = ("V", "F", "UI", "C", "X", "Q", "R", "rows", "superseded", "routes", "jobs", "pages", "commands",
               "config-keys")
    EXPECT = {"V": 1, "F": 1, "UI": 1, "C": 1, "X": 1, "Q": 1, "R": 1, "rows": 2, "superseded": 1,
              "routes": 2, "jobs": 1, "pages": 1, "commands": 1, "config-keys": 2}

    @staticmethod
    def marker(cls, n="99"):
        return f"<!-- appdoc:count {cls} -->{n}<!-- /appdoc:count -->"

    def setUp(self):
        from tests.test_check import AUDIT, ROWS, build_doc
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        rows = ROWS + [dict(ROWS[0], id="E-3", supersedes="E-1")]
        with open(os.path.join(self.tmp.name, "evidence.jsonl"), "w", encoding="utf-8") as fh:
            fh.write("\n".join(json.dumps(r) for r in [AUDIT] + rows) + "\n")
        self.facts = doc(route("web/a.py", 1), route("web/a.py", 5), route("web/t.py", 9, test=True),
                         fact("entry_point", "web/pages.py", 3, "home", type="page"),
                         fact("entry_point", "cli.py", 4, "run", type="command"),
                         fact("entry_point", "jobs.py", 6, "nightly", type="job"),
                         cfg("conf/app.ini", 1, "DEBUG"), cfg("conf/app.ini", 2, "PORT"), cfg("conf/app.ini", 3, "PORT"))
        line = "; ".join(f"{c} {self.marker(c)}" for c in self.CLASSES)
        self.text = build_doc({3: "- The entry module wires the handlers in `app/main.py:3-5`.\n\n- Counts: " + line + "."})
        self.ctx = {"out_dir": self.tmp.name}

    def counts(self, text):
        import re
        return {m.group(1): m.group(2) for m in re.finditer(
            r"<!-- appdoc:count (\S+) -->(.*?)<!-- /appdoc:count -->", text)}

    def test_count_marker_filled(self):
        out, _ = fill.fill_text(self.text, self.facts, self.ctx)
        self.assertEqual(self.counts(out), {c: str(n) for c, n in self.EXPECT.items()})
        # the marker stays: only the number between the two comments changed
        self.assertEqual(out.replace("99", "").count("appdoc:count"), 2 * len(self.CLASSES))

    def test_count_marker_idempotent(self):
        once, _ = fill.fill_text(self.text, self.facts, self.ctx)
        self.assertEqual(fill.fill_text(once, self.facts, self.ctx)[0], once)
        # a changed Fact changes the number on the next fill, nothing else
        self.facts["facts"].append(route("web/b.py", 2))
        twice, _ = fill.fill_text(once, self.facts, self.ctx)
        self.assertEqual(self.counts(twice), {**self.counts(once), "routes": "3"})

    def test_unknown_class_and_missing_inputs_are_left_alone(self):
        text = self.text + "\nx " + self.marker("widgets", "7") + "\n"
        out, _ = fill.fill_text(text, self.facts, self.ctx)
        self.assertIn(self.marker("widgets", "7"), out)
        # no register beside the Facts: the register classes are left alone, the rest is still filled
        out, _ = fill.fill_text(self.text, self.facts, {"out_dir": self.tmp.name + "-none"})
        self.assertEqual((self.counts(out)["rows"], self.counts(out)["V"], self.counts(out)["jobs"]), ("99", "1", "1"))

    def test_markers_leave_the_audit_fingerprint_alone(self):
        from appdoc import check
        out, _ = fill.fill_text(self.text, self.facts, self.ctx)
        other = out.replace("<!-- appdoc:count routes -->2", "<!-- appdoc:count routes -->7")
        self.assertNotEqual(other, out)
        self.assertEqual(fingerprint.doc_sha(out), fingerprint.doc_sha(other))


class FillTextTests(unittest.TestCase):
    TEXT = ("# T\n\n<!-- appdoc:generated entry-points -->\nold\n<!-- /appdoc:generated entry-points -->\n\n"
            "<!-- appdoc:generated scheduled-jobs -->\n<!-- /appdoc:generated scheduled-jobs -->\n"
            "<!-- appdoc:generated unknown-block -->\nkeep\n<!-- /appdoc:generated unknown-block -->\n")

    def test_fills_known_blocks_only_and_is_idempotent(self):
        once, filled = fill.fill_text(self.TEXT, doc())
        self.assertEqual(filled, ["entry-points", "scheduled-jobs"])
        self.assertIn("No entry points were extracted.", once)
        self.assertIn("keep", once)
        self.assertNotIn("old", once)
        self.assertEqual(fill.fill_text(once, doc())[0], once)

    def test_mask_keeps_the_line_count_and_hides_content(self):
        masked = dm.mask_blocks(self.TEXT, ("entry-points", "scheduled-jobs"))
        self.assertEqual(masked.count("\n"), self.TEXT.count("\n"))
        self.assertNotIn("old", masked)
        self.assertIn("keep", masked)  # unnamed blocks are left alone
        filled = fill.fill_text(self.TEXT, doc(route("a.py")))[0]
        self.assertEqual(dm.mask_blocks(filled, ("entry-points",)).count("\n"), filled.count("\n"))
        self.assertNotIn("a.py", dm.mask_blocks(filled, ("entry-points",)))

    def test_run_writes_all_five_blocks_with_the_register_context(self):
        names = ("scan-coverage", "entry-points", "config-reference", "scheduled-jobs", "appendix-a")
        text = "# T\n" + "".join(f"<!-- appdoc:generated {n} -->\n<!-- /appdoc:generated {n} -->\n" for n in names)
        with tempfile.TemporaryDirectory() as tmp:
            with open(os.path.join(tmp, "application-documentation.md"), "w", newline="") as fh:
                fh.write(text)
            with open(os.path.join(tmp, "facts.json"), "w") as fh:
                json.dump(doc(route("a.py")), fh)
            with open(os.path.join(tmp, "evidence.jsonl"), "w") as fh:
                fh.write(json.dumps({"type": "audit", "performed": False, "scope": "time-boxed"}) + "\n")
            with contextlib.redirect_stdout(io.StringIO()) as buf:
                self.assertEqual(fill.run(tmp, tmp), 0)
                with open(os.path.join(tmp, "application-documentation.md"), newline="") as fh:
                    once = fh.read()
                self.assertEqual(fill.run(tmp, tmp), 0)
            with open(os.path.join(tmp, "application-documentation.md"), newline="") as fh:
                self.assertEqual(fh.read(), once)
        self.assertIn("filled: " + ", ".join(names), buf.getvalue())
        self.assertIn("1 route handler file; 1 route", once)
        self.assertIn("time-boxed", once)


if __name__ == "__main__":
    unittest.main()
