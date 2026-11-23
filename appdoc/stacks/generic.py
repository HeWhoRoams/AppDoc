"""Generic extractor: runs on every Target and owns config files and dependency manifests.

Stack extractors read code files only. This module reads: web.config/app.config, appsettings*.json,
*.properties, *.yml/*.yaml, *.ini, .env*, package.json, requirements*.txt, pom.xml, build.gradle, *.csproj,
packages.config, Gemfile, go.mod, composer.json, *.sql (DDL objects) and ownership files (CODEOWNERS,
MAINTAINERS, ...). It never records a config value, a person's name or an email address.

Every config_key carries a `role` (app, build, ci, orchestration, test). Lockfiles and i18n message
bundles are not configuration and produce no config_key Facts. Test config (test directories, fixtures,
test data) gets role `test` and is marked as test code; tooling folders (tools, scripts, docs, examples,
contrib, editor settings) get role `build`.
"""

from __future__ import annotations

import json
import re
from typing import Iterable

from ..facts import Fact, is_test_path
from ..secrets import is_secret_key, find_secret_shapes
from .base import iter_matches, line_of, strip_comments

STACK_ID = "generic"
# Fact kinds this reader emits (it is not a registered Stack). tests/test_conformance.py derives the set from
# the samples and compares it with its own literal, so an addition is deliberate.
GENERIC_KINDS = frozenset({"config_key", "connection", "dependency", "file", "owner_file", "schema_object", "smell"})

CONFIG_NAMES_JSON = re.compile(r"^(appsettings(\..+)?|config|settings|local\.settings)\.json$", re.I)
# Framework-defined application config names (closed set, R3): positive evidence for role `app`.
_APP_CONFIG_NAME = re.compile(
    r"(?i)^(application[\w.-]*\.(properties|ya?ml)|appsettings[\w.-]*\.json|"
    r"web\.config|app\.config|local\.settings\.json|\.env[\w.-]*|config\.json|settings\.json)$")
# A locale suffix on a config file base: <base>_<ll> or <base>_<ll>_<CC>.
_LOCALE_SUFFIX = re.compile(r"(?i)^(.*?)[_.-]([a-z]{2})([_.-][a-z]{2})?$")

# Hoisted per-call regexes (compiled once at import) so extraction doesn't recompile them per file.
_REQUIREMENTS_TXT_RE = re.compile(r"^requirements.*\.txt$")
_GEM_RE = re.compile(r"(?m)^\s*gem\s+['\"]([^'\"]+)['\"](?:\s*,\s*['\"]([^'\"]+)['\"])?")
_GOMOD_RE = re.compile(r"(?m)^\s*(?:require\s+)?([\w.\-/]+\.[\w.\-/]+)\s+(v[\w.\-+]+)\s*$")
_JSON_COMMENT_RE = re.compile(r"(?m)^\s*//.*$")
_PROPS_RE = re.compile(r"([^=:\s]+)\s*[=:]")
_PROPS_URL_RE = re.compile(r"datasource\.url|jdbc[_.]url|\.url$", re.I)
_PROPS_JDBC_RE = re.compile(r"jdbc|datasource", re.I)
_YAML_RE = re.compile(r"^(\s*)([A-Za-z0-9_.\-]+)\s*:(.*)$")
_DOTENV_RE = re.compile(r"^\s*(?:export\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*=")
_REQS_RE = re.compile(r"([A-Za-z0-9_.\-\[\]]+)\s*(?:(==|>=|<=|~=|>|<)\s*([\w.*+\-]+))?")
_POM_DEP_RE = re.compile(r"<dependency>(.*?)</dependency>", re.S)
_POM_GROUP_RE = re.compile(r"<groupId>\s*([^<\s]+)")
_POM_ARTIFACT_RE = re.compile(r"<artifactId>\s*([^<\s]+)")
_POM_VERSION_RE = re.compile(r"<version>\s*([^<\s]+)")
_GRADLE_RE = re.compile(r"""(?m)^\s*(?:implementation|api|compile|runtimeOnly|testImplementation|compileOnly)\s*\(?\s*['"]([^'":]+:[^'":]+)(?::([^'"]+))?['"]""")
_CSPROJ_RE = re.compile(r'<PackageReference\s+[^>]*Include="([^"]+)"(?:[^>]*Version="([^"]+))?', re.I)
_PACKAGES_CONFIG_RE = re.compile(r'<package\s+[^>]*id="([^"]+)"[^>]*?(?:version="([^"]+))?', re.I)


def _name(path: str) -> str:
    return path.rsplit("/", 1)[-1]


_LOCKFILE = re.compile(r"(?i)^(.*[-.]lock\.(ya?ml|json)|.*\.lock|npm-shrinkwrap\.json)$")
_I18N_NAME = re.compile(r"(?i)^(messages|strings|resources?|labels|locale|lang)([_.-][\w-]+)?\.(properties|ya?ml|ini)$")
_I18N_DIRS = {"i18n", "l10n", "locale", "locales", "lang", "langs", "translations"}
_CI_DIRS = (".github/", ".gitlab/", ".circleci/", ".azure-pipelines/", ".buildkite/", ".woodpecker/", ".gitea/", ".forgejo/")
_CI_NAMES = re.compile(r"(?i)^(\.gitlab-ci|azure-pipelines.*|\.travis|appveyor|bitbucket-pipelines|\.drone|codecov|\.codecov|cloudbuild|buildspec|\.woodpecker)\.ya?ml$")
_ORCH_DIRS = {"k8s", "kubernetes", "helm", "charts", "chart", "deploy", "deployment", "manifests", "kustomize"}
_ORCH_NAMES = re.compile(r"(?i)^((docker-)?compose.*|chart|values.*|kustomization|skaffold|fly|app\.yaml|manifest|serverless|\.gitpod)\.ya?ml$|^\.gitpod\.yml$")
# Test data folders that is_test_path does not cover; `*testdata` also matches `file_format_testdata`.
_TEST_CONFIG_DIRS = {"fixtures", "__fixtures__", "testdata", "e2e"}
_TEST_CONFIG_NAME = re.compile(r"(?i)\.devtest\.")
# Folders that hold tooling, samples and docs rather than the application's own settings.
_TOOLING_DIRS = {"tools", "scripts", "docs", "doc", "examples", "example", "samples", "sample", "contrib",
                 ".devcontainer", ".vscode", ".idea"}
_BUILD_NAMES = re.compile(
    r"(?i)^(.*-wrapper\.properties|gradle\.properties|sonar-project\.properties|lombok\.config|"
    r"crowdin\.ya?ml|snapcraft\.ya?ml|"
    r"\.pre-commit.*\.ya?ml|mkdocs\.ya?ml|\.golangci.*\.ya?ml|\.yamllint.*|\.markdownlint.*|\.readthedocs\.ya?ml|"
    r"pnpm-workspace\.ya?ml|environment\.ya?ml|\.goreleaser\.ya?ml|renovate\.json|\.spectral\.ya?ml|"
    r"tox\.ini|setup\.cfg|pytest\.ini|\.flake8|mypy\.ini|\.editorconfig|\.?eslintrc.*|\.?prettierrc.*|\.?stylelintrc.*|\.?swcrc.*)$")


def config_role(path: str, siblings: set[str] | None = None) -> str | None:
    """Role of a config source: app, build, ci, orchestration, test or unclassified.

    `app` is returned only on positive evidence (a framework-defined name). `unclassified` is the
    default. `None` for lockfiles and i18n message bundles (a file with a locale sibling).
    """
    n = _name(path)
    parts = [p.lower() for p in path.split("/")[:-1]]
    if _LOCKFILE.match(n):
        return None
    if _I18N_NAME.match(n) or any(p in _I18N_DIRS for p in parts):
        return None
    if siblings is not None and _is_bundle(n, siblings):
        return None
    if (is_test_path(path) or _TEST_CONFIG_NAME.search(n)
            or any(p in _TEST_CONFIG_DIRS or p.endswith("testdata") for p in parts)):
        return "test"
    low = path.lower()
    if low.startswith(_CI_DIRS) or _CI_NAMES.match(n):
        return "ci"
    if _ORCH_NAMES.match(n) or any(p in _ORCH_DIRS for p in parts):
        return "orchestration"
    if _BUILD_NAMES.match(n) or any(p in _TOOLING_DIRS for p in parts):
        return "build"
    if _APP_CONFIG_NAME.match(n):
        return "app"
    return "unclassified"


def _locale_base(base: str) -> str | None:
    """The base of a locale-suffixed name: `ClientRes_en` -> `ClientRes`, else None."""
    m = _LOCALE_SUFFIX.match(base)
    return m.group(1) if m else None


def _is_bundle(name: str, siblings: set[str]) -> bool:
    """A .properties/.yml/.yaml file that belongs to a locale bundle (a sibling <base>_<ll>[_<CC>].<ext>)."""
    if not name.lower().endswith((".properties", ".yml", ".yaml")):
        return False
    ext = name.rsplit(".", 1)[-1].lower()
    base = name.rsplit(".", 1)[0]
    f_locale = _locale_base(base)
    for sib in siblings:
        if sib == name or not sib.lower().endswith("." + ext):
            continue
        s_base = sib.rsplit(".", 1)[0]
        if s_base == f_locale or _locale_base(s_base) == base:
            return True
    return False


def _roled(path: str, facts: Iterable[Fact], siblings: set[str] | None = None) -> Iterable[Fact]:
    """Stamp config_key Facts with the path's role; test config is marked as test code; lockfiles yield nothing."""
    role = config_role(path, siblings)
    if role is None:
        return
    for f in facts:
        f = _with_role(f, role)
        yield f.as_test() if role == "test" else f


def extract(path: str, text: str, siblings: set[str] | None = None) -> Iterable[Fact]:
    n = _name(path)
    low = n.lower()
    kind = _owner_kind(path)
    if kind:
        yield _owner_file(path, text, kind)
        return
    if low.endswith(".sql"):
        yield from _ddl(path, text)
    elif low in ("web.config", "app.config") or (low.endswith(".config") and "<configuration" in text[:2000]):
        yield from _roled(path, _dotnet_config(path, text), siblings)
    elif CONFIG_NAMES_JSON.match(n):
        yield from _roled(path, _json_config(path, text), siblings)
    elif low.endswith((".properties", ".yml", ".yaml", ".ini")):
        reader = _properties if low.endswith(".properties") else _ini if low.endswith(".ini") else _yaml
        yield from _roled(path, reader(path, text), siblings)
    elif low == ".env" or low.startswith(".env."):
        yield from _roled(path, _dotenv(path, text), siblings)
    elif low == "package.json":
        yield from _package_json(path, text)
    elif _REQUIREMENTS_TXT_RE.match(low):
        yield from _requirements(path, text)
    elif low == "pom.xml":
        yield from _pom(path, text)
    elif low in ("build.gradle", "build.gradle.kts"):
        yield from _gradle(path, text)
    elif low.endswith(".csproj"):
        yield from _csproj(path, text)
    elif low == "packages.config":
        yield from _packages_config(path, text)
    elif low == "gemfile":
        for ln, m in iter_matches(_GEM_RE, text):
            yield _dep(path, ln, m.group(1), m.group(2), "bundler")
    elif low == "go.mod":
        for ln, m in iter_matches(_GOMOD_RE, text):
            yield _dep(path, ln, m.group(1), m.group(2), "go")
    elif low == "composer.json":
        yield from _json_deps(path, text, ("require", "require-dev"), "composer")


# ---------------------------------------------------------------- helpers

def _dep(path, line, name, version, manager) -> Fact:
    return Fact.make("dependency", STACK_ID, path, line, name, version=version or "", manager=manager)


def _cfg(path, line, key, source, role="app") -> Fact:
    return Fact.make("config_key", STACK_ID, path, line, key, source=source, role=role, use="define",
                     secret_location=is_secret_key(key))


def _with_role(f: Fact, role: str) -> Fact:
    if f.kind != "config_key":
        return f
    d = f.detail_dict()
    d["role"] = role
    return Fact.make(f.kind, f.stack, f.path, f.line, f.name, **d)


def _find_line(text: str, token: str) -> int | None:
    i = text.find(token)
    return line_of(text, i) if i >= 0 else None


def _conn(path, line, name, kind="database", secret=False) -> Fact:
    return Fact.make("connection", STACK_ID, path, line, name, type=kind, secret_location=secret)


# ---------------------------------------------------------------- .NET config

_ADD = re.compile(r"<add\s+([^>]*?)/?>", re.I | re.S)
_ATTR = re.compile(r'(\w+)\s*=\s*"([^"]*)"')


def _dotnet_config(path, text):
    clean = strip_comments(text, "xml")
    for section, kind in (("appSettings", "app"), ("connectionStrings", "conn")):
        sec = re.search(rf"<{section}\b[^>]*>(.*?)</{section}>", clean, re.I | re.S)
        if not sec:
            continue
        base = sec.start(1)
        for m in _ADD.finditer(sec.group(1)):
            attrs = dict((k.lower(), v) for k, v in _ATTR.findall(m.group(1)))
            line = line_of(clean, base + m.start())
            key = attrs.get("key") or attrs.get("name")
            if not key:
                continue
            if kind == "conn":
                value = attrs.get("connectionstring", "")
                secret = is_secret_key(key) or bool(find_secret_shapes(value))
                yield _conn(path, line, key, "database", secret)
            else:
                yield _cfg(path, line, key, _name(path))


# ---------------------------------------------------------------- JSON config

def _flatten(obj, prefix=""):
    if isinstance(obj, dict):
        for k in sorted(obj):
            key = f"{prefix}:{k}" if prefix else str(k)
            if isinstance(obj[k], dict):
                yield from _flatten(obj[k], key)
            else:
                yield key
    # lists and scalars at top level carry no key names


def _json_key_lines(text: str) -> dict[str, int]:
    """Line of every object key in JSON text, by its `A:B:C` path. Tolerates // and /* */ comments.

    Keys inside arrays are not tracked (the flattened key list does not name them). On malformed
    text it returns what it found so far; the caller falls back to a text search for the rest.
    """
    lines: dict[str, int] = {}
    # frame: [is_object, key path or None when untracked, expecting a key]
    stack: list[list] = []
    pending: list[str] | None = None  # path of the key whose value is being read
    i, n, line = 0, len(text), 1
    while i < n:
        c = text[i]
        if c == "\n":
            line += 1
        elif c == "/" and text.startswith("//", i):
            j = text.find("\n", i)
            i = n if j < 0 else j - 1
        elif c == "/" and text.startswith("/*", i):
            j = text.find("*/", i + 2)
            end = n if j < 0 else j + 2
            line += text.count("\n", i, end)
            i = end - 1
        elif c == '"':
            j = i + 1
            while j < n and text[j] != '"':
                j += 2 if text[j] == "\\" else 1
            frame = stack[-1] if stack else None
            if frame and frame[0] and frame[2] and frame[1] is not None:
                try:
                    key = json.loads(text[i:j + 1])
                except ValueError:
                    break
                pending = frame[1] + [key]
                lines.setdefault(":".join(pending), line)
                frame[2] = False
            line += text.count("\n", i, j)
            i = j
        elif c in "{[":
            path = [] if not stack else (pending if stack[-1][0] else None)
            stack.append([c == "{", path, True])
            pending = None
        elif c in "}]":
            if stack:
                stack.pop()
            pending = None
        elif c == ",":
            if stack:
                stack[-1][2] = True
            pending = None
        i += 1
    return lines


def _json_config(path, text):
    try:
        data = json.loads(_JSON_COMMENT_RE.sub("", text))
    except ValueError:
        return
    located = _json_key_lines(text)
    for key in _flatten(data):
        leaf = key.rsplit(":", 1)[-1]
        line = located.get(key) or _find_line(text, f'"{leaf}"')
        if key.startswith("ConnectionStrings:"):
            yield _conn(path, line, leaf, "database", True)
        else:
            yield _cfg(path, line, key, _name(path))


# ---------------------------------------------------------------- properties / yaml / env

def _properties(path, text):
    for i, raw in enumerate(text.splitlines(), 1):
        s = raw.strip()
        if not s or s.startswith(("#", "!")):
            continue
        m = _PROPS_RE.match(s)
        if not m:
            continue
        key = m.group(1)
        if _PROPS_URL_RE.search(key) and _PROPS_JDBC_RE.search(key):
            yield _conn(path, i, key, "database", bool(find_secret_shapes(s)))
        yield _cfg(path, i, key, _name(path))


def _yaml(path, text):
    stack: list[tuple[int, str]] = []
    for i, raw in enumerate(text.splitlines(), 1):
        if not raw.strip() or raw.lstrip().startswith(("#", "-", "---")):
            continue
        m = _YAML_RE.match(raw)
        if not m:
            continue
        indent, key, rest = len(m.group(1)), m.group(2), m.group(3).strip()
        while stack and stack[-1][0] >= indent:
            stack.pop()
        stack.append((indent, key))
        if rest and not rest.startswith("#"):
            yield _cfg(path, i, ".".join(k for _, k in stack), _name(path))


def _dotenv(path, text):
    for i, raw in enumerate(text.splitlines(), 1):
        m = _DOTENV_RE.match(raw)
        if m and not raw.lstrip().startswith("#"):
            yield _cfg(path, i, m.group(1), _name(path))


_INI_SECTION = re.compile(r"^\s*([;#]\s*)?\[([A-Za-z0-9_.:\- ]+)\]\s*$")
_INI_KEY = re.compile(r"^\s*([;#]\s*)?([A-Za-z0-9_.\-]+)\s*=")
_UPPER_KEY = re.compile(r"^[A-Z][A-Z0-9_]*$")


def _ini(path, text):
    """Keys as `section.KEY`, never values. Commented keys are documented defaults (e.g. `;PORT = 3000`)."""
    section = ""
    for i, raw in enumerate(text.splitlines(), 1):
        m = _INI_SECTION.match(raw)
        if m:
            section = m.group(2).strip()
            continue
        m = _INI_KEY.match(raw)
        if not m:
            continue
        commented, key = bool(m.group(1)), m.group(2)
        if commented and not _UPPER_KEY.match(key):
            continue  # prose in a comment, not a documented key
        name = f"{section}.{key}" if section else key
        f = _cfg(path, i, name, _name(path))
        if commented:
            d = f.detail_dict()
            d["commented"] = True
            f = Fact.make(f.kind, f.stack, f.path, f.line, f.name, **d)
        yield f


# ---------------------------------------------------------------- manifests

def _json_deps(path, text, sections, manager):
    try:
        data = json.loads(text)
    except ValueError:
        return
    for sec in sections:
        deps = data.get(sec) if isinstance(data, dict) else None
        if isinstance(deps, dict):
            for name in sorted(deps):
                yield _dep(path, _find_line(text, f'"{name}"'), name, str(deps[name]), manager)


def _package_json(path, text):
    yield from _json_deps(path, text, ("dependencies", "devDependencies"), "npm")


def _requirements(path, text):
    for i, raw in enumerate(text.splitlines(), 1):
        s = raw.split("#", 1)[0].strip()
        if not s or s.startswith("-"):
            continue
        m = _REQS_RE.match(s)
        if m:
            yield _dep(path, i, m.group(1), (m.group(2) or "") + (m.group(3) or ""), "pip")


def _pom(path, text):
    clean = strip_comments(text, "xml")
    for m in _POM_DEP_RE.finditer(clean):
        g = _POM_GROUP_RE.search(m.group(1))
        a = _POM_ARTIFACT_RE.search(m.group(1))
        v = _POM_VERSION_RE.search(m.group(1))
        if a:
            name = f"{g.group(1)}:{a.group(1)}" if g else a.group(1)
            yield _dep(path, line_of(clean, m.start()), name, v.group(1) if v else "", "maven")


def _gradle(path, text):
    for ln, m in iter_matches(_GRADLE_RE, strip_comments(text, "c")):
        yield _dep(path, ln, m.group(1), m.group(2), "gradle")


def _csproj(path, text):
    for ln, m in iter_matches(_CSPROJ_RE, text):
        yield _dep(path, ln, m.group(1), m.group(2), "nuget")


def _packages_config(path, text):
    for ln, m in iter_matches(_PACKAGES_CONFIG_RE, text):
        yield _dep(path, ln, m.group(1), m.group(2), "nuget")


# ---------------------------------------------------------------- ownership files

_OWNER_KINDS = {
    "codeowners": "codeowners",
    "maintainers": "maintainers",
    "maintainers.md": "maintainers",
    "owners": "maintainers",
    "contributing.md": "contributing",
    "governance.md": "governance",
}
_OWNER_DIRS = ("", ".github/", "docs/")


def _owner_kind(path: str) -> str | None:
    low = path.lower()
    for d in _OWNER_DIRS:
        if low.startswith(d) and "/" not in low[len(d):]:
            return _OWNER_KINDS.get(low[len(d):])
    return None


def _owner_file(path, text, kind) -> Fact:
    lines = text.splitlines()
    if kind in ("contributing", "governance"):
        entries = len(lines)
    else:
        entries = sum(1 for s in lines if s.strip() and not s.lstrip().startswith("#"))
    # `kind` is a detail key here and Fact.make's own first parameter, so build the Fact directly.
    return Fact("owner_file", STACK_ID, path, None, path, (("entries", entries), ("kind", kind)))


# ---------------------------------------------------------------- DDL

_DIALECTS = {
    "postgres": "postgres", "postgresql": "postgres", "pgsql": "postgres",
    "mysql": "mysql", "mariadb": "mysql",
    "h2": "h2", "hsqldb": "hsqldb", "sqlite": "sqlite", "sqlite3": "sqlite",
    "oracle": "oracle", "mssql": "mssql", "sqlserver": "mssql",
}
_SQL_NOISE = re.compile(r"'(?:[^']|'')*'|\"[^\"\n]*\"|--[^\n]*|/\*.*?\*/", re.S)
_IDENT = r"(?:\"[^\"]+\"|`[^`]+`|\[[^\]]+\]|[\w$]+)(?:\s*\.\s*(?:\"[^\"]+\"|`[^`]+`|\[[^\]]+\]|[\w$]+))*"
_CREATE_TABLE = re.compile(
    rf"\bCREATE\s+(?:(?:GLOBAL\s+|LOCAL\s+)?(?:TEMP|TEMPORARY)\s+|UNLOGGED\s+)?TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?({_IDENT})\s*\(",
    re.I)
_CREATE_INDEX = re.compile(
    rf"\bCREATE\s+(UNIQUE\s+)?(?:(?:CLUSTERED|NONCLUSTERED|FULLTEXT|SPATIAL)\s+)?INDEX\s+(?:CONCURRENTLY\s+)?"
    rf"(?:IF\s+NOT\s+EXISTS\s+)?({_IDENT})\s+ON\s+(?:ONLY\s+)?({_IDENT})\s*(?:USING\s+(\w+)\s*)?\(", re.I)
_ALTER_FK = re.compile(
    rf"\bALTER\s+TABLE\s+(?:ONLY\s+)?(?:IF\s+EXISTS\s+)?({_IDENT})\s+ADD\s+(?:CONSTRAINT\s+({_IDENT})\s+)?"
    rf"FOREIGN\s+KEY\s*\(([^)]*)\)\s*REFERENCES\s+({_IDENT})\s*(?:\(([^)]*)\))?", re.I)
_INLINE_FK = re.compile(
    rf"^(?:CONSTRAINT\s+({_IDENT})\s+)?FOREIGN\s+KEY\s*\(([^)]*)\)\s*REFERENCES\s+({_IDENT})\s*(?:\(([^)]*)\))?", re.I)
_COL_REF = re.compile(rf"\bREFERENCES\s+({_IDENT})\s*(?:\(([^)]*)\))?", re.I)
_NOT_COLUMN = {"CONSTRAINT", "PRIMARY", "FOREIGN", "UNIQUE", "CHECK", "KEY", "INDEX", "FULLTEXT", "SPATIAL",
               "EXCLUDE", "LIKE", "PERIOD"}
_TYPE_STOP = {"NOT", "NULL", "PRIMARY", "REFERENCES", "DEFAULT", "UNIQUE", "CHECK", "GENERATED", "AUTO_INCREMENT",
              "AUTOINCREMENT", "IDENTITY", "CONSTRAINT", "COLLATE", "COMMENT", "ON", "AS", "KEY"}
_COL_NAME = re.compile(r"\s*(\"[^\"]+\"|`[^`]+`|\[[^\]]+\]|[^\s(]+)\s*(.*)$", re.S)
_TOKEN = re.compile(r"[^\s(]+(?:\s*\([^)]*\))?|\S+")
MAX_COLUMNS = 60
MAX_EXPR = 120


def _ident(s: str) -> str:
    """Identifier without quoting characters; schema prefix kept."""
    return re.sub(r"\s*\.\s*", ".", re.sub(r"[\"`\[\]]", "", s.strip()))


def _collapse(s: str, limit: int | None = None) -> str:
    s = re.sub(r"\s+", " ", s).strip()
    return s[:limit] if limit else s


def sql_dialect(path: str) -> str | None:
    """Dialect from a directory or file-name segment of the path (db/postgres/schema.sql)."""
    for part in re.split(r"[/\\\-_.]", path.lower()):
        if part in _DIALECTS:
            return _DIALECTS[part]
    return None


def _match_paren(text: str, start: int) -> int:
    """Index of the ')' that closes the '(' at text[start], or -1. Quote aware."""
    depth, i, n = 0, start, len(text)
    while i < n:
        c = text[i]
        if c in "'\"`":
            j = text.find(c, i + 1)
            if j < 0:
                return -1
            i = j
        elif c == "(":
            depth += 1
        elif c == ")":
            depth -= 1
            if depth == 0:
                return i
        i += 1
    return -1


def _split_top(body: str, base: int):
    """Yield (offset in the cleaned text, part) for each top-level comma separated part."""
    depth, start, i, n = 0, 0, 0, len(body)
    while i <= n:
        c = body[i] if i < n else ","
        if c in "'\"`" and i < n:
            j = body.find(c, i + 1)
            i = n if j < 0 else j
        elif c == "(":
            depth += 1
        elif c == ")":
            depth -= 1
        elif c == "," and depth <= 0:
            part = body[start:i]
            if part.strip():
                yield base + start + (len(part) - len(part.lstrip())), part.strip()
            start = i + 1
        i += 1


def _column(part: str) -> str | None:
    m = _COL_NAME.match(part)
    if not m or m.group(1).upper() in _NOT_COLUMN:
        return None
    name, rest = _ident(m.group(1)), m.group(2)
    type_tokens = []
    for tok in _TOKEN.findall(rest):
        if tok.split("(")[0].upper() in _TYPE_STOP:
            break
        type_tokens.append(re.sub(r"\s*,\s*", ",", re.sub(r"\s+\(", "(", tok)))
    out = " ".join([name, *type_tokens])
    if re.search(r"\bPRIMARY\s+KEY\b", rest, re.I):
        out += " pk"
    if re.search(r"\bNOT\s+NULL\b", rest, re.I):
        out += " not null"
    return out


def _schema_fact(path, line, name, **detail) -> Fact:
    return Fact.make("schema_object", STACK_ID, path, line, name, **detail)


def _table_fact(path, line, name, dialect, cols) -> Fact:
    # Fact.make sorts list values; a table's column order is meaningful, so it is added unsorted.
    f = _schema_fact(path, line, name, type="table", dialect=dialect, column_count=len(cols))
    return Fact(f.kind, f.stack, f.path, f.line, f.name,
                tuple(sorted(f.detail + (("columns", tuple(cols[:MAX_COLUMNS])),))))


def _fk(path, line, table, name, cols, ref, ref_cols, dialect) -> Fact:
    expr = _collapse(cols, MAX_EXPR)
    target = _ident(ref) + (f"({_collapse(ref_cols)})" if ref_cols else "")
    return _schema_fact(path, line, _ident(name) if name else f"{table}({expr})", type="fk", table=table,
                        expression=expr, references=target, dialect=dialect)


def _ddl(path: str, text: str) -> Iterable[Fact]:
    """Tables, indexes and foreign keys from DDL. Not a SQL parser: INSERT-only files yield nothing."""
    def blank(m):
        s = m.group(0)
        # Comments and string literals are blanked (newlines kept) so their text is never matched or recorded.
        keep = s[0] if s[0] in "'\"" else ""
        body = re.sub(r"[^\n]", " ", s[1:-1] if keep else s)
        return keep + body + (s[-1] if keep else "")

    clean = _SQL_NOISE.sub(lambda m: m.group(0) if m.group(0)[0] == '"' else blank(m), text)
    dialect = sql_dialect(path)

    for m in _CREATE_TABLE.finditer(clean):
        table = _ident(m.group(1))
        end = _match_paren(clean, m.end() - 1)
        if end < 0:
            continue
        cols, fks = [], []
        for off, part in _split_top(clean[m.end():end], m.end()):
            line = line_of(clean, off)
            fk = _INLINE_FK.match(part)
            if fk:
                fks.append(_fk(path, line, table, fk.group(1), fk.group(2), fk.group(3), fk.group(4), dialect))
                continue
            col = _column(part)
            if col is None:
                continue
            cols.append(col)
            ref = _COL_REF.search(part)
            if ref:
                fks.append(_fk(path, line, table, None, col.split(" ", 1)[0], ref.group(1), ref.group(2), dialect))
        yield _table_fact(path, line_of(clean, m.start()), table, dialect, cols)
        yield from fks

    for m in _CREATE_INDEX.finditer(clean):
        end = _match_paren(clean, m.end() - 1)
        if end < 0:
            continue
        detail = dict(type="index", unique=bool(m.group(1)), table=_ident(m.group(3)), dialect=dialect,
                      expression=_collapse(clean[m.end():end], MAX_EXPR))
        if m.group(4):
            detail["method"] = m.group(4).lower()
        yield _schema_fact(path, line_of(clean, m.start()), _ident(m.group(2)), **detail)

    for m in _ALTER_FK.finditer(clean):
        yield _fk(path, line_of(clean, m.start()), _ident(m.group(1)), m.group(2), m.group(3), m.group(4),
                  m.group(5), dialect)


# ---------------------------------------------------------------- unsupported ecosystems

# ecosystem id -> (predicate over file basenames/paths, ids of supported Stacks that cover it)
ECOSYSTEMS = {
    "go": (lambda files: [f for f in files if _name(f) == "go.mod"], ("go",)),
    "ruby": (lambda files: [f for f in files if _name(f) in ("Gemfile",)], ()),
    "rust": (lambda files: [f for f in files if _name(f) == "Cargo.toml"], ()),
    "php": (lambda files: [f for f in files if _name(f) == "composer.json"], ()),
    "django": (lambda files: [f for f in files if _name(f) == "manage.py"], ()),
    "java": (lambda files: [f for f in files if _name(f) in ("pom.xml", "build.gradle", "build.gradle.kts")], ("java-spring",)),
    "dotnet": (lambda files: [f for f in files if f.lower().endswith(".csproj")], ("aspnet", "aspnet-core")),
    "node": (lambda files: [f for f in files if _name(f) == "package.json"], ("node-express",)),
    "python": (lambda files: [f for f in files if re.match(r"^(requirements.*\.txt|pyproject\.toml|setup\.py)$", _name(f))], ("python-flask",)),
}


def unsupported_stacks(files: list[str], detected_ids: set[str]) -> list[tuple[str, list[str]]]:
    """Return (ecosystem id, marker files) for ecosystems present with no supported Stack covering them."""
    out = []
    for eco in sorted(ECOSYSTEMS):
        finder, covered_by = ECOSYSTEMS[eco]
        markers = sorted(finder(files))
        if markers and not (detected_ids & set(covered_by)):
            out.append((eco, markers))
    return out
