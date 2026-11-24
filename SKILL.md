---
name: appdoc
description: Use when asked to document, inventory, or onboard someone to an application, or to install AppDoc from a local folder or GitHub repository.
---

# AppDoc

Produces onboarding documentation for a **Target** (the codebase being documented). Scripts extract **Facts** (what exists, with `file:line`). You write the **Narrative** from them. A **Check** verifies it. Read `CONTEXT.md` for the exact terms.

`SKILL_DIR` below is the folder that contains this file. Requires Python 3.10+ (standard library only). On Windows use `py -3` if `python` is not on PATH. Every command works from any current directory; always call the launcher by its full path, `python SKILL_DIR/run_appdoc.py ...`.

Before running any AppDoc command, verify that `SKILL_DIR` contains `CONTEXT.md`, `run_appdoc.py`, `appdoc/assets/template.md`, and `appdoc/assets/mermaid.min.js`. If any are missing, stop before creating or changing files in the Target. Tell the user the skill bundle is incomplete and to run `python <AppDoc-checkout>/install_skill.py <skills-root>` from the AppDoc source checkout (on Windows, use `py -3` if needed). Installing only `SKILL.md` is not sufficient.

## Install this skill

When asked to install AppDoc from a folder, repository, or GitHub URL:

1. Make sure the full AppDoc source checkout is available, including `install_skill.py`, `SKILL.md`, `CONTEXT.md`, `run_appdoc.py`, and `appdoc/`. If given only a URL, obtain the full repository if network access is available. Do not install a standalone `SKILL.md`.
2. Install globally by default. Use the current runtime's skills root: `~/.copilot/skills` for VS Code Copilot, `~/.claude/skills` for Claude Code, or `~/.agents/skills` for Codex and Gemini CLI. If the runtime or requested project-local destination is unclear, ask before installing.
3. Run `python <AppDoc-checkout>/install_skill.py <skills-root>` (on Windows, use `py -3` if needed). The installer creates or repairs the `appdoc/` folder under that skills root.
4. Verify the installed bundle contains `SKILL.md`, `CONTEXT.md`, `run_appdoc.py`, `appdoc/assets/template.md`, and `appdoc/assets/mermaid.min.js`; then run the installed `run_appdoc.py --help` and report the installation path.

If the source cannot be accessed or Python cannot be run, explain the blocker and give the user the manual command from `README.md`; do not claim the skill is installed.

## Choosing the Target

`/appdoc` with no argument documents the **current working directory**: the folder the user opened the session in (the project root). Do not ask which codebase; just start. If the user passes a path, use that instead. If the working directory is clearly not a codebase (home folder, empty), say so and ask for a path. Below, `<target>` is that folder.

## Run

If `<target>/docs/appdoc/application-documentation.md` already exists, run `check` first and continue from its problems. Do not start over, and do not restart from the template after an interrupted run. If the document's `appdoc:template` stamp is older than the template you run (the Check reports it under C3), run the Upgrade command below first: `appdoc upgrade` adds the headings, blocks, columns and rows the template now requires, keeps every line of text (what it cannot place goes under an `appdoc:upgrade-orphan` comment that the Check fails until you have moved it), extracts and fills, and writes `<target>/docs/appdoc/UPGRADE-TODO.md`. That file lists what only a person can do, each with the Check rule that fails until it is done. It never writes `evidence.jsonl` or `notes.jsonl`.

1. **Extract.** Run the Extract command below. It writes `<target>/docs/appdoc/facts.json`, `facts-summary.md` and `provenance.json`. Re-running gives identical output.
2. **Orient.** Read `facts-summary.md` first, including its Finding candidates, Ownership files and Scheduled jobs sections, and the two scan-coverage lists (folders that look retired by name; folders that duplicate another folder). If `<target>/appdoc-context.md` exists, read it: it is the owner's notes (purpose, owners, environments) and the only source for things the code cannot show. Then drill into `facts.json` by kind or folder, and open source files to understand behavior. Read every `owner_file` before writing section 11.
3. **Write.** Copy `SKILL_DIR/appdoc/assets/template.md` to `<target>/docs/appdoc/application-documentation.md` and fill every section, keeping all 17 headings, every numbered `###` subsection, every table header, the `appdoc:template` stamp and the `appdoc:generated` markers. Fill section 17 (Build, Run and Test Locally; see the writing rules). Fill the header line (Target, commit from `facts.json`, evidence date) and keep the "How to read this document" paragraph. Delete each `appdoc:guide` comment once its section is filled. Write the register (`evidence.jsonl`) rows the document needs, or the minimal audit record `{"type": "audit", "performed": false, ...}` until the audit runs.
4. **Build until it passes.** Run the Build command below. It seals the register, writes every generated block (2.1 scan coverage, the 4 entry-point list, 16.6 configuration reference, 16.7 scheduled jobs, Appendix A), runs the Check and renders the HTML. Fix every problem it lists and run it again. `build --expand-citations` first rewrites each bare file name that has one full path to the full path. After 3 failed builds, stop and report the remaining problems to the user verbatim. Never edit a generated block by hand.
5. **Plan the audit.** Before `audit-plan`, run `check --strict` and fix every advisory: the audit plan's sample is seeded by `doc_sha`, so any later Narrative edit reshuffles the sample and forces another audit pass. Then run the Audit plan command. It writes `<target>/docs/appdoc/audit-plan.json`, a function of the document: every 10.1 finding, workflow, section 14 question and finding candidate, plus a sample of sections 4, 6, 8.1, 8.3, 9 and 15 that the tool, not the auditor, chooses. Generated and opaque blocks are not audited; say that in the audit record's `exclusions`, not in `scope`. `audit-plan` rewrites `audit-plan.json` on every run; an auditor under a read-only mandate runs `audit-plan <target> --check` instead, which writes nothing, prints the planned IDs on disk and from a fresh computation, and exits 0 when they are equal and 2 when the plan is stale or missing.
6. **Audit in a fresh agent.** The auditor gets the finished document, the Target and `audit-plan.json`, not your notes (see Source-to-claim audit). It covers **every planned ID** (more if useful), writes `<target>/docs/appdoc/evidence.jsonl`, and classifies every section 14 question and every finding candidate. The audit verifies **support**; the Check verifies **resolution and structure**; do not conflate them. Where the runtime has no sub-agents, audit in a new session and record `"same-session"` if you cannot.
7. **Apply findings, audit the delta, seal.** The order is: audit, apply findings, audit the delta, seal, build. Edits made because of audit findings change the document, so after applying them run `audit-plan` again and have the auditor cover the new IDs; repeat until the plan is stable, then seal. Because the sample is seeded by `doc_sha`, any Narrative edit after an audit reshuffles it: in the final pass the auditor should cover every row of the sampled sections (all F, UI, C, X and R rows and every section 9 row), so a later reseed cannot leave an unaudited planned ID. Run the Seal command with today's date (`--audit --date YYYY-MM-DD`). It writes the audit date, the AppDoc version and bundle, and the document fingerprint on line 1 of the register, and seals the new rows as audited. A plain `build` seals a row as `upgrade` instead when the document changed after the audit; `check --require-audit --strict` fails on those.
8. **Build again.** Run the Build command with `--require-audit`. The register changes the Appendix A block, so the generated blocks are rewritten. Then rewrite every sentence in 15.1 and 2.1 that states the audit state (who audited, what was covered, or that none was done) so it matches `evidence.jsonl`. These sentences must not state counts by result (supported, corrected and so on): counts go stale after every delta pass. Use a `rows` count marker for the number of register rows and refer to Appendix A for the rest. Then close each `Answerable` question (put the answer in the body, remove the question from section 14; the generated closed-questions block lists it), and build again. The last thing you run after any register or document edit is the Build command.
9. **Report.** Tell the user where the files are, whether the Check passed, who audited (independent or same-session), and what Appendix A.1 says about provenance: the `Generated blocks written by AppDoc ... (bundle ...)` line, the `Audited on ... with AppDoc ...` line, any rows sealed at upgrade, and the line that says the generated blocks were regenerated after the audit when it is there.

<!-- appdoc-self:generated run-commands -->
Commands, in order (generated from `appdoc/workflow.py`):

1. Upgrade: `python SKILL_DIR/run_appdoc.py upgrade <target>` (only when the existing document carries an older template stamp: adds what the template now requires, keeps every line of text, extracts and fills, and writes UPGRADE-TODO.md for the steps left to a person)
2. Extract: `python SKILL_DIR/run_appdoc.py extract <target>` (writes facts.json, facts-summary.md and provenance.json; re-running gives identical output)
3. Build: `python SKILL_DIR/run_appdoc.py build <target>` (seal, fill, check and render; repeat until it passes, and after 3 failures report the problems verbatim)
4. Fix advisories: `python SKILL_DIR/run_appdoc.py check <target> --strict` (fix every advisory before the audit plan: the plan's sample is seeded by doc_sha, so a later Narrative edit reshuffles it)
5. Audit plan: `python SKILL_DIR/run_appdoc.py audit-plan <target>` (writes audit-plan.json: the IDs the audit must cover, a sample chosen by the tool)
6. Seal: `python SKILL_DIR/run_appdoc.py seal <target> --audit --date <YYYY-MM-DD>` (records the audit date and provenance and seals the new rows as audited; the date is given, never read from the clock)
7. Build: `python SKILL_DIR/run_appdoc.py build <target> --require-audit` (the same command, now that the audit exists)
<!-- /appdoc-self:generated run-commands -->

Optional flags: `--out DIR` (inside the target) on every command; `--css FILE` on `render` to replace the theme; `--require-audit` and `--strict` on `check`, `build` and `gate`.

## Writing rules

- **Cite everything.** A Citation is a backticked Target-relative path, with a line where the claim is specific: `` `portal/verify.asp:6` ``, `` `src/App.java:40-52` ``, `` `portal/HelpWeb/search.asp` ``. A folder (`` `src/main/` ``) or a unique bare filename (`` `data.sql` ``, `` `Procfile` ``, `` `MAINTAINERS` ``) also resolves. Routes (`/api/x`) and absolute paths are not Citations. Cite `` `appdoc-context.md` `` only if that file exists in the Target.
- **Cite config files by full path.** Names like `app.ini`, `appsettings.json` or `application.properties` often exist more than once; a bare name that matches several files fails the Check. Never cite a file you have not opened (for example a runtime-generated `custom/conf/app.ini`): cite the example or template that exists and say the runtime file is Unknown.
- **Never downgrade a correct Cited claim to satisfy the Check.** If a valid Citation does not parse, report it.
- **Fill the tables the template gives you,** one cited row per item. The Check enforces headers, cell counts, ID prefixes and allowed values (C9) and that every ID you mention exists (C10); this list covers what it cannot judge. Thin sections are a defect: the Glossary lists every Target-specific term used in the document; the Troubleshooting Matrix has one row per `message` Fact or error branch you read; "Escalate when" is a concrete trigger, not Unknown, wherever the code shows the failure.
- **Enumerations are complete or say so.** A list or table that claims to be complete ("all tasks", "as coded") lists every item in source. Otherwise say how many are shown, with the total as a count marker (next rule), never from memory.
- **Severity (10.1, 15)** follows the rubric in the template: Critical = exploitable without authentication, or exposes secrets or data, in the default configuration; High = authenticated privilege escalation, data-integrity loss, or an exposed credential; Medium = needs another condition; Low = hygiene. State the condition that sets the level in the Impact cell.
- **10.2 status is a finding, not a shrug.** "Verified absent" when you confirmed in source the control does not exist; "Not established" when the code cannot show it either way; "Present" only with a Citation. Every control that is not Present gets a recommendation or an open question that names it.
- **No auth is still content.** If the Target has no roles or auth, fill 5.1-5.3 anyway (no roles observed, where enforcement would be, every capability public) and list the missing controls in 10.2. 5.3 includes rows a role must not have, and a token/scope view where the API is scope-gated.
- **Finding candidates.** Every `smell` in the Facts summary becomes a 10.1 finding, or the auditor dismisses it with a reason. Do not dismiss your own.
- **Config and findings.** When a config key changes the impact of a finding, name it and cite it in that finding's Impact cell.
- **Framework defaults.** When config exposes a framework's known set (actuator `*`, Swagger UI, debug toolbars), list the set as **Inferred** from the framework version in the dependency manifest. Do not mark it Unknown.
- **Ownership files.** Never copy personal email addresses from `CODEOWNERS`, `MAINTAINERS` or similar files; name the role or team, or say that the file exists.
- **Mine the tests.** Test suites show intended behavior (concurrency, dialects, permissions). Cite what a test asserts as evidence for a claim, list each suite in section 11 with the F-IDs it covers, and never describe test-only code as application behavior.
- **Data model.** 8.4 adds a field table per core entity (type, null, key/FK, sensitivity) from the schema, migrations or model classes; section 12 gets an `erDiagram` when 8.4 has entities.
- **Runbook is for operators.** 16.5 has a row for each of Build, Test, Deploy, Upgrade, Rollback, Backup, Restore and Secret rotation: the command, job or script that does it, cited, or Unknown. A CI job list is not a runbook.
- **Folders not scanned.** The 2.1 generated block lists folders AppDoc pruned. If one holds source, say so in 2.1 and read it, or add `!name` to `.appdocignore` and re-extract.
- **Name every candidate in 2.1.** Each folder in "Folders that look retired by name" gets a sentence in 2.1 naming it and saying what you found (retired, live, or unknown). The name is only a signal: a folder called `old` can be live, and a folder not named like that can be dead. For each pair in "Folders that duplicate another folder", say in 2.1 **which copy is live** (the one the build, the routes or the imports use, cited) and that the other is a copy, or say it is Unknown. Neither list excludes anything from the Facts; Facts from both copies are in `facts.json`, so do not describe the dead copy's routes as application behavior.
- **Counts only through count markers.** Do not type a number of findings, routes, jobs, workflows or register rows. Write `<!-- appdoc:count V -->14<!-- /appdoc:count -->` and let `fill` write the number. The classes are `V F UI C X Q R` (defined IDs), `rows superseded` (register) and `routes jobs pages commands config-keys` (Facts). A stale marker or an unknown class fails C15; a hand-written "N of M" is an advisory that asks for a marker.
- **Known extractor limitations go in `notes.jsonl`.** A caveat about a generated block ("the extractor does not see X") is one line of `<target>/docs/appdoc/notes.jsonl`: `{"block": "entry-points", "text": "...", "cites": ["path:line"], "block_sha": ""}`. `fill` prints it inside its block; `build` fills `block_sha`. When the block later changes, C18 fails the note: re-read the block, rewrite or delete the note and clear `block_sha`. Never write the label `Known extractor limitation:` in the Narrative.
- **Order 10.1 and 15 by severity** (Critical, High, Medium, Low). A row that outranks the one above it fails C9: move the row and keep its ID.
- **Cite files by full path.** On template 2.7 a bare name that is not a root file fails C1, and the message prints the unique full path. `build --expand-citations` rewrites those for you, outside code fences and generated blocks.
- **Close questions with `answered_in`.** An `Answerable` register row carries `"answered_in": "<section>"` (for example `"16.3"`), the section whose body now holds the answer.
- **Never delete register rows.** To correct a row, append a new row on the same `ref` with `"supersedes": "E-<n>"` and leave the old one. Two live rows on one ref fail C11. To re-audit text that changed, add the new row; do not rewrite or remove the old one.
- **Audit `scope` is the method only.** Write how the audit was done (what was read, what was sampled and why), with no IDs, section lists or digits: coverage is computed into A.1. Caveats about a section go in `exclusions`: `{"<section>": "<reason>"}`, which A.1 prints. C17 fails a `scope` with an ID or a digit. Exclusions are whole sections: the key is a bare section number (`"9"`), and the planned IDs under it then need no rows (C19). Never exclude a section that has planned IDs; audit them. Generated blocks inside such a section are simply not audited, so they need no exclusion.
- **A backticked file name is a Citation, even in a negative sentence.** `appdoc-context.md` in backticks must exist; to say a file does not exist, write its name without backticks (appdoc-context.md does not exist), or C1 fails.
- **A sentence that carries a count marker still needs a Citation (C5).** The marker supplies the number, not the support.
- **Write `\|` for a `|` inside a table cell.** A bare pipe splits the cell and fails C9.
- **Section 11 Status is Cited, Inferred or Unknown.** No other value passes C9.
- **One live register row per ref.** Where a section has several planned items under one ref (9, 10.2, 16.5, 17) the auditor writes one combined row with per-item notes in `limitation`; a failing item makes the whole row Corrected or Downgraded.
- **Fill section 17, Build, Run and Test Locally.** Five rows (Prerequisites, Restore dependencies, Build, Run, Test). The Command cell holds exactly one backticked command and nothing else (put extra commands and prose under the table); it is that command, `Unknown - see Open questions.` (the repository does not show it) or `Not applicable`; any row that is not Unknown needs a Citation with a line in Evidence, where the command is defined.
- **Section 10 splits findings from non-controls.** 10.1 lists risks observed in source; 10.2 lists controls (TLS, CSRF, MFA, cookie flags, rate limiting, audit integrity, backup and recovery, production secrets) with their status so no reader mistakes them for protections.
- **Three claim statuses only.** *Cited* (has a Citation), *Inferred* (start the paragraph or item with `**Inferred:**` and still cite what it rests on), *Unknown* (add a row to section 14; elsewhere write "Unknown - see Open questions.").
- **Never write a secret value**: passwords, tokens, keys, connection-string credentials. Write "value omitted" and cite the location. The Check scans for secret shapes and fails.
- Do not invent owners, environments, deployment steps or business purpose. If the code, an `owner_file` and `appdoc-context.md` do not say, it is Unknown.
- Read source for the parts that need explanation (workflows, error handling, security findings). The Facts tell you where to look; they do not replace reading.
- Section 7 (Workflows) has no fixed subsections: name each `###` after a real workflow in the Target. Cover every create, edit and delete flow listed in section 4, and end each workflow with a cited "Failure and escalation:" line. Write it and section 1 (Index) last.
- Treat an empty Facts list as "not extracted", not "absent": confirm in source before writing that something does not exist (for example, no auth checks).
- Ownership Facts exist only with full git history (`Git history: full` in the summary). On a shallow clone or without git, say ownership is Unknown.
- Facts marked `test` in `facts.json` come from test code; do not describe them as application behavior.
- Put diagrams in ```` ```mermaid ```` fences, each with a one-line cited caption.
- Never edit `facts.json`. Never weaken the Check to make it pass: fix the document.

## Source-to-claim audit

Verify that every Cited claim is actually **supported** by the lines it cites. The Check verifies **resolution** (each Citation points to a real file and line, and each register anchor is still in its cited lines); the audit verifies **support** (the cited lines actually back the claim). A citation that resolves but does not support its claim is a **defect**, not a pass.

**Who audits.** The auditor gets the finished document and the Target, not the writer's notes or reasoning. Where the runtime has sub-agents, start a fresh one for the audit. Where it does not, audit in a new session (the register is a file, so an interrupted audit resumes). Record which it was: `"auditor": "independent"` or `"same-session"`. Never claim independent when the writer audited.

- Cover every ID in `audit-plan.json` (C19 fails a planned ID without a live row), and more where the claims are risky. The plan covers sections 3 to 10 and 14 to 17 where they make claims. Every 10.1 finding and every workflow needs a row (C11). Do not choose your own sample: the tool did. In the final pass cover every row of the sampled sections (all F, UI, C, X and R rows and every section 9 row), because the sample is seeded by `doc_sha` and a later Narrative edit reseeds it. **Generated and opaque blocks are not audited** (scan coverage, entry points, closed questions, configuration reference, scheduled jobs, Appendix A); the Check and `fill` own them, and an audit row never certifies one.
- **Classify each section 14 question.** `Needs owner` (only a person can answer it) or `Answerable` (a row with ref `14/Q-n` and the Citations that answer it). A `14/Q-n` row marked `Answerable` means the writer removes the question from section 14 and puts the answer in the body; C11 fails while it is still open.
- **A Supported row always needs a Citation and an anchor, even when it records a `Needs owner` question.** A `Needs owner` question has no result value (only Supported, Corrected, Downgraded, Dismissed and Answerable exist): write a Supported row citing the nearest source (the file that shows the topic is not answered in source, or the question's own source) with an anchor copied from those lines. The question stays open in section 14.
- **Review each finding candidate** (`smell` in the Facts summary, shown with its id). Open the code. If it is a real defect, confirm it: the writer adds a 10.1 finding that cites the line. If it is not, write a `Dismissed` row (ref `smell/<id>`) whose `limitation` says why. C12 fails while a candidate is neither cited in 10.1 nor dismissed.
- **Glossary check (your judgment, not enforced).** Every identifier in a 10.1 Finding cell that is not a common word should have a section 13 row. The Check does not test this.
- Open the cited span and confirm it supports the exact claim. Identify whether the claim comes from code, repository documentation, or owner context.
- When a cited line does not support the claim: correct the claim to match the source (result Corrected), downgrade it to **Inferred** or move it to section 14 as **Unknown** (result Downgraded). Never leave a Cited claim that the source does not back.
- Trace behavior through the code that controls the result, including relevant callers, model/service logic, and success or error paths. A route, Facts record, or nearby call site may not establish the outcome.
- Read build and deployment configuration job by job. Keep restore, build, test, package, and deploy steps attributed to the job that actually runs them.
- Do not infer why a file was excluded or a behavior is absent. State that it was not reviewed unless an explicit policy source supports the reason; otherwise record the reason as Unknown.
- Keep inferences visibly marked and list unresolved questions in section 14. An empty Facts list or a passing Check is not evidence that a behavior does not exist or that the Narrative is factually correct.
- Never copy secret values into the Narrative or the register (C6 scans both). If source contains a credential, redact it and report the exposure separately; redaction does not remediate the credential.

**Record the audit** in `<target>/docs/appdoc/evidence.jsonl`, one JSON object per line:

```
{"type": "audit", "performed": true, "auditor": "independent", "scope": "read each planned claim against the cited lines and the callers; a fresh agent, no writer notes"}
{"id": "E-1", "ref": "10.1/V-1", "claim": "Login compares the password with !=", "result": "Supported", "cites": ["app.py:80-83"], "anchor": "!= app.config['PASSWORD']", "limitation": "timing not measured"}
{"id": "E-2", "ref": "smell/3fa9c1d2", "claim": "Flash message set before a non-redirect return", "result": "Dismissed", "cites": [], "anchor": "", "limitation": "the view reads the flash in the same request"}
{"id": "E-3", "ref": "14/Q-2", "claim": "Session lifetime is set in config", "result": "Answerable", "cites": ["app.py:31"], "anchor": "", "limitation": ""}
```

- `ref` is the heading number the claim lives under, with the document ID when there is one: `10.1/V-1`, `4/F-3`, `7.2`, `16.5`.
- `cites` are Target-relative `path:line` or `path:start-end` strings.
- `anchor` is a short literal string copied from the cited lines (not a regex). Supported and Corrected rows need one; the Check confirms it is still there.
- `result` is Supported, Corrected, Downgraded, Dismissed or Answerable. Write what the source shows, not what an earlier draft said: the register records the document as it is.
- `Dismissed` rows use ref `smell/<id>` and a `limitation` that gives the reason; `Answerable` rows use ref `14/Q-n` and cite the answer. Both need no anchor (`"anchor": ""`), and a `Dismissed` row may have empty `cites`; every row still carries all seven keys.
- Do not write counts, a summary or re-run commands; `fill` computes them into Appendix A.
- If no audit was done, write only `{"type": "audit", "performed": false, "scope": "<why>"}`. Appendix A then carries a banner, and `check --require-audit` fails. A missing file always fails.

## Large Targets

Read `facts-summary.md` and work subsystem by subsystem. Do not try to read the whole Target.

1. Write 4.1 (Subsystem inventory) first, one row per folder in the top-folders table.
2. For each subsystem, pull its entry points and data access from `facts.json`, read the files that matter, and write its part of sections 4 to 8. Save the document after each subsystem so an interrupted run can resume where it stopped.
3. Run `check` after sections 4-8 and again after 10, not only at the end; fix problems while the context is fresh.
4. Write sections 7 and 1 last.

When splitting work across agents, give each agent one subsystem and the template subsections it owns; one agent merges, writes 1, 7, 14-16, runs `fill` and the Check. A separate agent that did not write any part runs the audit.

Part agents also own the `entry-points` coverage of their subsystem: every handler file in it is cited in the document. The merger confirms every handler file is cited or listed in 2.1 as not reviewed. If an agent returns no response after writing the file, inspect the file and resume with `check`.

## When a Stack is not supported

Facts for it are generic only (files, dependencies, config keys, secret locations). Say so in section 2, rely on reading source, and mark what you could not establish as Unknown. Build 4.1 from the folder structure, and if the Target ships a generated API description (OpenAPI/Swagger, route tables), register its main endpoint groups in section 4 rather than deferring to it. To add a Stack, see "Add a Stack" in `README.md`.

## What the Check enforces

C1 every Citation resolves to a real file and line. C2 section 10 Citations have lines. C3 all 17 sections exist and have content, and the document carries the current template stamp. C4 gaps are declared in section 14. C5 each paragraph in sections 3 to 10 is cited, Inferred or Unknown. C6 no secret-shaped strings and no `never-mention` terms in the document or the register. C7 unsupported Stacks are named in section 2, 4.1 file counts match the Facts, generated blocks match what `fill` writes, and a count such as "five controllers" in sections 2 to 4 matches the Facts ("N of M" passes when M matches). C8 every required numbered subsection (4.1, 5.1-5.3, 8.1-8.5, 10.1-10.2, 15.1, 16.1-16.7) exists inside its section and has content. C9 tables match the template: headers, cell counts, ID prefixes, allowed values, the eight 16.5 rows, the six 11 owner rows, the fixed 5.3 Restriction line, and no leftover `appdoc:guide` comment. C10 references resolve: IDs are defined once, every mentioned ID and `#anchor` exists, every 10.1 finding has a recommendation, every 10.2 control that is not Present is in 15 or 14, every 8.1 and 8.3 ID has an 8.5 row, every Area in section 4 appears in 5.3, and every Key in a 16.6 effect table is a `config_key` Fact. C11 `evidence.jsonl` is valid, covers every 10.1 finding and workflow, every anchor is in its cited lines, no `Answerable` question is still open in section 14, and anchors are one line and at most 200 characters. C12 every finding candidate is cited in 10.1 or `Dismissed` in the register with a reason. On a template 2.7 document the Check also enforces: C14 section 14 and the register agree (live rows only); C15 count markers are current and their class is known; C17 audit provenance and a method-only `scope`; C18 notes match their block; C19 the audit follows the plan; C1 full paths, C9 severity order and section 17 rows; C11 two live rows on one ref fail and `supersedes` must name an older row of the same ref.

Two further rules, C16 and C20: plain `build` prints them as advisories and `check --strict` fails on them, so fix them before the audit plan. C16 universal claims cite only single lines. A sentence with a word such as all, any, each, every, always, never, whole or entire and only single-line Citations triggers it; cite the covering range or mark the claim **Inferred:**. C20 citation precision. A cell may cite at most 5 sources, each range at most 100 lines, and a wide range that is the claim's only lined Citation fails; cite the specific lines the claim rests on.

Advisory, in `check-report.md`: **Entry points not cited** lists entry-point Facts whose file the document never cites. It does not fail the Check unless you run `check --strict`.

The Check never judges whether a claim's wording follows from its evidence, or whether a finding candidate's wording is right; that is the audit. Do not present a PASS as an accuracy certification. The result is in `check-report.md`, which also holds the Citation register and the audit coverage per section.

## Owner context (optional)

The owner may add `<target>/appdoc-context.md` with purpose, owners, environments and known history. Cite it as `` `appdoc-context.md` ``. A fenced block with info string `never-mention` lists internal terms (one per line) that must not appear in the document.
