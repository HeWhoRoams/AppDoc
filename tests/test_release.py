"""Release guards (remediation plan 2.6, 6.3, 7.2): generated docs, changelog heading, gate pin, release script, example layout.

"""
import importlib.util
import os
import re
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

import appdoc
from appdoc import __main__ as cli
from appdoc import check, facts, template_spec as spec, workflow

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GEN_DOCS = os.path.join(ROOT, "tools", "gen_docs.py")
RELEASE = os.path.join(ROOT, "tools", "release.py")
YAML = os.path.join(ROOT, "ci", "appdoc-docs-gate.yml")


def load_tool(name, path):
    spec_ = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec_)
    spec_.loader.exec_module(mod)
    return mod


gen_docs = load_tool("appdoc_gen_docs", GEN_DOCS)


def is_release(version=appdoc.__version__):
    return ".dev" not in version


def read(*parts):
    with open(os.path.join(ROOT, *parts), encoding="utf-8") as fh:
        return fh.read()


def slurp(*parts):
    with open(os.path.join(*parts), encoding="utf-8") as fh:
        return fh.read()


def git(cwd, *args, env=None):
    return subprocess.run(["git", *args], cwd=cwd, capture_output=True, text=True, env=env)


class GeneratedDocs(unittest.TestCase):
    def test_generated_docs_current(self):
        res = subprocess.run([sys.executable, GEN_DOCS, "--check"], capture_output=True, text=True)
        self.assertEqual(res.returncode, 0, res.stdout + res.stderr)
        for rel, (current, new) in gen_docs.generate(ROOT).items():
            self.assertEqual(current, new, f"{rel} has stale generated blocks; run python tools/gen_docs.py")

    def test_check_names_a_stale_file_and_write_fixes_it(self):
        with tempfile.TemporaryDirectory() as tmp:
            for rel in ("README.md", "SKILL.md", os.path.join("ci", "appdoc-docs-gate.yml")):
                os.makedirs(os.path.dirname(os.path.join(tmp, rel)), exist_ok=True)
                shutil.copy(os.path.join(ROOT, rel), os.path.join(tmp, rel))
            tools = os.path.join(tmp, "tools")
            shutil.copytree(os.path.join(ROOT, "tools"), tools, ignore=shutil.ignore_patterns("__pycache__"))
            shutil.copytree(os.path.join(ROOT, "appdoc"), os.path.join(tmp, "appdoc"),
                            ignore=shutil.ignore_patterns("__pycache__"))
            readme = os.path.join(tmp, "README.md")
            text = slurp(readme)
            with open(readme, "w", encoding="utf-8", newline="") as fh:
                fh.write(text.replace("| C1 |", "| C1 stale |", 1))
            tool = os.path.join(tools, "gen_docs.py")
            res = subprocess.run([sys.executable, tool, "--check"], capture_output=True, text=True)
            self.assertEqual(res.returncode, 1)
            self.assertIn("README.md", res.stderr)
            self.assertEqual(subprocess.run([sys.executable, tool], capture_output=True, text=True).returncode, 0)
            self.assertEqual(subprocess.run([sys.executable, tool, "--check"], capture_output=True, text=True).returncode, 0)
            self.assertEqual(slurp(readme), text)

    def test_every_block_in_the_files_has_a_generator(self):
        for rel, generators in gen_docs.GENERATORS.items():
            names = set(m.group("name") for m in gen_docs.BLOCK_RE.finditer(read(rel)))
            self.assertEqual(names, set(generators), rel)

    def test_readme_rules_list_every_rule_with_its_flags(self):
        block = gen_docs.rules("")
        for rule in check.RULE_TITLES:
            self.assertRegex(block, rf"\| {rule} \|")
        self.assertRegex(block, r"\| C20 \| Citation precision \|.*advisory; fails under `--strict`")
        self.assertRegex(block, r"\| C16 \|.*advisory; fails under `--strict`")
        self.assertIn("fails from template 2.7", block)
        for rule in check.PREVIEW_RULES:
            self.assertIn(f"- {rule}:", block)

    def test_readme_commands_come_from_the_parser(self):
        block = gen_docs.commands("")
        for name in cli.COMMANDS:
            self.assertIn(f"`appdoc {name} <target>`", block)
        self.assertIn("`--require-audit`", block)

    def test_facts_schema_block_names_the_schema(self):
        self.assertIn(f"`{facts.SCHEMA}`", gen_docs.facts_schema(""))

    def test_skill_commands_come_from_workflow(self):
        block = gen_docs.run_commands("")
        for _, command, _ in workflow.run_commands():
            self.assertIn(f"`{command}`", block)
        for step in workflow.SKILL_STEPS:
            if step.command:
                self.assertIn(step.command.split()[0], cli.COMMANDS)


class SharedConstants(unittest.TestCase):
    """The docstrings of __main__ and check.py are built from the same constants the docs are generated from."""

    def test_main_docstring_lists_every_command(self):
        for name in cli.COMMANDS:
            self.assertIn(name, cli.__doc__)

    def test_parser_commands_are_the_constant(self):
        self.assertEqual(tuple(gen_docs._subparsers()), cli.COMMANDS)

    def test_check_docstring_names_the_rule_range(self):
        self.assertIn(f"rules {check.RULE_RANGE}", check.__doc__)
        self.assertEqual(check.RULE_RANGE, "C1-C" + str(max(int(k[1:]) for k in check.RULE_TITLES)))

    def test_every_rule_has_a_summary_and_flags_name_real_rules(self):
        self.assertEqual(set(check.RULE_SUMMARIES), set(check.RULE_TITLES))
        self.assertLessEqual(set(check.RULE_FLAGS), set(check.RULE_TITLES))
        for flags in check.RULE_FLAGS.values():
            self.assertLessEqual(set(flags), {"advisory", "strict"})

    def test_gate_header_uses_the_gate_constants(self):
        from appdoc import gate
        header = gen_docs.gate_header("")
        self.assertIn(f"at most {gate.DIFF_CAP} lines", header)
        self.assertIn(facts.SCHEMA, header)


class ChangelogAndPin(unittest.TestCase):
    def test_changelog_top_heading_matches_version(self):
        top = next(l for l in read("CHANGELOG.md").splitlines() if l.startswith("## "))
        if is_release():
            self.assertRegex(top, rf"^## {re.escape(appdoc.__version__)}(\s|$)")
        else:
            self.assertEqual(top, "## Unreleased")

    def test_gate_pin_matches_version(self):
        pin = re.search(r"APPDOC_REF: (v\d+\.\d+\.\d+)\s", read("ci", "appdoc-docs-gate.yml"))
        self.assertTrue(pin, "the gate YAML must pin APPDOC_REF: vX.Y.Z")
        if is_release():
            self.assertEqual(pin.group(1), f"v{appdoc.__version__}")
        else:
            # a dev version never requires a pin to a tag that does not exist yet
            self.assertEqual(gen_docs.gate_pin(f"APPDOC_REF: {pin.group(1)}"), f"APPDOC_REF: {pin.group(1)}")

    def test_gate_pin_for_a_release_version_is_its_tag(self):
        with mock.patch.object(gen_docs, "__version__", "2.6.0"):
            self.assertEqual(gen_docs.gate_pin("APPDOC_REF: v2.5.0"), "APPDOC_REF: v2.6.0")
        with mock.patch.object(gen_docs, "__version__", "2.6.1.dev0"):
            self.assertEqual(gen_docs.gate_pin("APPDOC_REF: v2.6.0"), "APPDOC_REF: v2.6.0")

    def test_version_has_no_second_literal(self):
        self.assertEqual(len(re.findall(r'__version__ = "', read("appdoc", "__init__.py"))), 1)


def _tree_copy(dest):
    """A throwaway git repo on `main` holding what the release script touches."""
    keep = ("appdoc", "tools", "ci", ".github", "README.md", "SKILL.md", "CHANGELOG.md", "CONTEXT.md", "run_appdoc.py",
            "examples")
    os.makedirs(os.path.join(dest, "tests"))
    shutil.copy(os.path.join(ROOT, "tests", "diag_metrics.py"), os.path.join(dest, "tests"))
    for name in keep:
        src = os.path.join(ROOT, name)
        if os.path.isdir(src):
            shutil.copytree(src, os.path.join(dest, name), ignore=shutil.ignore_patterns("__pycache__"))
        else:
            shutil.copy(src, dest)
    gate = os.path.join(dest, "ci", "appdoc-docs-gate.yml")
    with open(gate, encoding="utf-8", newline="") as fh:
        text = fh.read()
    with open(gate, "w", encoding="utf-8", newline="") as fh:
        fh.write(text.replace("APPDOC_REF: v2.6.0", "APPDOC_REF: v2.5.0"))  # the pin of the last release
    env = dict(os.environ, GIT_AUTHOR_NAME="t", GIT_AUTHOR_EMAIL="t@example.com",
               GIT_COMMITTER_NAME="t", GIT_COMMITTER_EMAIL="t@example.com")
    git(dest, "init", "-q", "-b", "main", env=env)
    git(dest, "add", "-A", env=env)
    git(dest, "commit", "-q", "-m", "base", env=env)
    return env


class ReleaseScript(unittest.TestCase):
    def test_release_script_dry_run(self):
        before = git(ROOT, "status", "--porcelain").stdout
        res = subprocess.run([sys.executable, RELEASE, "2.6.0", "--dry-run"], capture_output=True, text=True)
        out = res.stdout + res.stderr
        self.assertEqual(res.returncode, 0, out)
        self.assertEqual(git(ROOT, "status", "--porcelain").stdout, before, "a dry run must not change files")
        self.assertIn("dry run", out)
        for step in ("set version 2.6.0", "rename '## Unreleased'", "gen_docs", "run tests", "determinism",
                     "extractor eval", "narrative eval", "rotate examples", "git commit", "git tag -a v2.6.0",
                     "git push origin main v2.6.0", "2.6.1.dev0"):
            self.assertIn(step, out)
        self.assertIn(f'__version__ = "{appdoc.__version__}"', read("appdoc", "__init__.py"))

    def test_release_script_rejects_a_bad_version(self):
        for bad in ("2.6", "v2.6.0", "2.6.0.dev0", "two"):
            res = subprocess.run([sys.executable, RELEASE, bad, "--dry-run"], capture_output=True, text=True)
            self.assertEqual(res.returncode, 2, bad)

    def test_release_refuses_off_main_and_on_a_dirty_tree(self):
        with tempfile.TemporaryDirectory() as tmp:
            env = _tree_copy(tmp)
            script = os.path.join(tmp, "tools", "release.py")
            git(tmp, "checkout", "-q", "-b", "side", env=env)
            res = subprocess.run([sys.executable, script, "2.6.0", "--skip-checks"], capture_output=True, text=True, env=env)
            self.assertEqual(res.returncode, 1, res.stdout + res.stderr)
            self.assertIn("main", res.stdout + res.stderr)
            git(tmp, "checkout", "-q", "main", env=env)
            with open(os.path.join(tmp, "README.md"), "a", encoding="utf-8") as fh:
                fh.write("dirty\n")
            res = subprocess.run([sys.executable, script, "2.6.0", "--skip-checks"], capture_output=True, text=True, env=env)
            self.assertEqual(res.returncode, 1, res.stdout + res.stderr)
            self.assertIn("clean", res.stdout + res.stderr)
            self.assertEqual(git(tmp, "tag").stdout.strip(), "")

    def test_release_end_to_end_on_a_temp_repo(self):
        with tempfile.TemporaryDirectory() as tmp:
            env = _tree_copy(tmp)
            script = os.path.join(tmp, "tools", "release.py")
            res = subprocess.run([sys.executable, script, "2.6.0", "--skip-checks"], capture_output=True, text=True, env=env)
            out = res.stdout + res.stderr
            self.assertEqual(res.returncode, 0, out)
            self.assertIn("git push origin main v2.6.0", out)
            self.assertEqual(git(tmp, "tag").stdout.split(), ["v2.6.0"])
            tagged = git(tmp, "show", "v2.6.0:appdoc/__init__.py").stdout
            self.assertIn('__version__ = "2.6.0"', tagged)
            changelog = git(tmp, "show", "v2.6.0:CHANGELOG.md").stdout
            self.assertEqual(next(l for l in changelog.splitlines() if l.startswith("## ")), "## 2.6.0")
            self.assertIn("APPDOC_REF: v2.6.0", git(tmp, "show", "v2.6.0:ci/appdoc-docs-gate.yml").stdout)
            self.assertIn('__version__ = "2.6.1.dev0"', slurp(tmp, "appdoc", "__init__.py"))
            self.assertEqual(next(l for l in slurp(tmp, "CHANGELOG.md").splitlines() if l.startswith("## ")),
                             "## Unreleased")
            self.assertIn("APPDOC_REF: v2.6.0", slurp(tmp, "ci", "appdoc-docs-gate.yml"))
            self.assertEqual(git(tmp, "status", "--porcelain").stdout, "")
            self.assertEqual(len(git(tmp, "log", "--oneline").stdout.splitlines()), 3)
            gen = subprocess.run([sys.executable, os.path.join(tmp, "tools", "gen_docs.py"), "--check"],
                                 capture_output=True, text=True)
            self.assertEqual(gen.returncode, 0, gen.stdout + gen.stderr)


EXAMPLE_APPS = ("eShop", "flaskr-tdd", "gitea", "spring-petclinic")


class ExampleLayout(unittest.TestCase):
    """examples/current and examples/previous (remediation plan 2.6, 7.2)."""

    def test_examples_current_and_previous(self):
        cur, prev = (os.path.join(ROOT, "examples", d) for d in ("current", "previous"))
        self.assertTrue(os.path.isdir(cur), "examples/current is missing")
        self.assertTrue(os.path.isdir(prev), "examples/previous is missing")
        self.assertEqual([d for d in sorted(os.listdir(os.path.join(ROOT, "examples"))) if d != "helpweb"],
                         ["current", "previous"], "only current and previous belong under examples/")
        cur_v, prev_v = (slurp(d, "VERSION").strip() for d in (cur, prev))
        self.assertLess(spec.version_tuple(prev_v), spec.version_tuple(cur_v))
        for app in EXAMPLE_APPS:
            for d, v in ((cur, cur_v), (prev, prev_v)):
                self.assertEqual(slurp(d, app, "VERSION").strip(), v, f"{d}/{app}/VERSION")
                self.assertTrue(os.path.isfile(os.path.join(d, app, "application-documentation.md")))
        self.assertEqual(cur_v, appdoc.__version__.split(".dev")[0])

    def test_rotation_moves_current_to_previous_and_writes_the_new_current(self):
        release = load_tool("appdoc_release", RELEASE)
        with tempfile.TemporaryDirectory() as tmp:
            ex, docs, clones = (os.path.join(tmp, d) for d in ("examples", "docs", "clones"))
            os.makedirs(docs)
            for d, v in (("previous", "2.4.0"), ("current", "2.5.0")):
                os.makedirs(os.path.join(ex, d, "app"))
                release.write_version_file(os.path.join(ex, d), v)
                release.write_version_file(os.path.join(ex, d, "app"), v)
                with open(os.path.join(ex, d, "app", "marker.txt"), "w") as fh:
                    fh.write(v)
            os.makedirs(os.path.join(clones, "app"))
            calls = []

            def fake(app, clone, previous_dir, dest):
                calls.append(app)
                self.assertEqual(slurp(previous_dir, "marker.txt"), "2.5.0")
                os.makedirs(dest)
                with open(os.path.join(dest, "marker.txt"), "w") as fh:
                    fh.write("new")

            release.write_comparison = lambda *a, **k: None
            msg = release.rotate_examples("2.6.0", ex, clones, regenerate=fake, docs_dir=docs)
            self.assertIn("rotated", msg)
            self.assertEqual(calls, ["app"])
            self.assertEqual(slurp(ex, "previous", "VERSION").strip(), "2.5.0")
            self.assertEqual(slurp(ex, "previous", "app", "marker.txt"), "2.5.0")
            self.assertEqual(slurp(ex, "current", "VERSION").strip(), "2.6.0")
            self.assertEqual(slurp(ex, "current", "app", "VERSION").strip(), "2.6.0")
            self.assertEqual(slurp(ex, "current", "app", "marker.txt"), "new")
            self.assertEqual(release.rotate_examples("2.6.0", ex, clones, regenerate=fake, docs_dir=docs),
                             "examples already at 2.6.0; not rotated")
            self.assertEqual(calls, ["app"])
            with self.assertRaises(SystemExit):
                release.rotate_examples("2.5.5", ex, clones, regenerate=fake, docs_dir=docs)

    def test_rotation_without_clones_changes_nothing(self):
        release = load_tool("appdoc_release2", RELEASE)
        with tempfile.TemporaryDirectory() as tmp:
            ex = os.path.join(tmp, "examples")
            os.makedirs(os.path.join(ex, "current", "app"))
            release.write_version_file(os.path.join(ex, "current"), "2.5.0")
            with mock.patch.dict(os.environ, {}, clear=False):
                os.environ.pop(release.EVAL_ROOT_ENV, None)
                with self.assertRaises(SystemExit):
                    release.rotate_examples("2.6.0", ex)
            self.assertTrue(os.path.isdir(os.path.join(ex, "current", "app")))
            self.assertFalse(os.path.exists(os.path.join(ex, "previous")))


if __name__ == "__main__":
    unittest.main()
