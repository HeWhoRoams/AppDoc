# ADR 0006: A Template spec the Check reads, and what the Check may verify

- **Status:** Accepted (2026-11-11)
- **Decision area:** Template; Check

## Context

2.1 fixed most gaps found by the reference comparison with template comments and SKILL.md
sentences. After regeneration the same classes of gap re-emerged: no Severity on findings, open
questions as a flat list, recommendations that skipped controls, runbooks without rollback, a
malformed glossary row, a cross-reference to a heading that did not exist. All of these are
structural and machine-detectable. The Check hard-coded section names and numbers, so each new
rule would have meant another ad hoc parser.

## Decision

1. `appdoc/template_spec.py` is the single description of the Narrative: sections, required
   subsections, and for each table its columns, ID prefix, allowed values and required rows.
   `check.py` reads it; a test asserts `assets/template.md` agrees with it.
2. The Narrative carries a version stamp (`<!-- appdoc:template 2.2 -->`). A missing or older
   stamp is one C3 problem pointing at the upgrade notes, and the structure rules (C8–C11) are
   not run, so an old document gets one clear message instead of a wall of failures.
3. Every template guidance comment starts `appdoc:guide`; one left in a finished document fails C9.
4. The Check may verify **structure** (headings, table shape, allowed values), **references**
   (IDs defined once and resolved; anchors; findings and non-present controls addressed; every
   connection and call explained in 8.5), **numbers against the Facts** (C7), and **anchors** in
   the Evidence Register (ADR 0007). It never judges meaning: whether a sentence follows from its
   evidence stays with the source-to-claim audit.
5. Cross-references are checked through explicit IDs and Markdown anchors only, never by matching
   prose such as "section 4.3", which would false-fail on text like "RFC 7231 section 4.3".

## Consequences

- A change to a table is one edit in the spec and one in the template, plus a version bump when
  committed documents would stop passing.
- The Check verifies that a reference exists, not that it points at the right thing.

## Amendment (2026-11-13): C2 judges the claim, and C1 refuses a line into a binary file

The 2.3 rule "every Citation in section 10 has a line" could only be met by inventing a line: a
dotfile or a data file has no meaningful line, so the auditor wrote `:1` into a binary SQLite file.
The rule now judges the claim, not the span.

1. **C2 is per-claim.** Each security claim in section 10 must carry at least one lined Citation:
   every 10.1 row's Evidence cell, every 10.2 row whose status is `Present`, and every other block
   in section 10 that holds a Citation. A bare mention (no line) is still a resolved Citation — C1
   proves the file exists — but does not satisfy C2. The message names the fix: "cite the exact
   line, e.g. `path:12` (dotfiles and data files take a line too: `.gitignore:5`)".
2. **C1 refuses a line into a binary file.** A Citation with a line into a file that is binary (a
   NUL byte in the first 8192 bytes, the test `scan.walk` already uses; exposed as
   `scan.is_binary`) or over `MAX_BYTES` fails: "`x.db` is a binary file; cite it without a line".
   A bare path to such a file still resolves.
