---
name: appdoc
description: Document an unfamiliar or legacy codebase for a human developer. Extracts reproducible Facts with Python scripts, then writes a cited Markdown document from a fixed Template, checks it, and renders HTML. Use when asked to document, inventory, or onboard someone to an application.
---

# AppDoc

Produces onboarding documentation for a **Target** (the codebase being documented). Scripts extract **Facts** (what exists, with `file:line`). You write the **Narrative** from them. A **Check** verifies it. Read `CONTEXT.md` for the exact terms.

`SKILL_DIR` below is the folder that contains this file. Requires Python 3.10+ (standard library only). On Windows use `py -3` if `python` is not on PATH.

## Run

1. **Extract.** From `SKILL_DIR`:
   `python -m appdoc extract <target>`
   Writes `<target>/docs/appdoc/facts.json` and `facts-summary.md`. Re-running gives identical output.
2. **Orient.** Read `facts-summary.md` first. If `<target>/appdoc-context.md` exists, read it: it is the owner's notes (purpose, owners, environments) and the only source for things the code cannot show. Then drill into `facts.json` by kind or folder, and open source files to understand behavior.
3. **Write.** Copy `SKILL_DIR/appdoc/assets/template.md` to `<target>/docs/appdoc/application-documentation.md` and fill every section, keeping all 16 headings in order.
4. **Check.** `python -m appdoc check <target>`. Fix every problem it lists and run it again. After 3 failed checks, stop and report the remaining problems to the user verbatim.
5. **Render.** `python -m appdoc render <target>`. Writes `application-documentation.html` next to the Markdown.
6. **Tell the user** where the files are and whether the Check passed.

Optional flags: `--out DIR` (inside the target) on every command; `--css FILE` on `render` to replace the theme.

## Writing rules

- **Cite everything.** A Citation is a backticked Target-relative path, with a line where the claim is specific: `` `portal/verify.asp:6` ``, `` `src/App.java:40-52` ``, `` `portal/HelpWeb/search.asp` ``. Routes (`/api/x`) and absolute paths are not Citations.
- **Section 10 (Security and Operational Risks): every Citation needs a line.**
- **Three claim statuses only.** *Cited* (has a Citation), *Inferred* (start the paragraph or item with `**Inferred:**` and still cite what it rests on), *Unknown* (list it in section 14; elsewhere write "Unknown - see Open questions.").
- **Never write a secret value**: passwords, tokens, keys, connection-string credentials. Write "value omitted" and cite the location. The Check scans for secret shapes and fails.
- Do not invent owners, environments, deployment steps or business purpose. If the code and `appdoc-context.md` do not say, it is Unknown.
- Read source for the parts that need explanation (workflows, error handling, security findings). The Facts tell you where to look; they do not replace reading.
- Section 7 (Workflows) has no fixed subsections: name each `###` after a real workflow in the Target. Write it and section 1 (Index) last.
- Name every unsupported Stack (listed in the Facts summary) in section 2.
- Put diagrams in ```` ```mermaid ```` fences, each with a one-line cited caption.
- Never edit `facts.json`. Never weaken the Check to make it pass: fix the document.

## Large Targets

Read `facts-summary.md` and work subsystem by subsystem. For each folder in the top-folders table, pull its entry points and data access from `facts.json`, read the files that matter, and write that part of sections 4 to 8 before moving on. Do not try to read the whole Target.

## When a Stack is not supported

Facts for it are generic only (files, dependencies, config keys, secret locations). Say so in section 2, rely on reading source, and mark what you could not establish as Unknown. To add a Stack, see "Add a Stack" in `README.md`.

## What the Check enforces

C1 every Citation resolves to a real file and line. C2 section 10 Citations have lines. C3 all 16 sections exist and have content. C4 gaps are declared in section 14. C5 each paragraph in sections 3 to 10 is cited, Inferred or Unknown. C6 no secret-shaped strings and no `never-mention` terms. C7 unsupported Stacks are named in section 2. The result is in `check-report.md`, which also holds the Citation register.

## Owner context (optional)

The owner may add `<target>/appdoc-context.md` with purpose, owners, environments and known history. Cite it as `` `appdoc-context.md` ``. A fenced block with info string `never-mention` lists internal terms (one per line) that must not appear in the document.
