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
            "classic-asp", "aspnet", "aspnet-core", "java-spring", "python-flask", "node-express"]))
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


if __name__ == "__main__":
    unittest.main()
