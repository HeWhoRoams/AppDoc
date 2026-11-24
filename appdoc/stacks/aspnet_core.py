"""ASP.NET Core Stack extractor (controllers, minimal APIs, Razor Pages, EF Core, Dapper).

Reads code files only (``.cs .cshtml .razor``). ``appsettings*.json`` and ``*.csproj`` belong to
``generic``. Regex based and comment aware; never records a secret value.
Shared lexical helpers and the framework independent patterns come from ``aspnet``.
"""

from __future__ import annotations

import os
import re
from urllib.parse import urlsplit

from .. import aspnet_guards, scan
from ..facts import Fact
from ..secrets import is_secret_key
from .aspnet import (STR, Ctx, _join_route, _safe, _strip_markup_comments, _unq, dotnet_common, error_messages,
                     find_classes, find_methods, first_string_arg)
from .base import Stack, strip_comments
from . import integrations

STACK_ID = "aspnet-core"

_CORE_HINT = re.compile(
    r"Microsoft\.AspNetCore|Microsoft\.EntityFrameworkCore|Dapper|\bWebApplication\b|ControllerBase|IHttpClientFactory|"
    r"GetConnectionString|\bMap(?:Get|Post|Put|Delete|Patch|Group|Methods)\s*\(|\bPageModel\b|\bDbContext\b|"
    r"\bIActionResult\b|:\s*Controller\b")
_FRAMEWORK_ONLY = re.compile(r"System\.Web\.(?:Mvc|UI|Http|Routing|Security|Optimization)")

_HTTP_ATTRS = {"HttpGet": "GET", "HttpPost": "POST", "HttpPut": "PUT", "HttpDelete": "DELETE",
               "HttpPatch": "PATCH", "HttpHead": "HEAD", "HttpOptions": "OPTIONS"}
_ACTION_RET = re.compile(r"(?:Task\s*<\s*|ValueTask\s*<\s*)?(?:\w+\.)*(?:IActionResult|ActionResult|\w*Result)\b")


def _norm(route: str) -> str:
    return _join_route(re.sub(r"/{2,}", "/", route))


# --------------------------------------------------------------------------- controllers

_STR_AT = re.compile(STR)
_VIEW_CALL = re.compile(r"(?<![\w.])(?:this\s*\.\s*)?View\s*\(")


def _method_body(t: str, start: int) -> tuple[int, str]:
    """(offset, text) of the block or expression body that follows a method signature ending at ``start``."""
    i = start
    while i < len(t) and t[i].isspace():
        i += 1
    if t.startswith("=>", i):
        j = t.find(";", i)
        return i, t[i:len(t) if j < 0 else j]
    if i >= len(t) or t[i] != "{":
        return i, ""
    depth, j = 0, i
    while j < len(t):
        c = t[j]
        if c == '"':
            sm = _STR_AT.match(t, j)
            j = sm.end() if sm else j + 1
            continue
        if c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
            if depth == 0:
                return i, t[i:j]
        j += 1
    return i, t[i:]


def _view_candidates(ctrl_path: str, ctrl: str, view: str):
    """Possible Target-relative view files, deepest project folder first."""
    name = view if view.lower().endswith(".cshtml") else view + ".cshtml"
    segs = ctrl_path.split("/")[:-1]
    for i in range(len(segs), -1, -1):
        d = "/".join(segs[:i])
        pre = d + "/" if d else ""
        if name.startswith(("~/", "/")):
            yield pre + name.lstrip("~/")
        else:
            yield f"{pre}Views/{ctrl}/{name}"
            yield f"{pre}Views/Shared/{name}"


class _Files:
    """The Target's file list, captured by ``detect`` so a controller can find its view."""

    def __init__(self, files):
        self.paths = frozenset(files)
        self.proj_dirs = frozenset(p.rsplit("/", 1)[0] if "/" in p else "" for p in files if p.lower().endswith(".csproj"))

    def __contains__(self, p):
        return p in self.paths


def _project_dir(paths, ctrl_path: str) -> str:
    """Nearest ancestor folder holding a .csproj, else the folder above ``Controllers``/``Quickstart``."""
    segs = ctrl_path.split("/")[:-1]
    if paths is not None:
        for i in range(len(segs), -1, -1):
            d = "/".join(segs[:i])
            if d in paths.proj_dirs:
                return d
    for i, s in enumerate(segs):
        if s.lower() in ("controllers", "quickstart"):
            return "/".join(segs[:i])
    return "/".join(segs)


def _resolve_view(paths, ctrl_path: str, ctrl: str, view: str):
    """(view file path, exists). ``exists`` is None when the Target's file list is unknown."""
    if paths is not None:
        for c in _view_candidates(ctrl_path, ctrl, view):
            if c in paths:
                return c, True
    proj = _project_dir(paths, ctrl_path)
    pre = proj + "/" if proj else ""
    name = view if view.lower().endswith(".cshtml") else view + ".cshtml"
    expected = pre + name.lstrip("~/") if name.startswith(("~/", "/")) else f"{pre}Views/{ctrl}/{name}"
    return expected, (False if paths is not None else None)


def _views(path, ctx: Ctx, m, ctrl, action, handler, route, verbs, paths):
    start, body = _method_body(ctx.t, m.end())
    seen = set()
    for vm in _VIEW_CALL.finditer(body):
        rest = body[vm.end():].lstrip()
        sm = _STR_AT.match(rest)
        view = _unq(sm.group(0)) if sm and not rest.startswith("$") else action
        if view in seen:
            continue
        seen.add(view)
        file, exists = _resolve_view(paths, path, ctrl, view)
        yield Fact.make("entry_point", STACK_ID, path, ctx.line(start + vm.start()), route, type="page",
                        method=",".join(sorted(set(verbs))) or "GET", handler=handler, view=file, exists=exists)


def _controllers(path, ctx: Ctx, classes, paths=None):
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
                        method=",".join(sorted(set(verbs))) or "ANY", handler=f"{cls.name}.{action}",
                        **aspnet_guards.inherits_detail(cls, classes))
        yield from _views(path, ctx, m, ctrl, action, f"{cls.name}.{action}", route, verbs, paths)


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


_EF_HINT = re.compile(r"EntityFrameworkCore|\bDbContext\b|\bDbSet\s*<")
_DBSET = re.compile(r"\bDbSet\s*<\s*([\w.]+)\s*>\s+(\w+)\s*(?:\{|=>|;)")
_EF_QUERY = re.compile(r"(?:\b(\w+)\s*)?\.\s*(Where|ToListAsync|FirstOrDefaultAsync|ExecuteSqlRaw)\s*\(")
_HTTP_VERBS = re.compile(r"\.\s*(SendAsync|PostAsync|GetAsync|GetStringAsync)\s*\(\s*(" + STR + ")?")


def _ef(path, ctx: Ctx):
    t = ctx.t
    if not _EF_HINT.search(t):
        return
    for m in _DBSET.finditer(t):
        yield Fact.make("data_access", STACK_ID, path, ctx.line(m.start()), m.group(2), type="ef", operation="set",
                        entity=m.group(1).rsplit(".", 1)[-1])
    seen = set()
    for m in _EF_QUERY.finditer(t):
        line = ctx.line(m.start(2))
        if line in seen:
            continue
        seen.add(line)
        recv = m.group(1)
        name = recv if recv and m.group(2) != "ExecuteSqlRaw" else m.group(2)
        yield Fact.make("data_access", STACK_ID, path, line, name, type="ef", operation="query")


def _httpclient(path, ctx: Ctx):
    t = ctx.t
    if "HttpClient" not in t and "CreateClient" not in t:
        return
    for m in _HTTP_VERBS.finditer(t):
        verb = m.group(1)
        d = dict(type="http", via="HttpClient")
        if verb != "SendAsync":
            d["method"] = {"PostAsync": "POST"}.get(verb, "GET")
        name = f"HttpClient.{verb}"
        if m.group(2):
            lit = _unq(m.group(2))
            sp = urlsplit(lit)
            if sp.scheme and sp.netloc:
                name = f"{sp.scheme}://{sp.netloc.rsplit('@', 1)[-1]}{sp.path}"
            elif lit and not sp.scheme:
                name = sp.path or name
        yield Fact.make("external_call", STACK_ID, path, ctx.line(m.start()), _safe(name, 200), **d)


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
            yield Fact.make("ui_page", STACK_ID, path, line, path, root=path, route=route)
        else:
            yield Fact.make("entry_point", STACK_ID, path, line, _page_route(path, tm), type="page", method="GET,POST")


# --------------------------------------------------------------------------- MVC view files

_VIEW_SKIP_DIRS = {"components", "editortemplates", "displaytemplates"}


def _view_file(path, text):
    parts = path.split("/")
    low = [p.lower() for p in parts]
    base = parts[-1]
    if "views" not in low[:-1] or base.startswith("_") or re.search(r"(?m)^[ \t]*@page\b", text):
        return
    if _VIEW_SKIP_DIRS & set(low[:-1]):
        return
    folder = parts[-2]
    yield Fact.make("entry_point", STACK_ID, path, 1, path, type="page", method="GET", source="view",
                    controller=None if folder.lower() in ("shared", "views") else folder,
                    view=base[:-len(".cshtml")])


# --------------------------------------------------------------------------- XAML pages

_XAML_ROOT = re.compile(r"<(?![?!/])([\w:.\-]+)((?:\"[^\"]*\"|'[^']*'|[^>\"'])*)>")
_XAML_PAGE = re.compile(r"(?:Shell|Window|Page|\w*Page(?:Base)?)")
_XAML_ROUTED = re.compile(r"<(?:\w+:)?(?:ShellContent|Tab|FlyoutItem|TabBar|ShellItem|ShellSection)\b([^>]*)>")


def _xaml_pages(path, text):
    clean = _strip_markup_comments(text)
    rm = _XAML_ROOT.search(clean)
    if not rm:
        return
    tag, attrs = rm.group(1), rm.group(2)
    local = tag.split(":")[-1]
    if not _XAML_PAGE.fullmatch(local):
        return
    cm = re.search(r'\bx:Class\s*=\s*"([^"]+)"', attrs)
    route = re.search(r'\bRoute\s*=\s*"([^"]+)"', attrs)
    routes = route.group(1) if route else None
    if routes is None and local == "Shell":
        found = sorted({r for blk in _XAML_ROUTED.findall(clean) for r in re.findall(r'\bRoute\s*=\s*"([^"]+)"', blk)})
        routes = ",".join(found) or None
    x_class = cm.group(1) if cm else None
    yield Fact.make("ui_page", STACK_ID, path, clean.count("\n", 0, rm.start()) + 1, x_class or path,
                    x_class=x_class, route=routes, root=tag)


# --------------------------------------------------------------------------- configuration reads

_CFG_RECEIVER = r"(?<![\w])(?:[\w.]*\.)?_?(?:[Cc]onfiguration|[Cc]onfig)\s*\[\s*(" + STR + r")\s*\]"
_CFG_READS = (
    re.compile(_CFG_RECEIVER),
    re.compile(r"\.\s*(?:GetValue|GetRequiredValue)\s*(?:<[^>()]*>)?\s*\(\s*(" + STR + ")"),
    re.compile(r"\.\s*(?:GetSection|GetRequiredSection)\s*\(\s*(" + STR + ")"),
    re.compile(r"\bEnvironment\s*\.\s*GetEnvironmentVariable\s*\(\s*(" + STR + ")"),
)


def _config_reads(path, ctx: Ctx):
    t = ctx.t
    for rx in _CFG_READS:
        for m in rx.finditer(t):
            key = _unq(m.group(1)).strip()
            if not key or "{" in key or len(key) > 200:
                continue
            assigned = rx is _CFG_READS[0] and re.match(r"\s*=(?!=)", t[m.end():])
            yield Fact.make("config_key", STACK_ID, path, ctx.line(m.start()), key, source="code",
                            secret_location=is_secret_key(key), use="define" if assigned else "read",
                            read_kind="env" if rx is _CFG_READS[3] else "file")


def _as_define(f: Fact) -> Fact:
    """A hard-coded literal assigned to a secret-named variable defines the value; it is not a read."""
    return Fact.make(f.kind, f.stack, f.path, f.line, f.name, **{**f.detail_dict(), "use": "define"})


# --------------------------------------------------------------------------- background jobs

_HOSTED_BASE = re.compile(r"\b(?:BackgroundService|IHostedService|IHostedLifecycleService)\b")
# Also matches primary-constructor classes: ``class X(IRepo repo) : BackgroundService``.
_JOB_CLASS = re.compile(
    r"\bclass\s+(\w+)\s*(?:<[^<>{}]*>)?\s*(?:\((?:[^()]|\((?:[^()]|\([^()]*\))*\))*\))?\s*:\s*([^{;]*)")
_CRON_LIT = re.compile(r"[\d*/,\-?LW#A-Za-z]+(?:\s+[\d*/,\-?LW#A-Za-z]+){4,6}")
_RECURRING = re.compile(r"\b(?:RecurringJob|\w*[Rr]ecurringJob\w*)\s*\.\s*AddOrUpdate\s*(?:<[^>()]*>)?\s*\(")


def _split_cs(args: str) -> list[str]:
    out, depth, i, start = [], 0, 0, 0
    while i < len(args):
        c = args[i]
        if c == '"':
            sm = _STR_AT.match(args, i)
            i = sm.end() if sm else i + 1
            continue
        if c in "([{":
            depth += 1
        elif c in ")]}":
            depth -= 1
        elif c == "," and depth == 0:
            out.append(args[start:i].strip())
            start = i + 1
        i += 1
    if args[start:].strip():
        out.append(args[start:].strip())
    return out


def _call_text(t: str, open_idx: int) -> str:
    depth, i = 0, open_idx
    while i < len(t):
        c = t[i]
        if c == '"':
            sm = _STR_AT.match(t, i)
            i = sm.end() if sm else i + 1
            continue
        if c == "(":
            depth += 1
        elif c == ")":
            depth -= 1
            if depth == 0:
                return t[open_idx + 1:i]
        i += 1
    return t[open_idx + 1:]


def _jobs(path, ctx: Ctx):
    t = ctx.t
    for c in _JOB_CLASS.finditer(t):
        bases = re.split(r"\bwhere\b", c.group(2))[0]
        if not _HOSTED_BASE.search(bases) or re.search(r"\babstract\s+(?:(?:partial|sealed)\s+)*$", t[max(0, c.start() - 40):c.start()]):
            continue
        name = c.group(1)
        registered = re.search(r"\bAddHostedService\s*<\s*(?:[\w.]+\.)?" + re.escape(name) + r"\b", t) is not None
        yield Fact.make("entry_point", STACK_ID, path, ctx.line(c.start()), name, type="job", handler=name,
                        schedule=None, enabled=True if registered else None, scheduler="hosted-service")
    for m in _RECURRING.finditer(t):
        parts = _split_cs(_call_text(t, m.end() - 1))
        if not parts:
            continue
        idm = _STR_AT.fullmatch(parts[0])
        sched = next((_unq(p) for p in parts[1:] if _STR_AT.fullmatch(p) and _CRON_LIT.fullmatch(_unq(p).strip())), None)
        if sched is None:
            sched = next((" ".join(p.split()) for p in parts[1:] if re.match(r"Cron\s*\.", p)), None)
        expr = next((p for p in parts[1:] if "=>" in p), "")
        mm = re.findall(r"\.\s*(\w+)\s*(?:<[^>()]*>)?\s*\(", expr)
        handler = (mm[-1] if mm else " ".join(expr.split())[:80]) or "job"
        yield Fact.make("entry_point", STACK_ID, path, ctx.line(m.start()), _unq(idm.group(0)) if idm else handler,
                        type="job", handler=handler, schedule=sched[:120] if sched else None, enabled=True,
                        scheduler="hangfire")


# --------------------------------------------------------------------------- the Stack

_CORE_SDK = re.compile(r"(?i)\bSdk\s*=\s*\"[^\"]*Microsoft\.NET\.Sdk\.(?:Web|Razor)\b|<Sdk\s[^>]*\bName\s*=\s*\"Microsoft\.NET\.Sdk\.(?:Web|Razor)\b")
_CORE_REF = re.compile(r"(?i)<(?:PackageReference|FrameworkReference)\b[^>]*\bInclude\s*=\s*\"Microsoft\.AspNetCore\.")
_MAX_PROJECT_BYTES = 1 << 20


def _is_core_project(root: str, rel: str) -> bool:
    try:
        if os.path.getsize(os.path.join(root, rel)) > _MAX_PROJECT_BYTES:
            return False
        text = scan.read_text(root, rel)[0]
    except OSError:
        return False
    return bool(_CORE_SDK.search(text) or _CORE_REF.search(text))


class AspNetCoreStack(Stack):
    id = STACK_ID
    capabilities = frozenset((
        "auth_check config_key connection const_def controller_class data_access entry_point.route "
        "entry_point.page entry_point.handler entry_point.job external_call guard_candidate guard_class guard_use "
        "message method_call ui_page"
    ).split())
    extensions = frozenset({".cs", ".cshtml", ".razor", ".xaml"})

    def __init__(self):
        self._files = None

    def detect(self, files):
        """Path-only check, used when the Target root is unknown. ``detect_in`` is the real test."""
        self._files = _Files(files)
        base = lambda p: p.rsplit("/", 1)[-1]
        proj = sorted(p for p in files if p.lower().endswith(".csproj"))
        entry = sorted(p for p in files if base(p) in ("Program.cs", "Startup.cs"))
        return sorted(proj + entry) if proj and entry else []

    def detect_in(self, files, root):
        """The ``.csproj`` files that make a web project, plus the ``Program.cs``/``Startup.cs`` of those projects: ``Sdk="Microsoft.NET.Sdk.Web"`` or ``.Razor``, a
        ``Microsoft.AspNetCore.*`` package, or an AspNetCore framework reference. A project plus
        ``Program.cs`` is not enough; a classic ``System.Web`` project belongs to the ``aspnet`` Stack."""
        self._files = _Files(files)
        projects = sorted(p for p in files if p.lower().endswith(".csproj") and _is_core_project(root, p))
        if not projects:
            return []
        all_dirs = {p.rsplit("/", 1)[0] if "/" in p else "" for p in files if p.lower().endswith(".csproj")}
        web_dirs = {p.rsplit("/", 1)[0] if "/" in p else "" for p in projects}

        def owner(p):
            d = p.rsplit("/", 1)[0] if "/" in p else ""
            while d not in all_dirs and d:
                d = d.rsplit("/", 1)[0] if "/" in d else ""
            return d

        entry = [p for p in files if p.rsplit("/", 1)[-1] in ("Program.cs", "Startup.cs") and owner(p) in web_dirs]
        return sorted(projects + entry)

    def extract(self, path, text):
        ext = "." + path.rsplit(".", 1)[-1].lower() if "." in path.rsplit("/", 1)[-1] else ""
        if ext == ".xaml":
            yield from _xaml_pages(path, text)
            return
        if _FRAMEWORK_ONLY.search(text) and "Microsoft.AspNetCore" not in text:
            return
        if ext == ".cs":
            ctx = Ctx(strip_comments(text, "c"))
            classes = find_classes(ctx)
            yield from _jobs(path, ctx)
            yield from _config_reads(path, ctx)
            yield from aspnet_guards.const_facts(STACK_ID, path, ctx, classes)
            if not _CORE_HINT.search(text):
                return
            http_client = list(_httpclient(path, ctx))
            http_lines = {f.line for f in http_client}
            for f in dotnet_common(STACK_ID, path, ctx, web_forms=False):
                # An HttpClient emission at a line supersedes the generic http emission for the same file and line.
                d = dict(f.detail)
                if f.kind == "external_call" and d.get("type") == "http" and "via" not in d and f.line in http_lines:
                    continue
                yield _as_define(f) if f.kind == "config_key" else f
            yield from error_messages(STACK_ID, path, ctx)
            yield from _controllers(path, ctx, classes, self._files)
            yield from _page_models(path, ctx, classes)
            yield from _minimal_apis(path, ctx)
            yield from aspnet_guards.file_facts(STACK_ID, path, ctx, classes, list(find_methods(ctx, classes)), core=True)
            yield from _data_and_calls(path, ctx)
            yield from _ef(path, ctx)
            yield from http_client
            yield from _messages(path, ctx)
            yield from integrations.scan_facts("dotnet", STACK_ID, path, strip_comments(text, "c"))
        elif ext in (".cshtml", ".razor"):
            clean = strip_comments(_strip_markup_comments(text), "c")
            if ext == ".cshtml":
                yield from _view_file(path, text)
            yield from _razor_pages(path, _strip_markup_comments(text))
            ctx = Ctx(clean)
            for f in dotnet_common(STACK_ID, path, ctx, web_forms=False):
                yield _as_define(f) if f.kind == "config_key" else f
            yield from error_messages(STACK_ID, path, ctx)
            yield from _messages(path, ctx)

STACK = AspNetCoreStack()
