"""Phase 2.5: version skew is detected.

Covers the `--version` flag (version + bundle hash) and that facts.json carries
provenance.json (generator, bundle, schema), which replaced the `generator` field of facts.json.
"""

import contextlib
import io
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import unittest

from appdoc import __version__, extract, facts, version

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
SAMPLE = os.path.join(HERE, "samples", "python-flask")


class CacheSaltTests(unittest.TestCase):
    def test_no_manual_extractor_version(self):
        """The cache is salted with the bundle hash, so there is no constant to forget to bump."""
        self.assertFalse(hasattr(extract, "EXTRACTOR_VERSION"))
        with open(os.path.join(ROOT, "appdoc", "extract.py"), encoding="utf-8") as fh:
            self.assertNotIn("EXTRACTOR_VERSION", fh.read())


class VersionFlagTests(unittest.TestCase):
    def test_version_flag_prints_version_and_bundle_hash(self):
        r = subprocess.run([sys.executable, "-m", "appdoc", "--version"],
                           cwd=ROOT, capture_output=True, text=True)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn(__version__, r.stdout)
        # a 40-char lowercase hex SHA-1
        self.assertRegex(r.stdout, r"\b[0-9a-f]{40}\b")

    def test_version_flag_is_deterministic(self):
        def run():
            r = subprocess.run([sys.executable, "-m", "appdoc", "--version"],
                               cwd=ROOT, capture_output=True, text=True)
            return r.stdout.strip()
        self.assertEqual(run(), run())

    def test_bundle_hash_changes_when_a_package_file_changes(self):
        from appdoc.__main__ import bundle_hash
        base = bundle_hash()
        pkg = os.path.join(ROOT, "appdoc")
        probe = os.path.join(pkg, "_probe.txt")
        try:
            with open(probe, "w", encoding="utf-8") as fh:
                fh.write("x")
            self.assertNotEqual(bundle_hash(), base)
        finally:
            if os.path.exists(probe):
                os.remove(probe)
        self.assertEqual(bundle_hash(), base)


def _extract(test, sample=SAMPLE, **kw):
    work = tempfile.mkdtemp()
    test.addCleanup(shutil.rmtree, work, True)
    target = os.path.join(work, "target")
    shutil.copytree(sample, target)
    out = os.path.join(target, "docs", "appdoc")
    written = extract.write(target, out, **kw)
    return target, out, written


class ProvenanceTests(unittest.TestCase):
    def test_facts_has_no_generator(self):
        _, out, _ = _extract(self)
        with open(os.path.join(out, "facts.json"), encoding="utf-8") as fh:
            doc = json.load(fh)
        self.assertNotIn("generator", doc)
        self.assertEqual(doc["schema"], facts.SCHEMA)
        self.assertNotIn("generator", json.loads(facts.dumps("t", None, [])))

    def test_provenance_written(self):
        _, out, written = _extract(self)
        path = os.path.join(out, "provenance.json")
        self.assertIn(path, written)
        with open(path, encoding="utf-8") as fh:
            text = fh.read()
        doc = json.loads(text)
        self.assertEqual(sorted(doc), ["bundle", "generator", "schema"])
        self.assertEqual(doc["generator"], __version__)
        self.assertEqual(doc["schema"], facts.SCHEMA)
        self.assertRegex(doc["bundle"], r"^[0-9a-f]{12}$")
        self.assertEqual(doc, version.provenance())
        self.assertNotRegex(text, r"\d{4}-\d{2}-\d{2}")  # no timestamps
        self.assertNotIn("\r", text)

    def test_provenance_is_the_one_implementation(self):
        self.assertEqual(version.provenance(), {"generator": __version__, "bundle": version.bundle_hash()[:12],
                                                "schema": facts.SCHEMA})

    def test_bundle_single_implementation(self):
        from appdoc import __main__ as main
        self.assertIs(main.bundle_hash, version.bundle_hash)
        hits = []
        for dirpath, _, names in os.walk(os.path.join(ROOT, "appdoc")):
            for n in names:
                if n.endswith(".py") and n != "version.py":
                    with open(os.path.join(dirpath, n), encoding="utf-8") as fh:
                        if re.search(r"^\s*def bundle_hash\b|hashlib\.sha1\(\).*pkg", fh.read(), re.M):
                            hits.append(n)
        self.assertEqual(hits, [])

    def test_bundle_hash_ignores_bytecode_and_crlf(self):
        base = version.bundle_hash()
        pyc = os.path.join(ROOT, "appdoc", "__pycache__", "zz_probe.cpython-310.pyc")
        os.makedirs(os.path.dirname(pyc), exist_ok=True)
        try:
            with open(pyc, "wb") as fh:
                fh.write(b"x")
            self.assertEqual(version.bundle_hash(), base)
        finally:
            os.remove(pyc)

    def test_check_report_prints_bundle(self):
        from tests.test_check import CheckTests, build_doc
        t = CheckTests("test_pass")
        t.setUp()
        try:
            _, report, _ = t.run_check(build_doc())
        finally:
            t.tearDown()
        self.assertIn(f"Run by AppDoc {__version__} (bundle {version.bundle_hash()[:12]})", report)


if __name__ == "__main__":
    unittest.main()
