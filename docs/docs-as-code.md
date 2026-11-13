# AppDoc docs-as-code

Keep the generated AppDoc documentation in lockstep with the code: when the code
changes, the docs must be refreshed and committed before the change can land.

This is a two-layer design. The **deterministic gate** runs in CI and can be
enforced on every merge; the **Narrative refresh** is AI-in-the-loop and runs in a
session. The split exists because AppDoc deliberately holds no API key, no
provider, and makes no network LLM call — so the AI-written Narrative cannot be
regenerated inside CI.

## The two layers

### Layer 1 — the deterministic gate (CI)

`ci/appdoc-docs-gate.yml` is the gate. Copy it into the target repository at
`.github/workflows/appdoc-docs-gate.yml`. On every push to `main` and every pull
request it does three things, all deterministic:

1. **Upgrade detection.** If the committed `facts.json` was written with a different
   Facts schema than the pinned AppDoc (`APPDOC_REF`) writes (for example `appdoc-facts/3`
   committed, `appdoc-facts/4` written by v2.3.0), AppDoc was upgraded. The
   gate says so, instead of reporting a code change.
2. **Change detection.** Regenerates the Facts (byte-identical across runs) into a
   throwaway directory and diffs them against the committed `docs/appdoc/facts.json`.
   If they differ, the code changed since the docs were last generated, so the gate
   fails with a clear instruction to refresh.
3. **Consistency (C1–C12).** Runs the AppDoc Check with `--require-audit` against the committed docs.
   Broken Citations or references, tables that do not match the template, stale
   generated blocks, secret-shaped text, a finding candidate that is neither cited nor
   dismissed, or an Evidence Register row whose anchor is no longer in its cited lines
   fail the gate. That last failure names exactly which audited claims a code change
   made stale, so a refresh can start there. `--require-audit` also fails when the
   audit was declared not performed.

The gate proves the committed docs are *consistent with the current code*. It does
not rewrite the Narrative and it does not run the source-to-claim audit.

### Layer 2 — the Narrative refresh (AI-in-the-loop)

When the gate trips (or after any meaningful code change), refresh the docs in a
session:

1. Re-run the AppDoc skill against the target on a scratch copy.
2. The AI rewrites the Narrative sections from the fresh Facts, carrying forward
   still-valid owner context and updating what changed. `appdoc fill` rewrites the
   generated blocks.
3. Run the source-to-claim audit: write `docs/appdoc/evidence.jsonl`, including a row for
   each finding candidate and each answerable open question, then run `fill` again so
   Appendix A carries the register.
4. Run the Check (must be a clean PASS), then render.
5. Commit the updated `docs/appdoc/` files. The gate then passes.

## Setting it up on a target

1. Generate the docs once, in a session, and commit `docs/appdoc/` to the target repo.
   At minimum `facts.json`, `application-documentation.md` and `evidence.jsonl`;
   `check-report.md` and the rendered HTML are recommended.
2. Copy `ci/appdoc-docs-gate.yml` to the target's `.github/workflows/` and set
   `APPDOC_REF` to the AppDoc release you used (this document describes `v2.3.0`).
3. Verify the gate passes on the current tree (it should, since the docs were just
   generated). The gate runs `check --require-audit`, so the audit must have been done.
4. From then on, any code change that alters the Facts fails the gate until the docs
   are refreshed in a session and committed.

## What the gate intentionally does not do

- **Does not regenerate the Narrative.** That is the AI's job, in a session. The gate
  only tells you *when* the refresh is due.
- **Does not run the source-to-claim audit.** That is an AI accuracy pass (step 5 of
  the skill workflow). The gate requires the audit to have been performed
  (`check --require-audit` fails when `evidence.jsonl` declares it not performed) and
  re-checks every anchor against the current code. Whether a cited line supports its
  claim stays with the auditor.
- **Does not fail on uncited entry points by default.** `check` lists them as an
  advisory. Add `--strict` to the check step in the workflow to fail on any.
- **Does not require the rendered HTML.** It is recommended but its absence is not a
  gate failure.

## Why this split

The deterministic layer is cheap, fast, reproducible, and safe to run on every commit —
it needs no secrets and no network. The Narrative layer is where judgment lives (what
changed, what is still valid, what to say), and it belongs with a person and an AI
looking at the diff together. Putting the tripwire in CI means the documentation debt
is visible at merge time, not discovered months later by someone who just picked up
the codebase.
