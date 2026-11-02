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
The pass/fail verification of a finished document: every Citation resolves, no section is empty, gaps appear under Open questions, and no secret-shaped value appears. It reports problems, not a score.
_Avoid_: gate, validation score, pristine report

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
