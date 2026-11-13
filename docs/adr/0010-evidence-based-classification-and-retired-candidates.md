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
