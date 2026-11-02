"""ASP.NET Core Stack extractor (controllers, minimal APIs, Razor Pages, EF Core, Dapper).

Reads code files only (``.cs .cshtml .razor``). ``appsettings*.json`` and ``*.csproj`` belong to
``generic``. Regex based and comment aware; never records a secret value.
Shared lexical helpers and the framework independent patterns come from ``aspnet``.
"""

from __future__ import annotations

import re
from urllib.parse import urlsplit

from ..facts import Fact
from .aspnet import (STR, Ctx, _join_route, _safe, _strip_markup_comments, _unq, dotnet_common, error_messages,
                     find_classes, find_methods, first_string_arg)
from .base import Stack, strip_comments

STACK_ID = "aspnet-core"

_CORE_HINT = re.compile(
    r"Microsoft\.AspNetCore|Microsoft\.EntityFrameworkCore|Dapper|\bWebApplication\b|ControllerBase|IHttpClientFactory|"
    r"GetConnectionString|\bMap(?:Get|Post|Put|Delete|Patch|Group|Methods)\s*\(|\bPageModel\b|\bDbContext\b")
_FRAMEWORK_ONLY = re.compile(r"System\.Web\.(?:Mvc|UI|Http|Routing|Security|Optimization)")

_HTTP_ATTRS = {"HttpGet": "GET", "HttpPost": "POST", "HttpPut": "PUT", "HttpDelete": "DELETE",
               "HttpPatch": "PATCH", "HttpHead": "HEAD", "HttpOptions": "OPTIONS"}
_ACTION_RET = re.compile(r"(?:Task\s*<\s*|ValueTask\s*<\s*)?(?:\w+\.)*(?:IActionResult|ActionResult|\w*Result)\b")


def _norm(route: str) -> str:
    return _join_route(re.sub(r"/{2,}", "/", route))


# --------------------------------------------------------------------------- controllers

def _controllers(path, ctx: Ctx, classes):
    for m, cls, attrs in find_methods(ctx, classes):
        if cls is None or "static" in m.group("mods"):
            continue
        cnames = {a for a, _ in cls.attrs}
        is_api = "ApiController" in cnames
        is_ctrl = is_api or cls.name.endswith("Controller") or re.search(r"\b(?:Controller|ControllerBase)\b", cls.base)
        if not is_ctrl or "NonAction" in {a for a, _ in attrs}:
            continue
        verbs, tmpl, has_route_attr = [], None, False
        for a, args in attrs:
            if a in _HTTP_ATTRS:
                verbs.append(_HTTP_ATTRS[a])
                has_route_attr = True
                tm = first_string_arg(args)
                if tm is not None and tmpl is None:
                    tmpl = tm
            elif a == "Route":
                has_route_attr = True
                tm = first_string_arg(args)
                if tm is not None:
                    tmpl = tm
            elif a == "AcceptVerbs":
                verbs += [v.upper() for v in re.findall(r'"(\w+)"', args or "")]
        if not has_route_attr and (is_api or not _ACTION_RET.match(m.group("ret").strip())):
            continue
        prefix = None
        for a, args in cls.attrs:
            if a == "Route":
                prefix = first_string_arg(args)
                break
        ctrl = cls.name[:-len("Controller")] if cls.name.endswith("Controller") else cls.name
        action = m.group("name")
        if tmpl is not None and tmpl.startswith(("/", "~/")):
            route = _norm(tmpl.lstrip("~"))
        elif tmpl is not None or prefix is not None:
            route = _norm(_join_route(prefix or "") + "/" + (tmpl or ""))
        elif is_api:
            route = "/"
        else:
            route = _norm(f"{ctrl}/{action}")
        route = route.replace("[controller]", ctrl).replace("[action]", action)
        yield Fact.make("entry_point", STACK_ID, path, ctx.line(m.start("name")), route, type="route",
                        method=",".join(sorted(set(verbs))) or "ANY", handler=f"{cls.name}.{action}")


def _page_models(path, ctx: Ctx, classes):
    for m, cls, _ in find_methods(ctx, classes):
        if cls is None or not re.search(r"\bPageModel\b", cls.base):
            continue
        hm = re.fullmatch(r"On(Get|Post|Put|Delete|Patch)(\w*?)(?:Async)?", m.group("name"))
        if hm:
            page = path[:-3] if path.lower().endswith(".cshtml.cs") else cls.name
            yield Fact.make("entry_point", STACK_ID, path, ctx.line(m.start("name")), m.group("name"), type="handler",
                            method=hm.group(1).upper(), handler=f"{cls.name}.{m.group('name')}", page=page)


# --------------------------------------------------------------------------- minimal APIs

def _minimal_apis(path, ctx: Ctx):
    t = ctx.t
    groups: dict[str, str] = {}
    for m in re.finditer(r"\b(\w+)\s*=\s*(\w+)\s*\.\s*MapGroup\s*\(\s*(" + STR + r")\s*\)", t):
        groups[m.group(1)] = (groups.get(m.group(2), "") + "/" + _unq(m.group(3)).strip("/")).rstrip("/")

    def prefix_for(pos: int) -> str:
        j = pos
        while j > 0 and t[j - 1].isspace():
            j -= 1
        if j > 0 and t[j - 1] == ")":
            s = max(t.rfind(";", 0, pos), t.rfind("{", 0, pos), t.rfind("}", 0, pos)) + 1
            stmt = t[s:pos]
            pre = ""
            vm = re.match(r"\s*(?:var\s+\w+\s*=\s*)?(\w+)\s*\.", stmt)
            if vm and vm.group(1) in groups:
                pre = groups[vm.group(1)]
            for gm in re.finditer(r"MapGroup\s*\(\s*(" + STR + r")\s*\)", stmt):
                pre += "/" + _unq(gm.group(1)).strip("/")
            return pre
        vm = re.search(r"(\w+)\s*$", t[max(0, j - 60):j])
        return groups.get(vm.group(1), "") if vm else ""

    def handler_after(end: int) -> str:
        tail = t[end:end + 200]
        if re.match(r"\s*,\s*(?:static\s+)?(?:async\s+)?(?:\(|\w+\s*=>|delegate\b)", tail):
            return "(inline)"
        hm = re.match(r"\s*,\s*([A-Za-z_][\w\.]*)\s*[,)]", tail)
        return hm.group(1) if hm else "(inline)"

    for m in re.finditer(r"\.\s*Map(Get|Post|Put|Delete|Patch)\s*\(\s*(" + STR + ")", t):
        route = _norm(prefix_for(m.start()) + "/" + _unq(m.group(2)))
        yield Fact.make("entry_point", STACK_ID, path, ctx.line(m.start()), route, type="route",
                        method=m.group(1).upper(), handler=handler_after(m.end()))
    for m in re.finditer(r"\.\s*MapMethods\s*\(\s*(" + STR + r")\s*,\s*new\s*(?:string)?\s*\[\s*\]\s*\{([^}]*)\}", t):
        verbs = sorted(set(v.upper() for v in re.findall(r'"(\w+)"', m.group(2))))
        yield Fact.make("entry_point", STACK_ID, path, ctx.line(m.start()), _norm(prefix_for(m.start()) + "/" + _unq(m.group(1))),
                        type="route", method=",".join(verbs) or "ANY", handler=handler_after(m.end()))
    for m in re.finditer(r"\.\s*MapControllerRoute\s*\([^;]*?pattern\s*:\s*(" + STR + ")", t):
        yield Fact.make("entry_point", STACK_ID, path, ctx.line(m.start()), _norm(_unq(m.group(1))), type="route",
                        method="ANY", handler="(conventional)")
    for m in re.finditer(r"\.\s*RequireAuthorization\s*\(((?:[^()]|\([^()]*\))*)\)", t):
        args = m.group(1)
        strs = [_unq(x) for x in re.findall(STR, args)]
        detail = dict(mechanism="minimal-api")
        if strs:
            detail["policy"] = strs[0] if len(strs) == 1 else ",".join(sorted(strs))
        yield Fact.make("auth_check", STACK_ID, path, ctx.line(m.start()),
                        _safe(f".RequireAuthorization({' '.join(args.split())})", 120), **detail)
    for m in re.finditer(r"\.\s*AllowAnonymous\s*\(\s*\)", t):
        yield Fact.make("auth_check", STACK_ID, path, ctx.line(m.start()), ".AllowAnonymous()", mechanism="minimal-api")
    for m in re.finditer(r"\bAddPolicy\s*\(\s*(" + STR + r")([^;]*)", t):
        roles = []
        for rm in re.finditer(r"\bRequireRole\s*\(([^)]*)\)", m.group(2)):
            roles += [_unq(x) for x in re.findall(STR, rm.group(1))]
        detail = dict(mechanism="policy", policy=_unq(m.group(1)))
        if roles:
            detail["roles"] = sorted(set(roles))
        yield Fact.make("auth_check", STACK_ID, path, ctx.line(m.start()), _safe(f'AddPolicy("{_unq(m.group(1))}")', 120), **detail)


# --------------------------------------------------------------------------- data / calls / messages

def _data_and_calls(path, ctx: Ctx):
    t = ctx.t
    for m in re.finditer(r"\bclass\s+(\w+Repository)\b", t):
        yield Fact.make("data_access", STACK_ID, path, ctx.line(m.start()), m.group(1), type="repository", operation="access")
    if "Dapper" in t:
        pat = (r"\.\s*(Query\w*|Execute\w*)\s*(?:<[^>()]*>)?\s*\(\s*(" + STR + r")")
        for m in re.finditer(pat, t):
            window = t[m.end():m.end() + 300]
            window = window[:window.find(";")] if ";" in window else window
            v = _unq(m.group(2))
            if re.search(r"StoredProcedure", window) and re.match(r"^[\w\.\[\]]+$", v):
                yield Fact.make("data_access", STACK_ID, path, ctx.line(m.start(2)), v.replace("[", "").replace("]", ""),
                                type="stored_procedure", operation="exec", via="dapper")
    for m in re.finditer(r"\.\s*(?:AddHttpClient|CreateClient)\s*(?:<\s*([\w\.,\s]+?)\s*>)?\s*\(\s*(" + STR + r")?", t):
        name = _unq(m.group(2)) if m.group(2) else (m.group(1).split(",")[-1].strip() if m.group(1) else None)
        if name:
            via = "IHttpClientFactory.CreateClient" if "CreateClient" in m.group(0) else "AddHttpClient"
            yield Fact.make("external_call", STACK_ID, path, ctx.line(m.start()), _safe(name, 200), type="http", via=via)
    for m in re.finditer(r"\bBaseAddress\s*=\s*new\s+Uri\s*\(\s*(" + STR + ")", t):
        sp = urlsplit(_unq(m.group(1)))
        if sp.scheme and sp.netloc:
            yield Fact.make("external_call", STACK_ID, path, ctx.line(m.start(1)),
                            f"{sp.scheme}://{sp.netloc.rsplit('@', 1)[-1]}{sp.path}", type="http", via="BaseAddress")
    for m in re.finditer(r"\"ConnectionStrings:(\w+)\"", t):
        yield Fact.make("connection", STACK_ID, path, ctx.line(m.start()), m.group(1), type="database", secret_location=True)


def _messages(path, ctx: Ctx):
    t = ctx.t
    verbs = r"BadRequest|NotFound|Unauthorized|Conflict|UnprocessableEntity|Forbid|ValidationProblem"
    for m in re.finditer(r"\b(?:(?:Typed)?Results\s*\.\s*)?(?:" + verbs + r")\s*\(\s*(" + STR + ")", t):
        f = _mk(path, ctx, m.start(), _unq(m.group(1)))
        if f:
            yield f
    for m in re.finditer(r"\b(?:(?:Typed)?Results\s*\.\s*)?(?:" + verbs + r")\s*\(\s*new\s*(?:\w+\s*)?\{[^}]*?\b\w+\s*=\s*(" + STR + ")", t):
        f = _mk(path, ctx, m.start(), _unq(m.group(1)))
        if f:
            yield f
    for m in re.finditer(r"\b(?:(?:Typed)?Results\s*\.\s*)?Problem\s*\(((?:[^()]|\([^()]*\))*)\)", t):
        lm = re.search(r"(?:\bdetail\s*:\s*|\btitle\s*:\s*|^\s*)(" + STR + ")", m.group(1))
        if lm:
            f = _mk(path, ctx, m.start(), _unq(lm.group(1)))
            if f:
                yield f


def _mk(path, ctx, off, text):
    text = " ".join(text.split())
    if not re.search(r"[A-Za-z]{3}", text):
        return None
    return Fact.make("message", STACK_ID, path, ctx.line(off), _safe(text, 200), context="error")


# --------------------------------------------------------------------------- Razor

def _page_route(path: str, template: str | None) -> str:
    p = path[:-len(".cshtml")] if path.lower().endswith(".cshtml") else path
    idx = ("/" + p).lower().rfind("/pages/")
    p = ("/" + p)[idx + len("/pages"):] if idx >= 0 else "/" + p
    if p.lower().endswith("/index"):
        p = p[:-len("/index")]
    if template is not None:
        if template.startswith("/"):
            return _norm(template)
        return _norm(p + "/" + template)
    return _norm(p)


def _razor_pages(path, text):
    for m in re.finditer(r"(?m)^[ \t]*@page\b[ \t]*(" + STR + ")?", text):
        line = text.count("\n", 0, m.start()) + 1
        tm = _unq(m.group(1)) if m.group(1) else None
        if path.lower().endswith(".razor"):
            route = _norm(tm) if tm is not None else _norm(path)
            yield Fact.make("entry_point", STACK_ID, path, line, route, type="page", component=True)
        else:
            yield Fact.make("entry_point", STACK_ID, path, line, _page_route(path, tm), type="page", method="GET,POST")


# --------------------------------------------------------------------------- the Stack

class AspNetCoreStack(Stack):
    id = STACK_ID
    extensions = frozenset({".cs", ".cshtml", ".razor"})

    def detect(self, files):
        base = lambda p: p.rsplit("/", 1)[-1]
        proj = sorted(p for p in files if p.lower().endswith(".csproj"))
        entry = sorted(p for p in files if base(p) in ("Program.cs", "Startup.cs"))
        return sorted(proj + entry) if proj and entry else []

    def extract(self, path, text):
        ext = "." + path.rsplit(".", 1)[-1].lower() if "." in path.rsplit("/", 1)[-1] else ""
        if _FRAMEWORK_ONLY.search(text) and "Microsoft.AspNetCore" not in text:
            return
        if ext == ".cs":
            if not _CORE_HINT.search(text):
                return
            ctx = Ctx(strip_comments(text, "c"))
            classes = find_classes(ctx)
            yield from dotnet_common(STACK_ID, path, ctx, web_forms=False)
            yield from error_messages(STACK_ID, path, ctx)
            yield from _controllers(path, ctx, classes)
            yield from _page_models(path, ctx, classes)
            yield from _minimal_apis(path, ctx)
            yield from _data_and_calls(path, ctx)
            yield from _messages(path, ctx)
        elif ext in (".cshtml", ".razor"):
            clean = strip_comments(_strip_markup_comments(text), "c")
            yield from _razor_pages(path, _strip_markup_comments(text))
            ctx = Ctx(clean)
            yield from dotnet_common(STACK_ID, path, ctx, web_forms=False)
            yield from error_messages(STACK_ID, path, ctx)
            yield from _messages(path, ctx)


STACK = AspNetCoreStack()
