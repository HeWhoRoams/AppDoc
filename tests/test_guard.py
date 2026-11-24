"""W4 effective protection per handler (appdoc/guard.py; T28.60, T28.61, T28.63-T28.67).

Two kinds of test. Pure ones build the Facts a Stack would emit and call ``guard.apply`` (no I/O); end-to-end ones write a
small invented Target to a temp folder and run ``extract.extract``, so the raw Facts that guard.py joins are the real ones.
Names in this file are invented (Contoso, Fabrikam); no secret, e-mail address or SID appears in any Fact.
"""

import json
import os
import random
import tempfile
import unittest

from appdoc import extract, facts as F, guard

BASE = "Controllers/{}.cs"


# --------------------------------------------------------------------------- Fact builders

def mk(kind, path, line, name, stack="aspnet", **d):
    return F.Fact.make(kind, stack, path, line, name, **d)


def ctrl(name, bases=("Controller",), external=False, stack="aspnet", **extra):
    return mk("controller_class", BASE.format(name), 5, name, stack=stack, base_list=list(bases), base_external=external, **extra)


def act(cls, method, line=10, url=None, verbs="ANY", stack="aspnet", **extra):
    name = cls[:-len("Controller")] if cls.endswith("Controller") else cls
    return mk("entry_point", BASE.format(cls), line, url or f"/{name}/{method}", stack=stack, type="route", method=verbs,
              handler=f"{cls}.{method}", inherits=extra.pop("inherits", ["Controller"]),
              base_external=extra.pop("base_external", False), end_line=extra.pop("end_line", line + 3), **extra)


def route(template, controller=None, action=None, name="Default", path="App_Start/RouteConfig.cs", area=None, http=False):
    d = {"type": "route", "method": "ANY", "route_name": name}
    if http:
        d["http_route"] = True
    if controller:
        d["handler"] = f"{controller}Controller.{action or '{action}'}"
    if area:
        d["mvc_area"] = area
    return mk("entry_point", path, 12, template, **d)


DEFAULT_ROUTE = route("/{controller}/{action}/{id}", "Home", "Index")


def authorize(cls, applies_to=None, roles=None, users=0, line=4, kinds=None, **extra):
    """The guard_use and the auth_check the Stack emits for ``[Authorize(...)]`` on a class or an action."""
    applies = applies_to or cls
    d = dict(applies_to=applies, attribute="Authorize", scope="method" if "." in applies else "class",
             arity=(1 if roles else 0) + (1 if users else 0), namespace="System.Web.Mvc",
             arg_kinds=kinds or (["literal"] if roles else []), **extra)
    if roles:
        d["role"] = roles[0] if len(roles) == 1 else list(roles)
        d["role_arg"] = "named"
    if users:
        d["users_named"] = users
    ac = dict(applies_to=applies, mechanism="attribute", namespace="System.Web.Mvc")
    if roles:
        ac["roles"] = list(roles)
    if users:
        ac["users_named"] = users
    return [mk("guard_use", BASE.format(cls), line, "Authorize", **d),
            mk("auth_check", BASE.format(cls), line, "[Authorize]", **ac)]


def allow_anon(cls, applies_to=None, line=4):
    return mk("auth_check", BASE.format(cls), line, "[AllowAnonymous]", applies_to=applies_to or cls, mechanism="attribute")


def glob(name="AuthorizeAttribute", api=False, roles=None):
    d = {"mechanism": "global-filter", "scope": "global"}
    if api:
        d["api_pipeline"] = True
    if roles:
        d["roles"] = roles
    return mk("auth_check", "Global.asax.cs", 12, name, **d)


def rule(effect, scope="", order=1, anon=False, all_=False, roles=(), users=0, config="base", status="base",
         file="Web.config", location=None):
    d = dict(effect=effect, scope_path=scope, order=order, config=config, config_status=status, file=file)
    if anon:
        d["anon"] = True
    if all_:
        d["all"] = True
    if roles:
        d["roles"] = list(roles)
    if users:
        d["users_named"] = users
    if location is not None:
        d["location"] = location
    return mk("access_rule", file, order, f"{effect} /{scope}", **d)


def deny_anon_allow_all(scope="", order=1, **kw):
    return [rule("deny", scope, order, anon=True, location=kw.get("location"), **{k: v for k, v in kw.items() if k != "location"}),
            rule("allow", scope, order + 1, all_=True, location=kw.get("location"), **{k: v for k, v in kw.items() if k != "location"})]


def host(owin=False, iis="unknown", source="none"):
    return mk("host_auth", "Web.config", 1, "host", iis_anonymous=iis, iis_authorization_present=False, owin_auth=owin, source=source)


def auth_mode(value, config="base"):
    return mk("security_setting", "Web.config", 4, "system.web/authentication@mode", config=config, config_status="base",
              value=value, secret_location=False)


def run(*facts):
    """``{handler: detail}`` of the entry points after the post-pass (first entry per handler)."""
    out = {}
    for f in guard.apply([x for part in facts for x in (part if isinstance(part, list) else [part])]):
        if f.kind == "entry_point" and f.detail_dict().get("handler"):
            out.setdefault(f.detail_dict()["handler"], f.detail_dict())
    return out


def detail_of(result, handler):
    return result[handler]


# --------------------------------------------------------------------------- end-to-end Targets

CSPROJ = '<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><TargetFramework>net48</TargetFramework></PropertyGroup></Project>\n'
GLOBAL_ASAX = '<%@ Application Codebehind="Global.asax.cs" Inherits="Contoso.Shop.MvcApplication" Language="C#" %>\n'
ROUTES = ('using System.Web.Mvc;\nusing System.Web.Routing;\nnamespace Contoso.Shop { public class RouteConfig {\n'
          'public static void RegisterRoutes(RouteCollection routes) {\n'
          'routes.MapRoute("Default", "{controller}/{action}/{id}", new { controller = "Home", action = "Index", id = UrlParameter.Optional });\n'
          '} } }\n')


def target(files: dict) -> dict:
    """Extract a temp Target made of ``files`` plus the minimum that makes it an ASP.NET one; ``{handler: detail}``."""
    with tempfile.TemporaryDirectory() as root, tempfile.TemporaryDirectory() as out:
        base = {"Global.asax": GLOBAL_ASAX, "Contoso.Shop.csproj": CSPROJ, "App_Start/RouteConfig.cs": ROUTES,
                "Web.config": '<?xml version="1.0"?><configuration><system.web><authentication mode="Forms"/></system.web></configuration>\n'}
        base.update(files)
        for rel, text in base.items():
            p = os.path.join(root, *rel.split("/"))
            os.makedirs(os.path.dirname(p), exist_ok=True)
            with open(p, "w", encoding="utf-8", newline="\n") as fh:
                fh.write(text)
        text, _ = extract.extract(root, out, workers=0, use_cache=False, no_ownership=True)
    doc = json.loads(text)
    res = {}
    for f in doc["facts"]:
        if f["kind"] == "entry_point" and f["detail"].get("handler") and f["stack"] == "aspnet" and not f["detail"].get("route_name"):
            res.setdefault(f["detail"]["handler"], f["detail"])
    return res


def controller_source(name, body, head="", base="Controller"):
    return ("using System.Web.Mvc;\nnamespace Contoso.Shop.Controllers\n{\n" + head +
            f"    public class {name} : {base}\n    {{\n{body}\n    }}\n}}\n")


# --------------------------------------------------------------------------- T28.60 scope

class Scope(unittest.TestCase):
    def test_core_reach_not_computed(self):
        c = ctrl("StatusController", ["ControllerBase"], stack="aspnet-core")
        e = act("StatusController", "Get", stack="aspnet-core", inherits=["ControllerBase"])
        d = run(c, e)["StatusController.Get"]
        self.assertEqual(d["guard_mechanism"], ["none"])
        for k in ("reach", "reach_anon", "reach_auth", "url_set", "verbs", "state_changing", "writes"):
            self.assertNotIn(k, d, k)

    def test_core_absence_only_without_auth_services(self):
        c = ctrl("StatusController", ["ControllerBase"], stack="aspnet-core")
        e = act("StatusController", "Get", stack="aspnet-core", inherits=["ControllerBase"])
        svc = mk("auth_check", "Program.cs", 6, "AddAuthorization", stack="aspnet-core", mechanism="services")
        d = run(c, e, svc)["StatusController.Get"]
        self.assertEqual(d["guard_mechanism"], ["unknown"], "a registered service is not an absence of authorization")
        self.assertIn("auth_services_registered", d["reasons"])
        fixture = mk("auth_check", "fixtures/sample-core-app/Program.cs", 2, "AddAuthentication", stack="aspnet-core",
                     mechanism="services")
        self.assertEqual(run(c, e, fixture)["StatusController.Get"]["guard_mechanism"], ["none"],
                         "a service token under a fixtures folder is not the Target's")

    def test_core_attribute_is_a_mechanism_even_with_services(self):
        c = ctrl("StatusController", ["ControllerBase"], stack="aspnet-core")
        e = act("StatusController", "Reset", stack="aspnet-core", inherits=["ControllerBase"])
        a = [mk("guard_use", BASE.format("StatusController"), 4, "Authorize", applies_to="StatusController.Reset",
                attribute="Authorize", scope="method", arity=1, arg_kinds=["literal"], role="Ops", role_arg="named"),
             mk("auth_check", BASE.format("StatusController"), 4, "[Authorize(Roles = \"Ops\")]", stack="aspnet-core",
                applies_to="StatusController.Reset", mechanism="attribute", roles=["Ops"])]
        d = run(c, e, a, mk("auth_check", "Program.cs", 6, "AddAuthorization", stack="aspnet-core", mechanism="services"))
        self.assertEqual(d["StatusController.Reset"]["guard_mechanism"], ["attribute"])

    def test_mapped_route_without_controller_gets_no_reach(self):
        # the conventional MapRoute Fact names HomeController.Index but sits in RouteConfig.cs, not in a controller file
        d = run(DEFAULT_ROUTE, ctrl("HomeController"))
        self.assertNotIn("reach", d["HomeController.Index"])
        self.assertNotIn("guard_mechanism", d["HomeController.Index"])

    def test_handler_not_in_the_target_is_not_evaluated(self):
        e = act("GhostController", "Index")          # no controller_class Fact: the class is not in the Target
        self.assertNotIn("guard_mechanism", run(e)["GhostController.Index"])

    def test_child_action_only_is_not_evaluated(self):
        d = run(ctrl("HomeController"), act("HomeController", "Menu", child_action=True))
        self.assertNotIn("guard_mechanism", d["HomeController.Menu"])

    def test_other_stacks_are_untouched(self):
        e = mk("entry_point", "app.js", 3, "/health", stack="node-express", type="route", method="GET", handler="health")
        out = guard.apply([e])
        self.assertEqual(out, [e])

    def test_test_code_is_untouched(self):
        c = ctrl("HomeController")
        e = act("HomeController", "Index", test=True)
        self.assertNotIn("guard_mechanism", run(c, e)["HomeController.Index"])

    def test_non_action_and_private_methods_are_not_entry_points_end_to_end(self):
        src = controller_source("HomeController", """
        [NonAction] public ActionResult Hidden() { return View(); }
        [ChildActionOnly] public ActionResult Menu() { return View(); }
        private ActionResult Secret() { return View(); }
        public ActionResult Index() { return View(); }""")
        got = target({"Controllers/HomeController.cs": src})
        self.assertIn("guard_mechanism", got["HomeController.Index"])
        self.assertNotIn("HomeController.Hidden", got)
        self.assertNotIn("HomeController.Secret", got)
        self.assertNotIn("guard_mechanism", got["HomeController.Menu"])


# --------------------------------------------------------------------------- T28.61 URL set

class UrlSet(unittest.TestCase):
    def urls(self, result, handler):
        v = result[handler]["url_set"]
        return v if v == "open" else {("/" + u.strip("/")).lower() for u in v}

    def test_default_route_alias_urls_all_checked(self):
        # a rule on Home/Index does not protect / or /Home: the most permissive URL wins
        facts = [ctrl("HomeController"), act("HomeController", "Index", url="/Home/Index"), DEFAULT_ROUTE,
                 rule("allow", "", 1, all_=True),
                 rule("deny", "Home/Index", 2, anon=True, location="Home/Index"),
                 rule("allow", "Home/Index", 3, all_=True, location="Home/Index")]
        got = run(*facts)
        self.assertEqual(self.urls(got, "HomeController.Index"), {"/", "/home", "/home/index"})
        self.assertEqual(got["HomeController.Index"]["reach_anon"], "allow")
        self.assertEqual(got["HomeController.Index"]["reach"], "no_app_restriction")

    def test_default_route_only_aliases_the_default_controller(self):
        got = run(ctrl("BillingController"), act("BillingController", "Index"), act("BillingController", "Pay"), DEFAULT_ROUTE)
        self.assertEqual(self.urls(got, "BillingController.Index"), {"/billing", "/billing/index"})
        self.assertEqual(self.urls(got, "BillingController.Pay"), {"/billing/pay"})

    def test_open_route_gives_unknown(self):
        docs = route("/{culture}/docs/{id}", "Docs", "Show", name="CatchAll")
        got = run(ctrl("DocsController"), act("DocsController", "Show"), docs, DEFAULT_ROUTE, rule("allow", "", 1, all_=True))
        d = got["DocsController.Show"]
        self.assertEqual(d["url_set"], "open")
        self.assertEqual(d["reach_anon"], "unknown")
        self.assertIn("url_set_open", d["reasons"])

    def test_url_set_open_on_nonliteral_segment(self):
        for template in ("/{culture}/docs/{id}", "/{*path}/docs", "/{lang:regex(^[a-z]{2}$)}/docs"):
            with self.subTest(template=template):
                urls, open_ = guard._template_urls(template, {})
                self.assertTrue(open_, template)
        for template in ("/docs/{id}", "/docs/{id?}", "/docs/{*rest}", "/docs/{id:int}"):
            with self.subTest(template=template):
                urls, open_ = guard._template_urls(template, {})
                self.assertFalse(open_, template)
                self.assertEqual(urls, ["/docs"])

    def test_constrained_controller_segment_is_open(self):
        urls, open_ = guard._template_urls("/{controller:regex(a.*)}/{action}", {"controller": ("A", None), "action": ("B", None)})
        self.assertTrue(open_)

    def test_attribute_route_excludes_the_conventional_urls(self):
        e = act("AccountController", "Login", url="/signin", attr_route=True)
        got = run(ctrl("AccountController"), e, mk("entry_point", BASE.format("AccountController"), 20, "/auth/login",
                  type="route", method="ANY", handler="AccountController.Login", attr_route=True, end_line=24), DEFAULT_ROUTE)
        self.assertEqual(self.urls(got, "AccountController.Login"), {"/signin", "/auth/login"})

    def test_http_verb_attribute_without_route_stays_conventional(self):
        e = act("AccountController", "Save", verbs="POST")          # [HttpPost] only: no attr_route
        got = run(ctrl("AccountController"), e, DEFAULT_ROUTE)
        self.assertEqual(self.urls(got, "AccountController.Save"), {"/account/save"})

    def test_extra_trailing_segments_do_not_change_the_url(self):
        e = act("InvoicesController", "Show", url="/invoices/{id:int?}", attr_route=True)
        got = run(ctrl("InvoicesController"), e)
        self.assertEqual(self.urls(got, "InvoicesController.Show"), {"/invoices"})

    def test_area_registration_route_is_used_for_area_controllers(self):
        area = route("/info/{controller}/{action}/{id}", name="Public_default", path="Areas/Public/PublicAreaRegistration.cs",
                     area="Public")
        c = mk("controller_class", "Areas/Public/Controllers/NoticesController.cs", 5, "NoticesController",
               base_list=["Controller"], base_external=False)
        e = mk("entry_point", "Areas/Public/Controllers/NoticesController.cs", 10, "/Notices/Index", type="route", method="ANY",
               handler="NoticesController.Index", inherits=["Controller"], base_external=False, mvc_area="Public",
               mvc_area_path="Areas/Public", end_line=13)
        got = run(c, e, area, DEFAULT_ROUTE)
        self.assertEqual(self.urls(got, "NoticesController.Index"), {"/info/notices/index"})

    def test_web_api_conventional_route_has_no_action_segment(self):
        api = route("/api/{controller}/{id}", name="DefaultApi", path="App_Start/WebApiConfig.cs", http=True)
        c = ctrl("ItemsController", ["ApiController"])
        e = act("ItemsController", "GetItems", verbs="GET", inherits=["ApiController"], url="/api/Items")
        got = run(c, e, api, DEFAULT_ROUTE)
        self.assertEqual(self.urls(got, "ItemsController.GetItems"), {"/api/items"})

    def test_fallback_is_the_stacks_own_conventional_route(self):
        got = run(ctrl("HomeController"), act("HomeController", "Index"))
        self.assertEqual(self.urls(got, "HomeController.Index"), {"/home/index"})


# --------------------------------------------------------------------------- T28.63 filters

class Filters(unittest.TestCase):
    def reach(self, *facts, handler="HomeController.Index"):
        d = run(*facts)[handler]
        return d["reach_anon"], d["reach_auth"], d

    def test_filters_and_class_and_method_are_anded(self):
        facts = [ctrl("HomeController"), act("HomeController", "Index"), authorize("HomeController"),
                 authorize("HomeController", "HomeController.Index", roles=["Admins"], line=9)]
        anon, auth, d = self.reach(*facts)
        self.assertEqual((anon, auth), ("deny", "deny"))
        self.assertEqual((d["reach"], d["reach_roles"]), ("role_restricted", ["Admins"]))

    def test_role_restriction_label(self):
        facts = [ctrl("HomeController"), act("HomeController", "Index"),
                 authorize("HomeController", roles=["Admins", "Staff"])]
        anon, auth, d = self.reach(*facts)
        self.assertEqual((anon, auth, d["reach"]), ("deny", "deny", "role_restricted"))
        self.assertEqual(d["reach_roles"], ["Admins", "Staff"])

    def test_in_target_base_class_filter_applies(self):
        base = mk("controller_class", BASE.format("SecureController"), 5, "SecureController", base_list=["Controller"],
                  base_external=False)
        c = ctrl("ReportsController", ["SecureController"])
        facts = [base, c, act("ReportsController", "Index", inherits=["SecureController"]),
                 authorize("SecureController", roles=["Auditors"])]
        d = run(*facts)["ReportsController.Index"]
        self.assertEqual((d["reach_anon"], d["reach_auth"], d["reach"]), ("deny", "deny", "role_restricted"))
        self.assertEqual(d["guard_mechanism"], ["attribute"])

    def test_allow_anonymous_on_controller_disables_action_authorize(self):
        facts = [ctrl("HomeController"), act("HomeController", "Index"), allow_anon("HomeController"),
                 authorize("HomeController", "HomeController.Index", roles=["Admins"], line=9)]
        anon, auth, d = self.reach(*facts)
        self.assertEqual((anon, auth), ("allow", "allow"))
        self.assertIn("allow_anonymous", d["guard_mechanism"])

    def test_allow_anonymous_does_not_override_url_deny(self):
        facts = [ctrl("LockedController"), act("LockedController", "Index"), allow_anon("LockedController"),
                 rule("allow", "", 1, all_=True), rule("deny", "Locked", 2, anon=True, location="Locked"),
                 rule("allow", "Locked", 3, all_=True, location="Locked")]
        d = run(*facts)["LockedController.Index"]
        self.assertEqual((d["reach_anon"], d["reach_auth"]), ("deny", "allow"))

    def test_allow_anonymous_disables_the_global_filter_too(self):
        facts = [ctrl("OpenController"), act("OpenController", "Index"), allow_anon("OpenController"), glob()]
        self.assertEqual(self.reach(*facts, handler="OpenController.Index")[0], "allow")

    def test_override_authorization_clears_outer(self):
        facts = [ctrl("HomeController"), act("HomeController", "Index", override_authorization=True),
                 authorize("HomeController", roles=["Admins"]), glob()]
        anon, auth, d = self.reach(*facts)
        self.assertEqual((anon, auth), ("allow", "allow"))
        self.assertEqual(d["guard_mechanism"], ["override_authorization"])

    def test_override_authorization_keeps_the_method_level_filter(self):
        facts = [ctrl("HomeController"), act("HomeController", "Index", override_authorization=True),
                 authorize("HomeController", roles=["Admins"]),
                 authorize("HomeController", "HomeController.Index", line=9)]
        anon, auth, _ = self.reach(*facts)
        self.assertEqual((anon, auth), ("deny", "allow"))

    def test_class_level_override_clears_the_global_filter_and_keeps_the_class(self):
        facts = [mk("controller_class", BASE.format("HomeController"), 5, "HomeController", base_list=["Controller"],
                    base_external=False, override_authorization=True),
                 act("HomeController", "Index"), glob(), authorize("HomeController", roles=["Staff"])]
        anon, auth, _ = self.reach(*facts)
        self.assertEqual((anon, auth), ("deny", "deny"))

    def test_authorize_roles_and_users_on_one_attribute(self):
        facts = [ctrl("BothController"), act("BothController", "Index"), authorize("BothController", roles=["Admins"], users=1)]
        d = run(*facts)["BothController.Index"]
        self.assertEqual((d["reach_anon"], d["reach_auth"]), ("deny", "deny"))
        self.assertNotIn("reach_roles", d, "a named user is no role archetype")

    def test_two_authorize_attributes_anded(self):
        facts = [ctrl("HomeController"), act("HomeController", "Index"),
                 authorize("HomeController", roles=["Admins"], line=4),
                 authorize("HomeController", roles=["Staff"], line=5)]
        d = run(*facts)["HomeController.Index"]
        self.assertNotIn("reach_roles", d, "no archetype is in both roles")
        self.assertEqual(d["reach"], "denied")

    def test_plain_authorize_admits_every_signed_in_archetype(self):
        d = run(ctrl("HomeController"), act("HomeController", "Index"), authorize("HomeController"))["HomeController.Index"]
        self.assertEqual((d["reach_anon"], d["reach_auth"], d["reach"]), ("deny", "allow", "signed_in_any"))

    def test_global_filter_applies_to_mvc_and_not_to_web_api(self):
        mvc = [ctrl("HomeController"), act("HomeController", "Index")]
        api = [ctrl("ItemsController", ["ApiController"]), act("ItemsController", "GetItems", verbs="GET", inherits=["ApiController"])]
        d = run(*mvc, *api, glob(), glob(api=True, roles=None))
        self.assertEqual(d["HomeController.Index"]["reach_anon"], "deny")
        only_mvc = run(*mvc, *api, glob())
        self.assertEqual(only_mvc["ItemsController.GetItems"]["reach_anon"], "allow", "a Web API call is not MVC's global filter")

    def test_non_auth_global_filter_is_not_a_guard(self):
        # the Stack never emits HandleErrorAttribute; an in-Target filter that is not authorization-capable is ignored here
        plain = mk("guard_class", "Filters/LogFilter.cs", 3, "LogFilter", base_list=["ActionFilterAttribute"],
                   base_external=False, overrides_authorization=False, authorization_capable=False)
        d = run(ctrl("HomeController"), act("HomeController", "Index"), plain, glob("LogFilter"))["HomeController.Index"]
        self.assertEqual(d["guard_mechanism"], ["none"])
        self.assertEqual(d["reach_anon"], "allow")

    def test_external_global_filter_is_unknown(self):
        d = run(ctrl("HomeController"), act("HomeController", "Index"), glob("ElmahFilter"))["HomeController.Index"]
        self.assertIn("global_filter_unknown", d["reasons"])
        self.assertEqual(d["reach_anon"], "unknown")

    def test_global_filter_in_global_asax_found(self):
        src = {"Global.asax.cs": ("using System.Web.Mvc;\nnamespace Contoso.Shop {\npublic class MvcApplication : System.Web.HttpApplication {\n"
                                  "protected void Application_Start() {\nGlobalFilters.Filters.Add(new AuthorizeAttribute());\n"
                                  "GlobalFilters.Filters.Add(new HandleErrorAttribute());\n} } }\n"),
               "Controllers/HomeController.cs": controller_source("HomeController", "        public ActionResult Index() { return View(); }")}
        d = target(src)["HomeController.Index"]
        self.assertEqual(d["guard_mechanism"], ["global-filter"])
        self.assertEqual((d["reach_anon"], d["reach_auth"]), ("deny", "allow"))

    def test_global_filter_in_a_filterconfig_method_found(self):
        src = {"App_Start/FilterConfig.cs": ("using System.Web.Mvc;\nnamespace Contoso.Shop {\npublic class FilterConfig {\n"
                                             "public static void RegisterGlobalFilters(GlobalFilterCollection filters) {\n"
                                             "filters.Add(new HandleErrorAttribute());\nfilters.Add(new AuthorizeAttribute());\n} } }\n"),
               "Controllers/HomeController.cs": controller_source("HomeController", "        public ActionResult Index() { return View(); }")}
        self.assertEqual(target(src)["HomeController.Index"]["reach_anon"], "deny")

    def test_override_authorization_end_to_end(self):
        src = controller_source("PageController", "        [OverrideAuthorization]\n        public ActionResult Index() { return View(); }",
                                head="    [Authorize(Roles = \"Admins\")]\n")
        d = target({"Controllers/PageController.cs": src})["PageController.Index"]
        self.assertEqual(d["guard_mechanism"], ["override_authorization"])
        self.assertEqual(d["reach_anon"], "allow")

    def test_const_role_argument_is_resolved_for_the_filter(self):
        consts = ("namespace Contoso.Shop { public static class Roles { public const string Admin = \"PortalAdmins\"; } }\n")
        src = controller_source("AdminController", "        public ActionResult Index() { return View(); }",
                                head="    [Authorize(Roles = Roles.Admin)]\n")
        got = target({"Roles.cs": consts, "Controllers/AdminController.cs": src})["AdminController.Index"]
        self.assertEqual((got["reach_anon"], got["reach"]), ("deny", "role_restricted"))
        self.assertEqual(got["reach_roles"], ["PortalAdmins"])


# --------------------------------------------------------------------------- T28.64 unknowns

class Unknowns(unittest.TestCase):
    def test_unresolved_base_is_unknown(self):
        c = ctrl("OrphanController", ["SharedControllerBase"], external=True)
        e = act("OrphanController", "Index", inherits=["SharedControllerBase"], base_external=True)
        d = run(c, e, glob())["OrphanController.Index"]
        self.assertIn("unknown", d["guard_mechanism"])
        self.assertIn("unresolved_base", d["reasons"])
        self.assertEqual((d["reach_anon"], d["reach_auth"], d["reach"]), ("unknown", "unknown", "unknown"))

    test_unresolved_base_gives_unknown = test_unresolved_base_is_unknown

    def test_unknown_never_collapses_to_none(self):
        cases = {
            "unresolved base": ([ctrl("HomeController", ["Mystery"], external=True),
                                 act("HomeController", "Index", inherits=["Mystery"], base_external=True)], []),
            "in-body check": ([ctrl("HomeController"), act("HomeController", "Index", line=10, end_line=14)],
                              [mk("auth_check", BASE.format("HomeController"), 12, 'User.IsInRole("Ops")', mechanism="role", roles=["Ops"])]),
            "filter provider": ([ctrl("HomeController"), act("HomeController", "Index")],
                                [mk("auth_check", "Global.asax.cs", 9, "FilterProviders", mechanism="filter-provider")]),
            "hook override": ([mk("controller_class", BASE.format("HomeController"), 5, "HomeController", base_list=["Controller"],
                                  base_external=False, filter_hooks=["OnActionExecuting"]), act("HomeController", "Index")], []),
            "candidate": ([ctrl("HomeController"), act("HomeController", "Index")],
                          [mk("guard_candidate", BASE.format("ReportsController"), 4, "StaffOnly", attribute="StaffOnly", uses=3, arity_set=[1]),
                           mk("guard_use", BASE.format("HomeController"), 4, "StaffOnly", attribute="StaffOnly", applies_to="HomeController",
                              scope="class", arity=1, arg_kinds=["literal"])]),
        }
        for label, (base, extra) in cases.items():
            with self.subTest(label):
                d = run(*base, *extra)["HomeController.Index"]
                self.assertNotEqual(d["guard_mechanism"], ["none"])
                self.assertIn("unknown", d["guard_mechanism"])
                self.assertEqual(d["reach_anon"], "unknown")
                self.assertNotEqual(d["reach"], "no_app_restriction")

    def test_inbody_isinrole_gives_unknown_not_none(self):
        src = controller_source("OpsController", """
        public ActionResult Index()
        {
            if (!User.IsInRole("Ops")) { return new HttpUnauthorizedResult(); }
            return View();
        }
        public ActionResult Plain() { return View(); }""")
        got = target({"Controllers/OpsController.cs": src})
        self.assertIn("inbody", got["OpsController.Index"]["guard_mechanism"])
        self.assertIn("unknown", got["OpsController.Index"]["guard_mechanism"])
        self.assertEqual(got["OpsController.Plain"]["guard_mechanism"], ["none"], "the check is in another method's span")

    def test_base_onactionexecuting_override_gives_unknown(self):
        base = ("using System.Web.Mvc;\nnamespace Contoso.Shop.Controllers { public class BaseController : Controller {\n"
                "protected override void OnActionExecuting(ActionExecutingContext filterContext) {\n"
                "if (Session[\"u\"] == null) { filterContext.Result = RedirectToAction(\"Login\"); }\nbase.OnActionExecuting(filterContext); } } }\n")
        child = controller_source("HomeController", "        public ActionResult Index() { return View(); }", base="BaseController")
        redirect_only = target({"Controllers/BaseController.cs": base, "Controllers/HomeController.cs": child})["HomeController.Index"]
        self.assertNotIn("hook_override", redirect_only.get("reasons", []), "a pure redirect is not an authorization hook")
        base2 = base.replace('if (Session["u"] == null) { filterContext.Result = RedirectToAction("Login"); }',
                             'if (User.Identity.Name == "x") { LogIt(); filterContext.Result = new HttpUnauthorizedResult(); }')
        d = target({"Controllers/BaseController.cs": base2, "Controllers/HomeController.cs": child})["HomeController.Index"]
        self.assertIn("hook_override", d["reasons"])
        self.assertIn("unknown", d["guard_mechanism"])

    def test_undeclared_candidate_with_authorize_is_unknown(self):
        facts = [ctrl("HomeController"), act("HomeController", "Index"), authorize("HomeController"),
                 mk("guard_candidate", BASE.format("ReportsController"), 4, "StaffOnly", attribute="StaffOnly", uses=3, arity_set=[1]),
                 mk("guard_use", BASE.format("HomeController"), 5, "StaffOnly", attribute="StaffOnly", applies_to="HomeController",
                    scope="class", arity=1, arg_kinds=["literal"])]
        d = run(*facts)["HomeController.Index"]
        self.assertEqual(d["reach_auth"], "unknown", "never downgraded to signed-in")
        self.assertIn("guard_candidate", d["reasons"])
        self.assertEqual(d["reach"], "unknown")

    def test_filterprovider_registration_gives_unknown(self):
        src = {"App_Start/Providers.cs": ("using System.Web.Mvc;\nnamespace Contoso.Shop { public class P {\n"
                                          "public static void Reg() { FilterProviders.Providers.Add(new MyProvider()); } } }\n"),
               "Controllers/HomeController.cs": controller_source("HomeController", "        public ActionResult Index() { return View(); }",
                                                                  head="    [Authorize]\n")}
        # the provider file has no controller: the registration is still found (any file of the Target)
        d = target(src)["HomeController.Index"]
        self.assertIn("unknown", d["guard_mechanism"])

    def test_custom_guard_without_role_arguments_is_unknown(self):
        facts = [ctrl("HomeController"), act("HomeController", "Index"),
                 mk("auth_check", BASE.format("HomeController"), 4, "[StaffOnly]", applies_to="HomeController", mechanism="attribute",
                    via="custom", scope="class", arity=0, role_guard=False)]
        d = run(*facts)["HomeController.Index"]
        self.assertIn("custom_guard_no_args", d["reasons"])
        self.assertEqual(d["reach_anon"], "unknown")

    def test_custom_guard_that_overrides_authorization_is_unknown(self):
        facts = [ctrl("HomeController"), act("HomeController", "Index"),
                 mk("auth_check", BASE.format("HomeController"), 4, "[StaffOnly]", applies_to="HomeController", mechanism="attribute",
                    via="custom", scope="class", arity=1, role_guard=False, overrides_authorization=True)]
        d = run(*facts)["HomeController.Index"]
        self.assertIn("guard_overrides_authorization", d["reasons"])

    def test_declared_guard_with_role_argument_is_a_role_guard(self):
        facts = [ctrl("HomeController"), act("HomeController", "Index"),
                 mk("auth_check", BASE.format("HomeController"), 4, "[StaffOnly]", applies_to="HomeController", mechanism="attribute",
                    via="declared", scope="class", arity=1, role_guard=True, roles=["Staff"])]
        d = run(*facts)["HomeController.Index"]
        self.assertEqual((d["reach_anon"], d["reach_auth"]), ("deny", "deny"))
        self.assertEqual(d["reach_roles"], ["Staff"])

    def test_declared_guard_without_args_is_unknown_reach(self):
        facts = [ctrl("HomeController"), act("HomeController", "Index"),
                 mk("auth_check", BASE.format("HomeController"), 4, "[StaffOnly]", applies_to="HomeController", mechanism="attribute",
                    via="declared", scope="class", arity=0, role_guard=False)]
        d = run(*facts)["HomeController.Index"]
        self.assertEqual(d["reach_auth"], "unknown")
        self.assertIn("declared_guard_no_args", d["reasons"])

    def test_unresolved_role_argument_denies_anon_and_leaves_signed_in_unknown(self):
        use = authorize("HomeController", roles=None, kinds=["expression"], role_ref="expression", role_arg="named")
        d = run(ctrl("HomeController"), act("HomeController", "Index"), use)["HomeController.Index"]
        self.assertEqual((d["reach_anon"], d["reach_auth"]), ("deny", "unknown"))

    def test_unparsed_web_config_is_unknown(self):
        facts = [ctrl("HomeController"), act("HomeController", "Index"),
                 mk("config_unparsed", "Web.config", None, "Web.config", reason="malformed")]
        d = run(*facts)["HomeController.Index"]
        self.assertIn("config_unparsed", d["reasons"])
        self.assertEqual(d["reach_anon"], "unknown")


# --------------------------------------------------------------------------- T28.66 verbs and writes

class Verbs(unittest.TestCase):
    def test_verbless_action_is_any_not_post(self):
        d = run(ctrl("HomeController"), act("HomeController", "Subscribe"))["HomeController.Subscribe"]
        self.assertEqual((d["verbs"], d["verbs_declared"]), (["any"], False))

    def test_declared_verbs_are_a_closed_sorted_list(self):
        d = run(ctrl("HomeController"), act("HomeController", "Edit", verbs="POST,GET"))["HomeController.Edit"]
        self.assertEqual((d["verbs"], d["verbs_declared"]), (["GET", "POST"], True))

    def test_state_changing_tristate(self):
        c = ctrl("HomeController")
        cases = {
            "declared POST": (act("HomeController", "A", verbs="POST"), "true"),
            "declared DELETE": (act("HomeController", "B", verbs="DELETE"), "true"),
            "declared GET, no write": (act("HomeController", "C", verbs="GET"), "false"),
            "verb-less, no write": (act("HomeController", "D"), "unknown"),
        }
        for label, (e, want) in cases.items():
            with self.subTest(label):
                self.assertEqual(run(c, e)[e.detail_dict()["handler"]]["state_changing"], want)
        write = mk("external_call", BASE.format("HomeController"), 11, "~/App_Data/x.txt", type="file", operation="File.AppendAllText")
        any_write = act("HomeController", "E", line=10, end_line=13)
        get_write = act("HomeController", "F", line=20, verbs="GET", end_line=23)
        got = run(c, any_write, get_write, write,
                  mk("external_call", BASE.format("HomeController"), 21, "~/App_Data/y.txt", type="file", operation="File.WriteAllText"))
        self.assertEqual((got["HomeController.E"]["state_changing"], got["HomeController.E"]["writes"]), ("true", True))
        self.assertEqual(got["HomeController.F"]["state_changing"], "true", "a GET that writes is state changing")

    def test_get_with_a_state_change_on_get_smell_is_state_changing(self):
        e = act("HomeController", "Purge", line=12, verbs="GET", end_line=16)
        smell = mk("smell", BASE.format("HomeController"), 11, "`[HttpGet]` action changes state", pattern="state-change-on-get", fid="ab12cd34")
        d = run(ctrl("HomeController"), e, smell)["HomeController.Purge"]
        self.assertEqual(d["state_changing"], "true")
        self.assertIs(d["writes"], False, "the smell is a write hit but not an external_call or data_access in the span")

    def test_webapi_name_convention_verb(self):
        c = ctrl("ItemsController", ["ApiController"])
        es = [act("ItemsController", "GetItems", inherits=["ApiController"]),
              act("ItemsController", "PostItem", inherits=["ApiController"]),
              act("ItemsController", "DeleteItem", inherits=["ApiController"]),
              act("ItemsController", "Health", inherits=["ApiController"])]
        got = run(c, *es)
        self.assertEqual((got["ItemsController.GetItems"]["verbs"], got["ItemsController.GetItems"]["verbs_declared"]), (["GET"], False))
        self.assertEqual(got["ItemsController.PostItem"]["verbs"], ["POST"])
        self.assertEqual(got["ItemsController.PostItem"]["state_changing"], "true")
        self.assertEqual(got["ItemsController.DeleteItem"]["verbs"], ["DELETE"])
        self.assertEqual(got["ItemsController.Health"]["verbs"], ["any"], "no prefix, no verb")

    def test_convention_verb_from_the_stack_is_not_declared(self):
        e = act("ItemsController", "PostItem", verbs="POST", verb_convention=True, inherits=["ApiController"])
        d = run(ctrl("ItemsController", ["ApiController"]), e)["ItemsController.PostItem"]
        self.assertEqual((d["verbs"], d["verbs_declared"]), (["POST"], False))

    def test_acceptverbs_enum_and_string_forms(self):
        body = """
        [AcceptVerbs(HttpVerbs.Post | HttpVerbs.Put)] public ActionResult Enum() { return View(); }
        [AcceptVerbs("GET", "HEAD")] public ActionResult Str() { return View(); }
        [HttpPost] public ActionResult Attr() { return View(); }
        public ActionResult Bare() { return View(); }"""
        got = target({"Controllers/FormsController.cs": controller_source("FormsController", body)})
        self.assertEqual((got["FormsController.Enum"]["verbs"], got["FormsController.Enum"]["verbs_declared"]), (["POST", "PUT"], True))
        self.assertEqual(got["FormsController.Str"]["verbs"], ["GET", "HEAD"])
        self.assertEqual(got["FormsController.Attr"]["verbs"], ["POST"])
        self.assertEqual((got["FormsController.Bare"]["verbs"], got["FormsController.Bare"]["verbs_declared"]), (["any"], False))

    def test_writes_flag_from_span(self):
        body = """
        public ActionResult Save(string a)
        {
            System.IO.File.AppendAllText(Server.MapPath("~/App_Data/a.txt"), a);
            return View();
        }
        public ActionResult Read()
        {
            return Content(System.IO.File.ReadAllText(Server.MapPath("~/App_Data/a.txt")));
        }
        public ActionResult Idle() { return View(); }"""
        got = target({"Controllers/NotesController.cs": controller_source("NotesController", body)})
        self.assertIs(got["NotesController.Save"]["writes"], True)
        self.assertEqual(got["NotesController.Save"]["state_changing"], "true")
        self.assertIs(got["NotesController.Read"]["writes"], False, "a file read is not a write")
        self.assertEqual(got["NotesController.Read"]["state_changing"], "unknown")
        self.assertIs(got["NotesController.Idle"]["writes"], False)

    def test_data_access_write_counts_and_select_does_not(self):
        c = ctrl("HomeController")
        e1, e2 = act("HomeController", "A", line=10, end_line=13), act("HomeController", "B", line=20, end_line=23)
        d1 = mk("data_access", BASE.format("HomeController"), 11, "Orders", stack="aspnet", type="sql", operation="update")
        d2 = mk("data_access", BASE.format("HomeController"), 21, "Orders", stack="aspnet", type="sql", operation="select")
        got = run(c, e1, e2, d1, d2)
        self.assertIs(got["HomeController.A"]["writes"], True)
        self.assertIs(got["HomeController.B"]["writes"], False)


# --------------------------------------------------------------------------- T28.65 reach

class Reach(unittest.TestCase):
    def home(self, *extra, handler="HomeController.Index", **kw):
        return run(ctrl("HomeController"), act("HomeController", "Index", **kw), *extra)[handler]

    def test_reach_labels(self):
        cases = {
            "no_app_restriction": [],
            "signed_in_any": [authorize("HomeController")],
            "role_restricted": [authorize("HomeController", roles=["Admins"])],
            "denied": [rule("deny", "", 1, all_=True)],
            "unknown": [authorize("HomeController", roles=None, kinds=["expression"], role_ref="expression", role_arg="named"),
                        rule("allow", "", 1, all_=True)],
        }
        for label, extra in cases.items():
            with self.subTest(label):
                d = self.home(*extra)
                self.assertEqual(d["reach"], label, d)

    def test_denied_label_needs_no_unknown(self):
        d = self.home(rule("deny", "", 1, all_=True))
        self.assertEqual((d["reach_anon"], d["reach_auth"]), ("deny", "deny"))
        self.assertNotIn("reach_roles", d)

    def test_owin_none_is_unknown(self):
        d = self.home(host(owin=True), auth_mode("none"))
        self.assertEqual(d["reach"], "unknown")
        self.assertIn("owin", d["reasons"])

    test_owin_none_mode_is_unknown = test_owin_none_is_unknown

    def test_owin_with_another_mode_is_only_disclosed(self):
        d = self.home(host(owin=True), auth_mode("forms"))
        self.assertEqual(d["reach"], "no_app_restriction")
        self.assertIn("owin_present", d["reasons"])
        self.assertNotIn("owin", d["reasons"])

    def test_windows_mode_no_rules_label_with_reason(self):
        d = self.home(host(), auth_mode("windows"))
        self.assertEqual(d["reach"], "no_app_restriction")
        self.assertIn("iis_anonymous_unknown", d["reasons"])

    test_reach_iis_anonymous_unknown_is_disclosed = test_windows_mode_no_rules_label_with_reason

    def test_host_auth_set_is_a_reason(self):
        d = self.home(host(iis="disabled", source="config"), auth_mode("windows"))
        self.assertIn("host_auth_set", d["reasons"])
        self.assertNotIn("iis_anonymous_unknown", d["reasons"])
        d = self.home(host(iis="unknown", source="csproj_dev_only"))
        self.assertNotIn("host_auth_set", d.get("reasons", []))

    def test_reach_authenticated_from_release_root_rule(self):
        facts = [rule("allow", "", 1, roles=["Staff"], config="Debug"), rule("allow", "", 2, all_=True, config="Debug"),
                 rule("allow", "", 1, roles=["Staff"]), rule("allow", "", 2, all_=True),
                 rule("deny", "", 1, anon=True, config="Release"), rule("allow", "", 2, all_=True, config="Release")]
        d = self.home(*facts)
        self.assertEqual((d["reach_anon"], d["reach_auth"], d["reach"]), ("deny", "allow", "signed_in_any"))
        self.assertEqual(d["reach_by_config"], ["Debug=no_app_restriction", "Release=signed_in_any"])

    def test_production_config_declared(self):
        facts = [rule("deny", "", 1, anon=True, config="Release"), rule("allow", "", 2, all_=True, config="Release"),
                 rule("allow", "", 1, all_=True, config="Staging")]
        self.assertEqual(self.home(*facts)["reach"], "signed_in_any")
        decl = mk("context_directive", "appdoc-context.md", 3, "Production config", stack="generic",
                  directive="production_config", value="Staging")
        self.assertEqual(self.home(*facts, decl)["reach"], "no_app_restriction")

    def test_reach_by_config_only_when_multiple(self):
        one = self.home(rule("deny", "", 1, anon=True, config="Release"), rule("allow", "", 2, all_=True, config="Release"))
        self.assertNotIn("reach_by_config", one)
        none = self.home(rule("allow", "", 1, all_=True))
        self.assertNotIn("reach_by_config", none)
        two = self.home(rule("allow", "", 1, all_=True, config="Debug"), rule("deny", "", 1, all_=True, config="Release"))
        self.assertEqual(two["reach_by_config"], ["Debug=no_app_restriction", "Release=denied"])

    test_reach_by_config_only_with_several_configs = test_reach_by_config_only_when_multiple

    def test_unsupported_transform_makes_that_configuration_unknown(self):
        facts = [rule("allow", "", 1, all_=True, config="Odd", status="unknown_transform"),
                 rule("allow", "", 1, all_=True, config="Release")]
        d = self.home(*facts)
        self.assertEqual(d["reach_by_config"], ["Odd=unknown", "Release=no_app_restriction"])

    def test_default_allow_star_when_no_rule(self):
        d = self.home()
        self.assertEqual((d["reach_anon"], d["reach_auth"]), ("allow", "allow"))

    def test_nested_webconfig_applies_to_matching_route_prefix(self):
        facts = [ctrl("AdminController"), act("AdminController", "Index", url="/Admin/Index"),
                 rule("allow", "Admin", 1, roles=["PortalAdmins"], file="Admin/Web.config"),
                 rule("deny", "Admin", 2, all_=True, file="Admin/Web.config")]
        d = run(*facts)["AdminController.Index"]
        self.assertEqual((d["reach_anon"], d["reach_auth"], d["reach"]), ("deny", "deny", "role_restricted"))
        self.assertEqual(d["reach_roles"], ["PortalAdmins"])

    def test_area_folder_webconfig_does_not_apply_to_area_route(self):
        facts = [mk("controller_class", "Areas/Reports/Controllers/ExportController.cs", 5, "ExportController",
                    base_list=["Controller"], base_external=False),
                 mk("entry_point", "Areas/Reports/Controllers/ExportController.cs", 10, "/reports/Export/Index", type="route",
                    method="ANY", handler="ExportController.Index", inherits=["Controller"], base_external=False,
                    mvc_area="Reports", attr_route=True, end_line=13),
                 rule("allow", "Areas/Reports", 1, roles=["Auditors"], file="Areas/Reports/Web.config"),
                 rule("deny", "Areas/Reports", 2, all_=True, file="Areas/Reports/Web.config")]
        d = run(*facts)["ExportController.Index"]
        self.assertEqual((d["reach_anon"], d["reach"]), ("allow", "no_app_restriction"))

    def test_verbs_are_evaluated_per_verb(self):
        facts = [rule("deny", "", 1, all_=True, ), ]
        deny_post = [mk("access_rule", "Web.config", 1, "deny /", effect="deny", scope_path="", order=1, config="base",
                        config_status="base", file="Web.config", all=True, verbs=["POST"])]
        post = run(ctrl("HomeController"), act("HomeController", "Save", verbs="POST"), deny_post)["HomeController.Save"]
        get = run(ctrl("HomeController"), act("HomeController", "Show", verbs="GET"), deny_post)["HomeController.Show"]
        self.assertEqual((post["reach_anon"], get["reach_anon"]), ("deny", "allow"))
        both = run(ctrl("HomeController"), act("HomeController", "Any"), deny_post)["HomeController.Any"]
        self.assertEqual(both["reach_anon"], "allow", "any evaluates GET and POST; the most permissive wins")

    def test_url_authorization_is_a_mechanism_only_for_restricting_rules(self):
        plain = self.home(rule("allow", "", 1, all_=True))
        self.assertEqual(plain["guard_mechanism"], ["none"])
        locked = self.home(rule("deny", "Home", 1, anon=True, location="Home"), rule("allow", "Home", 2, all_=True, location="Home"))
        self.assertEqual(locked["guard_mechanism"], ["url-authorization"])

    def test_roles_cap_is_disclosed(self):
        rules = [rule("allow", "", i, roles=[f"Role{i:02d}"]) for i in range(1, 26)]
        d = self.home(*rules)
        self.assertIn("roles_capped", d["reasons"])

    def test_reach_roles_lists_the_roles_that_get_in(self):
        facts = [rule("allow", "Admin", 1, roles=["PortalAdmins"], location="Admin"), rule("deny", "Admin", 2, all_=True, location="Admin")]
        d = run(ctrl("AdminController"), act("AdminController", "Index", url="/Admin/Index"), facts)["AdminController.Index"]
        self.assertEqual(d["reach_roles"], ["PortalAdmins"])
        self.assertEqual(d["reach"], "role_restricted")


# --------------------------------------------------------------------------- Web Forms pages

class Pages(unittest.TestCase):
    def page(self, path="Pages/report.aspx", **extra):
        return mk("entry_point", path, 1, "/" + path, type="page", **extra)

    def test_nested_webconfig_applies_to_aspx_by_file_url(self):
        facts = [self.page("Contoso.Shop/Admin/users.aspx"),
                 F.Fact("project", "generic", "Contoso.Shop/Contoso.Shop.csproj", 1, "Contoso.Shop", (("kind", "web"), ("web", True))),
                 rule("deny", "Admin", 1, anon=True, file="Contoso.Shop/Admin/Web.config"),
                 rule("allow", "Admin", 2, all_=True, file="Contoso.Shop/Admin/Web.config")]
        got = guard.apply(facts)
        d = [f for f in got if f.kind == "entry_point"][0].detail_dict()
        self.assertEqual(d["url_set"], ["/Admin/users.aspx"])
        self.assertEqual((d["reach_anon"], d["reach_auth"]), ("deny", "allow"))
        self.assertNotIn("verbs", d)

    def test_mappageroute_both_urls(self):
        page = self.page("Pages/report.aspx")
        mapped = mk("entry_point", "App_Start/RouteConfig.cs", 14, "/reports/monthly", type="route", method="ANY",
                    route_name="Monthly", handler="~/Pages/report.aspx")
        rules = [rule("deny", "reports", 1, anon=True, location="reports"), rule("allow", "reports", 2, all_=True, location="reports")]
        got = guard.apply([page, mapped] + rules)
        d = [f for f in got if f.kind == "entry_point" and f.detail_dict().get("type") == "page"][0].detail_dict()
        self.assertEqual(sorted(d["url_set"]), ["/Pages/report.aspx", "/reports/monthly"])
        self.assertEqual(d["reach_anon"], "allow", "the physical URL has no rule: the most permissive URL wins")

    def test_page_with_codebehind_checks_is_unknown(self):
        page = self.page("Pages/report.aspx", codebehind="Pages/report.aspx.cs")
        check = mk("auth_check", "Pages/report.aspx.cs", 14, 'Session["u"] == null', mechanism="session")
        d = [f for f in guard.apply([page, check]) if f.kind == "entry_point"][0].detail_dict()
        self.assertEqual(d["reach_anon"], "unknown")
        self.assertIn("inbody", d["guard_mechanism"])


# --------------------------------------------------------------------------- shape, determinism

class Shape(unittest.TestCase):
    def facts(self):
        c = ctrl("HomeController")
        return [c, act("HomeController", "Index"), act("HomeController", "Save", verbs="POST"), DEFAULT_ROUTE,
                authorize("HomeController", roles=["Admins"]), glob(), rule("allow", "", 1, all_=True),
                rule("deny", "", 1, anon=True, config="Release"), rule("allow", "", 2, all_=True, config="Release")]

    def flat(self):
        return [x for part in self.facts() for x in (part if isinstance(part, list) else [part])]

    def test_detail_values_are_scalars_or_sorted_lists_of_scalars(self):
        for f in guard.apply(self.flat()):
            if f.kind != "entry_point":
                continue
            for k, v in f.detail:
                if isinstance(v, tuple):
                    self.assertEqual(list(v), sorted(v), k)
                    self.assertTrue(all(isinstance(x, (str, int, bool)) for x in v), k)
                else:
                    self.assertIsInstance(v, (str, int, bool, type(None)), k)

    def test_detail_keys_are_declared(self):
        for f in guard.apply(self.flat()):
            if f.kind == "entry_point":
                self.assertFalse({k for k, _ in f.detail} - F.DETAIL_KEYS["entry_point"], f.name)

    def test_apply_is_idempotent_and_order_free(self):
        once = guard.apply(self.flat())
        twice = guard.apply(once)
        key = lambda fs: sorted(fs, key=lambda f: f.sort_key())                       # noqa: E731
        self.assertEqual(key(once), key(twice))
        shuffled = self.flat()
        random.Random(3).shuffle(shuffled)
        self.assertEqual(key(guard.apply(shuffled)), key(once))

    def test_url_signature_cache_matches_direct_evaluation(self):
        """URLs that match the same rule prefixes share one urlauth call; the shared answer equals a direct call per URL."""
        from appdoc import urlauth
        rules = [rule("allow", "Admin", 1, roles=["Ops"], location="Admin"), rule("deny", "Admin", 2, all_=True, location="Admin"),
                 rule("deny", "Admin/Public", 3, anon=True, location="Admin/Public"),
                 rule("allow", "Admin/Public", 4, all_=True, location="Admin/Public"),
                 rule("allow", "Reports", 1, roles=["Auditors"], file="Reports/Web.config"),
                 rule("deny", "Reports", 2, all_=True, file="Reports/Web.config"),
                 rule("allow", "", 9, all_=True),
                 mk("config_unparsed", "Legacy/Web.config", None, "Web.config", reason="malformed")]
        ix = guard._Index(rules)
        rc = guard._Reach(ix)
        urls = ["/", "/Home", "/Admin", "/admin/x/y", "/Admin/Public", "/Admin/Public/z", "/Admin/Other", "/Reports/a",
                "/reports", "/Legacy", "/Legacy/Deep/Er", "/Adminx"]
        for u in urls:
            for p in rc.principals:
                for v in ("any", "GET", "POST"):
                    self.assertEqual(rc.url(u, p, v, "base").result, urlauth.evaluate(ix.rules, u, p, v, "base").result, (u, p, v))

    def test_no_entry_points_means_the_same_list(self):
        facts = [mk("file", "a.txt", None, "a.txt", stack="generic", ext=".txt")]
        self.assertEqual(guard.apply(facts), facts)

    def test_no_source_text_is_read(self):
        # the pass takes Facts only: no path is opened, so a Fact list for a Target that does not exist still works
        self.assertTrue(guard.apply(self.flat()))

    def test_no_secret_or_identity_in_any_derived_value(self):
        text = json.dumps([f.to_json() for f in guard.apply(self.flat())])
        for bad in ("@", "S-1-5", "password"):
            self.assertNotIn(bad, text)


if __name__ == "__main__":
    unittest.main()
