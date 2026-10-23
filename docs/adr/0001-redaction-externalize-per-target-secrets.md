# ADR 0001: AppDoc ships shape-patterns only; per-target secrets are operator-supplied

- **Status:** Accepted (2026-10-21)
- **Decision area:** Redaction / secret handling; reusable-tool boundary; docs-as-code

## Context

AppDoc is a **reusable** documentation-generation tool (an AI skill/workflow). A specific
application is a **test target** it is run against, not part of the tool.

Two independent code paths hardcoded the test target's three live credential *values* as a
fail-closed "known secrets" backstop:

- `AppDoc.SemanticRedaction.psm1` — `$script:AppDocKnownSecrets` (enrichment path; the gate
  merges it additively with operator-supplied values).
- `AppDoc.SourceDocs.psm1` — a separate local `$knownSecrets` array (deterministic source-docs
  path; an independent duplicate that did not read the semantic module).

Committing those values into the AppDoc repo would bake one test target's live credentials into a
reusable tool's git history — a category error (test-target data leaking into tool source) and a
standing exposure, independent of the fact that the values already live in the target's own config.

The redaction engine's *shape* patterns (base64 / high-entropy / named-key / URI-credential) and the
per-target operator channel (`-RedactionPatterns` CLI param and the target's `.appdoc/config.json`
`redactionPatterns` key) already existed. The operator channel is the designed per-target backstop.

## Decision

1. **The tool ships shape-patterns only.** Both hardcoded copies are removed; the built-in list
   defaults to empty. A reusable tool carries no specific target's live secret values in committed
   source.
2. **Per-target live values are operator-supplied** through the existing channel. For a given target
   run, the operator supplies its known secret values (CLI `-RedactionPatterns`, or the target's
   `.appdoc/config.json`), or relies on shape/key-name redaction when the value is long or sits under
   a credential-shaped key.
3. **The deterministic source-docs path was wired to that same channel** (`Get-AppDocSourceDocsRedacted`
   gained an additive, deduped operator merge) so it no longer needs a hardcoded copy.
4. **The generated docs *highlight* a secret's presence (key name + location) but never document its
   value** — value renders as `[REDACTED]`, key is retained. This is the desired behavior and is
   preserved.

## Consequences

- **Positive:** no live credential value lives in AppDoc source; per-target secrets are a deliberate
  operator act, not autonomous ingestion. The fail-closed gate still fires (verified on the 18-proof
  harness, which uses its own fixture secrets via the operator channel).
- **Trade-off accepted:** a *short, shape-ambiguous* secret under a *non-credential key name* is no
  longer caught by a built-in backstop — it is caught only if the operator supplies it (or its key is
  credential-shaped). By design, not a bug.
- **Not changed:** shape-pattern arrays, the single-source URI-cred array, the two-file endpoint-regex
  invariant, the quarantine harness.
- **Behavior-preservation verified:** 132/132 goldens, 18-proof harness green, committed baselines
  89/97, and the live end-to-end build (scratch-dotnet-restapi) still gate-passes at 94 with all three
  of its real secrets 0-leak (redacted by shape/key-name, not the emptied list).

## Related / follow-ups

- **Gitignore-aware enumeration (follow-up):** AppDoc's file scope is a **static regex policy**
  (`AppDoc.Scope.psm1` / `policies/scope.v1.json`), not `.gitignore` consultation. Common dirs
  (`node_modules/`, `bin/`, `obj/`, `docs/`, `.appdoc/`) are excluded, but a file gitignored *for a
  reason outside those patterns* (e.g. a custom `*.pem` rule) is still scanned. Making enumeration
  `.gitignore`-aware would more fully realize the "avoid autonomously ingesting gitignored/sensitive
  material where possible" principle.
- **`.env` handling (already correct):** `.env` / `.env.*` are read-and-redacted (desired); the
  only verbatim values documented are non-sensitive keys (host/url/username), never known secret
  values. The LLM stage is fail-closed against a surviving secret.
- **Docs-as-code (direction, see ADR 0002):** `docs/` is the stable, non-wiped, committed home for
  generated documentation; a commit hook that regenerates docs is the long-term sync mechanism.

## Amendment (2026-10-22): literal values and regexes are separate keys

`redactionPatterns` was documented as "exact values / regexes" but every consumer escaped it, so a
regex never matched. It now means **exact values only** (unchanged behaviour for existing configs),
and a new `redactionRegexes` key carries regular expressions. Both are compiled in one place
(`AppDoc.SecretPolicy.psm1`), applied by the final sweep and the source-docs path, and scanned for by
the semantic gate. An invalid regex or an unparseable `config.json` stops the build instead of
silently running without the operator's redaction (fail-closed). The credential key-name vocabulary
the extractors, the gate and the docs remediator use also lives in that module, so the lists cannot
drift apart.

## Amendment (2026-10-22): no target-specific narrative in the tool

The same principle covers narrative, not only secrets. The composer previously carried one target's
operator workflows, role descriptions, glossary and benchmark name, and emitted them (tagged
`Verified`) for every Classic ASP target; the security/extcalls generators also passed one target's
`@@…@@` placeholder prefix through redaction. All of that is removed. The section is now the generic
**Operational Workflows**, built only from entry-point evidence and documented procedure contracts.
Target-specific narrative is supplied by the target as an **overlay** (rendered `Operator-supplied`),
and a target's placeholder convention is declared with `opaqueTokenPattern`. See
`references/config-schema.md`.
