"""Finding candidates: high-precision code patterns that usually deserve a 10.1 finding.

Called once per non-skipped file by ``extract``. Never records a secret value.
Each Fact: kind "smell", name = human sentence, detail pattern=<id>, fid=<facts.fact_id>.

Patterns favour precision over recall: a candidate is a place for the auditor to look, not a verdict.
"""

from __future__ import annotations

import re
from bisect import bisect_right
from typing import Iterable

from .facts import Fact, fact_id, is_test_path
from .stacks.base import strip_comments

MAX_CHARS = 1_000_000  # larger files are skipped (the walk already drops files over 2 MB)

# ---------------------------------------------------------------------------
# Shared helpers
# ---------------------------------------------------------------------------


class _Ctx:
    """One file under analysis. Comment-stripped copies are made lazily and keep every offset."""

    def __init__(self, path: str, text: str):
        self.path = path
        self.text = text
        self._styles: dict[str, str] = {}
        self._starts: list[int] | None = None

    def code(self, style: str) -> str:
        if style not in self._styles:
            self._styles[style] = strip_comments(self.text, style)
        return self._styles[style]

    def line(self, offset: int) -> int:
        if self._starts is None:
            self._starts = [m.end() for m in re.finditer("\n", self.text)]
        return bisect_right(self._starts, offset) + 1


def _hit(pattern: str, line: int, name: str, **detail):
    return (pattern, line, name, detail)


def _blank(m: "re.Match") -> str:
    return re.sub(r"[^\n]", " ", m.group(0))


def _match_close(code: str, i: int, open_ch: str, close_ch: str) -> int:
    """Index of the bracket closing the one at ``i`` (string and char literals skipped); -1 if unbalanced."""
    depth, n, j = 0, len(code), i
    while j < n:
        ch = code[j]
        if ch == '"' or ch == "'":
            j += 1
            while j < n and code[j] != ch:
                if code[j] == "\\":
                    j += 1
                elif code[j] == "\n":
                    break
                j += 1
        elif ch == open_ch:
            depth += 1
        elif ch == close_ch:
            depth -= 1
            if depth == 0:
                return j
        j += 1
    return -1


def _blocks(code: str) -> list[tuple[int, int]]:
    """All (open, close) offsets of brace blocks, string and char literals skipped."""
    out, stack, n, j = [], [], len(code), 0
    while j < n:
        ch = code[j]
        if ch == '"' or ch == "'":
            j += 1
            while j < n and code[j] != ch:
                if code[j] == "\\":
                    j += 1
                elif code[j] == "\n":
                    break
                j += 1
        elif ch == "{":
            stack.append(j)
        elif ch == "}" and stack:
            out.append((stack.pop(), j))
        j += 1
    return sorted(out)


def _first_ident(expr: str) -> str:
    m = re.search(r"[A-Za-z_][\w.]*", expr)
    return m.group(0) if m else ""


# ---------------------------------------------------------------------------
# 1. logger-type-mismatch (.cs)
# ---------------------------------------------------------------------------

_LOGGER = re.compile(r"\bILogger<\s*([A-Za-z_]\w*(?:\.[A-Za-z_]\w*)*)\s*>")
_CS_DECL = re.compile(r"\b(?:class|record(?:\s+(?:class|struct))?|struct)\s+([A-Za-z_]\w*)\s*(<[^<>(){};]*>)?")
_FIELD_PRE = re.compile(r"(?:^|\n)[ \t]*(?:(?:public|private|protected|internal|static|readonly|required)\s+)*$")
_FIELD_POST = re.compile(r"\??\s+\w+\s*(?:;|=|\{)")
_PARAM_PRE = re.compile(r"[(,]\s*(?:\[[^\]]*\]\s*)*$")
_GENERIC_PARAM = re.compile(r"T(?:[A-Z][a-z0-9]\w*)?")
_PARAM_OWNER = re.compile(r"(\w+)\s*(?:<[^<>()]*>)?\s*$")


def _class_decls(code: str):
    out = []
    for m in _CS_DECL.finditer(code):
        name = m.group(1)
        if name in ("where", "new"):
            continue
        j, n = m.end(), len(code)
        while j < n and code[j] not in "{;":
            if code[j] == "(":
                k = _match_close(code, j, "(", ")")
                j = k + 1 if k > 0 else n
                continue
            j += 1
        if j >= n:
            continue
        end = j if code[j] == ";" else _match_close(code, j, "{", "}")
        if end < 0:
            continue
        generics = set(re.findall(r"[A-Za-z_]\w*", m.group(2) or ""))
        out.append((m.start(), end, name, generics))
    return out


def _enclosing_paren(code: str, p: int) -> int:
    depth = 0
    for j in range(p - 1, -1, -1):
        ch = code[j]
        if ch == ")":
            depth += 1
        elif ch == "(":
            if depth == 0:
                return j
            depth -= 1
        elif ch in "{};" and depth == 0:
            return -1
    return -1


def _logger_mismatch(ctx: _Ctx):
    if "ILogger<" not in ctx.text:
        return
    code = ctx.code("c")
    decls = None
    for m in _LOGGER.finditer(code):
        target = m.group(1).rsplit(".", 1)[-1]
        if target == "object" or _GENERIC_PARAM.fullmatch(target):
            continue
        before = code[max(0, m.start() - 160):m.start()]
        kind = None
        if _FIELD_PRE.search(before) and _FIELD_POST.match(code, m.end()):
            kind = "field"
        elif _PARAM_PRE.search(before):
            kind = "constructor parameter"
        if kind is None:
            continue
        if decls is None:
            decls = _class_decls(code)
        inner = [d for d in decls if d[0] <= m.start() <= d[1]]
        if not inner:
            continue
        _, _, cls, generics = max(inner, key=lambda d: d[0])
        if target == cls or target in generics:
            continue
        if kind == "constructor parameter":
            q = _enclosing_paren(code, m.start())
            owner = _PARAM_OWNER.search(code[max(0, q - 120):q]) if q >= 0 else None
            if not owner or owner.group(1) != cls:
                continue
        yield _hit("logger-type-mismatch", ctx.line(m.start()),
                   f"Class `{cls}` takes an `ILogger<{target}>` ({kind}), so its log entries are categorised under `{target}`",
                   cls=cls, logger_type=target, member=kind)


# ---------------------------------------------------------------------------
# 2. flash-without-redirect (.java)
# ---------------------------------------------------------------------------

_FLASH = re.compile(r"\.addFlashAttribute\(")
_CLASS_KW = re.compile(r"\b(?:class|interface|enum|record)\s+\w+")
_METHOD_HDR = re.compile(r"\)\s*(?:throws\s+[\w.,\s<>]+)?$")
_CONTROL_HDR = re.compile(r"\s*(?:if|for|while|switch|catch|synchronized|else)\b")
_RETURN = re.compile(r"\breturn\b\s*([^;]*);")


def _block_header(code: str, open_: int) -> str:
    cut = max(code.rfind(";", 0, open_), code.rfind("{", 0, open_), code.rfind("}", 0, open_))
    return code[cut + 1:open_].strip()


def _method_name(header: str) -> str:
    m = _METHOD_HDR.search(header)
    if not m:
        return ""
    depth = 0
    for j in range(m.start(), -1, -1):
        if header[j] == ")":
            depth += 1
        elif header[j] == "(":
            depth -= 1
            if depth == 0:
                nm = re.search(r"(\w+)\s*$", header[:j])
                return nm.group(1) if nm else ""
    return ""


def _flash_without_redirect(ctx: _Ctx):
    if "addFlashAttribute(" not in ctx.text:
        return
    code = ctx.code("c")
    blocks = _blocks(code)
    for m in _FLASH.finditer(code):
        enclosing = [b for b in blocks if b[0] < m.start() < b[1]]
        method = None
        for k in range(1, len(enclosing)):
            hdr = _block_header(code, enclosing[k][0])
            if _METHOD_HDR.search(hdr) and not _CONTROL_HDR.match(hdr) \
                    and _CLASS_KW.search(_block_header(code, enclosing[k - 1][0])):
                method = (enclosing[k], hdr)
                break
        if method is None:
            continue
        (_, close), hdr = method
        ret = _RETURN.search(code, m.end(), close)
        if not ret:
            continue
        expr = ret.group(1).strip()
        view = None
        lit = re.match(r'"([^"]*)"', expr)
        if lit:
            if not lit.group(1).startswith("redirect:"):
                view = lit.group(1)
        elif re.fullmatch(r"[A-Z][A-Z0-9_]+", expr) and "REDIRECT" not in expr:
            view = expr
        if view is None:
            continue
        name = _method_name(hdr)
        yield _hit("flash-without-redirect", ctx.line(m.start()),
                   f"`{name}` sets a flash attribute and then returns the view `{view}` instead of redirecting, so the message is not shown",
                   method=name, view=view)


# ---------------------------------------------------------------------------
# 3. distinct-auth-errors
# ---------------------------------------------------------------------------

_STR = re.compile(r'"(?:[^"\\\n]|\\.)*"|\'(?:[^\'\\\n]|\\.)*\'')
_USER_MSG = re.compile(r"(?i)invalid\s+user(?:name)?\b|user\s+not\s+found|unknown\s+user")
_PASS_MSG = re.compile(r"(?i)invalid\s+password|wrong\s+password|incorrect\s+password")
_WINDOW = 25


def _distinct_auth(ctx: _Ctx, style: str):
    if not (_USER_MSG.search(ctx.text) and _PASS_MSG.search(ctx.text)):
        return
    code = ctx.code(style)
    users, passes = [], []
    for m in _STR.finditer(code):
        lit = m.group(0)
        if _USER_MSG.search(lit) and "password" not in lit.lower():
            users.append(ctx.line(m.start()))
        if _PASS_MSG.search(lit):
            passes.append(ctx.line(m.start()))
    seen = set()
    for u in users:
        near = [p for p in passes if abs(p - u) <= _WINDOW and p != u]
        if not near:
            continue
        p = min(near, key=lambda x: (abs(x - u), x))
        first = min(u, p)
        if first in seen:
            continue
        seen.add(first)
        yield _hit("distinct-auth-errors", first,
                   f"Login reports an unknown username (line {u}) and a wrong password (line {p}) with different messages, which reveals which accounts exist",
                   user_line=u, password_line=p)


# ---------------------------------------------------------------------------
# 4. unescaped-template-output
# ---------------------------------------------------------------------------

_JINJA_EXPR = re.compile(r"\{[{%](.*?)[}%]\}", re.S)
_JINJA_COMMENT = re.compile(r"\{#.*?#\}", re.S)
_SAFE_FILTER = re.compile(r"\|\s*safe\b")
_SAFE_BEFORE = re.compile(r"\|\s*(?:tojson|e|escape|forceescape|striptags)\b")
_MARKUP = re.compile(r"(?<!class )(?<!def )\bMarkup\(\s*([A-Za-z_][\w.]*)")
_HTML_RAW = re.compile(r"\bHtml\.Raw\(\s*([^)]*)")
_RAZOR_COMMENT = re.compile(r"@\*.*?\*@", re.S)
_EJS_COMMENT = re.compile(r"<%#.*?%>", re.S)
_EJS_RAW = re.compile(r"<%-\s*([^%]*?)\s*-?%>", re.S)
_EJS_SKIP = frozenset({"include", "partial", "body", "script", "style", "stylesheet", "layout", "block",
                       "yield", "content", "contentfor", "title", "meta"})
_UTEXT = re.compile(r"""th:utext\s*=\s*(?:"([^"]*)"|'([^']*)')""")
_UTEXT_INLINE = re.compile(r"\[\(\s*\$\{\s*([A-Za-z_][\w.]*)")


def _unescaped_jinja(ctx: _Ctx):
    if "safe" not in ctx.text:
        return
    code = _JINJA_COMMENT.sub(_blank, ctx.code("xml"))
    for blk in _JINJA_EXPR.finditer(code):
        inner = blk.group(1)
        sm = _SAFE_FILTER.search(inner)
        if not sm:
            continue
        before = inner[:sm.start()]
        if _SAFE_BEFORE.search(before) or re.match(r"\s*[-+]?\s*[\"']", before):
            continue
        var = _first_ident(before)
        if not var or var in ("not", "if", "set"):
            continue
        yield _hit("unescaped-template-output", ctx.line(blk.start(1) + sm.start()),
                   f"Template writes `{var}` without HTML escaping (Jinja `|safe` filter)",
                   expression="jinja-safe-filter", variable=var)


def _unescaped_markup(ctx: _Ctx):
    if "Markup(" not in ctx.text:
        return
    code = ctx.code("hash")
    for m in _MARKUP.finditer(code):
        var = m.group(1)
        if var in ("f", "r", "b", "rb", "br", "u", "escape", "html.escape", "str"):
            continue
        yield _hit("unescaped-template-output", ctx.line(m.start()),
                   f"`Markup(...)` marks `{var}` as safe HTML, so it is not escaped on output",
                   expression="markup-call", variable=var)


def _unescaped_razor(ctx: _Ctx, style: str):
    if "Html.Raw(" not in ctx.text:
        return
    code = ctx.code(style)
    if style == "xml":
        code = _RAZOR_COMMENT.sub(_blank, code)
    for m in _HTML_RAW.finditer(code):
        arg = m.group(1).strip()
        if not arg or arg[0] in "\"'@" or re.match(r"(?:Json|JsonSerializer|JsonConvert|Newtonsoft)\b", arg):
            continue
        var = _first_ident(arg)
        if not var:
            continue
        yield _hit("unescaped-template-output", ctx.line(m.start()),
                   f"`Html.Raw` writes `{var}` without HTML encoding",
                   expression="html-raw", variable=var)


def _unescaped_ejs(ctx: _Ctx):
    if "<%-" not in ctx.text:
        return
    code = _EJS_COMMENT.sub(_blank, ctx.code("xml"))
    for m in _EJS_RAW.finditer(code):
        expr = m.group(1)
        if not expr or expr[0] in "\"'`":
            continue
        var = _first_ident(expr)
        if not var or var.lower() in _EJS_SKIP:
            continue
        yield _hit("unescaped-template-output", ctx.line(m.start()),
                   f"EJS `<%-` writes `{var}` without HTML escaping",
                   expression="ejs-raw-output", variable=var)


def _unescaped_thymeleaf(ctx: _Ctx):
    if "utext" not in ctx.text and "[(" not in ctx.text:
        return
    code = ctx.code("xml")
    for m in _UTEXT.finditer(code):
        expr = m.group(1) if m.group(1) is not None else m.group(2)
        vm = re.search(r"\$\{\s*([A-Za-z_][\w.]*)", expr)
        if vm:
            yield _hit("unescaped-template-output", ctx.line(m.start()),
                       f"Thymeleaf `th:utext` writes `{vm.group(1)}` without HTML escaping",
                       expression="thymeleaf-utext", variable=vm.group(1))
    for m in _UTEXT_INLINE.finditer(code):
        yield _hit("unescaped-template-output", ctx.line(m.start()),
                   f"Thymeleaf unescaped inline `[(...)]` writes `{m.group(1)}` without HTML escaping",
                   expression="thymeleaf-utext", variable=m.group(1))


# ---------------------------------------------------------------------------
# 5. state-change-on-get
# ---------------------------------------------------------------------------

_FLASK_ROUTE = re.compile(r"(?m)^([ \t]*)@\w+(?:\.\w+)*\.route\(")
_FLASK_METHODS = re.compile(r"methods\s*=\s*[\[(]([^\])]*)[\])]")
_FLASK_STATE = re.compile(
    r"\bsession\.(?:add|add_all|delete|merge)\(|\.commit\(\s*\)|\.delete\(\s*\)"
    r"|DELETE FROM\b|INSERT INTO\b|UPDATE\s+\w+\s+SET\b")
_FLASK_DEF = re.compile(r"\s*(?:@[^\n]*\n\s*)*(?:async\s+)?def\s+(\w+)\s*\(")
_SPRING_MAPPING = re.compile(r"@(GetMapping|RequestMapping)\b")
_SPRING_STATE = re.compile(r"\.(?:delete\w*|save|saveAll|saveAndFlush|persist)\(")
_ASPNET_GET = re.compile(r"\[HttpGet\b(?:\([^)\n]*\))?[^\]\n]*\]")
_ASPNET_STATE = re.compile(
    r"\bSaveChanges(?:Async)?\(|\bExecuteSql\w*\(|\bExecuteDelete(?:Async)?\(|\bExecuteUpdate(?:Async)?\("
    r"|\b\w*[Cc]ontext\.\w+\.(?:Add|AddAsync|Remove|RemoveRange|Update)\("
    r"|\b_?[Dd]b\w*\.\w+\.(?:Add|AddAsync|Remove|RemoveRange)\(")
_EXPRESS_GET = re.compile(r"\b(?:router|app|server|\w+[Rr]outer)\.get\(\s*([\"'`])([^\"'`\n]*)\1\s*,")
_EXPRESS_STATE = re.compile(
    r"\.(?:deleteOne|deleteMany|findByIdAndDelete|findByIdAndRemove|findOneAndDelete|updateOne|updateMany"
    r"|insertOne|insertMany|bulkCreate)\(|\.destroy\(\s*\{"
    r"|\b(?!(?:Object|Math|JSON|Date|Array|Promise|Map|Set|Number|String|Symbol|Reflect|Buffer|URL|Intl|Error)\b)"
    r"[A-Z]\w*\.(?:remove|delete|destroy|create|update)\("
    r"|DELETE FROM\b|INSERT INTO\b|UPDATE\s+\w+\s+SET\b")
_FIRST_LITERAL = re.compile(r"""\s*["']([^"']*)["']""")


def _strip_docstring(body: str) -> str:
    m = re.match(r"\s*(\"\"\"|''').*?\1", body, re.S)
    return body[m.end():] if m else body


def _state_flask(ctx: _Ctx):
    if ".route(" not in ctx.text:
        return
    code = ctx.code("hash")
    for m in _FLASK_ROUTE.finditer(code):
        close = _match_close(code, m.end() - 1, "(", ")")
        if close < 0:
            continue
        args = code[m.end():close]
        mm = _FLASK_METHODS.search(args)
        if mm:
            verbs = {v.upper() for v in re.findall(r"[A-Za-z]+", mm.group(1))}
            if not verbs or verbs - {"GET", "HEAD", "OPTIONS"}:
                continue
        elif "methods" in args:
            continue
        dm = _FLASK_DEF.match(code, close + 1)
        if not dm:
            continue
        indent = len(m.group(1).expandtabs())
        psig = _match_close(code, dm.end() - 1, "(", ")")
        colon = code.find(":", psig) if psig > 0 else -1
        body_start = code.find("\n", colon) if colon > 0 else -1
        if body_start < 0:
            continue
        end = len(code)
        for lm in re.finditer(r"\n([ \t]*)\S", code[body_start:]):
            if len(lm.group(1).expandtabs()) <= indent:
                end = body_start + lm.start()
                break
        body = _strip_docstring(code[body_start:end])
        if "request.method" in body:
            continue
        sm = _FLASK_STATE.search(body)
        if not sm:
            continue
        lit = _FIRST_LITERAL.match(args)
        route = lit.group(1) if lit else ""
        op = re.sub(r"\s+", " ", sm.group(0)).strip()
        if op.endswith("("):
            op += "...)"
        yield _hit("state-change-on-get", ctx.line(m.start() + len(m.group(1))),
                   f"GET route `{route}` ({dm.group(1)}) changes state ({op}), so a link or prefetch can trigger it",
                   route=route, handler=dm.group(1), operation=op)


def _signature_end(code: str, i: int) -> int:
    """Offset of the ``{`` opening the method body found from ``i``; -1 for ``;`` or ``=>``."""
    depth, n, j = 0, len(code), i
    while j < n:
        ch = code[j]
        if ch == "(":
            depth += 1
        elif ch == ")":
            depth -= 1
        elif depth == 0:
            if ch == "{":
                return j
            if ch == ";" or code.startswith("=>", j):
                return -1
        j += 1
    return -1


def _sig_name(sig: str) -> str:
    m = re.search(r"(?<![@\w])(\w+)\s*\(", re.sub(r"@\w+(?:\([^)]*\))?", "", sig))
    return m.group(1) if m else ""


def _state_spring(ctx: _Ctx):
    if "Mapping" not in ctx.text:
        return
    code = ctx.code("c")
    for m in _SPRING_MAPPING.finditer(code):
        j = m.end()
        args = ""
        if code[j:j + 1] == "(":
            k = _match_close(code, j, "(", ")")
            if k < 0:
                continue
            args, j = code[j + 1:k], k + 1
        if m.group(1) == "RequestMapping" and not (
                "RequestMethod.GET" in args and not re.search(r"RequestMethod\.(?!GET)", args)):
            continue
        open_ = _signature_end(code, j)
        if open_ < 0:
            continue
        close = _match_close(code, open_, "{", "}")
        if close < 0:
            continue
        sm = _SPRING_STATE.search(code, open_, close)
        if not sm:
            continue
        name = _sig_name(code[j:open_])
        lit = re.search(r"\"([^\"]*)\"", args)
        route = lit.group(1) if lit else ""
        op = sm.group(0).strip(".(")
        yield _hit("state-change-on-get", ctx.line(m.start()),
                   f"GET mapping `{route}` ({name}) calls `{op}`, so a link or prefetch can change state",
                   route=route, handler=name, operation=op)


def _state_aspnet(ctx: _Ctx):
    if "[HttpGet" not in ctx.text:
        return
    code = ctx.code("c")
    for m in _ASPNET_GET.finditer(code):
        open_ = _signature_end(code, m.end())
        if open_ < 0:
            continue
        close = _match_close(code, open_, "{", "}")
        if close < 0:
            continue
        sm = _ASPNET_STATE.search(code, open_, close)
        if not sm:
            continue
        name = _sig_name(code[m.end():open_])
        op = re.sub(r"\s+", "", sm.group(0)).rstrip("(")
        lit = re.search(r"\"([^\"]*)\"", m.group(0))
        route = lit.group(1) if lit else ""
        yield _hit("state-change-on-get", ctx.line(m.start()),
                   f"`[HttpGet]` action `{name}` calls `{op}`, so a link or prefetch can change state",
                   route=route, handler=name, operation=op)


def _state_express(ctx: _Ctx):
    if ".get(" not in ctx.text:
        return
    code = ctx.code("c")
    for m in _EXPRESS_GET.finditer(code):
        open_ = code.find("(", m.start())
        close = _match_close(code, open_, "(", ")")
        if close < 0:
            continue
        sm = _EXPRESS_STATE.search(code, m.end(), close)
        if not sm:
            continue
        route = m.group(2)
        op = sm.group(0).strip(".(")
        yield _hit("state-change-on-get", ctx.line(m.start()),
                   f"GET route `{route}` calls `{op}`, so a link or prefetch can change state",
                   route=route, operation=op)


# ---------------------------------------------------------------------------
# 6. actuator-exposed
# ---------------------------------------------------------------------------

_ACTUATOR_KEY = "management.endpoints.web.exposure.include"
_PROP_LINE = re.compile(r"^\s*([^\s#!=:]+)\s*[=:]\s*(.*)$")
_YAML_LINE = re.compile(r"""^([A-Za-z0-9_.\-\[\]"']+)\s*:(?:\s+(.*))?$""")


def _property_pairs(text: str, yaml: bool):
    """Yield (line, dotted key, value) for a .properties or YAML file."""
    stack: list[tuple[int, str]] = []
    for i, raw in enumerate(text.split("\n"), 1):
        if not yaml:
            if raw.lstrip().startswith(("#", "!")):
                continue
            m = _PROP_LINE.match(raw)
            if m:
                yield i, m.group(1), m.group(2).strip()
            continue
        if raw.strip() == "---":
            stack = []
            continue
        s = raw.rstrip()
        stripped = s.strip()
        if not stripped or stripped.startswith("#"):
            continue
        m = _YAML_LINE.match(stripped)
        if not m:
            continue
        indent = len(s) - len(s.lstrip(" "))
        key, val = m.group(1).strip("\"'"), (m.group(2) or "").strip()
        while stack and stack[-1][0] >= indent:
            stack.pop()
        if not val:
            stack.append((indent, key))
            continue
        yield i, ".".join([k for _, k in stack] + [key]), re.split(r"\s+#", val)[0]


def _actuator(ctx: _Ctx):
    base = ctx.path.rsplit("/", 1)[-1].lower()
    if not base.startswith("application") or "exposure" not in ctx.text:
        return
    for line, key, val in _property_pairs(ctx.text, not base.endswith(".properties")):
        if key != _ACTUATOR_KEY:
            continue
        items = [v.strip().strip("\"'") for v in val.strip("[]").split(",")]
        if "*" in items:
            yield _hit("actuator-exposed", line,
                       "Spring Boot exposes every actuator endpoint over HTTP (`management.endpoints.web.exposure.include` is `*`)",
                       property=_ACTUATOR_KEY)


# ---------------------------------------------------------------------------
# 7. hardcoded-credential-constant
# ---------------------------------------------------------------------------

_CRED_WORDS = frozenset({"password", "passwd", "secret", "token", "apikey"})
_CRED_PAIRS = frozenset({("api", "key"), ("secret", "key"), ("private", "key")})
_CRED_ANY = re.compile(r"(?i)password|passwd|secret|api_?key|token|private_?key")
_NAME_TOKENS = re.compile(r"[A-Z]+(?![a-z])|[A-Z]?[a-z]+|\d+")
_KEYLIKE = re.compile(r"(?i)[a-z]+(?:[_.\-:][a-z]+)+")
_CRED_BARE = re.compile(r"(?i)password|passwd|secret|token|api_?key")

_PY_CONST = re.compile(
    r"""(?m)^([A-Za-z_]\w*)\s*(?::\s*[\w\[\], .]+?)?\s*=\s*(?:"((?:[^"\\\n]|\\.)*)"|'((?:[^'\\\n]|\\.)*)')[ \t]*(?:#.*)?\r?$""")
_JS_CONST = re.compile(
    r"""(?m)^(?:export\s+)?const\s+(\w+)\s*(?::\s*string\s*)?=\s*(?:"((?:[^"\\\n]|\\.)*)"|'((?:[^'\\\n]|\\.)*)')\s*;?[ \t]*(?://.*)?\r?$""")
_JAVA_CONST = re.compile(
    r'(?m)^[ \t]*((?:(?:public|private|protected|static|final)\s+)+)String\s+(\w+)\s*=\s*"((?:[^"\\\n]|\\.)*)"\s*;')
_CS_CONST = re.compile(
    r'(?m)^[ \t]*((?:(?:public|private|protected|internal|static|readonly|const)\s+)+)string\s+(\w+)\s*=\s*"((?:[^"\\\n]|\\.)*)"\s*;')


def _is_cred_name(name: str) -> bool:
    toks = [t.lower() for t in _NAME_TOKENS.findall(name)]
    return bool(toks) and (toks[-1] in _CRED_WORDS or tuple(toks[-2:]) in _CRED_PAIRS)


def _value_ok(name: str, value: str) -> bool:
    """True when the literal looks like an actual secret rather than an env reference, URL or key name."""
    if not value.strip() or value.startswith(("$", "%(", "<%", "@")) or "${" in value or "{{" in value:
        return False
    if re.match(r"(?i)[a-z][a-z0-9+.\-]*://", value) or value.count(" ") >= 2:
        return False
    if re.sub(r"[_\-. ]", "", value).lower() == re.sub(r"[_\-. ]", "", name).lower():
        return False
    if _CRED_ANY.search(value) and (_KEYLIKE.fullmatch(value) or _CRED_BARE.fullmatch(value)):
        return False
    return True


def _credentials(ctx: _Ctx, kind: str):
    if not _CRED_ANY.search(ctx.text):
        return
    if is_test_path(ctx.path):
        return
    text = ctx.text
    if kind == "py":
        cands = [(m, m.start(1), m.group(1), m.group(2) if m.group(2) is not None else m.group(3))
                 for m in _PY_CONST.finditer(text)]
    elif kind == "js":
        cands = [(m, m.start(1), m.group(1), m.group(2) if m.group(2) is not None else m.group(3))
                 for m in _JS_CONST.finditer(text)]
    elif kind == "java":
        cands = [(m, m.start(2), m.group(2), m.group(3)) for m in _JAVA_CONST.finditer(text)
                 if "static" in m.group(1) and "final" in m.group(1)]
    else:
        cands = [(m, m.start(2), m.group(2), m.group(3)) for m in _CS_CONST.finditer(text)
                 if "const" in m.group(1) or ("static" in m.group(1) and "readonly" in m.group(1))]
    for m, at, name, value in cands:
        if not _is_cred_name(name) or not _value_ok(name, value):
            continue
        if kind != "py" and not ctx.code("c")[m.start():m.end()].strip():
            continue
        yield _hit("hardcoded-credential-constant", ctx.line(at),
                   f"Constant `{name}` holds a hardcoded credential string in source",
                   constant=name)


# ---------------------------------------------------------------------------
# Dispatch
# ---------------------------------------------------------------------------

_BY_EXT = {
    ".cs": (_logger_mismatch, lambda c: _distinct_auth(c, "c"), lambda c: _unescaped_razor(c, "c"),
            _state_aspnet, lambda c: _credentials(c, "cs")),
    ".cshtml": (lambda c: _unescaped_razor(c, "xml"),),
    ".razor": (lambda c: _unescaped_razor(c, "xml"),),
    ".java": (_flash_without_redirect, lambda c: _distinct_auth(c, "c"), _state_spring,
              lambda c: _credentials(c, "java")),
    ".py": (lambda c: _distinct_auth(c, "hash"), _unescaped_markup, _state_flask,
            lambda c: _credentials(c, "py")),
    ".js": (lambda c: _distinct_auth(c, "c"), _state_express, lambda c: _credentials(c, "js")),
    ".ts": (lambda c: _distinct_auth(c, "c"), _state_express, lambda c: _credentials(c, "js")),
    ".asp": (lambda c: _distinct_auth(c, "asp"),),
    ".aspx": (lambda c: _distinct_auth(c, "asp"),),
    ".vb": (lambda c: _distinct_auth(c, "asp"),),
    ".html": (_unescaped_jinja, _unescaped_thymeleaf),
    ".jinja": (_unescaped_jinja,),
    ".j2": (_unescaped_jinja,),
    ".ejs": (_unescaped_ejs,),
    ".properties": (_actuator,),
    ".yml": (_actuator,),
    ".yaml": (_actuator,),
}


def extract(path: str, text: str, stacks: list[str]) -> Iterable[Fact]:
    """``stacks`` are the ids of the supported Stacks that read this file."""
    base = path.rsplit("/", 1)[-1]
    ext = base[base.rfind("."):].lower() if "." in base else ""
    handlers = _BY_EXT.get(ext)
    if not handlers or len(text) > MAX_CHARS:
        return ()
    path = path.replace("\\", "/")
    stack = stacks[0] if stacks else "generic"
    ctx = _Ctx(path, text)
    out, seen = [], set()
    for handler in handlers:
        for pattern, line, name, detail in handler(ctx):
            key = (pattern, line, name)
            if key in seen:
                continue
            seen.add(key)
            out.append(Fact.make("smell", stack, path, line, name, pattern=pattern,
                                 fid=fact_id("smell", pattern, path, line), **detail))
    return out
