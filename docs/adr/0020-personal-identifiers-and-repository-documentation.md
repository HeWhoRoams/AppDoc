# ADR 0020: Personal identifiers are counted, and repository documentation is input

- **Status:** Accepted (2.8.0)
- **Decision area:** Facts (new kinds, `ownership`); Generated blocks; Check (C23); SKILL.md
- **Builds on:** ADR 0001, ADR 0016 (P1, P2), ADR 0018
- **Rules:** R18

## Context

The new Fact kinds read places where people appear: user names in `<authorization>` rules, employee identifiers in configuration values, owner names in a README. A Facts file is committed with the Target and a generated block is read by everyone who reads the document. A Fact that records a person's name or identifier is a copy of personal data in a place nobody curates. Separately, a repository's own README or runbook often answers a question that the Narrative marks Unknown.

## Decision

1. **R18: personal identifiers are counted, never recorded, in the new Fact kinds and in generated blocks.** A user account in an access rule is `users_named: N`, never the name. An email-shaped or SID-shaped role string is counted as a user and not recorded; a `DOMAIN\X` role is recorded with `domain_qualified: true`. A list of identifiers in a configuration value (the `identifier-list-in-config` candidate) reports a count and the key, not the tokens. Role and group names are recorded as written (Q25), because they describe the application's design, not a person. Generated blocks print names through one cleaning step that withholds an email address or a SID.
2. **Scope and exemptions.** R18 covers the kinds added in 2.8 and the blocks. `ownership` has no exemption: since 2.6.0 (T26.66) it holds commit and contributor counts and first and last commit dates, and no author names, so no 2.8 work changed it. `test_conformance` covers it with the other kinds (an email-shaped regex over the new kinds and generated blocks; existing `message` and `dependency` Facts hold verbatim strings and are allow-listed rather than scanned).
3. **Owner files.** SKILL.md already forbids copying personal addresses from `CODEOWNERS` and `MAINTAINERS`; the rule stays a writing rule and is not a Check.
4. **C23: an Unknown the repository may answer (advisory).** For each section 14 row and each "Unknown - see Open questions." paragraph that names an authentication, authorization, identity or role topic from a closed vocabulary, while a `security_setting` or `access_rule` Fact exists, the advisory names the location (`path:line (kind)`, three at most). It never fails except under `--strict` (R8). The audit's `Answerable` classification remains the binding mechanism. 2.8 covers the authentication topics only.
5. **Repository documentation (2.4, `repo-docs`).** 2.8 adds the generated block marker, in section 2.4 (not 2.2, which is hand-written Purpose and users). The block is a placeholder: it counts `doc_file` Facts if any exist and otherwise says none were recorded. The documentation reader and its closed topic vocabulary (headings recorded as `(line, level)`, heading text only when it matches a closed topic, owner entries as counts) are 2.9 work. Until then the SKILL does not tell the writer to read the block.
6. **Opt-in recording.** `Record connection targets: yes|no` in `appdoc-context.md` is parsed into a `context_directive` Fact and is off by default. In 2.8 the `connections` block lists connection names, kinds, where each is defined and overridden, and whether it is a secret location; it records no target. A later release that records targets may do so only when the directive is `yes`, and only as `scheme://host[:port]` (R19).

## Consequences

- **Positive:** a named user in an access rule can be reported ("N named users in /Admin") without the Facts file or document becoming a roster. The rule is testable, so a new kind cannot regress it.
- **Negative:** a reader cannot learn from the Facts who the named users are; they open the configuration file, which C21 already obliges the writer to cite. The counting rule withholds a role string that happens to look like an email address.
- **Rejected:** hashing identifiers (a hash of a short name is a name); a blanket ban on `@` in Facts (npm scopes and verbatim messages are legitimate).
