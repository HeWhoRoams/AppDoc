"""Classic ASP / VBScript Stack (``*.asp``, ``*.inc``, ``*.asa``).

Regex based. VBScript string literals (with ``""`` escapes and ``&`` / `` _`` concatenation)
are parsed by a small tokenizer so SQL and messages are read from the real literal text.
No secret value is ever recorded: connection facts only carry ``secret_location``.
"""

from __future__ import annotations

import re
from typing import Iterable

from ..facts import Fact
from .base import Stack, line_of
from ..secrets import find_secret_shapes

ID = "classic-asp"

# ---------------------------------------------------------------------------
# Source preparation (comment-aware; line numbers are preserved)
# ---------------------------------------------------------------------------

_SEG_RE = re.compile(r"<%(=?)(.*?)(?:%>|\Z)", re.S)
_HTML_COMMENT_RE = re.compile(r"<!--.*?-->", re.S)
_INCLUDE_RE = re.compile(
    r"""<!--\s*\#\s*include\s+(file|virtual)\s*=\s*["']([^"']+)["']\s*-->""", re.I)


def _blank(s: str) -> str:
    return re.sub(r"[^\n]", " ", s)


def _strip_line_comments(code: str) -> str:
    """Blank VBScript ' and REM comments inside one code block (quote aware)."""
    out = []
    for line in code.split("\n"):
        i, n, instr = 0, len(line), False
        cut = None
        while i < n:
            ch = line[i]
            if instr:
                if ch == '"':
                    if i + 1 < n and line[i + 1] == '"':
                        i += 1
                    else:
                        instr = False
            elif ch == '"':
                instr = True
            elif ch == "'":
                cut = i
                break
            elif (ch in "rR" and re.match(r"rem\b", line[i:i + 4], re.I)
                  and re.fullmatch(r"[\s:]*", line[:i] or "")):
                cut = i
                break
            i += 1
        out.append(line if cut is None else line[:cut] + " " * (n - cut))
    return "\n".join(out)


def prepare(text: str) -> tuple[str, str]:
    """Return (code_view, include_view), both the same length/line layout as ``text``.

    code_view: HTML blanked, ``<% %>`` markers replaced by statement separators, comments blanked.
    include_view: text where HTML comments other than #include directives and VBScript
    comments are blanked (so commented-out includes yield nothing).
    """
    code_parts, inc_parts = [], []
    pos = 0

    def html(seg: str) -> str:
        return _HTML_COMMENT_RE.sub(
            lambda m: m.group(0) if _INCLUDE_RE.fullmatch(m.group(0)) else _blank(m.group(0)), seg)

    for m in _SEG_RE.finditer(text):
        if m.start() > pos:
            seg = text[pos:m.start()]
            code_parts.append(_blank(seg))
            inc_parts.append(html(seg))
        body = _strip_line_comments(m.group(2))
        raw = m.group(0)
        end = "%>" if raw.endswith("%>") else ""
        code_parts.append(" " * (2 + len(m.group(1))) + body + (" :" if end else ""))
        inc_parts.append(" " * (2 + len(m.group(1))) + body + ("  " if end else ""))
        pos = m.end()
    if pos < len(text):
        seg = text[pos:]
        code_parts.append(_blank(seg))
        inc_parts.append(html(seg))
    return "".join(code_parts), "".join(inc_parts)


# ---------------------------------------------------------------------------
# Statements and string literals
# ---------------------------------------------------------------------------

def _mask(s: str) -> str:
    """Replace string literal contents with 'x' (same length) so regexes ignore them."""
    out, i, n, instr = [], 0, len(s), False
    while i < n:
        ch = s[i]
        if instr:
            if ch == '"':
                if i + 1 < n and s[i + 1] == '"':
                    out.append("xx")
                    i += 2
                    continue
                instr = False
                out.append('"')
            else:
                out.append("x")
        else:
            if ch == '"':
                instr = True
            out.append(ch)
        i += 1
    return "".join(out)


def statements(code: str) -> list[tuple[int, str]]:
    """Logical VBScript statements as (1-based line, text): joins `` _`` continuations, splits on ':'."""
    lines = code.split("\n")
    out: list[tuple[int, str]] = []
    i = 0
    while i < len(lines):
        start = i
        buf = lines[i]
        while re.search(r"\s_\s*$", _mask(buf)) and i + 1 < len(lines):
            buf = re.sub(r"\s_\s*$", " ", buf) + lines[i + 1]
            i += 1
        i += 1
        masked = _mask(buf)
        last = 0
        for m in re.finditer(":", masked):
            out.append((start + 1, buf[last:m.start()]))
            last = m.end()
        out.append((start + 1, buf[last:]))
    return [(ln, s.strip()) for ln, s in out if s.strip()]


def _read_string(s: str, i: int) -> tuple[str, int]:
    """s[i] is an opening quote. Return (unescaped value, index after closing quote)."""
    buf, i, n = [], i + 1, len(s)
    while i < n:
        if s[i] == '"':
            if i + 1 < n and s[i + 1] == '"':
                buf.append('"')
                i += 2
                continue
            return "".join(buf), i + 1
        buf.append(s[i])
        i += 1
    return "".join(buf), i


def _read_operand(s: str, i: int) -> int:
    """Skip a non-literal operand (identifier / call with balanced parens); return end index."""
    n = len(s)
    depth = 0
    while i < n:
        ch = s[i]
        if ch == '"':
            _, i = _read_string(s, i)
            continue
        if ch == "(":
            depth += 1
        elif ch == ")":
            if depth == 0:
                return i
            depth -= 1
        elif depth == 0 and (ch in "&," or ch.isspace()):
            if ch.isspace() and re.match(r"\s*\(", s[i:]):
                i += 1
                continue
            return i
        i += 1
    return i


def chains(stmt: str) -> list[tuple[str, str, int]]:
    """Find ``"lit" & x & "lit"`` chains that start with a string literal.

    Returns (joined text with '?' for variable parts, literal parts only, start offset).
    """
    res = []
    i, n = 0, len(stmt)
    amp = re.compile(r"\s*&\s*")
    while i < n:
        if stmt[i] != '"':
            i += 1
            continue
        offset = i
        joined, lits = [], []
        while True:
            val, i = _read_string(stmt, i)
            joined.append(val)
            lits.append(val)
            more = False
            while True:
                m = amp.match(stmt, i)
                if not m:
                    break
                j = m.end()
                if j < n and stmt[j] == '"':
                    i, more = j, True
                    break
                k = _read_operand(stmt, j)
                if k == j:
                    break
                joined.append("?")
                i = k
            if not more:
                break
        res.append(("".join(joined), "".join(lits), offset))
    return res


# ---------------------------------------------------------------------------
# Patterns
# ---------------------------------------------------------------------------

_IDENT = r"[\w.\[\]#$]+"
_SQL_START = re.compile(r"^\s*(SELECT|INSERT|UPDATE|DELETE)\b", re.I)
_EXEC_RE = re.compile(r"^\s*EXEC(?:UTE)?\s+(" + _IDENT + ")", re.I)
_CALL_RE = re.compile(r"^\s*\{\s*(?:\?\s*=\s*)?call\s+(" + _IDENT + ")", re.I)
_REQ_RE = re.compile(
    r"""\bRequest\s*(?:\.\s*(?:Form|QueryString|ServerVariables|Cookies)\s*)?\(\s*"([^"]+)"\s*\)""", re.I)
_CREATE_RE = re.compile(r"""\b(?:Server\.|WScript\.)?CreateObject\s*\(?\s*"([^"]+)"\s*\)?""", re.I)
_SET_CREATE_RE = re.compile(
    r"""^Set\s+(\w+)\s*=\s*(?:Server\.|WScript\.)?CreateObject\s*\(?\s*"([^"]+)"\s*\)?""", re.I)
_CONN_STRING_RE = re.compile(r"(?i)\b(Provider|Driver|DSN|Data Source|Server|Dbq)\s*=")
_SECRET_PARTS_RE = re.compile(r"(?i)(?:\bpassword|\bpwd|\buser\s*id|\buid)\s*=")
_ERR_WORDS_RE = re.compile(
    r"(?i)\b(error|invalid|not found|denied|must|failed|failure|required|unauthori[sz]ed|cannot|not allowed)\b")
_VALIDATION_RE = re.compile(r"(?i)\b(invalid|must|required|please (?:enter|select|provide|supply))\b")
_ROLE_KEY_RE = re.compile(r"(?i)role|group|level|admin|priv|perm|access|type")

_HTTP_PROGIDS = ("msxml2.serverxmlhttp", "msxml2.xmlhttp", "microsoft.xmlhttp", "winhttp.winhttprequest")


def _progid_type(progid: str) -> str:
    p = progid.lower()
    if p.startswith(_HTTP_PROGIDS) or p.startswith("msxml2.serverxmlhttp"):
        return "http"
    if p.startswith("cdo.message") or p.startswith("cdonts.newmail"):
        return "email"
    if p.startswith("scripting.filesystemobject"):
        return "file"
    if p.startswith("wscript.shell"):
        return "process"
    return "com"


def _table(joined: str, op: str) -> str:
    rx = {
        "select": r"\bFROM\s+(" + _IDENT + ")",
        "delete": r"\bFROM\s+(" + _IDENT + ")",
        "insert": r"\bINTO\s+(" + _IDENT + ")",
        "update": r"^\s*UPDATE\s+(" + _IDENT + ")",
    }[op]
    m = re.search(rx, joined, re.I)
    return m.group(1).replace("[", "").replace("]", "") if m else "(unknown)"


def _clean_message(lits: str) -> str:
    s = re.sub(r"<!--|-->", " ", lits)
    s = re.sub(r"<[^>]*>", " ", s)
    s = re.sub(r"&nbsp;", " ", s)
    s = re.sub(r"\s+", " ", s).strip()
    return s[:200]


def _safe(text: str) -> bool:
    return not find_secret_shapes(text)


# ---------------------------------------------------------------------------
# The Stack
# ---------------------------------------------------------------------------

class ClassicAsp(Stack):
    id = ID
    extensions = frozenset({".asp", ".inc", ".asa"})

    def detect(self, files: list[str]) -> list[str]:
        out = []
        for f in files:
            base = f.rsplit("/", 1)[-1].lower()
            if base.endswith(".asp") or base == "global.asa":
                out.append(f)
        return sorted(out)

    def extract(self, path: str, text: str) -> Iterable[Fact]:
        facts: list[Fact] = []
        add = facts.append
        code, inc_view = prepare(text)
        is_page = path.lower().endswith(".asp")

        # --- includes -------------------------------------------------------
        for m in _INCLUDE_RE.finditer(inc_view):
            add(Fact.make("dependency", ID, path, line_of(inc_view, m.start()), m.group(2),
                          manager="include", mode=m.group(1).lower()))

        stmts = statements(code)

        # --- page entry point ----------------------------------------------
        if is_page:
            inputs = sorted({m.group(1) for m in _REQ_RE.finditer(code)})
            add(Fact.make("entry_point", ID, path, 1, path, type="page", inputs=inputs))

        # --- per-file context ----------------------------------------------
        conn_vars = set()
        stored_proc_type = bool(re.search(r"(?i)\bCommandType\s*=\s*(?:4\b|adCmdStoredProc\b)", code))
        for _, s in stmts:
            m = _SET_CREATE_RE.match(s)
            if m and m.group(2).lower().startswith("adodb.connection"):
                conn_vars.add(m.group(1).lower())

        ifstack: list[dict] = []   # {"cond": str, "branch": "if"|"elseif"|"else"}

        def in_error_branch() -> bool:
            for e in ifstack:
                c = e["cond"]
                if not re.search(r"(?i)\bErr(?:\.Number)?\b", c):
                    continue
                ok = bool(re.search(r"(?i)=\s*0\b", c)) and not re.search(r"(?i)<>\s*0|>\s*0", c)
                if e["branch"] == "else":
                    if ok:
                        return True
                elif not ok:
                    return True
            return False

        def body_has_exit(idx: int) -> bool:
            """Does the If block that starts at stmts[idx] contain Response.Redirect/End?"""
            depth = 0
            for _, s in stmts[idx + 1:]:
                ms = _mask(s)
                if re.match(r"(?i)If\b.*\bThen$", ms):
                    depth += 1
                elif re.match(r"(?i)End\s+If\b", ms):
                    if depth == 0:
                        return False
                    depth -= 1
                elif depth == 0 and re.match(r"(?i)Else(?:If\b|$)", ms):
                    return False
                if re.match(r"(?i)Response\.(Redirect|End)\b", ms):
                    return True
            return False

        def handle_body(ln: int, s: str):
            ms = _mask(s)
            # --- Server.CreateObject ---
            for m in _CREATE_RE.finditer(s):
                prog = m.group(1)
                if prog.lower().startswith("adodb."):
                    continue
                add(Fact.make("external_call", ID, path, ln, prog, type=_progid_type(prog)))
            # --- connections ---
            m = re.match(r"(?i)(\w+)\s*\.\s*ConnectionString\s*=\s*(.*)$", s)
            if m:
                self_conn(ln, m.group(1), m.group(2))
            else:
                m = re.match(r"(?i)(\w+)\s*\.\s*Open\b\s*(.*)$", s)
                if m and (m.group(1).lower() in conn_vars
                          or re.fullmatch(r"(?i)(?:\w*conn\w*|cn|con|db\w*)", m.group(1))):
                    arg = m.group(2).strip()
                    if not arg or arg.startswith('"') or arg.startswith("("):
                        self_conn(ln, m.group(1), arg)
                    else:
                        add(Fact.make("connection", ID, path, ln, m.group(1), type="database",
                                      secret_location=False))
                else:
                    m = re.match(r"(?i)(\w+)\s*=\s*(.*)$", s)
                    if m:
                        ch = chains(m.group(2))
                        if ch and _CONN_STRING_RE.search(ch[0][1]):
                            self_conn(ln, m.group(1), m.group(2), force=True)
            # --- data access (literal chains) ---
            is_cmdtext = bool(re.match(r"(?i)\w+\s*\.\s*CommandText\s*=", s))
            for joined, lits, off in chains(s):
                sm = _SQL_START.match(joined)
                em = _EXEC_RE.match(joined)
                cm = _CALL_RE.match(joined)
                if em:
                    add(Fact.make("data_access", ID, path, ln, em.group(1), type="stored_procedure",
                                  operation="exec"))
                elif cm:
                    add(Fact.make("data_access", ID, path, ln, cm.group(1), type="stored_procedure",
                                  operation="call"))
                elif sm:
                    op = sm.group(1).lower()
                    add(Fact.make("data_access", ID, path, ln, _table(joined, op), type="sql",
                                  operation=op))
                elif is_cmdtext and re.fullmatch(r"\s*" + _IDENT + r"\s*", lits):
                    if stored_proc_type or "." in lits or lits.lower().startswith(("sp_", "usp_")):
                        add(Fact.make("data_access", ID, path, ln, lits.strip().replace("[", "").replace("]", ""),
                                      type="stored_procedure", operation="exec"))
            # --- messages ---
            if re.match(r"(?i)Response\s*\.\s*Write\b", ms) and ifstack:
                ch = chains(s)
                if ch:
                    lits = "".join(c[1] for c in ch)
                    msg = _clean_message(lits)
                    if re.search(r"[A-Za-z]{2}", msg) and _safe(msg):
                        err_branch = in_error_branch()
                        words = bool(_ERR_WORDS_RE.search(msg))
                        if err_branch or words:
                            ctx = "validation" if _VALIDATION_RE.search(msg) else "error"
                            add(Fact.make("message", ID, path, ln, msg, context=ctx))

        def self_conn(ln: int, var: str, rest: str, force: bool = False):
            ch = chains(rest) if rest else []
            lit = ch[0][1] if ch else ""
            secret = bool(_SECRET_PARTS_RE.search(lit))
            name = var if var else "ADODB.Connection"
            add(Fact.make("connection", ID, path, ln, name, type="database", secret_location=secret))

        def auth(ln: int, cond: str, exits: bool):
            if not exits or not re.search(r"(?i)\bSession\s*(?:\.Contents)?\s*\(", cond):
                return
            name = re.sub(r"\s+", " ", cond).strip()
            if len(name) > 120:
                name = name[:120]
            roles = []
            for key, lit in re.findall(r"""(?i)Session\s*\(\s*"([^"]+)"\s*\)\s*(?:<>|=)\s*"([^"]*)\"""", cond):
                if _ROLE_KEY_RE.search(key):
                    roles.append(lit)
            kw = {"mechanism": "session"}
            if roles:
                kw["roles"] = sorted(set(roles))
            if _safe(name):
                add(Fact.make("auth_check", ID, path, ln, name, **kw))

        for idx, (ln, s) in enumerate(stmts):
            ms = _mask(s)
            m = re.match(r"(?i)If\s+(.*?)\s+Then\b\s*(.*)$", ms)
            if m:
                cond = s[m.start(1):m.end(1)]
                rest = s[m.start(2):].strip() if m.group(2) else ""
                if rest:  # single-line If
                    ifstack.append({"cond": cond, "branch": "if"})
                    parts = re.split(r"(?i)\bElse\b", _mask(rest), maxsplit=1)
                    body = rest[:len(parts[0])].strip()
                    auth(ln, cond, bool(re.match(r"(?i)Response\.(Redirect|End)\b", _mask(body))))
                    handle_body(ln, body)
                    if len(parts) == 2:
                        ifstack[-1]["branch"] = "else"
                        handle_body(ln, rest[len(parts[0]) + 4:].strip())
                    ifstack.pop()
                else:
                    auth(ln, cond, body_has_exit(idx))
                    ifstack.append({"cond": cond, "branch": "if"})
                continue
            m = re.match(r"(?i)ElseIf\s+(.*?)\s+Then\b", ms)
            if m and ifstack:
                ifstack[-1] = {"cond": s[m.start(1):m.end(1)], "branch": "elseif"}
                continue
            if re.fullmatch(r"(?i)Else", ms) and ifstack:
                ifstack[-1]["branch"] = "else"
                continue
            if re.match(r"(?i)End\s+If\b", ms):
                if ifstack:
                    ifstack.pop()
                continue
            handle_body(ln, s)
        return facts


STACK = ClassicAsp()
