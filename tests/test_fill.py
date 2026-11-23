import contextlib
import io
import json
import os
import tempfile
import unittest

from appdoc import fill


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
        self.assertEqual(out[0], "2 route handler files; 3 routes; 1 pages; 1 commands; 1 jobs.")
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
                         "Shown 1 of 1 application keys; 500 commented defaults in 1 file(s) "
                         "are not listed (see facts.json).")

    def test_only_commented_keys(self):
        d = doc(cfg("a.ini", 1, "A", role="app", commented=True), cfg("b.ini", 1, "B", role="app", commented=True))
        self.assertEqual(fill.render_block("config-reference", d).splitlines()[-1],
                         "No application config keys were extracted. 2 commented defaults in 2 file(s) "
                         "are not listed (see facts.json).")

    def test_ci_and_test_keys_are_excluded(self):
        d = doc(cfg(".github/workflows/ci.yml", 1, "on", role="ci"), cfg("tests/app.ini", 1, "X", test=True))
        out = fill.render_block("config-reference", d)
        self.assertIn("No application config keys were extracted.", out)
        self.assertTrue(out.endswith("0 env-var keys and 1 CI keys are excluded from the application table (see facts.json)."))

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
        self.assertTrue(out.endswith("Shown 1 of 1 application keys."))

    def test_unclassified_keys_are_not_listed_but_trailered(self):
        d = doc(cfg("a.ini", 1, "K", role="app"),
                cfg("custom/ClientRes.properties", 1, "X", role="unclassified"),
                cfg("custom/ClientRes.properties", 2, "Y", role="unclassified"))
        out = fill.render_block("config-reference", d)
        self.assertIn("| K | `a.ini:1` | no |", out)
        self.assertNotIn("`X`", out)
        self.assertIn("2 keys in 1 file(s) were not classified as application configuration", out)
        self.assertIn("`custom/ClientRes.properties`", out)

    def test_unclassified_trailer_alone_when_no_app_keys(self):
        d = doc(cfg("custom/ClientRes.properties", 1, "X", role="unclassified"))
        out = fill.render_block("config-reference", d)
        self.assertIn("No application config keys were extracted.", out)
        self.assertIn("1 keys in 1 file(s) were not classified", out)


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
        masked = fill.mask_blocks(self.TEXT, ("entry-points", "scheduled-jobs"))
        self.assertEqual(masked.count("\n"), self.TEXT.count("\n"))
        self.assertNotIn("old", masked)
        self.assertIn("keep", masked)  # unnamed blocks are left alone
        filled = fill.fill_text(self.TEXT, doc(route("a.py")))[0]
        self.assertEqual(fill.mask_blocks(filled, ("entry-points",)).count("\n"), filled.count("\n"))
        self.assertNotIn("a.py", fill.mask_blocks(filled, ("entry-points",)))

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
        self.assertIn("1 route handler files; 1 routes", once)
        self.assertIn("time-boxed", once)


if __name__ == "__main__":
    unittest.main()
