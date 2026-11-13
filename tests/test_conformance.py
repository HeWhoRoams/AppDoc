"""Stack conformance test (Phase 2.3): the "new language" guard.

For every stack in stacks.MODULES, run the extractor on its sample and assert:
  1. kind is in facts.KINDS
  2. path exists in the sample
  3. 1 <= line <= file length (when line is not None)
  4. detail keys are a subset of facts.DETAIL_KEYS[kind]
  5. no detail value has a secret shape
  6. two extractions are byte-identical
  7. the stack emits nothing outside its declared capabilities
  8. the sample exercises every declared capability
"""

import json
import os
import tempfile
import unittest

from appdoc import extract
from appdoc import facts as facts_mod
from appdoc import secrets
from appdoc.stacks import MODULES

SAMPLES = os.path.join(os.path.dirname(__file__), "samples")


def _extract(sample_dir: str) -> dict:
    with tempfile.TemporaryDirectory() as out:
        text, _ = extract.extract(sample_dir, out)
    return json.loads(text)


class ConformanceTests(unittest.TestCase):
    """One test per stack, plus cross-cutting checks."""

    @classmethod
    def setUpClass(cls):
        cls.results = {}
        for name in MODULES:
            sample = os.path.join(SAMPLES, name.replace("_", "-"))
            if not os.path.isdir(sample):
                continue
            doc1 = _extract(sample)
            doc2 = _extract(sample)
            cls.results[name] = (sample, doc1, doc2)

    def _stack_name(self, module_name: str) -> str:
        """Map module name to the stack id used in facts."""
        import importlib
        mod = importlib.import_module(f"appdoc.stacks.{module_name}")
        return getattr(mod, "STACK_ID", module_name.replace("_", "-"))

    def _capabilities(self, module_name: str) -> frozenset:
        import importlib
        mod = importlib.import_module(f"appdoc.stacks.{module_name}")
        return getattr(mod, "capabilities", frozenset())

    def test_all_stacks_have_samples(self):
        for name in MODULES:
            sample = os.path.join(SAMPLES, name.replace("_", "-"))
            self.assertTrue(os.path.isdir(sample), f"missing sample dir for {name}")

    def test_determinism(self):
        for name, (sample, doc1, doc2) in self.results.items():
            self.assertEqual(doc1, doc2, f"{name}: two extractions differ")

    def test_kind_in_kinds(self):
        for name, (sample, doc, _) in self.results.items():
            for f in doc["facts"]:
                self.assertIn(f["kind"], facts_mod.KINDS,
                              f"{name}: unknown kind {f['kind']!r} in {f['path']}")

    def test_path_exists(self):
        for name, (sample, doc, _) in self.results.items():
            for f in doc["facts"]:
                full = os.path.join(sample, f["path"].replace("/", os.sep))
                self.assertTrue(os.path.isfile(full),
                                f"{name}: path {f['path']!r} does not exist in sample")

    def test_line_in_range(self):
        for name, (sample, doc, _) in self.results.items():
            for f in doc["facts"]:
                if f["line"] is None:
                    continue
                full = os.path.join(sample, f["path"].replace("/", os.sep))
                with open(full, "rb") as fh:
                    nlines = fh.read().count(b"\n") + 1
                self.assertGreaterEqual(f["line"], 1,
                                        f"{name}: line < 1 in {f['path']}")
                self.assertLessEqual(f["line"], nlines,
                                     f"{name}: line {f['line']} > {nlines} in {f['path']}")

    def test_detail_keys_subset(self):
        for name, (sample, doc, _) in self.results.items():
            for f in doc["facts"]:
                allowed = facts_mod.DETAIL_KEYS.get(f["kind"], frozenset())
                for k in f.get("detail", {}):
                    self.assertIn(k, allowed,
                                  f"{name}: detail key {k!r} not in DETAIL_KEYS[{f['kind']!r}]")

    def test_no_secret_shapes(self):
        for name, (sample, doc, _) in self.results.items():
            for f in doc["facts"]:
                for k, v in f.get("detail", {}).items():
                    s = str(v)
                    shapes = secrets.find_secret_shapes(s)
                    self.assertEqual(shapes, [],
                                     f"{name}: secret shape in {f['kind']}.{k} = {s!r}")

    def test_no_facts_outside_capabilities(self):
        for name, (sample, doc, _) in self.results.items():
            caps = self._capabilities(name)
            if not caps:
                continue
            stack_id = self._stack_name(name)
            for f in doc["facts"]:
                if f["stack"] != stack_id:
                    continue
                self.assertIn(f["kind"], caps,
                              f"{name}: emits {f['kind']!r} not in capabilities {sorted(caps)}")

    def test_sample_exercises_every_capability(self):
        for name, (sample, doc, _) in self.results.items():
            caps = self._capabilities(name)
            if not caps:
                continue
            stack_id = self._stack_name(name)
            emitted = {f["kind"] for f in doc["facts"] if f["stack"] == stack_id}
            missing = caps - emitted
            self.assertEqual(missing, set(),
                             f"{name}: capabilities {sorted(caps)} not exercised: {sorted(missing)}")


if __name__ == "__main__":
    unittest.main()
