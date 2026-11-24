"""Per-file Facts from .NET security configuration (plan 2.8 W1 and W2; tasks T28.30-T28.44).

Pure functions of one file's text: ``config_facts`` (the ``aspnet`` stack's ``.config`` reader: ``security_setting``,
``access_rule``, ``config_transform``, ``external_call`` for WCF client endpoints, ``host_auth`` evidence) and
``generic_facts`` (``config_unparsed`` and ``config_external``, emitted under the ``generic`` stack id). Nothing here
looks at another file: joins across files (a transform applied to its base, effective values per build configuration,
``overridden_in``) are the post-pass in ``appdoc/configs.py`` (raw Facts per file keep the cache and the process pool
safe).

Rules kept here:

* a closed element set (``SETTINGS``); a missing element or attribute is ``value: absent``, never a framework default;
* values come from the per-attribute enumerations of ``dotnetcfg`` (anything else is ``other``), a password or
  connection-string attribute is recorded as ``other`` or ``placeholder`` with ``secret_location``, and a ``machineKey``
  is classed (``autogenerate``, ``literal_hex``, ``placeholder``, ``absent_keys``, ``other``), never recorded (R19);
* users in access rules are counted (deduplicated case-insensitively), never recorded; a role that looks like an email
  or a SID is counted as a user; ``DOMAIN\\X`` roles are kept with ``domain_qualified`` (R18);
* WCF addresses are recorded as ``scheme://host[:port]`` only.
"""
from __future__ import annotations

import json
import re
from urllib.parse import urlsplit

from . import dotnetcfg
from .facts import Fact

STACK_ID = "aspnet"

# ------------------------------------------------------------------ the closed element set (W1.1)

# (name, element path from <configuration>, attribute or None, kind)
_SW = ("system.web",)
SETTINGS = (
    ("system.web/authentication@mode", _SW + ("authentication",), "mode", "enum"),
    ("system.web/forms@requireSSL", _SW + ("authentication", "forms"), "requireSSL", "enum"),
    ("system.web/forms/credentials", _SW + ("authentication", "forms", "credentials"), None, "credentials"),
    ("system.web/machineKey", _SW + ("machineKey",), None, "machinekey"),
    ("system.web/customErrors@mode", _SW + ("customErrors",), "mode", "enum"),
    ("system.web/compilation@debug", _SW + ("compilation",), "debug", "enum"),
    ("system.web/httpCookies@requireSSL", _SW + ("httpCookies",), "requireSSL", "enum"),
    ("system.web/httpCookies@httpOnlyCookies", _SW + ("httpCookies",), "httpOnlyCookies", "enum"),
    ("system.web/sessionState@mode", _SW + ("sessionState",), "mode", "enum"),
    ("system.web/sessionState@cookieless", _SW + ("sessionState",), "cookieless", "enum"),
    ("system.web/sessionState@sqlConnectionString", _SW + ("sessionState",), "sqlConnectionString", "secret"),
    ("system.web/trace@enabled", _SW + ("trace",), "enabled", "enum"),
    ("system.web/trace@localOnly", _SW + ("trace",), "localOnly", "enum"),   # folded into trace@enabled's local_only
    ("system.web/httpRuntime@requestValidationMode", _SW + ("httpRuntime",), "requestValidationMode", "enum"),
    ("system.web/identity@impersonate", _SW + ("identity",), "impersonate", "enum"),
    ("system.web/identity@userName", _SW + ("identity",), "userName", "user"),
    ("system.web/identity@password", _SW + ("identity",), "password", "secret"),
    ("system.webServer/httpErrors@errorMode", ("system.webServer", "httpErrors"), "errorMode", "enum"),
    ("system.net/mailSettings/smtp/network@password",
     ("system.net", "mailSettings", "smtp", "network"), "password", "secret"),
    ("system.web/processModel@userName", _SW + ("processModel",), "userName", "user"),
    ("system.web/processModel@password", _SW + ("processModel",), "password", "secret"),
)
BY_NAME = {s[0]: s for s in SETTINGS}
FOLDED = {"system.web/trace@localOnly"}          # pseudo setting: carried as ``local_only`` on trace@enabled
PLACEHOLDER = re.compile(r"^(?:#\{[^}]*\}|\$\{[^}]*\}|\$\([^)]*\)|__[A-Za-z0-9_.]+__)$")
_HEX = re.compile(r"^[0-9A-Fa-f]{32,128}$")

# Section files (``configSource`` targets): the root element names a section; its place in <configuration>.
SECTION_ROOTS = {
    "authentication": ("system.web", "authentication"), "authorization": ("system.web", "authorization"),
    "machineKey": ("system.web", "machineKey"), "customErrors": ("system.web", "customErrors"),
    "compilation": ("system.web", "compilation"), "httpCookies": ("system.web", "httpCookies"),
    "sessionState": ("system.web", "sessionState"), "trace": ("system.web", "trace"),
    "httpRuntime": ("system.web", "httpRuntime"), "identity": ("system.web", "identity"),
    "processModel": ("system.web", "processModel"), "system.web": ("system.web",),
    "httpErrors": ("system.webServer", "httpErrors"),
}

SETTING_ELEMENTS = frozenset(s[1] for s in SETTINGS)
EXTRA_PREFIXES = ("connectionStrings/", "system.serviceModel/")   # settings outside the per-configuration engine


def under(path: tuple, prefix: tuple) -> bool:
    """True when ``path`` equals ``prefix`` or lies below it (whole segments)."""
    return path[:len(prefix)] == prefix


def secret_of(name: str, value: str) -> bool:
    """Whether a setting's value is a secret location (never its value)."""
    kind = BY_NAME[name][3] if name in BY_NAME else ""
    if kind == "machinekey":
        return value == "literal_hex"
    if kind == "secret":
        return value == "other"
    return kind == "credentials" and value == "literal"


def classify(name: str, node) -> str:
    """The closed value of one setting read from ``node`` (the element, or ``None`` when it is missing)."""
    _, path, attr, kind = BY_NAME[name]
    if node is None:
        return "absent"
    if kind == "machinekey":
        keys = [node.attrs[a] for a in ("validationKey", "decryptionKey") if node.attrs.get(a)]
        if not keys:
            return "absent_keys"
        if any(_HEX.match(k) for k in keys):
            return "literal_hex"
        if any(PLACEHOLDER.match(k) for k in keys):
            return "placeholder"
        if all(k.lower().startswith("autogenerate") for k in keys):
            return "autogenerate"
        return "other"
    if kind == "credentials":
        for u in node.findall("user"):
            pw = u.attrs.get("password", "")
            if pw and not PLACEHOLDER.match(pw):
                return "literal"
        return "other"
    value = node.attrs.get(attr)
    if value is None:
        return "absent"
    if kind == "enum":
        return dotnetcfg.enum_value(path[-1], attr, value)
    value = value.strip()
    if not value:
        return "absent"
    return "placeholder" if PLACEHOLDER.match(value) else "other"


def read_settings(root, base: tuple = ()) -> dict:
    """``{setting name: (value, line)}`` for every setting of the closed set found under ``root``'s ``base`` path.

    ``root`` is the element at path ``base`` (``configuration`` with ``()``, or a section file's root element).
    A missing element is ``absent`` with the line of its nearest present parent (the element's own line when
    present, else the ``system.web`` element, else the root)."""
    out = {}
    for name, path, _attr, _kind in SETTINGS:
        if not under(path, base):
            continue
        rel = path[len(base):]
        node = root.find(*rel) if rel else root
        line = node.line if node is not None else _parent_line(root, rel)
        out[name] = (classify(name, node), line)
    return out


def _parent_line(root, rel: tuple) -> int:
    for k in range(len(rel) - 1, 0, -1):
        n = root.find(*rel[:k])
        if n is not None:
            return n.line
    return root.line


def mk(kind: str, stack: str, path: str, line, name: str, **detail) -> Fact:
    """``Fact.make`` for a kind whose detail also carries ``name`` (``security_setting``), which ``make`` cannot take as
    a keyword because ``name`` is its own parameter."""
    base = Fact.make(kind, stack, path, line, name, **detail)
    return Fact(base.kind, base.stack, base.path, base.line, base.name, tuple(sorted(base.detail + (("name", name),))))


def setting_fact(path: str, line: int, name: str, value: str, config: str, status: str, secret: bool = False,
                 local_only=None, reason=None, **extra) -> Fact:
    d = dict(value=value, config=config, config_status=status, secret_location=secret)
    if local_only is not None:
        d["local_only"] = local_only
    if reason:
        d["reason"] = reason
    d.update(extra)
    return mk("security_setting", STACK_ID, path, line, name, **d)


def emit_settings(path: str, values: dict, config: str, only_present: bool = False):
    """Facts from ``{name: (value, line, status, reason)}``; ``trace@localOnly`` is folded into ``trace@enabled``."""
    local = values.get("system.web/trace@localOnly")
    for name in sorted(values):
        if name in FOLDED:
            continue
        value, line, status, reason = values[name]
        if only_present and value == "absent":
            continue
        lo = None
        if name == "system.web/trace@enabled" and local and local[0] in ("true", "false"):
            lo = local[0] == "true"
        yield setting_fact(path, line, name, value, config, status, secret_of(name, value), lo, reason)


# ------------------------------------------------------------------ XDT operations (W1.7)

SUPPORTED_OPS = frozenset({"Replace", "Remove", "RemoveAll", "RemoveAttributes", "SetAttributes", "Insert"})
RECOGNISED_OPS = SUPPORTED_OPS | {"InsertBefore", "InsertAfter", "InsertIfMissing"}
RULE_NAMES = ("allow", "deny", "clear", "remove")
_CALL = re.compile(r"^\s*([A-Za-z_]\w*)\s*(?:\((.*)\))?\s*$", re.S)
_COND = re.compile(r"""^\s*@([A-Za-z_][\w.-]*)\s*=\s*(?:'([^']*)'|"([^"]*)")\s*$""")


def _call(text):
    m = _CALL.match(text or "")
    return (m.group(1), m.group(2)) if m else (None, None)


def _locator(node):
    """``(kind, attrs, value, ok)`` of an element's ``xdt:Locator`` (kind ``none`` without one). ``ok`` is whether the
    extractor can evaluate it: only ``Match(attr)`` (and ``Condition(@attr='literal')``, the same single comparison)
    is evaluated; ``Match(a,b)``, ``XPath(...)``, compound conditions and anything else are not (``ok`` False)."""
    loc = node.xdt.get("Locator")
    if loc is None:
        return "none", [], None, True
    kind, args = _call(loc)
    if kind == "Match" and args is not None:
        names = [a.strip() for a in args.split(",") if a.strip()]
        if len(names) == 1 and names[0] in node.attrs:
            return "Match", names, node.attrs[names[0]], True
        return "Match", names, None, False
    if kind == "Condition" and args is not None:
        m = _COND.match(args)
        if m:
            return "Condition", [m.group(1)], m.group(2) if m.group(2) is not None else m.group(3), True
        return "Condition", [], None, False
    if kind == "XPath":
        return "XPath", [], None, False
    return "other", [], None, False


def _split_args(args):
    return [a.strip() for a in (args or "").split(",") if a.strip()]


# ------------------------------------------------------------------ users and rules (W2, R18)

_SID = re.compile(r"(?i)^S-1-\d+(?:-\d+)+$")


def _csv(value):
    return [p.strip() for p in (value or "").split(",") if p.strip()]


def rule_fields(el) -> dict:
    """The recordable fields of one ``<allow>/<deny>/<clear>/<remove>`` element: roles (names), anon/all flags, a user
    count, verbs. A user name is counted and forgotten; a role that looks like an email or a SID is a user."""
    users = _csv(el.attrs.get("users"))
    named = {u.lower() for u in users if u not in ("?", "*")}
    roles, domain = [], False
    for r in _csv(el.attrs.get("roles")):
        if "@" in r or _SID.match(r):
            named.add(r.lower())
        else:
            roles.append(r)
            domain = domain or "\\" in r
    return {"effect": el.name, "roles": sorted(set(roles)), "anon": "?" in users, "all": "*" in users,
            "users_named": len(named), "verbs": sorted({v.upper() for v in _csv(el.attrs.get("verbs"))}),
            "domain": domain, "line": el.line,
            "attrs": sorted(a for a in ("users", "roles", "verbs") if a in el.attrs)}


def rule_fact_detail(rule: dict, **extra) -> dict:
    d = {"effect": rule["effect"]}
    if rule["roles"]:
        d["roles"] = list(rule["roles"])
    if rule["verbs"]:
        d["verbs"] = list(rule["verbs"])
    if rule["anon"]:
        d["anon"] = True
    if rule["all"]:
        d["all"] = True
    if rule["users_named"]:
        d["users_named"] = rule["users_named"]
    if rule["domain"]:
        d["domain_qualified"] = True
    d.update(extra)
    return d


def norm_scope(folder: str, location_path: "str | None") -> str:
    """The URL-space prefix of a rule: the file's folder joined with ``location@path``. ``.``, empty and absent paths
    mean the folder itself; a leading ``~/`` or ``/`` and a trailing ``/`` are dropped; separators are ``/``; case is kept
    (matching is case-insensitive, done by the readers of the Fact)."""
    p = (location_path or "").strip().replace("\\", "/")
    if p == ".":
        p = ""
    for lead in ("~/", "/"):
        while p.startswith(lead):
            p = p[len(lead):]
    if p == "~":
        p = ""
    parts = [s for s in ("/".join(x for x in (folder, p) if x)).split("/") if s and s != "."]
    return "/".join(parts)


def _authorizations(root):
    """``(location key or None, location element or None, authorization element)`` in document order."""
    for child in root.children:
        if child.name == "system.web":
            for a in child.findall("authorization"):
                yield None, None, a
        elif child.name == "location":
            for sw in child.findall("system.web"):
                for a in sw.findall("authorization"):
                    yield child.attrs.get("path", ""), child, a


def rule_facts(path: str, root, folder: str):
    order = 0
    for key, loc, auth in _authorizations(root):
        scope = norm_scope(folder, key)
        for el in auth.children:
            if el.name not in RULE_NAMES:
                continue
            order += 1
            r = rule_fields(el)
            extra = dict(scope_path=scope, order=order, config="base", config_status="base", file=path)
            if loc is not None:
                extra["location"] = loc.attrs.get("path", "")
                for attr, k in (("allowOverride", "allow_override"), ("inheritInChildApplications", "inherit_in_child_apps")):
                    if attr in loc.attrs:
                        extra[k] = loc.attrs[attr].strip().lower() != "false"
            yield Fact.make("access_rule", STACK_ID, path, el.line, f"{el.name} /{scope}", **rule_fact_detail(r, **extra))


# ------------------------------------------------------------------ transforms (raw, per transform file)

def _payload_rules(el) -> list:
    if el.name == "authorization":
        kids = el.children
    elif el.name in RULE_NAMES:
        kids = [el]
    elif el.name == "system.web":
        kids = [k for a in el.findall("authorization") for k in a.children]
    elif el.name == "location":
        kids = [k for sw in el.findall("system.web") for a in sw.findall("authorization") for k in a.children]
    else:
        kids = []
    return [rule_fields(k) for k in kids if k.name in RULE_NAMES]


def _payload_settings(el, full: tuple, flag_secret=True) -> list:
    """``name:value`` for each closed setting present in the transform element's subtree (the new content)."""
    out = []

    def walk(node, path):
        for name, spath, _a, _k in SETTINGS:
            if spath == path:
                v = classify(name, node)
                if v != "absent":
                    out.append(f"{name}:{v}")
        for c in node.children:
            walk(c, path + (c.name,))

    walk(el, full)
    return sorted(set(out))


def transform_facts(path: str, root, config: str):
    """One ``config_transform`` per element that carries ``xdt:Transform``, in document order. See configs.py for how
    they are applied. Unsupported operations and locators are recorded with ``supported: false`` and a reason."""

    def walk(node, segs, nav_ok):
        for child in node.children:
            kind, largs, lval, lok = _locator(child)
            if child.name == "location":
                if kind in ("Match", "Condition") and lok and largs == ["path"]:
                    seg, here_nav = f"location[{lval}]", True
                else:
                    seg, here_nav = "location[*]", False
            else:
                seg, here_nav = child.name, True
            full = segs + (seg,)
            op_text = child.xdt.get("Transform")
            if op_text is None:
                yield from walk(child, full, nav_ok and here_nav)
                continue
            op, args = _call(op_text)
            recognised = op in RECOGNISED_OPS
            reason = None
            if not recognised:
                reason = "operation"
            elif op not in SUPPORTED_OPS:
                reason = "operation"
            elif not nav_ok or (child.name == "location" and not here_nav):
                reason = "ancestor_locator"
            elif child.name == "location":
                reason = "location_element"
            elif not lok:
                reason = "xpath" if kind == "XPath" else "locator"
            elif kind != "none" and (child.name in RULE_NAMES or child.name == "authorization"
                                     or full in SETTING_ELEMENTS):
                reason = "locator_on_security_element"
            if "Condition" in child.xdt:
                reason = reason or "condition"
            target = "/".join(full)
            d = dict(config=config, operation=op or "other", recognised=recognised, supported=reason is None,
                     locator=kind, target_path=target)
            if args is not None and op in ("SetAttributes", "RemoveAttributes"):
                d["arglist"] = _split_args(args)
            name = target
            if kind in ("Match", "Condition") and lok:
                d["locator_attrs"] = largs
                if largs in (["key"], ["name"]):
                    d["match"] = lval
                    name = f"{target}[{lval}]"
            attrs = _payload_settings(child, full)
            if attrs:
                d["attributes"] = attrs
            rules = _payload_rules(child)
            if rules:
                d["rules"] = [json.dumps(r, sort_keys=True, separators=(",", ":")) for r in rules]
            if reason:
                d["unsupported_reason"] = reason
            yield Fact.make("config_transform", STACK_ID, path, child.line, name, **d)
            if op in ("SetAttributes", "RemoveAttributes", "Remove", "RemoveAll"):
                yield from walk(child, full, nav_ok and here_nav)

    yield from walk(root, (), True)


# ------------------------------------------------------------------ WCF client endpoints (W1.9)

def _scheme_host(address: str) -> "str | None":
    """``scheme://host[:port]`` of an address; userinfo, path, query and fragment are dropped. ``None`` if it has no
    scheme and host."""
    try:
        u = urlsplit(address.strip())
        host = u.hostname
        port = u.port
    except ValueError:
        return None
    if not u.scheme or not host or not re.match(r"^[A-Za-z][A-Za-z0-9+.-]*$", u.scheme):
        return None
    host = host.lower()
    if ":" in host:
        host = f"[{host}]"
    return f"{u.scheme.lower()}://{host}" + (f":{port}" if port else "")


def wcf_facts(path: str, root):
    for ep in (e for c in root.findall("system.serviceModel") for cl in c.findall("client") for e in cl.findall("endpoint")):
        addr = _scheme_host(ep.attrs.get("address", ""))
        if not addr:
            continue
        d = dict(type="service")
        if ep.attrs.get("contract"):
            d["via"] = ep.attrs["contract"].strip()
        if ep.attrs.get("name"):
            d["config_key"] = ep.attrs["name"].strip()
        yield Fact.make("external_call", STACK_ID, path, ep.line, addr, **d)
    sm = root.find("system.serviceModel")
    for cc in ([x for x in sm.iter() if x.name == "clientCredentials"] if sm is not None else []):
        literal = any(a.endswith(("password", "Password")) and v and not PLACEHOLDER.match(v)
                      for n in cc.iter() for a, v in n.attrs.items())
        yield setting_fact(path, cc.line, "system.serviceModel/clientCredentials", "other" if literal else "absent",
                           "base", "base", literal)


# ------------------------------------------------------------------ credential carriers (W1.4)

_CRED = re.compile(r"(?i)\b(?:password|pwd|user\s*id|uid)\s*=\s*([^;]*)")


def has_literal_credential(conn: str) -> bool:
    for m in _CRED.finditer(conn or ""):
        v = m.group(1).strip().strip("'\"")
        if v and not PLACEHOLDER.match(v):
            return True
    return False


def credential_facts(path: str, root, config: str, status: str):
    """One ``security_setting`` per file counting connection strings that carry a literal ``Password=`` or ``User ID=``.
    The count and the location are recorded; no value (R19)."""
    lines = [a.line for cs in root.findall("connectionStrings") for a in cs.children
             if a.name == "add" and has_literal_credential(a.attrs.get("connectionString", ""))]
    if lines:
        yield setting_fact(path, lines[0], "connectionStrings/add@connectionString", "literal", config, status, True,
                           count=len(lines))


# ------------------------------------------------------------------ external config (W1.5)

def _external(folder: str, value: str):
    """``(target, resolved)``: the Target-relative path of a ``configSource``/``file`` value when it is relative and
    inside the Target, else ``(None, False)``."""
    v = (value or "").strip().replace("\\", "/")
    if not v or v.startswith(("/", "~")) or re.match(r"^[A-Za-z]:", v) or "://" in v:
        return None, False
    parts = [p for p in (folder.split("/") if folder else [])]
    for seg in v.split("/"):
        if seg in ("", "."):
            continue
        if seg == "..":
            if not parts:
                return None, False
            parts.pop()
        else:
            parts.append(seg)
    return "/".join(parts), True


def external_facts(path: str, root, folder: str, stack: str = "generic"):
    def walk(node, segs):
        for c in node.children:
            full = segs + (c.name,)
            for attr in ("configSource", "file"):
                if attr in c.attrs and (attr == "configSource" or c.name == "appSettings"):
                    target, ok = _external(folder, c.attrs[attr])
                    d = dict(element="/".join(full), resolved=ok)
                    if target:
                        d["target"] = target
                    yield Fact.make("config_external", stack, path, c.line, f"{'/'.join(full)}@{attr}", **d)
            yield from walk(c, full)

    yield from walk(root, ())


def generic_facts(path: str, text: str, raw: "bytes | None" = None):
    """``config_unparsed`` and ``config_external`` (stack ``generic``) for a Web/App config or a transform file."""
    if not (dotnetcfg.is_config_name(path) or dotnetcfg.transform_config_name(path)):
        return
    doc = dotnetcfg.parse(raw) if raw is not None else dotnetcfg.parse(text.encode("utf-8"), encoding="utf-8")
    if doc.root is None:
        yield Fact.make("config_unparsed", "generic", path, None, path.rsplit("/", 1)[-1], reason=doc.unparsed)
        return
    if doc.root.name == "configuration" and not dotnetcfg.transform_config_name(path):
        folder = path.rsplit("/", 1)[0] if "/" in path else ""
        yield from external_facts(path, doc.root, folder)


# ------------------------------------------------------------------ host and OWIN disclosure (W1.10)

_OWIN_CALL = re.compile(
    r"\bUse(?:Cookie|OpenIdConnect|WsFederation|OAuthBearer|WindowsAzureActiveDirectoryBearer|JwtBearer)Authentication\s*\(")


def code_facts(path: str, clean_text: str):
    """``host_auth`` evidence in C# code: an ``IAppBuilder`` method calling a ``Use*Authentication`` middleware."""
    if "IAppBuilder" not in clean_text:
        return
    m = _OWIN_CALL.search(clean_text)
    if m:
        yield Fact.make("host_auth", STACK_ID, path, clean_text.count("\n", 0, m.start()) + 1, "owin",
                        owin_auth=True)


def _host_facts(path: str, root):
    anon = root.find("system.webServer", "security", "authentication", "anonymousAuthentication")
    if anon is not None and anon.attrs.get("enabled", "").strip().lower() in ("true", "false"):
        yield Fact.make("host_auth", STACK_ID, path, anon.line, "iis", source="config",
                        iis_anonymous="enabled" if anon.attrs["enabled"].strip().lower() == "true" else "disabled")
    present = [root.find("system.webServer", "security", "authorization")] + [
        loc.find("system.webServer", "security", "authorization") for loc in root.findall("location")]
    present = [p for p in present if p is not None]
    if present:
        yield Fact.make("host_auth", STACK_ID, path, present[0].line, "iis", iis_authorization_present=True)


# ------------------------------------------------------------------ entry point for the aspnet stack

def config_facts(path: str, text: str):
    """Facts of the ``aspnet`` stack for one ``.config`` file (Web/App config, transform, or a section file)."""
    doc = dotnetcfg.parse(text.encode("utf-8"), encoding="utf-8")
    root = doc.root
    if root is None:
        return
    folder = path.rsplit("/", 1)[0] if "/" in path else ""
    cfg = dotnetcfg.transform_config_name(path)
    if cfg and root.name == "configuration":
        yield from transform_facts(path, root, cfg)
        yield from credential_facts(path, root, cfg, "transformed")
        return
    if dotnetcfg.is_config_name(path) and root.name == "configuration":
        is_web = path.rsplit("/", 1)[-1].lower() == "web.config"
        values = read_settings(root)
        yield from emit_settings(path, {n: (v, ln, "base", None) for n, (v, ln) in values.items()}, "base",
                                 only_present=not is_web)
        if is_web:
            yield from rule_facts(path, root, folder)
            yield from _host_facts(path, root)
        yield from credential_facts(path, root, "base", "base")
        yield from wcf_facts(path, root)
        return
    if root.name in SECTION_ROOTS and not cfg:
        base = SECTION_ROOTS[root.name]
        values = read_settings(root, base)
        yield from emit_settings(path, {n: (v, ln, "base", None) for n, (v, ln) in values.items()}, "base",
                                 only_present=True)
        if root.name == "authorization":
            for r in rule_facts_from_auth(path, root, folder):
                yield r


def rule_facts_from_auth(path: str, auth, folder: str):
    order = 0
    for el in auth.children:
        if el.name not in RULE_NAMES:
            continue
        order += 1
        extra = dict(scope_path=norm_scope(folder, None), order=order, config="base", config_status="base", file=path)
        yield Fact.make("access_rule", STACK_ID, path, el.line, f"{el.name} /{extra['scope_path']}",
                        **rule_fact_detail(rule_fields(el), **extra))
