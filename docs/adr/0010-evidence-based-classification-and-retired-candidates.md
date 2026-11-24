# ADR 0010: Evidence-based classification and retired candidates

- **Status:** Accepted (2026-11-13)
- **Decision area:** Facts; Scan; Generated blocks; Check

## Context

2.2 moved pruning to evidence (`prune_rule`) because name-based pruning dropped gitea's `packages/`
and `build/`. But the same permissive default survived in two places. `config_role` returned `app`
for anything it did not recognise, so every unknown file was asserted to be application
configuration — `desktop.ini`, `crowdin.yml` and a lone `ClientRes.properties` all read as app
config. And the scan still pruned `vendor`, `_private` and `To be deleted` by name, learned from the
sample Targets; `_private` is where FrontPage-era Classic ASP sites keep live includes, and the
match was case-sensitive, so `OLD_site/` and `To Be Deleted/` on the next Target were not covered.
A name people choose must raise a question, never drive a behaviour.

## Decision

1. **Config role defaults to `unclassified`.** `config_role` returns `app` only on positive
   evidence: a framework-defined name (a closed set per framework — `application*.properties|yml`,
   `appsettings*.json`, `web.config`, `app.config`, `.env*`, `local.settings.json`, and the
   `config`/`settings` JSON names), or a post-pass in `extract.py` that promotes a file whose key
   name matches a `config_key` Fact with `use="read"` from code. Message bundles (a
   `.properties`/`.yml` file with a locale sibling) are role `None`. The config-reference trailer
   counts what was not classified: "K keys in F files were not classified as application
   configuration: … (see facts.json)". Nothing is asserted to be app config without evidence, and
   nothing disappears.
2. **OS and authoring metadata is dropped under a named rule.** Files `desktop.ini`, `Thumbs.db`,
   `.DS_Store` and folders with the `_vti_` prefix (a closed set) are dropped in `scan.walk` and
   counted in scan coverage ("OS and authoring metadata: N files"). `_private`, `vendor` and
   anything named by a person are not touched.
3. **Retired code is a recorded decision, not a prune.** No folder is pruned because of its name.
   `scan` records `target.scan.retired_candidates`: a folder qualifies by **name** (its name,
   case-folded and split on non-alphanumerics, contains a whole token from a closed set — `old`,
   `bak`, `backup`, `archive`, `archived`, `deprecated`, `retired`, `obsolete`, `unused`, `copy`,
   `trash`, `deleteme` — or reads "to be deleted") or by **content** (at least five files, at least
   half byte-identical to a file outside the folder). Each entry carries path, signal and file
   count.
4. **The candidate raises a question.** `scan-coverage` renders "Folders that look retired (not
   excluded)"; `entry-points` states its headline both ways ("N route handler files (K under
   folders that look retired)"). While a candidate is present, C7 requires section 2.1 to name it,
   so the writer records the decision: documented as live, or excluded. Exclusion is the owner's
   act — add the folder to `.appdocignore` and re-extract.

## Consequences

- The default change alters what 16.6 lists on every Target; the per-Target diff (every file that
  leaves role `app`, with the reason) is reviewed before merge.
- A name people choose triggers a question, never a behaviour; a closed set (an OS or tool
  specification) may drive one.
- A retired candidate is not evidence that the code is dead. The writer reads it and decides.

## Amendment (2026-11-23, 2.6.0): duplicate folders and AppDoc-artifact pruning

1. **Retired candidates are by name only.** The content signal in decision 3 ("at least five files,
   at least half byte-identical to a file outside the folder") flagged folders whose
   names gave no sign of being retired, so `retired_candidates` mixed two different claims. The content test moves
   to its own list, `target.scan.duplicate_folders` (`{a, b, files}`), rendered as "Folders that
   duplicate another folder (not excluded; say in 2.1 which copy is live)". A folder `a` with at
   least five non-test files pairs with the folder `b` holding most of its matches when at least half
   of its files match. Ties go to the smallest path; a pair is stored once with `a < b`; the list is
   sorted; nested entries are collapsed in both lists; each list renders at most ten. Test paths
   (`facts.is_test_path`) are ignored. C7 requires 2.1 to name each retired-by-name candidate and
   reports an unnamed duplicate pair as an advisory, which fails under `--strict`. The entry-points
   headline counts name candidates only. One streaming SHA-1 per scanned file builds the index
   (oversize and binary files are never read).
2. **Pruning of AppDoc's own artifacts, by evidence.** A folder is pruned, rule `AppDoc output`,
   when the first 4 KiB of its `facts.json` contain `"schema": "appdoc-facts/` or of its
   `application-documentation.md` contain `<!-- appdoc:template `; and, rule `AppDoc skill bundle`,
   when it holds `run_appdoc.py` and `appdoc/assets/template.md`. Without this, a prior run's output
   or a vendored skill was scanned as the Target and its own Facts, routes and secrets-shaped test
   strings entered the new Facts. Both are recorded in `target.scan.pruned`, disclosed in 2.1, and
   re-included by `!name` in `.appdocignore`. A plain `docs/` folder is not pruned; the evidence is
   the file's own content, never a name.

