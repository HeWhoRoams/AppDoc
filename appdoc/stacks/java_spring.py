"""Java Spring Stack: Spring MVC/Boot, Struts, servlets, JPA/JDBC/MyBatis, Spring Security.

Reads code files only (.java, .jsp/.jspx, and Spring/Struts/MyBatis/web.xml mapping XML recognized by
content). Config files (application*.properties/.yml, pom.xml, build.gradle) belong to generic.py.
Regex based, comment-aware, with paren/brace-aware scanning where annotations span lines.
Never records a secret value: connection facts carry ``secret_location`` only.
"""

from __future__ import annotations

import re
from typing import Iterable

from ..facts import Fact
from ..secrets import find_secret_shapes, is_secret_key
from .base import Stack, line_of, strip_comments

STACK_ID = "java-spring"
_BUILD = ("pom.xml", "build.gradle", "build.gradle.kts")
_XMLISH = re.compile(r"(?i)(?:^|/)(?:applicationContext[^/]*\.xml|[^/]*-servlet\.xml|struts[^/]*\.xml|[^/]*\.jspx?)$")
_MAX_JSP_MARKERS = 20

# ------------------------------------------------------------------ literals and scanning helpers

_STR = r'"""[\s\S]*?"""|"(?:[^"\\\n]|\\.)*"'
_CHAIN = rf"(?:{_STR})(?:\s*\+\s*(?:{_STR}))*"
_STR_RX = re.compile(_STR)
_TOKEN = re.compile(rf"//[^\n]*|/\*[\s\S]*?\*/|{_STR}|'(?:[^'\\\n]|\\.)+'")
_PLACEHOLDER = ""


def _blank(m) -> str:
    return re.sub(r"[^\n]", " ", m.group(0))


def _clean_java(text: str) -> str:
    """Strip comments with base.strip_comments, protecting '/' inside string literals ("/api/*")."""
    def mask(m):
        s = m.group(0)
        return s if s.startswith(("//", "/*")) else s.replace("/", _PLACEHOLDER)
    return strip_comments(_TOKEN.sub(mask, text), "c").replace(_PLACEHOLDER, "/")


def _code_only(clean: str) -> str:
    """Same length as clean, string/char literal contents blanked (structure scans)."""
    def b(m):
        s = m.group(0)
        if s.startswith(("//", "/*")) or len(s) < 2:
            return s
        return s[0] + re.sub(r"[^\n]", " ", s[1:-1]) + s[-1]
    return _TOKEN.sub(b, clean)


def _unq(s: str) -> str:
    s = s[3:-3] if s.startswith('"""') else s[1:-1]
    return s.replace('\\"', '"')


def _lits(chunk: str) -> str:
    return "".join(_unq(m.group(0)) for m in _STR_RX.finditer(chunk))


def _match_close(text: str, i: int, open_c: str, close_c: str, limit: int = 40000) -> int:
    """Index of the bracket closing text[i], skipping string literals; -1 if not found."""
    depth, n, j = 0, min(len(text), i + limit), i
    while j < n:
        c = text[j]
        if c == '"':
            if text.startswith('"""', j):
                k = text.find('"""', j + 3)
                j = (k + 3) if k >= 0 else n
                continue
            j += 1
            while j < n and text[j] != '"' and text[j] != "\n":
                j += 2 if text[j] == "\\" else 1
        elif c == "'":
            j += 1
            while j < n and text[j] != "'" and text[j] != "\n":
                j += 2 if text[j] == "\\" else 1
        elif c == open_c:
            depth += 1
        elif c == close_c:
            depth -= 1
            if depth == 0:
                return j
        j += 1
    return -1


def _match_paren(text: str, i: int) -> int:
    return _match_close(text, i, "(", ")")


def _match_brace(code: str, i: int) -> int:
    depth = 0
    for j in range(i, len(code)):
        c = code[j]
        if c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
            if depth == 0:
                return j
    return len(code)


def _split_top(s: str) -> list[str]:
    parts, depth, cur, j, n = [], 0, [], 0, len(s)
    while j < n:
        c = s[j]
        if c == '"':
            k = j + 1
            if s.startswith('"""', j):
                e = s.find('"""', j + 3)
                k = (e + 3) if e >= 0 else n
            else:
                while k < n and s[k] != '"' and s[k] != "\n":
                    k += 2 if s[k] == "\\" else 1
                k += 1
            cur.append(s[j:k])
            j = k
            continue
        if c in "([{":
            depth += 1
        elif c in ")]}":
            depth -= 1
        elif c == "," and depth == 0:
            parts.append("".join(cur))
            cur = []
            j += 1
            continue
        cur.append(c)
        j += 1
    if "".join(cur).strip():
        parts.append("".join(cur))
    return parts


def _attrmap(args: str | None) -> dict:
    d = {}
    for part in _split_top(args or ""):
        m = re.match(r"\s*([A-Za-z_]\w*)\s*=(?!=)\s*([\s\S]*)$", part)
        if m:
            d[m.group(1)] = m.group(2).strip()
        elif part.strip() and "value" not in d:
            d["value"] = part.strip()
    return d


def _elements(v: str | None) -> list[str]:
    """Literal elements of an annotation value: "x", {"a","b"}, BASE + "/x" (non-literals dropped)."""
    if not v:
        return []
    v = v.strip()
    if v.startswith("{") and v.endswith("}"):
        v = v[1:-1]
    return [_lits(item) for item in _split_top(v) if '"' in item]


def _first_lit(v: str | None) -> str | None:
    els = _elements(v)
    return els[0] if els else None


def _join(*parts: str) -> str:
    segs = [p.strip("/") for p in parts if p and p.strip("/")]
    return "/" + "/".join(segs) if segs else "/"


def _safe(s: str | None) -> str | None:
    """Return s unless it looks like it carries a secret."""
    if not s or find_secret_shapes(s) or re.search(r"(?i)(password|passwd|pwd|secret|token|apikey|api_key)\s*[=:]", s):
        return None
    return s


def _safe_url(s: str) -> str | None:
    s = re.sub(r"(?<=//)[^/@\s]*@", "", s).split("?", 1)[0].strip()
    return _safe(s)


def _f(kind, path, line, name, **detail) -> Fact:
    return Fact.make(kind, STACK_ID, path, line, name, **detail)


# ------------------------------------------------------------------ annotations

_ANN = re.compile(r"(?<![\w.])@([A-Za-z_]\w*(?:\.[A-Za-z_]\w*)*)")
_CLASS = re.compile(r"(?<![.\w@])(class|interface|enum)\s+([A-Za-z_]\w*)")
_CLASS_TARGET = re.compile(r"^\s*(?:(?:public|protected|private|abstract|final|static|sealed|strictfp)\s+)*(class|interface|enum)\s+([A-Za-z_]\w*)")
_METHOD_TARGET = re.compile(r"^[^;{}=]*?\b([A-Za-z_]\w*)\s*\(")


class _Ann:
    __slots__ = ("name", "args", "start", "end", "target", "cls", "method")


class _Cls:
    __slots__ = ("kw", "name", "kind", "body", "end", "anns")


def _scan_annotations(clean: str) -> list[_Ann]:
    out, pos = [], 0
    while True:
        m = _ANN.search(clean, pos)
        if not m:
            break
        name = m.group(1).rsplit(".", 1)[-1]
        end, args, j = m.end(), None, m.end()
        if name == "interface":
            pos = end
            continue
        while j < len(clean) and clean[j] in " \t\r\n":
            j += 1
        if j < len(clean) and clean[j] == "(":
            close = _match_paren(clean, j)
            if close > 0:
                args, end = clean[j + 1:close], close + 1
        a = _Ann()
        a.name, a.args, a.start, a.end = name, args, m.start(), end
        a.target = end
        a.cls = a.method = None
        out.append(a)
        pos = end
    for i in range(len(out) - 2, -1, -1):  # chained annotations share the final target
        if not clean[out[i].end:out[i + 1].start].strip():
            out[i].target = out[i + 1].target
    return out


def _scan_classes(code: str) -> list[_Cls]:
    out = []
    for m in _CLASS.finditer(code):
        brace = code.find("{", m.end())
        semi = code.find(";", m.end())
        if brace < 0 or (0 <= semi < brace):
            continue
        c = _Cls()
        c.kw, c.kind, c.name, c.body, c.end, c.anns = m.start(), m.group(1), m.group(2), brace, _match_brace(code, brace), []
        out.append(c)
    return out


def _enclosing(classes: list[_Cls], pos: int):
    best = None
    for c in classes:
        if c.kw < pos < c.end and (best is None or c.kw > best.kw):
            best = c
    return best


# ------------------------------------------------------------------ SQL helpers

_SQL_OP = re.compile(r"^\s*(?:\(\s*)?(select|insert|update|delete|merge|with|from|truncate)\b", re.I)
_STRONG_SQL = re.compile(
    r"(?is)^\s*(?:insert\s+(?:ignore\s+)?into\s+\w|delete\s+from\s+\w|update\s+[\w.$]+\s+set\s"
    r"|select\s.+\sfrom\s+[\w.$]+.*\b(?:where|join|order\s+by|group\s+by)\b)")
_TABLE_RX = {
    "select": re.compile(r"(?i)\bfrom\s+([A-Za-z_][\w.$]*)"),
    "insert": re.compile(r"(?i)\binsert\s+(?:ignore\s+)?into\s+([A-Za-z_][\w.$]*)"),
    "update": re.compile(r"(?i)^\s*update\s+([A-Za-z_][\w.$]*)"),
    "delete": re.compile(r"(?i)\bdelete\s+(?:from\s+)?([A-Za-z_][\w.$]*)"),
    "merge": re.compile(r"(?i)\bmerge\s+into\s+([A-Za-z_][\w.$]*)"),
    "truncate": re.compile(r"(?i)\btruncate\s+(?:table\s+)?([A-Za-z_][\w.$]*)"),
}
_SQL_CALLS = ("query|queryForObject|queryForList|queryForMap|queryForRowSet|queryForInt|queryForLong|update|batchUpdate|"
              "execute|prepareStatement|prepareCall|createQuery|createNativeQuery|createSQLQuery|createSqlQuery|"
              "executeQuery|executeUpdate|addBatch|getNamedQuery")
_CTX_CALL = re.compile(rf"\.\s*(?:{_SQL_CALLS})\s*\(\s*$")
_CTX_VAR = re.compile(r"(?i)\w*(?:sql|query|qry|stmt|statement)\w*\s*\+?=\s*$")
_CALL_RX = re.compile(
    r"(?i)(?:\{\s*(?:\?\s*=\s*)?call|prepareCall\s*\(\s*\"\s*(?:call|exec(?:ute)?))\s+([A-Za-z_][\w.$]*)")


def _sql_info(sql: str, ctx: bool):
    m = _SQL_OP.match(sql)
    if not m:
        return None
    if not ctx and not _STRONG_SQL.match(sql):
        return None
    op = m.group(1).lower()
    op = "select" if op in ("from", "with") else op
    t = _TABLE_RX[op].search(sql)
    return op, (t.group(1) if t else "(dynamic)")


# ------------------------------------------------------------------ Java extraction

_MAPPING = {"GetMapping": "GET", "PostMapping": "POST", "PutMapping": "PUT", "DeleteMapping": "DELETE",
            "PatchMapping": "PATCH", "RequestMapping": None}
_VERBS = re.compile(r"\b(GET|POST|PUT|DELETE|PATCH|HEAD|OPTIONS|TRACE)\b")
_LISTENERS = {"JmsListener": ("destination",), "KafkaListener": ("topics",), "RabbitListener": ("queues",),
              "SqsListener": ("value",), "MessageMapping": ("value",)}
_VALIDATION = {"NotNull", "NotBlank", "NotEmpty", "Size", "Min", "Max", "Pattern", "Email", "Positive", "Negative",
               "Past", "Future", "Digits", "AssertTrue", "AssertFalse", "DecimalMin", "DecimalMax", "Valid"}
_DS_EXCLUDE = re.compile(r"TransactionManager|Initializer|Populator|Utils|Template|Transaction|Proxy|Factory|Exception")


def _handler_name(code: str, a: _Ann, cls) -> str:
    m = _METHOD_TARGET.match(code[a.target:a.target + 600])
    return f"{cls.name if cls else '?'}.{m.group(1)}" if m else (cls.name if cls else "?")


def _scan_java(path: str, text: str, clean: str | None = None) -> Iterable[Fact]:
    clean = clean if clean is not None else _clean_java(text)
    code = _code_only(clean)
    L = lambda off: line_of(clean, off)  # noqa: E731
    anns = _scan_annotations(clean)
    classes = _scan_classes(code)
    by_kw = {c.kw: c for c in classes}
    consumed: list[tuple[int, int]] = []

    for a in anns:
        t = _CLASS_TARGET.match(code[a.target:a.target + 300])
        if t and (a.target + t.start(1)) in by_kw:
            a.cls = by_kw[a.target + t.start(1)]
            a.cls.anns.append(a)
        else:
            a.method = True
    for c in classes:  # classes extending a Spring Data repository
        header = code[c.kw:c.body]
        r = re.search(r"\bextends\b[\s\S]*?\b\w*Repository\s*<\s*([\w.]+)", header) if c.kind == "interface" else None
        if r:
            yield _f("data_access", path, L(c.kw), c.name, type="repository", operation="crud", entity=r.group(1))

    # ---- annotation-driven facts
    for a in anns:
        n, at = a.name, _attrmap(a.args)
        line = L(a.start)
        cls = a.cls or _enclosing(classes, a.start)
        if n in _MAPPING and a.cls is None:
            enc_ann = {x.name: x for x in (cls.anns if cls else [])}
            prefix_ann = enc_ann.get("RequestMapping")
            prefixes = _elements(_attrmap(prefix_ann.args).get("value") or _attrmap(prefix_ann.args).get("path")) if prefix_ann else []
            paths = _elements(at.get("value") or at.get("path")) or [""]
            verbs = [_MAPPING[n]] if _MAPPING[n] else (sorted(set(_VERBS.findall(at.get("method", "")))) or ["ANY"])
            handler = _handler_name(code, a, cls)
            feign = enc_ann.get("FeignClient")
            if feign:
                fa = _attrmap(feign.args)
                base = _first_lit(fa.get("url")) or _first_lit(fa.get("name")) or _first_lit(fa.get("value")) or "feign"
                for p in paths:
                    nm = _safe_url(base.rstrip("/") + _join("", *(prefixes[:1] + [p])))
                    for v in verbs:
                        if nm:
                            yield _f("external_call", path, line, nm, type="http", client="FeignClient", method=v)
                continue
            for pre in (prefixes or [""]):
                for p in paths:
                    for v in verbs:
                        yield _f("entry_point", path, line, _join(pre, p), type="route", method=v, handler=handler)
        elif n == "WebServlet" and a.cls is not None:
            for p in _elements(at.get("urlPatterns") or at.get("value")) or [a.cls.name]:
                yield _f("entry_point", path, line, p, type="route", method="ANY", handler=a.cls.name)
        elif n == "Scheduled" and a.cls is None:
            sched = re.sub(r"\s+", " ", (a.args or "").strip())
            yield _f("entry_point", path, line, _handler_name(code, a, cls), type="job", handler=_handler_name(code, a, cls),
                     schedule=sched[:120])
        elif n in _LISTENERS and a.cls is None:
            dest = next((_first_lit(at.get(k)) for k in (_LISTENERS[n][0], "value") if at.get(k)), None)
            yield _f("entry_point", path, line, _safe(dest) or _handler_name(code, a, cls), type="handler",
                     handler=_handler_name(code, a, cls), listener=n)
        elif n in ("Query", "NamedQuery", "NamedNativeQuery") and at.get("query" if n != "Query" else "value", at.get("query")):
            consumed.append((a.start, a.end))
            sql = _lits(at.get("query") or at.get("value") or "")
            info = _sql_info(sql, True)
            if info:
                d = dict(type="sql", operation=info[0])
                if "nativeQuery" in at:
                    d["native"] = at["nativeQuery"].strip() == "true"
                yield _f("data_access", path, line, info[1], **d)
        elif n in ("Procedure", "NamedStoredProcedureQuery"):
            nm = _first_lit(at.get("procedureName") or at.get("name") or at.get("value"))
            if not nm and a.cls is None:
                m = _METHOD_TARGET.match(code[a.target:a.target + 600])
                nm = m.group(1) if m else None
            if nm:
                yield _f("data_access", path, line, nm, type="stored_procedure", operation="call")
        elif n in ("PreAuthorize", "PostAuthorize"):
            expr = _lits(a.args or "")
            if expr:
                roles = re.findall(r"""['"]([^'"]+)['"]""", " ".join(
                    re.findall(r"(?:hasRole|hasAnyRole|hasAuthority|hasAnyAuthority)\s*\(([^)]*)\)", expr)))
                d = dict(mechanism=n)
                if roles:
                    d["roles"] = sorted(set(roles))
                yield _f("auth_check", path, line, expr.strip()[:120], **d)
        elif n in ("Secured", "RolesAllowed", "DeclareRoles"):
            roles = sorted(set(x for x in _elements(at.get("value")) if x))
            if roles:
                yield _f("auth_check", path, line, f"@{n}({','.join(roles)})"[:120], mechanism=n, roles=roles)
        elif n in ("PermitAll", "DenyAll"):
            yield _f("auth_check", path, line, f"@{n}", mechanism=n)
        elif n == "Bean" and a.cls is None:
            m = re.match(r"[^;{}=]*?\b\w*DataSource\w*\s+(\w+)\s*\(", code[a.target:a.target + 400])
            if m and not _DS_EXCLUDE.search(m.group(1)):
                b = code.find("{", a.target)
                e = _match_brace(code, b) if b >= 0 else a.target
                body = clean[a.target:e]
                secret = bool(re.search(r"(?i)\b(?:set)?(?:password|username)\s*\(", body))
                yield _f("connection", path, line, m.group(1), type="database", secret_location=secret)
        elif n in _VALIDATION and at.get("message"):
            msg = _lits(at["message"]).strip()
            if msg and _safe(msg):
                yield _f("message", path, line, msg[:200], context="validation")

    # ---- entities
    for c in classes:
        names = {x.name: x for x in c.anns}
        tbl = names.get("Table")
        ent = names.get("Entity")
        if ent or tbl:
            src = ent or tbl
            tname = (_first_lit(_attrmap(tbl.args).get("name")) if tbl else None) or \
                    (_first_lit(_attrmap(ent.args).get("name")) if ent else None) or c.name
            d = dict(type="entity", operation="map", **{"class": c.name})
            if tbl and _attrmap(tbl.args).get("schema"):
                sch = _first_lit(_attrmap(tbl.args)["schema"])
                if sch:
                    d["schema"] = sch
            yield _f("data_access", path, L(src.start), tname, **d)

    # ---- SQL in string literals
    for m in re.finditer(_CHAIN, clean):
        s = m.start()
        if any(lo <= s < hi for lo, hi in consumed):
            continue
        pre = clean[max(0, s - 160):s]
        ctx = bool(_CTX_CALL.search(pre) or _CTX_VAR.search(pre))
        info = _sql_info(_lits(m.group(0)), ctx)
        if info:
            yield _f("data_access", path, L(s), info[1], type="sql", operation=info[0])
    for m in _CALL_RX.finditer(clean):
        yield _f("data_access", path, L(m.start()), m.group(1), type="stored_procedure", operation="call")
    for m in re.finditer(r'\.\s*with(?:Procedure|Function)Name\s*\(\s*(' + _CHAIN + ")", clean):
        nm = _lits(m.group(1))
        if nm:
            yield _f("data_access", path, L(m.start()), nm, type="stored_procedure", operation="call")

    # ---- connections
    for m in re.finditer(r'"((?:java:comp/env/)?jdbc/[\w./\-]+)"', clean):
        yield _f("connection", path, L(m.start()), m.group(1).replace("java:comp/env/", ""), type="database",
                 secret_location=False, source="jndi")
    for m in re.finditer(r"\bDriverManager\s*\.\s*getConnection\s*\(", clean):
        close = _match_paren(clean, m.end() - 1)
        args = clean[m.end():close] if close > 0 else ""
        yield _f("connection", path, L(m.start()), "DriverManager.getConnection", type="database",
                 secret_location=len(_split_top(args)) > 1 or bool(find_secret_shapes(args)))

    # ---- external calls
    yield from _external_calls(path, clean, code, L)

    # ---- auth checks in code
    for m in re.finditer(r"\.\s*(antMatchers|mvcMatchers|regexMatchers|requestMatchers|anyRequest)\s*\(", clean):
        op = m.end() - 1
        close = _match_paren(clean, op)
        if close < 0:
            continue
        r = re.compile(r"\s*\.\s*(hasRole|hasAnyRole|hasAuthority|hasAnyAuthority|permitAll|authenticated|denyAll|access|"
                       r"hasIpAddress|anonymous|fullyAuthenticated|rememberMe)\s*\(").match(clean, close + 1)
        if not r:
            continue
        rclose = _match_paren(clean, r.end() - 1)
        if rclose < 0:
            continue
        rule_args = clean[r.end():rclose]
        roles = sorted(set(x for x in re.findall(r"""["']([^"']+)["']""", rule_args) if r.group(1).startswith(("has", "access"))))
        text_ = re.sub(r"\s+", " ", clean[m.start() + 1:rclose + 1]).strip()[:120]
        d = dict(mechanism="HttpSecurity")
        if roles:
            d["roles"] = roles
        yield _f("auth_check", path, L(m.start()), text_, **d)
    for m in re.finditer(r"\.\s*(formLogin|httpBasic|oauth2Login|oauth2ResourceServer|saml2Login)\s*\(", clean):
        yield _f("auth_check", path, L(m.start()), f"{m.group(1)}()", mechanism="HttpSecurity")
    for m in re.finditer(r'\.\s*isUserInRole\s*\(\s*(' + _CHAIN + ")", clean):
        role = _lits(m.group(1))
        yield _f("auth_check", path, L(m.start()), f'isUserInRole("{role}")'[:120], mechanism="isUserInRole", roles=[role])

    # ---- messages
    yield from _messages(path, clean, L)


_EXC = re.compile(rf"\bnew\s+([\w.]*(?:Exception|Error))\s*(?:<[^>]*>)?\s*\(\s*({_CHAIN})")
_RSE = re.compile(rf"\bnew\s+ResponseStatusException\s*\(\s*([^,()]+(?:\([^)]*\))?)\s*,\s*({_CHAIN})")
_RESP_BODY = re.compile(rf"\bResponseEntity\s*\.\s*(\w+)\s*\((?:[^()]|\([^()]*\))*\)\s*\.\s*body\s*\(\s*({_CHAIN})")
_RESP_NEW = re.compile(rf"\bnew\s+ResponseEntity\s*(?:<[^>]*>)?\s*\(\s*({_CHAIN})\s*,\s*([^)]*)\)")
_SEND_ERR = re.compile(rf"\.\s*sendError\s*\(\s*[^,()]+,\s*({_CHAIN})")
_STRUTS_MSG = re.compile(rf"\b(addActionError|addActionMessage|addFieldError)\s*\(\s*(?:(?:{_STR})\s*,\s*)?({_CHAIN})")
_ERRISH = re.compile(r"(?i)bad|error|not_?found|forbidden|unauthori|conflict|invalid|unprocessable|\b[45]\d\d\b|internal")


def _msg(path, line, text, ctx, **extra):
    text = re.sub(r"\s+", " ", text).strip()
    if not text or not re.search(r"[A-Za-z]", text) or not _safe(text):
        return None
    return _f("message", path, line, text[:200], context=ctx, **extra)


def _messages(path, clean, L):
    for m in _EXC.finditer(clean):
        ctx = "validation" if re.search(r"(?i)validat|illegalargument|constraint|invalid|binding|badrequest", m.group(1)) else "error"
        f = _msg(path, L(m.start()), _lits(m.group(2)), ctx, exception=m.group(1).rsplit(".", 1)[-1])
        if f:
            yield f
    for m in _RSE.finditer(clean):
        f = _msg(path, L(m.start()), _lits(m.group(2)), "error" if _ERRISH.search(m.group(1)) else "info")
        if f:
            yield f
    for m in _RESP_BODY.finditer(clean):
        f = _msg(path, L(m.start()), _lits(m.group(2)), "error" if _ERRISH.search(m.group(1)) else "info")
        if f:
            yield f
    for m in _RESP_NEW.finditer(clean):
        f = _msg(path, L(m.start()), _lits(m.group(1)), "error" if _ERRISH.search(m.group(2)) else "info")
        if f:
            yield f
    for m in _SEND_ERR.finditer(clean):
        f = _msg(path, L(m.start()), _lits(m.group(1)), "error")
        if f:
            yield f
    for m in _STRUTS_MSG.finditer(clean):
        ctx = {"addActionError": "error", "addActionMessage": "info", "addFieldError": "validation"}[m.group(1)]
        f = _msg(path, L(m.start()), _lits(m.group(2)), ctx)
        if f:
            yield f


def _first_arg_lit(clean: str, open_idx: int) -> str | None:
    close = _match_paren(clean, open_idx)
    if close < 0:
        return None
    parts = _split_top(clean[open_idx + 1:close])
    return _lits(parts[0]) if parts and '"' in parts[0] else None


def _typed_vars(code: str, types: str) -> list[str]:
    return sorted(set(re.findall(rf"\b(?:{types})\s*(?:<[^>;]*>)?\s+(\w+)\s*[;=,)]", code)))


def _external_calls(path, clean, code, L):
    # RestTemplate: one fact per call; declaration only if the file never calls it.
    rt_vars = _typed_vars(code, "RestTemplate|TestRestTemplate|RestClient|OAuth2RestTemplate")
    calls = []
    if rt_vars:
        rx = re.compile(r"\b(?:%s)\s*\.\s*(getForObject|getForEntity|postForObject|postForEntity|postForLocation|put|delete|"
                        r"exchange|execute|patchForObject|headForHeaders|optionsForAllow)\s*\(" % "|".join(map(re.escape, rt_vars)))
        calls = list(rx.finditer(clean))
    for m in calls:
        close = _match_paren(clean, m.end() - 1)
        args = clean[m.end():close] if close > 0 else ""
        first = _split_top(args)[0] if args.strip() else ""
        url = _safe_url(_lits(first)) if '"' in first else None
        meth = m.group(1)
        verb = ("GET" if meth.startswith("get") else "POST" if meth.startswith("post") else "PUT" if meth == "put"
                else "DELETE" if meth == "delete" else "PATCH" if meth.startswith("patch") else "HEAD" if meth.startswith("head") else "ANY")
        if verb == "ANY":
            hm = re.search(r"HttpMethod\s*\.\s*(\w+)", args)
            verb = hm.group(1).upper() if hm else "ANY"
        yield _f("external_call", path, L(m.start()), url or "RestTemplate", type="http", client="RestTemplate", method=verb)
    if not calls:
        for m in re.finditer(r"\bnew\s+(RestTemplate|RestClient)\s*\(", clean):
            yield _f("external_call", path, L(m.start()), m.group(1), type="http", client=m.group(1))

    # WebClient
    uri = [m for m in re.finditer(rf"\.\s*uri\s*\(\s*({_CHAIN}|[^,)]*)", clean)] if "WebClient" in code else []
    for m in uri:
        pre = clean[max(0, m.start() - 60):m.start()]
        vm = re.findall(r"\.\s*(get|post|put|delete|patch|head|method)\s*\(", pre)
        lit = _lits(m.group(1)) if '"' in m.group(1) else ""
        yield _f("external_call", path, L(m.start()), _safe_url(lit) or "WebClient", type="http", client="WebClient",
                 method=(vm[-1].upper() if vm and vm[-1] != "method" else "ANY"))
    if not uri:
        for m in re.finditer(r"\bWebClient\s*\.\s*(create|builder)\s*\(", clean):
            lit = _first_arg_lit(clean, m.end() - 1) if m.group(1) == "create" else None
            if m.group(1) == "builder":
                bm = re.search(rf"\.\s*baseUrl\s*\(\s*({_CHAIN})", clean[m.end():m.end() + 400])
                lit = _lits(bm.group(1)) if bm else None
            yield _f("external_call", path, L(m.start()), _safe_url(lit or "") or "WebClient", type="http", client="WebClient")

    # HttpURLConnection / java.net.http / Apache HttpClient
    seen_http = False
    for m in re.finditer(r"\bnew\s+URL\s*\(", clean):
        lit = _first_arg_lit(clean, m.end() - 1)
        if lit and lit.lower().startswith("http"):
            seen_http = True
            yield _f("external_call", path, L(m.start()), _safe_url(lit) or "URL", type="http", client="HttpURLConnection")
    if not seen_http:
        for m in re.finditer(r"\(\s*HttpURLConnection\s*\)", clean):
            yield _f("external_call", path, L(m.start()), "HttpURLConnection", type="http", client="HttpURLConnection")
    other = False
    for m in re.finditer(r"\bnew\s+(HttpGet|HttpPost|HttpPut|HttpDelete|HttpPatch)\s*\(", clean):
        other = True
        lit = _first_arg_lit(clean, m.end() - 1)
        yield _f("external_call", path, L(m.start()), _safe_url(lit or "") or "HttpClient", type="http",
                 client="ApacheHttpClient", method=m.group(1)[4:].upper())
    for m in re.finditer(r"\bHttpRequest\s*\.\s*newBuilder\s*\(", clean):
        other = True
        um = re.search(rf"URI\s*\.\s*create\s*\(\s*({_CHAIN})", clean[m.end():m.end() + 400])
        yield _f("external_call", path, L(m.start()), _safe_url(_lits(um.group(1)) if um else "") or "HttpClient",
                 type="http", client="HttpClient")
    if not other:
        for m in re.finditer(r"\b(?:HttpClient\s*\.\s*(?:newHttpClient|newBuilder)|HttpClients\s*\.\s*\w+)\s*\(", clean):
            yield _f("external_call", path, L(m.start()), "HttpClient", type="http", client="HttpClient")

    # email
    mail_vars = _typed_vars(code, "JavaMailSender|MailSender|JavaMailSenderImpl")
    sends = []
    if mail_vars:
        sends = list(re.finditer(r"\b(?:%s)\s*\.\s*send\s*\(" % "|".join(map(re.escape, mail_vars)), clean))
    for m in sends:
        yield _f("external_call", path, L(m.start()), "JavaMailSender", type="email")
    if mail_vars and not sends:
        m = re.search(r"\b(?:JavaMailSender|MailSender|JavaMailSenderImpl)\b(?!\s*;)", code)
        yield _f("external_call", path, L(m.start()) if m else None, "JavaMailSender", type="email")
    for m in re.finditer(r"\bTransport\s*\.\s*send\s*\(", clean):
        yield _f("external_call", path, L(m.start()), "javax.mail.Transport", type="email")

    # files
    for m in re.finditer(r"\bnew\s+(File|FileInputStream|FileOutputStream|FileReader|FileWriter|RandomAccessFile)\s*\(", clean):
        lit = _first_arg_lit(clean, m.end() - 1)
        if lit is None:
            close = _match_paren(clean, m.end() - 1)
            lits = [_lits(p) for p in _split_top(clean[m.end():close] if close > 0 else "") if '"' in p]
            lit = lits[0] if lits else None
        op = "read" if m.group(1) in ("FileInputStream", "FileReader") else "write" if m.group(1) in ("FileOutputStream", "FileWriter") else "access"
        yield _f("external_call", path, L(m.start()), _safe(lit) or m.group(1), type="file", operation=op)
    for m in re.finditer(r"\bFiles\s*\.\s*(\w+)\s*\(", clean):
        close = _match_paren(clean, m.end() - 1)
        lit = next((_lits(p) for p in _split_top(clean[m.end():close] if close > 0 else "") if '"' in p), None)
        op = "write" if re.match(r"(?i)write|copy|move|delete|create|newOutput|setAttr|setLast", m.group(1)) else \
            "read" if re.match(r"(?i)read|lines|newInput|newBuffered|list|walk|find|exists|size|is", m.group(1)) else "access"
        yield _f("external_call", path, L(m.start()), _safe(lit) or "Files", type="file", operation=op)

    # processes (name = executable only, never the arguments)
    for m, default in [(x, "ProcessBuilder") for x in re.finditer(r"\bnew\s+ProcessBuilder\s*\(", clean)] + \
                      [(x, "Runtime.exec") for x in re.finditer(r"\bgetRuntime\s*\(\s*\)\s*\.\s*exec\s*\(", clean)]:
        close = _match_paren(clean, m.end() - 1)
        lit = next((_lits(p) for p in _split_top(clean[m.end():close] if close > 0 else "") if '"' in p), None)
        exe = lit.split()[0] if lit and lit.split() else None
        yield _f("external_call", path, L(m.start()), _safe(exe) or default, type="process")


# ------------------------------------------------------------------ JSP

def _scan_jsp(path: str, text: str) -> Iterable[Fact]:
    stripped = re.sub(r"<%--[\s\S]*?--%>", _blank, text)
    stripped = strip_comments(stripped, "xml")
    inputs = sorted(set(re.findall(r"""getParameter\s*\(\s*["']([^"']+)["']""", stripped)
                        + re.findall(r"\$\{\s*param\.(\w+)", stripped)
                        + re.findall(r"""param\[\s*["'](\w+)["']\s*\]""", stripped)))
    d = dict(type="page")
    if inputs:
        d["inputs"] = inputs
    yield _f("entry_point", path, None, path, **d)
    L = lambda off: line_of(stripped, off)  # noqa: E731
    for m in re.finditer(r"<(?:\w+:)?authorize\b[^>]*?\baccess\s*=\s*(?:\"([^\"]*)\"|'([^']*)')", stripped):
        expr = (m.group(1) or m.group(2)).strip()
        roles = sorted(set(re.findall(r"""['"]([^'"]+)['"]""", " ".join(
            re.findall(r"(?:hasRole|hasAnyRole|hasAuthority|hasAnyAuthority)\s*\(([^)]*)\)", expr)))))
        det = dict(mechanism="sec:authorize")
        if roles:
            det["roles"] = roles
        yield _f("auth_check", path, L(m.start()), expr[:120], **det)
    for m in re.finditer(r"""<%[^@-][\s\S]*?%>""", stripped):  # scriptlets: reuse the Java scanners
        seg = m.group(0)
        pad = re.sub(r"[^\n]", " ", stripped[:m.start()])  # keep line numbers
        for fact in _scan_java(path, pad + seg, clean=_clean_java(pad + seg)):
            if fact.kind in ("data_access", "external_call", "connection", "message"):
                yield fact


# ------------------------------------------------------------------ XML

_ATTR = re.compile(r"""([\w:.\-]+)\s*=\s*(?:"([^"]*)"|'([^']*)')""")
_XML_KINDS = (
    ("beans", re.compile(r"<(?:\w+:)?beans\b")),
    ("struts", re.compile(r"<struts\b|<struts-config\b")),
    ("mapper", re.compile(r"<mapper\b")),
    ("webapp", re.compile(r"<web-app\b")),
    ("hibernate", re.compile(r"<hibernate-mapping\b")),
    ("ojb", re.compile(r"<descriptor-repository\b")),
)


def _attrs(tag: str) -> dict:
    return {k: (v1 if v1 is not None else v2) for k, v1, v2 in _ATTR.findall(tag)}


def _scan_xml(path: str, text: str) -> Iterable[Fact]:
    clean = strip_comments(text, "xml")
    head = clean[:20000]
    kind = next((k for k, rx in _XML_KINDS if rx.search(head)), None)
    if kind is None:
        return
    L = lambda off: line_of(clean, off)  # noqa: E731
    yield from {"beans": _spring_xml, "struts": _struts_xml, "mapper": _mapper_xml, "webapp": _webapp_xml,
                "hibernate": _hbm_xml, "ojb": _ojb_xml}[kind](path, clean, L)


def _bean_body(clean: str, start: int) -> int:
    depth = 1
    for m in re.finditer(r"<(/?)(?:\w+:)?bean\b[^>]*?(/?)>", clean[start:]):
        if m.group(1):
            depth -= 1
            if depth == 0:
                return start + m.start()
        elif not m.group(2):
            depth += 1
    return len(clean)


def _spring_xml(path, clean, L):
    for m in re.finditer(r"<(?:\w+:)?bean\b([^>]*?)(/?)>", clean):
        at = _attrs(m.group(1))
        cls = at.get("class", "")
        simple = cls.rsplit(".", 1)[-1]
        ident = at.get("id") or at.get("name", "").split(",")[0].strip() or simple
        line = L(m.start())
        body = clean[m.end():_bean_body(clean, m.end())] if not m.group(2) else ""
        props = set(re.findall(r"""<(?:\w+:)?property\b[^>]*?\bname\s*=\s*["']([\w.]+)["']""", body))
        props |= {k[2:] for k in at if k.startswith("p:") and not k.endswith("-ref")} | {k[2:-4] for k in at if k.startswith("p:") and k.endswith("-ref")}
        secret = any(is_secret_key(p) or p.lower() in ("username", "user") for p in props)
        for alias in re.split(r"[\s,;]+", (at.get("name", "") + " " + at.get("id", "")).strip()):
            if alias.startswith("/"):
                yield _f("entry_point", path, line, alias, type="route", method="ANY", handler=cls or ident)
        if "DataSource" in simple and not _DS_EXCLUDE.search(simple):
            yield _f("connection", path, line, ident, type="database", secret_location=secret, **{"class": simple})
        elif re.search(r"MailSender", simple):
            yield _f("connection", path, line, ident, type="smtp", secret_location=secret, **{"class": simple})
        elif "JndiObjectFactoryBean" in simple:
            jm = re.search(r"""name\s*=\s*["']jndiName["'][^>]*?value\s*=\s*["']([^"']+)["']""", body)
            if jm:
                yield _f("connection", path, line, jm.group(1).replace("java:comp/env/", ""), type="database",
                         secret_location=False, source="jndi")
        elif "SimpleUrlHandlerMapping" in simple:
            pass  # mappings below
    for m in re.finditer(r"""<(?:\w+:)?prop\s+key\s*=\s*["'](/[^"']*)["']\s*>\s*([^<\s]+)\s*</""", clean):
        yield _f("entry_point", path, L(m.start()), m.group(1), type="route", method="ANY", handler=m.group(2))
    for m in re.finditer(r"<(?:\w+:)?entry\b([^>]*?)/?>", clean):
        at = _attrs(m.group(1))
        if at.get("key", "").startswith("/"):
            yield _f("entry_point", path, L(m.start()), at["key"], type="route", method="ANY",
                     handler=at.get("value") or at.get("value-ref") or "?")
    for m in re.finditer(r"<(?:\w+:)?view-controller\b([^>]*?)/?>", clean):
        at = _attrs(m.group(1))
        if at.get("path"):
            yield _f("entry_point", path, L(m.start()), at["path"], type="route", method="ANY", handler=at.get("view-name", "view"))
    for m in re.finditer(r"<(?:\w+:)?scheduled\b([^>]*?)/?>", clean):
        at = _attrs(m.group(1))
        if at.get("method"):
            sched = next((f"{k}={at[k]}" for k in ("cron", "fixed-rate", "fixed-delay") if k in at), "")
            h = f"{at.get('ref', '?')}.{at['method']}"
            yield _f("entry_point", path, L(m.start()), h, type="job", handler=h, schedule=sched)
    for m in re.finditer(r"<(?:\w+:)?jndi-lookup\b([^>]*?)/?>", clean):
        at = _attrs(m.group(1))
        nm = (at.get("jndi-name") or at.get("id") or "").replace("java:comp/env/", "")
        if nm:
            yield _f("connection", path, L(m.start()), nm, type="database", secret_location=False, source="jndi")
    for m in re.finditer(r"<(?:\w+:)?embedded-database\b([^>]*?)/?>", clean):
        yield _f("connection", path, L(m.start()), _attrs(m.group(1)).get("id", "embedded-database"), type="database",
                 secret_location=False)
    for m in re.finditer(r"<(?:\w+:)?intercept-url\b([^>]*?)/?>", clean):
        at = _attrs(m.group(1))
        if at.get("pattern") and at.get("access"):
            roles = sorted(set(re.findall(r"""['"]([^'"]+)['"]""", at["access"])) or
                           [r.strip() for r in at["access"].split(",") if r.strip()])
            yield _f("auth_check", path, L(m.start()), f"intercept-url {at['pattern']} access={at['access']}"[:120],
                     mechanism="intercept-url", roles=roles)


def _struts_xml(path, clean, L):
    v1 = "<struts-config" in clean
    pkgs = [(m.start(), _attrs(m.group(1)).get("namespace", "/")) for m in re.finditer(r"<package\b([^>]*)>", clean)]
    for m in re.finditer(r"<action\b([^>]*?)/?>", clean):
        at = _attrs(m.group(1))
        line = L(m.start())
        if v1 and at.get("path"):
            yield _f("entry_point", path, line, at["path"], type="route", method="ANY", handler=at.get("type", at["path"]))
        elif not v1 and at.get("name"):
            ns = next((n for s, n in reversed(pkgs) if s < m.start()), "/")
            h = at.get("class", at["name"]) + (("." + at["method"]) if at.get("method") else "")
            yield _f("entry_point", path, line, _join(ns, at["name"]), type="route", method="ANY", handler=h)


def _mapper_xml(path, clean, L):
    ns = ""
    nm = re.search(r"<mapper\b([^>]*)>", clean)
    if nm:
        ns = _attrs(nm.group(1)).get("namespace", "")
    for m in re.finditer(r"<(select|insert|update|delete)\b([^>]*)>([\s\S]*?)</\1>", clean):
        at = _attrs(m.group(2))
        body = re.sub(r"<!\[CDATA\[|\]\]>", " ", m.group(3))
        body = re.sub(r"<[^>]+>", " ", body)
        body = re.sub(r"\s+", " ", body).strip()
        sid = at.get("id", "")
        cm = _CALL_RX.search(body)
        if cm:
            yield _f("data_access", path, L(m.start()), cm.group(1), type="stored_procedure", operation="call", statement=sid)
            continue
        info = _sql_info(body, True)
        op, table = info if info else (m.group(1), "(dynamic)")
        yield _f("data_access", path, L(m.start()), sid if table == "(dynamic)" and sid else table, type="sql",
                 operation=op, statement=sid, namespace=ns)


def _webapp_xml(path, clean, L):
    servlets = {}
    for m in re.finditer(r"<servlet>([\s\S]*?)</servlet>", clean):
        n = re.search(r"<servlet-name>\s*([^<\s]+)", m.group(1))
        c = re.search(r"<servlet-class>\s*([^<\s]+)", m.group(1))
        if n:
            servlets[n.group(1)] = (c.group(1) if c else n.group(1), L(m.start()))
    mapped = set()
    for m in re.finditer(r"<servlet-mapping>([\s\S]*?)</servlet-mapping>", clean):
        n = re.search(r"<servlet-name>\s*([^<\s]+)", m.group(1))
        if not n:
            continue
        mapped.add(n.group(1))
        handler = servlets.get(n.group(1), (n.group(1), 0))[0]
        for u in re.finditer(r"<url-pattern>\s*([^<\s]+)", m.group(1)):
            yield _f("entry_point", path, L(m.start() + 0 + m.group(0).find(u.group(0))), u.group(1), type="route",
                     method="ANY", handler=handler)
    for name in sorted(servlets):
        if name not in mapped:
            cls, line = servlets[name]
            yield _f("entry_point", path, line, name, type="handler", handler=cls)
    for m in re.finditer(r"<security-constraint>([\s\S]*?)</security-constraint>", clean):
        urls = re.findall(r"<url-pattern>\s*([^<\s]+)", m.group(1))
        roles = sorted(set(re.findall(r"<role-name>\s*([^<\s]+)", m.group(1))))
        if urls:
            d = dict(mechanism="web.xml security-constraint")
            if roles:
                d["roles"] = roles
            yield _f("auth_check", path, L(m.start()), ("security-constraint " + ",".join(urls))[:120], **d)
    for m in re.finditer(r"<res-ref-name>\s*(jdbc/[^<\s]+)", clean):
        yield _f("connection", path, L(m.start()), m.group(1), type="database", secret_location=False, source="jndi")


def _hbm_xml(path, clean, L):
    for m in re.finditer(r"<class\b([^>]*)>", clean):
        at = _attrs(m.group(1))
        if at.get("name"):
            yield _f("data_access", path, L(m.start()), at.get("table") or at["name"].rsplit(".", 1)[-1],
                     type="entity", operation="map", **{"class": at["name"].rsplit(".", 1)[-1]})


def _ojb_xml(path, clean, L):
    for m in re.finditer(r"<class-descriptor\b([^>]*)>", clean):
        at = _attrs(m.group(1))
        if at.get("table"):
            yield _f("data_access", path, L(m.start()), at["table"], type="entity", operation="map",
                     **{"class": at.get("class", "").rsplit(".", 1)[-1]})


# ------------------------------------------------------------------ the Stack

class JavaSpring(Stack):
    id = STACK_ID
    extensions = frozenset({".java", ".xml", ".jsp", ".jspx"})

    def detect(self, files: list[str]) -> list[str]:
        build = sorted(f for f in files if f.rsplit("/", 1)[-1] in _BUILD)
        has_java = any(f.lower().endswith(".java") for f in files)
        xmlish = sorted(f for f in files if _XMLISH.search(f))
        jsps = [f for f in xmlish if f.lower().endswith((".jsp", ".jspx"))]
        others = [f for f in xmlish if f not in set(jsps)]
        if not ((build and has_java) or xmlish):
            return []
        return sorted((build if has_java else []) + others + jsps[:_MAX_JSP_MARKERS])

    def extract(self, path: str, text: str) -> Iterable[Fact]:
        low = path.lower()
        if low.endswith(".java"):
            return list(_scan_java(path, text))
        if low.endswith((".jsp", ".jspx")):
            return list(_scan_jsp(path, text))
        if low.endswith(".xml") and low.rsplit("/", 1)[-1] != "pom.xml":
            return list(_scan_xml(path, text))
        return ()


STACK = JavaSpring()
