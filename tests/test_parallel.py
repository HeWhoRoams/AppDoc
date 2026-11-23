"""Phase 2: parallel per-file extraction matches serial and is deterministic.

``dumps`` sorts + de-duplicates the *set* of Facts, so completion order is erased. These tests
build a target large enough to cross ``PARALLEL_THRESHOLD`` and prove the process pool produces
byte-identical output to the serial loop, and that it is stable across worker counts.
"""

import os
import shutil
import tempfile
import unittest

from appdoc import extract


def _large_target(root, n=60):
    """A target with ``n`` source files (>= PARALLEL_THRESHOLD) plus a manifest, each file
    yielding a distinct external-call Fact so the set of Facts is meaningful and stable."""
    with open(os.path.join(root, "requirements.txt"), "w") as fh:
        fh.write("requests==2.31\n")
    pkg = os.path.join(root, "pkg")
    os.makedirs(pkg, exist_ok=True)
    for i in range(n):
        with open(os.path.join(pkg, f"mod{i:03d}.py"), "w") as fh:
            fh.write(f"import requests\nrequests.get('http://svc{i}.example/api/{i}')\n")


class ParallelTests(unittest.TestCase):
    def test_parallel_matches_serial(self):
        root = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, root, True)
        _large_target(root)
        out_a = tempfile.mkdtemp()
        out_b = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, out_a, True)
        self.addCleanup(shutil.rmtree, out_b, True)
        # workers=4 forces the process pool (file count > threshold); workers=0 is the serial path.
        a = extract.extract(root, out_a, workers=4, use_cache=False)
        b = extract.extract(root, out_b, workers=0, use_cache=False)
        self.assertEqual(a, b, "parallel (4) must be byte-identical to serial (0)")

    def test_parallel_determinism_across_worker_counts(self):
        root = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, root, True)
        _large_target(root)
        outs = [tempfile.mkdtemp() for _ in range(3)]
        for o in outs:
            self.addCleanup(shutil.rmtree, o, True)
        results = [extract.extract(root, o, workers=w, use_cache=False) for w, o in ((1, outs[0]), (2, outs[1]), (8, outs[2]))]
        self.assertEqual(results[0], results[1], "workers=1 must equal workers=2")
        self.assertEqual(results[1], results[2], "workers=2 must equal workers=8")

    def test_parallel_with_cache_matches_serial_cold(self):
        """The default-style path (process pool + content-hash cache on) is byte-identical to a
        cold serial run on a large target."""
        root = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, root, True)
        _large_target(root)
        out_p = tempfile.mkdtemp()
        out_s = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, out_p, True)
        self.addCleanup(shutil.rmtree, out_s, True)
        parallel_cached = extract.extract(root, out_p, workers=4, use_cache=True)
        serial_cold = extract.extract(root, out_s, workers=0, use_cache=False)
        self.assertEqual(parallel_cached, serial_cold, "pool+cache must equal cold serial")


if __name__ == "__main__":
    unittest.main()
