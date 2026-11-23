"""Core guarantees: every Stack loads, the Facts file is reproducible, and no secret value leaks."""

import json
import os
import shutil
import tempfile
import unittest
from unittest import mock

from appdoc import extract, facts, scan, secrets
from appdoc.stacks import load, generic

HERE = os.path.dirname(os.path.abspath(__file__))
SAMPLES = os.path.join(HERE, "samples")
SAMPLE_NAMES = sorted(d for d in os.listdir(SAMPLES) if os.path.isdir(os.path.join(SAMPLES, d)) and d != "docs")


def run(name):
    out = os.path.join(tempfile.gettempdir(), "appdoc-unused-out")
    return extract.extract(os.path.join(SAMPLES, name), out)


class RegistryTests(unittest.TestCase):
    def test_all_six_stacks_load_with_unique_ids(self):
        ids = [s.id for s in load()]
        self.assertEqual(sorted(ids), sorted([
            "classic-asp", "aspnet", "aspnet-core", "java-spring", "python-flask", "node-express", "go"]))
        self.assertEqual(len(ids), len(set(ids)))

    def test_every_stack_has_a_sample_and_detects_it(self):
        by_id = {s.id: s for s in load()}
        for sid, stack in by_id.items():
            paths = [f.path for f in scan.walk(os.path.join(SAMPLES, sid))]
            self.assertTrue(stack.detect(paths), f"{sid} does not detect its own sample")


class ReproducibleTests(unittest.TestCase):
    def test_two_runs_are_byte_identical_for_every_sample(self):
        for name in SAMPLE_NAMES:
            a = run(name)
            b = run(name)
            self.assertEqual(a, b, name)

    def test_walk_order_does_not_matter(self):
        real_walk = os.walk

        def reversed_walk(top, *args, **kwargs):
            for dirpath, dirnames, filenames in real_walk(top, *args, **kwargs):
                dirnames.reverse()
                filenames.reverse()
                yield dirpath, dirnames, filenames

        for name in SAMPLE_NAMES:
            normal = run(name)
            with mock.patch("appdoc.scan.os.walk", reversed_walk):
                self.assertEqual(normal, run(name), name)

    def test_facts_file_has_no_timestamps_or_absolute_paths(self):
        for name in SAMPLE_NAMES:
            text, _ = run(name)
            doc = json.loads(text)
            self.assertEqual(doc["schema"], facts.SCHEMA)
            for f in doc["facts"]:
                self.assertNotIn("\\", f["path"])
                self.assertFalse(f["path"].startswith("/"))
                self.assertFalse(len(f["path"]) > 1 and f["path"][1] == ":")
            self.assertNotIn(SAMPLES, text)
            self.assertNotRegex(text, r"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}")

    def test_facts_are_sorted_and_unique(self):
        text, _ = run("java-spring")
        items = json.loads(text)["facts"]
        keys = [(f["path"], f["line"] or 0, f["kind"], f["name"]) for f in items]
        self.assertEqual(keys, sorted(keys))

    def test_summary_is_reproducible_and_lists_stacks(self):
        _, s1 = run("classic-asp")
        _, s2 = run("classic-asp")
        self.assertEqual(s1, s2)
        self.assertIn("| classic-asp | yes |", s1)


class SecretTests(unittest.TestCase):
    PLANTED = [
        "AKIAIOSFODNN7EXAMPLE",
        "hunter2hunter2xyz",
        "ghp_abcdefghijklmnopqrstuvwxyz0123456789",
    ]

    def test_secrets_sample_never_leaks_a_value(self):
        text, summary = run("secrets")
        for value in self.PLANTED:
            for chunk in (value, value[:8]):
                self.assertNotIn(chunk, text)
                self.assertNotIn(chunk, summary)

    def test_secret_locations_are_flagged_by_key_name(self):
        doc = json.loads(run("secrets")[0])
        flagged = [f for f in doc["facts"] if f["kind"] == "config_key" and f["detail"].get("secret_location")]
        self.assertTrue(any(f["name"] == "DB_PASSWORD" for f in flagged))

    def test_no_sample_leaks_any_connection_password(self):
        for name in SAMPLE_NAMES:
            text, _ = run(name)
            for needle in ("fakepass", "Password=", "Pwd="):
                self.assertNotIn(needle, text, f"{name}: {needle}")

    def test_secret_shape_finder_reports_lines_not_values(self):
        hits = secrets.find_secret_shapes("ok\nkey AKIAIOSFODNN7EXAMPLE here\nPassword=abc12345;\n")
        self.assertEqual([h[0] for h in hits], [2, 3])
        self.assertTrue(all(isinstance(h[1], str) and "AKIA" not in h[1] for h in hits))

    def test_commit_hashes_and_guids_are_not_secrets(self):
        self.assertEqual(secrets.find_secret_shapes("token = 30b662ed4e8a21908a2ade37e63f5e9ff17db4ce"), [])
        self.assertEqual(secrets.find_secret_shapes("api_key = 123e4567-e89b-12d3-a456-426614174000"), [])

    def test_path_citations_after_a_secret_word_are_not_secrets(self):
        for line in (
            "The reset token: `portal/HelpWeb/functions/pwreset_long_name.asp:123` is read here.",
            "password: `To be deleted/FrontCounterDev/logcall_archive.asp:212`",
            "secret: portal/some/long/path/with/many/segments/file.asp:123",
            "token = src\\main\\java\\com\\example\\security\\TokenService.java:40-52",
            "token: `appsettings.Production.environment.override.json:12`",
            "The token: `portal/some/long/path/file.asp:123`.",
        ):
            self.assertEqual(secrets.find_secret_shapes(line), [], line)

    def test_real_secret_values_are_still_found(self):
        for line in (
            "token = Xk9fQ2mZp7LwR4tYv8NbC3dHs6JgA1eU",
            'secret: "dGhpc2lzYXZlcnlsb25nYmFzZTY0c2VjcmV0dmFsdWUxMjM9ISE="',
            "The token: `Xk9fQ2mZp7LwR4tYv8NbC3dHs6JgA1eU` is used.",
            "password: Xk9fQ2mZp7LwR4/tYv8NbC3dHs6JgA1eU+Zq",
            "api_key: AKIAIOSFODNN7EXAMPLE",
            'api_key: "AKIAIOSFODNN7EXAMPLE"',
        ):
            self.assertTrue(secrets.find_secret_shapes(line), line)


class ScanTests(unittest.TestCase):
    def setUp(self):
        self.root = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, self.root, True)

    def write(self, rel, data, mode="w"):
        p = os.path.join(self.root, rel)
        os.makedirs(os.path.dirname(p), exist_ok=True)
        if isinstance(data, bytes):
            with open(p, "wb") as fh:
                fh.write(data)
        else:
            with open(p, "w", encoding="utf-8") as fh:
                fh.write(data)

    def test_ignored_dirs_and_appdocignore(self):
        self.write("src/a.py", "x = 1\n")
        self.write("node_modules/b.js", "x\n")
        self.write("legacy/old.py", "x\n")
        self.write(".appdocignore", "legacy\n")
        paths = [f.path for f in scan.walk(self.root)]
        self.assertEqual(paths, [".appdocignore", "src/a.py"])

    def test_binary_and_large_files_are_listed_but_skipped(self):
        self.write("img.bin", b"\x00\x01\x02", "wb")
        self.write("big.txt", "a" * (scan.MAX_BYTES + 1))
        flags = {f.path: f.skipped for f in scan.walk(self.root)}
        self.assertEqual(flags, {"big.txt": "size", "img.bin": "binary"})

    def test_cp1252_is_decoded_without_error(self):
        self.write("legacy.asp", "caf\xe9".encode("cp1252"), "wb")
        text, enc = scan.read_text(self.root, "legacy.asp")
        self.assertEqual((text, enc), ("caf\xe9", "cp1252"))

    def test_output_dir_is_not_scanned(self):
        self.write("a.py", "x\n")
        self.write("docs/appdoc/facts.json", "{}")
        paths = [f.path for f in scan.walk(self.root, os.path.join(self.root, "docs", "appdoc"))]
        self.assertEqual(paths, ["a.py"])

    def walk_stats(self):
        stats = {}
        paths = [f.path for f in scan.walk(self.root, None, stats)]
        return paths, stats

    def test_nested_packages_folder_with_source_is_scanned(self):
        self.write("routers/api/packages/api.go", "package packages\n")
        self.write("build/generate.go", "package main\n")
        paths, stats = self.walk_stats()
        self.assertEqual(paths, ["build/generate.go", "routers/api/packages/api.go"])
        self.assertEqual(stats["pruned"], [])

    def test_build_output_is_pruned_on_evidence_and_counted(self):
        self.write("App.sln", "x\n")
        self.write("packages/Foo.1.0/Foo.1.0.nupkg", b"\x00", "wb")
        self.write("src/Web/Web.csproj", "<Project/>\n")
        self.write("src/Web/bin/Debug/Web.dll", b"\x00", "wb")
        self.write("src/Web/obj/a.json", "{}")
        self.write("web/package.json", "{}")
        self.write("web/dist/app.js", "x\n")
        self.write("pom.xml", "<project/>\n")
        self.write("target/classes/A.class", b"\x00", "wb")
        self.write(".git/HEAD", "ref\n")
        paths, stats = self.walk_stats()
        self.assertEqual(paths, ["App.sln", "pom.xml", "src/Web/Web.csproj", "web/package.json"])
        self.assertEqual([(p["path"], p["files"]) for p in stats["pruned"]],
                         [("packages/", 1), ("src/Web/bin/", 1), ("src/Web/obj/", 1), ("target/", 1), ("web/dist/", 1)])

    def test_appdocignore_bang_reincludes_a_pruned_folder(self):
        self.write("web/package.json", "{}")
        self.write("web/dist/app.js", "x\n")
        self.write(".appdocignore", "!dist\n")
        paths, stats = self.walk_stats()
        self.assertIn("web/dist/app.js", paths)
        self.assertEqual(stats["pruned"], [])

    def test_facts_reconcile_found_scanned_pruned_ignored(self):
        self.write("a.py", "x\n")
        self.write("legacy/b.py", "x\n")
        self.write(".appdocignore", "legacy\n")
        self.write("node_modules/c/index.js", "x\n")
        text, summary = extract.extract(self.root, os.path.join(self.root, "docs", "appdoc"))
        sc = json.loads(text)["target"]["scan"]
        self.assertEqual((sc["found"], sc["scanned"], sc["pruned_files"], sc["ignored"]), (4, 2, 1, 1))
        self.assertIn("Files found: 4 = scanned 2 + pruned 1", summary)
        self.assertIn("| `node_modules/` | always | 1 |", summary)

    def test_os_and_authoring_metadata_are_dropped_and_counted(self):
        self.write("a.py", "x\n")
        self.write("desktop.ini", "[.ShellClassInfo]\n")
        self.write("Thumbs.db", b"\x00\x01")
        self.write(".DS_Store", b"\x00")
        self.write("_vti_cnf/x.asp", "x\n")
        paths, stats = self.walk_stats()
        self.assertEqual(paths, ["a.py"])
        self.assertEqual(stats["metadata"], 4)  # 3 files + 1 in _vti_cnf

    def test_retired_candidate_by_name(self):
        self.write("a.py", "x\n")
        self.write("old/legacy.py", "x\n")
        self.write("To be deleted/Front Dev/logcall.asp", "x\n")
        _, stats = self.walk_stats()
        names = {c["path"] for c in stats["retired_candidates"]}
        self.assertIn("old/", names)
        self.assertIn("To be deleted/", names)  # the shallowest matching folder

    def test_retired_candidate_by_content(self):
        self.write("src/a.py", "same content\n")
        self.write("src/b.py", "same content\n")
        self.write("src/c.py", "same content\n")
        self.write("src/d.py", "same content\n")
        self.write("src/e.py", "same content\n")
        self.write("other/a.py", "same content\n")
        _, stats = self.walk_stats()
        # src has 5 files, all byte-identical to other/a.py -> content signal
        self.assertIn({"path": "src/", "signal": "content", "files": 5}, stats["retired_candidates"])

    def test_retired_token_matcher(self):
        from appdoc.scan import _retired_name_signal
        for name in ("old", "household-old", "site-old", "OLD_site", "To Be Deleted", "tobedeleted",
                     "deprecated", "bak", "archive", "unused", "trash", "deleteme"):
            self.assertEqual(_retired_name_signal(name), "name", name)
        for name in ("household", "older", "copycat", "new", "src"):
            self.assertIsNone(_retired_name_signal(name), name)


@unittest.skipUnless(shutil.which("git"), "git not installed")
class GitScopeTests(unittest.TestCase):
    """Commit and ownership come only from a Target's own repo, never a parent repo."""

    def git(self, cwd, *args):
        import subprocess
        subprocess.run(["git", "-C", cwd, "-c", "user.name=T", "-c", "user.email=t@example.com", *args],
                       check=True, capture_output=True)

    def setUp(self):
        self.repo = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, self.repo, True)
        os.makedirs(os.path.join(self.repo, "sub", "src"))
        with open(os.path.join(self.repo, "sub", "src", "a.py"), "w") as fh:
            fh.write("x = 1\n")
        with open(os.path.join(self.repo, "top.py"), "w") as fh:
            fh.write("y = 2\n")
        self.git(self.repo, "init", "-q")
        self.git(self.repo, "add", "-A")
        self.git(self.repo, "commit", "-q", "-m", "init")
        self.out = os.path.join(self.repo, "docs", "appdoc")

    def test_repo_root_gets_commit_and_ownership(self):
        doc = json.loads(extract.extract(self.repo, self.out)[0])
        self.assertIsNotNone(doc["target"]["commit"])
        self.assertTrue([f for f in doc["facts"] if f["kind"] == "ownership"])

    def test_target_nested_in_a_repo_borrows_nothing(self):
        sub = os.path.join(self.repo, "sub")
        doc = json.loads(extract.extract(sub, os.path.join(sub, "docs", "appdoc"))[0])
        self.assertIsNone(doc["target"]["commit"])
        self.assertEqual([f for f in doc["facts"] if f["kind"] == "ownership"], [])


class TestCodeAndHistoryTests(unittest.TestCase):
    def test_is_test_path(self):
        for p in ["src/test/java/a/FooTest.java", "tests/test_x.py", "app/__tests__/a.js", "a/b.spec.ts",
                  "x/FooIT.java", "svc/Foo.Tests.cs", "pkg/foo_test.py", "web/app.test.js"]:
            self.assertTrue(extract.is_test_path(p), p)
        for p in ["src/main/java/Foo.java", "app/contest.py", "latest/a.py", "src/Attest.java"]:
            self.assertFalse(extract.is_test_path(p), p)

    def test_test_facts_are_marked_and_left_out_of_summary(self):
        root = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, root, True)
        for rel, body in (("app.py", "import requests\nrequests.get('http://prod.example/api')\n"),
                          ("tests/test_app.py", "import requests\nrequests.get('http://test.example/x')\n")):
            p = os.path.join(root, rel)
            os.makedirs(os.path.dirname(p), exist_ok=True)
            with open(p, "w") as fh:
                fh.write(body)
        text, summary = extract.extract(root, os.path.join(root, "docs", "appdoc"))
        calls = [f for f in json.loads(text)["facts"] if f["kind"] == "external_call"]
        self.assertTrue(any(f["detail"].get("test") for f in calls) or not calls)
        for f in calls:
            self.assertEqual(bool(f["detail"].get("test")), f["path"].startswith("tests/"))
        self.assertNotIn("tests/test_app.py", summary.split("## Largest source files")[-1].split("## Entry points")[-1])

    def test_summary_wording_for_empty_lists(self):
        doc = {"schema": "s", "target": {"name": "t", "commit": None, "history": "none"}, "stacks": [], "facts": []}
        from appdoc.summary import render_summary
        out = render_summary(doc)
        self.assertIn("not proof of absence", out)
        self.assertIn("Git history: none", out)

    @unittest.skipUnless(shutil.which("git"), "git not installed")
    def test_shallow_clone_has_no_ownership(self):
        import subprocess
        src = tempfile.mkdtemp(); dst = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, src, True); self.addCleanup(shutil.rmtree, dst, True)
        os.makedirs(os.path.join(src, "pkg"))
        for i in (1, 2):
            with open(os.path.join(src, "pkg", "a.py"), "w") as fh:
                fh.write(f"x = {i}\n")
            for a in (["add", "-A"], ["commit", "-q", "-m", str(i)]):
                subprocess.run(["git", "-C", src, "-c", "user.name=T", "-c", "user.email=t@e.com", *(["init", "-q"] if False else []), *a],
                               check=True, capture_output=True) if os.path.isdir(os.path.join(src, ".git")) else None
            if i == 1 and not os.path.isdir(os.path.join(src, ".git")):
                subprocess.run(["git", "-C", src, "init", "-q"], check=True, capture_output=True)
                subprocess.run(["git", "-C", src, "add", "-A"], check=True, capture_output=True)
                subprocess.run(["git", "-C", src, "-c", "user.name=T", "-c", "user.email=t@e.com", "commit", "-q", "-m", "1"],
                               check=True, capture_output=True)
        shutil.rmtree(dst)
        subprocess.run(["git", "clone", "-q", "--depth", "1", "file://" + src.replace("\\", "/"), dst],
                       check=True, capture_output=True)
        doc = json.loads(extract.extract(dst, os.path.join(dst, "docs", "appdoc"))[0])
        self.assertEqual(doc["target"]["history"], "shallow")
        self.assertEqual([f for f in doc["facts"] if f["kind"] == "ownership"], [])
        full = json.loads(extract.extract(src, os.path.join(src, "docs", "appdoc"))[0])
        self.assertEqual(full["target"]["history"], "full")


class GenericTests(unittest.TestCase):
    def names(self, path, text, kind):
        return sorted(f.name for f in generic.extract(path, text) if f.kind == kind)

    def test_web_config_keys_and_connections_without_values(self):
        cfg = ('<configuration><appSettings><add key="Mode" value="x"/></appSettings>'
               '<connectionStrings><add name="Main" connectionString="Server=s;Password=hunter2pw;"/>'
               '</connectionStrings></configuration>')
        out = list(generic.extract("web.config", cfg))
        self.assertIn("Mode", [f.name for f in out if f.kind == "config_key"])
        conn = [f for f in out if f.kind == "connection"]
        self.assertEqual([c.name for c in conn], ["Main"])
        self.assertTrue(conn[0].detail_dict()["secret_location"])
        self.assertNotIn("hunter2pw", repr(out))

    def test_dependency_manifests(self):
        self.assertEqual(self.names("requirements.txt", "flask==2.0\n# c\nrequests>=2\n", "dependency"), ["flask", "requests"])
        self.assertEqual(self.names("package.json", '{"dependencies":{"express":"^4"}}', "dependency"), ["express"])
        self.assertEqual(self.names("app.csproj", '<PackageReference Include="Dapper" Version="2.0" />', "dependency"), ["Dapper"])

    def test_unsupported_ecosystems_are_reported(self):
        got = dict(generic.unsupported_stacks(["go.mod", "main.go", "Gemfile"], set()))
        self.assertEqual(sorted(got), ["go", "ruby"])

    def test_supported_ecosystem_is_not_reported(self):
        self.assertEqual(generic.unsupported_stacks(["package.json"], {"node-express"}), [])

    def test_config_roles(self):
        cases = {
            "src/main/resources/application.properties": "app",
            "src/main/resources/messages/messages_de.properties": None,
            "pnpm-lock.yaml": None,
            "options/locale/locale_en-US.ini": None,
            ".github/workflows/ci.yml": "ci",
            "k8s/db.yml": "orchestration",
            "docker-compose.yml": "orchestration",
            ".mvn/wrapper/maven-wrapper.properties": "build",
            "custom/conf/app.example.ini": "unclassified",
            "src/Identity.API/appsettings.json": "app",
            "config/settings.json": "app",
        }
        for path, role in cases.items():
            self.assertEqual(generic.config_role(path), role, path)

    def test_lockfiles_and_message_bundles_yield_no_config_keys(self):
        self.assertEqual(self.names("pnpm-lock.yaml", "lockfileVersion: '9.0'\n", "config_key"), [])
        self.assertEqual(self.names("src/messages.properties", "welcome=Hi\n", "config_key"), [])
        keys = [f for f in generic.extract("src/application.properties", "server.port=8080\n") if f.kind == "config_key"]
        self.assertEqual([(f.name, f.detail_dict()["role"]) for f in keys], [("server.port", "app")])

    def test_ini_keys_and_documented_defaults_without_values(self):
        ini = ("APP_NAME = Gitea\n[server]\n;HTTP_PORT = 3000\n; see the docs = here\n"
               "[database]\nPASSWD = hunter2pw\n")
        out = [f for f in generic.extract("custom/conf/app.example.ini", ini) if f.kind == "config_key"]
        got = {f.name: f.detail_dict() for f in out}
        self.assertEqual(sorted(got), ["APP_NAME", "database.PASSWD", "server.HTTP_PORT"])
        self.assertTrue(got["server.HTTP_PORT"]["commented"])
        self.assertTrue(got["database.PASSWD"]["secret_location"])
        self.assertNotIn("hunter2pw", repr(out))


class OwnerContextTests(unittest.TestCase):
    def case(self, name):
        from tests.test_corpus import run_case
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        return run_case(name, tmp=tmp)

    def test_owner_context_detected(self):
        r = self.case("owner-present")
        files = [f for f in r.facts_of("owner_file") if f["path"] == "appdoc-context.md"]
        self.assertEqual(len(files), 1, r.facts_of("owner_file"))
        own = [f for f in r.facts_of("ownership") if f["detail"].get("source") == "appdoc-context.md"]
        self.assertEqual(sorted(f["detail"]["role"] for f in own), ["Business owner", "Technical owner"])
        self.assertEqual(sorted(f["line"] for f in own), [3, 4])
        self.assertNotIn("Registrar", json.dumps(r.facts))  # values (possibly personal) never enter Facts
        self.assertFalse(self.case("owner-absent").facts_of("owner_file"))

    def test_owner_absent_advisory(self):
        absent = self.case("owner-absent")
        self.assertEqual(absent.code, 0, absent.report)
        self.assertIn("ownership is Unknown by absence (no appdoc-context.md)", absent.report)
        self.assertIn("deployment runbook is Unknown by absence (no appdoc-context.md)", absent.report)
        present = self.case("owner-present")
        self.assertEqual(present.code, 0, present.report)
        self.assertNotIn("Unknown by absence", present.report)


if __name__ == "__main__":
    unittest.main()


class VersionCompareTests(unittest.TestCase):
    def test_version_tuple(self):
        from appdoc.template_spec import version_tuple
        self.assertEqual(version_tuple("2.4"), (2, 4))
        self.assertEqual(version_tuple("2.10.1"), (2, 10, 1))
        self.assertEqual(version_tuple("2.6.0.dev0"), (2, 6, 0))
        self.assertGreater(version_tuple("2.10"), version_tuple("2.9"))  # a string compare says otherwise
        self.assertEqual(version_tuple(""), ())
        self.assertEqual(version_tuple("none"), ())
        self.assertEqual(version_tuple(None), ())

    def test_no_string_version_compares(self):
        import re
        pkg = os.path.join(os.path.dirname(HERE), "appdoc")
        bad = []
        for dirpath, _, names in os.walk(pkg):
            for n in names:
                if n.endswith(".py"):
                    with open(os.path.join(dirpath, n), encoding="utf-8") as fh:
                        for i, line in enumerate(fh, 1):
                            if re.search(r"(?:>=|<=|<|>)\s*[\"']\d+\.\d", line):
                                bad.append(f"{n}:{i}: {line.strip()}")
        self.assertEqual(bad, [])
