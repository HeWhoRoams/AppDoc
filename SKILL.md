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

1. **Extract.** `python SKILL_DIR/run_appdoc.py extract <target>`
   Writes `<target>/docs/appdoc/facts.json` and `facts-summary.md`. Re-running gives identical output.
2. **Orient.** Read `facts-summary.md` first. If `<target>/appdoc-context.md` exists, read it: it is the owner's notes (purpose, owners, environments) and the only source for things the code cannot show. Then drill into `facts.json` by kind or folder, and open source files to understand behavior.
3. **Write.** Copy `SKILL_DIR/appdoc/assets/template.md` to `<target>/docs/appdoc/application-documentation.md` and fill every section, keeping all 16 headings in order.
4. **Source-to-claim audit.** Before checking, verify that each Cited claim in sections 3 to 10 is actually **supported** by the lines you cited — not just that they resolve. A citation that resolves but does not support its claim is a **defect**, not a pass: correct the claim to match the source, downgrade it to **Inferred** (state what it rests on), or move it to section 14 as **Unknown**. This step verifies **support**; the Check verifies **resolution** — do not conflate them. Record the outcome in `<target>/docs/appdoc/verification.md` (see Source-to-claim audit).
5. **Check.** `python SKILL_DIR/run_appdoc.py check <target>`. Fix every problem it lists and run it again. After 3 failed checks, stop and report the remaining problems to the user verbatim.
6. **Render.** `python SKILL_DIR/run_appdoc.py render <target>`. Writes `application-documentation.html` next to the Markdown.
7. **Tell the user** where the files are and whether the Check passed.

Optional flags: `--out DIR` (inside the target) on every command; `--css FILE` on `render` to replace the theme.

## Writing rules

- **Cite everything.** A Citation is a backticked Target-relative path, with a line where the claim is specific: `` `portal/verify.asp:6` ``, `` `src/App.java:40-52` ``, `` `portal/HelpWeb/search.asp` ``. A folder (`` `src/main/` ``) or a unique bare filename (`` `data.sql` ``) also resolves. Routes (`/api/x`) and absolute paths are not Citations. Cite `` `appdoc-context.md` `` only if that file exists in the Target.
- **Section 10 (Security and Operational Risks): every Citation needs a line.**
- **Three claim statuses only.** *Cited* (has a Citation), *Inferred* (start the paragraph or item with `**Inferred:**` and still cite what it rests on), *Unknown* (list it in section 14; elsewhere write "Unknown - see Open questions.").
- **Never write a secret value**: passwords, tokens, keys, connection-string credentials. Write "value omitted" and cite the location. The Check scans for secret shapes and fails.
- Do not invent owners, environments, deployment steps or business purpose. If the code and `appdoc-context.md` do not say, it is Unknown.
- Read source for the parts that need explanation (workflows, error handling, security findings). The Facts tell you where to look; they do not replace reading.
- Section 7 (Workflows) has no fixed subsections: name each `###` after a real workflow in the Target. Write it and section 1 (Index) last.
- Treat an empty Facts list as "not extracted", not "absent": confirm in source before writing that something does not exist (for example, no auth checks).
- Ownership Facts exist only with full git history (`Git history: full` in the summary). On a shallow clone or without git, say ownership is Unknown.
- Facts marked `test` in `facts.json` come from test code; do not describe them as application behavior.
- Name every unsupported Stack (listed in the Facts summary) in section 2.
- Put diagrams in ```` ```mermaid ```` fences, each with a one-line cited caption.
- Never edit `facts.json`. Never weaken the Check to make it pass: fix the document.

## Source-to-claim audit

Before running the Check, verify that every Cited claim is actually **supported** by the lines you cited. This audit is separate from the Check and is not the Check. The Check verifies **resolution** (each Citation points to a real file and line); the audit verifies **support** (the cited lines actually back the claim). A citation that resolves but does not support its claim is a **defect**, not a pass.

- For every factual paragraph, list item, and table row in sections 3 to 10, open the cited source span and confirm it supports the exact claim. Identify whether the claim comes from code, repository documentation, or owner context.
- When a cited line does not support the claim, treat it as a defect: correct the claim to match the source, downgrade it to **Inferred** (state what it rests on), or move it to section 14 as **Unknown**. Never leave a Cited claim that the source does not back.
- Trace behavior through the code that controls the result, including relevant callers, model/service logic, and success or error paths. A route, Facts record, or nearby call site may not establish the outcome.
- Read build and deployment configuration job by job. Keep restore, build, test, package, and deploy steps attributed to the job that actually runs them.
- Do not infer why a file was excluded or a behavior is absent. State that it was not reviewed unless an explicit policy source supports the reason; otherwise record the reason as Unknown.
- Keep inferences visibly marked and list unresolved questions in section 14. An empty Facts list or a passing Check is not evidence that a behavior does not exist or that the Narrative is factually correct.
- Never copy secret values into the Narrative. If source contains a credential, redact it in documentation and report the source exposure separately; documentation redaction does not remediate the credential.
- **Record the audit.** Write the outcome to `<target>/docs/appdoc/verification.md`: a one-line summary (claims re-verified, claims corrected, claims downgraded to Inferred/Unknown) plus each correction as section + claim + what changed; if you audited nothing, say the audit was not performed. The Check reads this file and surfaces it in the Check report's Verification section; a missing file is a noted gap, not a Check failure.

## Large Targets

Read `facts-summary.md` and work subsystem by subsystem. For each folder in the top-folders table, pull its entry points and data access from `facts.json`, read the files that matter, and write that part of sections 4 to 8 before moving on. Do not try to read the whole Target.

## When a Stack is not supported

Facts for it are generic only (files, dependencies, config keys, secret locations). Say so in section 2, rely on reading source, and mark what you could not establish as Unknown. To add a Stack, see "Add a Stack" in `README.md`.

## What the Check enforces

C1 every Citation resolves to a real file and line. C2 section 10 Citations have lines. C3 all 16 sections exist and have content. C4 gaps are declared in section 14. C5 each paragraph in sections 3 to 10 is cited, Inferred or Unknown. C6 no secret-shaped strings and no `never-mention` terms. C7 unsupported Stacks are named in section 2. The Check verifies **resolution and structure** only; it does **not** verify that a cited line supports the claim, that section 1 links work, or that Mermaid syntax is valid. **Support** is the source-to-claim audit (step 4): it is recorded in `docs/appdoc/verification.md` and surfaced in the report's Verification section. Do not present a PASS as an accuracy certification. The result is in `check-report.md`, which also holds the Citation register.

## Owner context (optional)

The owner may add `<target>/appdoc-context.md` with purpose, owners, environments and known history. Cite it as `` `appdoc-context.md` ``. A fenced block with info string `never-mention` lists internal terms (one per line) that must not appear in the document.
