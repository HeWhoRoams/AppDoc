"""Generic extractor: runs on every Target and owns config files and dependency manifests.

Stack extractors read code files only. This module reads: web.config/app.config, appsettings*.json,
*.properties, *.yml/*.yaml, .env*, package.json, requirements*.txt, pom.xml, build.gradle, *.csproj,
packages.config, Gemfile, go.mod, composer.json. It never records a config value.
"""

from __future__ import annotations

import json
import re
from typing import Iterable

from ..facts import Fact
from ..secrets import is_secret_key, find_secret_shapes
from .base import iter_matches, line_of, strip_comments

STACK_ID = "generic"

CONFIG_NAMES_JSON = re.compile(r"^(appsettings(\..+)?|config|settings|local\.settings)\.json$", re.I)


def _name(path: str) -> str:
    return path.rsplit("/", 1)[-1]


def extract(path: str, text: str) -> Iterable[Fact]:
    n = _name(path)
    low = n.lower()
    if low in ("web.config", "app.config") or (low.endswith(".config") and "<configuration" in text[:2000]):
        yield from _dotnet_config(path, text)
    elif CONFIG_NAMES_JSON.match(n):
        yield from _json_config(path, text)
    elif low.endswith(".properties"):
        yield from _properties(path, text)
    elif low.endswith((".yml", ".yaml")):
        yield from _yaml(path, text)
    elif low == ".env" or low.startswith(".env."):
        yield from _dotenv(path, text)
    elif low == "package.json":
        yield from _package_json(path, text)
    elif re.match(r"^requirements.*\.txt$", low):
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
        for ln, m in iter_matches(re.compile(r"(?m)^\s*gem\s+['\"]([^'\"]+)['\"](?:\s*,\s*['\"]([^'\"]+)['\"])?"), text):
            yield _dep(path, ln, m.group(1), m.group(2), "bundler")
    elif low == "go.mod":
        for ln, m in iter_matches(re.compile(r"(?m)^\s*(?:require\s+)?([\w.\-/]+\.[\w.\-/]+)\s+(v[\w.\-+]+)\s*$"), text):
            yield _dep(path, ln, m.group(1), m.group(2), "go")
    elif low == "composer.json":
        yield from _json_deps(path, text, ("require", "require-dev"), "composer")


# ---------------------------------------------------------------- helpers

def _dep(path, line, name, version, manager) -> Fact:
    return Fact.make("dependency", STACK_ID, path, line, name, version=version or "", manager=manager)


def _cfg(path, line, key, source) -> Fact:
    return Fact.make("config_key", STACK_ID, path, line, key, source=source, secret_location=is_secret_key(key))


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


def _json_config(path, text):
    try:
        data = json.loads(re.sub(r"(?m)^\s*//.*$", "", text))
    except ValueError:
        return
    conns = data.get("ConnectionStrings") if isinstance(data, dict) else None
    for key in _flatten(data):
        leaf = key.rsplit(":", 1)[-1]
        line = _find_line(text, f'"{leaf}"')
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
        m = re.match(r"([^=:\s]+)\s*[=:]", s)
        if not m:
            continue
        key = m.group(1)
        if re.search(r"(?i)datasource\.url|jdbc[_.]url|\.url$", key) and re.search(r"(?i)jdbc|datasource", key):
            yield _conn(path, i, key, "database", bool(find_secret_shapes(s)))
        yield _cfg(path, i, key, _name(path))


def _yaml(path, text):
    stack: list[tuple[int, str]] = []
    for i, raw in enumerate(text.splitlines(), 1):
        if not raw.strip() or raw.lstrip().startswith(("#", "-", "---")):
            continue
        m = re.match(r"^(\s*)([A-Za-z0-9_.\-]+)\s*:(.*)$", raw)
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
        m = re.match(r"^\s*(?:export\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*=", raw)
        if m and not raw.lstrip().startswith("#"):
            yield _cfg(path, i, m.group(1), _name(path))


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
        m = re.match(r"([A-Za-z0-9_.\-\[\]]+)\s*(?:(==|>=|<=|~=|>|<)\s*([\w.*+\-]+))?", s)
        if m:
            yield _dep(path, i, m.group(1), (m.group(2) or "") + (m.group(3) or ""), "pip")


def _pom(path, text):
    clean = strip_comments(text, "xml")
    for m in re.finditer(r"<dependency>(.*?)</dependency>", clean, re.S):
        g = re.search(r"<groupId>\s*([^<\s]+)", m.group(1))
        a = re.search(r"<artifactId>\s*([^<\s]+)", m.group(1))
        v = re.search(r"<version>\s*([^<\s]+)", m.group(1))
        if a:
            name = f"{g.group(1)}:{a.group(1)}" if g else a.group(1)
            yield _dep(path, line_of(clean, m.start()), name, v.group(1) if v else "", "maven")


def _gradle(path, text):
    rx = re.compile(r"""(?m)^\s*(?:implementation|api|compile|runtimeOnly|testImplementation|compileOnly)\s*\(?\s*['"]([^'":]+:[^'":]+)(?::([^'"]+))?['"]""")
    for ln, m in iter_matches(rx, strip_comments(text, "c")):
        yield _dep(path, ln, m.group(1), m.group(2), "gradle")


def _csproj(path, text):
    for ln, m in iter_matches(re.compile(r'<PackageReference\s+[^>]*Include="([^"]+)"(?:[^>]*Version="([^"]+)")?', re.I), text):
        yield _dep(path, ln, m.group(1), m.group(2), "nuget")


def _packages_config(path, text):
    for ln, m in iter_matches(re.compile(r'<package\s+[^>]*id="([^"]+)"[^>]*?(?:version="([^"]+)")?', re.I), text):
        yield _dep(path, ln, m.group(1), m.group(2), "nuget")


# ---------------------------------------------------------------- unsupported ecosystems

# ecosystem id -> (predicate over file basenames/paths, ids of supported Stacks that cover it)
ECOSYSTEMS = {
    "go": (lambda files: [f for f in files if _name(f) == "go.mod"], ()),
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
