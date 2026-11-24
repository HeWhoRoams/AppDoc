"""The `access-model` generated block (template 5.4): a pure function of the Facts document.

`render(doc, unmatched)` writes the application-layer access summary from the Facts alone: the mandatory disclosure line,
the per-configuration columns, the access-rule matrix, the per-area handler counts with the three archetype results
(`anon`, `auth`, `role`), the handlers a reader must look at, the guard attributes and their argument shapes, the role
names and constants referenced by guards, the secret-location table (counts only), a Defaults note and the Stacks that do
or do not report protection.

Nothing here prints a value: role and group names are printed as written (Q25), never a user name, e-mail address, SID,
secret or URL userinfo (R18, R19). The output is deterministic: every list is sorted and every capped list says
"N of M". Standard library only; imports only the layers below it (`fill` calls it and passes the unmatched-rule rows,
computed once in `summary.unmatched_rules`).
"""

from __future__ import annotations

import re

from . import aspnet_guards
from .integration import safe_target
from .textutil import plural

DISCLOSURE = ("Application-layer evaluation only: ASP.NET `<authorization>`, MVC filters and the declared "
              "authentication mode. IIS authentication settings, server-level configuration, network exposure, "
              "group membership and effective permissions are not in the repository.")

RULE_CAP = 40       # access rules and unmatched rules listed
HANDLER_CAP = 60    # state-changing handlers listed that are not role-restricted
FILE_CAP = 60       # files in the secret-location table
SHAPE_CAP = 40      # guard argument shapes listed
PATH_CAP = 10       # `.ashx`/`.asmx`/`.svc` files named

LABELS = ("no_app_restriction", "signed_in_any", "role_restricted", "unknown", "denied")
_LABEL_RANK = {"no_app_restriction": 0, "unknown": 1, "signed_in_any": 2}
_HANDLER_EXT = (".ashx", ".asmx", ".svc")
_AUTH_MODE = "system.web/authentication@mode"
_EMAIL = re.compile(r"[^\s@]+@[^\s@]+")
_SID = re.compile(r"\bS-1-\d+(?:-\d+)+\b", re.I)


# ------------------------------------------------------------------------------------------------- small helpers

def _cell(s) -> str:
    return str(s).replace("|", "\\|")


def _clean(name) -> str:
    """A name as the block prints it: line breaks, pipes and URL userinfo made harmless; an e-mail address or a SID is
    withheld, never printed."""
    s = safe_target(name)
    if _EMAIL.search(s):
        return "(e-mail address withheld)"
    if _SID.search(s):
        return "(SID withheld)"
    return s


def _code(name) -> str:
    return f"`{_clean(name)}`"


def _at(f: dict) -> str:
    return f"`{_clean(f['path'])}:{f['line']}`" if f.get("line") else f"`{_clean(f['path'])}`"


def _live(doc: dict, kind: str) -> list[dict]:
    return [f for f in doc.get("facts") or [] if f["kind"] == kind and not f["detail"].get("test")]


def _of(f: dict) -> tuple:
    return (f["path"], f.get("line") or 0, str(f["name"]))


def _names(items) -> str:
    return ", ".join(f"`{_clean(n)}`" for n in items)


def _n_of_m(shown: int, total: int, noun: str) -> str:
    return f"Listed {shown} of {plural(total, noun)}."


# ------------------------------------------------------------------------------------------------- configurations

def _configurations(doc: dict) -> list[str]:
    seen: dict[str, str] = {}
    for kind in ("security_setting", "access_rule"):
        for f in _live(doc, kind):
            c = str(f["detail"].get("config", "base"))
            if c.lower() != "base":
                seen.setdefault(c.lower(), c)
    for f in _live(doc, "project"):
        for c in f["detail"].get("configs") or []:
            seen.setdefault(str(c).lower(), str(c))
    return sorted(seen.values(), key=lambda c: (c.lower(), c))


def _production(doc: dict, configs: list[str]) -> tuple[str, str]:
    """(the production configuration, how it was chosen): the declared `Production config:` or `Release` (R17); `base`
    when no configuration of that name exists."""
    declared = None
    for f in _live(doc, "context_directive"):
        if f["detail"].get("directive") == "production_config" and f["detail"].get("value"):
            declared = str(f["detail"]["value"])
    want = declared or "Release"
    for c in configs:
        if c.lower() == want.lower():
            return c, "declared in appdoc-context.md" if declared else "default"
    return "base", f"no configuration named {_clean(want)}; base values shown"


def _effective(facts: list[dict], config: str, key) -> list[dict]:
    """For each `key(fact)` group, the Facts of `config` when it has any, else those of `base`: a transform only
    restates what it changes, so a nested folder's rules stay the base ones."""
    by: dict = {}
    for f in facts:
        by.setdefault(key(f), {}).setdefault(str(f["detail"].get("config", "base")).lower(), []).append(f)
    out = []
    for k in sorted(by, key=str):
        g = by[k]
        out += g.get(config.lower()) or g.get("base") or []
    return out


def _rule_key(f: dict):
    return (f["path"], f["detail"].get("scope_path", ""))


def _setting_key(f: dict):
    return (f["path"], f["name"])


def _principal(d: dict) -> str:
    parts = []
    if d.get("all"):
        parts.append("all users (`*`)")
    if d.get("anon"):
        parts.append("anonymous users (`?`)")
    if d.get("roles"):
        parts.append("roles: " + ", ".join(f"`{_clean(r)}`" for r in d["roles"]))
    if d.get("users_named"):
        parts.append(f"users: {d['users_named']} named")
    return "; ".join(parts) or "(not recorded)"


def _rules_for(doc: dict, config: str) -> list[dict]:
    rules = _effective(_live(doc, "access_rule"), config, _rule_key)
    return sorted(rules, key=lambda f: (f["detail"].get("scope_path", "").lower(), f["path"], f["detail"].get("order", 0)))


def _column(doc: dict, config: str) -> dict:
    rules = _rules_for(doc, config)
    modes = _effective([f for f in _live(doc, "security_setting") if f["name"] == _AUTH_MODE], config, _setting_key)
    settings = _effective(_live(doc, "security_setting"), config, _setting_key)
    statuses = {str(f["detail"].get("config_status", "base")) for f in rules + settings}
    unknown = any(s.startswith("unknown") for s in statuses)
    return {"config": config,
            "mode": ", ".join(sorted({str(f["detail"].get("value")) for f in modes})) or "not set",
            "rules": len(rules),
            "unknown": unknown,
            "publish_only": "transformed" in statuses or unknown,
            "signature": (tuple(sorted({str(f["detail"].get("value")) for f in modes})), unknown,
                          tuple(sorted((f["detail"].get("scope_path", ""), f["detail"].get("effect"), f["detail"].get("order", 0),
                                        tuple(f["detail"].get("roles") or ()), bool(f["detail"].get("all")),
                                        bool(f["detail"].get("anon")), f["detail"].get("users_named", 0)) for f in rules)))}


def _host(doc: dict, key: str) -> str:
    vals = sorted({str(f["detail"][key]).lower() if isinstance(f["detail"].get(key), bool) else str(f["detail"][key])
                   for f in _live(doc, "host_auth") if key in f["detail"]})
    return ", ".join(vals) or "not recorded"


def _config_section(doc: dict, configs: list[str], prod: str, how: str) -> list[str]:
    names = configs or ["base"]
    cols = {c: _column(doc, c) for c in dict.fromkeys([prod] + names)}
    bad = [c for c in names if cols[c]["unknown"]]
    out = [f"**Configurations.** Production configuration: `{_clean(prod)}` ({how}). "
           f"{len(bad)} of {len(names)} configurations could not be evaluated"
           + (f": {_names(bad)}." if bad else ".")]
    differ = [c for c in names if c != prod and cols[c]["signature"] != cols[prod]["signature"]]
    same = [c for c in names if c != prod and c not in differ]
    out += ["", "| Configuration | Authentication mode | `owin_auth` | `host_auth` iis_anonymous | `iis_authorization_present` "
                "| Access rules | Effective on publish or package only |", "|---|---|---|---|---|---:|---|"]
    owin, anon, iisauth = _host(doc, "owin_auth"), _host(doc, "iis_anonymous"), _host(doc, "iis_authorization_present")
    for c in [prod] + differ:
        k = cols[c]
        pub = "yes" if k["publish_only"] else "no"
        out.append(f"| `{_clean(c)}`{' (production)' if c == prod else ''}{' (not evaluated)' if k['unknown'] else ''} | "
                   f"{_cell(k['mode'])} | {owin} | {anon} | {iisauth} | {k['rules']} | {pub} |")
    if same:
        out += ["", f"Same authentication mode and access rules as the production configuration: {_names(same)}."]
    out += ["", "A transform changes a configuration only when the project is published or packaged; a debug build "
                "reads the base `Web.config`. A configuration whose transform the reader cannot evaluate is "
                "counted above, never reported as the base value."]
    return out


# ------------------------------------------------------------------------------------------------- access rules

def _rules_section(doc: dict, prod: str, unmatched: list[dict]) -> list[str]:
    rules = _rules_for(doc, prod)
    anyrule = any(True for _ in _live(doc, "access_rule"))
    if not anyrule:
        return ["**Access rules.** No `<authorization>` rules were extracted (the generic reader and the Stack read "
                "`Web.config` files only)."]
    out = [f"**Access rules** (production configuration `{_clean(prod)}`; the first rule that matches decides).", "",
           "| Scope | Order | Effect | Applies to | Verbs | Defined in |", "|---|---:|---|---|---|---|"]
    for f in rules[:RULE_CAP]:
        d = f["detail"]
        verbs = ", ".join(d.get("verbs") or []) or "all"
        out.append(f"| `{_clean(d.get('scope_path') or '/')}` | {d.get('order', '')} | {d.get('effect', '')} | "
                   f"{_cell(_principal(d))} | {_cell(verbs)} | {_at({'path': d.get('file') or f['path'], 'line': f.get('line')})} |")
    out += ["", _n_of_m(min(len(rules), RULE_CAP), len(rules), "access rule")]
    if unmatched:
        out += ["", "Rules whose path matches no route prefix and no folder or file of the Target (stale rules, or routes "
                    "the Stacks do not see):", "", "| Effect | Scope | Location |", "|---|---|---|"]
        for r in unmatched[:RULE_CAP]:
            out.append(f"| {r['effect']} | `{_clean(r['scope_path'])}` | "
                       f"{_at({'path': r['path'], 'line': r['line']})} |")
        out += ["", _n_of_m(min(len(unmatched), RULE_CAP), len(unmatched), "unmatched rule")]
    else:
        out += ["", "Rules whose path matches no route prefix and no folder or file of the Target: none."]
    return out


# ------------------------------------------------------------------------------------------------- handlers

def _handlers(doc: dict) -> list[dict]:
    return sorted((f for f in _live(doc, "entry_point") if "reach" in f["detail"]), key=_of)


def _truthy(v) -> bool:
    return v is True or str(v).lower() == "true"


def _role_result(d: dict) -> str:
    """The `role` archetype: some role is allowed (`reach_roles`, or every signed-in user is), else deny, else unknown."""
    if d.get("reach_roles") or d.get("reach_auth") == "allow":
        return "allow"
    return "deny" if d.get("reach_auth") == "deny" and d.get("reach") != "unknown" else "unknown"


def _triple(hs: list[dict], pick) -> str:
    c = {"allow": 0, "deny": 0, "unknown": 0}
    for f in hs:
        c[pick(f["detail"]) if pick(f["detail"]) in c else "unknown"] += 1
    return f"{c['allow']}/{c['deny']}/{c['unknown']}"


def _area(f: dict) -> str:
    return str(f["detail"].get("mvc_area") or "(no area)")


def _areas(hs: list[dict]) -> list[str]:
    """The area rows of the handler table, `(no area)` last."""
    return sorted({_area(f) for f in hs}, key=lambda a: (a == "(no area)", a.lower(), a))


def _handler_row(f: dict) -> str:
    d = f["detail"]
    verbs = ", ".join(d.get("verbs") or []) or "none declared"
    why = ", ".join(d.get("reasons") or []) or "none"
    return (f"| `{_clean(f['name'])}` | `{_clean(d.get('handler') or '')}` | {_at(f)} | {d.get('reach')} | {_cell(verbs)} | "
            f"{d.get('reach_anon', '')} | {d.get('reach_auth', '')} | {d.get('state_changing', '')} | {_cell(why)} |")


_HANDLER_HEAD = ["| Route | Handler | File | Label | Verbs | Anon | Auth | State changing | Reasons |", "|---|---|---|---|---|---|---|---|---|"]


def _handler_section(doc: dict, prod: str, reporting: list[str], mechanism: list[str]) -> list[str]:
    hs = _handlers(doc)
    out = [f"**Handlers by area** (production configuration `{_clean(prod)}`). A label says what the application layer "
           "makes possible, never what is the case: `no_app_restriction` means no application rule stops an anonymous "
           "caller, and says nothing about IIS."]
    mech_only = [f for f in _live(doc, "entry_point") if "reach" not in f["detail"] and f["detail"].get("guard_mechanism")]
    if not hs:
        if mechanism and not reporting:
            out += ["", "No handler has a per-handler result: the Stacks that report protection report the mechanism only "
                        f"({plural(len(mech_only), 'handler')} with a guard mechanism)."]
        elif reporting:
            out += ["", f"No handler with an evaluated result was found (reported by {_names(reporting)})."]
        else:
            out += ["", "No handler protection was evaluated (No supported Stack reports effective protection, "
                        "`entry_point.guard_reach`)."]
        return out
    areas = _areas(hs)
    out += ["", "| Area | Handlers | " + " | ".join(f"`{l}`" for l in LABELS) + " |", "|---|---:|" + "---:|" * len(LABELS)]
    for a in areas + ["all areas"]:
        of = hs if a == "all areas" else [f for f in hs if _area(f) == a]
        cnt = [sum(1 for f in of if f["detail"]["reach"] == l) for l in LABELS]
        out.append(f"| {_clean(a)} | {len(of)} | " + " | ".join(str(n) for n in cnt) + " |")
    out += ["", "Archetype results per area, as allow/deny/unknown counts. `anon` is an unauthenticated caller, `auth` a "
                "signed-in user in no role the repository names, `role` a user in at least one named role.", "",
            "| Area | Handlers | `anon` | `auth` | `role` |", "|---|---:|---|---|---|"]
    for a in areas + ["all areas"]:
        of = hs if a == "all areas" else [f for f in hs if _area(f) == a]
        out.append(f"| {_clean(a)} | {len(of)} | {_triple(of, lambda d: d.get('reach_anon'))} | "
                   f"{_triple(of, lambda d: d.get('reach_auth'))} | {_triple(of, _role_result)} |")
    by_cfg: dict[str, dict] = {}
    for f in hs:
        for item in f["detail"].get("reach_by_config") or []:
            c, _, lab = str(item).partition("=")
            by_cfg.setdefault(c, {}).setdefault(lab, 0)
            by_cfg[c][lab] += 1
    if by_cfg:
        order = sorted(by_cfg, key=lambda c: (c != prod, c.lower(), c))
        out += ["", "Handlers by label in each configuration:", "",
                "| Configuration | " + " | ".join(f"`{l}`" for l in LABELS) + " |", "|---|" + "---:|" * len(LABELS)]
        for c in order:
            out.append(f"| `{_clean(c)}` | " + " | ".join(str(by_cfg[c].get(l, 0)) for l in LABELS) + " |")
    if mech_only:
        out += ["", f"{plural(len(mech_only), 'handler')} with a guard mechanism but no per-handler result "
                    "(mechanism-only Stacks)."]
    noapp = [f for f in hs if f["detail"]["reach"] == "no_app_restriction"]
    out += ["", f"**Handlers with no application restriction** (every one is listed; {plural(len(noapp), 'handler')}):"]
    if noapp:
        out += [""] + _HANDLER_HEAD + [_handler_row(f) for f in noapp]
    else:
        out += ["", "None."]
    others = sorted((f for f in hs if _truthy(f["detail"].get("state_changing"))
                     and f["detail"]["reach"] in ("signed_in_any", "unknown")),
                    key=lambda f: (_LABEL_RANK[f["detail"]["reach"]],) + _of(f))
    out += ["", "**State-changing handlers that are not role-restricted** (label `signed_in_any` or `unknown`; "
                "`no_app_restriction` ones are above):"]
    if others:
        out += [""] + _HANDLER_HEAD + [_handler_row(f) for f in others[:HANDLER_CAP]]
        out += ["", _n_of_m(min(len(others), HANDLER_CAP), len(others), "handler")]
    else:
        out += ["", "None."]
    verbless = [f for f in hs if str(f["detail"].get("verbs_declared")).lower() == "false"]
    unk = sum(1 for f in verbless if f["detail"].get("state_changing") == "unknown")
    out += ["", f"{plural(len(verbless), 'verb-less action')} (they accept every verb); {unk} of them have no write hit, so "
                "whether they change state is unknown and they are not listed above unless unrestricted."]
    return out


# ------------------------------------------------------------------------------------------------- guards

def _kind_of(attr: str, uses: list[dict], classes: set, candidates: set) -> str:
    key = _guard_key(attr)
    if any(u["detail"].get("namespace") for u in uses):
        return "framework"
    if key in classes:
        return "declared in the Target"
    if key in candidates:
        return "candidate, undeclared"
    return "not classified"


def _guard_key(name: str) -> str:
    n = str(name).strip().strip("[]").split("(")[0].rsplit(".", 1)[-1].lower()
    return n[:-9] if n.endswith("attribute") and len(n) > 9 else n


def _as_list(v) -> list:
    return [] if v is None else (list(v) if isinstance(v, (list, tuple)) else [v])


def _guard_section(doc: dict) -> list[str]:
    uses = _live(doc, "guard_use")
    cands = _live(doc, "guard_candidate")
    if not uses and not cands:
        return ["**Guard attributes.** None were extracted (no `guard_use` or `guard_candidate` Facts)."]
    classes = {_guard_key(f["name"]) for f in _live(doc, "guard_class")}
    ckeys = {_guard_key(f["name"]) for f in cands}
    by: dict[str, list[dict]] = {}
    for f in uses:
        by.setdefault(f["name"], []).append(f)
    out = ["**Guard attributes.**", "", "| Attribute | Kind | Uses |", "|---|---|---:|"]
    for a in sorted(by, key=lambda x: (x.lower(), x)):
        out.append(f"| `{_clean(a)}` | {_kind_of(a, by[a], classes, ckeys)} | {len(by[a])} |")
    undeclared = sorted({f["name"] for f in cands if _guard_key(f["name"]) not in classes})
    used = {_guard_key(a) for a in by}
    for a in undeclared:
        if _guard_key(a) not in used:
            out.append(f"| `{_clean(a)}` | candidate, undeclared | 0 |")
    out += ["", f"{plural(len(undeclared), 'undeclared guard candidate')}"
            + (f": {_names(undeclared)}" if undeclared else "")
            + ". A candidate is an external attribute used on three or more controllers or actions; a handler it guards "
              "is `unknown`, never downgraded."]
    shapes = aspnet_guards.guard_shapes(doc.get("facts") or [])
    if shapes:
        out += ["", "Guard argument shapes (what each use passes, by kind; `const` is a constant reference, `secret` a "
                    "secret-named constant, `literal` a string literal):", "",
                "| Attribute | Argument kinds | Arity | Uses | Arity overrides |", "|---|---|---:|---:|---:|"]
        for r in shapes[:SHAPE_CAP]:
            out.append(f"| `{_clean(r['attribute'])}` | {_cell(', '.join(r['arg_kinds']) or 'none')} | {r['arity']} | "
                       f"{r['uses']} | {r['overrides']} |")
        out += ["", _n_of_m(min(len(shapes), SHAPE_CAP), len(shapes), "argument shape")]
    return out


def _pairs(roles: list, refs: list) -> list[tuple]:
    """(role, constants) pairs: constants pair with roles by position when the counts agree, else every constant goes
    with every role; a constant whose value was not resolved has no role name."""
    if not roles:
        return [("(value not resolved)", set(refs))] if refs else []
    if len(roles) == len(refs):
        return [(r, {c}) for r, c in zip(roles, refs)]
    return [(r, set(refs)) for r in roles]


def _role_rows(doc: dict) -> dict[str, dict]:
    rows: dict[str, dict] = {}

    def add(role, consts, col):
        x = rows.setdefault(_clean(role), {"consts": set(), "guards": 0, "calls": 0})
        x[col] += 1
        x["consts"].update(_clean(c) for c in consts)
    for f in _live(doc, "guard_use"):
        d = f["detail"]
        for r, cs in _pairs(_as_list(d.get("role")), _as_list(d.get("role_ref"))):
            add(r, cs, "guards")
    for f in _live(doc, "auth_check"):
        d = f["detail"]
        if d.get("via") == "call":
            for r, cs in _pairs(_as_list(d.get("roles")), _as_list(d.get("role_refs"))):
                add(r, cs, "calls")
    return rows


def _roles_section(doc: dict) -> list[str]:
    rows = _role_rows(doc)
    if not rows:
        return ["**Role names referenced by guards or `auth_method` calls.** None were extracted."]
    out = ["**Role names referenced by guards or `auth_method` calls** (names as written; every one is listed; "
           "no user names).", "", "| Role or group name | Constants | Guard uses | `auth_method` calls |", "|---|---|---:|---:|"]
    for name in sorted(rows, key=lambda n: (n.lower(), n)):
        x = rows[name]
        consts = ", ".join(f"`{c}`" for c in sorted(x["consts"])) or "none"
        out.append(f"| `{name}` | {_cell(consts)} | {x['guards']} | {x['calls']} |")
    out += ["", f"Listed {len(rows)} of {len(rows)} role names."]
    return out


# ------------------------------------------------------------------------------------------------- secrets

def _secret_places(doc: dict) -> dict[str, dict]:
    """Per file, counts of places where a secret lives, by kind. A place is counted once (by file and line), under
    the first kind it matches. Values are never read here: only the `secret_location` and `secret` flags."""
    seen: set = set()
    per: dict[str, dict] = {}

    def add(f: dict, col: str):
        k = (f["path"], f.get("line"))
        if k in seen:
            return
        seen.add(k)
        per.setdefault(f["path"], dict.fromkeys(("keys", "conns", "machine", "consts", "other"), 0))[col] += 1
    for f in sorted(_live(doc, "security_setting"), key=_of):
        d = f["detail"]
        if d.get("secret_location") and str(d.get("value", "")).startswith("literal"):
            n = str(f["name"])
            add(f, "machine" if n.endswith("machineKey") else "conns" if "connectionString" in n else "other")
    for f in sorted(_live(doc, "connection"), key=_of):
        if f["detail"].get("secret_location"):
            add(f, "conns")
    for f in sorted(_live(doc, "const_def"), key=_of):
        if f["detail"].get("secret"):
            add(f, "consts")
    for f in sorted(_live(doc, "config_key"), key=_of):
        if f["detail"].get("secret_location"):
            add(f, "keys")
    return per


def _secret_table(doc: dict) -> list[str]:
    """The secret-location table (see `_secret_places`)."""
    per = _secret_places(doc)
    if not per:
        return ["**Secret locations.** No secret-location config keys, connection strings with literal credentials, "
                "literal `machineKey`s or secret-named constants were extracted. Values are never recorded."]
    files = sorted(per)
    tot = {c: sum(per[p][c] for p in files) for c in ("keys", "conns", "machine", "consts", "other")}
    out = ["**Secret locations** (counts only; a value is never recorded, and a location is not a quotation).", "",
           "| File | Secret-location config keys | Connection strings with literal credentials | Literal `machineKey`s "
           "| Secret-named constants | Other secret-location settings |", "|---|---:|---:|---:|---:|---:|"]
    for p in files[:FILE_CAP]:
        c = per[p]
        out.append(f"| `{_clean(p)}` | {c['keys']} | {c['conns']} | {c['machine']} | {c['consts']} | {c['other']} |")
    out += ["", _n_of_m(min(len(files), FILE_CAP), len(files), "file")
            + f" Totals: {tot['keys']} config keys, {tot['conns']} connection strings, {tot['machine']} `machineKey`s, "
              f"{tot['consts']} constants, {tot['other']} other settings."]
    return out


# ------------------------------------------------------------------------------------------------- stacks and notes

def _stack_lines(doc: dict) -> tuple[list[str], list[str], list[str]]:
    sup = [s for s in doc.get("stacks") or [] if (s.get("detail") or {}).get("supported")]
    caps = {s["name"]: set((s.get("detail") or {}).get("capabilities") or []) for s in sup}
    reporting = sorted(n for n, c in caps.items() if "entry_point.guard_reach" in c)
    mechanism = sorted(n for n, c in caps.items() if "entry_point.guard_mechanism" in c and n not in reporting)
    none = sorted(n for n in caps if n not in reporting and n not in mechanism)
    return reporting, mechanism, none


def _stacks_section(reporting: list[str], mechanism: list[str], none: list[str]) -> list[str]:
    if not (reporting or mechanism):
        return ["**Stacks.** No supported Stack reports effective protection (`entry_point.guard_reach`) or a guard "
                "mechanism (`entry_point.guard_mechanism`), so this block lists no per-handler result"
                + (f"; supported Stacks without it: {_names(none)}." if none else ".")]
    out = ["**Stacks.** Effective protection per handler is reported by " + (_names(reporting) if reporting else "no Stack")
           + ". "]
    if mechanism:
        out[0] += (f"Mechanism only (no reach, and no claim that a handler is unguarded): {_names(mechanism)}; for "
                   "these the attributes and filters found are listed, not what they allow.")
    if none:
        out[0] += f" Supported Stacks that do not report protection: {_names(none)}."
    return out


def _unevaluated_handlers(doc: dict) -> list[str]:
    files = sorted(f["path"] for f in _live(doc, "file") if f["path"].lower().endswith(_HANDLER_EXT))
    if not files:
        return []
    by_ext = {e: sum(1 for p in files if p.lower().endswith(e)) for e in _HANDLER_EXT}
    counts = ", ".join(f"{n} `{e}`" for e, n in by_ext.items() if n)
    out = [f"Not evaluated: `.ashx`, `.asmx` and `.svc` handler files exist in the Target ({counts}). URL authorization "
           "applies to them by file URL, but the Stacks do not emit them as handlers and this block says nothing about "
           "their protection."]
    out[0] += " Files: " + ", ".join(f"`{_clean(p)}`" for p in files[:PATH_CAP])
    out[0] += (f", ... {len(files) - PATH_CAP} more." if len(files) > PATH_CAP else ".")
    return out


DEFAULTS = ("**Defaults** (documentation of ASP.NET behaviour, not a Fact about this Target): URL authorization ends with "
            "the machine-level `allow *`, so a URL no rule decides is open at the application layer; `[Authorize]` "
            "with no `Roles` or `Users` admits any signed-in user; an action with no rule and no filter is open to "
            "anonymous callers unless IIS refuses anonymous access, which the repository does not show.")


def render(doc: dict, unmatched: list[dict] | None = None) -> str:
    """The `access-model` block body. `unmatched` is `summary.unmatched_rules(doc["facts"])` (computed by the caller)."""
    configs = _configurations(doc)
    prod, how = _production(doc, configs)
    reporting, mechanism, none = _stack_lines(doc)
    parts = [[DISCLOSURE], _config_section(doc, configs, prod, how), _rules_section(doc, prod, unmatched or []),
             _handler_section(doc, prod, reporting, mechanism), _guard_section(doc), _roles_section(doc),
             _secret_table(doc), [DEFAULTS], _stacks_section(reporting, mechanism, none), _unevaluated_handlers(doc)]
    return "\n\n".join("\n".join(p) for p in parts if p)



# ------------------------------------------------------------------------------------------------- count markers

def _state_changing(doc: dict, label: str) -> int:
    return sum(1 for f in _handlers(doc) if f["detail"]["reach"] == label and _truthy(f["detail"].get("state_changing")))


def count(cls: str, doc: dict) -> int | None:
    """The number a count marker of an access-model class holds (`template_spec.ACCESS_COUNT_CLASSES`), taken from the
    same helpers `render` uses, so a marker and the block never disagree (R5); None for another class."""
    if cls == "areas":
        return sum(1 for a in _areas(_handlers(doc)) if a != "(no area)")
    if cls.startswith("state-changing-") and cls[len("state-changing-"):] in LABELS:
        return _state_changing(doc, cls[len("state-changing-"):])
    if cls == "access-rules":
        return len(_rules_for(doc, _production(doc, _configurations(doc))[0]))
    if cls == "role-constants":
        return len(_role_rows(doc))
    if cls == "guard-shapes":
        return len(aspnet_guards.guard_shapes(doc.get("facts") or []))
    if cls == "secret-location-files":
        return len(_secret_places(doc))
    if cls == "configurations":
        return len(_configurations(doc) or ["base"])
    return None
