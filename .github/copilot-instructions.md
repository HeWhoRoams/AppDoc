Copilot Instructions for AppDoc (v3.5 Workflow Context)

[TARGET AUDIENCE & PURPOSE] 🎯

This file supplies persistent workspace context to guide Copilot Chat's behavior, tailoring its responses to align with the Non-Destructive Documentation Workflow and the specific constraints of the Full-Stack Automation Agent.

1. Key Directories & Template Roles 📁

The system relies on three files in the appdoc.templates/ directory to control ALL documentation output structure.

Template Roles (Mandatory Reference)

    appdoc.templates/architecture.template.md: Initial Analysis/Input Constraint. Defines the structure for the codebase's architectural summary.

    appdoc.templates/logic-and-workflows.template.md: Drafting Constraint. Defines the required structure and style for function/class documentation (logic-and-workflows.md).

    appdoc.templates/audit.report.template.md: Final Output Constraint. Defines the structure and mandatory metrics for the final Audit Report.

Workflow Prompts

    .github/prompts/: Contains the master executable prompt (appdocument.workflow.prompt.md) that drives the multi-stage documentation process.

2. Core Workflow Mandate & AI Bias 🔄

The primary workflow is a three-phase, non-destructive cycle designed to maximize content extraction while maintaining a prioritized remediation plan.

Non-Destructive Principle (CRITICAL)

    Data Gaps: When extracting data from a codebase, if the value is uncertain or missing, the agent MUST adhere to the non-destructive principle: leave the original placeholder text (e.g., <owner_team>) untouched in the final document.

    Remediation Routing: Remediation notes, tasks, or incomplete data MUST NOT be written into the final documentation. All gaps are routed to the separate Documentation Tasks.md file.

Agent Logic Bias

    Priority Logic: Responses should respect the established priority system: P0 (Security/Critical Logic), P1 (Core Documentation), P2 (Ambiguity/Partial), P3 (Low/Style).

    Traceability: The agent uses an internal `` tagging mechanism during drafting for validation. This tag MUST NOT be present in any final, user-facing documentation output.

3. Project-Specific Conventions & Constraints ⚙️

    Format: All documentation is Markdown-based.

    Consistency: Section headers, data fields, and the overall structure defined in the templates are strictly enforced.

    Naming Convention: Placeholder extraction should be guided by the $<SOURCE_TYPE>_<DATA_TYPE>_<NAME> pattern (e.g., <CONFIG_STRING_DB_ENDPOINT>).

    Style: All generated prose for function/class logic must adhere to the Peer-Review Style Guide (Active Voice, Consistent Simple Present Tense).

4. Integration Points & Status

    Current State: The system is entirely file-based. No external dependencies or build commands are present or required for the AppDoc codebase itself.

    Future State: Any external dependencies (e.g., CI/CD triggers, external APIs) must be documented here if they are integrated into the workflow execution.

Last updated: October 21, 2025