"""Phase 3: content-hash Facts cache is exact and self-invalidating.

The cache is a *cache*, not a semantic change: a warm run and a cold run must produce
byte-identical Facts, and a changed file must invalidate its cached entry.
"""

import json
import os
import shutil
import tempfile
import unittest

from appdoc import extract, facts as F


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


class CacheKeyVersionTests(unittest.TestCase):
    """The cache key is salted with F.SCHEMA + EXTRACTOR_VERSION, so an AppDoc upgrade
    (a schema or extractor-logic change) invalidates a stale cache entry."""

    RAW = b"requests.get('http://x.example/')\n"
    PATH = "a.py"
    IDS = ["python-flask"]

    def _key(self, version=None, schema=None):
        saved_v, saved_s = extract.EXTRACTOR_VERSION, F.SCHEMA
        extract.EXTRACTOR_VERSION = version if version is not None else saved_v
        F.SCHEMA = schema if schema is not None else saved_s
        try:
            return extract._cache_key(self.RAW, self.PATH, self.IDS)
        finally:
            extract.EXTRACTOR_VERSION, F.SCHEMA = saved_v, saved_s

    def test_same_version_same_key(self):
        # (b) The same (raw, path, detected_ids) at the current version is deterministic.
        self.assertEqual(self._key(), self._key())

    def test_bumped_extractor_version_changes_key(self):
        # (a) Two keys for the same (raw, path, detected_ids) at different EXTRACTOR_VERSION
        # values differ — a stale cache written by an older build is never served.
        self.assertNotEqual(self._key(), self._key(version=extract.EXTRACTOR_VERSION + 1))

    def test_changed_schema_changes_key(self):
        # The schema bytes are also in the key: a schema change invalidates the cache.
        self.assertNotEqual(self._key(), self._key(schema="appdoc-facts/999"))


if __name__ == "__main__":
    unittest.main()
