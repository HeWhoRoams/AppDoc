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
request it does two things, both deterministic:

1. **Change detection.** Regenerates the Facts (byte-identical across runs) into a
   throwaway directory and diffs them against the committed `docs/appdoc/facts.json`.
   If they differ, the code changed since the docs were last generated, so the gate
   fails with a clear instruction to refresh.
2. **Consistency (C1–C7).** Runs the AppDoc Check against the committed docs.
   Broken Citations, empty or placeholder sections, secret-shaped text, or an
   unlisted unsupported stack fail the gate.

The gate proves the committed docs are *consistent with the current code*. It does
not rewrite anything and it does not run the source-to-claim audit.

### Layer 2 — the Narrative refresh (AI-in-the-loop)

When the gate trips (or after any meaningful code change), refresh the docs in a
session:

1. Re-run the AppDoc skill against the target on a scratch copy.
2. The AI rewrites the Narrative sections from the fresh Facts, carrying forward
   still-valid owner context and updating what changed.
3. Run the source-to-claim audit and write `docs/appdoc/verification.md`.
4. Run the Check (must be a clean PASS), then render.
5. Commit the updated `docs/appdoc/` files. The gate then passes.

## Setting it up on a target

1. Generate the docs once, in a session, and commit `docs/appdoc/` to the target repo.
   At minimum `facts.json` and `application-documentation.md`; `check-report.md` and
   the rendered HTML are recommended.
2. Copy `ci/appdoc-docs-gate.yml` to the target's `.github/workflows/`.
3. Verify the gate passes on the current tree (it should, since the docs were just
   generated).
4. From then on, any code change that alters the Facts fails the gate until the docs
   are refreshed in a session and committed.

## What the gate intentionally does not do

- **Does not regenerate the Narrative.** That is the AI's job, in a session. The gate
  only tells you *when* the refresh is due.
- **Does not run the source-to-claim audit.** That is an AI accuracy pass (Step 4 of
  the skill workflow) and is recorded in `verification.md`. A missing
  `verification.md` is a noted gap in the check report, never a gate failure.
- **Does not require the rendered HTML or `verification.md` to be present.** Those are
  recommended for completeness but their absence is not a gate failure.

## Why this split

The deterministic layer is cheap, fast, reproducible, and safe to run on every commit —
it needs no secrets and no network. The Narrative layer is where judgment lives (what
changed, what is still valid, what to say), and it belongs with a person and an AI
looking at the diff together. Putting the tripwire in CI means the documentation debt
is visible at merge time, not discovered months later by someone who just picked up
the codebase.
