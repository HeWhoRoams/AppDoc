"""Go Stack: routes (stdlib, chi, gin, echo, gorilla, gitea/macaron style with nested groups), CLI commands,
scheduled jobs, config reads, literal SQL, outbound HTTP calls, auth middleware.

Regex based and comment-aware (comments are blanked and newlines kept, so line numbers stay correct).
No AST: a route group is a ``.Group("/p", func() { ... })`` call and its prefix applies to every route registered
inside the closure, whatever the receiver is called. It never records a secret value: config keys carry
``secret_location`` only, URLs are cut at the query string and stripped of user info.
"""

from __future__ import annotations

import re
from bisect import bisect_left, bisect_right
from typing import Iterable

from ..facts import Fact
from ..secrets import find_secret_shapes, is_secret_key
from .base import Stack

STACK_ID = "go"


class GoStack(Stack):
    id = STACK_ID
    capabilities = frozenset((
        "auth_check config_key connection data_access entry_point.route "
        "entry_point.command entry_point.job external_call schema_object "
        "ui_page"
    ).split())
    extensions = frozenset({".go", ".html"})

    def detect(self, files: list[str]) -> list[str]:
        def vendored(f):
            return "vendor" in f.split("/")[:-1]

        mods = sorted(f for f in files if f.rsplit("/", 1)[-1] == "go.mod" and not vendored(f))
        if mods and any(f.lower().endswith(".go") and not vendored(f) for f in files):
            return mods
        return []

    def extract(self, path: str, text: str) -> Iterable[Fact]:
        parts = path.split("/")[:-1]
        if "vendor" in parts:
            return ()
        if path.lower().endswith(".html"):
            return _templates(path, parts)
        return _extract(path, text)


STACK = GoStack()


# ---------------------------------------------------------------- lexical helpers

# String, raw string and rune literals are matched first so "//" inside them is not a comment.
# (A local regex instead of base.strip_comments: that one is a per-character loop, too slow for ~3000 files.)
_COMMENT = re.compile(r"(\"(?:\\.|[^\"\\\n])*\"|`[^`]*`|'(?:\\.|[^'\\\n])*')|//[^\n]*|/\*.*?\*/", re.S)
_NOT_NL = re.compile(r"[^\n]")
# Brackets, commas and literals: lets us walk an argument list without a character loop.
_TOK = re.compile(r"\"(?:\\.|[^\"\\\n])*\"|`[^`]*`|'(?:\\.|[^'\\\n])*'|[()\[\]{},]")
_NL = re.compile(r"\n")
_FUNC_LIT = re.compile(r"func\s*\(")


def _blank(m):
    if m.group(1) is not None:
        return m.group(0)
    g = m.group(0)
    return " " * len(g) if "\n" not in g else _NOT_NL.sub(" ", g)


def _strip(text: str) -> str:
    return _COMMENT.sub(_blank, text)


class _Src:
    """Comment-stripped text with an offset -> line lookup."""

    def __init__(self, text: str):
        self.t = _strip(text)
        self._nl = None

    def line(self, off: int) -> int:
        if self._nl is None:
            self._nl = [m.start() for m in _NL.finditer(self.t)]
        return bisect_left(self._nl, off) + 1


def _push(spans, t, s, e):
    while s < e and t[s].isspace():
        s += 1
    while e > s and t[e - 1].isspace():
        e -= 1
    if s < e:
        spans.append((s, e))


def _scan(t: str, i: int):
    """t[i] opens a bracket. Return ([(start, end) of each top-level comma-separated item], index of the closer)."""
    depth, start, spans = 0, i + 1, []
    for m in _TOK.finditer(t, i):
        c = m.group(0)
        if len(c) > 1:
            continue
        if c in "([{":
            depth += 1
        elif c in ")]}":
            depth -= 1
            if depth == 0:
                _push(spans, t, start, m.start())
                return spans, m.start()
        elif c == "," and depth == 1:
            _push(spans, t, start, m.start())
            start = m.end()
    _push(spans, t, start, len(t))
    return spans, len(t)


def _items(s: str) -> list[str]:
    """Top-level items of a call text such as ``append(mid, a, b)``."""
    i = s.find("(")
    if i < 0:
        return []
    spans, _ = _scan(s, i)
    return [s[a:b] for a, b in spans]


def _str_at(s: str, i: int):
    """Go string literal at s[i]: (value, end) or None."""
    if i >= len(s):
        return None
    if s[i] == "`":
        j = s.find("`", i + 1)
        return (s[i + 1:j], j + 1) if j >= 0 else None
    if s[i] != '"':
        return None
    j = i + 1
    while j < len(s):
        c = s[j]
        if c == "\\":
            j += 2
            continue
        if c == '"':
            return re.sub(r"\\(.)", lambda m: {"n": "\n", "t": "\t"}.get(m.group(1), m.group(1)), s[i + 1:j]), j + 1
        if c == "\n":
            return None
        j += 1
    return None


def _skip_ws(s, i):
    while i < len(s) and s[i].isspace():
        i += 1
    return i


def _const_str(s: str):
    """Value of a literal or a ``"a" + "b"`` concatenation of literals; None when any term is not a literal."""
    i, parts = _skip_ws(s, 0), []
    while True:
        r = _str_at(s, i)
        if r is None:
            return None
        parts.append(r[0])
        i = _skip_ws(s, r[1])
        if i >= len(s):
            return "".join(parts)
        if s[i] != "+":
            return None
        i = _skip_ws(s, i + 1)


def _lead_str(s: str):
    """Leading literal terms of ``"https://x/" + id``; None when the expression does not start with a literal."""
    i, parts = _skip_ws(s, 0), []
    while True:
        r = _str_at(s, i)
        if r is None:
            break
        parts.append(r[0])
        i = _skip_ws(s, r[1])
        if i < len(s) and s[i] == "+":
            i = _skip_ws(s, i + 1)
            continue
        break
    return "".join(parts) if parts else None


_LABEL = re.compile(r"&?([A-Za-z_]\w*(?:\.[A-Za-z_]\w*)*)(?:\[[^\]]*\])?\s*(\(|$)")


def _label(arg: str):
    """Printable identifier of a handler/middleware argument, or None for an inline function literal."""
    a = arg.strip()
    if _FUNC_LIT.match(a):
        return None
    m = _LABEL.match(a)
    if not m:
        return None
    name = m.group(1)
    if name == "http.HandlerFunc" and m.group(2):
        inner = _items(a)
        return _label(inner[0]) if inner else name
    return name


def _flatten(args: list[str]) -> list[str]:
    """Expand ``append(mid, a, b)...`` into its handler arguments."""
    out = []
    for a in args:
        a = a.strip()
        if a.endswith("..."):
            a = a[:-3].strip()
        if re.match(r"append\s*\(", a):
            out.extend(_items(a)[1:])
        else:
            out.append(a)
    return out


def _safe_url(u: str) -> str:
    u = u.split("?", 1)[0]
    u = re.sub(r"^([a-z][a-z0-9+.-]*://)[^/@\s]*@", r"\1", u, flags=re.I)
    return u[:200]


# ---------------------------------------------------------------- routes

_RECV = re.compile(r"(?i)(?:m|r|e|g|rg|api|app|srv|server|engine|group|\w*(?:router|routes?|group|mux|api|rg|engine))")
_CTOR = re.compile(r"\b(\w+)\s*:?=\s*&?(?:http\.NewServeMux|chi\.NewRouter|chi\.NewMux|mux\.NewRouter|gin\.(?:Default|New)"
                   r"|echo\.New|web\.NewRouter|fiber\.New|httprouter\.New|macaron\.(?:New|Classic))\s*\(")
_VERBS = ("Get|Post|Put|Patch|Delete|Head|Options|Any|Connect|Trace|GET|POST|PUT|PATCH|DELETE|HEAD|OPTIONS|ANY|"
          "Handle|HandleFunc|Methods|Combo|Group|Route|Use")
_CALL = re.compile(r"(?<![\w.])([A-Za-z_]\w*)\s*\.\s*(" + _VERBS + r")\s*\(")
_CHAIN = re.compile(r"\s*\.\s*(Get|Post|Put|Patch|Delete|Head|Options|Any)\s*\(")
_METHODS_CHAIN = re.compile(r"\s*\.\s*Methods\s*\(")
_VAR_BEFORE = re.compile(r"(\w+)\s*:?=\s*$")
_STD_PATTERN = re.compile(r"^([A-Z]+)\s+(/.*)$", re.S)
_HELPER_CLOSURE = re.compile(r"\b(\w+)\s*:?=\s*func\s*\(")
_FUNC_DECL = re.compile(r"(?m)^func\s+(\w+)\s*(?:\[[^\]]*\])?\s*\(")
_ROUTER_PARAM = re.compile(r"\*?\b(?:web|chi|mux|gin|echo|fiber|macaron)\.(?:Router|Mux|RouterGroup|Group|Engine|Echo|Macaron|App)\b")
_AUTH = re.compile(r"(?i:\w*jwt\w*)|(?:req(?:SignIn|SignOut|Token|\w*Admin|Repo\w+|Org\w+|Team\w+|Self\w+|Unit\w+|Package\w+"
                   r"|Basic\w+)|[Rr]equireAuth\w*|\w*[Aa]uth\w*Middleware|basicAuth\w*)")

_ROOT = ("", (), False)  # (prefix, inherited middleware, prefix_unresolved)


def _auth_mechanism(label: str) -> str:
    low = label.lower()
    return "jwt" if "jwt" in low else "basic" if "basic" in low else "middleware"


def _is_auth(label: str) -> bool:
    return bool(_AUTH.fullmatch(label.rsplit(".", 1)[-1]))


def _join(prefix: str, path: str) -> str:
    if not prefix:
        return path or "/"
    if not path:
        return prefix
    return prefix.rstrip("/") + "/" + path.lstrip("/")


def _labels(args: list[str]) -> list[str]:
    return [x for x in (_label(a) for a in _flatten(args)) if x]


def _norm_methods(s: str) -> str:
    return ",".join(x.strip().upper() for x in s.split(",") if x.strip())


def _route_events(src: _Src):
    """(offset, kind, payload) for every route registration and group, plus direct Use() middleware."""
    t = src.t
    known = set(_CTOR.findall(t))
    events, uses = [], []
    for m in _CALL.finditer(t):
        recv, verb = m.group(1), m.group(2)
        vl = verb.lower()
        if not (recv in known or _RECV.fullmatch(recv) or (recv == "http" and vl in ("handle", "handlefunc"))):
            continue
        spans, pclose = _scan(t, m.end() - 1)
        args = [t[a:b] for a, b in spans]
        voff = m.start(2)
        if vl == "use":
            uses.append((voff, _labels(args)))
        elif vl in ("group", "route"):
            cl = next((i for i, a in enumerate(args) if _FUNC_LIT.match(a)), None)
            if cl is None and vl == "route":
                # macaron: Route(path, "GET,POST", handlers...)
                if len(args) >= 3 and _const_str(args[0]) is not None and _const_str(args[1]) is not None:
                    events.append((voff, "route", dict(recv=recv, method=_norm_methods(_const_str(args[1])),
                                                       path=_const_str(args[0]), hargs=args[2:])))
                continue
            if not args:
                continue
            var = None
            if cl is None:
                vm = _VAR_BEFORE.search(t[max(0, m.start() - 80):m.start()])
                if not vm:
                    continue
                var = vm.group(1)
            events.append((m.start(), "group", dict(
                recv=recv, own=_const_str(args[0]), closure=spans[cl] if cl is not None else None, var=var,
                mws=_labels(args[cl + 1:] if cl is not None else args[1:]), voff=voff)))
        elif vl == "methods":
            # gitea/chi: Methods("GET, HEAD", "/p", handlers...); a lone Methods("GET") is gorilla's chain, handled below
            ms, pth = (_const_str(args[0]), _const_str(args[1])) if len(args) >= 2 else (None, None)
            if ms is not None and pth is not None and (pth.startswith(("/", "*")) or len(args) >= 3):
                events.append((voff, "route", dict(recv=recv, method=_norm_methods(ms), path=pth, hargs=args[2:])))
        elif vl == "combo":
            p = _const_str(args[0]) if args else None
            if p is None:
                continue
            pos = pclose + 1
            while True:
                cm = _CHAIN.match(t, pos)
                if not cm:
                    break
                cs, cclose = _scan(t, cm.end() - 1)
                events.append((cm.start(1), "route", dict(recv=recv, method=cm.group(1).upper(), path=p,
                                                          hargs=[t[a:b] for a, b in cs])))
                pos = cclose + 1
        else:
            p = _const_str(args[0]) if args else None
            if p is None:
                continue
            handle = vl in ("handle", "handlefunc")
            method = "ANY" if vl in ("any", "handle", "handlefunc") else verb.upper()
            if handle:
                sm = _STD_PATTERN.match(p)
                if sm:
                    method, p = sm.group(1), sm.group(2)
                mc = _METHODS_CHAIN.match(t, pclose + 1)
                if mc:
                    ms, _ = _scan(t, mc.end() - 1)
                    names = [_const_str(t[a:b]) for a, b in ms]
                    if names and all(names):
                        method = _norm_methods(",".join(names))
            if len(args) < 2 or not (p == "" or p.startswith(("/", "*", "{"))):
                continue
            events.append((voff, "route", dict(recv=recv, method=method, path=p, hargs=args[1:])))
    return events, uses


def _helper_events(src: _Src, groups):
    """Closures assigned to a variable and router helper functions: the caller decides the prefix of their routes."""
    t = src.t
    out = []

    def body_end(pclose):
        b = t.find("{", pclose)
        if b < 0 or b - pclose > 120 or "\n" in t[pclose:b]:
            return None
        return _scan(t, b)[1]

    for m in _HELPER_CLOSURE.finditer(t):
        _, pclose = _scan(t, m.end() - 1)
        end = body_end(pclose)
        if end is not None:
            out.append((m.start(), "helper", dict(end=end)))
    for m in _FUNC_DECL.finditer(t):
        _, pclose = _scan(t, m.end() - 1)
        if not _ROUTER_PARAM.search(t[m.end() - 1:pclose]):
            continue
        end = body_end(pclose)
        if end is None:
            continue
        name = m.group(1)
        called_in_group = any(
            any(s <= c.start() < e for s, e in groups)
            for c in re.finditer(r"(?<![\w.])" + re.escape(name) + r"\s*\(", t) if c.start() != m.start(1))
        if re.match(r"add[A-Z]", name) or called_in_group:
            out.append((m.start(), "helper", dict(end=end)))
    return out


def _routes(src: _Src, path: str):
    events, uses = _route_events(src)
    if events:
        groups = [ev[2]["closure"] for ev in events if ev[1] == "group" and ev[2]["closure"]]
        events.extend(_helper_events(src, groups))
        events.sort(key=lambda e: e[0])
    stack: list = []  # (end offset, ctx)
    named: dict = {}  # gin-style ``v1 := r.Group("/v1")`` variables -> ctx

    for off, kind, p in events:
        while stack and stack[-1][0] <= off:
            stack.pop()
        cur = stack[-1][1] if stack else _ROOT
        if kind == "helper":
            stack.append((p["end"], (cur[0], cur[1], True)))
            continue
        base = named.get(p["recv"], cur)
        if kind == "group":
            prefix = _join(base[0], p["own"]) if (base[0] or p["own"]) else ""
            ctx = (prefix, base[1] + tuple(p["mws"]), base[2] or p["own"] is None)
            if p["closure"]:
                stack.append((p["closure"][1], ctx))
            elif p["var"]:
                named[p["var"]] = ctx
            yield from _auth_facts(src, path, p["voff"], p["mws"], "group")
            continue
        flat = _flatten(p["hargs"])
        if not flat:
            continue
        own = [x for x in (_label(a) for a in flat[:-1]) if x]
        d = dict(type="route", method=p["method"], handler=_label(flat[-1]) or "inline", middleware=list(base[1]) + own)
        if base[2]:
            d["prefix_unresolved"] = True
        yield Fact.make("entry_point", STACK_ID, path, src.line(off), _join(base[0], p["path"]), **d)
        yield from _auth_facts(src, path, off, own, "route")
    for voff, labels in uses:
        yield from _auth_facts(src, path, voff, labels, "use")


def _auth_facts(src, path, off, labels, scope):
    for lab in labels:
        if _is_auth(lab):
            yield Fact.make("auth_check", STACK_ID, path, src.line(off), lab, mechanism=_auth_mechanism(lab), scope=scope)


# ---------------------------------------------------------------- commands

_CMD = re.compile(r"(cli|cobra)\.Command\s*\{")
_FIELD = re.compile(r"(\w+)\s*:\s*(.*)", re.S)


def _fields(t, open_idx):
    """{field: (offset, text)} of a composite literal's top-level ``Key: value`` items."""
    spans, _ = _scan(t, open_idx)
    out = {}
    for a, b in spans:
        m = _FIELD.match(t, a, b)
        if m and m.group(1) not in out:
            out[m.group(1)] = (a, t[m.start(2):b].strip())
    return out


def _commands(src: _Src, path: str):
    t = src.t
    for m in _CMD.finditer(t):
        fw = m.group(1)
        open_idx = m.end() - 1
        if t[max(0, m.start() - 3):m.start()].endswith(("[]", "[]*")):
            # []*cli.Command{ {Name: ...}, newX() }: only the inline elements are literals
            spans, _ = _scan(t, open_idx)
            literals = [a for a, _b in spans if t[a] == "{"]
        else:
            literals = [open_idx]
        for lit in literals:
            fields = _fields(t, lit)
            key = "Name" if fw == "cli" else "Use"
            if key not in fields:
                continue
            off, expr = fields[key]
            val = _const_str(expr)
            if not val or not val.split():
                continue
            d = dict(type="command", framework="urfave/cli" if fw == "cli" else "cobra")
            usage = fields.get("Usage" if fw == "cli" else "Short")
            if usage and _const_str(usage[1]):
                d["usage"] = _const_str(usage[1])[:200]
            act = fields.get("Action") if fw == "cli" else (fields.get("RunE") or fields.get("Run"))
            if act:
                d["handler"] = _label(act[1]) or "inline"
            yield Fact.make("entry_point", STACK_ID, path, src.line(off), val.split()[0], **d)


# ---------------------------------------------------------------- jobs

_JOB = re.compile(r"(?<![\w])(?:\w+\.)?RegisterTask\w*\s*\(")
_CRON_ADD = re.compile(r"\.\s*(AddFunc|AddJob)\s*\(")
_CRON_SPEC = re.compile(r"^(?:@\w+(?:\s+\S+)?|(?:\S+\s+){4,6}\S+)$")
_SCHEDULE = re.compile(r"\bSchedule\s*:\s*(\"(?:\\.|[^\"\\\n])*\"|`[^`]*`)")
_ENABLED = re.compile(r"\bEnabled\s*:\s*(true|false)\b")
_FIRST_CALL = re.compile(r"(?<![\w.])([A-Za-z_]\w*(?:\.[A-Za-z_]\w*)*)\s*\(")
_NOT_HANDLERS = frozenset("if for switch select return func go defer len cap make new append panic recover string int int64 "
                          "float64 bool byte error".split())


def _handler_of(fn: str):
    """Function passed to a job registration: the first call in an inline body, or the identifier itself."""
    fn = fn.strip()
    if not fn:
        return None
    if _FUNC_LIT.match(fn):
        b = fn.find("{")
        for c in _FIRST_CALL.finditer(fn, b + 1 if b >= 0 else 0):
            if c.group(1) not in _NOT_HANDLERS:
                return c.group(1)
        return "inline"
    return _label(fn)


def _jobs(src: _Src, path: str):
    t = src.t
    for m in _JOB.finditer(t):
        spans, _ = _scan(t, m.end() - 1)
        args = [t[a:b] for a, b in spans]
        name = _const_str(args[0]) if args else None
        if not name:
            continue  # the RegisterTask wrapper itself passes ``name`` through
        cfg = args[1] if len(args) > 1 else ""
        sm, em = _SCHEDULE.search(cfg), _ENABLED.search(cfg)
        yield Fact.make("entry_point", STACK_ID, path, src.line(m.start()), name, type="job",
                        schedule=_const_str(sm.group(1)) if sm else None,
                        enabled=(em.group(1) == "true") if em else None,
                        handler=_handler_of(args[2]) if len(args) > 2 else None)
    if ".AddFunc" in t or ".AddJob" in t:
        for m in _CRON_ADD.finditer(t):
            spans, _ = _scan(t, m.end() - 1)
            args = [t[a:b] for a, b in spans]
            spec = _const_str(args[0]) if args else None
            if not spec or len(args) < 2 or not _CRON_SPEC.match(spec.strip()):
                continue
            handler = _handler_of(args[1])
            name = handler if handler and handler != "inline" else "cron " + spec
            yield Fact.make("entry_point", STACK_ID, path, src.line(m.start()), name, type="job",
                            schedule=spec, enabled=None, handler=handler)


# ---------------------------------------------------------------- config

_SEC_ASSIGN = re.compile(r"\b(\w+)\s*:?=\s*[\w.]+\.Section\(\s*\"([^\"]*)\"\s*\)(?!\s*\.\s*Key)")
_KEY_CHAIN = re.compile(r"\.Section\(\s*\"([^\"]*)\"\s*\)\s*\.\s*Key\(\s*\"([^\"]+)\"\s*\)")
_KEY_VAR = re.compile(r"(?<![\w.])(\w+)\s*\.\s*Key\(\s*\"([^\"]+)\"\s*\)")
_CFG_RECV = re.compile(r"(?i)(?:sec|section|\w*sec|\w*cfg|\w*config|cfg\w*|conf\w*|ini\w*)")
_ENV = re.compile(r"(?<![\w.])os\s*\.\s*(Getenv|LookupEnv)\s*\(\s*\"([^\"]+)\"")
_VIPER = re.compile(r"(?<![\w.])(\w+)\s*\.\s*(?:Get(?:String|Int|Int64|Bool|Float64|Duration|StringSlice|StringMap|StringMapString)?"
                    r"|IsSet)\s*\(\s*\"([^\"]+)\"")
_VIPER_NEW = re.compile(r"\b(\w+)\s*:?=\s*viper\.New\s*\(")


def _cfg(src, path, off, key, via):
    return Fact.make("config_key", STACK_ID, path, src.line(off), key, source="code",
                     secret_location=is_secret_key(key), use="read", via=via,
                     read_kind="env" if via == "env" else "file")


def _config(src: _Src, path: str):
    t = src.t
    if ".Key(" in t:
        assigns: dict = {}
        for m in _SEC_ASSIGN.finditer(t):
            assigns.setdefault(m.group(1), []).append((m.start(), m.group(2)))
        for m in _KEY_CHAIN.finditer(t):
            sec, key = m.group(1), m.group(2)
            yield _cfg(src, path, m.start(), f"{sec}.{key}" if sec else key, "ini")
        for m in _KEY_VAR.finditer(t):
            recv, key = m.group(1), m.group(2)
            hist = assigns.get(recv)
            sec = None
            if hist:
                i = bisect_right([h[0] for h in hist], m.start()) - 1
                sec = hist[i][1] if i >= 0 else None
            if sec is None and not _CFG_RECV.fullmatch(recv):
                continue
            yield _cfg(src, path, m.start(), f"{sec}.{key}" if sec else key, "ini")
    if "Getenv" in t or "LookupEnv" in t:
        for m in _ENV.finditer(t):
            yield _cfg(src, path, m.start(), m.group(2), "env")
    if "viper" in t:
        names = {"viper"} | set(_VIPER_NEW.findall(t))
        for m in _VIPER.finditer(t):
            if m.group(1) in names:
                yield _cfg(src, path, m.start(), m.group(2), "viper")


# ---------------------------------------------------------------- SQL and outbound calls

# The lookahead keeps the match selective: only calls whose literal starts like a SQL statement are scanned.
_SQL_CALL = re.compile(r"\.\s*(Query|QueryRow|Exec|QueryContext|QueryRowContext|ExecContext|Prepare|PrepareContext|"
                       r"Select|Get|MustExec|NamedExec|NamedQuery)\s*\(\s*(?:[&\w.]+\s*,\s*)?(?=[\"`]\s*\(?\s*"
                       r"(?:select|insert|update|delete|with|merge|truncate|exec|call|replace)\b)", re.I)
_TABLE = r"([A-Za-z_#@\[\"`$][\w.\[\]\"`${}#@]*)"


def _clean_table(t: str) -> str:
    return t.strip().strip(",;()").replace("[", "").replace("]", "").replace('"', "").replace("`", "")


def _sql_tables(sql: str):
    op = re.match(r"^\s*\(?\s*(\w+)", sql).group(1).lower()
    if op in ("exec", "call"):
        pm = re.match(r"^\s*\(?\s*(?:exec|call)\s+" + _TABLE, sql, re.I)
        return "execute", [pm.group(1)] if pm else []
    if op in ("select", "with"):
        return "select", re.findall(r"(?i)\b(?:from|join)\s+" + _TABLE, sql)
    if op in ("insert", "merge", "replace"):
        return ("merge" if op == "merge" else "insert"), re.findall(r"(?i)\binto\s+" + _TABLE, sql)[:1]
    if op == "update":
        return op, re.findall(r"(?i)^\s*\(?\s*update\s+" + _TABLE, sql)[:1]
    if op == "delete":
        return op, re.findall(r"(?i)\bfrom\s+" + _TABLE, sql)[:1]
    return op, re.findall(r"(?i)\btable\s+" + _TABLE, sql)[:1]


def _sql(src: _Src, path: str):
    t = src.t
    for m in _SQL_CALL.finditer(t):
        spans, _ = _scan(t, t.rfind("(", 0, m.end()))
        lit = next(((a, b) for a, b in spans if t[a] in "\"`"), None)
        sql = _lead_str(t[lit[0]:lit[1]]) if lit else None
        if not sql:
            continue
        op, tables = _sql_tables(" ".join(sql.split()))
        names = sorted({_clean_table(x) for x in tables if _clean_table(x)})
        for n in names or ["(unparsed)"]:
            yield Fact.make("data_access", STACK_ID, path, src.line(m.start()), n, type="sql", operation=op)


_HTTP_CALL = re.compile(r"(?<![\w.])http\s*\.\s*(NewRequestWithContext|NewRequest|Get|Post|PostForm|Head)\s*\(")
_URL_ARG = {"NewRequestWithContext": 2, "NewRequest": 1}


def _external(src: _Src, path: str):
    t = src.t
    for m in _HTTP_CALL.finditer(t):
        verb = m.group(1)
        spans, _ = _scan(t, m.end() - 1)
        args = [t[a:b] for a, b in spans]
        idx = _URL_ARG.get(verb, 0)
        url = _lead_str(args[idx]) if len(args) > idx else None
        d = dict(type="http", call="http." + verb)
        if verb.startswith("NewRequest"):
            meth = _const_str(args[idx - 1]) if len(args) > idx - 1 else None
            if meth:
                d["method"] = meth.upper()
        else:
            d["method"] = {"PostForm": "POST"}.get(verb, verb.upper())
        yield Fact.make("external_call", STACK_ID, path, src.line(m.start()), _safe_url(url) if url else "http." + verb, **d)


# ---------------------------------------------------------------- connections, models, templates

_CONNECT = re.compile(r"(?<![\w.])(sql\.Open|sqlx\.Open|xorm\.NewEngine)\s*\(")
_REGISTER = re.compile(r"\.\s*RegisterModel\s*\(")


def _connections(src: _Src, path: str):
    t = src.t
    for m in _CONNECT.finditer(t):
        spans, _ = _scan(t, m.end() - 1)
        probe = " ".join(t[a:b] for a, b in spans[1:])
        secret = bool(is_secret_key(probe) or find_secret_shapes(probe)
                      or re.search(r"(?i)password=|://[^/\s\"'`:@]+:[^/\s\"'`@]*@", probe))
        yield Fact.make("connection", STACK_ID, path, src.line(m.start()), m.group(1), type="database",
                        secret_location=secret)


def _models(src: _Src, path: str):
    t = src.t
    for m in _REGISTER.finditer(t):
        spans, _ = _scan(t, m.end() - 1)
        for a, b in spans:
            arg = t[a:b].strip()
            mm = re.fullmatch(r"(?:new\s*\(\s*([\w.]+)\s*\)|&?\s*([\w.]+)\s*\{\s*\})", arg)
            if mm:
                yield Fact.make("schema_object", STACK_ID, path, src.line(m.start()), mm.group(1) or mm.group(2),
                                type="table")


def _templates(path: str, dirs: list[str]):
    if "templates" in dirs:
        yield Fact.make("ui_page", STACK_ID, path, 1, path, root=path)


# ---------------------------------------------------------------- main

# Cheap substring gates on the raw text: most files carry none of these and skip the comment pass.
_GATES = (".Group(", ".Route(", ".Combo(", ".Methods(", "Handle", ".Get(", ".Post(", ".Put(", ".Patch(", ".Delete(",
          ".Head(", ".Options(", ".Any(", ".GET(", ".POST(", ".PUT(", ".PATCH(", ".DELETE(", ".Use(", ".Connect(",
          "Command", "RegisterTask", ".AddFunc(", ".AddJob(", ".Key(", "Getenv", "LookupEnv", "viper", ".Query", ".Exec",
          ".Prepare", ".Select(", ".NamedExec", ".MustExec", "http.", "sql.Open", "sqlx.Open", "NewEngine",
          "RegisterModel")


def _extract(path: str, text: str) -> Iterable[Fact]:
    if not any(g in text for g in _GATES):
        return []
    src = _Src(text)
    t = src.t
    out: list[Fact] = list(_routes(src, path))
    if "Command" in t:
        out.extend(_commands(src, path))
    if "RegisterTask" in t or ".AddFunc" in t or ".AddJob" in t:
        out.extend(_jobs(src, path))
    out.extend(_config(src, path))
    out.extend(_sql(src, path))
    out.extend(_connections(src, path))
    if "RegisterModel" in t:
        out.extend(_models(src, path))
    if "http." in t:
        out.extend(_external(src, path))
    return list(dict.fromkeys(out))


# Module alias kept for one release; use stacks.capabilities_of(stack).
capabilities = GoStack.capabilities
