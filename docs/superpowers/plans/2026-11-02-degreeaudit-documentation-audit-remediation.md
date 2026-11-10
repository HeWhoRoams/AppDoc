# DegreeAudit Documentation Audit Remediation Implementation Plan

> **For agentic workers:** Implement the tasks in order. Keep the DegreeAudit target changes separate from the AppDoc skill changes, preserve existing user work, and do not expose credential values in output.

**Goal:** Correct the identified DegreeAudit documentation inaccuracies, address the hard-coded credential risk with the target owner, and strengthen AppDoc's workflow so future generated documentation receives a semantic accuracy review in addition to the automated Check.

**Architecture:** Keep AppDoc's automated Check responsible for structural and resolvable-citation rules; do not imply that it proves citation support. Add an explicit source-to-claim audit to the skill workflow, then correct the DegreeAudit document from direct source evidence and regenerate its HTML. Treat the hard-coded credential as a separate operational security remediation that requires owner coordination and rotation through the approved secret-management process.

**Tech Stack:** Markdown, Python 3.10+ standard library (`run_appdoc.py`), existing DegreeAudit C# and GitLab CI configuration.

**Spec:** Findings from the DegreeAudit documentation review in this conversation: unsupported attribution of the `Web.config` exclusion to organizational policy; inaccurate description of the CI build job; a transfer-configuration troubleshooting citation that does not point to the code setting the error; a hard-coded SAP credential in source; and the gap between citation resolution and citation support.

## Global Constraints

- Never include the credential value in documentation, plan updates, logs, screenshots, or review output.
- Never edit or weaken `docs/appdoc/facts.json` or AppDoc Check rules to make the document pass.
- Distinguish an observed fact, an owner-confirmed explanation, an inference, and an unknown.
- Keep DegreeAudit target changes under `C:\Github\DegreeAudit` and AppDoc skill changes under `C:\Github\Appdoc`.
- Preserve unrelated or pre-existing changes in both repositories.
- Do not claim the automated Check validates whether a citation supports its claim.

## Review Focus

- Facts were generated from a recorded commit; if DegreeAudit has moved since then, refresh Facts and re-evaluate claims against the current source.
- Excluded or inaccessible configuration: state only that it was not reviewed unless an owner or policy document substantiates why.
- Multiple CI jobs: describe each job's actual commands and purpose; do not combine restore, build, and deploy steps under one job name.
- Error behavior: trace the code that constructs and returns the view model, not just the controller branch that renders it.
- Hard-coded credential: treat it as exposed; verify active status with the owner and rotate it through the approved process without reproducing it.

---

## Task List

### Task 1: Confirm the DegreeAudit baseline

**Files:** Read-only inspection of `C:\Github\DegreeAudit\docs\appdoc\facts-summary.md`, `facts.json`, generated documents, and cited source.

- [ ] Check the DegreeAudit working tree and current commit against the commit recorded in `facts-summary.md`.
- [ ] If the source commit changed, rerun AppDoc extraction before changing the narrative; inspect the resulting Facts summary and do not carry forward stale claims without revalidation.
- [ ] Record the current Check result and preserve any pre-existing edits to the target.

**Acceptance:** The document edits are based on the same source revision as the Facts, or the Facts have been refreshed and reviewed.

**Verification:** Compare `git rev-parse HEAD` with the commit recorded in the Facts summary; inspect `git status --short` before editing.

### Task 2: Correct unsupported and inaccurate claims

**Files:** Modify `C:\Github\DegreeAudit\docs\appdoc\application-documentation.md`.

- [ ] In section 2.1, remove “by the organization content policy” unless the owner supplies a policy citation. Otherwise say only that `Web.config` was not reviewed and identify resulting unknowns.
- [ ] In section 16, describe `.gitlab-ci.yml` jobs separately: the `build` job restores NuGet packages; deployment jobs invoke MSBuild for environment-specific publishing; NuGet packaging jobs build the shared library. Cite the exact lines for each distinct job and command.
- [ ] In section 9, cite `CMich.DegreeAudit.Web/Areas/TransferBlock/ViewModels/TBEvalViewModel.cs:209-211` for the missing transfer configuration error. Keep controller citations only for behavior the controller itself establishes.
- [ ] Re-read each changed paragraph against its cited source. Retain the existing cautious statement about Perceptive Content unless code or owner-provided evidence establishes the handoff mechanism.

**Acceptance:** No unsupported policy attribution remains; CI activities are assigned to the correct jobs; the transfer error claim cites the implementation that sets the error.

**Verification:** Review each edited Markdown claim against its source lines, then run the AppDoc Check in Task 5.

### Task 3: Remediate the exposed credential

**Files:** `C:\Github\DegreeAudit\CMich.DegreeAudit.Web\Global.asax.cs`, the approved secret/configuration mechanism for the target, and any deployment configuration required by that mechanism.

- [ ] Notify the DegreeAudit owner/security contact that a credential is hard-coded in source; do not paste its value into the notification or this plan.
- [ ] Have the owner determine whether it is active and rotate it through the approved process. Treat it as exposed regardless of whether current validity can be confirmed.
- [ ] Replace the source constant with the approved runtime secret/configuration mechanism and update deployment configuration without committing the secret.
- [ ] Verify all build configurations and deployment environments receive the new value and that application startup still initializes SAP credentials.
- [ ] Search tracked files and generated documentation for accidental copies of the old value without printing matching content.

**Acceptance:** No credential literal remains in tracked application source; the approved secret source is used at runtime; rotation and deployment are confirmed by the owner.

**Verification:** Run the target's relevant build/tests and a content-safe secret scan. Do not include secret-shaped matches in terminal output or reports.

**Dependency:** Owner/security coordination is required before changing credential provisioning. If the owner or approved secret mechanism is unavailable, leave this task explicitly blocked and report it as an outstanding risk; do not invent a replacement configuration path.

### Task 4: Add an accuracy gate to the AppDoc skill

**Files:** Modify `C:\Github\Appdoc\SKILL.md`; update `README.md` only if its description of Check scope needs clarification.

- [ ] Add a required “Accuracy review” before Check/render: for every substantive claim, open the cited source and verify that it supports that exact claim; distinguish source code, repository documentation, owner context, inference, and unknowns.
- [ ] Require tracing behavior through the controlling implementation, including relevant success and error paths, rather than relying only on a route, call site, Facts record, or nearby controller.
- [ ] Require CI/build/deployment claims to be checked job-by-job against the pipeline commands and names.
- [ ] Prohibit attributing exclusions, policy decisions, ownership, or intent without explicit evidence; use Unknown or neutral wording when evidence is absent.
- [ ] Keep the Check's limitation explicit: it verifies citation resolution and structure, not semantic support. Do not present a PASS as an accuracy certification.
- [ ] Preserve the current secret-redaction rule and make clear that redaction in documentation does not remediate an exposed source credential.

**Acceptance:** The skill workflow includes a mandatory, actionable source-to-claim review and cannot equate Check PASS with factual accuracy.

**Verification:** Manually walk the DegreeAudit findings against the revised checklist and confirm each finding maps to a skill rule.

### Task 5: Recheck and regenerate the DegreeAudit artifacts

**Files:** Regenerate `C:\Github\DegreeAudit\docs\appdoc\check-report.md` and `application-documentation.html` from the corrected Markdown. Do not edit `facts.json` by hand.

- [ ] Run `py -3 C:\Users\niles1tj\.copilot\skills\appdoc\run_appdoc.py check C:\Github\DegreeAudit` and fix every reported problem in the document.
- [ ] Run `py -3 C:\Users\niles1tj\.copilot\skills\appdoc\run_appdoc.py render C:\Github\DegreeAudit` after Check passes.
- [ ] Review all 16 sections, each changed source citation, all Mermaid diagrams, section 1 anchors, and the final HTML. Confirm the HTML corresponds to the corrected Markdown.
- [ ] Confirm no secret value appears in either generated artifact. Record the security remediation status separately from document Check status.

**Acceptance:** AppDoc Check passes; Markdown claims are source-supported or explicitly Inferred/Unknown; HTML reflects the Markdown; no secret value is present in generated files.

**Verification:** Run the exact Check and render commands above, then inspect the resulting Check report and rendered HTML.

## Risks and Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| DegreeAudit source has changed since Facts were generated | Citations may resolve but support different behavior | Compare the current commit with the Facts commit; re-extract and re-review if they differ |
| Credential rotation requires production coordination | Application startup or integrations could fail if configuration is changed without deployment alignment | Coordinate with the owner/security contact and validate each environment before rollout |
| Semantic review is manual | Future claims can still be wrong despite resolved citations | Make source-to-claim inspection mandatory and report the Check as structural validation only |
| Web.config policy rationale is owner-specific | Removing the rationale may leave less context | Ask the owner for a citable policy source; otherwise retain neutral wording and list the reason as unknown |

## Open Questions

- Is the source credential active, and who owns its rotation and deployment?
- Which approved secret/configuration mechanism should DegreeAudit use across its environments?
- Is there a documented organizational policy that requires excluding `Web.config` from inspection? If so, where can it be cited?