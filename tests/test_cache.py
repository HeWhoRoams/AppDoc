"""Content-hash Facts cache is exact and self-invalidating (salted with SCHEMA and the bundle hash).

The cache is a *cache*, not a semantic change: a warm run and a cold run must produce
byte-identical Facts, and a changed file must invalidate its cached entry.
"""

import json
import os
import shutil
import tempfile
import unittest
from unittest import mock

from appdoc import extract, facts as F, version


class CacheRoundTripTests(unittest.TestCase):
    def test_cache_round_trip(self):
        """Fact.from_json(f.to_json()) == f for a battery of Facts (incl. as_test, collections, None line)."""
        battery = [
            F.Fact.make("file", "generic", "a/b.py", None, "a/b.py",
                        size=10, ext=".py", lines=1, encoding="utf-8", stacks=["python-flask"]),
            F.Fact.make("stack", "python-flask", "requirements.txt", None, "python-flask",
                        marker_files=["requirements.txt"], file_count=3, supported=True),
            F.Fact.make("external_call", "python-flask", "app.py", 2, "requests.get", type="http", test=True),
            F.Fact.make("dependency", "generic", "requirements.txt", 1, "flask", version="2.0", manager="pip"),
            F.Fact.make("dependency", "generic", "pom.xml", 9, "g:a", version="", manager="maven"),
            F.Fact.make("connection", "generic", "web.config", 5, "Main", type="database", secret_location=True),
            F.Fact.make("ownership", "generic", "pkg", None, "pkg", authors=["A", "B"], commits=42),
            F.Fact.make("config_key", "generic", ".env", 1, "DB_PASSWORD", source=".env", secret_location=True),
            F.Fact.make("data_access", "python-flask", "db.py", 4, "SELECT", table="users"),
        ]
        # as_test() produces a Fact with an extra ('test', True) detail; verify it round-trips too.
        battery.append(battery[2].as_test())
        # A multi-value collection detail (list of >1).
        battery.append(F.Fact.make("stack", "node-express", "package.json", None, "node-express",
                                   marker_files=["package.json"], file_count=10, supported=True))
        for f in battery:
            self.assertEqual(F.Fact.from_json(f.to_json()), f, f)

    def test_cache_round_trip_preserves_sort_order(self):
        f = F.Fact.make("ownership", "generic", "pkg", None, "pkg", authors=["Z", "A"], commits=1)
        self.assertEqual(F.Fact.from_json(f.to_json()).detail, f.detail)


def _build_target(root):
    with open(os.path.join(root, "requirements.txt"), "w") as fh:
        fh.write("requests==2.31\n")
    with open(os.path.join(root, "a.py"), "w") as fh:
        fh.write("requests.get('http://v1.example/x')\n")


def _ext_calls_for(doc, path):
    return [f for f in doc["facts"] if f["kind"] == "external_call" and f["path"] == path]


class CacheBehaviorTests(unittest.TestCase):
    def test_cache_warm_equals_cold(self):
        """A warm run (cache present) and a cold run (--no-cache) produce byte-identical Facts."""
        root = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, root, True)
        _build_target(root)
        out = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, out, True)
        cold_with_cache = extract.extract(root, out, use_cache=True)   # miss, writes cache
        warm = extract.extract(root, out, use_cache=True)              # hit, reads cache
        cold_no_cache = extract.extract(root, out, use_cache=False)    # no cache
        self.assertEqual(cold_with_cache[0], warm[0], "warm must equal the first cold run")
        self.assertEqual(warm[0], cold_no_cache[0], "warm must equal the no-cache cold run")
        self.assertEqual(cold_with_cache[1], cold_no_cache[1])
        # The cache file was actually written and is non-empty.
        cache_path = os.path.join(out, ".appdoc-cache.json")
        self.assertTrue(os.path.isfile(cache_path))
        self.assertTrue(json.load(open(cache_path, encoding="utf-8")))

    def test_cache_invalidates_on_content_change(self):
        """Mutating a file's content must invalidate its cache entry; the output reflects the change."""
        root = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, root, True)
        _build_target(root)
        out = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, out, True)
        before = extract.extract(root, out, use_cache=True)
        before_calls = len(_ext_calls_for(json.loads(before[0]), "a.py"))
        # Mutate a.py: add a second request (new content -> new cache key -> recompute).
        with open(os.path.join(root, "a.py"), "w") as fh:
            fh.write("requests.get('http://v1.example/x')\nrequests.get('http://v2.example/x')\n")
        after = extract.extract(root, out, use_cache=True)
        after_calls = len(_ext_calls_for(json.loads(after[0]), "a.py"))
        self.assertNotEqual(before[0], after[0], "output must change when content changes")
        self.assertEqual(before_calls, 1, "baseline should have one external_call for a.py")
        self.assertEqual(after_calls, 2, "the changed content must be re-extracted (cache invalidated)")


class CacheKeySaltTests(unittest.TestCase):
    """The cache key is salted with F.SCHEMA and the bundle hash (version.bundle_hash()), so any change to
    AppDoc's own files (a Stack regex, the catalog, extraction logic) invalidates a stale cache entry."""

    RAW = b"requests.get('http://x.example/')\n"
    PATH = "a.py"
    IDS = ["python-flask"]

    def _key(self, schema=None):
        saved = F.SCHEMA
        F.SCHEMA = schema if schema is not None else saved
        try:
            return extract._cache_key(self.RAW, self.PATH, self.IDS)
        finally:
            F.SCHEMA = saved

    def test_same_bundle_hits(self):
        self.assertEqual(self._key(), self._key())

    def test_bundle_change_invalidates(self):
        """Change the content of a file in the bundle: the key changes (and changes back with it)."""
        pkg = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, pkg, True)
        path = os.path.join(pkg, "stack.py")

        def write(text):
            with open(path, "w", encoding="utf-8") as fh:
                fh.write(text)

        write("REGEX = 'a'\n")
        with mock.patch.object(version, "_bundle_files", lambda: [("stack.py", path)]):
            before = self._key()
            self.assertEqual(before, self._key())
            write("REGEX = 'ab'\n")
            after = self._key()
            self.assertNotEqual(before, after)
            write("REGEX = 'a'\n")
            self.assertEqual(before, self._key())

    def test_key_uses_the_bundle_hash(self):
        with mock.patch.object(version, "bundle_hash", return_value="0" * 40):
            k0 = self._key()
        with mock.patch.object(version, "bundle_hash", return_value="1" * 40):
            k1 = self._key()
        self.assertNotEqual(k0, k1)

    def test_changed_schema_changes_key(self):
        # The schema bytes are also in the key: a schema change invalidates the cache.
        self.assertNotEqual(self._key(), self._key(schema="appdoc-facts/999"))


if __name__ == "__main__":
    unittest.main()
