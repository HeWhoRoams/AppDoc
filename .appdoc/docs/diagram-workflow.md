# C4 Diagram Generation Workflow

## Overview

AppDoc uses a **three-step workflow** to create high-quality C4 architecture diagrams. This separation ensures reliability, flexibility, and AI-enhanced accuracy.

## Workflow Steps

### Step 1: Generate Baseline PlantUML (Deterministic)

**Script**: `generate-c4-diagrams.ps1`

**Purpose**: Analyze codebase and generate baseline `.puml` source files

**How it works**:
- Parses solution files and project references
- Detects containers (projects) and their types
- Identifies external systems via NuGet packages
- Analyzes project dependencies for relationships
- Generates valid PlantUML syntax with C4-PlantUML library

**Command**:
```powershell
.\\.appdoc\scripts\powershell\generate-c4-diagrams.ps1 `
    -CodebasePath ".\MySolution.sln" `
    -OutputPath ".\docs" `
    -RenderMode SourceOnly `
    -DiagramLevels All
```

**Output**: `.puml` files in `docs/diagrams/`
- `c4-context.puml` - System Context diagram (Level 1)
- `c4-container.puml` - Container diagram (Level 2)
- `c4-component.puml` - Component diagram (Level 3, future)

**Characteristics**:
- ✅ **Never fails** - Deterministic script-based analysis
- ✅ **Version controllable** - Text-based `.puml` files
- ⚠️ **Generic descriptions** - Limited to code structure analysis
- ⚠️ **Missing context** - Can't infer business purpose or external actors

---

### Step 2: AI Enhancement (Intelligent)

**Command**: `/appdoc.diagrams` (GitHub Copilot Chat)

**Purpose**: Enhance `.puml` files with codebase intelligence and business context

**How it works**:
- Analyzes README, documentation, and code comments
- Searches for connection strings, HTTP clients, API endpoints
- Identifies external systems (databases, APIs, file shares)
- Discovers actors (users, administrators, external systems)
- Adds technology-specific details (versions, protocols, data flows)
- Updates `.puml` files in place with evidence-based improvements

**Prerequisites**:
- Baseline `.puml` files from Step 1
- Codebase open in VS Code workspace
- GitHub Copilot enabled

**What gets enhanced**:
- ✅ System/container descriptions → Business-meaningful purposes
- ✅ Generic "Database" → "SQL Server Database (CourseAudit, MembershipAudit tables)"
- ✅ "Uses" relationships → "Reads/writes enrollment data via ADO.NET"
- ✅ Missing external actors → Added (Admin, SAP PPF, End Users)
- ✅ Missing external systems → Added (APIs, queues, file shares)
- ✅ Technology stacks → Exact versions (.NET 4.8, NHibernate 4.0, etc.)

**Example transformation**:

**Before** (Step 1):
```plantuml
System(lmsconnect, "LmsConnect", "Software system: LmsConnect")
System_Ext(database, "Database", "Persistent data storage")
Rel(lmsconnect, database, "Uses", "HTTPS")
```

**After** (Step 2):
```plantuml
System(lmsconnect, "LmsConnect", "Middleware for propagating course, enrollment, and user changes from SAP to Blackboard Learn LMS in real-time")
Person(admin, "System Administrator", "Monitors system health and troubleshoots issues")
Person(sap_ppf, "SAP Post Processing Framework", "Sends course and user updates via SOAP")
SystemDb(database, "SQL Server Database", "LmsConnect schema with CourseAudit, MembershipAudit, and UserAudit tables")
System_Ext(blackboard, "Blackboard Learn LMS", "Learning management system (REST API v3300 with OAuth)")
System_Ext(sap_files, "SAP Batch Export", "CSV files at \\\\sapdata\\OIT$\\PRD (ZCIAS002, ZCIAS008)")

Rel(admin, lmsconnect, "Monitors and administers", "HTTPS/Browser")
Rel(sap_ppf, lmsconnect, "Sends update notifications", "SOAP/XML via SapLmsEtlListener.svc")
Rel(lmsconnect, sap_files, "Reads batch update files", "File Share/CSV at 5:45am and 11:45pm")
Rel(lmsconnect, blackboard, "Synchronizes courses and memberships", "REST API/JSON with OAuth")
Rel(lmsconnect, database, "Persists queue and audit logs", "ADO.NET via NHibernate 4.0")
```

---

### Step 3: Render SVG Diagrams (Visual)

**Script**: `render-plantuml-diagrams.ps1`

**Purpose**: Convert enhanced `.puml` files to SVG diagrams

**How it works**:
- Downloads PlantUML JAR if not present (one-time, ~10MB)
- Validates Java installation
- Renders each `.puml` file to `.svg` using PlantUML
- Skips files where SVG is newer than source (unless `-Force`)

**Command**:
```powershell
.\\.appdoc\scripts\powershell\render-plantuml-diagrams.ps1 `
    -DiagramPath ".\docs\diagrams" `
    -Force
```

**Requirements**:
- Java 8+ installed and in PATH
- PlantUML JAR (auto-downloaded to `.appdoc\bin\`)

**Output**: `.svg` files alongside `.puml` files
- `c4-context.svg` - Rendered Context diagram
- `c4-container.svg` - Rendered Container diagram

**Characteristics**:
- ✅ **Production-ready visuals** - SVG for web/print
- ✅ **Incremental rendering** - Only updates changed diagrams
- ✅ **Offline rendering** - No external service dependencies

---

## Why Three Steps?

### Separation of Concerns

| Aspect | Generate (Step 1) | Enhance (Step 2) | Render (Step 3) |
|--------|-------------------|------------------|-----------------|
| **Technology** | PowerShell | AI (Copilot) | PlantUML JAR |
| **Input** | Codebase files | `.puml` + code context | `.puml` files |
| **Output** | `.puml` (baseline) | `.puml` (enhanced) | `.svg` (visual) |
| **Reliability** | 100% (deterministic) | ~95% (evidence-based) | 100% (PlantUML rendering) |
| **Editable** | Auto-generated | AI + manual edits | Read-only output |
| **Version Control** | Committed | Committed (enhanced) | Optional (generated) |

### Benefits

1. **Never fails to generate diagrams** - Step 1 always produces valid output
2. **Human-reviewable before rendering** - Edit `.puml` files between Step 2 and 3
3. **CI/CD friendly** - Can skip AI enhancement (Step 2) in automated pipelines
4. **Version control friendly** - `.puml` text files show meaningful diffs
5. **Best of both worlds** - Deterministic structure + AI intelligence

### Flexibility

- **Quick baseline**: Run Step 1 only for rapid prototyping
- **AI-enhanced production**: Run Steps 1 → 2 → 3 for final documentation
- **Manual editing**: Edit `.puml` after Step 2, re-run Step 3 to render
- **Batch processing**: Generate all diagrams (Step 1), enhance separately (Step 2), render on-demand (Step 3)

---

## Complete Example

```powershell
# Navigate to project root
cd C:\Projects\MyApplication

# Step 1: Generate baseline .puml files
.\\.appdoc\scripts\powershell\generate-c4-diagrams.ps1 `
    -CodebasePath ".\MyApplication.sln" `
    -OutputPath ".\docs" `
    -RenderMode SourceOnly `
    -DiagramLevels All

# Step 2: AI enhance .puml files (in GitHub Copilot Chat)
# Type: /appdoc.diagrams

# Step 3: Render enhanced .puml to SVG
.\\.appdoc\scripts\powershell\render-plantuml-diagrams.ps1 `
    -DiagramPath ".\docs\diagrams"

# View diagrams
Invoke-Item ".\docs\diagrams\*.svg"
```

---

## Script Responsibilities

### `generate-c4-diagrams.ps1` - Baseline Generator
- ✅ Parse solution and project files
- ✅ Detect containers and their types
- ✅ Identify external systems via packages
- ✅ Build relationship graph
- ✅ Generate PlantUML syntax
- ❌ **NO** business context analysis
- ❌ **NO** AI enhancement
- ❌ **NO** SVG rendering

### `/appdoc.diagrams` - AI Enhancer (Copilot prompt)
- ✅ Read existing `.puml` files
- ✅ Analyze codebase for context
- ✅ Search for connection strings, APIs, endpoints
- ✅ Identify actors and external systems
- ✅ Add technology details and protocols
- ✅ Update `.puml` files in place
- ❌ **NO** diagram generation from scratch
- ❌ **NO** SVG rendering

### `render-plantuml-diagrams.ps1` - SVG Renderer
- ✅ Download PlantUML JAR (if needed)
- ✅ Validate Java installation
- ✅ Render `.puml` → `.svg`
- ✅ Incremental rendering (skip up-to-date)
- ❌ **NO** diagram generation
- ❌ **NO** content enhancement
- ❌ **NO** codebase analysis

---

## Troubleshooting

### Step 1 Issues

**Problem**: No `.puml` files generated
- Check `CodebasePath` points to valid `.sln` or project directory
- Verify projects are .NET (Framework or Core/5+)
- Check console output for parsing errors

**Problem**: Empty diagrams
- Legacy .NET Framework projects may need package.config parsing fixes
- Check project files have `<PackageReference>` or `packages.config`

### Step 2 Issues

**Problem**: AI doesn't find external systems
- Ensure README or documentation mentions integrations
- Check connection strings are in config files (not environment variables only)
- Verify HTTP clients and database context are in code

**Problem**: AI changes are incorrect
- All changes are evidence-based, check source code/docs for accuracy
- Edit `.puml` files manually to correct
- Re-run Step 3 to render corrected diagrams

### Step 3 Issues

**Problem**: "Java not found"
- Install Java 8+: https://adoptium.net/
- Add Java to PATH: `C:\Program Files\Java\jdk-xx\bin`

**Problem**: "PlantUML JAR download failed"
- Check internet connection
- Manually download from: https://github.com/plantuml/plantuml/releases
- Place in `.appdoc\bin\plantuml.jar`

**Problem**: SVG rendering errors
- Check `.puml` syntax is valid PlantUML
- Run `java -jar plantuml.jar -syntax <file>.puml` to validate

---

## Best Practices

1. **Commit `.puml` files** - Source of truth for diagrams
2. **`.gitignore` SVG files** (optional) - Can be regenerated from `.puml`
3. **Run Step 1 on CI/CD** - Keep baseline diagrams updated
4. **Run Step 2 manually** - AI enhancement requires human review
5. **Run Step 3 before releases** - Update SVGs for documentation
6. **Review AI enhancements** - Verify accuracy before committing
7. **Edit `.puml` directly** - Manual corrections are preserved

---

## Future Enhancements

- **Component diagrams** (Level 3) - Class-level architecture
- **Online rendering fallback** - When Java not available
- **Diff visualization** - Show changes between baseline and enhanced
- **Batch enhancement** - Process multiple diagrams in one prompt
- **Custom templates** - Project-specific diagram styles
- **Mermaid support** - Alternative to PlantUML
