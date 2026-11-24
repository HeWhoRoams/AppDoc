# ADR 0013: A provenance sidecar, kept out of the Facts

- **Status:** Accepted (2026-11-23, 2.6.0)
- **Decision area:** Facts; Generated blocks; Check; Release

## Context

Through 2.5 `facts.json` carried a `generator` field with the AppDoc version. Any AppDoc release,
including a patch that changed no Fact, therefore changed `facts.json`, and the docs-as-code gate
read that change as the Target's code having changed. One version string also stood for two
different things: the AppDoc that wrote the Facts and the AppDoc that wrote the generated blocks
and ran the Check. The 2.4 examples audit found documents whose generated blocks came from a newer
AppDoc than the audit they sat beside. Principle P5 (ADR 0016) says provenance is separate and
printed, and that `facts.json` is a pure function of the Target.

## Decision

1. **`docs/appdoc/provenance.json`** is written by `extract` as `{"generator", "bundle", "schema"}`:
   the AppDoc version, a 12-hex hash of the `appdoc/` package files (CRLF read as LF, bytecode
   skipped, so it is equal on Windows and Linux), and the Facts schema. It holds no timestamp, path
   or other ambient value, so two runs of the same build give the same bytes.
2. **`facts.json` drops `generator`.** It keeps `schema`. An AppDoc patch that changes no Fact
   changes no `facts.json`.
3. **`fill` adds `blocks_by`** (`generator`, `bundle`) to the sidecar: the AppDoc that wrote the
   generated blocks. Appendix A.1 prints `Generated blocks written by AppDoc X (bundle B).` When the
   register's audit record carries `audited_with` and its major.minor differs, A.1 adds that the
   blocks were regenerated after the audit and are not covered by it. Both lines are generated
   content.
4. **One implementation.** `appdoc/version.py` owns `__version__`, `bundle_hash()` and
   `provenance()`; nothing else computes them. The cache salt is the bundle hash, so no hand-bumped
   extractor version exists.
5. **The Check reads it.** The scope line prints `Run by AppDoc X (bundle B)`. C7 version skew reads
   the sidecar, and a missing sidecar is an advisory. A sidecar whose `schema` disagrees with
   `facts.json` fails C7. A version difference by itself never fails anything.
6. **The gate treats it as information.** `appdoc gate` prints a version difference and carries on
   (ADR 0014).

## Consequences

- Upgrading AppDoc by a patch release does not trip the gate; only a schema change does (exit 3).
- Readers can tell which AppDoc produced the Facts, the blocks and the audit, and see when the
  audit predates the blocks.
- The sidecar is a second committed file in `docs/appdoc/`. Deleting it loses the printed
  provenance and raises the C7 advisory, but the Facts stay valid.
