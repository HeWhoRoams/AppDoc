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
from . import integrations

STACK_ID = "python-flask"

_MANIFEST_RE = re.compile(r"^(requirements[^/]*\.txt|pyproject\.toml|setup\.py)$", re.I)
_FLASK_IMPORT = re.compile(r"(?m)^\s*(?:from\s+flask\b|import\s+flask\b)")
_VERBS = ("get", "post", "put", "delete", "patch")
_CLEAN_RE = re.compile(r'("""|\'\')(?:.*?)\1|"(?:\\.|[^"\\\n])*"|\'(?:\\.|[^\'\\\n])*\'|#[^\n]*', re.S)
_DEFCLASS_RE = re.compile(r"\b(def|class)\s+(\w+)")
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
    rx = _CLEAN_RE

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
    out.extend(_jobs(path, t))
    out.extend(_external(path, t))
    out.extend(_messages(path, t))
    out.extend(integrations.scan_facts("python", STACK_ID, path, t))
    return list(dict.fromkeys(out))


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
        hm = _DEFCLASS_RE.search(t, end)
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


def _split_pos(args: str):
    """Top-level comma split of an argument list: [(offset, text)] with string-aware nesting."""
    out, depth, i, start = [], 0, 0, 0
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
            out.append((start, args[start:i]))
            start = i + 1
        i += 1
    if args[start:].strip():
        out.append((start, args[start:]))
    return out


def _cfg(path, t, off, key, use, via):
    return Fact.make("config_key", STACK_ID, path, line_of(t, off), key, source="code",
                     secret_location=is_secret_key(key), use=use, via=via,
                     **({"read_kind": "env" if via == "environ" else "file"} if use == "read" else {}))


_UPPER_DEF = re.compile(r"(?m)^([A-Z][A-Z0-9_]*)[ \t]*(?::[^=\n]+)?=(?!=)")
_CFG_ASSIGN = re.compile(r"\s*\]\s*(?:\|=|\+=|=(?!=))")
_CFG_FROM_OBJECT = re.compile(r"(?<![\w])(?:[A-Za-z_][\w.]*)\.config\.from_object\s*\(")


def _class_attr_defs(t, name, seen=None):
    """(offset, NAME) of UPPER_CASE class attributes of ``name`` and of base classes defined in the same file."""
    seen = seen if seen is not None else set()
    if name in seen or len(seen) > 4:
        return
    seen.add(name)
    m = re.search(rf"(?m)^class\s+{re.escape(name)}\b\s*(?:\(([^)]*)\))?\s*:", t)
    if not m:
        return
    nxt = re.search(r"(?m)^\S", t[m.end():])
    end = m.end() + nxt.start() if nxt else len(t)
    body = t[m.end():end]
    first = re.search(r"(?m)^([ \t]+)\S", body)
    if first:
        rx = re.compile(rf"(?m)^{re.escape(first.group(1))}([A-Z][A-Z0-9_]*)[ \t]*(?::[^=\n]+)?=(?!=)")
        for a in rx.finditer(body):
            yield m.end() + a.start(1), a.group(1)
    for base in re.findall(r"[\w.]+", m.group(1) or ""):
        yield from _class_attr_defs(t, base.rsplit(".", 1)[-1], seen)


def _from_object_defs(path, t, arg):
    arg = arg.strip()
    this_mod = re.sub(r"(?:/__init__)?\.py$", "", path).replace("/", ".")

    def module_level():
        for a in _UPPER_DEF.finditer(t):
            yield a.start(1), a.group(1)

    lit = _leading_string(arg) if arg[:1] in "\"'" else None
    if arg == "__name__":
        yield from module_level()
    elif lit is not None:
        if this_mod == lit or this_mod.endswith("." + lit):
            yield from module_level()
        else:
            yield from _class_attr_defs(t, lit.rsplit(".", 1)[-1])
    elif re.fullmatch(r"[A-Za-z_][\w.]*", arg):
        yield from _class_attr_defs(t, arg.rsplit(".", 1)[-1])


def _config(path, t):
    # Definitions: values loaded with config.from_object() and writes through app.config.
    for m in _CFG_FROM_OBJECT.finditer(t):
        args, _ = _call_args(t, m.end() - 1)
        for off, key in _from_object_defs(path, t, _first_arg(args)):
            yield _cfg(path, t, off, key, "define", "from_object")
    for m in re.finditer(r"\b(?:current_app|app)\.config\s*\.\s*(update|from_mapping|setdefault)\s*\(", t):
        args, _ = _call_args(t, m.end() - 1)
        base = m.end()
        for off, part in _split_pos(args):
            km = re.match(r"\s*([A-Za-z_]\w*)\s*=(?!=)", part)
            if km:
                yield _cfg(path, t, base + off + km.start(1), km.group(1), "define", m.group(1))
                continue
            stripped = part.lstrip()
            lead = base + off + len(part) - len(stripped)
            if m.group(1) == "setdefault":
                key = _leading_string(stripped)
                if key and re.fullmatch(r"\w[\w.\-]*", key) and off == 0:
                    yield _cfg(path, t, lead, key, "define", "setdefault")
            elif stripped.startswith("{"):
                close = stripped.rfind("}")
                for o2, p2 in _split_pos(stripped[1:close if close > 0 else len(stripped)]):
                    dm = re.match(r"\s*[\"'](\w[\w.\-]*)[\"']\s*:", p2)
                    if dm:
                        yield _cfg(path, t, lead + 1 + o2 + dm.start(1), dm.group(1), "define", m.group(1))
            elif stripped.startswith("dict("):
                inner, _end = _call_args(stripped, 4)
                for o2, p2 in _split_pos(inner):
                    dm = re.match(r"\s*([A-Za-z_]\w*)\s*=(?!=)", p2)
                    if dm:
                        yield _cfg(path, t, lead + 5 + o2 + dm.start(1), dm.group(1), "define", m.group(1))
    # app.config["X"] / .get("X"): a definition when assigned to, otherwise a read.
    for m in re.finditer(r"\b(?:current_app|app)\.config(?:\s*\[\s*|\.get\(\s*)[\"'](\w[\w.\-]*)[\"']", t):
        is_def = "[" in m.group(0) and _CFG_ASSIGN.match(t, m.end())
        yield _cfg(path, t, m.start(), m.group(1), "define" if is_def else "read", "assign" if is_def else "config")
    for m in re.finditer(r"\b(?:os\.)?environ\s*\[\s*[\"'](\w+)[\"']", t):
        is_def = _CFG_ASSIGN.match(t, m.end())
        yield _cfg(path, t, m.start(), m.group(1), "define" if is_def else "read", "environ")
    for p in (r"\b(?:os\.)?environ\.get\(\s*[\"'](\w+)[\"']",
              r"\bos\.getenv\(\s*[\"'](\w+)[\"']",
              r"(?<![\w.])getenv\(\s*[\"'](\w+)[\"']"):
        for m in re.finditer(p, t):
            yield _cfg(path, t, m.start(), m.group(1), "read", "environ")


# --- scheduled jobs ----------------------------------------------------

_APS_SKIP = {"id", "name", "args", "kwargs", "replace_existing", "misfire_grace_time", "coalesce", "max_instances",
             "next_run_time", "jobstore", "executor", "func", "trigger"}


def _kwargs_and_pos(args: str):
    kw, pos = {}, []
    for _, part in _split_pos(args):
        part = part.strip()
        km = re.match(r"([A-Za-z_]\w*)\s*=(?!=)\s*(.*)$", part, re.S)
        if km:
            kw[km.group(1)] = " ".join(km.group(2).split())
        elif part:
            pos.append(" ".join(part.split()))
    return kw, pos


def _job_fact(path, t, off, name, handler, schedule, scheduler):
    return Fact.make("entry_point", STACK_ID, path, line_of(t, off), name, type="job", handler=handler,
                     schedule=schedule, enabled=None, scheduler=scheduler)


def _aps_job(path, t, off, kw, pos, func, trig_idx, scheduler="apscheduler"):
    trig = kw.get("trigger") or (pos[trig_idx] if len(pos) > trig_idx else None)
    if not trig:
        return None
    lit = _leading_string(trig)
    if lit is not None and lit.lower() in ("cron", "interval"):
        rest = ", ".join(f"{k}={v}" for k, v in kw.items() if k not in _APS_SKIP)
        schedule = (lit.lower() + (" " + rest if rest else ""))[:120]
    elif re.match(r"(?:\w+\.)*(?:CronTrigger|IntervalTrigger)\b", trig):
        schedule = trig[:120]
    else:
        return None
    jid = _leading_string(kw["id"]) if "id" in kw else None
    handler = func.split("(")[0].strip()[:80]
    return _job_fact(path, t, off, jid or handler or "job", handler, schedule, scheduler)


def _matching_brace(t, i):
    depth = 0
    while i < len(t):
        c = t[i]
        if c in "\"'":
            r = _parse_string(t, i)
            if r and r[1]:
                i = r[1]
                continue
        elif c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
            if depth == 0:
                return i
        i += 1
    return len(t)


def _jobs(path, t):
    has_aps = bool(re.search(r"(?i)apscheduler", t))
    for m in re.finditer(r"(?<![\w])([\w.]+)\s*\.\s*add_job\s*\(", t):
        if not (has_aps or re.search(r"(?i)sched", m.group(1))):
            continue
        args, _ = _call_args(t, m.end() - 1)
        kw, pos = _kwargs_and_pos(args)
        func = kw.get("func") or (pos[0] if pos else "")
        f = _aps_job(path, t, m.start(), kw, pos, func, 1)
        if f:
            yield f
    for m in re.finditer(r"(?m)^[ \t]*@([\w.]*sched\w*)\s*\.\s*(?:scheduled_job|task)\s*\(", t, re.I):
        args, end = _call_args(t, m.end() - 1)
        kw, pos = _kwargs_and_pos(args)
        kw.setdefault("trigger", pos[0] if pos else "")
        hm = re.compile(r"\bdef\s+(\w+)").search(t, end)
        f = _aps_job(path, t, m.start(), kw, [], hm.group(1) if hm else "", 0)
        if f:
            yield f
    for m in re.finditer(r"\b(?:beat_schedule|CELERYBEAT_SCHEDULE)\b[\"']?\s*(?:=|:)\s*\{", t):
        open_i = m.end() - 1
        body = t[open_i + 1:_matching_brace(t, open_i)]
        for off, ent in _split_pos(body):
            km = re.match(r"\s*[\"']([^\"'\n]+)[\"']\s*:\s*(.*)$", ent, re.S)
            if not km:
                continue
            val = km.group(2).strip()
            fields = {}
            if val.startswith("{"):
                for _, p2 in _split_pos(val[1:val.rfind("}")]):
                    fm = re.match(r"\s*[\"'](\w+)[\"']\s*:\s*(.*)$", p2, re.S)
                    if fm:
                        fields[fm.group(1)] = " ".join(fm.group(2).split())
            task = _leading_string(fields.get("task", "")) or fields.get("task", "")
            key_off = open_i + 1 + off + len(ent) - len(ent.lstrip())
            yield _job_fact(path, t, key_off, km.group(1), task, fields.get("schedule", "")[:120] or None, "celery")
    for m in re.finditer(r"\.\s*add_periodic_task\s*\(", t):
        args, _ = _call_args(t, m.end() - 1)
        kw, pos = _kwargs_and_pos(args)
        sig = kw.get("sig") or (pos[1] if len(pos) > 1 else "")
        name = _leading_string(kw["name"]) if "name" in kw else None
        yield _job_fact(path, t, m.start(), name or sig.split("(")[0] or "periodic task", sig.split("(")[0][:80],
                        (pos[0] if pos else kw.get("run_every", ""))[:120] or None, "celery")


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


capabilities = frozenset(
    "auth_check config_key connection data_access entry_point external_call message smell".split())
