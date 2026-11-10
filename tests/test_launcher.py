import os
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SAMPLE = os.path.join(ROOT, "tests", "samples", "python-flask")


class LauncherTests(unittest.TestCase):
    def test_installs_complete_runnable_bundle(self):
        work = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, work, True)
        skills = os.path.join(work, "skills")
        partial = os.path.join(skills, "appdoc")
        os.makedirs(partial)
        with open(os.path.join(partial, "SKILL.md"), "w", encoding="utf-8") as installed_skill:
            installed_skill.write("partial install")
        elsewhere = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, elsewhere, True)

        result = subprocess.run([sys.executable, os.path.join(ROOT, "install_skill.py"), skills],
                                cwd=elsewhere, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)

        installed = os.path.join(skills, "appdoc")
        for path in ("SKILL.md", "CONTEXT.md", "run_appdoc.py", "appdoc/assets/template.md",
                     "appdoc/assets/mermaid.min.js"):
            self.assertTrue(os.path.isfile(os.path.join(installed, path)), path)
        with open(os.path.join(ROOT, "SKILL.md"), encoding="utf-8") as source_skill:
            with open(os.path.join(installed, "SKILL.md"), encoding="utf-8") as installed_skill:
                self.assertEqual(installed_skill.read(), source_skill.read())

        target = os.path.join(work, "target")
        shutil.copytree(SAMPLE, target)
        result = subprocess.run([sys.executable, os.path.join(installed, "run_appdoc.py"),
                                 "extract", target], cwd=elsewhere, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(os.path.isfile(os.path.join(target, "docs", "appdoc", "facts.json")))

    def test_runs_from_an_unrelated_directory(self):
        work = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, work, True)
        target = os.path.join(work, "target")
        shutil.copytree(SAMPLE, target)
        elsewhere = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, elsewhere, True)
        r = subprocess.run([sys.executable, os.path.join(ROOT, "run_appdoc.py"), "extract", target],
                           cwd=elsewhere, capture_output=True, text=True)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertTrue(os.path.isfile(os.path.join(target, "docs", "appdoc", "facts.json")))

    def test_check_reports_missing_document_with_exit_1(self):
        work = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, work, True)
        r = subprocess.run([sys.executable, os.path.join(ROOT, "run_appdoc.py"), "check", work],
                           cwd=tempfile.gettempdir(), capture_output=True, text=True)
        self.assertEqual(r.returncode, 1)


if __name__ == "__main__":
    unittest.main()
