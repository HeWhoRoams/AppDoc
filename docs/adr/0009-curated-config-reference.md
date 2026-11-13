# ADR 0009: A curated, generated configuration reference that never records values

- **Status:** Accepted (2026-11-11)
- **Decision area:** Facts; Template; Generated blocks

## Context

The 2.2 `config-reference` block listed every `config_key` Fact. On gitea that was about 9,000 rows,
nearly all commented defaults in a sample `app.ini`, which no reader can use. On flaskr it listed
`USERNAME` as "defined at" a read site and omitted `SECRET_KEY`, which the app loads from a module
constant with `from_object`. Reviewers asked for a "Default" column; the extractor deliberately
never records values, because detecting which values are secrets is heuristic.

## Decision

1. No config value is ever recorded in Facts or in the block. The reference names keys and
   locations only.
2. **Define first.** Each `config_key` Fact has `use` = `define` (the file or code that sets it) or
   `read` (code that consumes it). A key is listed at its first definition; it falls back to its
   first read only when no definition exists. Flask `from_object` modules and `app.config[...] =`
   assignments count as definitions.
3. Only application-role keys outside test code are listed. Build, CI and orchestration keys are
   excluded as in 2.2.
4. **Commented defaults are counted, not listed.** The trailer says how many there are and where
   (`Shown N of M application keys; K commented defaults in <files> are not listed (see
   facts.json)`).
5. **Order and cap.** Secret locations first, then by path and line; at most 150 rows. The "N of M
   shown" figures are computed by `fill`, never written by hand.
6. Effects of keys that matter are written by hand in an optional `Key | Effect | Evidence` table
   below the block. C10 requires each Key cell to name a `config_key` Fact, so the table cannot
   describe a key that does not exist.

## Consequences

- The block is a map of where to look, not a description of what each key does or its default.
  The hand table and the writer's reading carry that.
- A key defined only in an unscanned folder or an extensionless file shows up as a read, or not at
  all. The 2.1 block lists pruned folders.
- Truncation is visible: a reader sees that rows are missing and by how many.
