# ADR 0011: The register is the single source of truth for which unknowns stand

- **Status:** Accepted (2026-11-23)
- **Decision area:** Check; Evidence Register; Narrative

## Context

The 2.4 diagnostic found that §14 (open questions) and the register disagreed. Questions the audit
resolved (Answerable) were still listed in §14 or silently dropped, and hand-written counts such as
"10 of 10" contradicted the register. Two places claimed to know which unknowns stand, so they
drifted.

## Decision

1. The Evidence Register decides which unknowns stand. A Q-row with an Answerable or Dismissed
   result is not an open question, and §14 must not list it (C14).
2. A hand-written "N of M <noun>" is checked against the live count of that noun's ID class in the
   register (C15). Nouns that map to no class are skipped.
3. An ownership or deployment section that is Unknown because no owner context exists says so
   ("Unknown by absence"), as an advisory in C4, so that absence is not mistaken for an audit
   result.

## Consequences

- Writers cannot keep a closed question open or hand-type a count that disagrees with the register.
- C14 and C15 may fail documents that passed under 2.4. The upgrade notes say so.
- 2.7 replaces the English-matching C15 with count markers; that is a recorded exception to the rule
  never to weaken the Check, because a structural rule replaces a textual one.
