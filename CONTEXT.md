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
Narrative content between `appdoc:generated` markers that `appdoc fill` writes from the Facts file and the Evidence Register: scan coverage in 2.1, the entry-point list in 4, the configuration reference in 16.6, scheduled jobs in 16.7 and Appendix A at the end. Nobody edits it by hand; the Check fails when it differs from what `fill` writes.
_Avoid_: auto section, computed table

**Opaque block**:
A Generated block the Check does not read as Narrative (`entry-points`, `scheduled-jobs`, `appendix-a`; see `OPAQUE_BLOCKS` in the Template spec). Its tables, IDs and Citations are not the writer's, so a Citation inside one does not count as the document citing that file.
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
The `claim_sha` a register row carries: 12 hex characters of SHA-1 over the normalised text its ref points to. `appdoc seal` (the first step of `build`) writes it into every row that lacks one and never overwrites one, so the Check can tell whether the text changed after the audit.
_Avoid_: fingerprint, checksum, hash (too generic)

**Severity**:
The rank of a verified finding (10.1) or recommendation (15): Critical, High, Medium or Low, by the rubric in the Template.
_Avoid_: risk score, priority (which ranks open questions)

**Verified absent**:
A 10.2 control status: the auditor confirmed in source that the control does not exist. Distinct from **Not established** (the code cannot show it either way) and **Present** (cited).
_Avoid_: missing, unknown

**Stack**:
A family of technology a Target is built on (for example Classic ASP, ASP.NET Core, Java Spring) that needs its own way of extracting Facts.
_Avoid_: framework class, platform

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
The number of live rows of one ID class (V, F, UI, C, X, Q, R, or all rows) in the Evidence Register. A hand-written "N of M <noun>" must have a denominator equal to the register count for that noun.
_Avoid_: total, tally

**Unknown by absence**:
A section left Unknown because the Target supplies no owner context, as distinct from Unknown after an audit. The Check says so in an advisory.
_Avoid_: not found, missing

