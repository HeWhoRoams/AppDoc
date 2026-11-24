"""Scale (T26.62): a synthetic Target of 10,000 files extracts within a generous time budget, and the content
index reads each file once. The budget is a guard against accidental quadratic work, not a benchmark: it is
several times what a slow CI runner needs."""
import json
import os
import shutil
import tempfile
import time
import unittest
from unittest import mock

from appdoc import extract, scan

FILES = 10_000  # including the requirements.txt that makes the Target a Flask app
FOLDERS = 101
BUDGET_SECONDS = 180


def build_tree(root: str, files: int = FILES, folders: int = FOLDERS) -> None:
    """`files` small, distinct files (one is requirements.txt) over `folders` folders, a route in every tenth module."""
    per = (files - 1) // folders
    with open(os.path.join(root, "requirements.txt"), "w", encoding="utf-8", newline="\n") as fh:
        fh.write("flask==3.0.3\n")
    for d in range(folders):
        folder = os.path.join(root, f"pkg{d:03d}")
        os.makedirs(folder)
        for i in range(per):
            n = d * per + i
            body = f"# module {n}\ndef handler_{n}():\n    return {n}\n"
            if n % 10 == 0:
                body = "from flask import Flask\napp = Flask(__name__)\n" + body.replace(
                    f"def handler_{n}", f'@app.route("/r{n}")\ndef handler_{n}')
            with open(os.path.join(folder, f"mod{i:03d}.py"), "w", encoding="utf-8", newline="\n") as fh:
                fh.write(body)


class Scale(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.root = tempfile.mkdtemp()
        cls.addClassCleanup(shutil.rmtree, cls.root, True)
        build_tree(cls.root)

    def test_tree_has_ten_thousand_files(self):
        n = sum(len(names) for _, _, names in os.walk(self.root))
        self.assertEqual(n, FILES)

    def test_content_index_reads_each_file_once(self):
        seen = []
        real = scan._sha1_file

        def spy(full):
            seen.append(os.path.relpath(full, self.root).replace(os.sep, "/"))
            return real(full)
        stats: dict = {}
        with mock.patch.object(scan, "_sha1_file", spy):
            files = scan.walk(self.root, None, stats)
        self.assertEqual(len(files), FILES)
        self.assertEqual(len(seen), FILES)
        self.assertEqual(len(set(seen)), FILES, "a file was hashed twice")
        self.assertEqual(stats["duplicate_folders"], [])
        self.assertEqual(stats["retired_candidates"], [])

    def test_extract_within_budget(self):
        with tempfile.TemporaryDirectory() as out:
            start = time.perf_counter()
            text, _ = extract.extract(self.root, out, workers=0, use_cache=False, no_ownership=True)
            elapsed = time.perf_counter() - start
        self.assertLess(elapsed, BUDGET_SECONDS, f"extracting {FILES} files took {elapsed:.1f}s")
        doc = json.loads(text)
        self.assertEqual(doc["target"]["scan"]["scanned"], FILES)
        routes = [f for f in doc["facts"] if f["kind"] == "entry_point" and f["detail"].get("type") == "route"]
        self.assertEqual(len(routes), FILES // 10)


if __name__ == "__main__":
    unittest.main()
