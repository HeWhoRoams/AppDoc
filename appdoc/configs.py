"""Joins of per-file .NET configuration Facts (plan 2.8 W1 and W2; tasks T28.33-T28.43): the build-configuration set,
the transform engine, effective values per configuration, ``overridden_in``, scope rebasing, ``host_auth`` merging.

Everything here reads Facts only (``apply(facts)`` is the one post-pass call in ``extract.py``) and rebuilds Facts with
``Fact.make``, so the cache keeps the raw per-file Facts and warm equals cold. ``facts.dumps`` sorts and deduplicates,
so the order of Facts returned here does not change bytes.

R17: a transform never overwrites the base Fact. Each build configuration gets its own copy of every setting and
access rule of the project-root ``Web.config`` (``config`` = its name). A configuration with no transform file is the
base (``config_status: base``); anything that depends on an operation or locator the engine cannot evaluate is
``unknown_transform`` (value ``unknown``), never the base value. Transforms run on the project-root ``Web.config``
only (publish or package time); a nested ``Web.config`` gets none.
"""
from __future__ import annotations

import json
import re

from . import dotnetcfg
from . import dotnetsec as S
from .facts import Fact

PRODUCTION_DEFAULT = "Release"
_SEG = re.compile(r"location\[[^\]]*\]|[^/]+")
OVERRIDE_OPS = frozenset({"Replace", "Remove", "RemoveAll", "SetAttributes", "RemoveAttributes"})


# ------------------------------------------------------------------ small helpers

def _dir(path: str) -> str:
    return path.rsplit("/", 1)[0] if "/" in path else ""


def _base(path: str) -> str:
    return path.rsplit("/", 1)[-1]


def _is_web(path: str) -> bool:
    return _base(path).lower() == "web.config"


def _within(path: str, folder: str) -> bool:
    return folder == "" or path == folder or path.startswith(folder + "/")


def _d(f: Fact) -> dict:
    return f.detail_dict()


def _remake(f: Fact, **changes) -> Fact:
    d = _d(f)
    named = d.pop("name", None) is not None      # security_setting carries its name in the detail too (see dotnetsec.mk)
    d.update(changes)
    return (S.mk if named else Fact.make)(f.kind, f.stack, f.path, f.line, f.name, **d)


def _ci_unique(names) -> list:
    seen, out = set(), []
    for n in names:
        if n and n.lower() not in seen:
            seen.add(n.lower())
            out.append(n)
    return out


# ------------------------------------------------------------------ the configuration set (R17, T28.33)

def production_config(facts) -> str:
    """The production configuration: ``Production config:`` from ``appdoc-context.md`` or ``Release`` (R17)."""
    for f in facts:
        if f.kind == "context_directive" and _d(f).get("directive") == "production_config" and _d(f).get("value"):
            return _d(f)["value"]
    return PRODUCTION_DEFAULT


def configurations(transform_names, project_configs=(), solution_configs=()) -> list:
    """The configuration names of one web project: transform file names, csproj ``Condition`` groups and the solution's
    ``SolutionConfigurationPlatforms``, de-duplicated case-insensitively (first spelling wins), sorted by name.
    A transform file alone is not a configuration: the caller passes transform names only for a folder that holds a
    ``Web.config``."""
    return sorted(_ci_unique(list(transform_names) + list(project_configs) + list(solution_configs)),
                  key=lambda n: (n.lower(), n))


# ------------------------------------------------------------------ the engine (T28.34, T28.35)

def _fields_of_fact(f: Fact, loc) -> dict:
    d = _d(f)
    return {"effect": d["effect"], "roles": list(d.get("roles", [])), "anon": bool(d.get("anon")),
            "all": bool(d.get("all")), "users_named": int(d.get("users_named") or 0),
            "verbs": list(d.get("verbs", [])), "domain": bool(d.get("domain_qualified")), "line": f.line,
            "file": d.get("file", f.path), "loc": loc, "keep": {k: d[k] for k in ("allow_override", "inherit_in_child_apps")
                                                              if k in d}}


def apply_transforms(settings: dict, rules: list, transforms: list, scope_attrs: "dict | None" = None):
    """Apply one configuration's transforms (``config_transform`` detail dicts with ``line`` and ``file``, in document
    order) to the base. ``settings`` is ``{name: (value, line)}``; ``rules`` a list of rule dicts (``loc`` is the raw
    ``location@path`` or ``None``). Returns ``(settings, rules, statuses)``: ``settings`` is
    ``{name: (value, line, status, reason)}``, ``rules`` the effective list in order, ``statuses`` ``{loc: (status,
    reason)}`` per rule scope. Pure; the inputs are not changed."""
    eff = {n: (tuple(t) + ("base", None))[:4] for n, t in settings.items()}
    scopes: dict = {}
    for r in rules:
        scopes.setdefault(r["loc"], []).append(dict(r))
    status: dict = {}

    def mark(loc, st, reason=None):
        if loc == "*":
            for k in list(scopes):
                if k is not None:
                    mark(k, st, reason)
            return
        cur = status.get(loc)
        if cur and cur[0] == "unknown_transform":
            return
        status[loc] = (st, reason if st == "unknown_transform" else None)
        scopes.setdefault(loc, scopes.get(loc, []))

    def unknown_settings(prefix, reason):
        for n in eff:
            if S.under(S.BY_NAME[n][1], prefix):
                eff[n] = ("unknown", eff[n][1], "unknown_transform", reason)

    for t in transforms:
        segs = tuple(_SEG.findall(t["target_path"]))
        loc = None
        rest = segs
        if segs and segs[0].startswith("location["):
            loc, rest = segs[0][len("location["):-1], segs[1:]
        reason = t.get("unsupported_reason") or "unsupported"
        op = t["operation"]
        payload = {a.rsplit(":", 1)[0]: a.rsplit(":", 1)[1] for a in t.get("attributes", [])}
        prules = [dict(json.loads(x), file=t.get("file")) for x in t.get("rules", [])]
        arglist = t.get("arglist") or []
        is_auth_scope = (loc is not None or bool(rest)) and rest in ((), ("system.web",), ("system.web", "authorization")) or \
            (len(rest) == 3 and rest[:2] == ("system.web", "authorization") and rest[2] in S.RULE_NAMES)
        if not t.get("supported"):
            if loc is None and rest:
                unknown_settings(rest, reason)
            if is_auth_scope:
                mark(loc, "unknown_transform", reason)
            continue
        if loc is None and rest:
            _apply_settings(eff, rest, op, arglist, payload)
        if is_auth_scope:
            _apply_rules(scopes, status, mark, loc, rest, op, arglist, prules)
    out = []
    for k, lst in scopes.items():
        out.extend(lst)
    return eff, out, status


def _apply_settings(eff, rest, op, arglist, payload):
    affected = [n for n in eff if S.under(S.BY_NAME[n][1], rest)]
    if not affected:
        return

    def set_(n, value):
        eff[n] = (value, eff[n][1], "transformed", None)

    def unk(n, reason):
        eff[n] = ("unknown", eff[n][1], "unknown_transform", reason)

    if op in ("Remove", "RemoveAll"):
        for n in affected:
            set_(n, "absent")
    elif op == "Replace":
        for n in affected:
            set_(n, payload.get(n, "absent"))
    elif op == "Insert":
        if all(eff[n][0] == "absent" for n in affected):
            for n in affected:
                set_(n, payload.get(n, "absent"))
        else:
            for n in affected:
                unk(n, "duplicate_element")
    elif op in ("SetAttributes", "RemoveAttributes"):
        for n in affected:
            _, path, attr, kind = S.BY_NAME[n]
            if path != rest:
                continue
            if kind in ("machinekey", "credentials"):
                unk(n, "attribute_merge")
                continue
            if op == "RemoveAttributes":
                if not arglist or attr in arglist:
                    set_(n, "absent")
            elif (not arglist or attr in arglist) and n in payload:
                set_(n, payload[n])


def _apply_rules(scopes, status, mark, loc, rest, op, arglist, prules):
    cur = scopes.setdefault(loc, [])
    if len(rest) == 3:                                   # one rule element
        eff_name = rest[2]
        idx = [i for i, r in enumerate(cur) if r["effect"] == eff_name]
        if op == "Insert":
            cur.extend(_with_scope(r, loc, cur) for r in prules)
        elif op == "RemoveAll":
            scopes[loc] = [r for r in cur if r["effect"] != eff_name]
        elif not idx:
            mark(loc, "unknown_transform", "no_match")
            return
        elif op == "Remove":
            del cur[idx[0]]
        elif op == "Replace" and prules:
            cur[idx[0]] = _with_scope(prules[0], loc, cur, keep=cur[idx[0]])
        elif op in ("SetAttributes", "RemoveAttributes") and prules:
            _merge_attrs(cur[idx[0]], prules[0], op, arglist)
        else:
            return
        mark(loc, "transformed")
        return
    # authorization, system.web or location level
    if op in ("Remove", "RemoveAll"):
        scopes[loc] = []
    elif op == "Replace":
        scopes[loc] = [_with_scope(r, loc, cur) for r in prules]
    elif op == "Insert":
        if cur:
            mark(loc, "unknown_transform", "duplicate_element")
            return
        scopes[loc] = [_with_scope(r, loc, cur) for r in prules]
    else:
        return
    mark(loc, "transformed")


def _with_scope(r: dict, loc, cur, keep=None) -> dict:
    out = dict(r)
    out.update(loc=loc, file=out.get("file"), tfile=True)
    anchor = keep or (cur[0] if cur else None)
    out["keep"] = dict(anchor["keep"]) if anchor else {}
    out["anchor_line"] = anchor.get("line") if anchor else None
    return out


def _merge_attrs(rule: dict, new: dict, op: str, arglist) -> None:
    attrs = [a for a in new.get("attrs", [])] if op == "SetAttributes" else list(arglist)
    if op == "SetAttributes" and arglist:
        attrs = [a for a in attrs if a in arglist]
    for a in attrs:
        src = new if op == "SetAttributes" else {"anon": False, "all": False, "users_named": 0, "roles": [],
                                                  "domain": False, "verbs": []}
        if a == "users":
            rule.update(anon=src["anon"], all=src["all"], users_named=src["users_named"])
        elif a == "roles":
            rule.update(roles=list(src["roles"]), domain=src["domain"])
        elif a == "verbs":
            rule.update(verbs=list(src["verbs"]))


# ------------------------------------------------------------------ the post-pass

def apply(facts: list) -> list:
    """Post-pass over the combined Facts (one call in ``extract.extract``). Returns the new Fact list."""
    facts = list(facts)
    kinds = {f.kind for f in facts}
    if not kinds & {"security_setting", "access_rule", "config_transform", "host_auth", "config_external"}:
        return facts
    files = {f.path for f in facts if f.kind == "file"}
    web_dirs = sorted({_dir(p) for p in files if _is_web(p)}, key=lambda d: (d.count("/") if d else -1, d))
    roots = [d for d in web_dirs if not any(o != d and _within(d, o) for o in web_dirs)]

    def root_of(path: str):
        best = None
        for r in roots:
            if _within(path, r) and (best is None or len(r) > len(best)):
                best = r
        return best

    def rebase(scope: str, root) -> str:
        if root and (scope == root or scope.startswith(root + "/")):
            return scope[len(root):].lstrip("/")
        return scope

    facts = _adopt_externals(facts, files)
    out: list = []
    by_file: dict = {}                 # web.config path -> (settings facts, rule facts), config "base"
    transforms: dict = {}              # (folder, lower cfg) -> [config_transform Fact]
    transform_files: dict = {}         # folder -> [config names]
    unparsed = {f.path for f in facts if f.kind == "config_unparsed"}
    for p in sorted(files):
        c = dotnetcfg.transform_config_name(p)
        if c:
            transform_files.setdefault(_dir(p), []).append(c)
    projects: dict = {}
    for f in facts:
        if f.kind == "config_transform":
            c = dotnetcfg.transform_config_name(f.path)
            if c:
                transforms.setdefault((_dir(f.path), c.lower()), []).append(f)
        elif f.kind == "project":
            projects.setdefault(_dir(f.path), []).append(f)
        elif f.kind in ("security_setting", "access_rule") and _is_web(f.path) and _d(f).get("config") == "base" \
                and not f.name.startswith(S.EXTRA_PREFIXES):
            by_file.setdefault(f.path, ([], []))[0 if f.kind == "security_setting" else 1].append(f)
    sln_configs = {d: _ci_unique(c for f in fs if _d(f).get("kind") == "solution" for c in _d(f).get("configs", []))
                   for d, fs in projects.items()}
    for path, (sf, rf) in sorted(by_file.items()):
        folder = _dir(path)
        root = root_of(path)
        nested = root is not None and folder != root
        for f in sf + rf:
            if not (nested and f.kind == "security_setting" and _d(f).get("value") == "absent"):
                out.append(_rebased(f, rebase, root))
        if not nested:
            out.extend(_per_configuration(path, folder, sf, rf, root, rebase, transforms, transform_files,
                                          projects, sln_configs, unparsed))
    done = {f for slot in by_file.values() for part in slot for f in part}
    out.extend(f for f in facts if f not in done and f.kind != "host_auth")
    out = _overridden_in(out, transforms)
    if any(f.kind in ("security_setting", "access_rule", "host_auth") for f in facts):
        out.extend(_host_auth(facts, roots, root_of))
    return _lock_reasons(out, root_of)


def _rebased(f: Fact, rebase, root) -> Fact:
    if f.kind != "access_rule":
        return f
    d = _d(f)
    s = rebase(d.get("scope_path", ""), root)
    return f if s == d.get("scope_path") else _remake(f, scope_path=s)


def _per_configuration(path, folder, sf, rf, root, rebase, transforms, transform_files, projects, sln_configs, unparsed):
    base_settings = {f.name: (_d(f)["value"], f.line, _d(f).get("config_status", "base"), _d(f).get("reason"))
                     for f in sf}
    base_rules = [_fields_of_fact(f, _d(f).get("location")) for f in sorted(rf, key=lambda x: _d(x).get("order", 0))]
    proj = projects.get(folder, [])
    lookup_unknown = any(_d(f).get("transform_lookup") == "unknown" for f in proj)
    names = configurations(transform_files.get(folder, []), [c for f in proj for c in _d(f).get("configs", [])],
                           _solution_configs(folder, sln_configs))
    for name in names:
        tfs = sorted(transforms.get((folder, name.lower()), []), key=lambda x: x.line or 0)
        broken = any(_dir(u) == folder and (dotnetcfg.transform_config_name(u) or "").lower() == name.lower()
                     for u in unparsed)
        yield from _emit_config(path, name, base_settings, base_rules, tfs, lookup_unknown or broken, root, rebase)


def _solution_configs(folder: str, sln_configs: dict) -> list:
    return [c for d in sorted(sln_configs, key=lambda x: (len(x), x)) if _within(folder, d) for c in sln_configs[d]]


def _emit_config(path, name, base_settings, base_rules, tfs, unknown_all, root, rebase):
    if unknown_all:
        eff = {n: ("unknown", t[1], "unknown_transform", "transform_lookup") for n, t in base_settings.items()}
        rules = [dict(r) for r in base_rules]
        status = {r["loc"]: ("unknown_transform", "transform_lookup") for r in rules}
    elif not tfs:
        eff = {n: tuple(t) for n, t in base_settings.items()}
        rules = [dict(r) for r in base_rules]
        status = {}
    else:
        eff, rules, status = apply_transforms(base_settings, base_rules,
                                              [dict(_d(t), line=t.line, file=t.path) for t in tfs])
    yield from S.emit_settings(path, eff, name)
    first: dict = {}
    for i, r in enumerate(base_rules):
        first.setdefault(r["loc"], i)
    fallback = min((r["line"] for r in base_rules), default=1)
    # each scope's rules stay together, in the order the scopes first appear in the base (the sort is stable)
    for order, r in enumerate(sorted(rules, key=lambda r: first.get(r["loc"], len(base_rules))), 1):
        st, reason = status.get(r["loc"], ("base", None))
        scope = rebase(S.norm_scope(_dir(path), r["loc"]), root)
        extra = dict(scope_path=scope, order=order, config=name, config_status=st, file=r.get("file") or path)
        extra.update(r.get("keep") or {})
        if r["loc"] is not None:
            extra["location"] = r["loc"]
        if reason:
            extra["reason_codes"] = [reason]
        line = r["line"] if not r.get("tfile") else (r.get("anchor_line") or fallback)
        yield Fact.make("access_rule", S.STACK_ID, path, line, f"{r['effect']} /{scope}",
                        **S.rule_fact_detail(r, **extra))


# ------------------------------------------------------------------ external configuration (T28.32)

def _adopt_externals(facts: list, files: set) -> list:
    """``config_external`` bookkeeping. ``resolved`` is true only when the target file was scanned. A resolved
    ``configSource`` gives the settings under its element the value read from the external section file (the Fact keeps
    the referencing file's path and the element's line; ``reason`` is ``external_file``); an unresolved one makes them
    ``unknown`` with status ``unknown_external``. Rules of an external ``authorization`` file stay Facts of that file."""
    lower = {p.lower(): p for p in files}
    if not any(f.kind == "config_external" for f in facts):
        return facts
    out, ext = [], []
    for f in facts:
        if f.kind == "config_external":
            d = _d(f)
            tgt = lower.get((d.get("target") or "").lower())
            ok = bool(d.get("resolved")) and tgt is not None
            d = {k: v for k, v in d.items() if k != "target"}
            d["resolved"] = ok
            if ok:
                d["target"] = tgt
            f = Fact.make(f.kind, f.stack, f.path, f.line, f.name, **d)
            if f.name.endswith("@configSource"):
                ext.append(f)
        out.append(f)
    settings: dict = {}
    for f in out:
        if f.kind == "security_setting" and _d(f).get("config") == "base":
            settings.setdefault(f.path, {})[f.name] = f
    swap: dict = {}
    for e in ext:
        d = _d(e)
        elem = tuple(d["element"].split("/"))
        for name, s in settings.get(e.path, {}).items():
            if not S.under(S.BY_NAME.get(name, (0, (),))[1], elem):
                continue
            if d.get("resolved"):
                src = settings.get(d["target"], {}).get(name)
                swap[s] = _remake(s, value=src and _d(src)["value"] or "absent", reason="external_file",
                                  secret_location=bool(src and _d(src).get("secret_location")))
            else:
                swap[s] = _remake(s, value="unknown", config_status="unknown_external", reason="external_unresolved",
                                  secret_location=False)
    return [swap.get(f, f) for f in out]


# ------------------------------------------------------------------ overridden_in (T28.36)

def _overridden_in(facts: list, transforms: dict) -> list:
    keys: dict = {}
    for (folder, cfg), tfs in transforms.items():
        for t in tfs:
            d = _d(t)
            if d.get("supported") and d.get("operation") in OVERRIDE_OPS and d.get("match") is not None \
                    and d.get("target_path") in ("appSettings/add", "connectionStrings/add"):
                kind = "config_key" if d["target_path"].startswith("appSettings") else "connection"
                keys.setdefault((folder, kind, d["match"]), set()).add(d["config"])
    if not keys:
        return facts
    out = []
    for f in facts:
        if f.kind in ("config_key", "connection") and _is_web(f.path) and f.stack == "generic":
            cfgs = keys.get((_dir(f.path), f.kind, f.name))
            if cfgs:
                f = _remake(f, overridden_in=sorted(cfgs, key=str.lower))
        out.append(f)
    return out


# ------------------------------------------------------------------ allowOverride (T28.42)

def _below(scope: str, outer: str) -> bool:
    return scope != outer and (outer == "" or scope.startswith(outer + "/"))


def _lock_reasons(facts: list, root_of) -> list:
    """``allowOverride="false"``: nested rules below a locked path are not merged, so the result there is unknown.
    A rule below the locked path, or at it but from another file (a nested ``Web.config``), is ``under_locked_scope``;
    the locking rules of a scope that has such rules are ``locked_with_nested_rules``."""
    rules: dict = {}
    locked: dict = {}
    for f in facts:
        if f.kind == "access_rule":
            d = _d(f)
            key = (root_of(f.path), d.get("config"))
            s, file = d.get("scope_path", "").lower(), d.get("file", f.path)
            rules.setdefault(key, []).append((s, file))
            if d.get("allow_override") is False:
                locked.setdefault(key, {}).setdefault(s, set()).add(file)
    if not locked:
        return facts

    def inside(s, file, L, files):
        return _below(s, L) or (s == L and file not in files)

    out = []
    for f in facts:
        if f.kind == "access_rule":
            d = _d(f)
            key = (root_of(f.path), d.get("config"))
            s, file = d.get("scope_path", "").lower(), d.get("file", f.path)
            codes = set(d.get("reason_codes", []))
            if any(inside(s, file, L, fs) for L, fs in locked.get(key, {}).items()):
                codes.add("under_locked_scope")
            if d.get("allow_override") is False and any(inside(o, of, s, locked[key][s]) for o, of in rules[key]):
                codes.add("locked_with_nested_rules")
            if codes != set(d.get("reason_codes", [])):
                f = _remake(f, reason_codes=sorted(codes))
        out.append(f)
    return out


# ------------------------------------------------------------------ host_auth (T28.38)

def _host_auth(facts: list, roots, root_of) -> list:
    """One ``host_auth`` per web application root, merged from the raw evidence: an ``anonymousAuthentication`` literal
    in a read config (``source: config``), OWIN middleware calls or ``Microsoft.Owin`` packages, IIS authorization
    rules, and the csproj's IIS Express values (disclosed as ``csproj_dev_only``, never used for reach)."""
    raw = [f for f in facts if f.kind == "host_auth"]
    owin_pkgs = [f for f in facts if f.kind == "dependency" and f.name.lower().startswith("microsoft.owin")]
    express = [f for f in facts if f.kind == "project" and _d(f).get("iis_express")]
    files = sorted({f.path for f in facts if f.kind == "file"})
    groups: dict = {}

    def group(path):
        r = root_of(path)
        key = r if r is not None else (roots[0] if roots else "")
        return groups.setdefault(key, {"iis": set(), "authz": False, "owin": False, "express": False, "anchor": None})

    for r in roots:
        groups[r] = {"iis": set(), "authz": False, "owin": False, "express": False, "anchor": None}
    for f in raw:
        g, d = group(f.path), _d(f)
        if d.get("iis_anonymous"):
            g["iis"].add(d["iis_anonymous"])
        g["authz"] = g["authz"] or bool(d.get("iis_authorization_present"))
        g["owin"] = g["owin"] or bool(d.get("owin_auth"))
        g["anchor"] = g["anchor"] or (f.path, f.line)
    for f in owin_pkgs:
        g = group(f.path)
        g["owin"], g["anchor"] = True, g["anchor"] or (f.path, f.line)
    for f in express:
        group(f.path)["express"] = True
    out = []
    for r, g in sorted(groups.items()):
        web = next((p for p in files if _is_web(p) and _dir(p) == r), None)
        anchor = (web, 1) if web else g["anchor"]
        if anchor is None:
            continue
        anon = next(iter(g["iis"])) if len(g["iis"]) == 1 else "unknown"
        source = "config" if anon != "unknown" else ("csproj_dev_only" if g["express"] else "none")
        out.append(Fact.make("host_auth", S.STACK_ID, anchor[0], anchor[1] or 1, "host", iis_anonymous=anon,
                             source=source, owin_auth=g["owin"], iis_authorization_present=g["authz"]))
    return out
