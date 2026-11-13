"""Phase 2.5: version skew is detected.

Covers the `--version` flag (version + bundle hash) and that facts.json carries
the `generator` field (the AppDoc version that wrote it).
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

from appdoc import __version__, extract, facts

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
SAMPLE = os.path.join(HERE, "samples", "python-flask")


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


class GeneratorFieldTests(unittest.TestCase):
    def test_facts_json_carries_the_generator_field(self):
        work = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, work, True)
        target = os.path.join(work, "target")
        shutil.copytree(SAMPLE, target)
        out = os.path.join(target, "docs", "appdoc")
        written = extract.write(target, out)
        self.assertTrue(any(p.endswith("facts.json") for p in written))
        with open(os.path.join(out, "facts.json"), encoding="utf-8") as fh:
            doc = json.load(fh)
        self.assertEqual(doc["generator"], __version__)

    def test_dumps_includes_generator(self):
        text = facts.dumps("t", None, [])
        self.assertEqual(json.loads(text)["generator"], __version__)


if __name__ == "__main__":
    unittest.main()
