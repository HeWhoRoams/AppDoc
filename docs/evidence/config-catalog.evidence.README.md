# Why is config-catalog.evidence.json committed?

The generated evidence artifact `config-catalog.evidence.json` is committed to version control for several important reasons:

- **Audit and Compliance Retention:** Retaining generated evidence artifacts ensures a verifiable audit trail for configuration discovery and compliance reviews, even if the codebase or generator changes over time.
- **Reproducibility:** Committed evidence provides a stable reference point for CI/CD pipelines, code reviews, and external audits, allowing others to verify that the configuration catalog matches the state of the codebase at a specific commit.
- **CI Snapshotting:** Automated workflows and quality gates can compare committed evidence with newly generated output to detect drift, regressions, or unintentional changes.

**Regeneration Workflow:**
- To update the evidence, run the generator script (`.appdoc/scripts/powershell/generate-config-catalog.ps1`) with the appropriate root path.
- Review the changes and commit the updated artifact only if the changes are intentional and verified.
- In normal development, do not ignore or delete this file; only remove it if the artifact is deprecated or replaced by a new evidence model.

**Maintainer Guidance:**
- Always review diffs in evidence artifacts before committing.
- Only commit regenerated evidence when it reflects a real, intended change in the codebase or configuration model.
- If in doubt, consult project documentation or leads before removing or ignoring evidence files.
