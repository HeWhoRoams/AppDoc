"""T28.62: the URL authorization chain evaluator (appdoc/urlauth.py), on invented rule Facts."""

import unittest

from appdoc import urlauth as U
from appdoc.urlauth import evaluate, principals_for, url_chain


def rule(effect, scope="", order=1, file="Web.config", users=None, roles=(), verbs=(), location=None, config="base",
         status="base", **extra):
    d = {"effect": effect, "scope_path": scope, "order": order, "file": file, "config": config, "config_status": status}
    users = users or []
    if "?" in users:
        d["anon"] = True
    if "*" in users:
        d["all"] = True
    named = [u for u in users if u not in ("?", "*")]
    if named:
        d["users_named"] = len(named)
    if roles:
        d["roles"] = sorted(roles)
    if verbs:
        d["verbs"] = sorted(verbs)
    if location is not None:
        d["location"] = location
    d.update(extra)
    return {"kind": "access_rule", "path": file, "line": order, "name": f"{effect} /{scope}", "detail": d}


def ev(rules, url="/Orders", principal="anon", verb="GET", config="base"):
    return evaluate(rules, url, principal, verb, config)


class UrlAuthTests(unittest.TestCase):
    def test_url_auth_allow_roles_only_falls_through(self):
        rules = [rule("allow", roles=["Admins"], order=1), rule("deny", users=["*"], order=2)]
        self.assertEqual(ev(rules, principal="anon").result, "deny")
        self.assertEqual(ev(rules, principal="auth").result, "deny")
        self.assertEqual(ev(rules, principal="role:admins").result, "allow")
        self.assertEqual(ev(rules, principal="role:Staff").result, "deny")

    def test_url_auth_first_match_wins(self):
        rules = [rule("allow", users=["?"], order=1), rule("deny", users=["*"], order=2)]
        self.assertEqual(ev(rules).result, "allow")
        self.assertEqual(ev(list(reversed(rules))).result, "allow", "input order does not matter, rule order does")
        r = ev([rule("deny", users=["*"], order=1), rule("allow", users=["?"], order=2)])
        self.assertEqual(r.result, "deny")
        self.assertTrue(r.reasons)

    def test_url_auth_child_before_parent(self):
        parent = rule("deny", users=["?"], file="Web.config", order=1)
        child = rule("allow", scope="Public", users=["?"], file="Public/Web.config", order=1)
        self.assertEqual(ev([parent, child], "/Public/x").result, "allow")
        self.assertEqual(ev([parent, child], "/Private/x").result, "deny")
        self.assertEqual(ev([parent, child], "/PublicRelations").result, "deny")

    def test_url_auth_location_before_own_authorization(self):
        own = rule("deny", users=["?"], order=1)
        loc = rule("allow", scope="Login", users=["?"], order=2, location="Login")
        self.assertEqual(ev([own, loc], "/login/in").result, "allow")
        self.assertEqual(ev([loc, own], "/Login").result, "allow")
        self.assertEqual(ev([own, loc], "/Home").result, "deny")
        deep = rule("deny", scope="Login/Admin", users=["?"], order=3, location="Login/Admin")
        self.assertEqual(ev([own, loc, deep], "/Login/Admin/x").result, "deny", "more segments first")

    def test_url_auth_tie_break_document_order(self):
        a = rule("allow", scope="Shared", users=["*"], order=1, location="Shared")
        b = rule("deny", scope="Shared", users=["*"], order=2, location="Shared")
        # two location elements with the same path: the first in document order is nearer
        b["detail"]["location"] = "~/Shared"
        self.assertEqual(ev([b, a], "/Shared/x").result, "allow")
        a2 = rule("deny", scope="Shared", users=["*"], order=1, location="Shared")
        b2 = rule("allow", scope="Shared", users=["*"], order=2, location="~/Shared")
        self.assertEqual(ev([a2, b2], "/Shared/x").result, "deny")

    def test_url_auth_verbs(self):
        rules = [rule("deny", users=["*"], verbs=["POST"], order=1), rule("allow", users=["*"], order=2)]
        self.assertEqual(ev(rules, verb="GET").result, "allow")
        self.assertEqual(ev(rules, verb="post").result, "deny")
        self.assertEqual(ev(rules, verb="any").result, "allow", "most permissive of GET and POST")
        only_post = [rule("deny", users=["*"], order=1)]
        self.assertEqual(ev(only_post, verb="any").result, "deny")

    def test_url_auth_clear_remove(self):
        parent = rule("deny", users=["*"], order=1)
        cleared = [parent, rule("clear", scope="Open", file="Open/Web.config", order=1)]
        self.assertEqual(ev(cleared, "/Open/x").result, "allow", "clear then the implicit allow *")
        self.assertEqual(ev(cleared, "/Other").result, "deny")
        removed = [parent, rule("remove", scope="Open", file="Open/Web.config", order=1, users=["*"])]
        self.assertEqual(ev(removed, "/Open/x").result, "allow")
        keep = [parent, rule("remove", scope="Open", file="Open/Web.config", order=1, users=["?"])]
        self.assertEqual(ev(keep, "/Open/x").result, "deny", "a remove of another rule drops nothing")
        again = [parent, rule("clear", scope="Open", file="Open/Web.config", order=1),
                 rule("deny", scope="Open", file="Open/Web.config", order=2, users=["?"])]
        self.assertEqual(ev(again, "/Open/x", "anon").result, "deny")
        self.assertEqual(ev(again, "/Open/x", "auth").result, "allow")

    def test_url_auth_default_allow_star(self):
        self.assertEqual(ev([]).result, "allow")
        self.assertEqual(ev([]).reasons, ["implicit_default"])
        self.assertEqual(ev([rule("deny", users=["?"])], principal="auth").reasons, ["implicit_default"])
        self.assertEqual(url_chain([], "/")[-1]["source"], "implicit_default")

    def test_url_auth_named_user_precedes_gives_unknown(self):
        rules = [rule("allow", users=["bob"], order=1), rule("deny", users=["*"], order=2)]
        self.assertEqual(ev(rules).result, "unknown")
        after = [rule("deny", users=["?"], order=1), rule("allow", users=["bob"], order=2)]
        self.assertEqual(ev(after).result, "deny", "decided before the named user")
        self.assertEqual(ev(after, principal="auth").result, "unknown")
        mixed = [rule("allow", users=["bob"], roles=["Admins"], order=1), rule("deny", users=["*"], order=2)]
        self.assertEqual(ev(mixed, principal="role:admins").result, "allow")

    def test_nested_webconfig_applies_to_matching_route_prefix(self):
        rules = [rule("allow", users=["*"], order=1),
                 rule("deny", scope="Admin", file="Admin/Web.config", users=["?"], order=1)]
        self.assertEqual(ev(rules, "/Admin/Users/Edit").result, "deny")
        self.assertEqual(ev(rules, "~/admin").result, "deny")
        self.assertEqual(ev(rules, "/AdminTools").result, "allow")

    def test_area_folder_webconfig_does_not_apply_to_area_route(self):
        rules = [rule("allow", users=["*"], order=1),
                 rule("deny", scope="Areas/Reports", file="Areas/Reports/Web.config", users=["?"], order=1)]
        self.assertEqual(ev(rules, "/Areas/Reports/Export").result, "deny")
        self.assertEqual(ev(rules, "/Reports/Export").result, "allow")

    def test_unknown_transform_external_locked_unparsed(self):
        rules = [rule("deny", users=["?"], status="unknown_transform", reason_codes=["transform_lookup"])]
        self.assertEqual(ev(rules).result, "unknown")
        decided = [rule("allow", scope="Open", file="Open/Web.config", users=["*"], order=1),
                   rule("deny", users=["?"], status="unknown_external")]
        self.assertEqual(ev(decided, "/Open/x").result, "allow", "an unread rule behind the decision is not consulted")
        self.assertEqual(ev(decided, "/Closed").result, "unknown")
        locked = [rule("deny", users=["*"], order=1, location="Admin", allow_override=False,
                       reason_codes=["locked_with_nested_rules"], scope="Admin"),
                  rule("allow", scope="Admin/Sub", file="Admin/Sub/Web.config", users=["*"],
                       reason_codes=["under_locked_scope"])]
        self.assertEqual(ev(locked, "/Admin/Sub/x").result, "unknown")
        self.assertEqual(ev(locked, "/Admin/x").result, "deny")
        unparsed = [{"kind": "config_unparsed", "path": "Admin/Web.config", "line": None, "name": "Web.config",
                     "detail": {"reason": "malformed"}}, rule("allow", users=["*"])]
        self.assertEqual(ev(unparsed, "/Admin/x").result, "unknown")
        self.assertEqual(ev(unparsed, "/Home").result, "allow")
        ext = [{"kind": "config_external", "path": "Web.config", "line": 3,
                "name": "system.web/authorization@configSource", "detail": {"resolved": False}}]
        self.assertEqual(ev(ext, "/x").result, "unknown")

    def test_configuration_selection(self):
        rules = [rule("deny", users=["?"], config="base"), rule("allow", users=["*"], config="Release"),
                 rule("deny", scope="Admin", file="Admin/Web.config", users=["?"])]
        self.assertEqual(ev(rules, "/x", config="base").result, "deny")
        self.assertEqual(ev(rules, "/x", config="Release").result, "allow")
        self.assertEqual(ev(rules, "/Admin/x", config="Release").result, "deny", "nested file has base rules only")

    def test_principals_for_caps_and_dedupes(self):
        rules = [rule("allow", roles=["Admins", "staff"]), rule("deny", roles=["ADMINS"], order=2)]
        p = principals_for(rules, ["Auditors", "staff"])
        self.assertEqual(list(p), ["anon", "auth", "role:Admins", "role:Auditors", "role:staff"])
        self.assertEqual((p.shown, p.total), (3, 3))
        q = principals_for(rules, [], cap=1)
        self.assertEqual((list(q), q.shown, q.total), (["anon", "auth", "role:Admins"], 1, 2))


if __name__ == "__main__":
    unittest.main()
