"""Cut an AppDoc release (remediation plan 2.6, 6.3).

    python tools/release.py X.Y.Z [--dry-run]

Steps: require a clean tree on `main`; set the version in appdoc/__init__.py and rename `## Unreleased` in
CHANGELOG.md; run tools/gen_docs.py (README, SKILL.md and the gate pin follow the version); run the tests, the
determinism job, the extractor eval and the narrative answer-key eval (`APPDOC_EVAL_ROOT` points at the local
clones; a regression refuses the release); rotate the examples; commit and tag `vX.Y.Z`; print the push command;
then a follow-up commit that sets `X.Y.(Z+1).dev0` and opens a new `## Unreleased`. Nothing is pushed.

Preflight, before any edit: `APPDOC_EVAL_ROOT` must hold all four clones of the example repositories, or the run
exits non-zero; `--skip-narrative-eval` is the only bypass, it prints a loud line and the release commit message
records it. Any failure after the first edit restores the tree (tracked files from git; untracked files the script
created are removed; the tree was clean when it started).

`--dry-run` prints those steps and the state of each precondition and changes nothing (it exits 0 even where a
real run would refuse). `--test-only-skip-checks` (accepted only with `--dry-run`) exists for the script's own
test. Stdlib only.
"""

from __future__ import annotations

import argparse
import os
import re
import shutil
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
VERSION_RE = re.compile(r'^(__version__ = ")([^"]+)(")', re.M)
UNRELEASED = "## Unreleased"
EVAL_ROOT_ENV = "APPDOC_EVAL_ROOT"
# The eval scripts that gate a release (extractor answer keys; narrative answer keys). Each exits 1 on a regression.
# The narrative eval needs local clones (APPDOC_EVAL_ROOT); a release run requires them (--require-clones).
EVAL_HOOKS = (("extractor eval", ("extractor_checks.py",)),
              ("narrative eval", ("score.py", "--all", "--require-clones")))


def _git(*args, cwd=None, check=False):
    res = subprocess.run(["git", *args], cwd=cwd or ROOT, capture_output=True, text=True)
    if check and res.returncode != 0:
        raise SystemExit(f"release: git {' '.join(args)} failed: {res.stderr.strip()}")
    return res


def _read(rel):
    with open(os.path.join(ROOT, rel), encoding="utf-8", newline="") as fh:
        return fh.read()


def _write(rel, text):
    with open(os.path.join(ROOT, rel), "w", encoding="utf-8", newline="") as fh:
        fh.write(text)


def next_dev(version: str) -> str:
    if ROOT not in sys.path:
        sys.path.insert(0, ROOT)
    from appdoc.template_spec import version_tuple
    major, minor, patch = version_tuple(version)
    return f"{major}.{minor}.{patch + 1}.dev0"


def set_version(version: str) -> None:
    path = os.path.join("appdoc", "__init__.py")
    text = _read(path)
    new, n = VERSION_RE.subn(lambda m: m.group(1) + version + m.group(3), text, count=1)
    if n != 1:
        raise SystemExit("release: could not find __version__ in appdoc/__init__.py")
    _write(path, new)


def rename_unreleased(version: str) -> None:
    text = _read("CHANGELOG.md")
    if UNRELEASED not in text:
        raise SystemExit(f"release: CHANGELOG.md has no '{UNRELEASED}' heading")
    _write("CHANGELOG.md", text.replace(UNRELEASED, f"## {version}", 1))


def open_unreleased() -> None:
    text = _read("CHANGELOG.md")
    nl = "\r\n" if "\r\n" in text else "\n"
    head = "# Changelog" + nl + nl
    if not text.startswith(head):
        raise SystemExit("release: CHANGELOG.md must start with '# Changelog' and a blank line")
    _write("CHANGELOG.md", head + UNRELEASED + nl + nl + text[len(head):])


def gen_docs() -> None:
    res = subprocess.run([sys.executable, os.path.join(ROOT, "tools", "gen_docs.py")], cwd=ROOT)
    if res.returncode != 0:
        raise SystemExit("release: gen_docs failed")


EXAMPLES = os.path.join(ROOT, "examples")
APPS = ("eShop", "flaskr-tdd", "gitea", "spring-petclinic")
ARTIFACTS = ("application-documentation.md", "application-documentation.html", "check-report.md", "evidence.jsonl",
             "facts.json", "facts-summary.md", "provenance.json")


def _load_module(name, rel):
    import importlib.util
    spec = importlib.util.spec_from_file_location(name, os.path.join(ROOT, rel))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def read_version_file(folder):
    try:
        with open(os.path.join(folder, "VERSION"), encoding="utf-8") as fh:
            return fh.read().strip()
    except OSError:
        return None


def write_version_file(folder, version):
    with open(os.path.join(folder, "VERSION"), "w", encoding="utf-8", newline="\n") as fh:
        fh.write(version + "\n")


def regenerate_example(app, clone, previous_dir, dest, workers=4):
    """Mechanically regenerate one example into `dest` with the running AppDoc (remediation plan 2.6, 7.2.4).

    `clone` is a clean clone at the example's target.commit. The previous Narrative and evidence.jsonl are copied
    in, then extract, fill and build --require-audit run. No new audit is performed.
    """
    import json
    with open(os.path.join(previous_dir, "facts.json"), encoding="utf-8") as fh:
        want = json.load(fh)["target"]["commit"]
    have = _git("rev-parse", "HEAD", cwd=clone).stdout.strip()
    if have != want:
        raise SystemExit(f"release: {app}: the clone is at {have[:12]}, the example targets {want[:12]}")
    out = os.path.join(clone, "docs", "appdoc")
    if os.path.isdir(out):
        shutil.rmtree(out)
    stray = [n for n in _walk_names(clone) if n.lower().startswith("appdoc")]
    if stray:
        raise SystemExit(f"release: {app}: the clone still has AppDoc output: {stray[:3]}")
    os.makedirs(out)
    for name in ("application-documentation.md", "evidence.jsonl"):
        shutil.copy(os.path.join(previous_dir, name), os.path.join(out, name))
    cli = os.path.join(ROOT, "run_appdoc.py")
    for argv in (["extract", clone, "--workers", str(workers)], ["fill", clone],
                 ["build", clone, "--require-audit"]):
        res = subprocess.run([sys.executable, cli, *argv], cwd=ROOT)
        if res.returncode != 0:
            raise SystemExit(f"release: {app}: appdoc {argv[0]} exited {res.returncode}")
    os.makedirs(dest, exist_ok=True)
    for name in ARTIFACTS:
        src = os.path.join(out, name)
        if os.path.isfile(src):
            shutil.copy(src, os.path.join(dest, name))
    shutil.rmtree(out)


def _walk_names(clone):
    for dirpath, dirs, files in os.walk(clone):
        dirs[:] = [d for d in dirs if d != ".git"]
        yield from dirs
        yield from files


def comparison_markdown(version, previous_dir, current_dir, apps=APPS):
    """docs/diagnostic-<version>-comparison.md: the movement between the two example folders."""
    diag = _load_module("appdoc_diag_metrics", os.path.join("tests", "diag_metrics.py"))
    prev_v = read_version_file(previous_dir) or "?"
    cur_v = read_version_file(current_dir) or version
    rows = []
    for app in apps:
        old = (diag.analyze(previous_dir, app), diag.baselines(previous_dir, app))
        new = (diag.analyze(current_dir, app), diag.baselines(current_dir, app))
        rows.append((app, old, new))

    def cfg(narr_dir, app):
        shown, total, unclassified = diag.config_reference(narr_dir, app)
        return (f"{shown} of {total}" if total else "n/a"), (unclassified or "none")

    def pair(get):
        return [f"{get(o)} -> {get(n)}" for _, o, n in rows]

    table = [
        ("Check", pair(lambda x: x[0]["check"])),
        ("Supported %", pair(lambda x: x[0]["pct_supported"])),
        ("Citations with a line %", pair(lambda x: x[0]["pct_cites_with_line"])),
        ("Citations (total)", pair(lambda x: x[0]["citations"])),
        ("Audit rows", pair(lambda x: x[0]["audit_rows"])),
        ("Facts (total)", pair(lambda x: x[0]["facts_total"])),
        ("Retired candidates, name signal only", pair(lambda x: x[1]["retired_name"])),
        ("Retired candidates, content signal", pair(lambda x: x[1]["retired_content"])),
        ("Duplicate-folder pairs", pair(lambda x: x[1]["duplicate_pairs"])),
        ("Capabilities declared", pair(lambda x: len(x[1]["capabilities"]))),
        ("Secret-location config keys", pair(lambda x: x[1]["secret_locations"])),
        ("16.6 application keys shown", [f"{cfg(previous_dir, a)[0]} -> {cfg(current_dir, a)[0]}" for a in apps]),
        ("16.6 keys not classified (keys, files)",
         [f"{cfg(previous_dir, a)[1]} -> {cfg(current_dir, a)[1]}" for a in apps]),
    ]
    lines = [f"# AppDoc v{version} - Comparative Diagnostic", "",
             f"Generated by `tools/release.py` from `examples/previous` ({prev_v}) and `examples/current` ({cur_v}). "
             "Each cell reads `previous -> current`. The Narrative is the previous audited text; only the generated "
             "blocks and the Facts move (no new audit), so Supported % and audit rows are expected to hold.", "",
             "| Metric | " + " | ".join(a for a, _, _ in rows) + " |", "|---|" + "---|" * len(rows)]
    for label, cells in table:
        lines.append(f"| {label} | " + " | ".join(cells) + " |")
    lines.append("")
    return "\n".join(lines)


def write_comparison(version, previous_dir, current_dir, docs_dir=None):
    rel = os.path.join("docs", f"diagnostic-{version}-comparison.md")
    docs_dir = docs_dir or os.path.join(ROOT, "docs")
    os.makedirs(docs_dir, exist_ok=True)
    with open(os.path.join(docs_dir, f"diagnostic-{version}-comparison.md"), "w", encoding="utf-8", newline="\n") as fh:
        fh.write(comparison_markdown(version, previous_dir, current_dir))
    return rel


def rotate_examples(version: str, examples_dir: str | None = None, clones: str | None = None,
                    regenerate=None, docs_dir: str | None = None) -> str:
    """Rotate examples/current to examples/previous and write the new current (remediation plan 2.6, 7.2.2).

    Order: delete previous, move current to previous, write the new current (mechanical regeneration from the
    clones in `clones`, default $APPDOC_EVAL_ROOT), write the VERSION files, generate the comparison document.
    A current already stamped `version` was written for this release (the 2.6.0 migration): nothing is rotated.
    Everything the regeneration needs is checked before anything is moved. Returns a one-line status.
    """
    if ROOT not in sys.path:
        sys.path.insert(0, ROOT)
    from appdoc.template_spec import version_tuple
    base = examples_dir or EXAMPLES
    regenerate = regenerate or regenerate_example
    cur, prev = os.path.join(base, "current"), os.path.join(base, "previous")
    cur_v = read_version_file(cur)
    if cur_v is None:
        raise SystemExit(f"release: {cur} has no VERSION file; the examples are not in the current/previous layout")
    if cur_v == version:
        if os.path.isdir(prev):
            write_comparison(version, prev, cur, docs_dir)
        return f"examples already at {version}; not rotated"
    if version_tuple(cur_v) >= version_tuple(version):
        raise SystemExit(f"release: examples/current is {cur_v}, which is not older than {version}")
    clones = clones or os.environ.get(EVAL_ROOT_ENV)
    if not clones:
        raise SystemExit(f"release: rotating the examples regenerates them from clean clones; set {EVAL_ROOT_ENV}")
    apps = [a for a in sorted(os.listdir(cur)) if os.path.isdir(os.path.join(cur, a))]
    missing = [a for a in apps if not os.path.isdir(os.path.join(clones, a))]
    if missing:
        raise SystemExit(f"release: no clean clone under {clones} for: {', '.join(missing)}")
    staging = os.path.join(base, ".current-new")
    shutil.rmtree(staging, ignore_errors=True)
    for app in apps:
        regenerate(app, os.path.join(clones, app), os.path.join(cur, app), os.path.join(staging, app))
    shutil.rmtree(prev, ignore_errors=True)
    shutil.move(cur, prev)
    shutil.move(staging, cur)
    for app in apps:
        write_version_file(os.path.join(cur, app), version)
    write_version_file(cur, version)
    write_comparison(version, prev, cur, docs_dir)
    return f"examples rotated: previous {cur_v}, current {version}"


def _run(label, argv):
    print(f"release: {label}: {' '.join(argv)}", flush=True)
    return subprocess.run(argv, cwd=ROOT).returncode == 0


def run_checks(skip_narrative_eval: bool = False) -> bool:
    ok = _run("run tests", [sys.executable, "-m", "unittest", "discover", "-s", "tests", "-t", "."])
    ok = ok and _run("determinism", [sys.executable, "-m", "unittest", "tests.test_determinism"])
    root = os.environ.get(EVAL_ROOT_ENV)
    for label, (script, *extra) in EVAL_HOOKS:
        if skip_narrative_eval and script == "score.py":
            print(f"release: {label}: SKIPPED (--skip-narrative-eval)", flush=True)
            continue
        argv = [sys.executable, os.path.join(ROOT, "eval", script), *extra]
        if root and script == "score.py":
            argv += ["--root", root]
        ok = _run(label, argv) and ok
    return ok


def steps(version: str) -> list[str]:
    return [
        f"set version {version} in appdoc/__init__.py",
        f"rename '{UNRELEASED}' to '## {version}' in CHANGELOG.md",
        "gen_docs: python tools/gen_docs.py (README, SKILL.md, gate YAML header and pin)",
        "run tests: python -m unittest discover -s tests -t .",
        "determinism job: python -m unittest tests.test_determinism",
        "extractor eval: python eval/extractor_checks.py (a regression refuses the release)",
        f"narrative eval: python eval/score.py --all --require-clones ({EVAL_ROOT_ENV} must hold the four clones, checked "
        "before any edit; a regression or a missing clone refuses the release; --skip-narrative-eval bypasses it loudly)",
        "rotate examples: delete previous, move current to previous, regenerate current from the clones, VERSION files, "
        "docs/diagnostic-<version>-comparison.md (nothing is rotated when current is already stamped with the version)",
        f"git commit -m 'AppDoc {version}'",
        f"git tag -a v{version} -m 'AppDoc {version}'",
        f"print: git push origin main v{version}",
        f"follow-up commit: set version {next_dev(version)} and open '{UNRELEASED}' in CHANGELOG.md",
    ]


def preconditions(version: str) -> list[str]:
    """What a real run would refuse on; empty when it may go ahead."""
    problems = []
    branch = _git("rev-parse", "--abbrev-ref", "HEAD").stdout.strip()
    if branch != "main":
        problems.append(f"the branch is '{branch}'; releases are cut from main")
    if _git("status", "--porcelain").stdout.strip():
        problems.append("the working tree is not clean; commit or stash first")
    if _git("rev-parse", "-q", "--verify", f"refs/tags/v{version}").returncode == 0:
        problems.append(f"the tag v{version} already exists")
    if UNRELEASED not in _read("CHANGELOG.md"):
        problems.append(f"CHANGELOG.md has no '{UNRELEASED}' heading")
    return problems


def clone_problems(clones=None, apps=APPS) -> list[str]:
    """Why the four example clones cannot be used ([] when $APPDOC_EVAL_ROOT resolves all of them)."""
    root = clones or os.environ.get(EVAL_ROOT_ENV)
    if not root:
        return [f"{EVAL_ROOT_ENV} is not set; point it at the folder holding clones of {', '.join(apps)}"]
    missing = [a for a in apps if not os.path.isdir(os.path.join(root, a))]
    return [f"{EVAL_ROOT_ENV}={root} has no clone of: {', '.join(missing)}"] if missing else []


def _restore() -> None:
    """Undo every edit of a failed run. The tree was clean when it started, so what git reports as modified,
    deleted or untracked now is the script's."""
    _git("checkout", "--", ".")
    _git("clean", "-fdq")


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description="Cut an AppDoc release.")
    ap.add_argument("version", help="the release version, X.Y.Z")
    ap.add_argument("--dry-run", action="store_true", help="print the steps and change nothing")
    ap.add_argument("--skip-narrative-eval", action="store_true",
                    help="release without the narrative answer-key eval; prints a loud line and is recorded in the commit")
    ap.add_argument("--test-only-skip-checks", action="store_true",
                    help="for the script's own test; accepted only with --dry-run")
    args = ap.parse_args(argv)
    if args.test_only_skip_checks and not args.dry_run:
        ap.error("--test-only-skip-checks is accepted only with --dry-run")
    version = args.version
    if not re.fullmatch(r"\d+\.\d+\.\d+", version):
        print(f"release: '{version}' is not a release version (X.Y.Z, no 'v' prefix, no .dev)", file=sys.stderr)
        return 2
    problems = preconditions(version)

    if args.dry_run:
        print(f"release: dry run for {version}; nothing is changed")
        for p in problems:
            print(f"release: a real run would refuse: {p}")
        for n, step in enumerate(steps(version), 1):
            print(f"  {n}. {step}")
        return 0

    if problems:
        for p in problems:
            print(f"release: {p}", file=sys.stderr)
        return 1
    skip_eval = args.skip_narrative_eval
    rotation_needed = read_version_file(os.path.join(EXAMPLES, "current")) != version
    if not skip_eval or rotation_needed:
        unusable = clone_problems()
        if unusable:
            for p in unusable:
                print(f"release: {p}" + ("" if not skip_eval else " (the example rotation needs them too)"),
                      file=sys.stderr)
            if not skip_eval:
                print("release: nothing was changed. --skip-narrative-eval is the only bypass.", file=sys.stderr)
            return 1
    if skip_eval:
        print("release: WARNING: the NARRATIVE EVAL IS SKIPPED (--skip-narrative-eval); the release commit says so",
              file=sys.stderr)
    try:
        return _release(version, skip_eval)
    except BaseException as exc:
        _restore()
        if isinstance(exc, SystemExit):
            print(f"{exc.code}" if not isinstance(exc.code, int) else "", end="", file=sys.stderr)
            print("\nrelease: failed; the tree was restored, nothing was committed after the failing step.", file=sys.stderr)
            return exc.code if isinstance(exc.code, int) and exc.code else 1
        print(f"release: failed with {type(exc).__name__}: {exc}; the tree was restored.", file=sys.stderr)
        raise


def _release(version: str, skip_eval: bool) -> int:
    set_version(version)
    rename_unreleased(version)
    gen_docs()
    if not run_checks(skip_eval):
        print("release: the checks failed or regressed; the version change was reverted, nothing was committed",
              file=sys.stderr)
        raise SystemExit(1)
    print("release: " + rotate_examples(version))
    _git("add", "-A", check=True)
    message = f"AppDoc {version}"
    if skip_eval:
        message += "\n\nNarrative eval skipped (--skip-narrative-eval); the narrative answer keys were not scored."
    _git("commit", "-q", "-m", message, check=True)
    _git("tag", "-a", f"v{version}", "-m", f"AppDoc {version}", check=True)
    print(f"release: tagged v{version}. Push with:\n  git push origin main v{version}")
    nxt = next_dev(version)
    set_version(nxt)
    open_unreleased()
    gen_docs()
    _git("add", "-A", check=True)
    _git("commit", "-q", "-m", f"Start {nxt}", check=True)
    print(f"release: now at {nxt}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
