# ADR 0002: Generated documentation is treated as code — committed to a stable, non-wiped home

- **Status:** Accepted (2026-10-21)
- **Decision area:** Docs-as-code; repository layout; sync/regeneration

## Context

AppDoc generates a 20-section benchmark documentation set. A prior build design wiped and
regenerated the target's `docs/` from scratch each run, so generated docs were treated as
ephemeral build output.

That framing is wrong for this workflow: the generated documentation is a **living artifact** that
should carry the same lifecycle as code — versioned, reviewed, and kept in sync with the source it
describes.

## Decision

1. **Generated documentation is treated as code.** It gets a stable home in the repository and is
   committed.
2. **The home is `docs/`.** It is **not build-wiped** by the current pipeline (a build creates it
   only if absent and overwrites generated artifacts in place — `run-all-generators.ps1`). It is
   already tracked in git (not gitignored), so it is the natural docs-as-code location.
3. **Hand-authored docs and generated docs coexist in `docs/`.** Hand-authored material (ADRs, the
   glossary, plans) lives in `docs/` alongside generated artifacts; a build preserves hand-authored
   files but appends/refreshes a `## Provenance` footer on every `docs/**/*.md` and `.json` in place
   (`Set-AppDocRootProvenance`). Hand-authored files must therefore be tolerant of that footer, or
   placed where it is acceptable.
4. **The sync mechanism is a commit hook (long-term).** A hook invokes the AppDoc skill on code
   change to regenerate the documentation and commit the diff, keeping docs in lockstep with the code.
   This is the design intent; the hook itself is a follow-up workstream, not built in this change.

## Consequences

- **Positive:** generated docs become reviewable, diffable, and auditable like code; provenance is
  stamped on every artifact.
- **Caveat to manage:** the provenance footer is appended to *all* `docs/**/*.md`, including
  hand-authored ones. If strict separation is required, the one in-`docs/` subfolder a build does
  not touch is one no generator writes (e.g. `docs/adr/`).
- **Follow-up workstream:** implement the commit-hook regeneration (skill invocation on commit), and
  decide the exact trigger (pre-commit vs post-commit CI).

## Related

- ADR 0001 — redaction externalization (the security boundary this docs-as-code artifact must honor:
  committed docs never contain a secret's *value*).

## Amendment (2026-10-22): which files get a footer

The build now stamps the `## Provenance` footer as its last Markdown step, recursively over
`docs/**`, so every generated file (including `diagrams/` and `evidence/` summaries, and the
composed master after its second pass) carries exactly one footer as its final section. Hand-authored
files are left untouched: everything under `docs/adr/`, and any file containing the line
`<!-- appdoc:hand-authored -->`. Generated files are written as UTF-8 without BOM with LF line
endings, matching `.gitattributes`. (Implementation: `AppDoc.Provenance.psm1`; test:
`Provenance.Footer.Tests.ps1`.)
