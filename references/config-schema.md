# AppDoc configuration reference

Optional per-target file: `<target>/.appdoc/config.json`. No config file means built-in defaults (CMU maroon/gold theme, `docs` output directory, enrichment off).

`schemaVersion: appdoc-config/v1`. Drives: `theme` (default CMU `#6a0032`/`#ffc82e`, swappable via
`themeFile`), `redactionPatterns[]` and `redactionRegexes[]` (operator redaction, below),
`pristineFloor` (default 80), `minCommitsForOwnership` (default 2), `outputDir` (default `docs`).
**No config = today's behavior.** A config file that exists but is not valid JSON stops the build
(exit 1) rather than silently falling back to defaults, because that would drop the operator's
redaction settings.

## Theming and branding

AppDoc is CMU-first: the default theme is the CMU maroon/gold theme with the CMU mark in the report masthead. Everything is configurable:

- `theme` — a theme name (`cmu` default, `navy-teal`, or `<name>` for `.appdoc/templates/html/<name>.json`) or an absolute path.
- `themeFile` — explicit path to a theme `.json` (overrides `theme`).
- Inside a theme file, `masthead.logoSvg` controls the logo: `inline:cmu` (built-in CMU mark; also the default when the key is absent), `none` (no logo), or `file:<path>` / `<path>.svg` (inline that SVG; relative paths resolve against the theme file's folder).
- `masthead.title` / `masthead.sub` set the report header text; `colors` and `fonts` restyle the report.

To brand for another organization, copy `.appdoc/templates/html/theme.json`, change colors/fonts/masthead, set `logoSvg` to `none` or your own SVG, and point `themeFile` at it.

### Operator redaction overrides (`.appdoc/config.json`, optional)

Two additive lists, applied on top of the built-in extractors and the semantic gate:

| Key | Meaning |
|---|---|
| `redactionPatterns[]` | Exact secret **values**. Matched literally: regex metacharacters in a value are not interpreted, so `a.b` only matches `a.b`. |
| `redactionRegexes[]` | Regular expressions (case-insensitive). Every match is replaced with `[REDACTED]`. An invalid regex stops the build with exit code 3 (fail-closed); a typo can never silently weaken redaction. |

Both lists are applied by the final sweep over every `docs/**` `.md`/`.html`/`.json`, by the
source-docs extractor, and are scanned for by the fail-closed semantic gate (which inspects raw string
values, so a secret containing `"` or `\` is still caught). Use them for target-specific secrets the
built-in patterns don't cover (e.g. a service-account username you've decided to treat as secret). A
fresh agent cannot know a target's hardcoded secret list: read the target's config files to discover
them.

```json
{
  "redactionPatterns": ["svc-helpdesk-prod"],
  "redactionRegexes":  ["corp-[0-9]{6}-key"]
}
```
