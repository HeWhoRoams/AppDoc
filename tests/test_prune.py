"""Phase 1 (--skip-tests) and Phase 4 (git ownership isolation) are opt-in and default-neutral.

Both change the output *only when the user opts in*; the default (no flag) path is unchanged.
"""

import json
import os
import shutil
import subprocess
import tempfile
import unittest

from appdoc import extract

HERE = os.path.dirname(os.path.abspath(__file__))


def _git(repo, *args):
    subprocess.run(["git", "-C", repo, "-c", "user.name=T", "-c", "user.email=t@example.com", *args],
                   check=True, capture_output=True)


def _build_target(root):
    with open(os.path.join(root, "requirements.txt"), "w") as fh:
        fh.write("requests==2.31\n")
    with open(os.path.join(root, "app.py"), "w") as fh:
        fh.write("import requests\nrequests.get('http://api.example/x')\n")
    os.makedirs(os.path.join(root, "tests"), exist_ok=True)
    with open(os.path.join(root, "tests", "test_app.py"), "w") as fh:
        fh.write("import requests\nrequests.get('http://t.example/x')\n")


def _facts(doc, kind=None, path=None):
    out = []
    for f in doc["facts"]:
        if kind and f["kind"] != kind:
            continue
        if path and f["path"] != path:
            continue
        out.append(f)
    return out


class SkipTestsTests(unittest.TestCase):
    def test_skip_tests_changes_output(self):
        root = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, root, True)
        _build_target(root)
        out = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, out, True)

        default1 = extract.extract(root, out, use_cache=False)
        default2 = extract.extract(root, out, use_cache=False)
        pruned = extract.extract(root, out, skip_tests=True, use_cache=False)

        # Default is deterministic and keeps the test-code Facts (marked as test).
        self.assertEqual(default1, default2, "default must be deterministic")
        self.assertTrue(_facts(json.loads(default1[0]), "external_call", "tests/test_app.py"),
                        "default must include the test file's external_call")
        # Pruning removes the test file's code Facts but still lists the file as skipped="test".
        pruned_doc = json.loads(pruned[0])
        self.assertEqual(_facts(pruned_doc, "external_call", "tests/test_app.py"), [],
                         "skip_tests must drop the test file's code Facts")
        skipped = _facts(pruned_doc, "file", "tests/test_app.py")
        self.assertTrue(skipped and skipped[0]["detail"].get("skipped") == "test",
                        "skip_tests must flag the test file skipped='test'")
        # The non-test file is untouched.
        self.assertTrue(_facts(pruned_doc, "external_call", "app.py"),
                        "skip_tests must leave non-test code Facts intact")
        # Opt-in changes the output; the default differs from the pruned output.
        self.assertNotEqual(default1[0], pruned[0], "skip_tests output must differ from the default")


@unittest.skipUnless(shutil.which("git"), "git not installed")
class OwnershipIsolationTests(unittest.TestCase):
    def _git_repo(self):
        root = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, root, True)
        for folder, count in (("alpha", 3), ("beta", 1)):
            d = os.path.join(root, folder)
            os.makedirs(d, exist_ok=True)
            for i in range(count):
                with open(os.path.join(d, f"m{i}.py"), "w") as fh:
                    fh.write(f"x = {i}\n")
        _git(root, "init", "-q")
        _git(root, "add", "-A")
        _git(root, "commit", "-q", "-m", "init")
        return root

    def _ownership_folders(self, doc):
        return {f["name"] for f in _facts(doc, "ownership")}

    def test_no_ownership_removes_ownership_facts(self):
        root = self._git_repo()
        out = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, out, True)
        default = extract.extract(root, out, use_cache=False)
        no_own = extract.extract(root, out, no_ownership=True, use_cache=False)
        # Default (full history, repo root) has ownership Facts for both top-level folders.
        self.assertEqual(self._ownership_folders(json.loads(default[0])), {"alpha", "beta"})
        # --no-ownership removes them entirely.
        self.assertEqual(_facts(json.loads(no_own[0]), "ownership"), [],
                         "no_ownership must remove all ownership Facts")
        self.assertNotEqual(default[0], no_own[0])

    def test_ownership_top_caps_to_top_folders(self):
        root = self._git_repo()
        out = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, out, True)
        top1 = extract.extract(root, out, ownership_top=1, use_cache=False)
        # alpha has 3 files, beta has 1 -> top-1 by (count desc, folder) is alpha only.
        self.assertEqual(self._ownership_folders(json.loads(top1[0])), {"alpha"})
        # Default still covers both (default-neutral).
        default = extract.extract(root, out, use_cache=False)
        self.assertEqual(self._ownership_folders(json.loads(default[0])), {"alpha", "beta"})


if __name__ == "__main__":
    unittest.main()
