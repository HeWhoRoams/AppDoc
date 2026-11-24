# ADR 0018: Security-bearing configuration is mandatory input

- **Status:** Accepted (2.8.0)
- **Decision area:** Facts (secrets, configuration); Check (C21); SKILL.md writing rules
- **Builds on:** ADR 0001 (redaction), ADR 0009 (curated config reference), ADR 0016 (P2: the Check reads structure, not wording)
- **Rules:** R16, R19

## Context

A document for a .NET Framework Target listed its runtime configuration files as "not reviewed". Those files held the settings that decide who can use the application: the authentication mode, `<authorization>` rules, role names, connection strings and keys. A writer who is unsure whether a file may be quoted leaves it out, and nothing in the Check noticed. The generated 16.6 configuration reference made it worse: it cites every application config file with a line, so a rule that only asked for "a citation of the file" would have passed on a document that never read the file.

The remedy for secrets is already settled (ADR 0001): values are redacted, never skipped. What was missing was a rule that a security-bearing file must be read, and a way to check that it was.

## Decision

1. **R16: primary runtime configuration is mandatory input.** A file that holds a `security_setting`, an `access_rule`, a `config_external` reference or an application-role `config_key` that is a secret location is read and cited with a line. Values are redacted, never skipped. A file the reader could not parse (`config_unparsed`) is still cited, by path.
2. **C21 checks it.** The rule takes the paths of those Facts and requires each to be cited with a line in the Narrative with every generated block masked (`docmodel.mask_blocks` over all `template_spec.GENERATED` names). Masking is the point of the design: without it the 16.6 block satisfies the rule. Section 16 is not an accepted location, and the wording of the citing sentence is not read (P2). It runs when the document's stamp equals the running template, like C7 to C13; it is a handle check and not a preview. Failure text: `this file is mandatory input (R16); read it and cite what it shows, redacting values`.
3. **A C20-family advisory** flags a citation of a file inside a sentence that says the file was not reviewed (`not reviewed`, `not inspected`, `excluded`, `was not read`), with a C21 hint when the file is mandatory input.
4. **R19: secret values and credential-bearing strings are never recorded or resolved.** The new Fact kinds (`security_setting`, `access_rule`, `const_def`, `guard_use` and the rest) follow the same rule as `secret_location`: a constant for which `secrets.never_record_value(name)` is true is not value-resolved (value gating uses `never_record_value`, never `is_secret_key` alone); URLs are recorded as `scheme://host[:port]` only; CI `variables` are recorded by key name. `tests/test_conformance.py` asserts that no Fact detail equals the value of a `secret_location` in the same run.
5. **SKILL.md says it.** The writing rule "never list a configuration file as not reviewed" is generated from `workflow.SKILL_RULES` (ADR 0005 mechanism), so the guidance and the Check cannot drift apart.

## Consequences

- **Positive:** a Target whose access rules live in configuration cannot be documented without reading them, and the document cannot state that it did not. A mandatory file is named in the failure message.
- **Negative:** a document passing a 2.7 Check can fail C21 after `appdoc upgrade` and re-extract. The writer must cite each such file with a line outside the generated blocks. The rule asks for a citation, not for correct reading: whether the cited lines support the sentence stays with the audit.
- **Rejected:** counting the 16.6 block as the citation (the rule would be vacuous); a warning (a warning nobody reads is how the not-reviewed list shipped); skipping files that contain secrets (redaction is the answer, ADR 0001).
- **Known limit:** R16 is generic in wording only. The Facts that make a file mandatory come from the .NET Stacks; a Spring or Express Target whose access rules live in configuration gets no mandatory-input obligation until a detector exists for it.
