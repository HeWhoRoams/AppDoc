## Summary

<!-- What changed and why. -->

## Checklist

- [ ] If this changes a build step, a gate, an exit code or the order of steps, the matching page under `docs/pipeline/` is updated in this pull request (`gates.md` for criteria and exit codes, the stage page for steps).
- [ ] If this fixes a known gap (`P-` or `T-` tag), the tag is removed from `docs/pipeline/gates.md` and from the pages that show it.
- [ ] `./.appdoc/scripts/powershell/ci-pipeline-docs-gate.ps1 -RootPath .` passes.
- [ ] `pwsh -NoProfile -File tests/powershell/test-output-snapshot.ps1` passes, or the baseline under `tests/powershell/snapshots/` is updated in this pull request and the description says which output changed and why.
