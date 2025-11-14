# AppDoc Begin Prompt

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## CRITICAL EXECUTION DIRECTIVE

**YOU MUST EXECUTE ALL PHASES CONTINUOUSLY WITHOUT PAUSING FOR USER INPUT.**

Do not ask "What would you like to do next?" or wait for confirmation between phases.
Execute Phase 0 → Phase 1 → Phase 2 → Phase 3 → Phase 4 → Phase 5 → Phase 6 in a single continuous workflow.
Only stop if a critical error prevents continuation.

## Workflow Overview

This prompt orchestrates the comprehensive AppDoc workflow by:
1. Reviewing all documentation templates in the `AppDoc/.AppDoc/templates/` directory.
2. Executing a series of PowerShell scripts that analyze the codebase and generate documentation.
3. Creating copies of templates in the target documentation directory.
4. Recursively and iteratively populating documentation with code-derived content.
5. Running all 6 phases of analysis, generation, validation, and assessment directly in this single prompt WITHOUT PAUSING.

## Execution Mode

**CONTINUOUS EXECUTION REQUIRED**: Execute all phases sequentially without stopping. Do not prompt user between phases.

## Outline

**EXECUTE THESE PHASES IN ORDER WITHOUT STOPPING:**

1. **Initialization & Context Setup**
   - Parse `$ARGUMENTS` to identify:
     - Target codebase root path (required). This is the first argument.
     - Target documentation output directory (default: `docs/`). This is the second argument (optional).
     - Any special analysis flags or filters (optional).
   - Validate paths and accessibility.
   - Set environment variables:
     - `$ROOT_PATH` = target codebase root path
     - `$OUTPUT_DIR` = documentation output directory (default: `docs/`)
     - `$TEMPLATE_DIR` = `.AppDoc\templates\`
     - `$SCRIPTS_DIR` = `.AppDoc\scripts\powershell\`

 Reviewing all documentation templates in the `appdoc/.appdoc/templates/` directory.
   
   **ACTION**: Run ALL 4 analysis scripts below, then immediately proceed to Phase 1.
   
   Run analysis scripts from `$SCRIPTS_DIR` to understand codebase structure:
   
   a. **Analyze Repository Structure**
      ```powershell
      cd $ROOT_PATH ; .\.AppDoc\scripts\powershell\analyze-repository.ps1 -RootPath $ROOT_PATH
      ```
      Parse JSON output for: file types, directory structure, language detection, project type.
   
   b. **Analyze Codebase Metrics**
      ```powershell
      cd $ROOT_PATH ; .\.AppDoc\scripts\powershell\analyze-codebase.ps1 -RootPath $ROOT_PATH -Json
      ```
      Parse JSON output for: code metrics, complexity, architecture patterns.
   
   c. **Extract Configuration**
      ```powershell
      cd $ROOT_PATH ; .\.AppDoc\scripts\powershell\extract-config.ps1 -RootPath $ROOT_PATH
      ```
      Parse JSON output for: config files, environment variables, settings.
   
   d. **Generate Dependency Graph**
      ```powershell
      cd $ROOT_PATH ; .\.AppDoc\scripts\powershell\generate-dependency-graph.ps1 -RootPath $ROOT_PATH
      ```
      Parse JSON output for: dependencies, relationships, module structure.
   
   **CRITICAL**: For single quotes in args like "I'm Groot", use escape syntax: e.g `'I'\''m Groot'` (or double-quote if possible: `"I'm Groot"`).

3. **Phase 1: SKIPPED - Template Initialization Automated**
   
   **ACTION**: Proceed directly to Phase 2. Each generator script automatically copies its template on first run.
   
   Note: All generators now use `template-helpers.ps1` module which calls `Initialize-TemplateFile` to copy templates
   from `.AppDoc/templates/` to `docs/` if they don't already exist. This ensures consistent document structure
   while allowing generators to populate placeholders with extracted data.

4. **Phase 2: Documentation Generation (Template Population)**
   
   **CRITICAL**: You MUST run ALL 8 generator scripts below. DO NOT SKIP ANY. Each script:
   1. Copies its template from `.AppDoc/templates/` (if output doesn't exist)
   2. Extracts data from the codebase
   3. Replaces template placeholders with extracted content
   4. Writes the populated documentation file
   
   **ACTION**: Execute ALL commands below in sequence, then immediately proceed to Phase 3.
   
   **Run these commands in order:**
   
   a. **Generate Overview** (REQUIRED)
      ```powershell
      .\.AppDoc\scripts\powershell\generate-overview.ps1 -RootPath .
      ```
   
   b. **Generate API Inventory** (REQUIRED)
      ```powershell
      .\.AppDoc\scripts\powershell\generate-api-inventory.ps1 -RootPath .
      ```
   
   c. **Generate Data Model** (REQUIRED)
      ```powershell
      .\.AppDoc\scripts\powershell\generate-data-model.ps1 -RootPath .
      ```
   
   d. **Generate Config Catalog** (REQUIRED)
      ```powershell
      .\.AppDoc\scripts\powershell\generate-config-catalog.ps1 -RootPath .
      ```
   
   e. **Generate Build Cookbook** (REQUIRED)
      ```powershell
      .\.AppDoc\scripts\powershell\generate-build-cookbook.ps1 -RootPath .
      ```
   
   f. **Generate Test Catalog** (REQUIRED)
      ```powershell
      .\.AppDoc\scripts\powershell\generate-test-catalog.ps1 -RootPath .
      ```
   
   g. **Generate Debt Register** (REQUIRED)
      ```powershell
      .\.AppDoc\scripts\powershell\generate-debt-register.ps1 -RootPath .
      ```
   
   h. **Generate Dependencies Catalog** (REQUIRED)
      ```powershell
      .\.AppDoc\scripts\powershell\generate-dependencies-catalog.ps1 -RootPath .
      ```
   
   **VERIFICATION**: After running all generators, verify each file has content (not just a header):
   - docs/overview.md
   - docs/api-inventory.md
   - docs/data-model.md
   - docs/config-catalog.md
   - docs/build-cookbook.md
   - docs/test-catalog.md
   - docs/debt-register.md
   - docs/dependencies-catalog.md
   
   If any file shows "0 items detected" or is nearly empty, that's EXPECTED for some codebases.
   The generators explicitly report when nothing is found.

5. **Phase 3: Validation**
   
   **ACTION**: Run validation scripts to verify generated documentation quality. Continue immediately to Phase 4 after completion.
   
   Run all 7 validation scripts (optional but recommended):
   
   a. **Validate Overview**
      ```powershell
      .\.AppDoc\scripts\powershell\validate-overview.ps1 -RootPath .
      ```
   
   b. **Validate API Inventory**
      ```powershell
      .\.AppDoc\scripts\powershell\validate-api-inventory.ps1 -RootPath .
      ```
   
   c. **Validate Data Model**
      ```powershell
      .\.AppDoc\scripts\powershell\validate-data-model.ps1 -RootPath .
      ```
   
   d. **Validate Config Catalog**
      ```powershell
      .\.AppDoc\scripts\powershell\validate-config-catalog.ps1 -RootPath .
      ```
   
   e. **Validate Build Cookbook**
      ```powershell
      .\.AppDoc\scripts\powershell\validate-build-cookbook.ps1 -RootPath .
      ```
   
   f. **Validate Test Catalog**
      ```powershell
      .\.AppDoc\scripts\powershell\validate-test-catalog.ps1 -RootPath .
      ```
   
   g. **Validate Debt Register**
      ```powershell
      .\.AppDoc\scripts\powershell\validate-debt-register.ps1 -RootPath .
      ```
   
   **Note**: Validation failures are informational - they help identify quality issues but don't block workflow completion.

6. **Phase 4: Assessment & Reporting**
   
   b. **Synthesize Assessment Report**
      ```powershell
      .\.AppDoc\scripts\powershell\synthesize-assessment-report.ps1 -RootPath .
      ```
   
   c. **List Generated Documentation Files:**
      ```powershell
      Get-ChildItem -Path "docs" -Filter "*.md" | ForEach-Object { "$($_.Name) - $([math]::Round($_.Length/1KB,2)) KB" }
      ```
   
   **WORKFLOW COMPLETE** - Report the number of files generated and total documentation size.
   Do not ask for next steps or validation - the workflow is finished.

## General Guidelines

- Focus on **WHAT** the system does and **WHY** it matters.
- Avoid HOW to implement (no tech stack, APIs, code structure unless required for documentation clarity).
- Written for business and technical stakeholders.
- Remove any sections that do not apply (do not leave as "N/A").
- Use absolute paths for all file operations.
- Mark unresolved clarifications with [NEEDS CLARIFICATION: ...] (max 3 per file).
- **CRITICAL**: For single quotes in PowerShell args like "I'm Groot", use escape syntax: `'I'\''m Groot'` (or double-quote if possible: `"I'm Groot"`).

## Script Execution Rules

1. **Always use absolute paths** when calling PowerShell scripts
2. **Parse JSON output** from scripts that use `-Json` flag
3. **Error handling**: If a script fails, document the error and continue with next phase where possible
4. **Script parameters**: All generator scripts accept `-RootPath` parameter pointing to target codebase
5. **Output directory**: Generators write to `docs/` (relative to RootPath) by default

## Prompt Delegation Model

**This prompt is fully self-contained and executes continuously** - it directly executes all PowerShell scripts across 3 active phases without delegating to another prompt and WITHOUT PAUSING.

**CONTINUOUS EXECUTION FLOW (NO STOPS):**
1. Parse arguments and setup environment variables
2. Phase 0: Run 4 analysis scripts → **immediately continue**
3. Phase 1: SKIP (generators handle templates)
4. Phase 2: Run 8 generator scripts → **immediately continue**
5. Phase 3: Run 7 validation scripts → **immediately continue**
6. Phase 4: Run 2 assessment scripts and display results → **DONE**

**CRITICAL**: Do NOT ask "What would you like to do next?" or similar questions between phases. Execute all phases in one continuous workflow.

**Note**: The `AppDoc.plan.prompt.md` file provides detailed phase documentation but is not invoked during execution. All script execution happens directly in this prompt.


Example:
```
/AppDoc.begin c:\myproject
/AppDoc.begin c:\myproject c:\myproject\docs --deep-analysis
```

## Phase Overview (Directly Executed)
| 2 | Primary Generation | Execute 8 generator scripts to populate documentation with extracted content |
| 3 | Validation | Run 7 validation scripts to verify documentation quality |
  ├─ config-catalog.md           (~10-18 KB)
  ├─ build-cookbook.md           (~12-20 KB)
  ├─ test-catalog.md             (~10-15 KB)
  ├─ debt-register.md            (~8-15 KB)
  └─ assessment-report.md        (~5-10 KB)
```

## Key Success Criteria

- ✓ All 8 generator scripts executed successfully
- ✓ All documentation files created in docs/ folder  
- ✓ Content extracted from actual codebase (populated from templates)
- ✓ Files with "0 items detected" are acceptable (indicates no content of that type exists)
- ✓ All 7 validation scripts run (validation failures are informational only)
- ✓ Assessment report generated showing file sizes and coverage
- ✓ No errors that block workflow completion

## Final Step

**The AppDoc workflow has been completed successfully!**

Your documentation artifacts are now ready in the `docs/` folder. However, they represent a **v0.9 machine-generated draft** that captures raw data from your codebase.

**To transform these artifacts into production-ready documentation**, you are now ready to execute:

```
/AppDoc.enhance
```

The enhance prompt will:
- Synthesize all generated artifacts with your existing documentation and codebase context
- Correct inaccuracies and fill gaps with code-verified information
- Reorganize content into clear, logical flows with proper data flow diagrams
- Transform technical outputs into human-friendly, operationally useful documentation
- Ensure accuracy over style, with explicit flags for any uncertainties

**Next Action**: Run `/AppDoc.enhance` to create your final, production-ready documentation.

## Example Output

- `docs/overview.md` (~10-15 KB) [landing page with navigation]
- `docs/api-inventory.md` (~15-25 KB)
- `docs/data-model.md` (~12-20 KB)
- `docs/config-catalog.md` (~10-18 KB)
- `docs/build-cookbook.md` (~12-20 KB)
- `docs/test-catalog.md` (~10-15 KB)
- `docs/debt-register.md` (~8-15 KB)
- `docs/assessment-report.md` (~5-10 KB)

---

**Generated by AppDoc Begin Prompt**
