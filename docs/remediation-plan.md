# AppDoc v2.3.0 → v2.4.0 Remediation Plan

**Date:** 2026-11-12
**Source:** Comparative analysis of 5 generated documents vs. the HelpDesk standard
**Goal:** Resolve root causes of all identified gaps and errors; prevent reproduction.

---

## Executive Summary

The comparative analysis identified **5 systemic root causes** (tooling bugs) and **7 structural gaps** (missing capabilities). This plan addresses both, organized into 4 phases by dependency and impact.

| Phase | Focus | Items | Effort |
|---|---|---|---|
| 1 | Fix root-cause bugs | 5 items | ~2 days |
| 2 | Clean generated blocks | 3 items | ~1 day |
| 3 | Add missing capabilities | 4 items | ~3 days |
| 4 | Harden against regression | 2 items | ~1 day |

---

## Phase 1: Fix Root-Cause Bugs

These are the 5 systemic defects that caused the implementation-phase failures and the A.4 trust problem.

---

### 1.1 Citation Parser: Prose File Mentions Treated as Citations

**Root cause:** `parse_span()` in `appdoc/citations.py` treats any backticked span that looks like a file path as a Citation. When prose says "which `.gitignore` lists", the span `` `.gitignore` `` is parsed as a Citation (dotfile + no line → `_file_like` returns True via `_is_dotfile`). C2 then flags it because it has no line number.

**Fix:** Add a **prose-context heuristic** to `find_citations()`. A backticked span is NOT a Citation when:
- It appears in a sentence (surrounded by word characters on both sides, not at a cell boundary or after a colon/parenthesis), AND
- It has no line number, AND
- It is a bare filename (no `/` in the path)

This preserves legitimate bare-file citations (e.g., "see `Dockerfile`" at the start of a sentence or in a table cell) while excluding mid-sentence prose mentions.

**Implementation:**

```python
# appdoc/citations.py — add to find_citations()

def _is_prose_mention(line: str, span_start: int, span_end: int, path: str) -> bool:
    """True when the span looks like a prose mention, not a deliberate citation."""
    if "/" in path:
        return False  # paths with folders are always citations
    # Check surrounding context
    before = line[span_start - 1] if span_start > 0 else ""
    after = line[span_end] if span_end < len(line) else ""
    # A citation typically follows: start-of-line, |, (, :, space+capital, or is in a table cell
    # A prose mention is embedded in a word: "the .gitignore lists"
    if before.isalpha() or after.isalpha():
        return True
    # "which .gitignore lists" — preceded by a common prose word
    prefix = line[:span_start].rstrip()
    if prefix and prefix[-1] not in "|(:\t" and not prefix.endswith("|"):
        # Check if the preceding word is a common prose connector
        words = prefix.split()
        if words and words[-1].lower() in ("the", "a", "an", "which", "that", "its", "our", "their", "this", "those"):
            return True
    return False
```

Then in `find_citations()`:
```python
for m in _SPAN_RE.finditer(line):
    parsed = parse_span(m.group(1))
    if parsed:
        path, start, end = parsed
        if start is None and _is_prose_mention(line, m.start(1), m.end(1), path):
            continue  # skip prose mentions
        out.append(Citation(lineno, path, start, end, m.group(1)))
```

**Test:** Add to `tests/test_citations.py`:
- `` `which .gitignore lists` `` → NOT a citation
- `` `see .gitignore:5` `` → IS a citation (has line)
- `` `Dockerfile` `` at start of line → IS a citation
- `` `the .gitignore` `` in a table cell → NOT a citation (prose)
- `` `portal/verify.asp` `` → IS a citation (has `/`)

**Risk:** Low. The heuristic only affects bare filenames without line numbers in prose context. All existing citations in the 5 documents use either paths with `/` or line numbers.

---

### 1.2 Register Completeness: Auto-Add Rows for Post-Audit Findings

**Root cause:** When findings (V-IDs) are added to the document after the initial audit, no register rows are created for them. C11 then fails because "finding V-N has no register row." The fix was manual (adding rows to evidence.jsonl), but the tool should detect and report this more clearly, or provide a helper.

**Fix (two-part):**

**Part A — Better C11 error message with a ready-to-paste row:**

In `appdoc/check.py`, `_c11_register()`, where the V-ID check happens (~line 635):
```python
for vid, no in ids.items():
    if vid.startswith("V-") and vid not in covered:
        # Find the finding's text to pre-fill the claim
        finding_text = _finding_text(lines, no)  # new helper
        add("C11", no, f"finding {vid} has no register row",
            f'add a row: {{"id": "E-<next>", "ref": "10.1/{vid}", "claim": "{finding_text[:80]}", '
            f'"result": "Supported", "cites": ["<path:line>"], "anchor": "<text>", "limitation": ""}}')
```

**Part B — `appdoc fill --register` subcommand (new):**

Add a `--register` flag to `fill` that scans the document for V-IDs and 7.x workflow IDs, checks which ones lack register rows, and appends stub rows to `evidence.jsonl`:

```python
# appdoc/fill.py — new function
def fill_register(target: str, out_dir: str) -> int:
    """Scan for V-IDs and workflow IDs without register rows; append stubs."""
    md_path = os.path.join(out_dir, "application-documentation.md")
    reg_path = os.path.join(out_dir, REGISTER)
    # ... read document, find all V-IDs and 7.x refs
    # ... read existing register, find covered IDs
    # ... for each missing ID, append a stub row with result="Supported", cites=[], anchor=""
    # ... the user must then fill in cites and anchor
    # ... print a summary of what was added
```

This is a **quality-of-life** fix — it doesn't auto-audit (that requires reading source), but it eliminates the "forgot to add a row" failure mode.

**Test:** Add to `tests/test_check.py`:
- A document with V-5 but no E-row for V-5 → C11 error includes the V-5 text in the fix message
- `fill --register` adds stub rows for missing V-IDs

---

### 1.3 Regeneration: Keep Appendix A in Sync with Narrative Edits

**Root cause:** When the narrative is edited (findings added, evidence changed), the generated Appendix A block becomes stale. C7 catches this ("generated block 'appendix-a' differs from the Facts"), but the fix requires re-running `fill`. The user should not have to know this.

**Fix:** Make `check` **auto-suggest** the fix when C7 fires on `appendix-a`:

In `appdoc/check.py`, the C7 block comparison (~line 500):
```python
elif facts is not None and found[name][0] != (fill_mod.render_block(name, facts, ctx) or "").strip():
    fix = "run `appdoc fill <target>` to regenerate"
    if name == "appendix-a":
        fix = "the evidence register changed; run `appdoc fill <target>` to regenerate Appendix A"
    add("C7", found[name][1], f"generated block '{name}' differs from the Facts", fix)
```

Additionally, add a **pre-check** to `check` that detects when `evidence.jsonl` has been modified after the last `fill` (by comparing the register's row count to what the appendix block shows):

```python
# In check.run(), before the C7 block comparison:
# If appendix-a block exists and evidence.jsonl has more rows than the block shows,
# emit an advisory (not a failure) suggesting fill.
```

**Test:** Add to `tests/test_check.py`:
- Modify evidence.jsonl after fill → C7 fires with the specific "run fill" message
- The advisory pre-check fires when row counts mismatch

---

### 1.4 Config-Role Classification: Exclude Non-App Files

**Root cause:** `config_role()` in `appdoc/stacks/generic.py` classifies files as "app" config when they don't match test/CI/orchestration/build patterns. This misses:
- `desktop.ini` (Windows shell metadata)
- `_vti_cnf/` (FrontPage metadata)
- `To be deleted/` (retired code copies)
- `*.properties` locale files outside i18n dirs (e.g., `peregrine/java/ClientRes.properties`)
- `crowdin.yml` (translation tooling)
- `es-metadata.yml` (routing metadata)

**Fix:** Extend `config_role()` with additional exclusion patterns:

```python
# appdoc/stacks/generic.py — additions to config_role()

# New: files/folders that are never application config
_NEVER_CONFIG_NAMES = re.compile(
    r"(?i)^(desktop\.ini|\.DS_Store|Thumbs\.db|\.htaccess|\.htpasswd)$"
)
_NEVER_CONFIG_DIRS = {"_vti_cnf", "_private", "To be deleted", "to be deleted",
                      "node_modules", "vendor", "bower_components"}
# Translation tooling (not app config)
_TRANSLATION_TOOLING = re.compile(
    r"(?i)^(crowdin|transifex|weblate|lokalise)\.(ya?ml|json)$"
)

def config_role(path: str) -> str | None:
    n = _name(path)
    parts = [p.lower() for p in path.split("/")[:-1]]
    if _LOCKFILE.match(n):
        return None
    if _I18N_NAME.match(n) or any(p in _I18N_DIRS for p in parts):
        return None
    # NEW: never-config files and directories
    if _NEVER_CONFIG_NAMES.match(n) or any(p in _NEVER_CONFIG_DIRS for p in parts):
        return None
    # NEW: translation tooling
    if _TRANSLATION_TOOLING.match(n):
        return "build"
    # ... rest unchanged
```

Also add `crowdin` to `_BUILD_NAMES` (it's already there for `crowdin.yml` but the regex may not catch all variants).

**Additionally:** Add a **`To be deleted` / retired-code exclusion** to the scan walker (`appdoc/scan.py`), not just config_role. Files under `To be deleted/` should be pruned from the scan entirely (like `node_modules`), not just reclassified. This fixes the entry-points inflation in helpweb.

```python
# appdoc/scan.py — add to the prune rules
_PRUNE_DIRS = {"node_modules", "vendor", "bower_components", "To be deleted",
               "to be deleted", "_vti_cnf", "_private"}
```

**Test:** Add to `tests/test_generic_facts.py` (or a new `tests/test_config_role.py`):
- `desktop.ini` → role None
- `_vti_cnf/something.yml` → role None
- `To be deleted/config.yml` → role None (or pruned from scan)
- `crowdin.yml` → role "build"
- `peregrine/java/ClientRes.properties` → role None (i18n by name pattern)
- `es-metadata.yml` → role "build" (add to _BUILD_NAMES or _TOOLING_DIRS)

**Re-run required:** After this fix, re-extract + re-fill all 5 targets to clean the rendered tables.

---

### 1.5 A.4 Verification Commands: Use the Correct Path

**Root cause:** `_commands()` in `appdoc/register.py` uses `_first_path(row)` — the path of the FIRST citation in the row. But the anchor text may be in a DIFFERENT cited file. The command then greps the wrong file.

**Fix:** Generate one command per citation (not just the first), or better: generate the command using the path where the anchor actually appears.

Since the tool doesn't read source files during `fill` (it only reads `facts.json` and `evidence.jsonl`), the most robust fix is to **generate one command per citation**:

```python
# appdoc/register.py — rewrite _commands()

def _commands(reg: Register) -> list[str]:
    out = []
    for _, row in reg.rows:
        anchor = str(row.get("anchor") or "")
        if (row.get("result") not in VERIFIABLE or not anchor.strip()
                or "\n" in anchor or "\r" in anchor or len(anchor) > MAX_ANCHOR):
            continue
        cites = row.get("cites") or []
        paths = []
        for raw in cites:
            parsed = parse_span(str(raw).strip("`"))
            if parsed:
                paths.append(parsed[0])
        if not paths:
            continue
        out += [f"- **{_cell(row['id'])}** (`{_cell(row['ref'])}`)", ""]
        for p in paths:
            out += ["```text",
                    f"Select-String -Path {_ps(p)} -SimpleMatch -Pattern {_ps(anchor)}",
                    f"grep -nF -- {_sh(anchor)} {_sh(p)}", "```", ""]
    if not out:
        return ["No row has an anchor to re-check."]
    return ["Each block holds a PowerShell command, then a POSIX command, per cited file. "
            "At least one should print the supporting line.",
            ""] + out[:-1]
```

**Alternative (simpler):** If a row has exactly one citation, use that path (current behavior is correct). If it has multiple, generate one command per path. This is what the fix above does.

**Test:** Add to `tests/test_register.py`:
- Row with single citation → one command block (unchanged)
- Row with two citations → two command blocks, one per path
- Row with no citations → no command block

**Re-run required:** After this fix, re-fill all 5 targets to regenerate Appendix A.

---

## Phase 2: Clean Generated Blocks

These fixes make the generated blocks informative rather than noisy.

---

### 2.1 Entry-Points Block: Exclude Retired/Deleted Code

**Root cause:** The `_entry_points()` renderer in `fill.py` includes ALL non-test entry_point Facts. When a repo has `To be deleted/` directories with copies of handlers, they inflate the count and dominate the table.

**Fix:** Two approaches (do both):

**A. Scan-level pruning (preferred):** Add `To be deleted`, `_vti_cnf`, `_private` to the scan prune rules (see 1.4). This removes them from facts.json entirely.

**B. Fill-level filter (defense in depth):** In `_entry_points()`, add a note when a significant fraction of entries come from a single top-level folder that looks like a retired area:

```python
# appdoc/fill.py — in _entry_points(), after building the table:
# If >30% of entries come from a folder matching r"(?i)to.?be.?deleted|retired|deprecated|old",
# add a footnote: "N of M entries are from <folder>/ (likely retired code)."
```

**Test:** Add to `tests/test_fill.py`:
- Facts with entries from `To be deleted/` → excluded (if scan prunes) or footnoted

---

### 2.2 Scheduled-Jobs Block: State Inferred Schedules

**Root cause:** For jobs that don't use a cron-style declaration (e.g., .NET `IHostedService` with a `TimeSpan` loop), the `schedule` field is `None`, and the block shows "Unknown." The narrative then infers the schedule, but the block is uninformative.

**Fix:** Allow the `schedule` field to hold a **descriptive string** (not just a cron spec). The Go extractor already does this (`@every 5m`). For .NET, the `aspnet_core` stack should extract the loop interval:

```python
# appdoc/stacks/aspnet_core.py — in the hosted-service/job extraction:
# Look for:
#   - TimeSpan.FromSeconds(N) / FromMinutes(N) / FromHours(N) in a loop
#   - await Task.Delay(TimeSpan...)
#   - PeriodicTimer(TimeSpan...)
# Set schedule to e.g. "every 30s (Task.Delay)" or "every 5m (PeriodicTimer)"
```

For the generic case (no stack-specific extraction), the block should show the **handler name** and the **definition location** even when schedule is Unknown, so the reader can look it up:

```python
# appdoc/fill.py — in _scheduled_jobs():
# Current: | Job | Schedule | Enabled by default | Defined at | Stack |
# The "Defined at" column already has the path:line. This is sufficient.
# The fix is in the extractors: extract the interval when possible.
```

**Test:** Add to `tests/test_facts_aspnet_core.py`:
- A hosted service with `Task.Delay(TimeSpan.FromSeconds(30))` → job Fact with `schedule="every 30s"`
- A `PeriodicTimer(TimeSpan.FromMinutes(5))` → job Fact with `schedule="every 5m"`

---

### 2.3 Config-Reference Block: Reduce Noise

**Root cause:** Even after the `config_role()` fix (1.4), the generated block can be noisy because:
- It shows up to 150 keys (`CONFIG_CAP`), which is a lot for a small app
- It doesn't distinguish between "read" and "define" uses in the table
- The curated table below it (written by the AI) is the useful part, but the generated block dilutes it

**Fix:**

**A. Lower the cap for small apps:** If the total app-role config keys < 50, show all. If > 50, show the top 50 by (secret_location, path) and note the rest.

```python
# appdoc/fill.py — in _config_reference():
effective_cap = CONFIG_CAP if len(keys) > 50 else len(keys)
```

**B. Add a "Use" column** to distinguish define vs. read:

```python
# Current: | Key | Defined at | Secret location |
# New:     | Key | Defined at | Use | Secret location |
```

**C. Group by file** (when there are > 20 keys): Show a sub-header per file so the reader can see which file defines which keys.

**Test:** Add to `tests/test_fill.py`:
- 30 config keys → all shown, no cap note
- 200 config keys → 150 shown, cap note present
- Keys with `use="read"` vs `use="define"` → different Use column values

---

## Phase 3: Add Missing Capabilities

These are the structural gaps that prevent the documents from matching the standard's depth.

---

### 3.1 External-Call / Data-Access Register (8A/8B Equivalent)

**Root cause:** The template has no section for a structured external-call register. The standard's 8A (connection register, procedure register, HTTP call register, email/COM/file boundary register, failure/fallback register) and 8B (procedure data dictionary with parameter signatures and return codes) have no equivalent.

**Fix:** Add a new generated block `data-access-register` to §8.1 (or a new §8.6):

**Template change** (`appdoc/assets/template.md`):
```markdown
### 8.6 Data-Access and External-Call Register

<!-- appdoc:generated data-access-register -->
<!-- /appdoc:generated data-access-register -->
```

**Fill renderer** (`appdoc/fill.py`):
```python
def _data_access_register(doc: dict, ctx: dict | None = None) -> str:
    """Register of connections, data-access patterns, and external calls."""
    connections = _facts(doc, "connection")
    data_access = _facts(doc, "data_access")
    external_calls = _facts(doc, "external_call")
    
    out = []
    if connections:
        out += ["#### Connections", "", "| Name | Kind | Defined at | Used by |", "|---|---|---|---|"]
        for c in connections:
            d = c["detail"]
            out.append(f"| {_cell(c['name'])} | {_cell(d.get('kind', ''))} | {_at(c)} | {_cell(d.get('used_by', ''))} |")
    if data_access:
        out += ["", "#### Data-Access Patterns", "", "| Pattern | File | Lines | Tables/Procedures |", "|---|---|---|---|"]
        for da in data_access[:50]:
            d = da["detail"]
            out.append(f"| {_cell(d.get('pattern', ''))} | `{da['path']}` | {da['line']} | {_cell(d.get('objects', ''))} |")
    if external_calls:
        out += ["", "#### External Calls", "", "| Target | Protocol | Defined at | Auth | Failure handling |", "|---|---|---|---|---|"]
        for ec in external_calls[:50]:
            d = ec["detail"]
            out.append(f"| {_cell(ec['name'])} | {_cell(d.get('protocol', ''))} | {_at(ec)} | {_cell(d.get('auth', ''))} | {_cell(d.get('failure', 'Not traced'))} |")
    if not out:
        return "No connections, data-access patterns, or external calls were extracted."
    return "\n".join(out)
```

**Stack extractor changes:** Each stack should emit `connection`, `data_access`, and `external_call` Facts with richer `detail`:
- `connection`: `kind` (sql, redis, rabbitmq, http), `used_by` (list of paths)
- `data_access`: `pattern` (e.g., "raw SQL", "ORM query", "stored procedure"), `objects` (table/procedure names)
- `external_call`: `protocol` (http, grpc, amqp), `auth` (bearer, basic, none), `failure` (retry, circuit-breaker, none)

**Check rule:** C4 already checks that §8 is non-empty when facts have `connection`/`data_access`/`external_call`. Extend to also check that the new block is present.

**Test:** Add to `tests/test_fill.py` and per-stack tests:
- Facts with connections + data_access + external_calls → block renders all three sub-tables
- No such facts → "No connections..." message

**Effort:** Medium. The Facts schema already has `connection`, `data_access`, and `external_call` kinds. The main work is enriching the `detail` fields in the stack extractors and writing the renderer.

---

### 3.2 UI Catalog: Add Rendered Controls and States

**Root cause:** The UI catalog (§6) lists routes and handler names but not the visible controls, states, and effects. The standard's section 6 describes what the user sees.

**Fix:** This is primarily an **AI narrative** improvement, not a tooling fix. The tool can't extract "the user sees a red error banner." However, we can:

**A. Add a template guide** that prompts the AI to describe controls/states:

```markdown
<!-- appdoc:guide: For each UI screen, describe: (1) the visible controls (buttons, fields, links),
     (2) the states (loading, error, empty, success), (3) the effects (what happens on submit/click).
     Cite the template/view file for each control. If the view is not in the repo, say so. -->
```

**B. Add a `ui_page` Fact enrichment** in the stack extractors:
- For ASP.NET: extract `<input>`, `<button>`, `<a href>`, `<form>` from `.cshtml`/`.razor` files
- For Flask: extract from Jinja2 templates
- For Go (gitea): extract from template files (`.html` in `templates/`)

This gives the AI a starting list of controls to describe, rather than starting from zero.

**Effort:** High (per-stack template parsing). **Priority:** Low (the AI can do this from reading the view files; the tool just needs to point at them).

---

### 3.3 Role-to-Capability Matrix: Reduce `?` Cells

**Root cause:** The matrix (§5.3) has `?` cells because the AI couldn't trace per-route enforcement. The tool extracts `auth_check` Facts but doesn't correlate them with routes.

**Fix:**

**A. Add a generated block** `role-matrix-hints` that lists, per auth middleware/interceptor, which routes it guards:

```python
# appdoc/fill.py — new renderer
def _role_matrix_hints(doc: dict, ctx: dict | None = None) -> str:
    """Per auth_check Fact, list the routes it guards (from the same file)."""
    auths = _facts(doc, "auth_check")
    routes = _facts(doc, "entry_point")
    # Group routes by file
    routes_by_file = {}
    for r in routes:
        if r["detail"].get("type") == "route":
            routes_by_file.setdefault(r["path"], []).append(r)
    # For each auth_check, find routes in the same file
    out = ["| Auth check | File | Routes in same file |", "|---|---|---|"]
    for a in auths[:50]:
        file_routes = routes_by_file.get(a["path"], [])
        route_names = ", ".join(r["name"] for r in file_routes[:5])
        if len(file_routes) > 5:
            route_names += f" (+{len(file_routes)-5} more)"
        out.append(f"| {_cell(a['name'])} | `{a['path']}:{a['line']}` | {route_names} |")
    return "\n".join(out) if len(out) > 2 else "No auth checks were extracted."
```

This doesn't fill the matrix (that requires understanding the middleware chain), but it gives the AI the raw material to do so.

**B. Template guide update:**
```markdown
<!-- appdoc:guide: Use the auth-check hints below to populate the matrix. For each cell, cite the
     middleware/interceptor that enforces the restriction. If you cannot trace the enforcement,
     write "?" and add an open question in section 14. -->
```

**Effort:** Medium. **Priority:** Medium (the matrix is high-value for security review).

---

### 3.4 Per-Subsystem Inventory (Standard's 4A)

**Root cause:** The standard has a per-subsystem inventory (file counts, DB tables, purpose per subsystem). Gitea's §4.1 does this well (22-row table), but it's AI-written, not generated.

**Fix:** Add a generated block `subsystem-inventory` to §4.1:

```python
# appdoc/fill.py — new renderer
def _subsystem_inventory(doc: dict, ctx: dict | None = None) -> str:
    """Per top-level folder: file count, entry-point count, config key count, stack."""
    files = [f for f in doc.get("facts", []) if f["kind"] == "file"]
    entries = _facts(doc, "entry_point")
    configs = _facts(doc, "config_key")
    
    by_folder: dict[str, dict] = {}
    for f in files:
        top = f["path"].split("/", 1)[0] + "/" if "/" in f["path"] else "(root)"
        d = by_folder.setdefault(top, {"files": 0, "routes": 0, "pages": 0, "jobs": 0, "commands": 0, "configs": 0})
        d["files"] += 1
    for e in entries:
        top = e["path"].split("/", 1)[0] + "/" if "/" in e["path"] else "(root)"
        d = by_folder.setdefault(top, {"files": 0, "routes": 0, "pages": 0, "jobs": 0, "commands": 0, "configs": 0})
        t = e["detail"].get("type")
        if t in d:
            d[t] += 1
    for c in configs:
        top = c["path"].split("/", 1)[0] + "/" if "/" in c["path"] else "(root)"
        d = by_folder.setdefault(top, {"files": 0, "routes": 0, "pages": 0, "jobs": 0, "commands": 0, "configs": 0})
        d["configs"] += 1
    
    out = ["| Folder | Files | Routes | Pages | Jobs | Commands | Config keys |", "|---|---|---|---|---|---|---|"]
    for folder, d in sorted(by_folder.items(), key=lambda kv: -kv[1]["files"])[:30]:
        out.append(f"| `{folder}` | {d['files']} | {d['routes']} | {d['pages']} | {d['jobs']} | {d['commands']} | {d['configs']} |")
    return "\n".join(out)
```

This is the **generated skeleton** that the AI then enriches with purpose descriptions. Gitea's 4.1 is the model: the generated table gives the numbers, the AI adds the "Purpose" and "Status" columns.

**Effort:** Low. **Priority:** Medium (generalizes gitea's best feature to all targets).

---

## Phase 4: Harden Against Regression

---

### 4.1 Integration Test: Full Pipeline on All 5 Targets

**Root cause:** The implementation-phase bugs (C11, C7, C2, config noise) were all caught by running `check` on the real targets, but only after the fact. A CI gate would catch them earlier.

**Fix:** Add a test that runs the full pipeline (extract → fill → check) on a **small fixture** that exercises all 5 root causes:

```python
# tests/test_integration.py
class IntegrationTests(unittest.TestCase):
    """Full pipeline on a fixture that exercises all known failure modes."""
    
    def test_full_pipeline_passes(self):
        # Fixture: a small Flask app with:
        #   - a .gitignore mentioned in prose (C2 regression)
        #   - a finding without a register row (C11)
        #   - a stale appendix (C7)
        #   - fixture config files (config_role)
        #   - a multi-citation register row (A.4)
        # Run extract → fill → check
        # Assert: check passes (or fails with the expected specific errors)
        pass
    
    def test_config_role_excludes_fixtures(self):
        # Assert that files under fixtures/ get role "test"
        pass
    
    def test_a4_uses_correct_path(self):
        # Assert that A.4 commands use the path where the anchor appears
        pass
```

**Additionally:** Add a **smoke test** that runs `check` on the 5 real targets (if they exist on the machine) and asserts PASS. This is opt-in (skipped if the targets aren't present):

```python
@pytest.mark.skipif(not os.path.isdir("c:/Github/appdoc-test"), reason="test targets not present")
def test_real_targets_pass(self):
    for target in ["flaskr-tdd", "spring-petclinic", "eShop", "gitea"]:
        # run check, assert exit code 0
        pass
```

---

### 4.2 Changelog and Version Bump

**Fix:** Update `CHANGELOG.md` with the v2.4.0 changes. Bump `TEMPLATE_VERSION` to `"2.4"` in `appdoc/template_spec.py`. Update the template stamp.

**Migration:** Existing documents with `<!-- appdoc:template 2.3 -->` will trigger C3 (template not current). The user must re-copy the template and re-fill. Document this in the changelog.

---

## Implementation Order

```
Phase 1 (bugs):
  1.1  Citation parser prose fix          ← do first (unblocks flaskr)
  1.5  A.4 correct path                   ← do second (affects all 5)
  1.4  Config-role exclusions             ← do third (affects gitea, helpweb, eShop)
  1.2  Register completeness helper       ← do fourth (QoL)
  1.3  Regeneration sync suggestion       ← do fifth (QoL)

Phase 2 (clean blocks):
  2.1  Entry-points exclusion             ← depends on 1.4
  2.2  Scheduled-jobs enrichment          ← independent
  2.3  Config-reference cleanup           ← depends on 1.4

Phase 3 (capabilities):
  3.4  Subsystem inventory block          ← do first (low effort, high value)
  3.1  Data-access register block         ← do second (medium effort)
  3.3  Role-matrix hints block            ← do third (medium effort)
  3.2  UI catalog enrichment              ← do last (high effort, low priority)

Phase 4 (hardening):
  4.1  Integration test                   ← after all fixes
  4.2  Changelog + version bump           ← last
```

---

## Effort Estimate

| Item | Files touched | LOC (est.) | Effort |
|---|---|---|---|
| 1.1 Citation parser | `citations.py`, `test_citations.py` | ~40 | 2h |
| 1.2 Register helper | `check.py`, `fill.py`, `test_check.py` | ~60 | 3h |
| 1.3 Regeneration sync | `check.py`, `test_check.py` | ~30 | 1h |
| 1.4 Config-role | `generic.py`, `scan.py`, `test_generic_facts.py` | ~50 | 2h |
| 1.5 A.4 path | `register.py`, `test_register.py` | ~30 | 1h |
| 2.1 Entry-points | `fill.py`, `scan.py`, `test_fill.py` | ~20 | 1h |
| 2.2 Scheduled-jobs | `aspnet_core.py`, `test_facts_aspnet_core.py` | ~40 | 2h |
| 2.3 Config-reference | `fill.py`, `test_fill.py` | ~30 | 1h |
| 3.1 Data-access register | `fill.py`, `template.md`, `template_spec.py`, stacks | ~100 | 4h |
| 3.2 UI catalog | `template.md`, stacks | ~80 | 4h |
| 3.3 Role-matrix hints | `fill.py`, `template.md`, `template_spec.py` | ~50 | 2h |
| 3.4 Subsystem inventory | `fill.py`, `template.md`, `template_spec.py` | ~40 | 2h |
| 4.1 Integration test | `test_integration.py` | ~80 | 3h |
| 4.2 Changelog | `CHANGELOG.md`, `template_spec.py` | ~20 | 0.5h |
| **Total** | | **~670** | **~29h (~4 days)** |

---

## Verification Plan

After each phase, run:
1. `python -m unittest discover -s tests -q` — all tests pass
2. `python run_appdoc.py check <target> --out docs/appdoc-2.3` — all 5 targets PASS
3. `python run_appdoc.py render <target> --out docs/appdoc-2.3` — all 5 render
4. Visual inspection of the rendered HTML for the changed blocks

After all phases:
5. Re-extract + re-fill + re-check + re-render all 5 targets
6. Copy outputs to `examples/`
7. Update the comparative analysis with a "post-remediation" section
