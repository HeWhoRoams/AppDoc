# ADR 0005: Generated blocks — Narrative content written from the Facts, not by hand

- **Status:** Accepted (2026-11-11)
- **Decision area:** Template; Narrative; Facts; Check

## Context

The 2.1 examples carried hand-counted numbers that drifted from the Facts: file counts per folder
(gitea `modules/` 1288 on disk vs 1220 in Facts, unexplained), "N claims audited" lines that
disagreed with the table under them, and configuration lists that were never surfaced at all.
An AI asked to restate a number the scripts already know will sometimes get it wrong, and nothing
noticed.

## Decision

1. A **Generated block** is the text between `<!-- appdoc:generated NAME -->` and
   `<!-- /appdoc:generated NAME -->` in the Narrative. `appdoc fill <target>` rewrites it from
   `facts.json`. It is idempotent.
2. 2.2 ships two blocks: `scan-coverage` in 2.1 (Stacks, files found = scanned + pruned + ignored,
   top folders, folders not scanned) and `config-reference` in 16.6 (application config keys,
   where defined, secret location; never values).
3. The Check (C7) fails when a block is missing or differs from what `fill` would write. The AI
   never edits a block; it writes judgment around it (what was not read; the effect of keys a
   workflow depends on).
4. Hand-written counts that remain (4.1 Files) are compared with the Facts by C7.

## Consequences

- A code change that alters the Facts makes the blocks stale; CI can refresh them mechanically
  without an AI session.
- New blocks need a renderer in `appdoc/fill.py` and an entry in `template_spec.GENERATED`.
