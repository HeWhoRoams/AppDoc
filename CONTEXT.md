# AppDoc

AppDoc documents an unfamiliar codebase so a human developer can pick it up, change it, or modernize it.

## Language

**Target**:
The codebase being documented.
_Avoid_: app, repo, project (ambiguous with AppDoc's own repo)

**Reader**:
The human developer who has to pick up a Target they did not write. The documentation is written for them first.
_Avoid_: user, audience, stakeholder

**Fact**:
A single observation about the Target that a script extracted directly from source, together with the file and line it came from.
_Avoid_: evidence, finding, metric

**Facts file**:
The complete, reproducible set of Facts for one Target. The same Target always yields the same Facts file.
_Avoid_: evidence graph, envelope, truth pack

**Facts summary**:
A short map of the Facts file (counts per kind, main folders, largest modules) that the AI reads first on large Targets before drilling into the Facts file.
_Avoid_: index, overview

**Owner context**:
Optional hand-written notes from the Target's owner (purpose, owners, environments) that the code cannot show. Claims drawn from it are cited as owner-supplied.
_Avoid_: overlay, operator-supplied

**Citation**:
A reference from documentation text to a source file in the Target, with a line where the claim is specific. Security and risk claims always carry a line.
_Avoid_: provenance, source link

**Narrative**:
The prose an AI writes into the Template. It starts from the Facts file and may read Target source to explain behavior, but every claim carries a Citation. Grounded, but not byte-identical between runs.
_Avoid_: enrichment, semantic layer

**Claim status**:
Every statement in the Narrative is one of three: **Cited** (backed by a Citation), **Inferred** (the AI's reasoning, visibly marked), or **Unknown** (listed under Open questions).
_Avoid_: epistemic tag, Verified, Partly verified, Operator-supplied

**Template**:
The fixed list of sections the Narrative fills in, plus one **Workflows** section whose subsections are named from the Target.
_Avoid_: section composer, profile

**Check**:
The pass/fail verification of a finished document: every Citation resolves, every table and reference matches the Template spec, counts agree with the Facts, gaps appear under Open questions, every Finding candidate is addressed, Evidence Register anchors are found in their cited lines, and no secret-shaped value appears. It reports problems, not a score. It never judges meaning.
_Avoid_: gate, validation score, pristine report

**Template spec**:
The single machine-readable description of the Template (`appdoc/template_spec.py`): headings, table columns, ID prefixes, allowed values and required rows. The Check reads it; the Template must agree with it.
_Avoid_: schema file, layout config

**Required subsection**:
A numbered `###` heading the Template fixes inside a section (for example 10.2 Unknowns that must not be treated as controls). The Check fails if one is missing or empty.
_Avoid_: mandatory block, sub-heading

**Generated block**:
Narrative content between `appdoc:generated` markers that `appdoc fill` writes from the Facts file and the Evidence Register: scan coverage in 2.1, the entry-point list in 4, the configuration reference in 16.6, scheduled jobs in 16.7, the closed questions under 14 and Appendix A at the end. Nobody edits it by hand; the Check fails when it differs from what `fill` writes.
_Avoid_: auto section, computed table

**Opaque block**:
A Generated block the Check does not read as Narrative and the audit does not cover (`entry-points`, `scheduled-jobs`, `closed-questions`, `appendix-a`, and from template 2.8 `access-model`, `connections`, `integrations`, `pipeline`, `repo-docs`; see `OPAQUE_BLOCKS` in the Template spec). Its tables, IDs and Citations are not the writer's, so a Citation inside one does not count as the document citing that file, and an audit row never certifies one.
_Avoid_: hidden block, skipped section

**Configuration reference**:
The generated list in 16.6 of curated application config keys (never values), with where each is defined (the definition first, a read only when there is none) and whether it is a secret location. Secret locations come first, the list is capped at 150 with a computed "N of M shown" line, and commented defaults are counted, not listed. Build, CI and orchestration config, lockfiles and message bundles are excluded.
_Avoid_: settings dump, config register

**Unclassified config**:
A config file whose role is `unclassified` — the default when no positive evidence (a framework-defined name, or a key read from code) marks it as application configuration. It is counted in the config-reference trailer, never asserted to be app config, and never dropped.
_Avoid_: unknown config, unrecognised config, other

**Evidence Register**:
The source-to-claim audit as data: `evidence.jsonl`, one JSON row per audited claim with its result (Supported, Corrected, Downgraded, Dismissed or Answerable), Citations, Anchor and limitation, after an audit record that declares whether the audit was performed and by whom (independent or same-session). `fill` computes the counts, coverage, register table and verification commands into the Appendix A block; the register is the only source of Appendix A.
_Avoid_: evidence graph, proof table, verification.md

**Finding candidate**:
A `smell` Fact: a code pattern the extractor flags as worth a second look (for example a flash message lost on a non-redirect return). It has a stable id. It is a prompt to read the code, not a verdict. The Check requires each one to be cited in 10.1 or **Dismissed**; it never judges the finding's wording.
_Avoid_: vulnerability, warning, lint error

**Dismissed**:
An Evidence Register result, ref `smell/<id>`, recording that the auditor read a Finding candidate and judged it not a finding. The `limitation` field gives the reason. The writer does not dismiss their own candidates.
_Avoid_: ignored, suppressed, false positive (a reason is required)

**Answerable**:
An Evidence Register result, ref `14/Q-n`, recording that a section 14 question can be closed from source, with the Citations that answer it. The Check fails while the question is still in section 14, so the writer closes it and removes it. A question only a person can answer is `Needs owner` and has no row.
_Avoid_: resolved, closed (those describe the question after the writer acts)

**Entry points not cited**:
An advisory in `check-report.md` listing entry-point Facts (route, page, command, job; not test code) whose file the document never cites, grouped by folder. It does not fail the Check unless `check --strict` is used.
_Avoid_: coverage gap, missing endpoints

**Retired candidate**:
A folder `scan` records as looking retired **by name only**: a whole token such as `old`, `backup`, `deprecated`, or "to be deleted" in the folder's own name (`wwwroot` and `oldest` are not candidates). A candidate nested inside another is not listed again. It is rendered in scan coverage as "Folders that look retired by name (not excluded)" and raises a question the writer must name and answer in 2.1; it never prunes. Whether a folder is a copy of another is not a name signal: see **Duplicate folders**.
_Avoid_: pruned folder, dead code, excluded folder, "retired by content"

**Duplicate folders**:
Pairs `{a, b, files}` in `target.scan.duplicate_folders`: folder `a` (at least five non-test files) has at least half of its files byte-identical to files in folder `b`, the folder holding most of those matches. A pair is stored once with `a < b`; ties go to the smallest path; test paths are ignored; the list is sorted and rendered (cap 10) as "Folders that duplicate another folder (not excluded; say in 2.1 which copy is live)". The writer says in 2.1 which copy is live. C7 reports a pair 2.1 does not name as an advisory, which fails under `--strict`. It never prunes.
_Avoid_: retired candidate (that is a name signal), mirror, fork, clone

**Provenance sidecar**:
`docs/appdoc/provenance.json`, written by `extract`: `{generator, bundle, schema}` for the AppDoc that wrote the Facts (version, a 12-hex hash of the `appdoc/` package, Facts schema), with no timestamps; `fill` adds `blocks_by` for the AppDoc that wrote the generated blocks. `facts.json` itself carries no generator, so an AppDoc patch that changes no Facts changes no Facts file. Appendix A.1 prints the `blocks_by` line; the Check's scope line and C7 version skew read the sidecar; a sidecar whose `schema` disagrees with `facts.json` fails C7. A version difference alone is informational.
_Avoid_: generator stamp, build info, version file

**Anchor**:
A short literal string copied from a claim's cited lines into its Evidence Register row. The Check confirms it is still there, so a code change that moves or removes the evidence is caught.
_Avoid_: quote, snippet, grep pattern

**Seal**:
The `claim_sha` a register row carries: 12 hex characters of SHA-1 over the normalised text its ref points to. `appdoc seal` (the first step of `build`) writes it into every row that lacks one and never overwrites one, so the Check can tell whether the text changed after the audit. Each Seal has a **Seal provenance**.
_Avoid_: fingerprint, checksum, hash (too generic)

**Live row**:
An Evidence Register row that no other row supersedes. The Check, the seals, the coverage and Appendix A read live rows; a superseded row stays in the file as history.
_Avoid_: current row, active row

**Superseded row**:
An Evidence Register row that a later row names in its `supersedes` key because it replaces it for the same ref. It is never deleted, and it is shown in Appendix A marked as superseded.
_Avoid_: deleted row, old row, retired row (a **Retired candidate** is a folder)

**Seal provenance**:
Which party vouched for a row's Seal: `sealed_by` is `audit` when the Seal was written by the audit command or against the text the auditor read, and `upgrade` when it was written against text no one re-audited. Appendix A counts the second kind.
_Avoid_: seal source, seal origin

**Note**:
A line of `notes.jsonl` that states a known limitation of one Generated block. It is rendered inside that block, carries the hash of the block it was written about, and stops matching when the block changes.
_Avoid_: comment, caveat, annotation

**Audit plan**:
`audit-plan.json`: the IDs the independent audit must cover, chosen by the tool from the Narrative (every finding, workflow, question and Finding candidate, and a sample of the other sections), not by the auditor. Generated and Opaque blocks are not part of it.
_Avoid_: audit sample, checklist

**Count marker**:
A pair of comments around a number in the Narrative that `appdoc fill` writes (`appdoc:count CLASS`). It is how a writer states a count; a hand-written "N of M" is only an advisory.
_Avoid_: counter, placeholder, variable

**Severity**:
The rank of a verified finding (10.1) or recommendation (15): Critical, High, Medium or Low, by the rubric in the Template.
_Avoid_: risk score, priority (which ranks open questions)

**Verified absent**:
A 10.2 control status: the auditor confirmed in source that the control does not exist. Distinct from **Not established** (the code cannot show it either way) and **Present** (cited).
_Avoid_: missing, unknown

**Stack**:
A family of technology a Target is built on (for example Classic ASP, ASP.NET Core, Java Spring) that needs its own way of extracting Facts.
_Avoid_: framework class, platform

**Mandatory input**:
A file that holds security-bearing configuration: a `security_setting`, an `access_rule`, a `config_external` reference or an application-role `config_key` that is a secret location (a file the reader could not parse counts, by path). The writer reads it, redacts the values and cites it with a line outside the generated blocks; C21 fails otherwise. See ADR 0018.
_Avoid_: required file, config to review

**Configuration** (build configuration):
A named MSBuild configuration such as `Debug` or `Release`, taken from transform file names, project `Condition` groups and the solution's configuration list. Each has its own **Effective values**. A deployment environment is not a Configuration; the two join only through a CI job's build configuration or a publish profile, never by name. The **production configuration** is `Release` unless `appdoc-context.md` says `Production config: <name>`.
_Avoid_: environment, profile, mode

**Effective value**:
A configuration setting or access rule as one build configuration yields it after its transform. A transform never overwrites the base Fact; a value that depends on something the extractor cannot evaluate is `unknown`, never the base value. Transforms apply at publish or package time to the project-root `Web.config` only.
_Avoid_: resolved value, final value, runtime value

**Access rule**:
An `access_rule` Fact: one `allow` or `deny` entry of `<system.web><authorization>`, with its scope path, verbs and role names as written. User accounts are counted (`users_named`), never recorded.
_Avoid_: permission, ACL, policy

**Guard candidate**:
A `guard_candidate` Fact: an attribute that the Target does not define, used on three or more controllers or actions, which may be an authorization guard. Until the owner declares it with `Auth attributes:` in `appdoc-context.md`, a handler it guards is `unknown`, never `signed_in_any`. Not a **Finding candidate**.
_Avoid_: custom attribute, filter

**Archetype principal**:
One of the three callers that handler reach is evaluated for: `anon` (not signed in), `auth` (signed in, in no role the Target names) and `role:<R>` (signed in, in role R only). A named user is none of them.
_Avoid_: user type, persona, actor

**Reach label**:
The per-handler result `no_app_restriction`, `signed_in_any`, `role_restricted`, `denied` or `unknown`, derived from the Archetype principals for the production configuration. It describes the **application layer only**: IIS, server settings, network exposure and group membership are not in the repository. A handler that changes state and is labelled `no_app_restriction`, `signed_in_any` or `unknown` is a 10.1 finding or a dismissed candidate.
_Avoid_: permission level, exposure, protection level (those claim more than the code shows)

## Relationships

- A **Target** is built on one or more **Stacks**
- Each **Stack** contributes **Facts** to the Target's single **Facts file**
- The **Facts file** is the inventory of what exists; the **Narrative** explains it and may read source to do so
- Every **Citation** points into the **Target**'s source, not into the **Facts file**
- A document is finished only when the **Check** passes
- Secret values never appear in the **Facts file** or the **Narrative**; only their locations do

## Flagged ambiguities

- "Deterministic" meant the whole output under the old design. It now means the **Facts file** only; the **Narrative** is grounded but may vary in wording.

**Register count**:
The number of **live rows** of one ID class (V, F, UI, C, X, Q, R, or all rows) in the Evidence Register. A **Count marker** of a register class holds it, and a hand-written "N of M <noun>" in a document on an older template must have a denominator equal to it.
_Avoid_: total, tally

**Unknown by absence**:
A section left Unknown because the Target supplies no owner context, as distinct from Unknown after an audit. The Check says so in an advisory.
_Avoid_: not found, missing

