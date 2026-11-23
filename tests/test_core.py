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

    SECRET_NAMES = (
        "PASSWORD", "DB_PASSWORD", "db.password", "dbPassword", "DBPassword", "SECRET_KEY", "SECRET_KEY_BASE",
        "client_secret", "ClientSecret", "API_TOKEN", "access_token", "accessToken", "AUTH_TOKEN", "api_key",
        "API-KEY", "apiKey", "APIKey", "private_key", "PrivateKey", "connection_string", "ConnectionString",
        "account_key", "AccountKey", "credentials", "user_credentials", "pwd", "DB_PWD", "passwd", "sas_token",
        "SAS", "JWT_SECRET", "jwt.secret", "LDAP_BIND_PASSWORD", "smtp_password", "dbpassword", "accesstoken",
        "TOKEN", "APP_SECRET", "server.SECRET_KEY")
    NOT_SECRET_NAMES = (
        # gitea's
        "MIN_PASSWORD_LENGTH", "PASSWORD_COMPLEXITY", "PASSWORD_HASH_ALGO", "PASSWORD_CHECK_PWN",
        "ENABLE_PASSWORD_SIGNIN_FORM", "DISABLE_PASSWORD_RESET", "ALLOW_PASSWORD_CHANGE", "REQUIRE_PASSWORD",
        "SECRET_KEY_URI", "INTERNAL_TOKEN_URI", "JWT_SECRET_URI",
        # the closed modifier set, one name each
        "MAX_PASSWORD_LENGTH", "PASSWORD_POLICY", "password.min.length", "passwordMinLength", "TOKEN_TTL",
        "TOKEN_LIFETIME", "TOKEN_EXPIRY", "TOKEN_EXPIRES_MINUTES", "SECRET_CACHE_TTL", "SECRET_HEADER",
        "TOKEN_HEADER_NAME", "SECRET_NAME", "TOKEN_TYPE", "PASSWORD_MODE", "TOKEN_SCOPE", "PASSWORD_REGEX",
        "PASSWORD_PATTERN", "PASSWORD_RESET_URL", "PASSWORD_FILE", "password_path", "passwordlength",
        # no secret noun
        "HTTP_PORT", "DOMAIN", "USERNAME", "KEY", "DB_HOST", "tokenizer", "secretary", "passenger", "server.DOMAIN",
        "ENCRYPTION_ALGORITHM", "", None)

    def test_secret_key_segments(self):
        self.assertGreaterEqual(len([n for n in self.SECRET_NAMES]), 20)
        self.assertGreaterEqual(len([n for n in self.NOT_SECRET_NAMES if n]), 25)
        for name in self.SECRET_NAMES:
            self.assertTrue(secrets.is_secret_key(name), name)
        for name in self.NOT_SECRET_NAMES:
            self.assertFalse(secrets.is_secret_key(name), name)

    def test_never_record_value_is_superset(self):
        for name in self.SECRET_NAMES + self.NOT_SECRET_NAMES:
            if secrets.is_secret_key(name):
                self.assertTrue(secrets.never_record_value(name), name)
        for name in self.SECRET_NAMES:
            self.assertTrue(secrets.never_record_value(name), name)
        for name in ("", None, "HTTP_PORT", "DB_HOST", "USERNAME", "KEY", "DOMAIN"):
            self.assertFalse(secrets.never_record_value(name), name)

    def test_password_hash_not_flagged_but_never_recorded(self):
        for name in ("PasswordHash", "PASSWORD_HASH_ALGO", "TokenCache", "TOKEN_CACHE_TTL", "PasswordFile",
                     "SECRET_HEADER", "MIN_PASSWORD_LENGTH"):
            self.assertFalse(secrets.is_secret_key(name), name)
            self.assertTrue(secrets.never_record_value(name), name)

    def test_config_key_facts_never_carry_a_value(self):
        self.assertNotIn("value", facts.DETAIL_KEYS["config_key"])
        root = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, root, True)
        os.makedirs(os.path.join(root, "conf"))
        with open(os.path.join(root, "conf", "app.ini"), "w") as fh:
            fh.write("[db]\nDB_PASSWORD = hunter2value\nPASSWORD_HASH = sha256valuehere\nHTTP_PORT = 8123\n")
        docs = [json.loads(extract.extract(root, os.path.join(root, "out"))[0]),
                json.loads(run("secrets")[0])]
        for doc in docs:
            cfg = [f for f in doc["facts"] if f["kind"] == "config_key"]
            self.assertTrue(cfg)
            for f in cfg:
                self.assertNotIn("value", f["detail"], f["name"])
                for v in f["detail"].values():
                    self.assertNotIn(v, ("hunter2value", "sha256valuehere", "8123"), f["name"])

    def test_secret_ref_flag(self):
        for name in ("SECRET_KEY_URI", "INTERNAL_TOKEN_URI", "DB_PASSWORD_FILE", "password_path", "PasswordFile"):
            self.assertTrue(secrets.is_secret_ref(name), name)
            self.assertFalse(secrets.is_secret_key(name), name)
        for name in ("DB_PASSWORD", "MIN_PASSWORD_LENGTH", "PASSWORD_RESET_URL", "HTTP_PORT", "PASSWORD_MIN_FILE", ""):
            self.assertFalse(secrets.is_secret_ref(name), name)
        root = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, root, True)
        os.makedirs(os.path.join(root, "conf"))
        with open(os.path.join(root, "conf", "app.ini"), "w") as fh:
            fh.write("[security]\nSECRET_KEY_URI = file:/etc/key\nINTERNAL_TOKEN = abc\nMIN_PASSWORD_LENGTH = 8\n")
        doc = json.loads(extract.extract(root, os.path.join(root, "out"))[0])
        keys = {f["name"]: f["detail"] for f in doc["facts"] if f["kind"] == "config_key"}
        self.assertIs(keys["security.SECRET_KEY_URI"].get("secret_ref"), True)
        self.assertFalse(keys["security.SECRET_KEY_URI"].get("secret_location"))
        self.assertIs(keys["security.INTERNAL_TOKEN"].get("secret_location"), True)
        self.assertNotIn("secret_ref", keys["security.INTERNAL_TOKEN"])
        self.assertFalse(keys["security.MIN_PASSWORD_LENGTH"].get("secret_location"))
        self.assertNotIn("secret_ref", keys["security.MIN_PASSWORD_LENGTH"])
        self.assertIn("secret_ref", facts.DETAIL_KEYS["config_key"])

    def test_c6_unaffected_by_key_naming(self):
        """C6 finds secret-shaped values by their shape and an assignment's key text, not by is_secret_key."""
        value = "Xk9fQ2mZp7LwR4tYv8NbC3dHs6JgA1eU"
        for name in ("MIN_PASSWORD_LENGTH", "PASSWORD_FILE", "SECRET_KEY_URI", "password_policy", "DB_PASSWORD"):
            self.assertEqual([h[1] for h in secrets.find_secret_shapes(f"{name} = {value}")],
                             ["high-entropy-secret"], name)
        self.assertEqual(secrets.find_secret_shapes("Password=abc12345;"), [(1, "connection-string-password")])

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

    def _twin(self, folder, n=5, body="same content {}\n"):
        for i in range(n):
            self.write(f"{folder}/f{i}.py", body.format(i))

    def test_retired_name_signal_only(self):
        self._twin("src")
        self._twin("other")
        self.write("old/legacy.py", "x\n")
        _, stats = self.walk_stats()
        self.assertEqual(stats["retired_candidates"], [{"path": "old/", "signal": "name", "files": 1}])

    def test_content_index_reads_each_file_once(self):
        self._twin("src")
        self._twin("other")
        self.write("img.bin", b"\x00\x01", "wb")
        self.write("big.txt", "a" * (scan.MAX_BYTES + 1))
        seen = []
        real = scan._sha1_file

        def spy(full):
            seen.append(os.path.relpath(full, self.root).replace(os.sep, "/"))
            return real(full)
        with mock.patch.object(scan, "_sha1_file", spy):
            self.walk_stats()
        self.assertEqual(len(seen), len(set(seen)), "a file was hashed twice")
        self.assertEqual(len(seen), 10)  # skipped binary and oversize files are never read

    def test_content_index_by_hash(self):
        self.write("a/x.py", "same\n")
        self.write("b/y.py", "same\n")
        self.write("c/z.py", "other\n")
        self.write("tests/t.py", "same\n")
        files = scan.walk(self.root)
        by_path, by_hash = scan._content_index(self.root, files)
        self.assertNotIn("tests/t.py", by_path)
        self.assertEqual(sorted(sorted(v) for v in by_hash.values()), [["a/x.py", "b/y.py"], ["c/z.py"]])

    def test_duplicates_under_test_paths_ignored(self):
        self._twin("tests/one")
        self._twin("tests/two")
        _, stats = self.walk_stats()
        self.assertEqual(stats["duplicate_folders"], [])
        self.assertEqual(stats["retired_candidates"], [])

    def test_duplicate_pair_reported_once(self):
        self._twin("alpha")
        self._twin("beta")
        self.write("main.py", "print(1)\n")
        _, stats = self.walk_stats()
        self.assertEqual(stats["retired_candidates"], [])
        self.assertEqual(stats["duplicate_folders"], [{"a": "alpha/", "b": "beta/", "files": 5}])

    def test_duplicate_below_threshold_not_reported(self):
        self._twin("alpha", 4)
        self._twin("beta", 4)
        _, stats = self.walk_stats()
        self.assertEqual(stats["duplicate_folders"], [])

    def test_duplicate_needs_half_of_the_hashes(self):
        self._twin("alpha", 4)
        for i in range(4):
            self.write(f"alpha/own{i}.py", f"unique {i}\n")
        self._twin("beta", 4)  # beta has under 5 files, so only alpha can be the first side
        _, stats = self.walk_stats()  # alpha: 4 of 8 match (50%)
        self.assertEqual([(d["a"], d["b"]) for d in stats["duplicate_folders"]], [("alpha/", "beta/")])
        self.write("alpha/own4.py", "unique 4\n")
        _, stats = self.walk_stats()  # alpha: 4 of 9 (<50%)
        self.assertEqual(stats["duplicate_folders"], [])

    def test_duplicate_threshold_ignores_empty_files(self):
        for d in ("alpha", "beta"):
            self._twin(d, 4)
            for i in range(5):
                self.write(f"{d}/empty{i}.py", "")
        _, stats = self.walk_stats()  # 4 of the 4 hashed files match; the 5 empty files are not in the denominator
        self.assertEqual(stats["duplicate_folders"], [{"a": "alpha/", "b": "beta/", "files": 4}])

    def test_duplicate_tie_break_sorted(self):
        # alpha, beta and gamma are identical: each pairs with the smallest other path.
        self._twin("gamma")
        self._twin("beta")
        self._twin("alpha")
        self._twin("zeta", 5, "zeta only {}\n")
        self._twin("zeta2", 5, "zeta only {}\n")
        _, stats = self.walk_stats()
        pairs = [(d["a"], d["b"]) for d in stats["duplicate_folders"]]
        self.assertEqual(pairs, [("alpha/", "beta/"), ("alpha/", "gamma/"), ("zeta/", "zeta2/")])
        self.assertTrue(all(a < b for a, b in pairs))

    def test_nested_candidates_collapsed(self):
        self.write("old/readme.txt", "x\n")
        self.write("old/sub_backup/x.py", "x\n")
        self.write("live/readme.txt", "x\n")
        self._twin("live")
        self._twin("old/sub")
        _, stats = self.walk_stats()
        self.assertEqual([c["path"] for c in stats["retired_candidates"]], ["old/"])
        for d in stats["duplicate_folders"]:
            self.assertFalse(d["a"].startswith("old/sub") or d["b"].startswith("old/sub"), d)
        self.assertEqual([(d["a"], d["b"]) for d in stats["duplicate_folders"]], [("live/", "old/")])

    def test_prune_prior_appdoc_output(self):
        self.write("main.py", "x\n")
        self.write("old-docs/facts.json", '{\n "facts": [],\n "schema": "appdoc-facts/6"\n}\n')
        self.write("old-docs/notes.txt", "keep out\n")
        self.write("more/application-documentation.md", "# T\n<!-- appdoc:template 2.4 -->\nbody\n")
        paths, stats = self.walk_stats()
        self.assertEqual(paths, ["main.py"])
        self.assertEqual(stats["pruned"], [{"path": "more/", "rule": "AppDoc output", "files": 1},
                                           {"path": "old-docs/", "rule": "AppDoc output", "files": 2}])

    def test_prune_skill_bundle(self):
        self.write("main.py", "x\n")
        self.write("tools/skill/run_appdoc.py", "x\n")
        self.write("tools/skill/appdoc/assets/template.md", "t\n")
        self.write("tools/skill/appdoc/check.py", "x\n")
        self.write("other/run_appdoc.py", "x\n")  # a launcher alone is not the bundle
        paths, stats = self.walk_stats()
        self.assertEqual(paths, ["main.py", "other/run_appdoc.py"])
        self.assertEqual(stats["pruned"], [{"path": "tools/skill/", "rule": "AppDoc skill bundle", "files": 3}])

    def test_appdocignore_reincludes_appdoc_output(self):
        self.write("old-docs/facts.json", '{"schema": "appdoc-facts/6"}\n')
        self.write(".appdocignore", "!old-docs\n")
        paths, stats = self.walk_stats()
        self.assertIn("old-docs/facts.json", paths)
        self.assertEqual(stats["pruned"], [])

    def test_plain_docs_folder_not_pruned(self):
        self.write("docs/facts.json", '{"schema": "something-else/1"}\n')
        self.write("docs/application-documentation.md", "# My own doc\nno marker\n")
        self.write("docs/late.md", "x\n")
        # the marker beyond the first 4 KiB is not looked at
        self.write("docs2/application-documentation.md", "a" * 5000 + "\n<!-- appdoc:template 2.4 -->\n")
        paths, stats = self.walk_stats()
        self.assertEqual(len(paths), 4)
        self.assertEqual(stats["pruned"], [])

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

    def test_ownership_has_no_author_names(self):
        import subprocess
        for name, day in (("Zed Quux", "2024-03-01T10:00:00"), ("Ada Lovelace", "2024-05-02T10:00:00"),
                          ("Zed Quux", "2024-06-03T10:00:00")):
            with open(os.path.join(self.repo, "sub", "src", "a.py"), "a") as fh:
                fh.write(f"# {day}\n")
            env = dict(os.environ, GIT_AUTHOR_DATE=day, GIT_COMMITTER_DATE=day)
            subprocess.run(["git", "-C", self.repo, "-c", f"user.name={name}", "-c", "user.email=q@example.com",
                            "commit", "-q", "-am", "edit"], check=True, capture_output=True, env=env)
        text = extract.extract(self.repo, self.out)[0]
        for forbidden in ("Zed", "Quux", "Ada", "Lovelace", "q@example.com"):
            self.assertNotIn(forbidden, text)
        own = [f for f in json.loads(text)["facts"] if f["kind"] == "ownership"]
        self.assertTrue(own)
        sub = next(f for f in own if f["name"] == "sub")
        d = sub["detail"]
        self.assertEqual((d["commits"], d["contributors"], d["first_commit"]), (4, 3, "2024-03-01"))
        self.assertEqual(sorted(d), ["commits", "contributors", "first_commit", "last_commit", "source"])
        self.assertEqual(d["source"], "git")        # F8: the gate ignores exactly the Facts that say so
        self.assertRegex(d["last_commit"], r"^\d{4}-\d{2}-\d{2}$")
        self.assertNotIn("authors", facts.DETAIL_KEYS["ownership"])
        self.assertEqual(facts.DETAIL_KEYS["ownership"], frozenset("commits contributors first_commit last_commit role source".split()))

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


class DocShaTests(unittest.TestCase):
    DOC = ("# T\n<!-- appdoc:template 2.4 -->\n\n## 3. Architecture\n\nThe service has "
           "<!-- appdoc:count V -->3<!-- /appdoc:count --> findings. <!-- a comment -->\n\n"
           "<!-- appdoc:generated entry-points -->\nold rows\n<!-- /appdoc:generated entry-points -->\n")

    def test_doc_sha_matches_c11_text(self):
        import hashlib
        from appdoc import check
        from appdoc.textnorm import normalize_text
        raw = self.DOC.replace("<!-- appdoc:count V -->3<!-- /appdoc:count -->", "many")
        want = hashlib.sha1(normalize_text(check.document_text(raw)).encode("utf-8")).hexdigest()[:12]
        self.assertEqual(check.doc_sha(raw), want)
        self.assertRegex(check.doc_sha(raw), r"^[0-9a-f]{12}$")

    def test_doc_sha_ignores_generated_blocks_counts_comments_and_newline_style(self):
        from appdoc import check
        base = check.doc_sha(self.DOC)
        self.assertEqual(check.doc_sha(self.DOC.replace("old rows", "new rows\nmore")), base)
        self.assertEqual(check.doc_sha(self.DOC.replace(">3<", ">14<")), base)
        self.assertEqual(check.doc_sha(self.DOC.replace("a comment", "another comment")), base)
        self.assertEqual(check.doc_sha(self.DOC.replace("\n", "\r\n")), base)
        self.assertNotEqual(check.doc_sha(self.DOC.replace("The service", "A service")), base)

    def test_check_and_fill_share_the_one_text_helper(self):
        import inspect
        from appdoc import check, fill
        self.assertIn("document_text(", inspect.getsource(check.run))
        self.assertIn("document_text(", inspect.getsource(check.seal_register))
        self.assertIn("document_text(", inspect.getsource(fill._appendix_a))


class SealProvenanceTests(unittest.TestCase):
    """T27.04: `seal --audit --date` and the audit/upgrade provenance of sealed rows."""

    def setUp(self):
        from tests.test_check import AUDIT, ROWS, build_doc
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.target = os.path.join(self.tmp.name, "t")
        self.out = os.path.join(self.target, "docs", "appdoc")
        os.makedirs(self.out)
        self.build_doc, self.AUDIT, self.ROWS = build_doc, AUDIT, ROWS

    def write(self, stamp="2.7", audit=None):
        from appdoc import template_spec as spec
        doc = self.build_doc().replace(spec.STAMP, f"<!-- appdoc:template {stamp} -->")
        with open(os.path.join(self.out, "application-documentation.md"), "w", encoding="utf-8") as fh:
            fh.write(doc)
        lines = [json.dumps(audit or self.AUDIT)] + [json.dumps(r) for r in self.ROWS]
        with open(os.path.join(self.out, "evidence.jsonl"), "w", encoding="utf-8") as fh:
            fh.write("\n".join(lines) + "\n")
        return doc

    def read(self):
        with open(os.path.join(self.out, "evidence.jsonl"), encoding="utf-8") as fh:
            return [json.loads(l) for l in fh if l.strip()]

    def main(self, *args):
        import contextlib, io
        from appdoc.__main__ import main
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf), contextlib.redirect_stderr(buf):
            try:
                rc = main(["seal", self.target, *args])
            except SystemExit as exc:
                rc = exc.code
        return rc, buf.getvalue()

    def test_seal_audit_requires_date(self):
        self.write()
        before = self.read()
        for args in (["--audit"], ["--audit", "--date", "23/11/2026"], ["--audit", "--date", "2026-13-40"],
                     ["--date", "2026-11-23"]):
            rc, out = self.main(*args)
            self.assertNotEqual(rc, 0, args)
            self.assertEqual(self.read(), before, args)   # nothing is written on a refusal
        rc, out = self.main("--audit", "--date", "2026-11-23")
        self.assertEqual(rc, 0, out)
        self.assertIn("sealed 2 row(s)", out)

    def test_seal_audit_writes_provenance_and_marks_rows_audit(self):
        from appdoc import __version__, check, version
        doc = self.write()
        self.main("--audit", "--date", "2026-11-23")
        audit, *rows = self.read()
        self.assertEqual(audit["audited_on"], "2026-11-23")
        self.assertEqual(audit["audited_with"], __version__)
        self.assertEqual(audit["audited_bundle"], version.bundle_hash()[:version.BUNDLE_LEN])
        self.assertEqual(audit["doc_sha"], check.doc_sha(doc))
        self.assertEqual([r["sealed_by"] for r in rows], ["audit", "audit"])
        self.assertTrue(all("claim_sha" in r for r in rows))
        self.assertEqual(self.AUDIT["scope"], audit["scope"])      # the writer's fields are kept
        # re-running on the same text changes nothing
        again = self.read()
        self.main("--audit", "--date", "2026-11-23")
        self.assertEqual(self.read(), again)

    def test_seal_marks_upgrade_without_matching_doc_sha(self):
        from appdoc import check
        doc = self.write()                       # a 2.7 document whose line 1 has no doc_sha
        rc, out = self.main()
        self.assertEqual(rc, 0, out)
        self.assertEqual([r["sealed_by"] for r in self.read()[1:]], ["upgrade", "upgrade"])
        # a doc_sha that matches the current text seals as audit; one that does not, as upgrade
        for sha, want in ((check.doc_sha(doc), "audit"), ("0" * 12, "upgrade")):
            self.write(audit=dict(self.AUDIT, doc_sha=sha))
            self.main()
            self.assertEqual({r["sealed_by"] for r in self.read()[1:]}, {want}, sha)

    def test_seal_on_a_2_4_document_writes_no_sealed_by(self):
        self.write(stamp="2.4")
        self.main()
        rows = self.read()[1:]
        self.assertTrue(all("claim_sha" in r and "sealed_by" not in r for r in rows))

    def test_seal_never_marks_or_seals_a_superseded_row(self):
        self.write()
        self.ROWS = [self.ROWS[0], self.ROWS[1], dict(self.ROWS[0], id="E-3", supersedes="E-1")]
        self.write()
        self.main("--audit", "--date", "2026-11-23")
        by_id = {r["id"]: r for r in self.read()[1:]}
        self.assertNotIn("sealed_by", by_id["E-1"])
        self.assertNotIn("claim_sha", by_id["E-1"])
        self.assertEqual(by_id["E-3"]["sealed_by"], "audit")
