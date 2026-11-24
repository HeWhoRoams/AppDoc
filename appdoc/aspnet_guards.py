"""ASP.NET guards (2.8, W3): raw per-file Facts and the post-pass that joins them.

``file_facts`` and ``const_facts`` run inside the ``aspnet`` and ``aspnet-core`` Stacks and see one file only (its text,
its classes and methods). They emit RAW Facts: ``controller_class``, ``guard_class``, ``guard_use``, ``const_def``,
``method_call`` and ``auth_check mechanism=global-filter|bearer``. Nothing here looks at a second file, so the Facts are
the same for serial, pooled and cached runs.

``promote`` is the post-pass over the combined Facts (called once from ``extract``). It resolves constants across files
(``role``, ``users_named``, secret arguments), tells in-Target guards from declared and external ones, derives
``auth_check via=custom|declared|call``, ``guard_candidate`` (an external attribute used at least three times, guard or
not), the argument-shape marks and ``api_pipeline``. ``guard_shapes`` is the shape table over Facts as JSON.

Rules: R18 (a role that looks like an email or a SID is counted as a user, never recorded; ``Users=`` is a count only) and
R19 (a constant that is a secret, by name or by value shape, is never value-resolved: ``arg_kind secret``, no ``role``,
no ``value``). This module sits below the Stacks in the import layering, so it takes the Stacks' parsed classes and
methods as duck-typed arguments (``.name .base .pos`` for a class; a ``_METHOD`` match for a method) instead of importing them.
"""

from __future__ import annotations

import bisect
import re

from .facts import Fact
from .secrets import find_secret_shapes, never_record_value

# --------------------------------------------------------------------------- lexical helpers (small copies; see the module doc)

STR = r'(?:\$?@"(?:[^"]|"")*"|\$?"(?:[^"\\\n]|\\.)*")'
_STR_RX = re.compile(STR)
_STR_CHAIN = re.compile(r"\s*" + STR + r"(?:\s*\+\s*" + STR + r")*\s*$")
_CHAR_RX = re.compile(r"'(?:\\.|[^'\\\n])'")
_ATTR_BLOCK = r"\[(?:[^\]\"]|\"(?:[^\"\\]|\\.)*\")*\]"
_ATTR_ITEM = re.compile(r'([A-Za-z_][\w\.]*)\s*(?:\(((?:[^()"]|"(?:[^"\\]|\\.)*"|\([^()]*\))*)\))?')
_USING = re.compile(r"\busing\s+(?:static\s+)?([\w.]+)\s*;")
_MVC_USING = re.compile(r"\busing\s+(?:static\s+)?(?:System\.Web\.(?:Mvc|Http)|Microsoft\.AspNetCore\.Mvc)\b")


def _unq(tok: str) -> str:
    t = tok.lstrip("$")
    if t.startswith('@"'):
        return t[2:-1].replace('""', '"')
    return t[1:-1].replace("\\\\", "\\").replace('\\"', '"')


def _blanked(ctx) -> str:
    """The file text with string and char literals blanked (same length, same newlines)."""
    chars = list(ctx.t)
    for s, e, _ in ctx.strings:
        for k in range(s, e):
            if chars[k] != "\n":
                chars[k] = " "
    text = "".join(chars)
    return _CHAR_RX.sub(lambda m: " " * len(m.group(0)), text)


def _match_close(blank: str, open_idx: int, op: str = "{", cl: str = "}", limit: int | None = None) -> int:
    depth = 0
    end = len(blank) if limit is None else min(len(blank), open_idx + limit)
    for i in range(open_idx, end):
        c = blank[i]
        if c == op:
            depth += 1
        elif c == cl:
            depth -= 1
            if depth == 0:
                return i
    return -1


def _attrs_before(text: str, pos: int) -> tuple[int, str]:
    """(offset, raw text) of the attribute blocks that directly precede a declaration starting at ``pos``."""
    lo = max(0, pos - 800)
    seg = text[lo:pos]
    seg = re.sub(r"(?:(?:public|internal|private|protected|abstract|sealed|partial|static)\s+)*$", "", seg)
    m = re.search(r"((?:" + _ATTR_BLOCK + r"\s*)+)$", seg)
    return (lo + m.start(1), m.group(1)) if m else (pos, "")


def _attr_uses(start: int, raw: str):
    """[(name as written, offset, args or None)] for ``[A, B("x")][C]`` found at ``start``."""
    out = []
    for blk in re.finditer(_ATTR_BLOCK, raw):
        inner = blk.group(0)[1:-1]
        base = start + blk.start() + 1
        for m in _ATTR_ITEM.finditer(inner):
            out.append((m.group(1), base + m.start(), m.group(2)))
    return out


def attr_key(name: str) -> str:
    """Lower-cased attribute name without namespace and without the ``Attribute`` suffix."""
    n = name.strip().rsplit(".", 1)[-1].lower()
    return n[:-9] if n.endswith("attribute") and len(n) > 9 else n


def _split_args(args: str) -> list[str]:
    out, depth, start, i, n = [], 0, 0, 0, len(args)
    while i < n:
        c = args[i]
        if c in '"$@':
            m = _STR_RX.match(args, i)
            if m:
                i = m.end()
                continue
        elif c == "'":
            m = _CHAR_RX.match(args, i)
            if m:
                i = m.end()
                continue
        if c in "([{":
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


# --------------------------------------------------------------------------- closed vocabularies

# Attributes that are not guards and never become a guard_use (compared by attr_key).
_FRAMEWORK_ATTRS = frozenset(k.lower() for k in (
    "HttpGet HttpPost HttpPut HttpDelete HttpPatch HttpHead HttpOptions Route RoutePrefix RouteArea Area NonAction "
    "ChildActionOnly ActionName AcceptVerbs ValidateAntiForgeryToken ValidateInput OutputCache HandleError Bind "
    "Obsolete Description DisplayName Serializable AllowAnonymous SuppressMessage AllowHtml ResponseType "
    "ProducesResponseType Produces Consumes ApiExplorerSettings ApiController RequireHttps SessionState "
    "ExcludeFromCodeCoverage DebuggerStepThrough DebuggerNonUserCode GeneratedCode CompilerGenerated Display Required "
    "StringLength Range AsyncTimeout NoAsyncTimeout ResponseCache IgnoreAntiforgeryToken AutoValidateAntiforgeryToken "
    "EnableCors DisableCors EnableQuery FromBody FromUri FromQuery FromRoute FromForm FromServices ModelBinder "
    "OverrideAuthorization OverrideActionFilters OverrideExceptionFilters OverrideResultFilters Flags "
    "DefaultValue ValidateModel RequestSizeLimit DisableRequestSizeLimit NonController NonActionAttribute "
    "ControllerAction ActionFilter TestMethod TestClass Test Fact Theory".split()))
_AUTH_BASES = frozenset({"AuthorizeAttribute", "AuthorizationFilterAttribute", "IAuthorizationFilter",
                         "IAsyncAuthorizationFilter", "AuthorizeFilter"})
_FILTER_IFACES = frozenset({"IAuthorizationFilter", "IAsyncAuthorizationFilter", "IActionFilter", "IAsyncActionFilter",
                            "IResultFilter", "IAsyncResultFilter", "IExceptionFilter", "IFilterMetadata"})
_FRAMEWORK_BASES = frozenset({
    "Controller", "ControllerBase", "ApiController", "AsyncController", "Page", "UserControl", "MasterPage",
    "HttpApplication", "PageModel", "ViewComponent", "Hub", "Object", "Attribute", "AuthorizeAttribute",
    "AuthorizationFilterAttribute", "ActionFilterAttribute", "FilterAttribute", "ExceptionFilterAttribute",
    "ResultFilterAttribute", "TypeFilterAttribute", "ServiceFilterAttribute", "ValidationAttribute",
    "RouteFactoryAttribute", "ActionMethodSelectorAttribute", "ActionNameSelectorAttribute",
    "CustomModelBinderAttribute", "ModelBinderAttribute", "HandleErrorAttribute", "RequireHttpsAttribute",
    "OutputCacheAttribute", "AuthorizeFilter"})
# Global filters that are not authorization (never an auth_check).
_NON_AUTH_FILTERS = frozenset({"HandleErrorAttribute", "HandleError", "RequireHttpsAttribute", "RequireHttps",
                               "OutputCacheAttribute", "ValidateAntiForgeryTokenAttribute", "HandleErrorInfoAttribute"})
_BEARER = re.compile(r"\b(UseOAuthBearerAuthentication|UseJwtBearerAuthentication|SuppressDefaultHostAuthentication|"
                     r"HostAuthenticationFilter|AddJwtBearer|AddBearerToken)\b")
_NOT_CALLS = frozenset("if for foreach while switch catch using lock return typeof nameof new sizeof default checked "
                       "unchecked fixed when await nameof base this throw".split())
_REF_DENY = frozenset("ViewBag ViewData TempData Request Response Session Server User Model String Math Convert Url Html "
                      "Path File Directory Environment DateTime Guid ConfigurationManager HttpStatusCode Console Enum "
                      "Int32 Int64 Double Decimal Boolean TimeSpan Encoding Regex StringComparison Cache Application "
                      "Context HttpContext ModelState Thread Task".split())
_EMAIL = re.compile(r"^[^@\s]+@[^@\s]+$")
_SID = re.compile(r"(?i)^S-1-\d+(?:-\d+)+$")


def _identity_like(s: str) -> bool:
    return bool(_EMAIL.match(s) or _SID.match(s))


_USERS_ARG = re.compile(r"\bUsers(\s*:?=\s*)(" + STR + ")")
_ROLES_ARG = re.compile(r"\bRoles(\s*:?=\s*)(" + STR + ")")


def scrub_attribute_args(args: str):
    """R18 for ``[Authorize(...)]`` argument text: ``(clean text, roles, users)``. ``Users = "..."`` becomes a count
    in the text, an email or SID inside ``Roles = "..."`` is dropped and counted, and ``roles`` lists the role names
    that remain. A role such as ``DOMAIN\\Group`` is kept."""
    users = 0

    def users_sub(m):
        nonlocal users
        n = len({p.strip().lower() for p in _unq(m.group(2)).split(",") if p.strip()})
        users += n
        return f'Users{m.group(1)}<{n} named>'

    clean = _USERS_ARG.sub(users_sub, args)
    roles: list = []

    def roles_sub(m):
        nonlocal users
        keep, dropped = [], 0
        for part in (p.strip() for p in _unq(m.group(2)).split(",")):
            if not part:
                continue
            if _identity_like(part):
                dropped += 1
            else:
                keep.append(part)
        users += dropped
        roles.extend(keep)
        return f'Roles{m.group(1)}"{", ".join(keep)}"' if dropped else m.group(0)

    clean = _ROLES_ARG.sub(roles_sub, clean)
    return clean, roles, users


def _is_iface(b: str) -> bool:
    return len(b) > 1 and b[0] == "I" and b[1].isupper()


def _bases(cls) -> list[str]:
    """Last name segments of a class's base list (``System.Web.UI.Page, IFoo`` gives ``Page``, ``IFoo``)."""
    return [b.strip().split("<")[0].rsplit(".", 1)[-1] for b in (cls.base or "").split(",") if b.strip()]


def _unresolved(bases, by_name, seen=()) -> bool:
    """True when a non-interface base is neither a framework type nor a class of this file (that has resolved bases)."""
    for b in bases:
        if _is_iface(b) or b in _FRAMEWORK_BASES:
            continue
        c = by_name.get(b)
        if c is None or b in seen or _unresolved(_bases(c), by_name, seen + (b,)):
            return True
    return False


def inherits_detail(cls, classes) -> dict:
    """``inherits`` (base list) and ``base_external`` for the entry_point of a controller action."""
    bases = _bases(cls)
    if not bases:
        return {}
    return {"inherits": bases, "base_external": _unresolved(bases, {c.name: c for c in classes})}


# --------------------------------------------------------------------------- arguments

_NAMED = re.compile(r"^([A-Za-z_]\w*)\s*(=|:)(?![=:])\s*(.+)$", re.S)
_DOTTED = re.compile(r"^[A-Za-z_]\w*(?:\s*\.\s*[A-Za-z_]\w*)*$")
_NUMBER = re.compile(r"^[-+]?\d[\w.]*$")


def _classify(expr: str):
    """(kind, string value or None, reference or None); kind is literal | const | secret | expression."""
    e = expr.strip()
    if _STR_CHAIN.match(e):
        value = "".join(_unq(m.group(0)) for m in _STR_RX.finditer(e))
        if find_secret_shapes(value):
            return "secret", None, None
        return "literal", value, None
    if _NUMBER.match(e) or e in ("true", "false", "null") or re.match(r"^typeof\s*\(", e):
        return "literal", None, None
    if _DOTTED.match(e):
        ref = re.sub(r"\s+", "", e)
        return ("secret" if never_record_value(ref.rsplit(".", 1)[-1]) else "const"), None, ref
    return "expression", None, None


def _namespace(qualifier: str, usings: set, is_api: bool, core: bool) -> str | None:
    """Which ``AuthorizeAttribute`` an ``[Authorize]`` is: qualified name first, then the ``using`` that fits the class."""
    if qualifier:
        return qualifier
    if core and "Microsoft.AspNetCore.Authorization" in usings:
        return "Microsoft.AspNetCore.Authorization"
    http, mvc = "System.Web.Http" in usings, "System.Web.Mvc" in usings
    if is_api and http:
        return "System.Web.Http"
    if not is_api and mvc:
        return "System.Web.Mvc"
    if http != mvc:
        return "System.Web.Http" if http else "System.Web.Mvc"
    return None


def _use_detail(norm: str, qualifier: str, args_text, scope: str, applies_to: str, usings, is_api, core) -> dict:
    args = _split_args(args_text or "")
    kinds, refs = [], []
    detail: dict = {"scope": scope, "arity": len(args), "applies_to": applies_to}
    roles: list[str] = []
    users = 0
    positional = 0
    role_set = False
    for a in args:
        nm = _NAMED.match(a)
        name, expr = (nm.group(1), nm.group(3)) if nm else (None, a)
        kind, value, ref = _classify(expr)
        kinds.append(kind)
        if ref:
            refs.append(ref)
        is_role = (name == "Roles") or (name is None and positional == 0 and norm != "authorize")
        if name is None:
            positional += 1
        if is_role and not role_set:
            role_set = True
            detail["role_arg"] = "named" if name else "positional"
            if kind == "literal" and value is not None:
                for part in (p.strip() for p in value.split(",")):
                    if not part:
                        continue
                    if _identity_like(part):
                        users += 1
                    else:
                        roles.append(part)
            elif kind == "const":
                detail["role_ref"] = ref
            elif kind == "expression":
                detail["role_ref"] = "expression"
        elif name == "Users":
            if kind == "literal" and value is not None:
                users += len({p.strip().lower() for p in value.split(",") if p.strip()})
            elif kind == "const":
                detail["users_ref"] = ref
    if roles:
        detail["role"] = roles[0] if len(roles) == 1 else sorted(set(roles))
    if users:
        detail["users_named"] = users
    detail["arg_kinds"] = kinds
    if refs:
        detail["arg_refs"] = refs
    ns = _namespace(qualifier, usings, is_api, core) if norm == "authorize" else (qualifier or None)
    if ns:
        detail["namespace"] = ns
    return detail


# --------------------------------------------------------------------------- per-file Facts

_CTRL_ATTR_API = "apicontroller"


def _is_controller(c, bases, attrs, mvc_using: bool, core: bool) -> bool:
    if core:
        is_api = any(attr_key(a[0]) == _CTRL_ATTR_API for a in attrs)
        return bool(is_api or c.name.endswith("Controller") or re.search(r"\b(?:Controller|ControllerBase)\b", c.base or ""))
    return any(b.endswith("Controller") for b in bases) or (c.name.endswith("Controller") and mvc_using)


_OVERRIDES = re.compile(
    r"(?:override|virtual|public|protected)\s+(?:async\s+)?[\w<>\.\[\]\?]+\s+"
    r"(?:AuthorizeCore|OnAuthorization|OnAuthorizationAsync|IsAuthorized)\s*\(")


def _class_body(blank: str, c) -> str:
    i = blank.find("{", c.pos)
    if i < 0:
        return ""
    j = _match_close(blank, i)
    return blank[i:j if j > 0 else len(blank)]


def file_facts(stack_id: str, path: str, ctx, classes, methods, core: bool = False):
    """Raw guard Facts of one C# file. ``methods`` is the list of ``(match, class, attrs)`` triples of ``find_methods``."""
    t = ctx.t
    if not t.strip():
        return
    blank = _blanked(ctx)
    usings = set(_USING.findall(t))
    mvc_using = bool(_MVC_USING.search(t))
    by_name = {c.name: c for c in classes}
    meta = {}
    for c in classes:
        bases = _bases(c)
        astart, araw = _attrs_before(t, c.pos)
        uses = _attr_uses(astart, araw)
        ctrl = _is_controller(c, bases, [(u[0],) for u in uses], mvc_using, core)
        is_api = "ApiController" in bases or any(attr_key(u[0]) == _CTRL_ATTR_API for u in uses)
        meta[id(c)] = (ctrl, is_api, uses)
        if ctrl:
            yield Fact.make("controller_class", stack_id, path, ctx.line(c.pos), c.name,
                            base_list=bases, base_external=_unresolved(bases, by_name))
            yield from _uses(stack_id, path, ctx, uses, "class", c.name, usings, is_api, core)
        elif c.name.endswith("Attribute") or any(b.endswith("Attribute") or b in _FILTER_IFACES for b in bases):
            yield Fact.make("guard_class", stack_id, path, ctx.line(c.pos), c.name, base_list=bases,
                            base_external=_unresolved(bases, by_name),
                            overrides_authorization=bool(_OVERRIDES.search(_class_body(blank, c))),
                            authorization_capable=any(b in _AUTH_BASES for b in bases))
    for m, cls, _ in methods:
        if cls is None or "static" in m.group("mods") or id(cls) not in meta or not meta[id(cls)][0]:
            continue
        uses = _attr_uses(m.start("attrs"), m.group("attrs"))
        if any(attr_key(u[0]) == "nonaction" for u in uses):
            continue
        yield from _uses(stack_id, path, ctx, uses, "method", f"{cls.name}.{m.group('name')}", usings,
                         meta[id(cls)][1], core)
    yield from _global_filters(stack_id, path, ctx, usings)
    yield from _calls(stack_id, path, ctx, blank, classes, methods)


def _uses(stack_id, path, ctx, uses, scope, applies_to, usings, is_api, core):
    for written, off, args in uses:
        norm = attr_key(written)
        if norm in _FRAMEWORK_ATTRS:
            continue
        qualifier = written.rsplit(".", 1)[0] if "." in written else ""
        name = written.rsplit(".", 1)[-1]
        name = name[:-9] if name.endswith("Attribute") and len(name) > 9 else name
        yield Fact.make("guard_use", stack_id, path, ctx.line(off), name, attribute=name,
                        **_use_detail(norm, qualifier, args, scope, applies_to, usings, is_api, core))


_GF_ADD = re.compile(r"([A-Za-z_][\w\.]*)\s*\.\s*Add\s*(?:<\s*([\w\.]+)\s*>)?\s*\(\s*(?:new\s+([\w\.]+)|typeof\s*\(\s*([\w\.]+)\s*\))?")


def _global_filters(stack_id, path, ctx, usings):
    """``filters.Add(new X())`` from a method that receives ``GlobalFilterCollection``, ``GlobalFilters.Filters.Add(...)``
    and ``config.Filters.Add(...)``: ``auth_check mechanism=global-filter`` named by the filter type."""
    t = ctx.t
    params = set(re.findall(r"\bGlobalFilterCollection\s+(\w+)", t))
    for m in (_GF_ADD.finditer(t) if "Add" in t else ()):
        recv = re.sub(r"\s+", "", m.group(1))
        if not (recv.rsplit(".", 1)[-1] == "Filters" or recv in params):
            continue
        typ = m.group(2) or m.group(3) or m.group(4)
        if not typ:
            continue
        typ = typ.rsplit(".", 1)[-1]
        if typ in _NON_AUTH_FILTERS:
            continue
        window = t[m.end():m.end() + 300]
        window = window[:window.find(";")] if ";" in window else window
        detail = {"mechanism": "global-filter", "scope": "global"}
        rm = re.search(r"\bRoles\s*=\s*(" + STR + ")", window)
        if rm:
            roles = [p.strip() for p in _unq(rm.group(1)).split(",") if p.strip() and not _identity_like(p.strip())]
            if roles:
                detail["roles"] = roles
        yield Fact.make("auth_check", stack_id, path, ctx.line(m.start()), typ, **detail)
    seen = set()
    for m in _BEARER.finditer(t):
        if m.group(1) not in seen:
            seen.add(m.group(1))
            yield Fact.make("auth_check", stack_id, path, ctx.line(m.start()), m.group(1), mechanism="bearer")


_CALL = re.compile(r"(?<![\w.])(?:(?:this|base)\s*\.\s*)?([A-Za-z_]\w*)\s*\(")
_BARE_CONST = re.compile(r"^[A-Z][A-Z0-9_]{2,}$")


def _const_ref(arg: str) -> str | None:
    a = re.sub(r"\s+", "", arg)
    if _BARE_CONST.match(a):
        return a
    if "." in a and _DOTTED.match(a) and a[0].isupper() and a.split(".", 1)[0] not in _REF_DENY and a.split(".")[0] not in _REF_DENY:
        return a
    return None


def _calls(stack_id, path, ctx, blank, classes, methods):
    """``method_call``: an unqualified (or ``this.``/``base.``) call outside attributes whose arguments hold >= 2
    constant-looking references. Whether the method is an auth method is decided later, over all files."""
    t = ctx.t
    if "(" not in t:
        return
    spans = [(m.start(), m.end()) for m in re.finditer(_ATTR_BLOCK, blank)]
    starts = [s for s, _ in spans]
    mspans = []
    for m, cls, _ in methods:
        i = blank.find("{", m.end())
        if i < 0 or blank.find(";", m.end(), i) >= 0:
            continue
        j = _match_close(blank, i)
        if j > 0:
            mspans.append((i, j, f"{cls.name}.{m.group('name')}" if cls else m.group("name")))
    for m in _CALL.finditer(blank):
        name = m.group(1)
        if name in _NOT_CALLS:
            continue
        k = bisect.bisect_right(starts, m.start()) - 1
        if k >= 0 and spans[k][0] <= m.start() < spans[k][1]:
            continue
        before = blank[max(0, m.start() - 12):m.start()].rstrip()
        if before.endswith("new") or before.endswith("class") or before.endswith("typeof"):
            continue
        close = _match_close(blank, m.end() - 1, "(", ")", 600)
        if close < 0:
            continue
        seg = blank[m.end():close]
        if "," not in seg:
            continue
        refs = [r for r in (_const_ref(a) for a in _split_args(t[m.end():close])) if r]
        if len(refs) < 2:
            continue
        owner = next((q for a, b, q in mspans if a <= m.start() <= b), None)
        if owner is None:
            c = None
            for cl in classes:
                if cl.pos < m.start():
                    c = cl
            owner = c.name if c else ""
        detail = {"arity": len(_split_args(t[m.end():close])), "arg_refs": refs}
        if owner:
            detail["applies_to"] = owner
        yield Fact.make("method_call", stack_id, path, ctx.line(m.start(1)), name, **detail)


# --- constants

_CONST = re.compile(
    r"\b(?:const|static\s+readonly|readonly\s+static)\s+(?:System\.)?[sS]tring\s+([A-Za-z_]\w*)\s*=\s*"
    r"(" + STR + r"(?:\s*\+\s*" + STR + r")*)\s*;")
_DIRECTIVE = re.compile(r"(?m)^[ \t]*#[ \t]*(if|elif|else|endif)\b([^\n]*)")


def _symbols(expr: str) -> tuple:
    return tuple(("!" if neg else "") + name for neg, name in re.findall(r"(!?)\s*([A-Za-z_]\w*)", expr)
                 if name not in ("true", "false", "defined"))


def _if_states(text: str):
    """Offsets and the conditional-compilation symbols in force after each directive line."""
    stack: list = []
    offs, states = [0], [()]
    for m in _DIRECTIVE.finditer(text):
        kind, expr = m.group(1), m.group(2)
        if kind == "if":
            stack.append(_symbols(expr))
        elif kind == "elif" and stack:
            stack[-1] = _symbols(expr)
        elif kind == "else" and stack:
            stack[-1] = ()
        elif kind == "endif" and stack:
            stack.pop()
        offs.append(m.end())
        states.append(tuple(sorted({s for fr in stack for s in fr})))
    return offs, states


def const_facts(stack_id: str, path: str, ctx, classes):
    """``const_def`` for each ``const``/``static readonly`` string with a literal value. A secret (by name or by value
    shape) has no ``value``; neither has a value that looks like an email or a SID, or is longer than 200 characters."""
    t = ctx.t
    if "string" not in t and "String" not in t:
        return
    offs = states = None
    for m in _CONST.finditer(t):
        name = m.group(1)
        cls = None
        for c in classes:
            if c.pos < m.start():
                cls = c
        qualified = f"{cls.name}.{name}" if cls else name
        value = "".join(_unq(x.group(0)) for x in _STR_RX.finditer(m.group(2)))
        detail = {"qualified": qualified}
        if never_record_value(name) or find_secret_shapes(value):
            detail["secret"] = True
        elif not _identity_like(value) and len(value) <= 200:
            detail["value"] = value
        if "#" in t:
            if offs is None:
                offs, states = _if_states(t)
            sym = states[bisect.bisect_right(offs, m.start()) - 1]
            if sym:
                detail["under_if"] = list(sym)
        yield Fact.make("const_def", stack_id, path, ctx.line(m.start(1)), qualified, **detail)


# --------------------------------------------------------------------------- post-pass

_RAW = ("guard_use", "guard_class", "const_def", "method_call", "controller_class")
CANDIDATE_MIN_USES = 3


def _is_test(f: Fact) -> bool:
    return any(k == "test" and v for k, v in f.detail)


def _remake(f: Fact, **changes) -> Fact:
    d = f.detail_dict()
    d.update(changes)
    return Fact.make(f.kind, f.stack, f.path, f.line, f.name, **d)


class _Consts:
    """Constants of the Target by qualified name (``Class.NAME``, last two segments of a reference)."""

    def __init__(self, defs):
        self.by_q: dict = {}
        self.by_bare: dict = {}
        for f in defs:
            d = f.detail_dict()
            q = d.get("qualified") or f.name
            entry = ("secret", None) if d.get("secret") else ("value", d.get("value"))
            self.by_q.setdefault(q, set()).add(entry)
            self.by_bare.setdefault(q.rsplit(".", 1)[-1], set()).add(entry)

    def resolve(self, ref: str):
        """None (not a Target constant), ("secret",), ("ambiguous",), ("value", text or None)."""
        segs = ref.split(".")
        entries = self.by_q.get(".".join(segs[-2:])) if len(segs) >= 2 else self.by_bare.get(segs[0])
        if not entries:
            return None
        if any(e[0] == "secret" for e in entries):
            return ("secret", None)
        vals = {e[1] for e in entries}
        return ("value", next(iter(vals))) if len(vals) == 1 else ("ambiguous", None)


def _roles_in(value: str):
    roles, users = [], 0
    for part in (p.strip() for p in value.split(",")):
        if not part:
            continue
        if _identity_like(part):
            users += 1
        else:
            roles.append(part)
    return roles, users


def promote(facts: list) -> list:
    """Join the raw guard Facts of all files (see the module doc). Pure function of ``facts``; order does not matter."""
    live = [f for f in facts if not _is_test(f)]
    if not any(f.kind in _RAW for f in live):
        return facts
    by: dict = {}
    for f in live:
        by.setdefault(f.kind, []).append(f)
    key = lambda f: f.sort_key()                                    # noqa: E731
    consts = _Consts(by.get("const_def", []))
    replaced: dict = {}                                             # id(old fact) -> new fact
    added: list = []

    # ---- classes: transitive base_external, authorization capability, override inheritance
    ctrl = sorted(by.get("controller_class", []), key=key)
    gcls = sorted(by.get("guard_class", []), key=key)
    bases_of: dict = {}
    for f in ctrl + gcls:
        bases_of.setdefault(f.name, []).append(list(f.detail_dict().get("base_list", [])))

    def external(bases, seen=()):
        for b in bases:
            if _is_iface(b) or b in _FRAMEWORK_BASES:
                continue
            chains = bases_of.get(b)
            if not chains or b in seen or any(external(c, seen + (b,)) for c in chains):
                return True
        return False

    capable = {f.name for f in gcls if f.detail_dict().get("authorization_capable")}
    overrides = {f.name for f in gcls if f.detail_dict().get("overrides_authorization")}
    changed = True
    while changed:
        changed = False
        for f in gcls:
            bl = f.detail_dict().get("base_list", [])
            for flag in (capable, overrides):
                if f.name not in flag and any(b in flag for b in bl):
                    flag.add(f.name)
                    changed = True
    for f in ctrl:
        d = f.detail_dict()
        ext = external(d.get("base_list", []))
        if d.get("base_external") != ext:
            replaced[id(f)] = _remake(f, base_external=ext)
    for f in gcls:
        d = f.detail_dict()
        new = dict(base_external=external(d.get("base_list", [])), authorization_capable=f.name in capable,
                   overrides_authorization=f.name in overrides)
        if any(d.get(k) != v for k, v in new.items()):
            replaced[id(f)] = _remake(f, **new)
    for f in by.get("entry_point", []):
        d = f.detail_dict()
        if d.get("inherits") and d.get("type") == "route" and "base_external" in d:
            ext = external(d["inherits"])
            if d["base_external"] != ext:
                replaced[id(f)] = _remake(f, base_external=ext)

    # ---- guard_use: constants, secrets, classification
    declared = set()
    for f in by.get("context_directive", []):
        d = f.detail_dict()
        if d.get("directive") == "auth_attributes":
            declared |= {attr_key(n) for n in d.get("names", [])}
    gcls_by_key = {}
    for f in gcls:
        gcls_by_key.setdefault(attr_key(f.name), []).append(f)
    ctrl_bases = {}
    for f in ctrl:
        ctrl_bases.setdefault((f.path, f.name), f.detail_dict().get("base_list", []))
    bearer = any(f.detail_dict().get("mechanism") == "bearer" for f in by.get("auth_check", []))

    uses = []
    for f in sorted(by.get("guard_use", []), key=key):
        d = f.detail_dict()
        kinds = list(d.get("arg_kinds", []))
        for ref in d.get("arg_refs", []):
            if never_record_value(ref.rsplit(".", 1)[-1]):          # already a secret argument at extraction
                continue
            r = consts.resolve(ref)
            if r and r[0] == "secret" and "const" in kinds:
                kinds.remove("const")
                kinds.append("secret")
        d["arg_kinds"] = kinds
        rr = d.get("role_ref")
        if rr and rr != "expression" and "role" not in d:
            r = consts.resolve(rr)
            if r and r[0] == "secret":
                d.pop("role_ref")
            elif r and r[0] == "value" and r[1]:
                roles, extra = _roles_in(r[1])
                if roles:
                    d["role"] = roles[0] if len(roles) == 1 else sorted(set(roles))
                if extra:
                    d["users_named"] = d.get("users_named", 0) + extra
        ur = d.get("users_ref")
        if ur:
            r = consts.resolve(ur)
            if r and r[0] == "value" and r[1]:
                d["users_named"] = d.get("users_named", 0) + len({p.strip().lower() for p in r[1].split(",") if p.strip()})
        cls_part = (d.get("applies_to") or "").split(".")[0]
        if d.get("namespace") == "System.Web.Http" and "ApiController" in ctrl_bases.get((f.path, cls_part), []) and bearer:
            d["api_pipeline"] = True
        uses.append((f, d))

    # method-level use overriding a class-level use with a different arity
    class_arity: dict = {}
    for f, d in uses:
        if d.get("scope") == "class":
            class_arity.setdefault((f.path, d["applies_to"], f.name), set()).add(d.get("arity"))
    for f, d in uses:
        if d.get("scope") == "method":
            ar = class_arity.get((f.path, (d.get("applies_to") or "").split(".")[0], f.name))
            if ar and d.get("arity") not in ar:
                d["arity_override"] = True

    external_uses: dict = {}
    for f, d in uses:
        nf = Fact.make(f.kind, f.stack, f.path, f.line, f.name, **d)
        if nf != f:
            replaced[id(f)] = nf
        norm = attr_key(f.name)
        tgt = gcls_by_key.get(norm)
        in_capable = bool(tgt) and any(g.name in capable for g in tgt)
        if norm == "authorize":
            continue
        if in_capable:
            via = "custom"
        elif norm in declared:
            via = "declared"
        elif tgt:
            continue                                                # an in-Target attribute that is not an authorization type
        else:
            external_uses.setdefault(norm, []).append((f, d))
            continue
        overridden = via == "custom" and any(g.name in overrides for g in tgt)
        named_role = d.get("role_arg") == "named" and "role" in d
        named_users = bool(d.get("users_named")) and d.get("role_arg") != "positional"
        role_guard = not overridden and (named_role or named_users)
        ac = {"mechanism": "attribute", "via": via, "scope": d["scope"], "arity": d["arity"],
              "applies_to": d["applies_to"], "role_guard": bool(role_guard)}
        if role_guard and named_role:
            ac["roles"] = d["role"] if isinstance(d["role"], list) else [d["role"]]
        if d.get("users_named"):
            ac["users_named"] = d["users_named"]
        if overridden:
            ac["overrides_authorization"] = True
        added.append(Fact.make("auth_check", f.stack, f.path, f.line, f"[{f.name}]", **ac))

    # ---- guard_candidate: an external attribute used at least three times (guard or not)
    for norm, items in sorted(external_uses.items()):
        if len(items) < CANDIDATE_MIN_USES:
            continue
        first, _ = min(items, key=lambda it: key(it[0]))
        added.append(Fact.make("guard_candidate", first.stack, first.path, first.line, first.name,
                               attribute=first.name, uses=len(items), arity_set=sorted({d.get("arity", 0) for _, d in items})))

    # ---- the framework [Authorize] facts learn their namespace / pipeline from the matching guard_use
    by_site = {}
    for f, d in uses:
        if attr_key(f.name) == "authorize" and d.get("namespace"):
            by_site[(f.path, d.get("applies_to"))] = d
    if by_site:
        for f in by.get("auth_check", []):
            d = f.detail_dict()
            if d.get("mechanism") == "attribute" and "via" not in d:
                u = by_site.get((f.path, d.get("applies_to")))
                if u:
                    changes = {"namespace": u["namespace"]}
                    if u.get("api_pipeline"):
                        changes["api_pipeline"] = True
                    replaced[id(f)] = _remake(f, **changes)

    # ---- auth_method promotion: a method called with >= 2 constants that are also guard-attribute arguments
    guard_refs = {r for _, d in uses for r in d.get("arg_refs", [])}
    calls: dict = {}
    for f in sorted(by.get("method_call", []), key=key):
        calls.setdefault(f.name, []).append(f)
    for name, group in sorted(calls.items()):
        if not any(len(set(f.detail_dict().get("arg_refs", [])) & guard_refs) >= 2 for f in group):
            continue
        for f in group:
            refs = sorted(set(f.detail_dict().get("arg_refs", [])))
            roles, users = [], 0
            for r in refs:
                res = consts.resolve(r)
                if res and res[0] == "value" and res[1]:
                    rs, extra = _roles_in(res[1])
                    roles += rs
                    users += extra
            ac = {"mechanism": "inbody", "via": "call", "role_refs": refs}
            if roles:
                ac["roles"] = sorted(set(roles))
            if users:
                ac["users_named"] = users
            if f.detail_dict().get("applies_to"):
                ac["applies_to"] = f.detail_dict()["applies_to"]
            added.append(Fact.make("auth_check", f.stack, f.path, f.line, f"{name}()", **ac))

    out = [replaced.get(id(f), f) for f in facts]
    out.extend(added)
    return out


def guard_shapes(facts) -> list:
    """Distinct ``(attribute, argument-kind tuple)`` with use counts over Facts as JSON dicts (``facts.json["facts"]``).

    A row is ``{"attribute", "arg_kinds": [...], "arity", "uses", "overrides": n}`` where ``overrides`` counts the
    method-level uses of that shape that override a class-level use of another arity. Sorted by attribute, kinds."""
    rows: dict = {}
    for f in facts:
        if f.get("kind") != "guard_use" or f["detail"].get("test"):
            continue
        d = f["detail"]
        kinds = tuple(d.get("arg_kinds", []))
        r = rows.setdefault((f["name"], kinds), {"attribute": f["name"], "arg_kinds": list(kinds), "arity": d.get("arity", 0),
                                                 "uses": 0, "overrides": 0})
        r["uses"] += 1
        if d.get("arity_override"):
            r["overrides"] += 1
    return [rows[k] for k in sorted(rows)]
