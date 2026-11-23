# ADR 0014: The docs-as-code gate is a command, not a workflow script

- **Status:** Accepted (2026-11-23, 2.6.0)
- **Decision area:** Docs-as-code; CI; Check; Release

## Context

Through 2.5 the gate lived in `ci/appdoc-docs-gate.yml` as shell steps: check out the skill into the
workspace (`appdoc-skill/`), extract into a throwaway folder with `--out "$RUNNER_TEMP/appdoc-regen"`,
compare the `schema` fields, `diff` the two `facts.json` files, then run the Check. The shell could not
be tested on both operating systems, and it had three faults. The skill sat inside the workspace, so
the Target it scanned contained the skill. The regeneration wrote to a different folder than the
committed run, so the scans did not see the same files. And the diff compared the whole file,
including the commit and the git history, which differ in a shallow CI clone. The 2.4 examples audit
recorded that the gate could not run on a clean repository.

## Decision

1. **`appdoc gate <target> [--require-audit] [--strict]`** (`appdoc/gate.py`) does the whole job
   and has exit codes a pipeline can act on:
   - `0` the Facts match and the Check passes;
   - `1` tool error (the committed `facts.json` is missing or unreadable);
   - `2` Facts changed (a diff of at most 200 lines is printed), or the Check failed;
   - `3` AppDoc upgraded: the committed Facts schema differs from the running AppDoc's.
2. **Order.** Read the committed `facts.json`; regenerate; compare schema (exit 3) before bytes
   (exit 2); only then run the Check. A version difference in `provenance.json` is printed and
   never fails the gate (ADR 0013). The schema test is equality, not ordering: an older and a newer committed schema are both "AppDoc upgraded" (exit 3), so no version tuple is involved (`template_spec.version_tuple` is for template versions).
3. **The workflow clones the skill to `$RUNNER_TEMP/appdoc-skill`** and runs
   `python "$RUNNER_TEMP/appdoc-skill/run_appdoc.py" gate "$GITHUB_WORKSPACE" --require-audit`. The
   skill is never inside the Target. The command is also correct when it is (a vendored copy is
   pruned as an "AppDoc skill bundle", ADR 0010), and `tests/test_gate.py` pins both.
4. The YAML header and the version pin are generated from code (`tools/gen_docs.py`, P6), and
   AppDoc's own CI runs the gate on a temporary copy of `tests/samples/java-spring`.

## Deviations the implementation made from the plan

The plan (remediation plan 2.6, 6.1) said the gate extracts into a fixed `<target>/.appdoc-regen/`
folder that is excluded from the scan and removed in `finally`, and that the comparison is of the
whole `facts.json`. The implementation differs in two ways, for these reasons.

1. **The gate extracts in memory, with the committed output folder excluded from the scan, instead
   of into `.appdoc-regen`.** The committed run that wrote `facts.json` excluded its own output
   folder (`docs/appdoc/`); the regeneration must exclude the same folder or the two scans see
   different files and the Facts differ on every run. Extracting in memory also writes nothing under
   the Target, so a failed or interrupted gate leaves nothing to clean up and cannot be mistaken for
   code. The gate creates, changes and deletes nothing in the Target (`.appdoc-regen` is not a name
   AppDoc uses or reserves; the Check's own report is the one file the last step may write). The
   cache is never used, so a stale `.appdoc-cache.json` cannot hide a code change.
2. **The comparison ignores `target.commit`, `target.history` and the git `ownership` Facts (`detail.source == "git"`).** A CI
   clone is usually shallow (`actions/checkout` fetches one commit), so history and ownership are
   different there than on the machine that generated the docs; and the docs are committed after
   the commit they describe, so `target.commit` can never match. Comparing them would make the gate
   fail on every run in exactly the setup it is designed for. Ownership remains in `facts.json` for
   readers; it is only neutralised in the comparison, on both sides. (Ownership Facts hold counts
   and dates, never names, since 2.6.0.)

## Consequences

- A changed ownership history cannot trip the gate; a changed source file always does.
- Exit `3` tells an upgrade from a code change, and the message names the remedy.
- The YAML is a thin wrapper; behaviour is tested in Python on both operating systems.
