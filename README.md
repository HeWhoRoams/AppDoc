# AppDoc

AppDoc is a template-driven documentation automation system designed to extract, analyze, and generate comprehensive documentation for any codebase. It is built for extensibility, auditability, and non-destructive workflows, making it ideal for teams seeking reliable, versioned documentation.

## Key Features
- **Template-Based Architecture:** All documentation is generated using Markdown templates found in `appdoc.templates/`. This ensures consistency and easy customization.
- **Multi-Stage Workflow:** The system uses workflow prompts (in `.github/prompts/`) to orchestrate multi-phase documentation processes, including analysis, drafting, and auditing.
- **Non-Destructive Principle:** Data gaps and uncertainties are preserved as placeholders, never overwritten or fabricated, ensuring traceable and actionable documentation.
- **Version Tracking:** Documentation versions are managed and tracked, supporting incremental updates and historical audits.

## Directory Structure
- `appdoc.templates/`: Core Markdown templates for architecture, audit reports, logic/workflows, documentation tasks, and troubleshooting playbooks.
- `.github/prompts/`: Workflow prompt files that drive documentation automation and agent behavior.
- `.github/copilot-instructions.md`: Persistent instructions for AI coding agents, detailing conventions, workflow mandates, and integration points.

## How It Works
1. **Select a Template:** Choose the appropriate template from `appdoc.templates/` for your documentation need.
2. **Run Workflow Prompt:** Use the relevant prompt in `.github/prompts/` to guide the documentation process.
3. **Generate Output:** Documentation is produced in Markdown, strictly following the template structure and conventions.
4. **Audit & Update:** Use audit templates and version tracking to review and improve documentation over time.

## Project Conventions
- All documentation is Markdown-based and must conform to the structure defined in the templates.
- Section headers, data fields, and formatting are strictly enforced for consistency.
- Placeholders follow the `$<SOURCE_TYPE>_<DATA_TYPE>_<NAME>[CONFIDENCE:LEVEL]` pattern for traceability.

## Integration & Extensibility
- The system is file-based with no external dependencies or build/test scripts required.
- New documentation types can be added by creating new templates in `appdoc.templates/` and updating workflow prompts as needed.

## Example Templates
- `appdoc.templates/architecture.template.md`: For architectural summaries.
- `appdoc.templates/audit.report.template.md`: For audit reports and metrics.
- `appdoc.templates/logic-and-workflows.template.md`: For documenting functions, classes, and workflows.
- `appdoc.templates/documentation.tasks.template.md`: For tracking documentation tasks and remediation.
- `appdoc.templates/troubleshooting.playbook.template.md`: For troubleshooting guides and operational playbooks.

## Getting Started
1. Review the templates in `appdoc.templates/` to understand documentation structure.
2. Read `.github/copilot-instructions.md` for agent guidance and workflow details.
3. Use or modify workflow prompts in `.github/prompts/` to automate documentation generation.

---
_Last updated: October 22, 2025_
