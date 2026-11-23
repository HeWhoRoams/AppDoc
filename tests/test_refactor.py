"""Phase 0: the _extract_file refactor is behavior-preserving.

The per-file work was factored out of the serial loop into a pure function. This test proves
the refactored ``_extract_file`` returns exactly the facts the original inline loop appended,
so the set of Facts (and therefore the byte-serialized Facts file) is unchanged.
"""

import os
import tempfile
import unittest

from appdoc import extract, facts as F, scan
from appdoc.stacks import generic, load


def _build_target(root):
    """A small target exercising file/stack/config/external-call Facts plus a test file."""
    with open(os.path.join(root, "requirements.txt"), "w") as fh:
        fh.write("flask==2.0\nrequests>=2\n")
    with open(os.path.join(root, "app.py"), "w") as fh:
        fh.write("import requests\nrequests.get('http://api.example/x')\nimport os\nos.environ.get('MODE')\n")
    os.makedirs(os.path.join(root, "tests"), exist_ok=True)
    with open(os.path.join(root, "tests", "test_app.py"), "w") as fh:
        fh.write("import requests\nrequests.get('http://t.example/x')\n")
    with open(os.path.join(root, "config.json"), "w") as fh:
        fh.write('{"settings": {"debug": true}, "db": {"name": "x"}}\n')


class RefactorTests(unittest.TestCase):
    def _detected(self, root):
        files = scan.walk(root)
        paths = [f.path for f in files]
        stacks = load()
        detected = {}
        for st in stacks:
            markers = st.detect(paths)
            if markers:
                detected[st.id] = (st, sorted(markers))
        return files, detected

    def test_refactor_preserves_output(self):
        """_extract_file over all files == the original inline loop body over all files."""
        root = tempfile.mkdtemp()
        self.addCleanup(lambda: __import__("shutil").rmtree(root, True))
        _build_target(root)
        files, detected = self._detected(root)

        # Reference: the ORIGINAL serial loop body (read_text + generic + stack + as_test).
        ref = []
        for sf in files:
            detail = {"size": sf.size, "ext": sf.ext}
            if sf.skipped:
                detail["skipped"] = sf.skipped
                ref.append(F.Fact.make("file", "generic", sf.path, None, sf.path, **detail))
                continue
            text, enc = scan.read_text(root, sf.path)
            detail.update(lines=text.count("\n") + (0 if text.endswith("\n") or not text else 1), encoding=enc)
            owners = sorted(sid for sid, (st, _) in detected.items() if sf.ext in st.extensions)
            detail["stacks"] = owners
            ref.append(F.Fact.make("file", "generic", sf.path, None, sf.path, **detail))
            found = list(generic.extract(sf.path, text))
            for sid in owners:
                found.extend(detected[sid][0].extract(sf.path, text))
            if extract.is_test_path(sf.path):
                found = [f.as_test() for f in found]
            ref.extend(found)

        # Refactored: the pure _extract_file over all files.
        got = []
        for sf in files:
            got.extend(extract._extract_file(root, sf, detected))

        key = lambda f: f.sort_key()
        self.assertEqual(sorted(got, key=key), sorted(ref, key=key))

    def test_extract_file_is_pure_and_idempotent(self):
        """Calling _extract_file twice for the same file yields identical Facts (no cross-file state)."""
        root = tempfile.mkdtemp()
        self.addCleanup(lambda: __import__("shutil").rmtree(root, True))
        _build_target(root)
        files, detected = self._detected(root)
        for sf in files:
            a = extract._extract_file(root, sf, detected)
            b = extract._extract_file(root, sf, detected)
            self.assertEqual(a, b, sf.path)


if __name__ == "__main__":
    unittest.main()
