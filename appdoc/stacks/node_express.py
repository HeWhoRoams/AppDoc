"""Node/Express Stack: routes, SQL and models, connections, env reads, outbound calls, auth middleware, messages.

Reads JS/TS code files only (package.json and .env belong to the generic extractor).
Regex based and comment-aware; no AST, no NestJS decorators. It never records a secret value:
connections and config keys carry ``secret_location`` only, URLs are cut at the query string
and stripped of user info.
"""

from __future__ import annotations

import re
from typing import Iterable

from ..facts import Fact
from ..secrets import find_secret_shapes, is_secret_key
from .base import Stack, line_of, strip_comments

STACK_ID = "node-express"

_CODE_EXT = (".js", ".ts", ".mjs", ".cjs", ".jsx", ".tsx")
_EXPRESS_RE = re.compile(r"\bexpress\b|\bRouter\s*\(")
_DB_MODEL_RE = re.compile(r"sequelize|mongoose", re.I)
_KNEX_RE = re.compile(r"\bknex\b", re.I)
_VERBS = ("get", "post", "put", "delete", "patch", "all", "options", "head", "use")
_AUTH_NAME = re.compile(r"auth|jwt|passport|session|role|permission|guard", re.I)
_SQL_START = re.compile(r"^\s*\(?\s*(select|insert|update|delete|merge|with|exec|execute|call|truncate)\b", re.I)
_TABLE = r"([A-Za-z_#@\[\"`$][\w.\[\]\"`${}#@]*)"
_GENERIC = r"(?:<[^<>()]*(?:<[^<>()]*>[^<>()]*)*>)?"


class NodeExpressStack(Stack):
    id = STACK_ID
    extensions = frozenset({".js", ".ts", ".mjs", ".cjs", ".jsx", ".tsx"})

    def detect(self, files: list[str]) -> list[str]:
        pkgs = sorted(f for f in files if f.rsplit("/", 1)[-1] == "package.json")
        if pkgs and any(f.lower().endswith(_CODE_EXT) for f in files):
            return pkgs
        return []

    def extract(self, path: str, text: str) -> Iterable[Fact]:
        return _extract(path, text)


STACK = NodeExpressStack()


# ---------------------------------------------------------------- lexical helpers

def _parse_string(s: str, i: int):
    """Parse a JS string/template literal at i. Return (value, end) or None."""
    if i >= len(s) or s[i] not in "\"'`":
        return None
    q, k = s[i], i + 1
    while k < len(s) and s[k] != q:
        if s[k] == "\\":
            k += 1
        elif s[k] == "\n" and q != "`":
            return None
        k += 1
    if k >= len(s):
        return None
    return s[i + 1:k], k + 1


def _skip_ws(s, i):
    while i < len(s) and s[i].isspace():
        i += 1
    return i


def _leading_string(s: str):
    """Leading string literal (with + concatenation); also accepts ``x || 'default'``."""
    i = _skip_ws(s, 0)
    while i < len(s) and s[i] == "(":
        i = _skip_ws(s, i + 1)
    parts = []
    r = _parse_string(s, i)
    if r is None:
        m = re.match(r"[\w$.\[\]'\"]+\s*(?:\|\||\?\?)\s*", s[i:])
        if m and not s[i:].startswith(("'", '"', "`")):
            i += m.end()
            r = _parse_string(s, i)
    while r is not None:
        parts.append(r[0])
        i = _skip_ws(s, r[1])
        if i < len(s) and s[i] == "+":
            i = _skip_ws(s, i + 1)
            r = _parse_string(s, i)
        else:
            break
    return "".join(parts) if parts else None


def _call_args(s: str, open_idx: int):
    """s[open_idx] == '('. Return (args_text, index_after_close)."""
    depth, i, n = 0, open_idx, len(s)
    while i < n:
        c = s[i]
        if c in "\"'`":
            r = _parse_string(s, i)
            if r:
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


def _split_args(args: str) -> list[str]:
    out, depth, i, start = [], 0, 0, 0
    while i < len(args):
        c = args[i]
        if c in "\"'`":
            r = _parse_string(args, i)
            if r:
                i = r[1]
                continue
        elif c in "([{":
            depth += 1
        elif c in ")]}":
            depth -= 1
        elif c == "," and depth == 0:
            out.append(args[start:i].strip())
            start = i + 1
        i += 1
    tail = args[start:].strip()
    if tail:
        out.append(tail)
    return out


def _assigned_string(text: str, var: str, pos: int):
    last = None
    rx = rf"(?m)^[ \t]*(?:export\s+)?(?:(?:const|let|var)\s+)?{re.escape(var)}\s*(?::[^=\n]+)?=(?!=)\s*"
    for m in re.finditer(rx, text):
        if m.start() < pos:
            last = m
    return _leading_string(text[last.end():last.end() + 2000]) if last else None


def _resolve_string(text: str, expr: str, pos: int):
    lit = _leading_string(expr) if expr and expr[0] in "\"'`" else None
    if lit is not None:
        return lit
    if re.fullmatch(r"[A-Za-z_$][\w$]*", expr or ""):
        return _assigned_string(text, expr, pos)
    return None


def _safe_url(u: str) -> str:
    u = u.split("?", 1)[0]
    u = re.sub(r"^([a-z][a-z0-9+.-]*://)[^/@\s]*@", r"\1", u, flags=re.I)
    return u[:200]


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
    if op == "select":
        tables = re.findall(r"(?i)\b(?:from|join)\s+" + _TABLE, sql)
    elif op in ("insert", "merge"):
        tables = re.findall(r"(?i)\binto\s+" + _TABLE, sql)[:1]
    elif op == "update":
        tables = re.findall(r"(?i)^\s*\(?\s*update\s+" + _TABLE, sql)[:1]
    elif op == "delete":
        tables = re.findall(r"(?i)\bfrom\s+" + _TABLE, sql)[:1]
    else:
        tables = re.findall(r"(?i)\btable\s+" + _TABLE, sql)[:1]
    names = sorted({_clean_table(t) for t in tables if _clean_table(t)})
    for n in names or ["(unparsed)"]:
        yield Fact.make("data_access", STACK_ID, path, line, n, type="sql", operation=op)


# ---------------------------------------------------------------- main

def _extract(path: str, text: str) -> Iterable[Fact]:
    t = strip_comments(text, "c")
    out: list[Fact] = []
    if _EXPRESS_RE.search(t):
        out.extend(_routes(path, t))
    out.extend(_passport(path, t))
    out.extend(_models(path, t))
    out.extend(_sql(path, t))
    out.extend(_connections(path, t))
    out.extend(_config(path, t))
    out.extend(_external(path, t))
    out.extend(_messages(path, t))
    return list(dict.fromkeys(out))


# --- routes / auth -----------------------------------------------------

def _mechanism(name: str) -> str:
    low = name.lower()
    for key, mech in (("passport", "passport"), ("jwt", "jwt"), ("session", "session"), ("auth", "auth-middleware"),
                      ("role", "role"), ("permission", "role"), ("guard", "guard")):
        if key in low:
            return mech
    return "middleware"


def _auth_fact(path, t, off, text, scope=None):
    text = " ".join(text.split())[:120]
    d = dict(mechanism=_mechanism(text))
    roles = sorted(set(re.findall(r"[\"'`]([\w .:-]+)[\"'`]", text))) if d["mechanism"] == "role" else []
    if roles:
        d["roles"] = roles
    if scope:
        d["scope"] = scope
    return Fact.make("auth_check", STACK_ID, path, line_of(t, off), text, **d)


def _mw_label(arg: str):
    """Printable middleware label for an argument, or None for inline functions."""
    a = arg.strip()
    if re.match(r"(?:async\b|function\b|\(|[\w$]+\s*=>)", a):
        return None
    m = re.match(r"passport\.authenticate\s*\(", a)
    if m:
        inner, _ = _call_args(a, m.end() - 1)
        first = _split_args(inner)
        return f"passport.authenticate({first[0]})" if first else "passport.authenticate()"
    m = re.match(r"([\w$.]+)\s*(\()?", a)
    if not m:
        return None
    if m.group(2):
        inner, _ = _call_args(a, m.end() - 1)
        return f"{m.group(1)}({' '.join(inner.split())})"
    return m.group(1)


def _mw_name(label: str) -> str:
    return label.split("(", 1)[0]


def _routes(path, t):
    apps = set(re.findall(r"(?m)\b(\w+)\s*(?::[^=\n]+)?=\s*express\s*\(\s*\)", t))
    routers = set(re.findall(r"(?m)\b(\w+)\s*(?::[^=\n]+)?=\s*(?:express\.)?Router\s*\(", t))
    known = apps | routers
    mounts: dict[str, tuple[str, str]] = {}
    calls = []  # (offset, receiver, verb, args)
    rx = re.compile(r"(?<![\w$.])([A-Za-z_$][\w$]*)\s*\.\s*(" + "|".join(_VERBS) + r")\s*\(")
    for m in rx.finditer(t):
        recv = m.group(1)
        if recv not in known and not re.fullmatch(r"(?i)app|server|router|\w*routes?|\w*router|api", recv):
            continue
        args, _ = _call_args(t, m.end() - 1)
        calls.append((m.start(), recv, m.group(2), _split_args(args)))
    # router.route('/x').get(...).post(...)
    for m in re.finditer(r"(?<![\w$.])([A-Za-z_$][\w$]*)\s*\.\s*route\s*\(", t):
        recv = m.group(1)
        if recv not in known and not re.fullmatch(r"(?i)app|router|\w*router|api", recv):
            continue
        pargs, i = _call_args(t, m.end() - 1)
        pl = _leading_string(pargs)
        if pl is None:
            continue
        while True:
            cm = re.compile(r"\s*\.\s*(" + "|".join(v for v in _VERBS if v != "use") + r")\s*\(").match(t, i)
            if not cm:
                break
            a, i = _call_args(t, cm.end() - 1)
            calls.append((cm.start(1), recv, cm.group(1), [repr_lit(pl)] + _split_args(a)))
    for off, recv, verb, args in calls:
        if verb == "use":
            if args and args[-1] and re.fullmatch(r"[\w$]+", args[-1]):
                pre = _leading_string(args[0]) if len(args) > 1 else ""
                mounts[args[-1]] = (recv, pre or "")

    def prefix_of(var, depth=0):
        """(prefix, resolved) for a router/app variable."""
        if var in apps or (var not in routers and var in ("app", "server")):
            return "", True
        if var in mounts and depth < 6:
            parent, pre = mounts[var]
            pp, ok = prefix_of(parent, depth + 1)
            return pp + pre, ok
        return "", False

    for off, recv, verb, args in sorted(calls, key=lambda c: c[0]):
        if not args:
            continue
        first = args[0]
        path_lit = _leading_string(first) if first[:1] in "\"'`" else None
        if verb == "use":
            if path_lit is None:
                # global middleware: app.use(requireAuth)
                for a in args:
                    lab = _mw_label(a)
                    if lab and _AUTH_NAME.search(_mw_name(lab)):
                        yield _auth_fact(path, t, off, lab, scope="all")
                continue
            if len(args) > 1 and re.fullmatch(r"[\w$]+", args[-1]) and args[-1] in routers:
                continue  # local router mount: recorded as prefix of its routes
            rest = args[1:]
        else:
            if path_lit is None or not (path_lit.startswith(("/", "*")) or path_lit == ""):
                continue
            rest = args[1:]
        if not rest:
            continue
        handler_arg = rest[-1]
        hm = re.match(r"(?:async\s+)?function\s*\*?\s*([\w$]+)", handler_arg)
        if hm:
            handler = hm.group(1)
        elif re.fullmatch(r"[\w$.]+", handler_arg):
            handler = handler_arg
        else:
            handler = "inline"
        mws = []
        for a in rest[:-1]:
            parts = _split_args(a[1:-1]) if a.startswith("[") and a.endswith("]") else [a]
            mws.extend(parts)
        labels = [x for x in (_mw_label(a) for a in mws) if x]
        names = sorted({_mw_name(x) for x in labels})
        pre, ok = prefix_of(recv)
        full = (pre.rstrip("/") + "/" + path_lit.lstrip("/")) if pre else path_lit
        d = dict(type="route", method=("USE" if verb == "use" else verb.upper()), handler=handler, middleware=names)
        if not ok:
            d["prefix_unresolved"] = True
        yield Fact.make("entry_point", STACK_ID, path, line_of(t, off), full, **d)
        for lab in labels:
            if _AUTH_NAME.search(_mw_name(lab)):
                yield _auth_fact(path, t, off, lab)


def repr_lit(s: str) -> str:
    return "'" + s.replace("\\", "\\\\").replace("'", "\\'") + "'"


def _passport(path, t):
    for m in re.finditer(r"(?<![\w$.])passport\.authenticate\s*\(", t):
        inner, _ = _call_args(t, m.end() - 1)
        first = _split_args(inner)
        yield _auth_fact(path, t, m.start(), f"passport.authenticate({first[0]})" if first else "passport.authenticate()")
    for m in re.finditer(r"(?<![\w$.])(?:requireRole|requireRoles|requirePermission|hasRole|checkRole|authorize|authorizeRoles)\s*\(", t):
        inner, end = _call_args(t, m.end() - 1)
        name = m.group(0).rstrip("( ").strip()
        # skip definitions (function requireRole(...)) and route middleware already captured
        before = t[max(0, m.start() - 20):m.start()]
        if re.search(r"(function|const|let|var)\s+$", before) or re.search(r"[(,\[]\s*$", before):
            continue
        yield _auth_fact(path, t, m.start(), f"{name}({' '.join(inner.split())})")


# --- data access -------------------------------------------------------

def _models(path, t):
    if _DB_MODEL_RE.search(t):
        for m in re.finditer(r"\.define\s*\(\s*[\"'`](\w+)[\"'`]", t):
            yield Fact.make("data_access", STACK_ID, path, line_of(t, m.start()), m.group(1),
                            type="entity", operation="model", orm="sequelize")
        for m in re.finditer(r"\bclass\s+(\w+)\s+extends\s+(?:Sequelize\.)?Model\b", t):
            yield Fact.make("data_access", STACK_ID, path, line_of(t, m.start()), m.group(1),
                            type="entity", operation="model", orm="sequelize")
        for m in re.finditer(r"\bmodel\s*" + _GENERIC + r"\s*\(\s*[\"'`](\w+)[\"'`]", t):
            yield Fact.make("data_access", STACK_ID, path, line_of(t, m.start()), m.group(1),
                            type="entity", operation="model", orm="mongoose")
        for m in re.finditer(r"(?m)\b(?:const|let|var)\s+(\w+)\s*(?::[^=\n]+)?=\s*new\s+(?:mongoose\.)?Schema\b", t):
            yield Fact.make("data_access", STACK_ID, path, line_of(t, m.start()), m.group(1),
                            type="entity", operation="schema", orm="mongoose")
    if _KNEX_RE.search(t):
        for m in re.finditer(r"(?:(?<![\w$])(?:knex|db|trx)|\.(?:from|table|into))\s*\(\s*[\"'`]([\w.]+)[\"'`]\s*[,)]", t):
            if t[max(0, m.start() - 6):m.start()].endswith(("Array", "Buffer")):
                continue
            ahead = t[m.end():m.end() + 300].split(";")[0]
            behind = t[max(0, m.start() - 200):m.start()].split(";")[-1]
            op = "select"
            if m.group(0).lstrip().startswith(".into") or re.search(r"\.insert\s*\(", behind):
                op = "insert"
            else:
                om = re.search(r"\.(insert|update|del|delete|select|first|count|truncate)\b", ahead)
                if om:
                    op = {"del": "delete", "first": "select", "count": "select"}.get(om.group(1), om.group(1))
            yield Fact.make("data_access", STACK_ID, path, line_of(t, m.start()), m.group(1),
                            type="sql", operation=op, builder="knex")


def _sql(path, t):
    for m in re.finditer(r"\.\s*(query|execute|raw)\s*" + _GENERIC + r"\s*\(", t):
        args, _ = _call_args(t, m.end() - 1)
        first = (_split_args(args) or [""])[0]
        sql = _leading_string(first) if first[:1] in "\"'`(" else _resolve_string(t, first, m.start())
        if sql:
            yield from _sql_facts(path, line_of(t, m.start()), sql)


# --- connections / config ---------------------------------------------

_CONNECT = re.compile(
    r"(?<![\w$.])(new\s+(?:pg\.|mysql\.)?Pool|(?:require\(\s*[\"']knex[\"']\s*\)(?=\s*\())|new\s+Sequelize|new\s+MongoClient|new\s+Client|"
    r"(?:\w+\.)?createPool|(?:\w+\.)?createConnection|mongoose\.connect|knex(?=\s*\(\s*\{))\s*" + _GENERIC + r"\s*\(")


def _connections(path, t):
    for m in _CONNECT.finditer(t):
        name = " ".join(m.group(1).split())
        if name.startswith("require("):
            name = "knex"
        if name == "new Client" and not re.search(r"\bpg\b|from\s+['\"]pg['\"]", t):
            continue
        args, _ = _call_args(t, m.end() - 1)
        first = (_split_args(args) or [""])[0]
        probe = args + " " + (_resolve_string(t, first, m.start()) or "")
        secret = bool(is_secret_key(probe) or re.search(r"(?i)\b(user|username|uri|url|dsn)\b", probe)
                      or find_secret_shapes(probe) or re.search(r"://[^/\s\"']+:[^/\s\"']*@", probe))
        yield Fact.make("connection", STACK_ID, path, line_of(t, m.start()), name,
                        type="database", secret_location=secret)


def _config(path, t):
    for m in re.finditer(r"\bprocess\.env\.([A-Za-z_]\w*)", t):
        yield _cfg(path, t, m.start(1), m.group(1))
    for m in re.finditer(r"\bprocess\.env\[\s*[\"'`]([\w]+)[\"'`]\s*\]", t):
        yield _cfg(path, t, m.start(), m.group(1))
    for m in re.finditer(r"\{([^{}]*)\}\s*=\s*process\.env\b", t):
        off = m.start(1)
        for part in m.group(1).split(","):
            km = re.match(r"\s*([A-Za-z_]\w*)", part)
            if km:
                yield _cfg(path, t, off + km.start(1), km.group(1))
            off += len(part) + 1


def _cfg(path, t, off, key):
    return Fact.make("config_key", STACK_ID, path, line_of(t, off), key, source="code", secret_location=is_secret_key(key))


# --- external calls ----------------------------------------------------

_FS_METHODS = ("readFile|readFileSync|writeFile|writeFileSync|appendFile|appendFileSync|unlink|unlinkSync|"
               "createReadStream|createWriteStream|readdir|readdirSync|mkdir|mkdirSync|rm|rmSync|rename|renameSync|"
               "copyFile|copyFileSync|rmdir|rmdirSync|stat|statSync|access|accessSync|existsSync|open|openSync")


def _url_fact(path, t, m, call):
    args, _ = _call_args(t, m.end() - 1)
    parts = _split_args(args)
    url = None
    for a in parts[:2]:
        url = _resolve_string(t, a, m.start())
        if url:
            break
    name = _safe_url(url) if url else call
    return Fact.make("external_call", STACK_ID, path, line_of(t, m.start()), name, type="http", call=call)


def _external(path, t):
    for m in re.finditer(r"(?<![\w$.])fetch\s*" + _GENERIC + r"\s*\(", t):
        yield _url_fact(path, t, m, "fetch")
    for m in re.finditer(r"(?<![\w$.])axios(?:\.(get|post|put|delete|patch|head|request))?\s*" + _GENERIC + r"\s*\(", t):
        yield _url_fact(path, t, m, "axios" + ("." + m.group(1) if m.group(1) else ""))
    for m in re.finditer(r"(?<![\w$.])got(?:\.(get|post|put|delete|patch|head))?\s*\(", t):
        if re.search(r"\bgot\b", t) and re.search(r"['\"]got['\"]", t):
            yield _url_fact(path, t, m, "got" + ("." + m.group(1) if m.group(1) else ""))
    if re.search(r"['\"]request['\"]", t):
        for m in re.finditer(r"(?<![\w$.])request(?:\.(get|post|put|delete|patch))?\s*\(", t):
            yield _url_fact(path, t, m, "request" + ("." + m.group(1) if m.group(1) else ""))
    for m in re.finditer(r"(?<![\w$.])https?\.(get|request)\s*\(", t):
        yield _url_fact(path, t, m, m.group(0).rstrip("( ").strip())
    if re.search(r"nodemailer", t):
        for m in re.finditer(r"\bnodemailer\.createTransport\s*\(", t):
            args, _ = _call_args(t, m.end() - 1)
            hm = re.search(r"\b(?:host|service)\s*:\s*[\"'`]([^\"'`]+)[\"'`]", args)
            yield Fact.make("external_call", STACK_ID, path, line_of(t, m.start()),
                            hm.group(1)[:200] if hm else "nodemailer.createTransport", type="email", call="nodemailer.createTransport")
        for m in re.finditer(r"\.sendMail\s*\(", t):
            yield Fact.make("external_call", STACK_ID, path, line_of(t, m.start()), "sendMail", type="email", call="sendMail")
    if re.search(r"child_process", t):
        for m in re.finditer(r"(?<![\w$])((?:\w+\.)?(?:execSync|exec|execFileSync|execFile|spawnSync|spawn|fork))\s*\(", t):
            args, _ = _call_args(t, m.end() - 1)
            first = (_split_args(args) or [""])[0]
            lit = _leading_string(first) if first[:1] in "\"'`" else None
            exe = lit.split()[0] if lit and lit.split() else m.group(1)
            yield Fact.make("external_call", STACK_ID, path, line_of(t, m.start()), exe[:120], type="process", call=m.group(1))
    for m in re.finditer(r"(?<![\w$.])(?:fs|fsp|fsPromises)\.(?:promises\.)?(" + _FS_METHODS + r")\s*\(", t):
        args, _ = _call_args(t, m.end() - 1)
        first = (_split_args(args) or [""])[0]
        p = _resolve_string(t, first, m.start())
        yield Fact.make("external_call", STACK_ID, path, line_of(t, m.start()), p[:200] if p else f"fs.{m.group(1)}",
                        type="file", call=f"fs.{m.group(1)}")


# --- messages ----------------------------------------------------------

def _ctx(text: str, status: int | None = None) -> str:
    if status in (400, 422) or re.search(r"(?i)\b(required|invalid|must|missing|cannot be|too (?:long|short)|not valid)\b", text):
        return "validation"
    return "error"


def _msg(path, t, off, text, context):
    text = " ".join(text.split())[:200]
    if not text or find_secret_shapes(text):
        return None
    return Fact.make("message", STACK_ID, path, line_of(t, off), text, context=context)


def _messages(path, t):
    for m in re.finditer(r"\.\s*status\s*\(\s*([45]\d\d)\s*\)\s*\.\s*(send|json)\s*\(", t):
        status = int(m.group(1))
        args, _ = _call_args(t, m.end() - 1)
        first = (_split_args(args) or [""])[0]
        s = _leading_string(first) if first[:1] in "\"'`" else None
        if s is None:
            km = re.search(r"\b(?:error|message|msg)\s*:\s*(?=[\"'`])", first)
            if km:
                s = _leading_string(first[km.end():])
        if s:
            f = _msg(path, t, m.start(), s, _ctx(s, status))
            if f:
                yield f
    for m in re.finditer(r"\bthrow\s+new\s+\w*Error\s*\(", t):
        args, _ = _call_args(t, m.end() - 1)
        first = (_split_args(args) or [""])[0]
        s = _leading_string(first) if first[:1] in "\"'`" else None
        if s:
            f = _msg(path, t, m.start(), s, _ctx(s))
            if f:
                yield f
