"""W4: effective protection per handler (2.8, stream 4E). A post-pass over Facts; it reads no source.

``apply(facts)`` rebuilds the ``entry_point`` Facts of the ASP.NET Stacks with derived detail (``Fact.make``, as the
config-role promotion in ``extract`` does) and returns the whole list. Raw inputs are Facts emitted per file by the
Stacks (``controller_class``, ``guard_use``, ``auth_check``, ``guard_class``, ``guard_candidate``, ``access_rule``,
``host_auth``, ``security_setting``, ``context_directive``, ``external_call``, ``data_access``); the join happens
here, so serial, pooled and cached runs give the same bytes.

Scope (V33). ``guard_mechanism`` is reported for ``aspnet`` and ``aspnet-core``; the URL set, verbs, ``writes`` and
the reach per principal only for ``aspnet``. For ``aspnet-core`` and every other Stack there is no ``reach`` and no
``guard_mechanism: none`` unless no authentication or authorization service token exists anywhere in the Target
(``auth_check mechanism=services``): R20, an absence claim needs a closed world. Only handlers that resolve to a
controller class of the Target (the entry's own file) are evaluated; ``[ChildActionOnly]`` actions get nothing.

Order of the work, one section each: the URL set, the filters (ANDed), the unknowns, verbs and writes, then the reach per
principal, which asks ``urlauth`` for the URL half. ``unknown`` is never collapsed into ``none`` or ``allow``.
"""

from __future__ import annotations

import bisect
import re

from . import urlauth
from .facts import Fact, is_test_data_path

MVC = "aspnet"
CORE = "aspnet-core"

VERBS = ("GET", "HEAD", "POST", "PUT", "PATCH", "DELETE", "OPTIONS")           # the closed list; "any" is the verb-less case
_WRITE_VERBS = frozenset({"POST", "PUT", "PATCH", "DELETE"})
_API_PREFIXES = (("Get", "GET"), ("Post", "POST"), ("Put", "PUT"), ("Delete", "DELETE"), ("Patch", "PATCH"),
                 ("Head", "HEAD"), ("Options", "OPTIONS"))                       # Web API name convention
_WRITE_OPS = frozenset({"insert", "update", "delete", "merge"})
_FILE_WRITE = re.compile(r"^(?:File|Directory)\.(?:Write|Append|Delete|Copy|Move|Create|Replace|Set)")
_RANK = {"allow": 2, "unknown": 1, "deny": 0}
_FRAMEWORK_API_BASE = "ApiController"
_INLINE = frozenset({"role", "identity", "session"})                              # in-body auth_check mechanisms (per line)
_LABELS = ("no_app_restriction", "signed_in_any", "role_restricted", "denied", "unknown")


# --------------------------------------------------------------------------- small helpers

def _is_test(f: Fact) -> bool:
    return any(k == "test" and v for k, v in f.detail)


def _attr_key(name: str) -> str:
    n = name.strip().strip("[]").split("(")[0].rsplit(".", 1)[-1].lower()
    return n[:-9] if n.endswith("attribute") and len(n) > 9 else n


def _as_list(v) -> list:
    if v is None:
        return []
    return list(v) if isinstance(v, (list, tuple)) else [v]


def _and(a: str, b: str) -> str:
    if "deny" in (a, b):
        return "deny"
    if "unknown" in (a, b):
        return "unknown"
    return "allow"


def _permissive(results) -> str:
    return max(results, key=lambda r: _RANK[r]) if results else "unknown"


def _segs(text: str) -> list:
    t = (text or "").strip().replace("\\", "/")
    for cut in ("?", "#"):
        t = t.split(cut, 1)[0]
    while t.startswith("~") or t.startswith("/"):
        t = t[1:]
    return [s for s in t.split("/") if s and s != "."]


def _url(segs) -> str:
    return "/" + "/".join(segs)


def _param(seg: str):
    """``(name, catch_all, constrained, optional)`` for a ``{...}`` route segment; None for anything else."""
    if not (seg.startswith("{") and seg.endswith("}")) or seg.count("{") != seg.count("}"):
        return None
    m = re.match(r"\{(\*?)(\w+)", seg)
    if not m:
        return ("?", False, True, False)
    rest = seg[m.end():-1]
    return (m.group(2), bool(m.group(1)), rest.startswith(":"), rest.endswith("?") or "=" in rest)


# --------------------------------------------------------------------------- the index (one pass over the Facts)

class _Index:
    def __init__(self, facts):
        self.live = [f for f in facts if not _is_test(f)]
        by: dict = {}
        for f in self.live:
            by.setdefault(f.kind, []).append(f)
        self.by = by
        self.classes: dict = {}            # (path, class) -> detail of its controller_class
        self.by_name: dict = {}            # class name -> [(path, detail)] (bases are found by name, across files)
        for f in sorted(by.get("controller_class", []), key=lambda x: x.sort_key()):
            d = f.detail_dict()
            self.classes[(f.path, f.name)] = d
            self.by_name.setdefault(f.name, []).append((f.path, d))
        self.uses: dict = {}               # (path, applies_to) -> [guard_use]
        for f in by.get("guard_use", []):
            self.uses.setdefault((f.path, f.detail_dict().get("applies_to", "")), []).append(f)
        self.at: dict = {}                 # (path, applies_to) -> [auth_check of attribute mechanism]
        self.inline: dict = {}             # path -> [auth_check that sits in a body]
        self.globals: list = []
        self.services = False              # any authentication/authorization service token outside test and fixture paths
        self.filter_provider = False
        self.inbody_calls: dict = {}       # (path, applies_to) -> [auth_check via call]
        for f in by.get("auth_check", []):
            d = f.detail_dict()
            mech = d.get("mechanism")
            if mech == "attribute":
                self.at.setdefault((f.path, d.get("applies_to", "")), []).append(f)
            elif mech == "global-filter":
                self.globals.append(f)
            elif mech == "services":
                if not is_test_data_path(f.path):
                    self.services = True
            elif mech == "filter-provider":
                self.filter_provider = True
            elif mech in _INLINE or (mech == "inbody" and d.get("via") == "body"):
                self.inline.setdefault(f.path, []).append(f)
            elif mech == "inbody":
                self.inbody_calls.setdefault((f.path, d.get("applies_to", "")), []).append(f)
        for lst in self.inline.values():
            lst.sort(key=lambda x: x.line or 0)
        self.guard_classes: dict = {}
        for f in by.get("guard_class", []):
            self.guard_classes.setdefault(_attr_key(f.name), []).append(f.detail_dict())
        self.candidates = {_attr_key(f.name) for f in by.get("guard_candidate", [])}
        self.web_config_unparsed = sorted(f.path for f in by.get("config_unparsed", [])
                                          if f.path.rsplit("/", 1)[-1].lower() == "web.config")
        directive = {}
        for f in by.get("context_directive", []):
            d = f.detail_dict()
            directive[d.get("directive")] = d.get("value")
        self.production = directive.get("production_config")
        self.rules = [f for f in self.live if f.kind in ("access_rule", "config_unparsed", "config_external")]
        rules = [f for f in by.get("access_rule", [])]
        self.rule_scopes = [(_segs(f.detail_dict().get("scope_path")), f.detail_dict()) for f in rules]
        self.configs = sorted({str(f.detail_dict().get("config", "base")) for f in rules} - {"base"}, key=str.lower)
        # every URL prefix at which the URL-authorization chain can change (a rule scope, or the folder of a config file
        # that is unparsed or external): two URLs that match the same prefixes get the same answer, so they share one call
        marks = {tuple(s.lower() for s in sc) for sc, _rd in self.rule_scopes}
        for f in self.rules:
            if f.kind != "access_rule":
                parts = [x.lower() for x in _segs(f.path.rsplit("/", 1)[0] if "/" in f.path else "")]
                marks.update(tuple(parts[k:]) for k in range(len(parts) + 1))
        self.marks = marks
        self.depth = max((len(m) for m in marks), default=0)
        self.owin = any(f.detail_dict().get("owin_auth") is True for f in by.get("host_auth", []))
        self.iis = sorted({str(f.detail_dict().get("iis_anonymous", "unknown")) + "/" + str(f.detail_dict().get("source", "none"))
                           for f in by.get("host_auth", [])})
        self.auth_mode: dict = {}          # config -> authentication mode (closed enumeration, lower case)
        for f in by.get("security_setting", []):
            d = f.detail_dict()
            if f.name == "system.web/authentication@mode" and d.get("value") != "absent":
                self.auth_mode.setdefault(str(d.get("config", "base")).lower(), d.get("value"))
        self.span_ops: dict = {}           # path -> sorted [(line, writes?)] of data_access and external_call Facts
        for f in by.get("data_access", []) + by.get("external_call", []):
            d = f.detail_dict()
            if f.kind == "data_access":
                hit = d.get("operation") in _WRITE_OPS
            else:
                op = str(d.get("operation") or "")
                hit = d.get("type") in ("email", "service") or (d.get("type") == "file" and bool(_FILE_WRITE.match(op)))
            self.span_ops.setdefault(f.path, []).append((f.line or 0, hit))
        for lst in self.span_ops.values():
            lst.sort()
        self.get_writes: dict = {}         # path -> sorted lines of state-change-on-get smells
        for f in by.get("smell", []):
            if f.detail_dict().get("pattern") == "state-change-on-get":
                self.get_writes.setdefault(f.path, []).append(f.line or 0)
        self.entries: dict = {}            # path -> sorted entry lines (span fallback)
        for f in by.get("entry_point", []):
            self.entries.setdefault(f.path, []).append(f.line or 0)
        for lst in self.entries.values():
            lst.sort()
        web_dirs = {f.path.rsplit("/", 1)[0] if "/" in f.path else ""
                    for f in self.live if f.path.rsplit("/", 1)[-1].lower() == "web.config"}
        proj_dirs = {f.path.rsplit("/", 1)[0] if "/" in f.path else ""
                     for f in by.get("project", []) if f.detail_dict().get("kind") == "web"}
        self.web_dirs = sorted(web_dirs, key=lambda p: (len(_segs(p)), p))
        self.proj_dirs = sorted(proj_dirs, key=lambda p: (-len(_segs(p)), p))
        self.routes = [f for f in by.get("entry_point", []) if f.stack == MVC and not _is_test(f)
                       and f.detail_dict().get("type") == "route" and f.detail_dict().get("route_name")]
        self.attr_entries: dict = {}       # (path, handler) -> [entry] of the attribute routes of that action
        for f in by.get("entry_point", []):
            fd = f.detail_dict()
            if fd.get("attr_route") and fd.get("handler"):
                self.attr_entries.setdefault((f.path, fd["handler"]), []).append(f)
        self.page_routes: dict = {}        # physical path (lower case) -> [route URL]
        for f in self.routes:
            h = str(f.detail_dict().get("handler") or "")
            if h.startswith("~") or "/" in h or h.lower().endswith(".aspx"):
                self.page_routes.setdefault("/".join(_segs(h)).lower(), []).append(f.name)

    # -- classes
    def chain(self, path: str, cls: str):
        """The class and every in-Target base class: ``[(path, name, detail, rank)]``, rank 2 for the class, 1 for a base."""
        out, seen, todo = [], set(), [(path, cls, 2)]
        while todo:
            p, n, rank = todo.pop(0)
            if (p, n) in seen:
                continue
            seen.add((p, n))
            d = self.classes.get((p, n))
            if d is None:
                continue
            out.append((p, n, d, rank))
            for b in d.get("base_list", []):
                for bp, _bd in self.by_name.get(b, []):
                    todo.append((bp, b, 1))
        return out

    def is_api(self, chain) -> bool:
        return any(_FRAMEWORK_API_BASE in d.get("base_list", []) for _p, _n, d, _r in chain)

    def web_root(self, path: str) -> list:
        """URL-space root (segments) of a file: the deepest web project folder above it, else the shallowest ``Web.config`` folder."""
        segs = _segs(path)
        for d in self.proj_dirs:
            s = _segs(d)
            if segs[:len(s)] == s:
                return s
        for d in self.web_dirs:
            s = _segs(d)
            if segs[:len(s)] == s:
                return s
        return []


# --------------------------------------------------------------------------- T28.61 the URL set

def _template_urls(template: str, binds: dict):
    """URLs of one route template. ``binds`` maps ``controller``/``action`` to ``(value, default or None)``; any other
    parameter is an extra segment. Returns ``(urls, open)``: the aliases (the full URL, then each shorter URL that
    defaults make equivalent) and whether a leading segment cannot be expanded (``{*path}``, ``{culture}/...``, a
    constrained controller or action)."""
    segs = [s for s in template.strip("/").split("/") if s]
    parsed = [(s, _param(s)) for s in segs]
    last_bound = -1
    for i, (s, p) in enumerate(parsed):
        if p is None or p[0] in binds:
            last_bound = i
    out, open_ = [], False
    for i, (s, p) in enumerate(parsed):
        if p is None:
            out.append((s, None))
        elif p[0] in binds:
            if p[2] or p[1]:
                open_ = True                      # a constraint or catch-all on the controller/action segment
            out.append((binds[p[0]][0], p[0]))
        else:
            if i < last_bound or (p[1] and i < len(parsed) - 1):
                open_ = True                      # a free parameter before a literal or a bound segment: its value is unknown
                out.append((s, "?"))
            else:
                break                             # trailing parameters are extra segments; a prefix rule still matches
    values = [v for v, _k in out]
    urls = [_url(values)]
    while out and out[-1][1] in binds and binds[out[-1][1]][1] is not None \
            and binds[out[-1][1]][1].lower() == out[-1][0].lower():
        out = out[:-1]
        urls.append(_url([v for v, _k in out]))
    return urls, open_


def _url_set(ix: _Index, f: Fact, d: dict, chain):
    """``(urls, open)`` for an action: its attribute routes when it has any ``[Route]``, else the conventional routes
    that can reach it (area-matched), else the Stack's own conventional route as the fallback."""
    ctrl_name = d["handler"].split(".", 1)[0]
    action = d["handler"].split(".", 1)[1]
    ctrl = ctrl_name[:-len("Controller")] if ctrl_name.endswith("Controller") else ctrl_name
    if d.get("attr_route"):
        urls, open_ = set(), False
        for g in ix.attr_entries.get((f.path, d["handler"]), []):
            u, o = _template_urls(g.name, {})
            urls.update(u)
            open_ = open_ or o
        return sorted(urls, key=str.lower), open_
    api = ix.is_api(chain)
    area = str(d.get("mvc_area") or "").lower()
    urls, open_ = set(), False
    for r in ix.routes:
        rd = r.detail_dict()
        if str(rd.get("mvc_area") or "").lower() != area or bool(rd.get("http_route")) != api:
            continue                          # MapHttpRoute templates reach Web API controllers, MapRoute the MVC ones
        template = r.name
        names = {p[0] for p in (_param(s) for s in template.strip("/").split("/") if s) if p}
        h = str(rd.get("handler") or "")
        cdef = adef = None
        if re.match(r"^\w+\.[\w{}]+$", h):
            c, a = h.split(".", 1)
            cdef = c[:-len("Controller")] if c.endswith("Controller") else c
            adef = None if a.startswith("{") else a
        binds = {}
        if "controller" in names:
            binds["controller"] = (ctrl, cdef)
        elif cdef is None or cdef.lower() != ctrl.lower():
            continue
        if "action" in names:
            binds["action"] = (action, adef)
        elif not api and (adef is None or adef.lower() != action.lower()):
            continue
        u, o = _template_urls(template, binds)
        urls.update(u)
        open_ = open_ or o
    if not urls and not open_:
        urls.add(_url(_segs(f.name)))
    return sorted(urls, key=str.lower), open_


# --------------------------------------------------------------------------- T28.63 filters (ANDed) and T28.64 unknowns

class _Filter:
    """Filter-level outcome for one handler: the effective checks, the mechanism list and the unknown reasons."""

    def __init__(self):
        self.checks: list = []             # (rank, family, roles(lower) or None, users, unresolved)
        self.mech: set = set()
        self.reasons: set = set()
        self.unknown = False

    def result(self, principal: str) -> str:
        if self.unknown:
            return "unknown"
        out = "allow"
        for _rank, _family, roles, users, unresolved in self.checks:
            out = _and(out, _check_result(principal, roles, users, unresolved))
        return out


def _check_result(principal: str, roles, users: int, unresolved: bool) -> str:
    """One ``AuthorizeAttribute``-style check. Within one attribute ``Roles`` is OR and ``Roles`` plus ``Users`` are ANDed;
    a named user is no archetype (``auth`` and ``role:R`` are not named users), so ``Users`` denies every archetype."""
    if principal == "anon":
        return "deny"
    if users:
        return "deny"
    if unresolved:
        return "unknown"
    if not roles:
        return "allow"
    if principal.startswith("role:"):
        return "allow" if principal[5:].lower() in roles else "deny"
    return "deny"


def _use_check(d: dict, policy: bool = False):
    """``(roles or None, users, unresolved)`` of one ``Authorize``-family ``guard_use``."""
    roles = [r.lower() for r in _as_list(d.get("role"))]
    kinds = _as_list(d.get("arg_kinds"))
    unresolved = bool(d.get("role_ref") and not roles) or ("users_ref" in d and not d.get("users_named")) \
        or any(k in ("expression", "secret") for k in kinds) or policy
    return (roles or None), int(d.get("users_named") or 0), unresolved


def _filter(ix: _Index, f: Fact, d: dict, chain, stack: str) -> _Filter:
    out = _Filter()
    path, handler = f.path, d["handler"]
    api = ix.is_api(chain)
    allow_anon = False
    override_rank = 0
    if d.get("base_external"):
        out.unknown = True
        out.reasons.add("unresolved_base")
    items = []                                              # (rank, scope key, path)
    for p, n, cd, rank in chain:
        items.append((rank, n, p))
        if cd.get("override_authorization"):
            override_rank = max(override_rank, rank)
        if cd.get("filter_hooks"):
            out.unknown = True
            out.reasons.add("hook_override")
        if cd.get("base_external"):
            out.unknown = True
            out.reasons.add("unresolved_base")
    items.append((3, handler, path))
    if d.get("override_authorization"):
        override_rank = 3
    candidates: list = []
    pending: list = []                                      # (rank, family, roles, users, unresolved, mechanism token)
    for rank, key, p in items:
        for u in ix.uses.get((p, key), []):
            ud = u.detail_dict()
            k = _attr_key(u.name)
            if k == "authorize":
                policy = any(c.detail_dict().get("policy") for c in ix.at.get((p, key), []) if c.line == u.line)
                pending.append((rank, True, *_use_check(ud, policy), "attribute"))
            elif k == "principalpermission":
                out.mech.add("inbody")
                out.unknown = True
                out.reasons.add("inbody_check")
            elif k in ix.candidates:
                candidates.append(u)
        for c in ix.at.get((p, key), []):
            cd = c.detail_dict()
            if c.name == "[AllowAnonymous]":
                allow_anon = True
            elif cd.get("via") in ("custom", "declared"):
                if cd.get("overrides_authorization"):
                    out.unknown = True
                    out.reasons.add("guard_overrides_authorization")
                    pending.append((rank, False, None, 0, True, "attribute"))
                elif cd.get("role_guard"):
                    roles = [r.lower() for r in _as_list(cd.get("roles"))]
                    pending.append((rank, cd.get("via") == "custom", roles or None, int(cd.get("users_named") or 0),
                                    False, "attribute"))
                else:
                    out.unknown = True
                    out.reasons.add("declared_guard_no_args" if cd.get("via") == "declared" else "custom_guard_no_args")
                    pending.append((rank, False, None, 0, True, "attribute"))
    for g in ix.globals:
        gd = g.detail_dict()
        if bool(gd.get("api_pipeline")) != api:
            continue
        k = _attr_key(g.name)
        if k in ("authorize", "authorizefilter"):
            roles = [r.lower() for r in _as_list(gd.get("roles"))]
            pending.append((0, True, roles or None, 0, False, "global-filter"))
        elif k in ix.guard_classes:
            if any(c.get("authorization_capable") for c in ix.guard_classes[k]):
                if any(c.get("overrides_authorization") for c in ix.guard_classes[k]):
                    out.unknown = True
                    out.reasons.add("guard_overrides_authorization")
                roles = [r.lower() for r in _as_list(gd.get("roles"))]
                pending.append((0, False, roles or None, 0, not roles, "global-filter"))
                if not roles:
                    out.unknown = True
                    out.reasons.add("custom_guard_no_args")
        else:
            out.unknown = True
            out.reasons.add("global_filter_unknown")
            out.mech.add("global-filter")
    if candidates:
        out.unknown = True
        out.reasons.add("guard_candidate")
        out.mech.add("attribute")
    if ix.filter_provider:
        out.unknown = True
        out.reasons.add("filter_provider")
    if _inbody(ix, f, d):
        out.mech.add("inbody")
        out.unknown = True
        out.reasons.add("inbody_check")
    if ix.web_config_unparsed and stack == MVC:
        out.unknown = True
        out.reasons.add("config_unparsed")
    if allow_anon:
        out.mech.add("allow_anonymous")
    if override_rank:
        out.mech.add("override_authorization")
    for rank, family, roles, users, unresolved, token in pending:
        if rank < override_rank or (allow_anon and family):
            continue                                        # cleared by [OverrideAuthorization] / disabled by [AllowAnonymous]
        out.checks.append((rank, family, roles, users, unresolved))
        out.mech.add(token)
    if stack == CORE and not out.mech and not out.unknown and ix.services:
        out.unknown = True
        out.reasons.add("auth_services_registered")
    if out.unknown:
        out.mech.add("unknown")
    if not out.mech:
        out.mech.add("none")
    return out


def _span(ix: _Index, f: Fact, d: dict) -> tuple:
    start = f.line or 0
    end = d.get("end_line")
    if not isinstance(end, int) or end < start:
        later = [x for x in ix.entries.get(f.path, []) if x > start]
        end = (later[0] - 1) if later else 10 ** 9
    return start, end


def _inbody(ix: _Index, f: Fact, d: dict) -> bool:
    """An authorization check in the body of the handler (``User.IsInRole``, ``HttpUnauthorizedResult``, a promoted helper)."""
    start, end = _span(ix, f, d)
    if any(start <= (c.line or 0) <= end for c in ix.inline.get(f.path, [])):
        return True
    return bool(ix.inbody_calls.get((f.path, d["handler"])))


# --------------------------------------------------------------------------- T28.66 verbs and writes

def _verbs(f: Fact, d: dict, api: bool):
    """``(verbs, declared)``: the closed verb list of the action and whether an attribute declared it."""
    declared_set = [v for v in str(d.get("method") or "ANY").upper().split(",") if v in VERBS]
    if d.get("method") not in (None, "ANY") and declared_set:
        return sorted(set(declared_set)), not d.get("verb_convention")
    if api:
        name = d["handler"].split(".", 1)[1]
        for prefix, verb in _API_PREFIXES:
            if name.startswith(prefix):
                return [verb], False
    return ["any"], False


def _writes(ix: _Index, f: Fact, d: dict) -> bool:
    start, end = _span(ix, f, d)
    ops = ix.span_ops.get(f.path, [])
    i = bisect.bisect_left(ops, (start, False))
    while i < len(ops) and ops[i][0] <= end:
        if ops[i][1]:
            return True
        i += 1
    return False


def _get_write_hit(ix: _Index, f: Fact) -> bool:
    """A ``state-change-on-get`` smell whose ``[HttpGet]`` line belongs to this action (the nearest entry at or after it)."""
    for line in ix.get_writes.get(f.path, []):
        later = [x for x in ix.entries.get(f.path, []) if x >= line]
        if later and later[0] == (f.line or 0) and (f.line or 0) - line <= 15:
            return True
    return False


def _state_changing(verbs, writes: bool) -> str:
    if verbs == ["any"]:
        return "true" if writes else "unknown"
    if set(verbs) & _WRITE_VERBS:
        return "true"
    return "true" if writes else "false"


# --------------------------------------------------------------------------- T28.65 reach per principal

def _mechanism_url(ix: _Index, urls) -> bool:
    """True when a rule that restricts (a deny, roles or named users) covers one of the action's URLs."""
    segs = [[s.lower() for s in _segs(u)] for u in urls]
    for scope, rd in ix.rule_scopes:
        if rd.get("effect") != "deny" and not rd.get("roles") and not rd.get("users_named"):
            continue
        sc = [s.lower() for s in scope]
        if any(u[:len(sc)] == sc for u in segs):
            return True
    return False


def _prod_config(ix: _Index) -> str:
    names = {c.lower(): c for c in ix.configs}
    if ix.production and str(ix.production).lower() in names:
        return names[str(ix.production).lower()]
    return names.get("release", "base")


class _Reach:
    def __init__(self, ix: _Index):
        self.ix = ix
        self._memo: dict = {}
        roles = set()
        for f in ix.by.get("guard_use", []):
            roles.update(_as_list(f.detail_dict().get("role")))
        for f in ix.by.get("auth_check", []):
            roles.update(_as_list(f.detail_dict().get("roles")))
        self.principals = urlauth.principals_for(ix.rules, sorted(roles))

    def url(self, url: str, principal: str, verb: str, config: str):
        segs = [x.lower() for x in _segs(url)]
        sig = tuple(tuple(segs[:i]) for i in range(min(len(segs), self.ix.depth) + 1) if tuple(segs[:i]) in self.ix.marks)
        k = (sig, principal, verb, config)
        if k not in self._memo:
            self._memo[k] = urlauth.evaluate(self.ix.rules, url, principal, verb, config)
        return self._memo[k]

    def url_result(self, urls, open_, verbs, principal: str, config: str):
        if open_:
            return "unknown", {"url_set_open"}
        results, reasons = [], set()
        for u in urls:
            for v in (["any"] if verbs == ["any"] else verbs):
                r = self.url(u, principal, v, config)
                results.append(r.result)
                if r.result == "unknown":
                    for text in r.reasons:
                        code = re.sub(r"^(?:GET|POST): ", "", text).split(" ", 1)[0]
                        if code:
                            reasons.add(code)
        return _permissive(results), reasons


def _label(reach: dict, roles_allowed, owin_none: bool) -> str:
    if owin_none:
        return "unknown"
    if reach["anon"] == "allow":
        return "no_app_restriction"
    if reach["auth"] == "allow":
        return "signed_in_any"
    if roles_allowed:
        return "role_restricted"
    if "unknown" in reach.values():
        return "unknown"
    return "denied"


def _reach_for(ix: _Index, rc: _Reach, flt: _Filter, urls, open_, verbs, config: str):
    reach, reasons = {}, set()
    for p in rc.principals:
        u, rs = rc.url_result(urls, open_, verbs, p, config)
        reach[p] = _and(u, flt.result(p))
        if reach[p] == "unknown":
            reasons |= rs
    roles_allowed = sorted(p[5:] for p in rc.principals if p.startswith("role:") and reach[p] == "allow")
    mode = ix.auth_mode.get(config.lower(), ix.auth_mode.get("base"))
    owin_none = ix.owin and mode == "none"
    return reach, roles_allowed, _label(reach, roles_allowed, owin_none), reasons, owin_none


# --------------------------------------------------------------------------- pages (Web Forms)

def _page_detail(ix: _Index, rc: _Reach, f: Fact, d: dict) -> dict:
    root = ix.web_root(f.path)
    phys = _segs(f.path)[len(root):]
    urls = {_url(phys)}
    for route in ix.page_routes.get("/".join(phys).lower(), []):
        urls.add(_url(_segs(route)))
    urls = sorted(urls, key=str.lower)
    flt = _Filter()
    code = _segs(d.get("codebehind") or "")
    cands = {"/".join(code).lower(), "/".join(root + code).lower()} - {""}
    if any("/".join(_segs(p)).lower() in cands for p in ix.inline):
        flt.unknown = True
        flt.mech.add("inbody")
        flt.reasons.add("inbody_check")
    if ix.web_config_unparsed:
        flt.unknown = True
        flt.reasons.add("config_unparsed")
    if flt.unknown:
        flt.mech.add("unknown")
    if not flt.mech:
        flt.mech.add("none")
    return _finish(ix, rc, flt, urls, False, ["any"], {"url_set": urls})


def _finish(ix: _Index, rc: _Reach, flt: _Filter, urls, open_, verbs, base: dict) -> dict:
    if _mechanism_url(ix, urls):
        flt.mech.discard("none")
        flt.mech.add("url-authorization")
    config = _prod_config(ix)
    reach, roles_allowed, label, url_reasons, owin_none = _reach_for(ix, rc, flt, urls, open_, verbs, config)
    reasons = set(flt.reasons) | url_reasons
    if open_:
        reasons.add("url_set_open")
    if owin_none:
        reasons.add("owin")
    elif ix.owin:
        reasons.add("owin_present")
    if any(s.startswith("unknown/") for s in ix.iis) and label == "no_app_restriction":
        reasons.add("iis_anonymous_unknown")
    if any(not s.startswith("unknown/") and not s.endswith("/none") and not s.endswith("/csproj_dev_only") for s in ix.iis):
        reasons.add("host_auth_set")
    if rc.principals.total > rc.principals.shown:
        reasons.add("roles_capped")
    out = dict(base)
    out.update(guard_mechanism=sorted(flt.mech), reach=label, reach_anon=reach["anon"], reach_auth=reach["auth"])
    if roles_allowed:
        out["reach_roles"] = roles_allowed
    if len(ix.configs) > 1:
        by_cfg = []
        for c in ix.configs:
            r, ra, lab, _rs, _o = _reach_for(ix, rc, flt, urls, open_, verbs, c)
            by_cfg.append(f"{c}={lab}")
        out["reach_by_config"] = sorted(by_cfg)
    if reasons:
        out["reasons"] = sorted(reasons)
    return out


# --------------------------------------------------------------------------- the post-pass

def _resolves(ix: _Index, f: Fact, d: dict):
    """The class chain of an entry whose handler is a method of a controller class in the entry's own file, else None."""
    h = str(d.get("handler") or "")
    if d.get("type") != "route" or not re.match(r"^\w+\.\w+$", h) or d.get("route_name"):
        return None
    chain = ix.chain(f.path, h.split(".", 1)[0])
    return chain or None


def apply(facts) -> list:
    """Return ``facts`` with the W4 detail on the entry points of the ``aspnet`` and ``aspnet-core`` Stacks."""
    facts = list(facts)
    if not any(f.kind == "entry_point" and f.stack in (MVC, CORE) for f in facts):
        return facts
    ix = _Index(facts)
    rc = _Reach(ix)
    out = []
    for f in facts:
        if f.kind != "entry_point" or f.stack not in (MVC, CORE) or _is_test(f):
            out.append(f)
            continue
        d = f.detail_dict()
        for k in ("guard_mechanism", "reach", "reach_anon", "reach_auth", "reach_roles", "reach_by_config", "reasons",
                  "state_changing", "verbs", "verbs_declared", "writes", "url_set"):
            d.pop(k, None)
        new = None
        if d.get("type") == "page" and f.stack == MVC and str(f.name).lower().endswith(".aspx"):
            new = _page_detail(ix, rc, f, d)
        else:
            chain = _resolves(ix, f, d)
            if chain and not d.get("child_action"):
                flt = _filter(ix, f, d, chain, f.stack)
                if f.stack == CORE:
                    new = {"guard_mechanism": sorted(flt.mech)}
                    if flt.reasons:
                        new["reasons"] = sorted(flt.reasons)
                else:
                    urls, open_ = _url_set(ix, f, d, chain)
                    verbs, declared = _verbs(f, d, ix.is_api(chain))
                    writes = _writes(ix, f, d)
                    base = {"url_set": "open" if open_ else urls, "verbs": verbs, "verbs_declared": declared,
                            "writes": writes,
                            "state_changing": _state_changing(verbs, writes or _get_write_hit(ix, f))}
                    new = _finish(ix, rc, flt, urls, open_, verbs, base)
        if new:
            d.update(new)
            f = Fact.make(f.kind, f.stack, f.path, f.line, f.name, **d)
        out.append(f)
    return out
