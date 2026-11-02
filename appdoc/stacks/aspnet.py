"""ASP.NET (.NET Framework Web Forms + MVC 5 / Web API 2) Stack extractor.

Reads code files only (``.aspx .ascx .master .asax .cs .vb .cshtml``). Config files such as
``web.config`` and ``*.csproj`` belong to ``generic``. Regex based and comment aware; never records
a secret value, only the name and location of the place that holds one.

The shared ``dotnet_*`` helpers at the bottom half are reused by ``aspnet_core``.
"""

from __future__ import annotations

import bisect
import re
from typing import Iterable
from urllib.parse import urlsplit

from ..facts import Fact
from ..secrets import find_secret_shapes, is_secret_key
from .base import Stack, strip_comments

STACK_ID = "aspnet"

# --------------------------------------------------------------------------- lexical helpers

STR = r'(?:\$?@"(?:[^"]|"")*"|\$?"(?:[^"\\\n]|\\.)*")'
_STRTOK_CS = re.compile(STR + r"|'(?:\\.|[^'\\\n])'")
_STRTOK_VB = re.compile(r'"(?:[^"\n]|"")*"')
_STR_RX = re.compile(STR)


def _unq(tok: str, vb: bool = False) -> str:
    t = tok.lstrip("$")
    if t.startswith('@"'):
        return t[2:-1].replace('""', '"')
    if vb:
        return t[1:-1].replace('""', '"')
    return t[1:-1].replace('\\\\', '\\').replace('\\"', '"')


def _safe(text: str, limit: int) -> str:
    """Normalise whitespace, cap the length, and never let a secret-shaped value through."""
    s = " ".join(str(text).split())
    if find_secret_shapes(s):
        return "[redacted]"
    return s[:limit]


class Ctx:
    """One comment-stripped file with cached line lookup, string tokens and catch-block spans."""

    def __init__(self, text: str, vb: bool = False):
        self.t = text
        self.vb = vb
        self._nl = [i for i, c in enumerate(text) if c == "\n"]
        self._strings = None
        self._catch = None

    def line(self, off: int) -> int:
        return bisect.bisect_left(self._nl, off) + 1

    @property
    def strings(self):
        """(start, end, value) for every string literal, in order (char literals consumed, not returned)."""
        if self._strings is None:
            out = []
            for m in (_STRTOK_VB if self.vb else _STRTOK_CS).finditer(self.t):
                tok = m.group(0)
                if tok[0] in "\"$@":
                    out.append((m.start(), m.end(), _unq(tok, self.vb)))
            self._strings = out
        return self._strings

    def chains(self):
        """Yield (offset, joined value) for each string literal chain ``"a" + "b"`` (or ``&`` in VB)."""
        toks = self.strings
        i = 0
        while i < len(toks):
            s, _, v = toks[i]
            j = i
            while j + 1 < len(toks) and re.fullmatch(r"\s*[+&]\s*", self.t[toks[j][1]:toks[j + 1][0]]):
                v += toks[j + 1][2]
                j += 1
            yield s, v
            i = j + 1

    def in_catch(self, off: int) -> bool:
        if self._catch is None:
            self._catch = _catch_spans(self)
        return any(a <= off < b for a, b in self._catch)


def _blank_strings(ctx: Ctx) -> str:
    chars = list(ctx.t)
    for s, e, _ in ctx.strings:
        for k in range(s, e):
            if chars[k] != "\n":
                chars[k] = " "
    return "".join(chars)


def _catch_spans(ctx: Ctx):
    spans = []
    if ctx.vb:
        for m in re.finditer(r"(?is)\bCatch\b.*?(?=\bFinally\b|\bEnd\s+Try\b)", ctx.t):
            spans.append((m.start(), m.end()))
        return spans
    ns = _blank_strings(ctx)
    for m in re.finditer(r"\bcatch\b", ns):
        i = ns.find("{", m.end())
        if i < 0:
            continue
        depth, j = 0, i
        while j < len(ns):
            if ns[j] == "{":
                depth += 1
            elif ns[j] == "}":
                depth -= 1
                if depth == 0:
                    break
            j += 1
        spans.append((i, j))
    return spans


# --------------------------------------------------------------------------- attributes / classes

_ATTR_BLOCK = r"\[(?:[^\]\"]|\"(?:[^\"\\]|\\.)*\")*\]"
_ATTR_ITEM = re.compile(
    r'([A-Za-z_][\w\.]*)\s*(?:\(((?:[^()"]|"(?:[^"\\]|\\.)*"|\([^()]*\))*)\))?')
_CLASS_RX = re.compile(r"\bclass\s+(\w+)(?:\s*:\s*([^{\n]+))?")


def attr_items(attr_text: str):
    """Parse ``[A, B("x")][C]`` into [(name, args-or-None)] with the ``Attribute`` suffix removed."""
    out = []
    for blk in re.finditer(_ATTR_BLOCK, attr_text):
        inner = blk.group(0)[1:-1]
        for m in _ATTR_ITEM.finditer(inner):
            name = m.group(1).rsplit(".", 1)[-1]
            if name.endswith("Attribute") and len(name) > 9:
                name = name[:-9]
            out.append((name, m.group(2)))
    return out


def first_string_arg(args: str | None, names=("Template", "routeTemplate")) -> str | None:
    """First positional string literal of an attribute argument list, or a ``Template = "..."``."""
    if not args:
        return None
    m = re.match(r"\s*(" + STR + ")", args)
    if m:
        return _unq(m.group(1))
    m = re.match(r"\s*(?:" + "|".join(names) + r")\s*=\s*(" + STR + ")", args)
    return _unq(m.group(1)) if m else None


def attrs_before(text: str, pos: int) -> str:
    """The attribute blocks that directly precede a declaration starting at ``pos``."""
    seg = text[max(0, pos - 800):pos]
    seg = re.sub(r"(?:(?:public|internal|private|protected|abstract|sealed|partial|static)\s+)*$", "", seg)
    m = re.search(r"((?:" + _ATTR_BLOCK + r"\s*)+)$", seg)
    return m.group(1) if m else ""


class ClassInfo:
    def __init__(self, name, base, pos, attrs):
        self.name, self.base, self.pos, self.attrs = name, base or "", pos, attr_items(attrs)


def find_classes(ctx: Ctx):
    out = []
    for m in _CLASS_RX.finditer(ctx.t):
        out.append(ClassInfo(m.group(1), m.group(2), m.start(), attrs_before(ctx.t, m.start())))
    return out


def class_at(classes, off):
    best = None
    for c in classes:
        if c.pos < off:
            best = c
        else:
            break
    return best


_METHOD = re.compile(
    r"(?P<attrs>(?:" + _ATTR_BLOCK + r"\s*)*)"
    r"public\s+(?P<mods>(?:(?:virtual|override|async|static|new|sealed|extern|unsafe)\s+)*)"
    r"(?P<ret>[\w\.<>\[\],\? ]+?)\s+(?P<name>\w+)\s*\((?P<args>(?:[^()]|\([^()]*\))*)\)"
    r"(?=\s*(?:\{|where\b|=>|;))")


def find_methods(ctx: Ctx, classes):
    for m in _METHOD.finditer(ctx.t):
        if m.group("ret").strip() in ("class", "struct", "interface", "enum", "return", "new"):
            continue
        yield m, class_at(classes, m.start()), attr_items(m.group("attrs"))


# --------------------------------------------------------------------------- shared SQL helpers

def _clean_ident(s: str) -> str:
    return s.replace("[", "").replace("]", "").strip(".;,)")


_SQL_SELECT = re.compile(r"^\s*(?:WITH\b.*?)?SELECT\b.+?\bFROM\s+([\w\.\[\]#@]+)", re.I | re.S)
_SQL_SELECT_NOFROM = re.compile(r"^\s*SELECT\b", re.I)
_SQL_INSERT = re.compile(r"^\s*INSERT\s+(?:INTO\s+)?([\w\.\[\]#@]+)", re.I)
_SQL_UPDATE = re.compile(r"^\s*UPDATE\s+([\w\.\[\]#@]+)\s+SET\b", re.I)
_SQL_DELETE = re.compile(r"^\s*DELETE\s+FROM\s+([\w\.\[\]#@]+)", re.I)
_SQL_MERGE = re.compile(r"^\s*MERGE\s+(?:INTO\s+)?([\w\.\[\]#@]+)", re.I)
_SQL_TRUNC = re.compile(r"^\s*TRUNCATE\s+TABLE\s+([\w\.\[\]#@]+)", re.I)
_SQL_EXEC = re.compile(r"^\s*EXEC(?:UTE)?\s+([\w\.\[\]#@]+)", re.I)


def classify_sql(value: str):
    """Return (type, name, operation) for a string that is a SQL statement, else None."""
    v = value.strip()
    if not v or "\n" in v[:0]:
        return None
    for rx, op in ((_SQL_INSERT, "insert"), (_SQL_UPDATE, "update"), (_SQL_DELETE, "delete"),
                   (_SQL_MERGE, "merge"), (_SQL_TRUNC, "delete")):
        m = rx.match(v)
        if m:
            return "sql", _clean_ident(m.group(1)), op
    m = _SQL_EXEC.match(v)
    if m:
        return "stored_procedure", _clean_ident(m.group(1)), "exec"
    m = _SQL_SELECT.match(v)
    if m:
        return "sql", _clean_ident(m.group(1)), "select"
    if _SQL_SELECT_NOFROM.match(v) and len(v) > 12:
        return "sql", _safe(v, 60), "select"
    return None


# --------------------------------------------------------------------------- shared fact builders

_AUTH_CS = re.compile(
    r"\[\s*(Authorize|AllowAnonymous)(?:Attribute)?\s*(?:\(((?:[^()\"]|\"(?:[^\"\\]|\\.)*\"|\([^()]*\))*)\))?\s*(?:,[^\]]*)?\]")
_AUTH_VB = re.compile(
    r"<\s*(Authorize|AllowAnonymous)(?:Attribute)?\s*(?:\(((?:[^()\"]|\"(?:[^\"\\]|\\.)*\"|\([^()]*\))*)\))?\s*>")
_ISINROLE = re.compile(r"\bUser\s*\.\s*IsInRole\s*\(\s*(" + STR + r")\s*\)")
_IDENTITY = re.compile(r"\bUser\s*\.\s*Identity\s*\??\s*\.\s*IsAuthenticated\b")
_SESSION_GUARD_CS = re.compile(
    r"\bif\s*\((?P<cond>[^\n{;]*?Session\s*\[\s*\"(?P<k>[^\"]+)\"\s*\][^\n{;]*?)\)\s*\{?\s*"
    r"(?:return\s+)?(?:Response\s*\.\s*Redirect|Redirect\w*\s*\(|Server\s*\.\s*Transfer)")
_SESSION_GUARD_VB = re.compile(
    r"(?i)\bIf\s+(?P<cond>[^\n]*?Session\s*\(\s*\"(?P<k>[^\"]+)\"\s*\)[^\n]*?)\s+Then\s*(?:\r?\n\s*)?"
    r"(?:Response\s*\.\s*Redirect|Server\s*\.\s*Transfer)")

_ERR_WORDS = re.compile(
    r"(?i)\b(error|invalid|fail(?:ed|ure|s)?|not found|denied|unauthori[sz]ed|required|unable|cannot|can't|could not|"
    r"does not exist|incorrect|expired)\b")
_INFO_WORDS = re.compile(r"(?i)\b(sent|saved|success(?:ful(?:ly)?)?|created|updated|deleted|thank|complete[d]?)\b")


def _msg(stack, path, ctx, off, text, context):
    text = _strip_tags(text)
    if not re.search(r"[A-Za-z]{3}", text):
        return None
    return Fact.make("message", stack, path, ctx.line(off), _safe(text, 200), context=context)


def _strip_tags(s: str) -> str:
    return " ".join(re.sub(r"<[^>]*>", " ", s).replace("&nbsp;", " ").split())


def error_messages(stack, path, ctx: Ctx):
    """``ErrorMessage="..."`` validators (code and markup)."""
    for m in re.finditer(r"\bErrorMessage\s*:?=\s*(?:\"((?:[^\"\\\n]|\\.)*)\"|'([^'\n]*)')", ctx.t):
        val = m.group(1) if m.group(1) is not None else m.group(2)
        if "<%" in val or not val.strip():
            continue
        f = _msg(stack, path, ctx, m.start(), val, "validation")
        if f:
            yield f


def dotnet_common(stack, path, ctx: Ctx, web_forms: bool) -> Iterable[Fact]:
    """Framework independent patterns: data access, external calls, auth checks, messages, secret locations."""
    t = ctx.t
    base = path.rsplit("/", 1)[-1]
    vb = ctx.vb

    # ----- data_access: stored procedures
    sp_literals: set[int] = set()
    cmd_new = re.compile(
        r"(?:\b(\w+)\s*=\s*new\s+(?:[\w\.]+\.)?\w*Command\s*\(\s*(" + STR + r")"
        r"|\b(\w+)\s+As\s+New\s+(?:[\w\.]+\.)?\w*Command\s*\(\s*(" + STR + r"))", re.I)
    cmd_text = re.compile(r"\b(\w+)\s*\.\s*CommandText\s*=\s*(" + STR + ")")
    defs = []  # (offset of var use, var, literal start, literal value)
    for m in cmd_new.finditer(t):
        var, lit, start = (m.group(1), m.group(2), m.start(2)) if m.group(1) else (m.group(3), m.group(4), m.start(4))
        defs.append((m.start(), var, start, _unq(lit, vb)))
    for m in cmd_text.finditer(t):
        defs.append((m.start(), m.group(1), m.start(2), _unq(m.group(2), vb)))
    defs.sort()
    for m in re.finditer(r"\b(\w+)\s*\.\s*CommandType\s*=\s*(?:System\.Data\.)?CommandType\s*\.\s*StoredProcedure", t):
        var, off = m.group(1), m.start()
        before = [d for d in defs if d[1] == var and d[0] < off]
        after = [d for d in defs if d[1] == var and d[0] >= off and d[0] - off < 500]
        d = before[-1] if before else (after[0] if after else None)
        if d and re.match(r"^[\w\.\[\]]+$", d[3]) and d[2] not in sp_literals:
            sp_literals.add(d[2])
            yield Fact.make("data_access", stack, path, ctx.line(d[2]), _clean_ident(d[3]),
                            type="stored_procedure", operation="exec")
    for m in re.finditer(
            r"new\s+(?:[\w\.]+\.)?\w*Command\s*\(\s*(" + STR + r")[^;{]*\{[^}]*CommandType\s*=\s*(?:System\.Data\.)?"
            r"CommandType\s*\.\s*StoredProcedure", t):
        v = _unq(m.group(1), vb)
        if m.start(1) not in sp_literals and re.match(r"^[\w\.\[\]]+$", v):
            sp_literals.add(m.start(1))
            yield Fact.make("data_access", stack, path, ctx.line(m.start(1)), _clean_ident(v),
                            type="stored_procedure", operation="exec")

    # ----- data_access: inline SQL strings (string literal chains)
    for off, value in ctx.chains():
        if off in sp_literals:
            continue
        c = classify_sql(value)
        if c:
            yield Fact.make("data_access", stack, path, ctx.line(off), c[1], type=c[0], operation=c[2])

    # ----- data_access: EF entities
    for m in re.finditer(r"\bI?DbSet\s*<\s*([\w\.]+)\s*>\s+(\w+)", t):
        yield Fact.make("data_access", stack, path, ctx.line(m.start()), m.group(1).rsplit(".", 1)[-1],
                        type="entity", operation="access", property=m.group(2))

    # ----- connection facts (location only; never the value)
    for m in re.finditer(r"\bConnectionStrings\s*\[\s*\"([^\"]+)\"\s*\]|\bGetConnectionString\s*\(\s*\"([^\"]+)\"", t):
        yield Fact.make("connection", stack, path, ctx.line(m.start()), m.group(1) or m.group(2),
                        type="database", secret_location=True)
    for m in re.finditer(r"(?:\bnew\s+(?:[\w\.]+\.)?\w*Connection\s*\(\s*|\.ConnectionString\s*=\s*)(" + STR + ")", t):
        v = _unq(m.group(1), vb)
        if "=" in v and ";" in v or re.search(r"(?i)\b(server|data source|host)\s*=", v):
            yield Fact.make("connection", stack, path, ctx.line(m.start(1)), "inline connection string",
                            type="database", secret_location=bool(find_secret_shapes(v) or re.search(r"(?i)pwd|password", v)))
    for m in re.finditer(r"\b([A-Za-z_]\w*)\s*:?=\s*(" + STR + ")", t):
        name, v = m.group(1), _unq(m.group(2), vb)
        if is_secret_key(name) and len(v) >= 3 and not re.search(r"\s", v) and \
                not re.search(r"(?i)(message|msg|label|text|title|prompt|error|hint|placeholder|desc|caption|format|regex|"
                              r"pattern|header|query|param|field|url|endpoint|claim|policy|scheme)", name):
            yield Fact.make("config_key", stack, path, ctx.line(m.start()), name, source=base, secret_location=True)

    # ----- external_call
    http_use = re.search(
        r"\b(?:HttpClient|WebClient|HttpWebRequest|WebRequest|RestClient|IHttpClientFactory|CreateClient|AddHttpClient)\b", t)
    if http_use:
        urls = []
        for s, e, v in ctx.strings:
            if re.match(r"(?i)https?://[^\s\"{]+", v):
                host = urlsplit(v).netloc.rsplit("@", 1)[-1].lower()
                if re.search(r"w3\.org|schemas\.|purl\.org|microsoft\.com|xmlsoap|openxmlformats|xmlns", host):
                    continue
                sp = urlsplit(v)
                urls.append((s, f"{sp.scheme}://{sp.netloc.rsplit('@', 1)[-1]}{sp.path}"))
        for s, u in urls:
            yield Fact.make("external_call", stack, path, ctx.line(s), _safe(u, 200), type="http")
        if not urls:
            for m in re.finditer(r"\bnew\s+(HttpClient|WebClient|RestClient)\b|\b(WebRequest|HttpWebRequest)\s*\.\s*Create(?:Http)?\s*\(", t):
                yield Fact.make("external_call", stack, path, ctx.line(m.start()), m.group(1) or m.group(2), type="http")
    for m in re.finditer(r"\bnew\s+(?:System\.Net\.Mail\.)?SmtpClient\s*\(\s*(" + STR + ")?", t):
        host = _unq(m.group(1), vb) if m.group(1) else "SmtpClient"
        yield Fact.make("external_call", stack, path, ctx.line(m.start()), _safe(host, 200), type="email")
    if re.search(r"\bMailKit\b", t):
        for m in re.finditer(r"\.\s*Connect(?:Async)?\s*\(\s*(" + STR + ")", t):
            yield Fact.make("external_call", stack, path, ctx.line(m.start()), _safe(_unq(m.group(1), vb), 200), type="email")
    for m in re.finditer(
            r"(?<![\w\.])(?:System\s*\.\s*IO\s*\.\s*)?(File|Directory)\s*\.\s*"
            r"(\w+)\s*\(\s*(?:Server\s*\.\s*MapPath\s*\(\s*|Path\s*\.\s*Combine\s*\(\s*)?(" + STR + ")?", t):
        meth = m.group(2)
        if re.match(r"(?:Read|Write|Append|Delete|Copy|Move|Create|Open|Exists|Get|Enumerate|Replace|Set)", meth):
            name = _unq(m.group(3), vb) if m.group(3) else f"{m.group(1)}.{meth}"
            yield Fact.make("external_call", stack, path, ctx.line(m.start()), _safe(name, 200),
                            type="file", operation=f"{m.group(1)}.{meth}")
    for m in re.finditer(r"\bProcess\s*\.\s*Start\s*\(\s*(" + STR + r")?|\bnew\s+ProcessStartInfo\s*\(\s*(" + STR + ")?", t):
        lit = m.group(1) or m.group(2)
        yield Fact.make("external_call", stack, path, ctx.line(m.start()),
                        _safe(_unq(lit, vb), 200) if lit else "Process.Start", type="process")

    # ----- auth_check
    classes = find_classes(ctx) if not vb else []
    for m in (_AUTH_VB if vb else _AUTH_CS).finditer(t):
        kind, args = m.group(1), m.group(2)
        roles = []
        policy = None
        if args:
            rm = re.search(r"\bRoles\s*:?=\s*(" + STR + ")", args)
            if rm:
                roles = [r.strip() for r in _unq(rm.group(1), vb).split(",") if r.strip()]
            pm = re.search(r"\bPolicy\s*:?=\s*(" + STR + ")", args)
            if pm:
                policy = _unq(pm.group(1), vb)
        nm = f"[{kind}" + (f"({' '.join(args.split())})" if args else "") + "]"
        detail = dict(mechanism="attribute")
        if roles:
            detail["roles"] = roles
        if policy:
            detail["policy"] = policy
        applies = _applies_to(ctx, classes, m.end()) if classes else ""
        if applies:
            detail["applies_to"] = applies
        yield Fact.make("auth_check", stack, path, ctx.line(m.start()), _safe(nm, 120), **detail)
    for m in _ISINROLE.finditer(t):
        role = _unq(m.group(1), vb)
        yield Fact.make("auth_check", stack, path, ctx.line(m.start()), _safe(f'User.IsInRole("{role}")', 120),
                        mechanism="role", roles=[role])
    for m in _IDENTITY.finditer(t):
        yield Fact.make("auth_check", stack, path, ctx.line(m.start()), "User.Identity.IsAuthenticated",
                        mechanism="identity")
    if web_forms:
        for m in (_SESSION_GUARD_VB if vb else _SESSION_GUARD_CS).finditer(t):
            yield Fact.make("auth_check", stack, path, ctx.line(m.start()), _safe(m.group("cond"), 120),
                            mechanism="session")

    # ----- messages
    for m in re.finditer(r"\bAddModelError\s*\(\s*(?:" + STR + r"|[\w\.]+(?:\([^()]*\))?)\s*,\s*(" + STR + ")", t):
        f = _msg(stack, path, ctx, m.start(), _unq(m.group(1), vb), "validation")
        if f:
            yield f
    if web_forms:
        for m in re.finditer(r"\b(\w+)\s*\.\s*Text\s*=\s*(" + STR + ")", t):
            name, v = m.group(1), _unq(m.group(2), vb)
            if re.search(r"(?i)err|fail|invalid|warn|denied", name) or ctx.in_catch(m.start()):
                ctxt = "error"
            elif re.search(r"(?i)msg|message|status|result|notice|info|success|confirm", name):
                ctxt = "info"
            else:
                continue
            f = _msg(stack, path, ctx, m.start(), v, ctxt)
            if f:
                yield f
        for m in re.finditer(r"\bResponse\s*\.\s*Write\s*\(\s*(" + STR + ")", t):
            v = _strip_tags(_unq(m.group(1), vb))
            if _ERR_WORDS.search(v) or (ctx.in_catch(m.start()) and v):
                ctxt = "error"
            elif _INFO_WORDS.search(v):
                ctxt = "info"
            else:
                continue
            f = _msg(stack, path, ctx, m.start(), v, ctxt)
            if f:
                yield f


def _applies_to(ctx: Ctx, classes, end: int) -> str:
    seg = ctx.t[end:end + 500]
    m = re.match(r"\s*(?:" + _ATTR_BLOCK + r"\s*)*[^{;(]*?(?:\bclass\s+(\w+)|(\w+)\s*\()", seg)
    if not m:
        return ""
    if m.group(1):
        return m.group(1)
    cls = class_at(classes, end)
    return f"{cls.name}.{m.group(2)}" if cls else m.group(2)


# --------------------------------------------------------------------------- web forms / MVC specifics

_HANDLER_CS = re.compile(
    r"(?:protected|public|private|internal)\s+(?:virtual\s+|override\s+)?void\s+(\w+)\s*\(\s*(?:object|Object)\s+\w+\s*,\s*"
    r"[\w\.]*EventArgs\s+\w+\s*\)")
_HANDLER_GLOBAL = re.compile(r"\bvoid\s+((?:Application|Session)_\w+)\s*\(")
_HANDLER_VB = re.compile(
    r"(?i)(?:Protected|Private|Public|Friend)\s+Sub\s+(\w+)\s*\(\s*(?:ByVal\s+)?\w+\s+As\s+(?:System\.)?Object\s*,\s*"
    r"(?:ByVal\s+)?\w+\s+As\s+(?:[\w\.]+\.)?\w*EventArgs\s*\)")
_HANDLER_VB_GLOBAL = re.compile(r"(?i)\bSub\s+((?:Application|Session)_\w+)\s*\(")
_CODEBEHIND_PAGE = re.compile(r"(?i)^(.*\.(?:aspx|ascx|master|asax))\.(?:cs|vb)$")

_ACTION_RET = re.compile(r"(?:Task\s*<\s*)?(?:\w+\.)*(?:ActionResult|\w+Result|IHttpActionResult|HttpResponseMessage)\b")
_HTTP_VERBS = ("HttpGet", "HttpPost", "HttpPut", "HttpDelete", "HttpPatch", "HttpHead", "HttpOptions")


def _join_route(*parts: str) -> str:
    segs = [p.strip("/") for p in parts if p and p.strip("/")]
    return "/" + "/".join(segs)


def _handlers(stack, path, ctx: Ctx, classes, vb: bool):
    cb = _CODEBEHIND_PAGE.match(path)
    for rx in ((_HANDLER_VB, _HANDLER_VB_GLOBAL) if vb else (_HANDLER_CS, _HANDLER_GLOBAL)):
        for m in rx.finditer(ctx.t):
            cls = class_at(classes, m.start()) if classes else None
            page = cb.group(1) if cb else (path if not path.lower().endswith((".cs", ".vb")) else (cls.name if cls else ""))
            detail = dict(type="handler", page=page)
            if cls:
                detail["class"] = cls.name
            yield Fact.make("entry_point", stack, path, ctx.line(m.start()), m.group(1), **detail)


def _controller_actions(stack, path, ctx: Ctx, classes):
    for m, cls, attrs in find_methods(ctx, classes):
        if cls is None or "static" in m.group("mods"):
            continue
        names = {a for a, _ in attrs}
        if "NonAction" in names:
            continue
        verbs = []
        route_tmpl = None
        has_route = False
        for a, args in attrs:
            if a in _HTTP_VERBS:
                verbs.append(a[4:].upper())
                has_route = True
                tm = first_string_arg(args)
                if tm is not None and route_tmpl is None:
                    route_tmpl = tm
            elif a == "Route":
                has_route = True
                tm = first_string_arg(args)
                if tm is not None:
                    route_tmpl = tm
            elif a == "AcceptVerbs":
                verbs += [v.upper() for v in re.findall(r'"(\w+)"', args or "")]
        is_ctrl = cls.name.endswith("Controller") or re.search(r"\b(?:Async)?Controller\b|\bApiController\b", cls.base)
        is_api = "ApiController" in cls.base
        ret = m.group("ret").strip()
        implicit = None
        if is_ctrl and not has_route:
            if is_api:
                vm = re.match(r"(Get|Post|Put|Delete|Patch)", m.group("name"))
                if not vm:
                    continue
                implicit = vm.group(1).upper()
            elif not _ACTION_RET.match(ret):
                continue
        elif not has_route:
            continue
        # class-level prefix
        prefix = None
        for a, args in cls.attrs:
            if a in ("RoutePrefix", "Route"):
                prefix = first_string_arg(args) or prefix
        ctrl = cls.name[:-len("Controller")] if cls.name.endswith("Controller") else cls.name
        action = m.group("name")
        if route_tmpl is not None:
            if route_tmpl.startswith(("/", "~/")):
                route = _join_route(route_tmpl.lstrip("~"))
            else:
                route = _join_route(prefix or "", route_tmpl)
        elif prefix is not None:
            route = _join_route(prefix)
        elif is_api and implicit:
            route = _join_route("api", ctrl)
        else:
            route = _join_route(ctrl, action)
        route = route.replace("[controller]", ctrl).replace("[action]", action)
        verbs = verbs or ([implicit] if implicit else [])
        yield Fact.make("entry_point", stack, path, ctx.line(m.start("name")), route, type="route",
                        method=",".join(sorted(set(verbs))) or "ANY", handler=f"{cls.name}.{action}")


def _route_tables(stack, path, ctx: Ctx):
    t = ctx.t
    eq = r"\s*:=?\s*"
    for m in re.finditer(r"\.\s*MapRoute\s*\(\s*(?:name" + eq + r")?(" + STR + r")\s*,\s*(?:url" + eq + r")?(" + STR + ")", t):
        tail = t[m.end():m.end() + 500]
        tail = tail[:re.search(r"\)\s*;|\n\s*\n", tail + ");").start()]
        c = re.search(r"controller\s*:?=\s*\"(\w+)\"", tail)
        a = re.search(r"action\s*:?=\s*\"(\w+)\"", tail)
        detail = dict(type="route", method="ANY", route_name=_unq(m.group(1)))
        if c:
            detail["handler"] = f"{c.group(1)}Controller.{a.group(1) if a else '{action}'}"
        yield Fact.make("entry_point", stack, path, ctx.line(m.start()), _join_route(_unq(m.group(2))), **detail)
    for m in re.finditer(r"\.\s*MapHttpRoute\s*\(\s*(?:name" + eq + r")?(" + STR + r")\s*,\s*(?:routeTemplate" + eq + r")?(" + STR + ")", t):
        yield Fact.make("entry_point", stack, path, ctx.line(m.start()), _join_route(_unq(m.group(2))),
                        type="route", method="ANY", route_name=_unq(m.group(1)))
    for m in re.finditer(r"\.\s*MapPageRoute\s*\(\s*(" + STR + r")\s*,\s*(" + STR + r")\s*,\s*(" + STR + ")", t):
        yield Fact.make("entry_point", stack, path, ctx.line(m.start()), _join_route(_unq(m.group(2))),
                        type="route", method="ANY", route_name=_unq(m.group(1)), handler=_unq(m.group(3)))


def _code_regions(text: str) -> str:
    """Keep only server-side code inside markup (``<script runat="server">`` and ``<% %>``), blank the rest."""
    out = [c if c == "\n" else " " for c in text]
    for m in re.finditer(r"<script\b[^>]*runat\s*=\s*[\"']server[\"'][^>]*>(.*?)</script>|<%(?![@#=:\-$])(.*?)%>",
                         text, re.S | re.I):
        g = 1 if m.group(1) is not None else 2
        for k in range(m.start(g), m.end(g)):
            out[k] = text[k]
    return "".join(out)


def _blank(m) -> str:
    return re.sub(r"[^\n]", " ", m.group(0))


def _strip_markup_comments(text: str) -> str:
    text = re.sub(r"<%--.*?--%>", _blank, text, flags=re.S)
    text = re.sub(r"<!--.*?-->", _blank, text, flags=re.S)
    return re.sub(r"@\*.*?\*@", _blank, text, flags=re.S)


# --------------------------------------------------------------------------- the Stack

class AspNetStack(Stack):
    id = STACK_ID
    extensions = frozenset({".aspx", ".ascx", ".master", ".asax", ".cs", ".vb", ".cshtml"})

    def __init__(self):
        self._web_target = False

    def detect(self, files):
        markers = sorted(p for p in files if p.lower().endswith((".aspx", ".ascx", ".master", ".asax")))
        if any(p.rsplit("/", 1)[-1].lower() == "global.asax" for p in files):
            markers += sorted(p for p in files
                              if p.lower().endswith(".cs") and "controllers/" in ("/" + p.lower()))
        markers = sorted(set(markers))
        # Remembered so that plain .cs helpers in a Web Forms/MVC Target (no System.Web reference) are still read.
        self._web_target = bool(markers)
        return markers[:20]

    def extract(self, path, text):
        ext = "." + path.rsplit(".", 1)[-1].lower() if "." in path.rsplit("/", 1)[-1] else ""
        if ext in (".cs", ".vb"):
            if "Microsoft.AspNetCore" in text:
                return
            if "System.Web" not in text and not self._web_target:
                return
            yield from self._code(path, text, ext == ".vb")
        elif ext in (".aspx", ".ascx", ".master", ".asax"):
            yield from self._markup(path, text, ext)
        elif ext == ".cshtml":
            if "Microsoft.AspNetCore" in text or re.search(r"(?m)^\s*@page\b", text):
                return
            clean = strip_comments(_strip_markup_comments(text), "c")
            ctx = Ctx(clean)
            yield from error_messages(STACK_ID, path, ctx)
            yield from dotnet_common(STACK_ID, path, ctx, web_forms=False)

    # -- code files
    def _code(self, path, text, vb):
        clean = strip_comments(text, "asp" if vb else "c")
        ctx = Ctx(clean, vb)
        classes = [] if vb else find_classes(ctx)
        yield from dotnet_common(STACK_ID, path, ctx, web_forms=True)
        yield from error_messages(STACK_ID, path, ctx)
        yield from _handlers(STACK_ID, path, ctx, classes, vb)
        if not vb:
            yield from _controller_actions(STACK_ID, path, ctx, classes)
        yield from _route_tables(STACK_ID, path, ctx)

    # -- markup files
    def _markup(self, path, text, ext):
        clean = _strip_markup_comments(text)
        full = Ctx(clean)
        if ext in (".aspx", ".ascx"):
            yield self._page(path, clean, ext, full)
        yield from error_messages(STACK_ID, path, full)
        code = _code_regions(clean)
        vb = bool(re.search(r"(?i)<%@[^%]*\bLanguage\s*=\s*\"VB", clean)) or \
            bool(re.search(r"(?i)<script[^>]*language\s*=\s*[\"']vb", clean))
        code = strip_comments(code, "asp" if vb else "c")
        ctx = Ctx(code, vb)
        classes = [] if vb else find_classes(ctx)
        yield from dotnet_common(STACK_ID, path, ctx, web_forms=True)
        yield from _handlers(STACK_ID, path, ctx, classes, vb)
        yield from _route_tables(STACK_ID, path, ctx)

    def _page(self, path, clean, ext, ctx: Ctx):
        m = re.search(r"<%@\s*(Page|Control)\b([^%]*)%>", clean, re.I)
        attrs = {k.lower(): v for k, v in re.findall(r"(\w+)\s*=\s*\"([^\"]*)\"", m.group(2))} if m else {}
        folder = path.rsplit("/", 1)[0] + "/" if "/" in path else ""
        detail = dict(type="page")
        cb = attrs.get("codebehind") or attrs.get("codefile")
        if cb:
            detail["codebehind"] = cb if cb.startswith("~/") else folder + cb
        if attrs.get("inherits"):
            detail["inherits"] = attrs["inherits"]
        if attrs.get("masterpagefile"):
            detail["master"] = attrs["masterpagefile"]
        if ext == ".ascx":
            detail["control"] = True
        inputs = sorted(set(re.findall(r"<(?:input|select|textarea)\b[^>]*?\bname\s*=\s*\"([^\"]+)\"", clean, re.I)))
        detail["inputs"] = inputs
        return Fact.make("entry_point", STACK_ID, path, ctx.line(m.start()) if m else 1, "/" + path, **detail)


STACK = AspNetStack()
