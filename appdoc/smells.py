"""Finding candidates: high-precision code patterns that usually deserve a 10.1 finding.

Called once per non-skipped file by ``extract``. Never records a secret value.
Each Fact: kind "smell", name = human sentence, detail pattern=<id>, fid=<facts.fact_id>.

Patterns favour precision over recall: a candidate is a place for the auditor to look, not a verdict.

Two passes (plan 2.8 W11): ``extract`` reads one file's text (cached per file); ``from_facts`` reads only Facts after
the post-passes, so it is deterministic and the same for every worker count and cache state (P3). The two passes never
emit the same pattern, with one exception: ``hardcoded-production-mode`` is found in text but needs the project Facts to
know the project's output type, so ``extract`` emits it and ``apply`` keeps only the hits ``from_facts`` confirms.
"""

from __future__ import annotations

import re
from bisect import bisect_right
from typing import Iterable

from . import dotnetcfg
from .facts import Fact, fact_id, is_test_path
from .stacks.base import strip_comments

MAX_CHARS = 1_000_000  # larger files are skipped (the walk already drops files over 2 MB)

# Patterns that oblige C12 (cite in 10.1 or dismiss in the register). Deterministic reads of declared configuration
# values oblige from the release that ships them (plan 2.8 W11 part C). The patterns of 2.7 and earlier keep their
# obligation until the labelled-set gate (T28.75) measures them. A heuristic added in 2.8 is summary-only until then.
DETERMINISTIC = frozenset({"machinekey-in-config", "named-user-access-rule", "duplicate-config-key",
                           "debug-setting-in-nondebug-config", "identifier-list-in-config"})
GRANDFATHERED = frozenset({"actuator-exposed", "distinct-auth-errors", "flash-without-redirect",
                           "hardcoded-credential-constant", "logger-type-mismatch", "state-change-on-get",
                           "unescaped-template-output"})
OBLIGING = DETERMINISTIC | GRANDFATHERED
# Heuristics (text or structure) and the summary-only patterns. A heuristic obliges only through ``OBLIGING``, and only
# after eval/smell_precision.py measures >= 0.8 on a labelled set a second person has re-labelled (T28.75, V31);
# until then it is a candidate in the summary. ``GRANDFATHERED`` are heuristics of 2.7 and earlier that keep their
# obligation unmeasured; every other heuristic is listed here and is not obliging.
HEURISTIC = frozenset({"handler-without-guard", "state-change-authenticated-only", "post-without-antiforgery",
                       "deref-before-null-check", "deref-in-null-branch", "dead-null-fallback",
                       "hardcoded-production-mode"}) | GRANDFATHERED
SUMMARY_ONLY = frozenset({"config-year-horizon", "debug-setting-in-debug-config", "debug-block-assigns-local"})


# Patterns the Facts-level pass (``from_facts``) emits; every other pattern comes from the per-file pass (``extract``).
# ``hardcoded-production-mode`` is found in text and confirmed against the project Facts, so it is listed here: its
# final hit exists only after ``from_facts`` ran.
FACTS_PATTERNS = frozenset({"machinekey-in-config", "named-user-access-rule", "debug-setting-in-nondebug-config",
                            "debug-setting-in-debug-config", "identifier-list-in-config", "config-year-horizon",
                            "handler-without-guard", "state-change-authenticated-only", "post-without-antiforgery",
                            "hardcoded-production-mode"})


def pattern_class(pattern: str) -> str:
    """``deterministic`` (a read of a declared value), ``summary-only`` or ``heuristic``."""
    if pattern in DETERMINISTIC:
        return "deterministic"
    return "summary-only" if pattern in SUMMARY_ONLY else "heuristic"


# Patterns whose detector runs for a Stack, so the summary can say "none" for a pattern that ran without a hit.
PATTERNS_BY_STACK = {
    "aspnet": ("machinekey-in-config", "named-user-access-rule", "duplicate-config-key",
               "debug-setting-in-nondebug-config", "debug-setting-in-debug-config", "identifier-list-in-config",
               "deref-before-null-check",
               "deref-in-null-branch", "dead-null-fallback", "hardcoded-production-mode", "config-year-horizon",
               "handler-without-guard", "state-change-authenticated-only", "post-without-antiforgery",
               "debug-block-assigns-local"),
}

# ---------------------------------------------------------------------------
# Shared helpers
# ---------------------------------------------------------------------------


class _Ctx:
    """One file under analysis. Comment-stripped copies are made lazily and keep every offset."""

    def __init__(self, path: str, text: str, stacks=()):
        self.path = path
        self.text = text
        self.stacks = tuple(stacks)
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
# 8. duplicate-config-key (.config text; plan 2.8 W11)
# ---------------------------------------------------------------------------

_TRANSFORM_NAME = re.compile(r"(?i)^(?:web|app)\.[^.]+\.config$")
_XDT_NS = re.compile(r"(?i)schemas\.microsoft\.com/XML-Document-Transform")
_APPSETTINGS = re.compile(r"<appSettings\b([^>]*)>(.*?)</appSettings\s*>", re.I | re.S)
_CFG_ELEMENT = re.compile(r"<(add|remove|clear)\b([^>]*?)/?>", re.I)
_CFG_ATTR = re.compile(r"""([A-Za-z_][\w:.-]*)\s*=\s*(?:"([^"]*)"|'([^']*)')""")


def _duplicate_keys(ctx: _Ctx):
    """The same key added twice in one ``appSettings`` section: the later ``add`` silently wins.

    Transform files are excluded (a transform repeats keys by design: they carry the locator, not a second value),
    and so is a section with ``file=`` or ``configSource=`` (an external file may override a value, so the Target
    alone cannot say which one wins). A ``remove`` or ``clear`` between the two adds makes the second one legal.
    """
    base = ctx.path.rsplit("/", 1)[-1]
    if _TRANSFORM_NAME.match(base) or _XDT_NS.search(ctx.text):
        return
    clean = ctx.code("xml")
    for sec in _APPSETTINGS.finditer(clean):
        attrs = {m.group(1).lower() for m in _CFG_ATTR.finditer(sec.group(1))}
        if attrs & {"file", "configsource"}:
            continue
        seen: set = set()
        for el in _CFG_ELEMENT.finditer(sec.group(2)):
            kind = el.group(1).lower()
            if kind == "clear":
                seen.clear()
                continue
            key = None
            for m in _CFG_ATTR.finditer(el.group(2)):
                if m.group(1).lower() == "key":
                    key = m.group(2) if m.group(2) is not None else m.group(3)
            if key is None:
                continue
            if kind == "remove":
                seen.discard(key)
            elif key in seen:
                yield _hit("duplicate-config-key", ctx.line(sec.start(2) + el.start()),
                           "an appSettings key is added twice in one section: the later value wins and the earlier "
                           "one is dead")
            else:
                seen.add(key)


# ---------------------------------------------------------------------------
# 9. Null patterns (.cs; plan 2.8 W11, soundness rules A I-13)
# ---------------------------------------------------------------------------


def _cs_code(text: str) -> str:
    """C# source with comments, string literals and char literals blanked (offsets and newlines kept)."""
    out, i, n = [], 0, len(text)
    while i < n:
        c, two = text[i], text[i:i + 2]
        if two == "//":
            j = text.find("\n", i)
            j = n if j < 0 else j
            out.append(" " * (j - i))
            i = j
        elif two == "/*":
            j = text.find("*/", i + 2)
            j = n if j < 0 else j + 2
            out.append(re.sub(r"[^\n]", " ", text[i:j]))
            i = j
        elif c == '"' or (c in "@$" and re.match(r'[@$]{1,2}"', text[i:i + 3])):
            m = re.match(r'[@$]{0,2}"', text[i:])
            verbatim = "@" in m.group(0)
            j = i + m.end()
            while j < n:
                if verbatim and text[j] == '"' and text[j + 1:j + 2] == '"':
                    j += 2
                    continue
                if not verbatim and text[j] == "\\":
                    j += 2
                    continue
                if text[j] == '"' or (not verbatim and text[j] == "\n"):
                    break
                j += 1
            j = min(n, j + 1)
            out.append(re.sub(r"[^\n]", " ", text[i:j]))
            i = j
        elif c == "'":
            m = re.match(r"'(?:\\.[^'\n]*|[^'\\\n])'", text[i:])
            if m:
                out.append(" " * m.end())
                i += m.end()
            else:
                out.append(c)
                i += 1
        else:
            out.append(c)
            i += 1
    return "".join(out)


_CTRL_WORDS = frozenset("if else for foreach while do switch try catch finally using lock fixed unsafe checked "
                        "unchecked return throw new case default when delegate nameof typeof sizeof".split())
_EXIT = re.compile(r"\b(?:goto|return|throw|break|continue)\b")
_LABEL = re.compile(r"^\s*(?!case\b|default\b)[A-Za-z_]\w*\s*:(?!:)")
_OBJECT_METHODS = frozenset({"ToString", "Equals", "GetType", "GetHashCode"})
_COMPOUND_START = re.compile(r"(?:if|for|foreach|while|do|switch|try|using|lock|else|fixed|unsafe|checked|unchecked|"
                             r"case|default|return|throw|yield|goto|break|continue)\b")
_NULL_COND = re.compile(r"(?:([A-Za-z_]\w*)\s*==\s*null|([A-Za-z_]\w*)\s+is\s+null|null\s*==\s*([A-Za-z_]\w*))")
_NOT_A_TYPE = r"(?!(?:return|new|else|throw|in|is|as|await|yield|case|goto|out|ref|using)\b)"


def _method_bodies(code: str):
    """(params, open, close) of every method, constructor or local function body (a brace block whose header is a
    call-shaped declaration, not control flow, a lambda, an initializer or a type)."""
    out = []
    for o, c in _blocks(code):
        start = max(code.rfind(";", 0, o), code.rfind("{", 0, o), code.rfind("}", 0, o)) + 1
        head = code[start:o].strip()
        while head.startswith("["):
            k = _match_close(head, 0, "[", "]")
            if k < 0:
                break
            head = head[k + 1:].lstrip()
        p = head.find("(")
        if p <= 0 or "=>" in head or "=" in head[:p]:
            continue
        q = _match_close(head, p, "(", ")")
        if q < 0 or not re.match(r"^\s*(?::\s*(?:base|this)\s*\(.*\)\s*)?(?:where\b.*)?$", head[q + 1:], re.S):
            continue
        m = re.search(r"([A-Za-z_]\w*)\s*(?:<[^()]*>)?\s*$", head[:p])
        if not m or m.group(1) in _CTRL_WORDS or re.search(r"\bnew\b", head[:p]):
            continue
        out.append((head[p + 1:q], o, c))
    return out


def _innermost(methods, offset):
    best = None
    for m in methods:
        if m[1] < offset < m[2] and (best is None or m[1] > best[1]):
            best = m
    return best


def _split_top(text: str, sep: str) -> list:
    out, depth, cur = [], 0, []
    for ch in text:
        if ch in "([{<":
            depth += 1
        elif ch in ")]}>":
            depth -= 1
        if ch == sep and depth <= 0:
            out.append("".join(cur))
            cur = []
        else:
            cur.append(ch)
    out.append("".join(cur))
    return out


def _declared(name: str, params: str, body: str) -> bool:
    """``name`` is a parameter or a local of the method whose parameter list and body text are given."""
    for part in _split_top(params, ","):
        part = re.sub(r"^\s*(?:\[[^\]]*\]\s*)*(?:(?:ref|out|in|params|this)\s+)*", "", part)
        part = part.split("=", 1)[0].strip()
        m = re.search(r"\s([A-Za-z_]\w*)$", part)
        if m and m.group(1) == name:
            return True
    return bool(re.search(
        rf"(?<![\w.]){_NOT_A_TYPE}[A-Za-z_][\w.]*(?:<[^<>;(){{}}]*>)?(?:\[[,\s]*\])*\??\s+{re.escape(name)}\s*"
        rf"(?:=(?!=)|;|,|\)|\bin\b)", body))


def _items(code: str, o: int, c: int):
    """Statements directly in the block ``code[o] == '{'``..``code[c] == '}'`` as (start, end) offsets: a simple statement
    ends with ``;``; a compound one ends at its closing brace unless ``else``, ``catch``, ``finally`` or a ``do``'s
    ``while`` follows, or the brace belongs to an expression (an initializer followed by ``;``, ``,``, ``)`` or ``.``)."""
    out, j = [], o + 1
    while j < c:
        while j < c and code[j].isspace():
            j += 1
        if j >= c:
            break
        s, depth = j, 0
        while j < c:
            ch = code[j]
            if ch in "([":
                depth += 1
            elif ch in ")]":
                depth -= 1
            elif ch == "{":
                k = _match_close(code, j, "{", "}")
                if k < 0 or k > c:
                    j = c
                    break
                if depth > 0:
                    j = k + 1
                    continue
                tail = code[k + 1:c].lstrip()
                if (re.match(r"(?:else|catch|finally)\b", tail)
                        or (re.match(r"do\b", code[s:j]) and re.match(r"while\b", tail))
                        or tail[:1] in (";", ",", ")", ".")):
                    j = k + 1
                    continue
                j = k + 1
                break
            elif ch == ";" and depth <= 0:
                j += 1
                break
            j += 1
        out.append((s, min(j, c)))
    return out


def _var_use(name: str) -> dict:
    n = re.escape(name)
    return {
        "assign": re.compile(rf"(?<![\w.@]){n}\s*(?:=(?!=)|\+\+|--|\?\?=|[-+*/%&|^]=)|(?:\+\+|--)\s*{n}\b"
                             rf"|\b(?:out|ref)\s+(?:var\s+|[A-Za-z_][\w.<>\[\]?]*\s+)?{n}\b"),
        "tested": re.compile(rf"(?<![\w.@]){n}\s*(?:==|!=|\?\.|\?\?|\?\[)|(?:==|!=)\s*{n}\b"
                             rf"|(?<![\w.@]){n}\s+(?:is|as)\b"),
        "deref": re.compile(rf"(?<![\w.@$]){n}\s*(?:\[|\.\s*([A-Za-z_]\w*))"),
    }


def _first_deref(stmt: str, use: dict):
    """Offset in ``stmt`` of the first sound dereference of the variable: ``x.Prop``, ``x.Field``, ``x[...]`` or a call of
    ``ToString|Equals|GetType|GetHashCode`` (any other call may be an extension method, which is legal on null)."""
    if "=>" in stmt or re.search(r"\b(?:nameof|typeof|sizeof|delegate)\b", stmt) or use["tested"].search(stmt):
        return None
    for m in use["deref"].finditer(stmt):
        member = m.group(1)
        if member:
            tail = stmt[m.end():]
            if re.match(r"\s*(?:<[\w\s,.<>?\[\]]*>\s*)?\(", tail) and member not in _OBJECT_METHODS:
                continue
        return m.start()
    return None


def _null_ifs(code: str, items):
    """(index, variable, offset of the condition's closing paren) of every item that is ``if (x == null)``,
    ``if (x is null)`` or ``if (null == x)`` and nothing else."""
    for idx, (s, e) in enumerate(items):
        m = re.match(r"if\s*\(", code[s:e])
        if not m:
            continue
        p = s + m.end() - 1
        q = _match_close(code, p, "(", ")")
        if q < 0 or q >= e:
            continue
        cond = _NULL_COND.fullmatch(code[p + 1:q].strip())
        if cond:
            yield idx, next(g for g in cond.groups() if g), q


def _is_dead_item(text: str) -> bool:
    return bool(_EXIT.search(text) or _LABEL.match(text))


def _simple(text: str) -> bool:
    return "{" not in text and not _COMPOUND_START.match(text) and text.rstrip().endswith(";")


def _null_patterns(ctx: _Ctx):
    code = _cs_code(ctx.text)
    methods = _method_bodies(code)
    for o, c in _blocks(code):
        items = _items(code, o, c)
        if not items:
            continue
        method = _innermost(methods, o + 1)
        if method is None:
            continue
        params, mo, mc = method
        body = code[mo:mc]
        for j, x, cond_end in _null_ifs(code, items):
            if not _declared(x, params, body):
                continue
            use = _var_use(x)
            # deref-before-null-check: the clean run of statements just before the check
            lo = j
            while lo > 0:
                text = code[items[lo - 1][0]:items[lo - 1][1]]
                if use["assign"].search(text) or _is_dead_item(text):
                    break
                lo -= 1
            for i in range(lo, j):
                s, e = items[i]
                text = code[s:e]
                off = _first_deref(text, use) if _simple(text) else None
                if off is not None:
                    yield _hit("deref-before-null-check", ctx.line(s + off),
                               f"a member of a local is accessed on line {ctx.line(s + off)} before its null check on "
                               f"line {ctx.line(items[j][0])} (no assignment between)")
                    break
            # deref-in-null-branch: a direct statement of the branch that runs when x is null
            s, e = items[j]
            rest = cond_end + 1
            while rest < e and code[rest].isspace():
                rest += 1
            if rest >= e:
                continue
            if code[rest] == "{":
                close = _match_close(code, rest, "{", "}")
                branch = _items(code, rest, close) if close > 0 else []
            else:
                branch = [(rest, e)]
            for a, b in branch:
                text = code[a:b]
                if use["assign"].search(text) or _is_dead_item(text):
                    break
                off = _first_deref(text, use) if _simple(text) else None
                if off is not None:
                    yield _hit("deref-in-null-branch", ctx.line(a + off),
                               f"a member of a local is accessed on line {ctx.line(a + off)} inside the branch that "
                               f"runs when it is null (check on line {ctx.line(s)})")
                    break


_LOG_USING = re.compile(r"(?m)^\s*using\s+(?:log4net|NLog|Common\.Logging)\b")
_LOG_FQ = re.compile(r"\b(?:log4net|NLog|Common\.Logging)\s*\.\s*LogManager\b")
_LOG_TYPE_DECL = re.compile(r"\b(?:class|interface|struct|enum|record)\s+(?:LogManager|ILog|Logger)\b")
_LOG_FACTORY = (r"(?:(?:log4net|NLog|Common\.Logging)\s*\.\s*|(?<![\w.]))LogManager\s*\.\s*"
                r"(?:GetLogger|GetCurrentClassLogger)\s*\(")
_LOG_TYPES = r"(?:log4net\s*\.\s*|NLog\s*\.\s*|Common\.Logging\s*\.\s*)?(?:ILog|Logger)"
_LOG_DECL = re.compile(rf"(?<![\w.])((?:private\s+(?:static\s+)?readonly\s+(?:static\s+)?)?){_LOG_TYPES}\s+"
                       rf"([A-Za-z_]\w*)\s*=\s*{_LOG_FACTORY}")


def _dead_null_fallback(ctx: _Ctx):
    """``ILog log = LogManager.GetLogger(...)`` is never null, so ``if (log == null) { fallback }`` cannot run. Sound only
    for the unqualified factory call on the logging library's ``LogManager`` (not an instance, not an extension method),
    an explicitly typed local or a ``private`` ``readonly`` field whose only assignment is that call, the library
    imported by ``using`` or used fully qualified, and no type of this file named ``LogManager``, ``ILog`` or ``Logger``."""
    code = _cs_code(ctx.text)
    if not (_LOG_USING.search(code) or _LOG_FQ.search(code)) or _LOG_TYPE_DECL.search(code):
        return
    methods = _method_bodies(code)
    blocks = _blocks(code)
    for d in _LOG_DECL.finditer(code):
        readonly, name = d.group(1).strip() != "", d.group(2)
        method = _innermost(methods, d.start())
        if method is None:
            if not readonly:
                continue            # a field that is not readonly may be assigned from anywhere
            scope = (0, len(code))
        else:
            if readonly:
                continue
            scope = (method[1], method[2])
        text = code[scope[0]:scope[1]]
        use = _var_use(name)
        if len(use["assign"].findall(text)) != 1:
            continue
        for o, c in blocks:
            if not (scope[0] <= o < scope[1]):
                continue
            items = _items(code, o, c)
            for j, x, _q in _null_ifs(code, items):
                if x == name:
                    yield _hit("dead-null-fallback", ctx.line(items[j][0]),
                               "the null branch cannot run: no assignment in this file gives the variable a null value")


# ---------------------------------------------------------------------------
# 10. hardcoded-production-mode (.cs, joined to the project's output type in apply)
# ---------------------------------------------------------------------------

_MAIN = re.compile(r"\bstatic\s+(?:async\s+)?(?:void|int|Task(?:\s*<\s*int\s*>)?)\s+Main\s*\(")
_MODE_ASSIGN = re.compile(r"(?<![\w.])(?:[A-Za-z_]\w*\s*\.\s*)*(\w*[Mm]ode\w*)\s*(?<![=!<>])=(?!=)\s*"
                          r"[A-Za-z_][\w.]*\s*\.\s*Production\s*(?=[;,})])")


def _production_mode(ctx: _Ctx):
    """A mode property or field assigned an enum member named ``Production`` in the file that holds ``Main``. Emitted for
    every such file; ``apply`` keeps it only for a project whose output type is ``Exe`` or ``WinExe``."""
    code = _cs_code(ctx.text)
    if not _MAIN.search(code):
        return
    for m in _MODE_ASSIGN.finditer(code):
        yield _hit("hardcoded-production-mode", ctx.line(m.start()),
                   "a mode is assigned the Production member in the file that holds Main: the application starts "
                   "in production mode whatever the configuration says")


_IF_DEBUG = re.compile(r"(?m)^[ \t]*#[ \t]*if[ \t]+\(?[ \t]*DEBUG[ \t]*\)?[ \t]*$")
_IF_END = re.compile(r"(?m)^[ \t]*#[ \t]*(?:else|elif|endif)\b")
_CONTROLLER_CLASS = re.compile(r"\bclass\s+\w+\s*:\s*[^{;]*\bController\b")
_LOCAL_ASSIGN = re.compile(r"(?m)^[ \t]*(?:(?:var|[A-Za-z_][\w.<>,\[\]?]*)[ \t]+)?[A-Za-z_]\w*[ \t]*=(?!=)[^;\n]*;")


def _debug_block(ctx: _Ctx):
    """A ``#if DEBUG`` block that assigns a local in a file that holds a controller (summary-only). The compile-time
    symbol is defined by some configurations only (the summary names them); a guard decision that differs between
    builds is easy to miss in review."""
    if "DEBUG" not in ctx.text:
        return
    code = _cs_code(ctx.text)
    if not _CONTROLLER_CLASS.search(code):
        return
    for m in _IF_DEBUG.finditer(code):
        end = _IF_END.search(code, m.end())
        body = code[m.end():end.start() if end else len(code)]
        if _LOCAL_ASSIGN.search(body):
            yield _hit("debug-block-assigns-local", ctx.line(m.start()),
                       "a block compiled only when a build symbol is defined assigns a local in a file that holds "
                       "handlers", symbols=["DEBUG"])


def _classic_net(ctx: _Ctx, handler):
    """Run a .NET Framework text pattern only for files a classic ASP.NET Stack owns (the pattern is specified on that
    shape; the public .NET Core examples stay unchanged)."""
    return handler(ctx) if "aspnet" in ctx.stacks else ()


# ---------------------------------------------------------------------------
# Dispatch
# ---------------------------------------------------------------------------

_BY_EXT = {
    ".cs": (_logger_mismatch, lambda c: _distinct_auth(c, "c"), lambda c: _unescaped_razor(c, "c"),
            _state_aspnet, lambda c: _credentials(c, "cs"), lambda c: _classic_net(c, _null_patterns),
            lambda c: _classic_net(c, _dead_null_fallback), _production_mode,
            lambda c: _classic_net(c, _debug_block)),
    ".config": (_duplicate_keys,),
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
    ctx = _Ctx(path, text, stacks)
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


# ---------------------------------------------------------------------------
# Facts-level pass (plan 2.8 W11 part A)
# ---------------------------------------------------------------------------

_DEBUG_SETTINGS = {"system.web/compilation@debug": "true", "system.web/customErrors@mode": "off"}
_JOINED_PATTERNS = frozenset({"hardcoded-production-mode"})   # found in text, confirmed against project Facts


def _source(f: Fact) -> tuple:
    return (f.path, f.line or 0, f.kind, f.name)


def _norm_attr(name: str) -> str:
    n = name.strip().rsplit(".", 1)[-1].lower()
    return n[:-9] if n.endswith("attribute") and len(n) > 9 else n


def _handlers(facts):
    """``(entry_point, detail)`` of every live action of the classic ASP.NET Stack that W4 evaluated, one per line."""
    seen, out = set(), []
    for f in facts:
        if f.kind != "entry_point" or f.stack != "aspnet" or is_test_path(f.path):
            continue
        d = f.detail_dict()
        if d.get("test") or d.get("type") != "route" or "reach" not in d or (f.path, f.line) in seen:
            continue
        seen.add((f.path, f.line))
        out.append((f, d))
    return out


def _handler_patterns(facts, add) -> None:
    """``handler-without-guard`` and ``state-change-authenticated-only`` (heuristics, plan 2.8 W11): both read the
    reach label W4 computed for the production configuration; both need a handler that changes state and writes."""
    handlers = _handlers(facts)
    role_by_area: dict = {}
    for f, d in handlers:
        if d.get("reach") == "role_restricted":
            role_by_area.setdefault(str(d.get("mvc_area") or "").lower(), []).append(str(d.get("handler") or "").split(".")[0])
    for f, d in handlers:
        if d.get("state_changing") != "true" or d.get("writes") is not True:
            continue
        reasons = {"reasons": list(d["reasons"])} if d.get("reasons") else {}
        if d.get("reach") == "no_app_restriction" and d.get("reach_anon") == "allow":
            add("handler-without-guard", f, "a handler that changes state has no application-layer restriction",
                [_source(f)], writes=True, **reasons)
        elif d.get("reach") == "signed_in_any":
            own = str(d.get("handler") or "").split(".")[0]
            siblings = [c for c in role_by_area.get(str(d.get("mvc_area") or "").lower(), []) if c != own]
            if siblings:
                add("state-change-authenticated-only", f,
                    "a handler that changes state is open to any signed-in user while a sibling controller in the "
                    "same area is restricted to roles", [_source(f)], count=len(siblings), writes=True)


_MVC_BASES = frozenset({"Controller", "AsyncController"})


def _antiforgery(facts, add) -> None:
    """``post-without-antiforgery``: one Target-level hit, anchored on the first affected controller class line, with a
    per-controller table ``path:line N of M``. A POST is protected by an own, class-level or inherited
    ``[ValidateAntiForgeryToken]`` (``antiforgery_check``), an in-body ``AntiForgery.Validate``, a Target attribute class
    that calls it (used on the action, a class of its chain, or added as a global filter) or a global
    ``ValidateAntiForgeryToken`` filter. ``ApiController`` and Web Forms are out of scope and a chain with an unresolved
    external base gives no hit (R20: an absence claim needs a closed world)."""
    live = [f for f in facts if not is_test_path(f.path) and not f.detail_dict().get("test")]
    classes: dict = {}                       # (path, name) -> controller_class Fact
    by_name: dict = {}
    for f in live:
        if f.kind == "controller_class" and f.stack == "aspnet":
            classes[(f.path, f.name)] = f
            by_name.setdefault(f.name, []).append(f.path)
    validators = {_norm_attr(f.name) for f in live if f.kind == "antiforgery_check"
                  and f.detail_dict().get("scope") == "validator"}
    global_on = any(f.kind == "antiforgery_check" and f.detail_dict().get("scope") == "global" for f in live) or any(
        f.kind == "auth_check" and f.detail_dict().get("mechanism") == "global-filter"
        and not f.detail_dict().get("api_pipeline") and _norm_attr(f.name) in validators for f in live)
    class_checks = {(f.path, f.detail_dict().get("applies_to")) for f in live
                    if f.kind == "antiforgery_check" and f.detail_dict().get("scope") == "class"}
    line_checks = {(f.path, f.line) for f in live if f.kind == "antiforgery_check"
                   and f.detail_dict().get("scope") in ("method", "body")}
    uses: dict = {}
    for f in live:
        if f.kind == "guard_use" and _norm_attr(f.name) in validators:
            uses.setdefault((f.path, f.detail_dict().get("applies_to")), []).append(f)

    def chain(path, name):
        out, seen, todo = [], set(), [(path, name)]
        while todo:
            key = todo.pop(0)
            if key in seen or key not in classes:
                continue
            seen.add(key)
            out.append(key)
            for b in classes[key].detail_dict().get("base_list", []):
                todo.extend((p, b) for p in by_name.get(b, []))
        return out

    table: dict = {}                         # (path, class) -> [unprotected, total]
    for f, d in _handlers(facts):
        if d.get("state_changing") != "true" or "POST" not in (d.get("verbs") or []) or d.get("http_route"):
            continue
        cls = str(d.get("handler") or "").split(".")[0]
        ch = chain(f.path, cls)
        if not ch or (f.path, cls) not in classes:
            continue
        bases = {b for k in ch for b in classes[k].detail_dict().get("base_list", [])}
        if any(classes[k].detail_dict().get("base_external") for k in ch) or d.get("base_external") \
                or "ApiController" in bases or not bases & _MVC_BASES:
            continue
        protected = (global_on or (f.path, f.line) in line_checks
                     or any(k in class_checks for k in ch)
                     or (f.path, d.get("handler")) in uses
                     or any(k in uses for k in ch))
        row = table.setdefault((f.path, cls), [0, 0])
        row[1] += 1
        row[0] += 0 if protected else 1
    exposed = sorted((k for k, (n, _m) in table.items() if n), key=lambda k: (k[0], classes[k].line or 0, k[1]))
    if not exposed:
        return
    anchor = classes[exposed[0]]
    add("post-without-antiforgery", anchor,
        "state-changing POST actions have no anti-forgery token validation (the per-controller table lists them)",
        [_source(classes[k]) for k in exposed],
        unprotected=sum(table[k][0] for k in exposed), total=sum(m for _n, m in table.values()),
        controllers=[f"{k[0]}:{classes[k].line} {table[k][0]} of {table[k][1]}" for k in exposed])


def from_facts(facts) -> list:
    """The smell Facts that follow from other Facts alone (no file is read, no clock, no ordering dependence).

    ``fid = fact_id("smell", pattern, path, line)``; ``sources`` are ``(path, line, kind, name)`` tuples of the Facts the
    hit rests on. A message never echoes a name or a value (R18, R19); counts and configuration names are details.
    """
    facts = sorted(facts, key=lambda f: f.sort_key())
    out: dict = {}

    def add(pattern, anchor: Fact, name, sources, **detail):
        key = (pattern, anchor.path, anchor.line)
        if key in out:
            return
        f = Fact.make("smell", anchor.stack, anchor.path, anchor.line, name, pattern=pattern,
                      fid=fact_id("smell", pattern, anchor.path, anchor.line), sources=sorted(set(sources)), **detail)
        if is_test_path(anchor.path) or anchor.detail_dict().get("test"):
            f = f.as_test()
        out[key] = f

    settings: dict = {}
    for f in facts:
        d = f.detail_dict()
        if f.kind == "security_setting":
            if f.name.endswith("/machineKey") and d.get("value") == "literal_hex":
                add("machinekey-in-config", f, "literal cryptographic key material is kept in configuration",
                    [_source(f)])
            if f.name in _DEBUG_SETTINGS:
                settings.setdefault((f.path, f.name), []).append((f, d))
        elif f.kind == "access_rule" and d.get("users_named", 0) > 0:
            add("named-user-access-rule", f, "an access rule names individual users instead of roles", [_source(f)],
                count=int(d["users_named"]))
        elif f.kind == "config_key" and d.get("list_count", 0) >= 3:
            add("identifier-list-in-config", f,
                f"an appSettings value is a list of {int(d['list_count'])} identifiers kept in configuration",
                [_source(f)], count=int(d["list_count"]), **({"overridden_in": d["overridden_in"]}
                                                            if d.get("overridden_in") else {}))

    for (path, name), group in sorted(settings.items()):
        named = [(f, d) for f, d in group if d.get("config") != "base"]
        evaluable = named or group          # a configuration without a transform inherits the base (R17)
        bad = _DEBUG_SETTINGS[name]
        flagged = [(f, d) for f, d in evaluable
                   if d.get("value") == bad and d.get("config_status") in ("base", "transformed")]
        nondebug = [(f, d) for f, d in flagged if str(d.get("config", "")).lower() != "debug"]
        debug = [(f, d) for f, d in flagged if str(d.get("config", "")).lower() == "debug"]
        if nondebug:
            anchor = min((f for f, _ in nondebug), key=lambda f: f.line or 0)
            add("debug-setting-in-nondebug-config", anchor,
                "a debug-time setting is on in the effective configuration of a build configuration that is not Debug",
                [_source(f) for f, _ in nondebug], configs=sorted({str(d.get("config")) for _, d in nondebug}))
        if debug:
            anchor = min((f for f, _ in debug), key=lambda f: f.line or 0)
            add("debug-setting-in-debug-config", anchor,
                "a debug-time setting is on in the Debug build configuration (listed for completeness)",
                [_source(f) for f, _ in debug], configs=["Debug"])

    year = next((int(f.detail_dict()["value"]) for f in facts
                 if f.kind == "context_directive" and f.detail_dict().get("directive") == "reference_year"
                 and re.fullmatch(r"\d{4}", str(f.detail_dict().get("value", "")))), None)
    if year is not None:
        for f in facts:
            y = f.detail_dict().get("year") if f.kind == "config_key" else None
            if y and abs(int(y) - year) <= 1:
                add("config-year-horizon", f,
                    "a configuration value is a year within one year of the declared reference year; if it is a "
                    "limit, confirm with the owner", [_source(f)])

    _handler_patterns(facts, add)
    _antiforgery(facts, add)

    projects = sorted(((f.path.rsplit("/", 1)[0] if "/" in f.path else "", f.detail_dict()) for f in facts
                       if f.kind == "project" and f.detail_dict().get("kind") != "solution"),
                      key=lambda t: -len(t[0]))
    for f in facts:
        if f.kind == "smell" and f.detail_dict().get("pattern") == "hardcoded-production-mode":
            proj = next((d for folder, d in projects if folder == "" or f.path.startswith(folder + "/")), None)
            if proj and proj.get("kind") in ("winforms", "console") and not proj.get("test") \
                    and proj.get("output_type") in ("winexe", "exe"):
                out.setdefault(("hardcoded-production-mode", f.path, f.line), f)
    return sorted(out.values(), key=lambda f: f.sort_key())


def apply(facts: list) -> list:
    """``facts`` with the Facts-level smells added. The provisional text hits of ``_JOINED_PATTERNS`` are replaced by the
    ones ``from_facts`` confirms (a project that is not an ``Exe`` or ``WinExe`` project drops them)."""
    new = from_facts(facts)
    kept = [f for f in facts if not (f.kind == "smell" and f.detail_dict().get("pattern") in _JOINED_PATTERNS)]
    return kept + new
