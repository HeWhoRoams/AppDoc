"""Python Flask Stack: routes, SQL, connections, config reads, outbound calls, auth checks, messages.

Reads ``.py`` files only (dependency and config files belong to the generic extractor).
Regex based and comment-aware. It never records a secret value: connections and config keys
carry ``secret_location`` only, URLs are cut at the query string and stripped of user info.
"""

from __future__ import annotations

import re
from typing import Iterable

from ..facts import Fact
from ..secrets import find_secret_shapes, is_secret_key
from .base import Stack, line_of, strip_comments

STACK_ID = "python-flask"

_MANIFEST_RE = re.compile(r"^(requirements[^/]*\.txt|pyproject\.toml|setup\.py)$", re.I)
_FLASK_IMPORT = re.compile(r"(?m)^\s*(?:from\s+flask\b|import\s+flask\b)")
_VERBS = ("get", "post", "put", "delete", "patch")
_AUTH_DECORATOR = re.compile(
    r"(login_required|roles_required|roles_accepted|permission_required|jwt_required|"
    r"auth_required|requires_auth|admin_required|token_required|requires_roles)", re.I)
_SQL_START = re.compile(r"^\s*\(?\s*(select|insert|update|delete|merge|with|exec|execute|call|truncate)\b", re.I)
_TABLE = r"([A-Za-z_#@\[\"`{][\w.\[\]\"`{}#@$]*)"


class PythonFlaskStack(Stack):
    id = STACK_ID
    extensions = frozenset({".py"})

    def detect(self, files: list[str]) -> list[str]:
        names = [f.rsplit("/", 1)[-1] for f in files]
        if "manage.py" in names:  # Django, not this Stack
            return []
        if not any(n.lower().endswith(".py") for n in names):
            return []
        return sorted(f for f in files if _MANIFEST_RE.match(f.rsplit("/", 1)[-1]))

    def extract(self, path: str, text: str) -> Iterable[Fact]:
        return _extract(path, text)


STACK = PythonFlaskStack()


# ---------------------------------------------------------------- lexical helpers

def _parse_string(s: str, i: int):
    """Parse a Python string literal starting at i (optional prefix). Return (value, end) or None."""
    j = i
    while j < len(s) and j - i < 2 and s[j] in "rRbBuUfF":
        j += 1
    if j >= len(s) or s[j] not in "\"'":
        return None
    q = s[j]
    if s.startswith(q * 3, j):
        end = s.find(q * 3, j + 3)
        return (None, None) if end < 0 else (s[j + 3:end], end + 3)
    k = j + 1
    while k < len(s) and s[k] != q and s[k] != "\n":
        k += 2 if s[k] == "\\" else 1
    if k >= len(s) or s[k] != q:
        return None
    return s[j + 1:k], k + 1


def _clean(text: str) -> str:
    """Blank comments and docstrings (string-aware), keeping every newline."""
    text = strip_comments(text, "hash")
    rx = re.compile(r'("""|\'\'\')(?:.*?)\1|"(?:\\.|[^"\\\n])*"|\'(?:\\.|[^\'\\\n])*\'|#[^\n]*', re.S)

    def blank(m):
        return re.sub(r"[^\n]", " ", m.group(0))

    def sub(m):
        tok = m.group(0)
        if tok.startswith("#"):
            return blank(m)
        if m.group(1):  # triple quoted: blank only docstrings (after ':' or at file start)
            before = text[:m.start()].rstrip()
            if not before or before.endswith(":"):
                return blank(m)
        return tok

    return rx.sub(sub, text)


def _call_args(s: str, open_idx: int):
    """s[open_idx] == '('. Return (args_text, index_after_close)."""
    depth, i, n = 0, open_idx, len(s)
    while i < n:
        c = s[i]
        if c in "\"'":
            r = _parse_string(s, i)
            if r and r[1]:
                i = r[1]
                continue
        elif c in "([{":
            depth += 1
        elif c in ")]}":
            depth -= 1
            if depth == 0:
                return s[open_idx + 1:i], i + 1
        i += 1
    return s[open_idx + 1:], n


def _leading_string(args: str):
    i = 0
    while i < len(args) and (args[i].isspace() or args[i] == "("):
        i += 1
    parts = []
    while True:
        r = _parse_string(args, i)
        if not r or r[0] is None:
            break
        parts.append(r[0])
        i = r[1]
        while i < len(args) and args[i].isspace():
            i += 1
    return "".join(parts) if parts else None


def _first_arg(args: str) -> str:
    depth, i = 0, 0
    while i < len(args):
        c = args[i]
        if c in "\"'":
            r = _parse_string(args, i)
            if r and r[1]:
                i = r[1]
                continue
        elif c in "([{":
            depth += 1
        elif c in ")]}":
            depth -= 1
        elif c == "," and depth == 0:
            break
        i += 1
    return args[:i].strip()


def _kwarg_string(args: str, name: str):
    m = re.search(rf"\b{name}\s*=\s*", args)
    if not m:
        return None
    r = _parse_string(args, m.end())
    return r[0] if r else None


def _assigned_string(text: str, var: str, pos: int):
    last = None
    for m in re.finditer(rf"(?m)^[ \t]*{re.escape(var)}\s*(?::[^=\n]+)?=(?!=)\s*", text):
        if m.start() < pos:
            last = m
    if not last:
        return None
    return _leading_string(text[last.end():last.end() + 2000])


def _resolve_string(text: str, expr: str, pos: int):
    lit = _leading_string(expr)
    if lit is not None:
        return lit
    if re.fullmatch(r"[A-Za-z_]\w*", expr or ""):
        return _assigned_string(text, expr, pos)
    return None


def _safe_url(u: str) -> str:
    u = u.split("?", 1)[0]
    u = re.sub(r"^([a-z][a-z0-9+.-]*://)[^/@\s]*@", r"\1", u, flags=re.I)
    return u[:200]


def _first_str_token(args: str):
    """First string literal inside a call's first argument (list or plain)."""
    m = re.search(r"[\"']", _first_arg(args))
    if not m:
        return None
    first = _first_arg(args)
    r = _parse_string(first, m.start())
    return r[0] if r and r[0] is not None else None


# ---------------------------------------------------------------- SQL

def _clean_table(t: str) -> str:
    return t.strip().strip(",;()").replace("[", "").replace("]", "").replace('"', "").replace("`", "")


def _sql_facts(path, line, sql):
    m = _SQL_START.match(sql)
    if not m:
        return
    op = m.group(1).lower()
    if op in ("exec", "execute", "call"):
        pm = re.match(r"^\s*\(?\s*(?:exec|execute|call)\s+" + _TABLE, sql, re.I)
        if pm:
            yield Fact.make("data_access", STACK_ID, path, line, _clean_table(pm.group(1)),
                            type="stored_procedure", operation="execute")
        return
    if op == "with":
        op = "select"
    tables = []
    if op == "select":
        tables = re.findall(r"(?i)\b(?:from|join)\s+" + _TABLE, sql)
    elif op in ("insert", "merge"):
        tables = re.findall(r"(?i)\binto\s+" + _TABLE, sql)[:1]
    elif op == "update":
        tables = re.findall(r"(?i)^\s*\(?\s*update\s+" + _TABLE, sql)[:1]
    elif op == "delete":
        tables = re.findall(r"(?i)\bfrom\s+" + _TABLE, sql)[:1]
    elif op == "truncate":
        tables = re.findall(r"(?i)\btable\s+" + _TABLE, sql)[:1]
    names = sorted({_clean_table(t) for t in tables if _clean_table(t)})
    for n in names or ["(unparsed)"]:
        yield Fact.make("data_access", STACK_ID, path, line, n, type="sql", operation=op)


# ---------------------------------------------------------------- main extraction

def _extract(path: str, text: str) -> Iterable[Fact]:
    t = _clean(text)
    out: list[Fact] = []
    is_flask = bool(_FLASK_IMPORT.search(t))
    L = lambda off: line_of(t, off)

    if is_flask:
        out.extend(_routes(path, t))
    out.extend(_auth(path, t))
    out.extend(_models(path, t))
    out.extend(_sql(path, t))
    out.extend(_connections(path, t))
    out.extend(_config(path, t))
    out.extend(_external(path, t))
    out.extend(_messages(path, t))
    return out


# --- routes ------------------------------------------------------------

def _routes(path, t):
    apps = set(re.findall(r"(?m)^\s*(\w+)\s*(?::[^=\n]+)?=\s*(?:\w+\.)?Flask\s*\(", t))
    bps: dict[str, tuple[str, bool]] = {}  # var -> (prefix, unresolved)
    for m in re.finditer(r"(?m)^\s*(\w+)\s*(?::[^=\n]+)?=\s*(?:\w+\.)?Blueprint\s*\(", t):
        args, _ = _call_args(t, m.end() - 1)
        pre = _kwarg_string(args, "url_prefix")
        bps[m.group(1)] = (pre or "", pre is None)
    for m in re.finditer(r"\bregister_blueprint\s*\(", t):
        args, _ = _call_args(t, m.end() - 1)
        var = _first_arg(args).split(".")[-1]
        pre = _kwarg_string(args, "url_prefix")
        if var in bps:
            if pre is not None:
                bps[var] = (pre, False)
            elif bps[var][1]:
                bps[var] = ("", False)  # registered here without a prefix
    for m in re.finditer(r"(?m)^([ \t]*)@([A-Za-z_][\w.]*)[ \t]*(\()?", t):
        dec = m.group(2)
        args = ""
        end = m.end()
        if m.group(3):
            args, end = _call_args(t, m.end() - 1)
        owner, _, verb = dec.rpartition(".")
        if not owner or (verb != "route" and verb not in _VERBS):
            continue
        route = _leading_string(args)
        if route is None:
            continue
        hm = re.compile(r"\b(def|class)\s+(\w+)").search(t, end)
        handler = hm.group(2) if hm and hm.group(1) == "def" else ""
        if owner in bps:
            prefix, unresolved = bps[owner]
        elif owner in apps:
            prefix, unresolved = "", False
        else:
            prefix, unresolved = "", True
        full = (prefix.rstrip("/") + "/" + route.lstrip("/")) if prefix else route
        if verb == "route":
            mm = re.search(r"\bmethods\s*=\s*[\[(]([^\])]*)[\])]", args)
            methods = sorted({x.upper() for x in re.findall(r"[\"'](\w+)[\"']", mm.group(1))}) if mm else []
            methods = methods or ["GET"]
        else:
            methods = [verb.upper()]
        for meth in methods:
            d = dict(type="route", method=meth, handler=handler)
            if unresolved:
                d["prefix_unresolved"] = True
            out_fact = Fact.make("entry_point", STACK_ID, path, line_of(t, m.start()), full, **d)
            yield out_fact


# --- auth --------------------------------------------------------------

def _auth(path, t):
    for m in re.finditer(r"(?m)^[ \t]*@([A-Za-z_][\w.]*)[ \t]*(\()?", t):
        dec = m.group(1)
        if not _AUTH_DECORATOR.search(dec.rsplit(".", 1)[-1]):
            continue
        args = ""
        if m.group(2):
            args, _ = _call_args(t, m.end() - 1)
        text = ("@" + dec + ("(" + " ".join(args.split()) + ")" if m.group(2) else ""))[:120]
        low = dec.lower()
        mech = ("jwt" if "jwt" in low else "flask-security" if "roles" in low else
                "permission" if "permission" in low else "login" if "login" in low else "decorator")
        roles = sorted(set(re.findall(r"[\"']([\w .:-]+)[\"']", args))) if m.group(2) else []
        d = dict(mechanism=mech)
        if roles and mech in ("flask-security", "permission"):
            d["roles"] = roles
        yield Fact.make("auth_check", STACK_ID, path, line_of(t, m.start()), text, **d)
    for m in re.finditer(r"\bcurrent_user\.(has_role|has_roles|can|is_authenticated|is_admin)\b(\s*\()?", t):
        args = ""
        if m.group(2):
            args, _ = _call_args(t, m.end() - 1)
        text = f"current_user.{m.group(1)}" + (f"({' '.join(args.split())})" if m.group(2) else "")
        d = dict(mechanism="current_user")
        roles = sorted(set(re.findall(r"[\"']([\w .:-]+)[\"']", args)))
        if roles:
            d["roles"] = roles
        yield Fact.make("auth_check", STACK_ID, path, line_of(t, m.start()), text[:120], **d)


# --- data access -------------------------------------------------------

def _models(path, t):
    for m in re.finditer(r"(?m)^class\s+(\w+)\s*\(([^)]*)\)\s*:", t):
        bases = m.group(2)
        if not re.search(r"\b(?:\w+\.)?(?:Model|Base|DeclarativeBase)\b", bases):
            continue
        nxt = re.search(r"(?m)^\S", t[m.end():])
        body = t[m.end(): m.end() + nxt.start()] if nxt else t[m.end():]
        tn = re.search(r"__tablename__\s*=\s*[\"']([^\"']+)[\"']", body)
        if not tn and "db.Model" not in bases:
            continue
        yield Fact.make("data_access", STACK_ID, path, line_of(t, m.start()), tn.group(1) if tn else m.group(1),
                        type="entity", operation="model", **{"class": m.group(1)})


def _sql(path, t):
    for m in re.finditer(r"(?<![\w])(?:\w+\.)*(execute|executemany|executescript|exec_driver_sql|text|read_sql|read_sql_query)\s*\(", t):
        args, _ = _call_args(t, m.end() - 1)
        sql = _resolve_string(t, _first_arg(args), m.start())
        if sql:
            yield from _sql_facts(path, line_of(t, m.start()), sql)
    for m in re.finditer(r"\.callproc\s*\(", t):
        args, _ = _call_args(t, m.end() - 1)
        name = _resolve_string(t, _first_arg(args), m.start())
        if name:
            yield Fact.make("data_access", STACK_ID, path, line_of(t, m.start()), _clean_table(name.split("(")[0]),
                            type="stored_procedure", operation="execute")


# --- connections / config ---------------------------------------------

_CONNECT = re.compile(r"(?<![\w.])((?:sqlalchemy\.|sa\.)?create_engine|pyodbc\.connect|psycopg2\.connect|sqlite3\.connect|"
                      r"pymysql\.connect|mysql\.connector\.connect|MySQLdb\.connect|pymssql\.connect)\s*\(")


def _connections(path, t):
    for m in _CONNECT.finditer(t):
        args, _ = _call_args(t, m.end() - 1)
        name = re.sub(r"^(sqlalchemy|sa)\.", "", m.group(1))
        resolved = _resolve_string(t, _first_arg(args), m.start()) or ""
        probe = args + " " + resolved
        secret = bool(is_secret_key(probe) or re.search(r"(?i)\b(user|uid|username)\b", probe)
                      or find_secret_shapes(probe) or re.search(r"://[^/\s\"']+:[^/\s\"']*@", probe))
        yield Fact.make("connection", STACK_ID, path, line_of(t, m.start()), name,
                        type="database", secret_location=bool(secret))


def _config(path, t):
    pats = (
        r"\b(?:current_app|app)\.config(?:\s*\[\s*|\.get\(\s*)[\"'](\w[\w.\-]*)[\"']",
        r"\b(?:os\.)?environ(?:\s*\[\s*|\.get\(\s*)[\"'](\w+)[\"']",
        r"\bos\.getenv\(\s*[\"'](\w+)[\"']",
        r"(?<![\w.])getenv\(\s*[\"'](\w+)[\"']",
    )
    for p in pats:
        for m in re.finditer(p, t):
            yield Fact.make("config_key", STACK_ID, path, line_of(t, m.start()), m.group(1),
                            source="code", secret_location=is_secret_key(m.group(1)))


# --- external calls ----------------------------------------------------

def _external(path, t):
    for m in re.finditer(r"(?<![\w.])(requests|httpx)\.(get|post|put|delete|patch|head|options|request)\s*\(", t):
        args, _ = _call_args(t, m.end() - 1)
        first = _first_arg(args)
        if m.group(2) == "request":  # request(method, url)
            rest = args[len(first) + 1:]
            first = _first_arg(rest)
        url = _resolve_string(t, first, m.start())
        name = _safe_url(url) if url else f"{m.group(1)}.{m.group(2)}"
        yield Fact.make("external_call", STACK_ID, path, line_of(t, m.start()), name,
                        type="http", call=f"{m.group(1)}.{m.group(2)}")
    for m in re.finditer(r"(?<![\w.])urllib\.request\.urlopen\s*\(", t):
        args, _ = _call_args(t, m.end() - 1)
        url = _resolve_string(t, _first_arg(args), m.start())
        yield Fact.make("external_call", STACK_ID, path, line_of(t, m.start()), _safe_url(url) if url else "urllib.request.urlopen",
                        type="http", call="urllib.request.urlopen")
    for m in re.finditer(r"(?<![\w.])smtplib\.(SMTP_SSL|SMTP)\s*\(", t):
        args, _ = _call_args(t, m.end() - 1)
        host = _resolve_string(t, _first_arg(args), m.start())
        yield Fact.make("external_call", STACK_ID, path, line_of(t, m.start()), host[:200] if host else f"smtplib.{m.group(1)}",
                        type="email", call=f"smtplib.{m.group(1)}")
    for m in re.finditer(r"(?<![\w.])(subprocess\.(?:run|Popen|call|check_output|check_call)|os\.system|os\.popen)\s*\(", t):
        args, _ = _call_args(t, m.end() - 1)
        tok = _first_str_token(args)
        exe = tok.split()[0] if tok and tok.split() else m.group(1)
        yield Fact.make("external_call", STACK_ID, path, line_of(t, m.start()), exe[:120],
                        type="process", call=m.group(1))
    for m in re.finditer(r"(?<![\w.])open\s*\(", t):
        args, _ = _call_args(t, m.end() - 1)
        p = _resolve_string(t, _first_arg(args), m.start())
        rest = args[len(_first_arg(args)) + 1:]
        mode = _leading_string(rest.strip().split(",")[0]) if rest.strip() else None
        yield Fact.make("external_call", STACK_ID, path, line_of(t, m.start()), p[:200] if p else "open",
                        type="file", call="open", **({"mode": mode} if mode else {}))
    for m in re.finditer(r"(?<![\w.])((?:os\.(?:remove|unlink|rename|makedirs|mkdir|rmdir))|(?:shutil\.\w+))\s*\(", t):
        args, _ = _call_args(t, m.end() - 1)
        p = _resolve_string(t, _first_arg(args), m.start())
        yield Fact.make("external_call", STACK_ID, path, line_of(t, m.start()), p[:200] if p else m.group(1),
                        type="file", call=m.group(1))


# --- messages ----------------------------------------------------------

def _ctx(text: str, default: str = "error") -> str:
    if re.search(r"(?i)\b(required|invalid|must|missing|cannot be|too (?:long|short)|not valid)\b", text):
        return "validation"
    return default


def _msg(path, t, off, text, context):
    text = " ".join(text.split())[:200]
    if not text or find_secret_shapes(text):
        return None
    return Fact.make("message", STACK_ID, path, line_of(t, off), text, context=context)


def _messages(path, t):
    for m in re.finditer(r"(?<![\w])(?:\w+\.)?flash\s*\(", t):
        args, _ = _call_args(t, m.end() - 1)
        s = _leading_string(args)
        if s:
            cat = _kwarg_string(args, "category")
            if cat is None:
                rest = args[len(_first_arg(args)) + 1:]
                cat = _leading_string(rest) or ""
            default = "error" if cat.lower() in ("error", "danger", "warning") else "info"
            f = _msg(path, t, m.start(), s, _ctx(s, default) if default == "error" else default)
            if f:
                yield f
    for m in re.finditer(r"(?<![\w.])abort\s*\(", t):
        args, _ = _call_args(t, m.end() - 1)
        first = _first_arg(args)
        rest = args[len(first) + 1:]
        s = _leading_string(rest.strip()) or _kwarg_string(args, "description")
        if s:
            f = _msg(path, t, m.start(), s, _ctx(s))
            if f:
                yield f
    lit = r"(?:[rRfF]{0,2})(?:\"((?:\\.|[^\"\\\n])*)\"|'((?:\\.|[^'\\\n])*)')"
    for rx in (r"jsonify\s*\(\s*error\s*=\s*" + lit, r"[\"']error[\"']\s*:\s*" + lit):
        for m in re.finditer(rx, t):
            s = m.group(1) if m.group(1) is not None else m.group(2)
            f = _msg(path, t, m.start(), s or "", _ctx(s or ""))
            if f:
                yield f
