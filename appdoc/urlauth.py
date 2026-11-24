"""URL authorization evaluated as a chain (T28.62, plan 2.8 W4 step 2).

Pure and stdlib only: no I/O, no imports from appdoc. It reads ``access_rule`` Fact dicts (``{"kind", "path", "line",
"name", "detail"}``, as in the facts document; a ``Fact`` object is also accepted) and answers one question: for this
principal, verb and URL, does ``<system.web><authorization>`` allow, deny, or is it unknown?

Interface (the caller, ``guard.py``, uses these three names)::

    evaluate(access_rules, url, principal, verb, config) -> UrlResult(result, reasons)
        result   'allow' | 'deny' | 'unknown'
        reasons  list of short strings; the deciding rule ("deny /admin (Web.config order 2)"), "implicit_default",
                 or why the result is unknown ("named_user_rule ...", "unknown_transform ...", "locked ...",
                 "unparsed_config ...", "external_unresolved ...").
    principals_for(access_rules, auth_roles, cap=PRINCIPAL_CAP) -> Principals (a list)
        ['anon', 'auth', 'role:<R>', ...]; every role named in a rule or in ``auth_roles`` (the roles named by auth
        attributes), de-duplicated case-insensitively, sorted, capped at ``cap`` roles. ``.total`` is M (all roles),
        ``.shown`` is N; print "N of M".
    url_chain(access_rules, url, config) -> list of dicts (debugging)
        The merged chain for the URL, nearest first, ending with the implicit ``allow *``. Keys: effect, scope,
        file, order, source ('file' | 'implicit_default'), users, roles, verbs, status.

Arguments. ``access_rules`` is every ``access_rule`` Fact of the Target (other kinds in the list are ignored, except
``config_unparsed`` and ``config_external``, which make the result unknown). ``url`` is a path relative to the web
application root (``/Admin/Users``, ``~/x``; a query or fragment is dropped). ``principal`` is ``anon``, ``auth`` (signed
in, in no role the Target names, not a named user) or ``role:<R>`` (signed in, in role R only). ``verb`` is an HTTP verb
or ``any``; ``any`` evaluates GET and POST and keeps the most permissive result (allow, else unknown, else deny).
``config`` is the build configuration name (``base`` or ``Release``...). A file that has rules for any non-``base``
configuration is a per-configuration file and contributes only that configuration's rules; other files (nested
``Web.config``) contribute their ``base`` rules.

Chain rules. For each config file whose folder is a segment prefix of the URL, deepest folder first: its ``<location>``
blocks whose path is a segment prefix of the URL (more segments first, ties in document order), then the file's own
un-located authorization. ``<clear/>`` and ``<remove/>`` are applied while merging (farthest block first; a clear drops
everything inherited or earlier in the block; a remove drops the earlier rule with the same users/roles/verbs, matched
on the flags, role set, verb set and the named-user count, because user names are never recorded). The implicit machine
rule ``allow *`` is appended. Matching is on segment boundaries, case-insensitive; a ``Web.config`` in ``Areas/X`` applies
to ``/Areas/X/...`` and not to the routed ``/X/...``, while a nested folder config applies to every URL under it.

Evaluation. First matching rule decides. ``?`` matches ``anon``; ``*`` matches everyone; a role entry matches
``role:<R>`` by case-insensitive equality (``auth`` and ``anon`` are in no role); a rule with a verb list matches only
those verbs. A rule naming users that does not otherwise match the principal gives ``unknown`` (a named user could be
the caller). ``unknown`` too when the URL's config depends on an unparsed file or an unresolved ``configSource``, when a
rule in the chain is locked-under (``allowOverride="false"`` above a nested rule), or when the walk reaches a rule whose
``config_status`` is ``unknown_*`` (an unsupported transform or external source) before any rule has decided.
"""

from typing import NamedTuple

PRINCIPAL_CAP = 20
_EFFECTS = ("allow", "deny")
_LOCK_CODES = ("under_locked_scope",)


class UrlResult(NamedTuple):
    result: str
    reasons: list


class Principals(list):
    """The probe set; ``total`` counts every named role, ``shown`` the roles kept (N of M)."""
    total = 0
    shown = 0


# ------------------------------------------------------------------ helpers

def _d(f) -> dict:
    if isinstance(f, dict):
        return f.get("detail") or {}
    return f.detail_dict() if hasattr(f, "detail_dict") else {}


def _kind(f) -> str:
    return f.get("kind") if isinstance(f, dict) else getattr(f, "kind", "")


def _path(f) -> str:
    return (f.get("path") if isinstance(f, dict) else getattr(f, "path", "")) or ""


def _segs(text) -> list:
    """Lower-cased path segments of a URL or scope; ``~/`` and ``/`` leads, query and fragment are dropped."""
    t = (text or "").strip().replace("\\", "/")
    for cut in ("?", "#"):
        t = t.split(cut, 1)[0]
    while t.startswith("~") or t.startswith("/"):
        t = t[1:]
    return [s for s in t.lower().split("/") if s and s != "."]


def _prefix(scope: list, url: list) -> bool:
    return url[:len(scope)] == scope


def _roles(d: dict) -> list:
    return [str(r) for r in (d.get("roles") or [])]


def _key(d: dict) -> tuple:
    return (bool(d.get("anon")), bool(d.get("all")), frozenset(r.lower() for r in _roles(d)),
            frozenset(str(v).upper() for v in (d.get("verbs") or [])), int(d.get("users_named") or 0))


def _file_prefix(d: dict) -> list:
    """The URL prefix of a rule's config file: the scope without the ``location@path`` part."""
    scope = _segs(d.get("scope_path"))
    loc = d.get("location")
    if loc is None:
        return scope
    tail = _segs(loc)
    return scope[:len(scope) - len(tail)] if tail and scope[len(scope) - len(tail):] == tail else scope


def _label(d: dict, rule_name: str) -> str:
    return f"{rule_name} /{d.get('scope_path', '')} ({d.get('file', '?')} order {d.get('order', '?')})"


# ------------------------------------------------------------------ the chain

def _select(access_rules, config):
    """Rules of the configuration, as ``(file, detail dict, fact name)``, sorted by file and order."""
    rules = [(f, _d(f)) for f in access_rules if _kind(f) == "access_rule"]
    cfgs: dict = {}
    for f, d in rules:
        c = str(d.get("config", "base")).lower()
        if c != "base":
            cfgs.setdefault(d.get("file") or _path(f), set()).add(c)
    want = str(config).lower() if config is not None else "base"
    out = []
    for f, d in rules:
        file = d.get("file") or _path(f)
        use = want if want in cfgs.get(file, ()) else "base"
        if str(d.get("config", "base")).lower() == use:
            out.append((file, d))
    out.sort(key=lambda x: (x[0], x[1].get("order", 0)))
    return out


def _blocks(selected, url):
    """Blocks that apply to the URL, nearest first: ``[(file, prefix_len, scope_len, first_order, [rules])]``."""
    by_file: dict = {}
    for file, d in selected:
        by_file.setdefault(file, []).append(d)
    blocks = []
    for file, rules in by_file.items():
        prefix = _file_prefix(rules[0])
        cur = None
        for d in rules:
            loc = d.get("location")
            if cur is None or cur[0] != loc:
                cur = [loc, []]
                blocks.append((file, prefix, _segs(d.get("scope_path")), cur[1]))
            cur[1].append(d)
    applicable = [b for b in blocks if _prefix(b[2], url) and _prefix(b[1], url)]

    def order_key(b):
        located = b[3][0].get("location") is not None
        return (-len(b[1]), 0 if located else 1, -len(b[2]) if located else 0, b[3][0].get("order", 0))
    return sorted(applicable, key=order_key)


def _merge(blocks):
    """Apply ``clear``/``remove`` farthest block first. Returns the effective entries, nearest first."""
    inherited: list = []
    for file, _prefix_, _scope, rules in reversed(blocks):
        cur: list = []
        for d in rules:
            eff = d.get("effect")
            tainted = str(d.get("config_status", "base")).startswith("unknown")
            if eff in _EFFECTS:
                cur.append(d)
            elif tainted:
                cur.append({**d, "effect": "barrier"})       # cannot tell what this clear/remove did
            elif eff == "clear":
                cur, inherited = [], []
            elif eff == "remove":
                k = _key(d)
                cur = [r for r in cur if _key(r) != k]
                inherited = [r for r in inherited if _key(r) != k]
        inherited = cur + inherited
    return inherited


def _implicit() -> dict:
    return {"effect": "allow", "all": True, "scope_path": "", "file": "machine", "order": 0, "_implicit": True}


def _entry(d: dict) -> dict:
    return {"effect": d.get("effect"), "scope": d.get("scope_path", ""), "file": d.get("file"),
            "order": d.get("order"), "source": "implicit_default" if d.get("_implicit") else "file",
            "users": {"anon": bool(d.get("anon")), "all": bool(d.get("all")), "named": int(d.get("users_named") or 0)},
            "roles": _roles(d), "verbs": list(d.get("verbs") or []), "status": d.get("config_status", "base")}


def url_chain(access_rules, url, config="base") -> list:
    """The merged rule chain for the URL, nearest first, ending in the implicit ``allow *`` (debugging aid)."""
    chain = _merge(_blocks(_select(access_rules, config), _segs(url))) + [_implicit()]
    return [_entry(d) for d in chain]


# ------------------------------------------------------------------ evaluation

def _config_blockers(access_rules, url: list, selected) -> list:
    """Reasons that make every answer for the URL unknown: an unparsed config file or an unresolved external section."""
    roots = []                       # (file folder, web-root part) of files known from rules
    for file, d in selected:
        folder = file.rsplit("/", 1)[0].split("/") if "/" in file else []
        pre = _file_prefix(d)
        if len(pre) <= len(folder):
            roots.append(([s.lower() for s in folder[:len(folder) - len(pre)]]))
    out = []
    for f in access_rules:
        k, d = _kind(f), _d(f)
        if k == "config_unparsed":
            reason = "unparsed_config"
        elif k == "config_external" and d.get("resolved") is False and "authorization" in str(
                (f.get("name") if isinstance(f, dict) else getattr(f, "name", "")) or "").lower():
            reason = "external_unresolved"
        else:
            continue
        p = _path(f)
        if k == "config_unparsed" and p.rsplit("/", 1)[-1].lower() != "web.config":
            continue
        folder = [s.lower() for s in (p.rsplit("/", 1)[0].split("/") if "/" in p else [])]
        rel = None
        for r in roots or [[]]:
            if folder[:len(r)] == r:
                rel = folder[len(r):]
                break
        if rel is None or _prefix(rel, url):
            out.append(f"{reason} {p}")
    return out


def _matches(d: dict, principal: str) -> bool:
    if d.get("all"):
        return True
    if principal == "anon":
        return bool(d.get("anon"))
    if principal.startswith("role:"):
        r = principal[5:].lower()
        return any(x.lower() == r for x in _roles(d))
    return False


def _one(access_rules, url: str, principal: str, verb: str, config) -> UrlResult:
    u = _segs(url)
    selected = _select(access_rules, config)
    blockers = _config_blockers(access_rules, u, selected)
    if blockers:
        return UrlResult("unknown", blockers)
    blocks = _blocks(selected, u)
    for _f, _p, _s, rules in blocks:
        for d in rules:
            if any(c in _LOCK_CODES for c in d.get("reason_codes", [])):
                return UrlResult("unknown", [f"locked allowOverride: {_label(d, d.get('effect'))}"])
    verb = verb.upper()
    for d in _merge(blocks) + [_implicit()]:
        eff = d.get("effect")
        status = str(d.get("config_status", "base"))
        if status.startswith("unknown"):
            return UrlResult("unknown", [f"{status} {_label(d, eff)}"])
        if d.get("verbs") and verb not in {str(v).upper() for v in d["verbs"]}:
            continue
        if _matches(d, principal):
            if d.get("_implicit"):
                return UrlResult("allow", ["implicit_default"])
            return UrlResult(eff, [_label(d, eff)])
        if int(d.get("users_named") or 0) > 0:
            return UrlResult("unknown", [f"named_user_rule {_label(d, eff)}"])
    return UrlResult("allow", ["implicit_default"])


def evaluate(access_rules, url, principal, verb, config) -> UrlResult:
    """Allow, deny or unknown for one (principal, verb, URL) under one configuration; see the module docstring."""
    p = str(principal)
    if p.lower() in ("anon", "auth"):
        p = p.lower()
    elif p.lower().startswith("role:"):
        p = "role:" + p[5:]
    if str(verb).lower() != "any":
        return _one(access_rules, url, p, str(verb), config)
    parts = [_one(access_rules, url, p, v, config) for v in ("GET", "POST")]
    results = [r.result for r in parts]
    pick = "allow" if "allow" in results else "unknown" if "unknown" in results else "deny"
    reasons = []
    for v, r in zip(("GET", "POST"), parts):
        reasons += [f"{v}: {x}" for x in r.reasons]
    return UrlResult(pick, reasons)


def principals_for(access_rules, auth_roles=(), cap=PRINCIPAL_CAP) -> Principals:
    """``anon``, ``auth`` and ``role:<R>`` for every role named in a rule or in ``auth_roles``, capped at ``cap``."""
    names: dict = {}
    for f in access_rules:
        if _kind(f) == "access_rule":
            for r in _roles(_d(f)):
                names.setdefault(r.lower(), r)
    for r in auth_roles or ():
        if r and str(r).strip():
            names.setdefault(str(r).strip().lower(), str(r).strip())
    ordered = [names[k] for k in sorted(names)]
    out = Principals(["anon", "auth"] + [f"role:{r}" for r in ordered[:cap]])
    out.total, out.shown = len(ordered), min(len(ordered), cap)
    return out
