# Documentation Tasks (Template)

---
# METADATA
---
title: "Documentation Tasks"
app: "$ARGUMENTS"
template: "documentation.tasks.template.md"
version: "2.0"
generated_by: "AppDoc Agent"
generated_at: "$DATE_GENERATED"
---

## Tasks (One entry per unresolved placeholder / issue)

Follow this exact task structure for every task created by the agent:

- **PRIORITY:** [P0 / P1 / P2 / P3]  
- **TASK:** [Action-oriented verb phrase. Max 10 words.]  
- **FILE/PLACEHOLDER:** [document.md / $PLACEHOLDER_TEXT]  
- **STATUS:** [To Do / Blocked / Auto-Resolved]  
- **SOURCE/LINE:** [file:line or N/A]  
- **SEARCH/ACTION:** [Specific action required or value discovered]  
- **JUSTIFICATION (If Blocked):** [If Blocked, brief reason]  

---

## Task Generation Rules (Agent MUST follow)

1. Create one task per unfilled placeholder.
2. Tasks for P0 items (security / critical) must be flagged as P0 and noted in the Audit Report.
3. The `TASK` sentence must be action-oriented and short (<= 10 words).
4. For `Auto-Resolved` tasks, include the injected value in `SEARCH/ACTION`.
5. Keep tasks atomic — do not combine multiple fixes into a single task.

*(end of tasks template)*
