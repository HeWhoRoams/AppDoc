"""tools/artifact_hashes.py: hashes of every generated artifact, LF-normalized, compared across CI jobs."""
import json
import os
import subprocess
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
TOOL = os.path.join(ROOT, "tools", "artifact_hashes.py")


def run(*args):
    return subprocess.run([sys.executable, TOOL, *args], cwd=tempfile.gettempdir(), capture_output=True, text=True)


class ArtifactHashes(unittest.TestCase):
    def test_prints_sorted_json_of_sha256_and_is_deterministic(self):
        a, b = run(), run()
        self.assertEqual(a.returncode, 0, a.stderr)
        self.assertEqual(a.stdout, b.stdout)
        doc = json.loads(a.stdout)
        self.assertEqual(list(doc), sorted(doc))
        self.assertTrue(any(k.endswith("/facts.json") for k in doc), list(doc))
        self.assertTrue(any(k.endswith("/application-documentation.md") for k in doc), list(doc))
        self.assertFalse(any("provenance.json" in k or ".appdoc-cache" in k for k in doc), list(doc))
        for v in doc.values():
            self.assertRegex(v, r"^[0-9a-f]{64}$")

    def test_compare_passes_when_equal_and_names_differences(self):
        d = tempfile.mkdtemp()
        base = json.loads(run().stdout)
        paths = []
        for i, doc in enumerate((base, dict(base), {**base, next(iter(base)): "0" * 64})):
            p = os.path.join(d, f"h{i}.json")
            with open(p, "w") as fh:
                json.dump(doc, fh)
            paths.append(p)
        ok = run("--compare", paths[0], paths[1])
        self.assertEqual(ok.returncode, 0, ok.stderr + ok.stdout)
        bad = run("--compare", *paths)
        self.assertEqual(bad.returncode, 1)
        self.assertIn(next(iter(base)), bad.stdout + bad.stderr)
        self.assertEqual(run("--compare", paths[0]).returncode, 1)   # one file proves nothing: fail loudly


class CiWorkflow(unittest.TestCase):
    def test_ci_runs_the_tool_per_matrix_job_and_compares(self):
        with open(os.path.join(ROOT, ".github", "workflows", "ci.yml"), encoding="utf-8") as fh:
            ci = fh.read()
        self.assertIn("python tools/artifact_hashes.py", ci)
        self.assertIn("actions/upload-artifact@v4", ci)
        self.assertIn("actions/download-artifact@v4", ci)
        self.assertIn("--compare", ci)
        self.assertIn("needs: test", ci)


if __name__ == "__main__":
    unittest.main()
