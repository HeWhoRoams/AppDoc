"""Core guarantees: every Stack loads, the Facts file is reproducible, and no secret value leaks."""

import json
import os
import shutil
import tempfile
import unittest
from unittest import mock

from appdoc import docmodel as dm, extract, facts, fingerprint, scan, seal, secrets
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



class UpgradeStepTableTests(unittest.TestCase):
    """T27.30: template_spec.UPGRADE_STEPS, the machine-readable steps `appdoc upgrade` applies."""

    @staticmethod
    def ops(version=None):
        from appdoc import template_spec as spec
        steps = spec.UPGRADE_STEPS
        return [op for v in sorted(steps, key=spec.version_tuple) if version in (None, v) for op in steps[v]]

    def test_upgrade_step_table_covers_every_version(self):
        from appdoc import template_spec as spec
        vt = spec.version_tuple
        versions = sorted(spec.UPGRADE_STEPS, key=vt)
        # one entry for each template that changed what a document holds: 2.1, 2.2, 2.3, 2.4, 2.7 and the running 2.8
        # (AppDoc 2.5 and 2.6 kept template 2.4); the chain starts at the template with no stamp
        self.assertEqual(versions, ["2.1", "2.2", "2.3", "2.4", "2.7", "2.8"])
        self.assertEqual(spec.UPGRADE_FROM, "2.0")
        self.assertEqual(versions[-1], spec.TEMPLATE_VERSION)
        for v in versions:
            self.assertEqual(spec.UPGRADE_STEPS[v][-1], ("stamp",), v)         # every step ends by stamping its version
        # the closed vocabulary, each operation with arguments that name real spec entries
        arity = {"stamp": 0, "section": 1, "subsection": 1, "appendix": 0, "block": 1, "reshape": 1, "rows": 1,
                 "rename": 3, "column": 4, "line": 2}
        for op in self.ops():
            self.assertIn(op[0], arity, op)
            self.assertEqual(len(op) - 1, arity[op[0]], op)
        sections = {str(n) for n in range(1, len(spec.SECTIONS) + 1)}
        for op in self.ops():
            if op[0] == "section":
                self.assertIn(op[1], sections)
            if op[0] == "subsection":
                self.assertIn(op[1], spec.REQUIRED_SUBSECTIONS)
            if op[0] == "block":
                self.assertIn(op[1], spec.GENERATED.values())
            if op[0] in ("reshape", "rows", "rename", "column"):
                self.assertIn(op[1], spec.TABLES)
            if op[0] == "rows":
                self.assertTrue(spec.TABLES[op[1]].required_rows, op)
        # everything the current template carries beyond a bare 2.0 document is added by some step ...
        self.assertTrue(set(spec.REQUIRED_SUBSECTIONS) <= {o[1] for o in self.ops() if o[0] == "subsection"})
        self.assertEqual({o[1] for o in self.ops() if o[0] == "block"},
                         set(spec.generated_blocks(spec.version_tuple(spec.TEMPLATE_VERSION)).values()))   # incl. the 2.8 blocks
        self.assertTrue(any(o[0] == "appendix" for o in self.ops()))
        tables = {o[1] for o in self.ops() if o[0] == "reshape"} | {"17"}   # 17 comes with its section
        self.assertEqual(tables, set(spec.TABLES) - {"16.6"})              # 16.6 is the generated block's table
        self.assertEqual({o[1] for o in self.ops() if o[0] == "rows"}, {"11", "16.5"})   # 17's rows come with the section
        self.assertIn(("rows", "16.5"), self.ops("2.8"))                    # the Periodic maintenance row (ROWS_SINCE)
        self.assertIn(("line", "5.3", spec.RESTRICTION_LINE), self.ops())
        # ... and what a later template added is added by the step of that template
        for n, since in spec.SECTIONS_SINCE.items():
            self.assertIn(("section", str(n)), self.ops(".".join(map(str, since))))
        # (no block is skipped: a block registered ahead of the running template would have been, and a tripwire that
        # skips what it should check is no tripwire; since T28.A4 the 2.8 blocks are checked against UPGRADE_STEPS["2.8"])
        for name, since in spec.GENERATED_SINCE.items():
            self.assertIn(("block", name), self.ops(".".join(map(str, since))))
        for key, since in {**spec.SUBSECTIONS_SINCE, **{"5.4": (2, 8), "16.8": (2, 8)}}.items():
            self.assertIn(("subsection", key), self.ops(".".join(map(str, since))))
        self.assertEqual({k for k in spec.REQUIRED_SUBSECTIONS if k not in spec.subsections((2, 7))}, {"2.4", "5.4", "16.8"})
        for row, since in spec.ROWS_SINCE.items():
            self.assertIn(row, spec.RUNBOOK_STEPS)                         # the row the ("rows", "16.5") step adds
            self.assertIn(("rows", "16.5"), self.ops(".".join(map(str, since))))
        # the 2.2 to 2.4 renames and insertions a 2.1 or 2.2 document needs
        self.assertIn(("rename", "5.3", "Area", "Capability"), self.ops("2.3"))
        self.assertIn(("rename", "6", "Route", "Route or entry"), self.ops("2.2"))
        self.assertTrue({"4", "4.1", "6", "8.1"} <= {o[1] for o in self.ops("2.2") if o[0] == "column"})
        # a document is inferred as 2.1 when it carries these subsections
        self.assertEqual(spec.SUBSECTIONS_2_1, ("4.1", "5.1", "5.2", "5.3", "8.4", "8.5", "10.1", "10.2", "15.1",
                                                "16.1", "16.2", "16.3", "16.4", "16.5"))



class UpgradeTests(unittest.TestCase):
    """T27.31: `appdoc upgrade <target>` (appdoc/upgrade.py)."""

    FIXTURES = os.path.join(os.path.dirname(os.path.abspath(__file__)), "fixtures")

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.target = os.path.join(self.tmp.name, "target")
        self.out = os.path.join(self.target, "docs", "appdoc")
        os.makedirs(os.path.join(self.target, "app"))
        os.makedirs(self.out)
        with open(os.path.join(self.target, "app", "main.py"), "w") as fh:
            fh.write("\n".join(f"line {i}" for i in range(1, 11)) + "\n")

    def put(self, name, text):
        with open(os.path.join(self.out, name), "w", encoding="utf-8", newline="") as fh:
            fh.write(text)

    def doc_from_fixture(self, which="docs-2.1", repo="flaskr-tdd", name="application-documentation.md"):
        with open(os.path.join(self.FIXTURES, which, repo, name), encoding="utf-8", newline="") as fh:
            return fh.read()

    def narrative(self):
        with open(os.path.join(self.out, "application-documentation.md"), encoding="utf-8", newline="") as fh:
            return fh.read()

    def upgrade(self, *args):
        import contextlib, io
        from appdoc.__main__ import main
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf), contextlib.redirect_stderr(buf):
            rc = main(["upgrade", self.target, "--no-ownership", "--workers", "0", *args])
        return rc, buf.getvalue()

    def snapshot(self):
        out = {}
        for d, dirs, files in os.walk(self.target):
            dirs.sort()
            for f in files:
                with open(os.path.join(d, f), "rb") as fh:
                    out[os.path.relpath(os.path.join(d, f), self.target)] = fh.read()
        return out

    # --- version inference

    def test_infer_version_from_stamp_or_subsections(self):
        from appdoc import template_spec as spec
        from appdoc import upgrade
        two_1 = self.doc_from_fixture()
        self.assertEqual(upgrade.infer_version(two_1), "2.1")                    # no stamp, has the 2.1 subsections
        no_sub = two_1.replace("### 5.2 Authorization enforcement", "Authorization enforcement")
        self.assertEqual(upgrade.infer_version(no_sub), "2.0")                   # no stamp, a 2.1 subsection missing
        self.assertEqual(upgrade.infer_version("# T\n<!-- appdoc:template 2.4 -->\n"), "2.4")
        self.assertEqual(upgrade.infer_version(self.doc_from_fixture("docs-2.2")), "2.2")
        self.assertEqual(upgrade.steps_after("2.0"), ["2.1", "2.2", "2.3", "2.4", "2.7", "2.8"])
        self.assertEqual(upgrade.steps_after("2.4"), ["2.7", "2.8"])
        self.assertEqual(upgrade.steps_after("2.7"), ["2.8"])
        self.assertEqual(upgrade.steps_after(spec.TEMPLATE_VERSION), [])

    # --- 2.1 -> 2.8

    def test_upgrade_2_1_to_current_mechanical(self):
        import re
        from appdoc import check, fill
        from appdoc import docmodel as dm
        from appdoc import template_spec as spec
        self.put("application-documentation.md", self.doc_from_fixture())
        self.put("verification.md", self.doc_from_fixture(name="verification.md"))
        rc, log = self.upgrade()
        self.assertEqual(rc, 0, log)
        text = self.narrative()
        lines = text.split("\n")
        self.assertEqual(spec.stamp_version(text), (2, 8))
        heads = dm.headings(lines)
        for n, title in enumerate(spec.SECTIONS, 1):                              # all 17 sections
            self.assertTrue(heads[str(n)].title.startswith(title), (n, title))
        for key, title in spec.REQUIRED_SUBSECTIONS.items():                     # every required subsection
            self.assertEqual(heads[key].title, title, key)
        self.assertEqual(sorted(n for n, _, _ in fill.blocks(text)),
                         sorted(spec.generated_blocks(spec.version_tuple(spec.TEMPLATE_VERSION)).values()))
        for key in ("4", "4.1", "6", "8.1", "11"):                               # the mechanical headers and rows
            self.assertTrue(spec.TABLES[key].header_ok([dm.cell_text(c) for c in dm.first_table(lines, heads[key]).header]), key)
        self.assertIn(spec.RESTRICTION_LINE, text)
        labels = {dm.cell_text(c[0]) for _, c in dm.first_table(lines, heads["11"]).rows}
        self.assertTrue(set(spec.OWNERSHIP_ROWS) <= labels)
        build = {dm.cell_text(c[0]): c[1] for _, c in dm.first_table(lines, heads["17"]).rows}
        self.assertEqual(build, {step: spec.UNKNOWN_TEXT for step in spec.BUILD_STEPS})
        ids = [dm.cell_text(c[0]) for _, c in dm.first_table(lines, heads["6"]).rows]
        self.assertEqual(ids, [f"UI-{i}" for i in range(1, len(ids) + 1)])       # sequential IDs for the new ID column
        # the tool ran extract and fill: facts exist and the scan-coverage block holds text
        self.assertTrue(os.path.isfile(os.path.join(self.out, "facts.json")))
        block = dict((n, c) for n, c, _ in fill.blocks(text))["scan-coverage"]
        self.assertIn("Stack", block)
        # what had no place in the new shape stays, under a marker C3 fails on (1 old TOC table, 10.1 without Severity ...)
        self.assertGreaterEqual(len(spec.ORPHAN_RE.findall(text)), 1)
        self.assertEqual(check.run(self.target, self.out), 2)
        with open(os.path.join(self.out, check.REPORT), encoding="utf-8") as fh:
            report = fh.read()
        self.assertRegex(report, r"(?m)^## C3 ")
        self.assertIn("appdoc:upgrade-orphan", report)
        self.assertNotRegex(report, r"template 2\.8 \(stamp")                    # the stamp is no longer the problem
        self.assertTrue(re.search(r"(?m)^## C9 ", report))                       # guides left in the added sections

    def test_upgrade_2_0_adds_2_1_subsections(self):
        from appdoc import docmodel as dm
        from appdoc import template_spec as spec
        from appdoc import upgrade
        two_1 = self.doc_from_fixture()
        two_0 = two_1
        for key in spec.SUBSECTIONS_2_1:                                          # a 2.0 document: the headings are not there
            two_0 = "\n".join(l for l in two_0.split("\n")
                              if not (l.startswith("### " + key + " ") or l == "### " + key))
        self.assertEqual(upgrade.infer_version(two_0), "2.0")
        self.put("application-documentation.md", two_0)
        rc, log = self.upgrade()
        self.assertEqual(rc, 0, log)
        heads = dm.headings(self.narrative().split("\n"))
        for key in spec.SUBSECTIONS_2_1 + ("8.1", "8.2", "8.3"):
            self.assertIn(key, heads, key)
        # in document order: 4.1 sits after section 4's body and before section 5
        self.assertLess(heads["4"].idx, heads["4.1"].idx)
        self.assertLess(heads["4.1"].idx, heads["5"].idx)
        self.assertLess(heads["16.4"].idx, heads["16.5"].idx)
        self.assertLess(heads["16.5"].idx, heads["16.6"].idx)

    def test_upgrade_idempotent(self):
        from appdoc import upgrade
        for which, repo in (("docs-2.1", "flaskr-tdd"), ("docs-2.1", "eShop"), ("docs-2.2", "spring-petclinic")):
            with self.subTest(which=which, repo=repo):
                original = self.doc_from_fixture(which, repo)
                started = upgrade.infer_version(original)
                self.put("application-documentation.md", original)
                rc, log = self.upgrade()
                self.assertEqual(rc, 0, log)
                once = self.snapshot()
                rc, log = self.upgrade()                                          # the second run is a no-op
                self.assertEqual(rc, 0, log)
                self.assertIn("already on template", log)
                self.assertEqual(self.snapshot(), once)
                # and the steps themselves are idempotent: applying them again to their own output adds nothing
                text = self.narrative()
                again, entries = upgrade.upgrade_text(text, started)
                self.assertEqual(again, text)
                self.assertEqual(entries, [])

    def test_upgrade_never_drops_text(self):
        from appdoc import docmodel as dm
        from appdoc import fill
        for which, repo in (("docs-2.1", "flaskr-tdd"), ("docs-2.1", "eShop"), ("docs-2.2", "flaskr-tdd")):
            with self.subTest(which=which, repo=repo):
                old = self.doc_from_fixture(which, repo)
                self.put("application-documentation.md", old)
                self.assertEqual(self.upgrade()[0], 0)
                new = self.narrative()
                new_lines = set(new.split("\n"))
                new_rows = [dm.split_row(l) for l in new.split("\n") if l.lstrip().startswith("|")]
                stamp = "<!-- appdoc:template"
                generated = set()          # lines of a generated block are the tool's, `fill` rewrites them
                for m in dm.BLOCK_RE.finditer(old):
                    generated.update(m.group(0).split("\n"))
                for line in old.split("\n"):
                    if not line.strip() or line.startswith(stamp) or line in generated:
                        continue
                    if line.lstrip().startswith("|"):
                        cells = dm.split_row(line)
                        header_like = all(c.strip("-: ") == "" for c in cells)
                        if header_like:
                            continue
                        # a row keeps every cell (columns were only added); a renamed header keeps all but the renamed one
                        kept = any(all(c in row for c in cells) for row in new_rows)
                        renamed = any(sum(c not in row for c in cells) == 1 and len(row) >= len(cells) for row in new_rows)
                        self.assertTrue(kept or renamed, f"a table row was lost: {line[:100]}")
                    else:
                        self.assertIn(line, new_lines, f"a line was lost: {line[:100]}")

    def test_upgrade_never_touches_register(self):
        import hashlib
        reg = '{"type": "audit", "performed": true, "auditor": "independent", "scope": "a read"}\n' \
              '{"id": "E-1", "ref": "10.1/V-1", "claim": "c", "result": "Supported", "cites": ["app/main.py:6"], ' \
              '"anchor": "line 6", "limitation": "none"}\n'
        self.put("application-documentation.md", self.doc_from_fixture("docs-2.2", "spring-petclinic"))
        # absent: the command creates none of the three files
        rc, log = self.upgrade()
        self.assertEqual(rc, 0, log)
        for name in ("evidence.jsonl", "notes.jsonl", "audit-plan.json"):
            self.assertFalse(os.path.exists(os.path.join(self.out, name)), name)
        # present: byte for byte unchanged (no seal, no note sha, no plan)
        self.put("application-documentation.md", self.doc_from_fixture("docs-2.2", "spring-petclinic"))
        self.put("evidence.jsonl", reg)
        self.put("notes.jsonl", '{"block": "entry-points", "text": "t", "cites": [], "block_sha": ""}\n')
        self.put("audit-plan.json", '{"sections": {}, "stale": true}\n')
        before = {n: hashlib.sha256(open(os.path.join(self.out, n), "rb").read()).hexdigest()
                  for n in ("evidence.jsonl", "notes.jsonl", "audit-plan.json")}
        rc, log = self.upgrade()
        self.assertEqual(rc, 0, log)
        after = {n: hashlib.sha256(open(os.path.join(self.out, n), "rb").read()).hexdigest() for n in before}
        self.assertEqual(after, before)

    # --- UPGRADE-TODO.md (T27.32)

    def test_upgrade_todo_lists_failing_rules(self):
        """Every rule the Check fails on the upgraded document appears in UPGRADE-TODO.md, each step names its rule,
        and the steps no rule can see (convert verification.md, the audit) are there too."""
        import re
        from tests.test_corpus import CORPUS
        for case, must in (("upgrade-2-1", ("Convert `verification.md` to `evidence.jsonl`", "appdoc:upgrade-orphan", "C3 ", "C9 ")),
                           ("upgrade-2-6-to-2-7", ("C1 Citations resolve", "C11 Register valid", "C17 ", "C18 ",
                                                   "C15 Register counts in prose (advisory)", "--expand-citations"))):
            with self.subTest(case=case):
                shutil.rmtree(self.target)
                shutil.copytree(os.path.join(CORPUS, case), self.target)
                self.assertEqual(self.upgrade()[0], 0)
                with open(os.path.join(self.out, "check-report.md"), encoding="utf-8") as fh:
                    report = fh.read()
                with open(os.path.join(self.out, "UPGRADE-TODO.md"), encoding="utf-8") as fh:
                    todo = fh.read()
                failing = set(re.findall(r"(?m)^## (C\d+) ", report))
                self.assertTrue(failing, "the upgraded document should still have steps for a person")
                rule_lines = [l for l in todo.splitlines() if l.startswith("   - Rule: ")]
                for rule in failing:
                    self.assertTrue(any(re.search(rf"\b{rule}\b", l) for l in rule_lines), (rule, todo))
                self.assertEqual(len(rule_lines), len(re.findall(r"(?m)^\d+\. \[ \] ", todo)))   # a rule for every step
                for text in must:
                    self.assertIn(text, todo, text)
                # a step quotes the Check's own message with its line, so it can be found
                self.assertRegex(todo, r"(?m)^   - line \d+: ")
                self.assertTrue(todo.startswith(f"# Upgrade TODO: template "))
                # written by the tool, deterministic, and the register stays the person's
                for name in ("evidence.jsonl", "notes.jsonl", "audit-plan.json"):
                    if not os.path.exists(os.path.join(CORPUS, case, "docs", "appdoc", name)):
                        self.assertFalse(os.path.exists(os.path.join(self.out, name)), name)

    # --- the command's edges

    def test_upgrade_errors_and_noop(self):
        rc, log = self.upgrade()                                                  # no document
        self.assertEqual(rc, 1)
        self.assertIn("not found", log)
        self.put("application-documentation.md", "# T\n<!-- appdoc:template 3.0 -->\n")   # newer than this tool
        before = self.snapshot()
        rc, log = self.upgrade()
        self.assertEqual(rc, 1)
        self.assertIn("newer than this AppDoc", log)
        self.assertEqual(self.snapshot(), before)

    def test_upgrade_keeps_crlf(self):
        text = self.doc_from_fixture().replace("\n", "\r\n")
        self.put("application-documentation.md", text)
        self.assertEqual(self.upgrade()[0], 0)
        new = self.narrative()
        from appdoc import fill
        self.assertNotRegex(dm.BLOCK_RE.sub("", new), r"(?<!\r)\n")           # every line break outside a block is CRLF
        self.assertIn("\r\n## 17. Build, Run and Test Locally\r\n", new)

    def test_upgrade_2_4_adds_the_2_7_and_2_8_parts(self):
        """A 2.4 document (what AppDoc 2.4 to 2.6 wrote) gets the stamp, the closed-questions markers, section 17 and
        the 2.8 headings, blocks and maintenance row."""
        from appdoc import upgrade
        from tests.test_check import build_doc
        old = self.without_maintenance_row(build_doc())
        new, log = upgrade.upgrade_text(old, "2.4")
        self.assertEqual(log[:2], ["added the closed-questions block", "added section 17 Build, Run and Test Locally"])
        self.assertEqual(log[2:], self.LOG_2_8 + ["stamp 2.8"])
        self.assertIn("<!-- appdoc:template 2.8 -->", new)
        self.assertIn("<!-- appdoc:generated closed-questions -->", new)
        self.assertIn("## 17. Build, Run and Test Locally", new)
        self.assertEqual(new.count("appdoc:upgrade-orphan"), 0)

    @staticmethod
    def without_maintenance_row(doc):
        """The test document as an older template wrote it: no Periodic maintenance row in 16.5."""
        return "\n".join(l for l in doc.split("\n") if not l.startswith("| Periodic maintenance |"))

    LOG_2_8 = ["added subsection 2.4 Repository documentation (generated)",
               "added subsection 5.4 Application-layer access (generated)",
               "added subsection 16.8 Pipeline (generated)",
               "added the connections block", "added the integrations block",
               "added the 16.5 rows Periodic maintenance"]

    def test_upgrade_2_7_adds_the_2_8_parts_and_is_idempotent(self):
        """T28.A4: `UPGRADE_STEPS["2.8"]` on a 2.7 document adds the five block markers at their GENERATED positions,
        the three headings with their `appdoc:guide`, the maintenance row skeleton, and the stamp; nothing is removed;
        a second run changes nothing; the upgraded text carries every block the running template requires."""
        from appdoc import docmodel as dm
        from appdoc import template_spec as spec
        from appdoc import upgrade
        from tests.test_check import CheckTests, build_doc
        old = self.without_maintenance_row(CheckTests("run_check").doc27(build_doc()))
        new, log = upgrade.upgrade_text(old, "2.7")
        self.assertEqual(log, self.LOG_2_8 + ["stamp 2.8"])
        self.assertEqual(spec.stamp_version(new), (2, 8))
        heads = dm.headings(new.split("\n"))
        for key, name in spec.GENERATED_2_8.items():
            marker = f"<!-- appdoc:generated {name} -->"
            self.assertEqual(new.count(marker), 1, name)
            h = heads[key]                                                       # the block sits inside its own section
            self.assertTrue(h.idx < new[:new.index(marker)].count("\n") < h.own_end or key in ("8.1", "8.3"), name)
        for key in ("2.4", "5.4", "16.8"):
            self.assertIn(spec.REQUIRED_SUBSECTIONS[key], heads[key].title)
            self.assertIn("appdoc:guide", "\n".join(new.split("\n")[heads[key].idx:heads[key].own_end]))
        row = spec.unknown_row("16.5", "Periodic maintenance")
        self.assertIn(row, new)
        self.assertEqual(spec.unknown_row("16.5", "Periodic maintenance"), row)
        kept = [l for l in new.split("\n")]
        for l in old.split("\n"):                                                # additions only: nothing is dropped
            if l.strip() and "appdoc:template" not in l:
                self.assertIn(l, kept)
                kept.remove(l)
        again, log2 = upgrade.upgrade_text(new, "2.7")
        self.assertEqual((again, log2), (new, []))
        self.assertEqual(upgrade.upgrade_text(new, "2.8"), (new, []))
        self.assertEqual(set(spec.GENERATED_2_8.values()) - {m.group(2) for m in dm.BLOCK_RE.finditer(new)}, set())


if __name__ == "__main__":
    unittest.main()


class VersionCompareTests(unittest.TestCase):
    def test_count_marker_classes_are_one_constant(self):
        """T27.16: the closed list of count-marker classes lives in template_spec, grouped by where the number comes from."""
        from appdoc import template_spec as spec
        self.assertEqual(list(spec.COUNT_CLASSES), ["V", "F", "UI", "C", "X", "Q", "R", "rows", "superseded",
                                                    "routes", "jobs", "pages", "commands", "config-keys"])
        self.assertEqual({c: k for c, k in spec.COUNT_CLASSES.items()},
                         {**{c: "id" for c in ("V", "F", "UI", "C", "X", "Q", "R")},
                          "rows": "register", "superseded": "register",
                          **{c: "facts" for c in ("routes", "jobs", "pages", "commands", "config-keys")}})
        # an ID class is the prefix of a defined ID (V- for V-1)
        self.assertEqual({c for c, k in spec.COUNT_CLASSES.items() if k == "id"},
                         {p.rstrip("-") for p in spec.ID_PREFIXES})

    def test_version_tuple(self):
        from appdoc.template_spec import version_tuple
        self.assertEqual(version_tuple("2.4"), (2, 4))
        self.assertEqual(version_tuple("2.10.1"), (2, 10, 1))
        self.assertEqual(version_tuple("2.6.0.dev0"), (2, 6, 0))
        self.assertGreater(version_tuple("2.10"), version_tuple("2.9"))  # a string compare says otherwise
        self.assertEqual(version_tuple(""), ())
        self.assertEqual(version_tuple("none"), ())
        self.assertEqual(version_tuple(None), ())

    def test_template_version_is_2_8(self):
        """T28.A4: the running template is 2.8; the template file carries its stamp, 17 headings and the conventions;
        a 2.7 stamp is not current and the 2.8 blocks are required from 2.8 only."""
        from appdoc import template_spec as spec
        self.assertEqual(spec.TEMPLATE_VERSION, "2.8")
        self.assertEqual(spec.STAMP, "<!-- appdoc:template 2.8 -->")
        self.assertEqual(spec.sections(spec.version_tuple(spec.TEMPLATE_VERSION)), spec.SECTIONS)
        self.assertEqual(spec.generated_blocks(spec.version_tuple(spec.TEMPLATE_VERSION)), spec.GENERATED)
        self.assertEqual(spec.generated_blocks((2, 7)),
                         {k: v for k, v in spec.GENERATED.items() if v not in spec.GENERATED_2_8.values()})
        path = os.path.join(os.path.dirname(HERE), "appdoc", "assets", "template.md")
        with open(path, encoding="utf-8") as fh:
            text = fh.read()
        self.assertEqual(spec.stamp_version(text), (2, 8))
        self.assertEqual(text.splitlines()[1], spec.STAMP)
        start = text.index("CONVENTIONS:")
        conventions = text[start:text.index("-->", start)]
        for phrase in ("all 17", "count marker", "notes.jsonl", "Known extractor limitation", "supersedes", "answered_in",
                       "Section 17", "Unknown - see Open questions.", "Not applicable", "--expand-citations",
                       "severity"):
            self.assertIn(phrase, conventions, phrase)
        self.assertEqual(text.count("<!-- appdoc:count"), 0)            # a comment inside a comment would end it early

    def test_no_older_stamp_is_accepted(self):
        """Strict C3 (T27.29): only the running template is current; the 2.4 window is gone."""
        from appdoc import template_spec as spec
        self.assertFalse(hasattr(spec, "OLDER_STAMPS"))
        self.assertFalse(hasattr(spec, "stamp_accepted"))
        self.assertEqual(spec.stamp_version("# T\n<!-- appdoc:template 2.4 -->\n"), (2, 4))
        self.assertEqual(spec.stamp_version("# T\n"), ())

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
        want = hashlib.sha1(normalize_text(fingerprint.document_text(raw)).encode("utf-8")).hexdigest()[:12]
        self.assertEqual(fingerprint.doc_sha(raw), want)
        self.assertRegex(fingerprint.doc_sha(raw), r"^[0-9a-f]{12}$")

    def test_doc_sha_ignores_generated_blocks_counts_comments_and_newline_style(self):
        from appdoc import check
        base = fingerprint.doc_sha(self.DOC)
        self.assertEqual(fingerprint.doc_sha(self.DOC.replace("old rows", "new rows\nmore")), base)
        self.assertEqual(fingerprint.doc_sha(self.DOC.replace(">3<", ">14<")), base)
        self.assertEqual(fingerprint.doc_sha(self.DOC.replace("a comment", "another comment")), base)
        self.assertEqual(fingerprint.doc_sha(self.DOC.replace("\n", "\r\n")), base)
        self.assertNotEqual(fingerprint.doc_sha(self.DOC.replace("The service", "A service")), base)

    def test_doc_sha_ignores_the_length_of_a_block_in_the_middle_of_the_document(self):
        """What `fill` writes into a block must not move the fingerprint (a plan or audit made before would go stale)."""
        from appdoc import check
        doc = self.DOC + "\n## 4. After\n\nMore text.\n"
        base = fingerprint.doc_sha(doc)
        self.assertEqual(fingerprint.doc_sha(doc.replace("old rows", "a\nb\nc\nd")), base)
        self.assertEqual(fingerprint.doc_sha(doc.replace("a comment", "a\nmulti\nline comment")), fingerprint.doc_sha(
            doc.replace("a comment", "x\ny")))
        self.assertNotEqual(fingerprint.doc_sha(doc.replace("More text", "Other text")), base)

    def test_check_and_fill_share_the_one_text_helper(self):
        import inspect
        from appdoc import check, fill
        self.assertIn("document_text(", inspect.getsource(check.run))
        self.assertIn("document_text(", inspect.getsource(seal.seal_register))
        self.assertIn("document_text(", inspect.getsource(fill._appendix_a))


class AuditPlanTests(unittest.TestCase):
    """T27.14: `appdoc audit-plan` writes docs/appdoc/audit-plan.json, a pure function of the Narrative."""

    def setUp(self):
        from tests.test_check import build_doc
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.target = os.path.join(self.tmp.name, "t")
        self.out = os.path.join(self.target, "docs", "appdoc")
        os.makedirs(self.out)
        self.build_doc = build_doc

    def write(self, n_f=1, n_r=1, stamp="2.7", extra=None, doc=None):
        from appdoc import template_spec as spec
        from tests.test_check import OLD_STAMP, SECTION_BODY
        body4 = SECTION_BODY[4].replace(
            "\n\n### 4.1", "".join(f"\n| F-{i} | Service | Run {i} | `app/main.py:2` | Does `app/main.py:2` things. | C-1 | Cited |"
                                    for i in range(2, n_f + 1)) + "\n\n### 4.1")
        body15 = SECTION_BODY[15].replace(
            "\n\n### 15.1", "".join(f"\n| R-{i} | High | S | Do thing {i} | V-1 |" for i in range(2, n_r + 1)) + "\n\n### 15.1")
        text = (doc or self.build_doc({4: body4, 15: body15})).replace(OLD_STAMP, f"<!-- appdoc:template {stamp} -->")
        with open(os.path.join(self.out, "application-documentation.md"), "w", encoding="utf-8", newline="\n") as fh:
            fh.write(text)
        if extra is not None:
            with open(os.path.join(self.target, "appdoc-context.md"), "w", encoding="utf-8") as fh:
                fh.write(extra)
        return text

    def plan(self, **kw):
        from appdoc import audit_plan
        return audit_plan.compute(self.target, self.out, **kw)

    def run_cli(self):
        import contextlib, io
        from appdoc.__main__ import main
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            rc = main(["audit-plan", self.target])
        with open(os.path.join(self.out, "audit-plan.json"), "rb") as fh:
            return rc, fh.read(), buf.getvalue()

    def section(self, plan, name):
        return next(s for s in plan["sections"] if s["section"] == name)

    def test_audit_plan_deterministic(self):
        self.write(n_f=30, n_r=12)
        rc, first, out = self.run_cli()
        self.assertEqual(rc, 0, out)
        self.assertEqual(self.run_cli()[1], first)
        # the same Narrative in another folder, written later, gives the same bytes
        other = os.path.join(self.tmp.name, "elsewhere")
        shutil.copytree(self.target, other)
        from appdoc.__main__ import main
        import contextlib, io
        with contextlib.redirect_stdout(io.StringIO()):
            main(["audit-plan", other])
        with open(os.path.join(other, "docs", "appdoc", "audit-plan.json"), "rb") as fh:
            self.assertEqual(fh.read(), first)
        self.assertNotIn(b"\r", first)
        self.assertNotIn(self.tmp.name.encode(), first)

    def test_audit_plan_lists_every_candidate_no_10_1_row_cites(self):
        """S6.5: a finding candidate no 10.1 row cites is planned, with or without a table id (smell/<fid>), whatever
        its file; a cited one and a test-code one are not."""
        from appdoc import facts as facts_mod
        self.write()
        sm = lambda fid, line, path="app/main.py", **d: {
            "kind": "smell", "stack": "python-flask", "path": path, "line": line, "name": "candidate",
            "detail": {"pattern": "hardcoded-credential-constant", **({"fid": fid} if fid else {}), **d}}
        facts = {"schema": facts_mod.SCHEMA, "target": {"name": "t", "commit": None}, "stacks": [], "facts": [
            sm("aaaa0001", 6),                                   # 10.1 cites app/main.py:6: covered
            sm("aaaa0002", 9),                                   # same file, another line: planned
            sm("", 12),                                          # no fid in the Facts: id derived from the Fact
            sm("aaaa0004", 3, path="project/templates/index.html"),   # a file the document never cites
            sm("aaaa0005", 5, test=True)]}                       # test code is never a candidate
        with open(os.path.join(self.out, "facts.json"), "w", encoding="utf-8") as fh:
            json.dump(facts, fh)
        derived = facts_mod.fact_id("smell", "hardcoded-credential-constant", "app/main.py", 12)
        cand = self.section(self.plan(), "candidates")
        self.assertEqual(sorted(cand["ids"]), sorted(["smell/aaaa0002", f"smell/{derived}", "smell/aaaa0004"]))
        self.assertEqual(cand["total"], 3)

    def test_audit_plan_full_and_sampled_sections(self):
        self.write(n_f=30, n_r=3)
        plan = self.plan()
        full = {s["section"]: s for s in plan["sections"] if s["mode"] == "full"}
        self.assertEqual(full["10.1"]["ids"], ["V-1"])
        self.assertEqual(full["7"]["ids"], ["7.1"])
        self.assertEqual(full["14"]["ids"], ["Q-1"])
        self.assertEqual(full["10.2"]["ids"], [])                # TLS is Not established, not Present
        self.assertEqual(full["16.5"]["ids"], [])                # every step is Unknown
        f = self.section(plan, "4")
        self.assertEqual((f["mode"], f["total"], f["k"], len(f["ids"])), ("sampled", 30, 8, 8))
        self.assertTrue(set(f["ids"]) <= {f"F-{i}" for i in range(1, 31)})
        r = self.section(plan, "15")
        self.assertEqual((r["total"], r["k"], sorted(r["ids"])), (3, 3, ["R-1", "R-2", "R-3"]))
        self.assertEqual(plan["doc_sha"], __import__("appdoc.fingerprint", fromlist=["x"]).doc_sha(self.write(n_f=30, n_r=3)))

    def test_audit_plan_changes_with_doc(self):
        text = self.write(n_f=40)
        a = self.plan()
        with open(os.path.join(self.out, "application-documentation.md"), "w", encoding="utf-8", newline="\n") as fh:
            fh.write(text.replace("- The entry module wires", "- The entry module also wires"))
        b = self.plan()
        self.assertNotEqual(a["doc_sha"], b["doc_sha"])
        self.assertNotEqual(self.section(a, "4")["ids"], self.section(b, "4")["ids"])
        self.assertEqual(self.section(a, "10.1"), self.section(b, "10.1"))     # full coverage does not depend on the text
        # an edit inside a generated block or a count marker does not change the plan
        with open(os.path.join(self.out, "application-documentation.md"), "w", encoding="utf-8", newline="\n") as fh:
            fh.write(text.replace("<!-- appdoc:generated entry-points -->\n",
                                  "<!-- appdoc:generated entry-points -->\nsomething else\n"))
        self.assertEqual(self.plan(), a)

    def test_audit_plan_floor_math(self):
        from appdoc import audit_plan
        want = {0: 0, 1: 1, 4: 4, 5: 5, 6: 5, 20: 5, 21: 6, 24: 6, 25: 7, 40: 10, 41: 11, 100: 25, 101: 26}
        for n, k in want.items():
            self.assertEqual(audit_plan.sample_size(n), k, n)
        self.write(n_f=24)
        self.assertEqual(self.section(self.plan(), "4")["k"], 6)
        # the pick is the first k by sha1(doc_sha + id), ties broken by id
        import hashlib
        plan = self.plan()
        ids = [f"F-{i}" for i in range(1, 25)]
        ranked = sorted(ids, key=lambda i: (hashlib.sha1((plan["doc_sha"] + i).encode()).hexdigest(), i))
        self.assertEqual(self.section(plan, "4")["ids"], sorted(ranked[:6], key=lambda i: int(i[2:])))

    # --- R71.A1a: one planned key per row of 10.2, 16.5, 17 and 9

    CONTROLS = ("| TLS | Not established | `app/main.py:7` |",
                ["| TLS | Present | `app/main.py:7` |", "| Read-only DB role | Present | `app/main.py:7` |",
                 "| Rate limit! | Verified absent | `app/main.py:7` |", "| Audit log | Present | `app/main.py:7` |"])

    def write_rows(self, controls=None, extra_symptoms=(), run="| Run | `python app/main.py` | . | `app/main.py:2` |"):
        from tests.test_check import SECTION_BODY, OLD_STAMP
        text = self.write()
        if "\n## 17. " not in text:      # the 2.4 test document has no section 17
            text = text.replace("\n## Appendix A.", f"\n## 17. Build, Run and Test Locally\n\n{SECTION_BODY[17]}\n\n## Appendix A.", 1)
        text = text.replace(self.CONTROLS[0], "\n".join(self.CONTROLS[1] if controls is None else controls))
        text = text.replace("| Build | Unknown | not in the repository |",
                            "| Build | `make` | `Makefile:1` |")
        text = text.replace("| Run | Unknown - see Open questions. | . | not in the repository |", run)
        text = text.replace("| Service will not start | Look at `app/main.py:2` | Restart the process | Twice in a row |",
                            "\n".join(["| Service will not start | Look at `app/main.py:2` | Restart the process | Twice in a row |",
                                      *extra_symptoms]))
        with open(os.path.join(self.out, "application-documentation.md"), "w", encoding="utf-8", newline="\n") as fh:
            fh.write(text)

    def test_per_row_keys_for_controls_steps_and_symptoms(self):
        self.write_rows()
        plan = self.plan()
        c = self.section(plan, "10.2")
        self.assertEqual(c["ids"], ["10.2/tls", "10.2/read-only-db-role", "10.2/audit-log"])   # Present rows only
        self.assertEqual((c["total"], c["items"]), (4, ["TLS", "Read-only DB role", "Audit log"]))
        self.assertEqual(self.section(plan, "16.5")["ids"], ["16.5/build"])      # the other steps stay Unknown
        self.assertEqual(self.section(plan, "17")["ids"], ["17/run"])
        nine = self.section(plan, "9")
        self.assertEqual((nine["mode"], nine["ids"], nine["items"]),
                         ("sampled", ["9/service-will-not-start"], ["Service will not start"]))

    def test_section_9_sample_is_k_rows_seeded_by_doc_sha(self):
        import hashlib
        self.write_rows(extra_symptoms=[f"| Symptom {i} | Check | Fix | Never |" for i in range(2, 31)])
        plan = self.plan()
        nine = self.section(plan, "9")
        keys = ["9/service-will-not-start"] + [f"9/symptom-{i}" for i in range(2, 31)]
        ranked = sorted(keys, key=lambda k: (hashlib.sha1((plan["doc_sha"] + k).encode()).hexdigest(), k))
        self.assertEqual((nine["total"], nine["k"]), (30, 8))
        self.assertEqual(nine["ids"], [k for k in keys if k in set(ranked[:8])])
        self.assertEqual(len(nine["items"]), 8)

    def test_row_keys_are_stable_under_unrelated_edits_and_collisions_are_suffixed(self):
        self.write_rows(controls=["| TLS | Present | `app/main.py:7` |", "| tls | Present | `app/main.py:7` |",
                                  "| TLS! | Not established | `app/main.py:7` |", "| TLS? | Present | `app/main.py:7` |"])
        keys = self.section(self.plan(), "10.2")["ids"]
        self.assertEqual(keys, ["10.2/tls", "10.2/tls-2", "10.2/tls-4"])      # the third row counts, though not planned
        # another cell of a row, or another row's status, does not move any key
        self.write_rows(controls=["| TLS | Present | `app/main.py:8` |", "| tls | Present | elsewhere |",
                                  "| TLS! | Present | `app/main.py:7` |", "| TLS? | Present | `app/main.py:7` |"])
        self.assertEqual(self.section(self.plan(), "10.2")["ids"], ["10.2/tls", "10.2/tls-2", "10.2/tls-3", "10.2/tls-4"])

    def test_renaming_the_first_cell_rekeys_the_row(self):
        self.write_rows(controls=["| Read-only DB role | Present | `app/main.py:7` |"])
        before = self.section(self.plan(), "10.2")["ids"]
        self.write_rows(controls=["| Read only database role | Present | `app/main.py:7` |"])
        after = self.section(self.plan(), "10.2")["ids"]
        self.assertEqual((before, after), (["10.2/read-only-db-role"], ["10.2/read-only-database-role"]))

    def test_row_refs_are_valid_register_refs(self):
        from appdoc import audit_plan, register
        for ref in ("10.2/tls", "16.5/secret-rotation", "17/run", "9/service-will-not-start", "10.2/tls-2"):
            self.assertTrue(register.REF_RE.match(ref), ref)
            self.assertEqual(register.ref_key(ref), ref)
            self.assertEqual(audit_plan.ref_for(ref), ref)
        self.assertEqual(register.ref_key("10.1/V-2"), "V-2")        # an ID ref is still its ID
        self.assertEqual(register.ref_key("10.2"), "10.2")           # a 2.7.0 section-level row is still valid
        for bad in ("10.2/TLS", "10.2/-tls", "10.2/tls-", "10.2/a b", "10.2/"):
            self.assertIsNone(register.REF_RE.match(bad), bad)
        self.assertTrue(audit_plan._in_section("10.2/tls", "10.2"))
        self.assertTrue(audit_plan._in_section("10.2", "10.2"))      # the legacy row counts as extra, not as a ref of 10.1
        self.assertFalse(audit_plan._in_section("10.2/tls", "10.1"))
        self.assertFalse(audit_plan._in_section("17/run", "7"))
        reg = register.parse("\n".join(json.dumps(x) for x in [
            {"type": "audit", "performed": True, "auditor": "independent", "scope": "x"},
            {"id": "E-1", "ref": "10.2/tls", "claim": "c", "result": "Supported", "cites": [], "anchor": "", "limitation": "none"}]))
        self.assertEqual(reg.live_keys(), {"10.2/tls"})

    def test_progress_counts_rows_and_calls_a_legacy_section_row_extra(self):
        from appdoc import audit_plan
        self.write_rows()
        plan = self.plan()
        got = {s: (p, a, x) for s, p, a, x in audit_plan.progress(plan, {"10.2/tls", "10.2/audit-log", "10.2", "17/run"})}
        self.assertEqual(got["10.2"], (3, 2, 1))
        self.assertEqual(got["17"], (1, 1, 0))

    def test_audit_floor_override_only_raises(self):
        self.write(n_f=20)
        self.assertEqual(self.section(self.plan(), "4")["k"], 5)
        self.write(n_f=20, extra="Audit floor: 0.5, 8\n")
        plan = self.plan()
        self.assertEqual(self.section(plan, "4")["k"], 10)            # max(8, ceil(0.5 * 20))
        self.assertEqual(plan["advisories"], [])
        self.write(n_f=20, extra="Audit floor: 0.1, 2\n")              # looser on both: ignored and reported
        plan = self.plan()
        self.assertEqual(self.section(plan, "4")["k"], 5)
        self.assertEqual(len(plan["advisories"]), 2, plan["advisories"])
        self.assertIn("appdoc-context.md line 1", plan["advisories"][0])
        self.write(n_f=20, extra="Audit floor: 0.5, 2\n")              # stricter fraction applies; the looser minimum does not
        plan = self.plan()
        self.assertEqual((plan["floor"], self.section(plan, "4")["k"]), ({"fraction": "0.5", "minimum": 5}, 10))
        self.assertEqual(len(plan["advisories"]), 1)


class SealProvenanceTests(unittest.TestCase):
    """T27.04: `seal --audit --date` and the audit/upgrade provenance of sealed rows."""

    def setUp(self):
        from tests.test_check import AUDIT, OLD_STAMP, ROWS, build_doc
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.target = os.path.join(self.tmp.name, "t")
        self.out = os.path.join(self.target, "docs", "appdoc")
        os.makedirs(self.out)
        self.build_doc, self.AUDIT, self.ROWS, self.OLD_STAMP = build_doc, AUDIT, ROWS, OLD_STAMP

    def write(self, stamp="2.7", audit=None):
        doc = self.build_doc().replace(self.OLD_STAMP, f"<!-- appdoc:template {stamp} -->")
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
        self.assertEqual(audit["doc_sha"], fingerprint.doc_sha(doc))
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
        for sha, want in ((fingerprint.doc_sha(doc), "audit"), ("0" * 12, "upgrade")):
            self.write(audit=dict(self.AUDIT, doc_sha=sha))
            self.main()
            self.assertEqual({r["sealed_by"] for r in self.read()[1:]}, {want}, sha)

    def facts(self):
        from appdoc import extract
        extract.write(self.target, self.out)

    def test_seal_audit_fingerprints_the_filled_document(self):
        """S6.1: a stale scan-coverage block is filled before the fingerprint, so a later `fill` keeps doc_sha."""
        from appdoc import check, fill
        self.write()
        self.facts()
        self.assertEqual(self.main("--audit", "--date", "2026-11-23")[0], 0)
        audit = self.read()[0]
        md = os.path.join(self.out, "application-documentation.md")
        with open(md, encoding="utf-8") as fh:
            sealed_text = fh.read()
        self.assertIn("Stack", dict((n, c) for n, c, _ in fill.blocks(sealed_text))["scan-coverage"])
        self.assertEqual(audit["doc_sha"], fingerprint.doc_sha(sealed_text))
        self.assertEqual(fill.run(self.target, self.out), 0)
        with open(md, encoding="utf-8") as fh:
            self.assertEqual(fingerprint.doc_sha(fh.read()), audit["doc_sha"])
        check.run(self.target, self.out, True, True)      # the fixture has other problems; C17 is not one of them
        with open(os.path.join(self.out, check.REPORT), encoding="utf-8") as fh:
            self.assertNotIn("## C17", fh.read())

    def test_build_after_the_audit_seals_rows_audit_not_upgrade(self):
        """S6.1: the audit read the filled document; `build` seals before it fills, yet the rows are `audit` because
        the stale generated block is filled first."""
        from appdoc import check, fill
        from appdoc.__main__ import main
        stale = self.write()
        self.facts()
        self.assertEqual(fill.run(self.target, self.out), 0)
        with open(os.path.join(self.out, "application-documentation.md"), encoding="utf-8") as fh:
            sha = fingerprint.doc_sha(fh.read())
        self.assertNotEqual(sha, fingerprint.doc_sha(stale))
        self.write(audit=dict(self.AUDIT, doc_sha=sha))          # the stale text again, rows unsealed
        import contextlib, io
        with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
            main(["build", self.target])
        self.assertEqual({r["sealed_by"] for r in self.read()[1:]}, {"audit"})

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


class ExpandCitationsTests(unittest.TestCase):
    """T27.22: `appdoc build --expand-citations` rewrites unique bare names to their full path."""

    DOC = "\n".join([
        "# Doc", "<!-- appdoc:template 2.7 -->",
        "<!-- a comment `main.py:5` -->",
        "See `main.py:5`, `main.py:3-5` and `main.py` for the entry; `util.py:2` is ambiguous.",
        "Root files stay: `README.md:1`, `Procfile`, `appdoc-context.md:1`; full paths stay: `app/main.py:2`.",
        "Not a citation: `self.main`, `GET main.py`, `util.py` is ambiguous.",
        "```", "`main.py:5` inside a fence", "```",
        "<!-- appdoc:generated entry-points -->", "| `main.py:5` | generated |", "<!-- /appdoc:generated entry-points -->",
        "Unknown name `nowhere.py:1` stays.", ""])

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.target = os.path.join(self.tmp.name, "t")
        self.out = os.path.join(self.target, "docs", "appdoc")
        for rel in ("app/main.py", "a/util.py", "b/util.py", "README.md", "Procfile", "appdoc-context.md"):
            path = os.path.join(self.target, *rel.split("/"))
            os.makedirs(os.path.dirname(path), exist_ok=True)
            with open(path, "w") as fh:
                fh.write("".join(f"line {i}\n" for i in range(1, 8)))
        os.makedirs(self.out)
        self.path = os.path.join(self.out, "application-documentation.md")
        with open(self.path, "w", encoding="utf-8", newline="\n") as fh:
            fh.write(self.DOC)

    def read(self):
        with open(self.path, encoding="utf-8", newline="") as fh:
            return fh.read()

    def test_expand_citations_unique_only(self):
        from appdoc import check
        self.assertEqual(seal.expand_citations(self.target, self.out), 3)
        got = self.read().splitlines()
        self.assertEqual(got[2], "<!-- a comment `main.py:5` -->")                       # comments stay
        self.assertEqual(got[3], "See `app/main.py:5`, `app/main.py:3-5` and `app/main.py` for the entry; "
                                 "`util.py:2` is ambiguous.")                          # unique names only
        self.assertEqual(got[4], self.DOC.splitlines()[4])                             # root, known and full stay
        self.assertEqual(got[5], self.DOC.splitlines()[5])                             # not citations
        self.assertEqual(got[6:], self.DOC.splitlines()[6:])                           # fence, block, unknown stay

    def test_expand_citations_idempotent(self):
        from appdoc import check
        seal.expand_citations(self.target, self.out)
        once = self.read()
        self.assertEqual(seal.expand_citations(self.target, self.out), 0)
        self.assertEqual(self.read(), once)
        self.assertNotIn("\r", once)

    def test_build_expand_citations_flag(self):
        import contextlib, io
        from appdoc import extract
        from appdoc.__main__ import main
        with contextlib.redirect_stdout(io.StringIO()):
            extract.write(self.target, self.out, workers=0, use_cache=False, no_ownership=True)
            main(["build", self.target, "--expand-citations"])
        self.assertIn("`app/main.py:5`", self.read())
        self.assertNotIn("See `main.py:5`", self.read())
        with contextlib.redirect_stdout(io.StringIO()):
            main(["build", self.target])      # without the flag the text is not touched again
        self.assertIn("`util.py:2` is ambiguous", self.read())
