"""W3 guards (T28.23, T28.50-T28.56): raw per-file Facts and the cross-file post-pass, on invented Targets (Contoso.*)."""

import json
import os
import re
import shutil
import tempfile
import unittest

from appdoc import aspnet_guards, extract
from appdoc import facts as F

HERE = os.path.dirname(os.path.abspath(__file__))
PORTAL = os.path.join(HERE, "corpus", "_targets", "mvc5-classic")

MVC = "using System.Web.Mvc;\n"


def run(files, workers=0, use_cache=False):
    """Extract an in-memory Target ({relative path: text}); returns the parsed facts document."""
    with tempfile.TemporaryDirectory() as tmp:
        root = os.path.join(tmp, "t")
        for rel, text in files.items():
            p = os.path.join(root, *rel.split("/"))
            os.makedirs(os.path.dirname(p), exist_ok=True)
            with open(p, "w", encoding="utf-8", newline="\n") as fh:
                fh.write(text)
        text, _ = extract.extract(root, os.path.join(tmp, "out"), workers=workers, use_cache=use_cache, no_ownership=True)
    return json.loads(text)


def of(doc, kind, **detail):
    return [f for f in doc["facts"] if f["kind"] == kind and all(f["detail"].get(k) == v for k, v in detail.items())]


def ctrl_file(attrs="", body="public ActionResult Index() { return View(); }", cls="OrdersController", extra=""):
    return f"{MVC}namespace Contoso.Web\n{{\n{extra}    {attrs}\n    public class {cls} : Controller\n    {{\n        {body}\n    }}\n}}\n"


WEB_MARK = {"Global.asax": '<%@ Application Codebehind="Global.asax.cs" Inherits="Contoso.Web.App" %>\n'}


def target(**files):
    d = dict(WEB_MARK)
    d.update({k.replace("__", "/").replace("_cs", ".cs"): v for k, v in files.items()})
    return d


class RawFacts(unittest.TestCase):
    def test_controller_class_inherits_base_external(self):
        doc = run(target(**{
            "Controllers__Base_cs": f"{MVC}namespace Contoso.Web {{ public abstract class BaseController : Contoso.Shared.SharedControllerBase {{ }} }}\n",
            "Controllers__Orders_cs": ctrl_file(cls="OrdersController").replace(": Controller", ": BaseController"),
            "Controllers__Plain_cs": ctrl_file(cls="PlainController"),
        }))
        cc = {f["name"]: f["detail"] for f in of(doc, "controller_class")}
        self.assertEqual(cc["BaseController"]["base_list"], ["SharedControllerBase"])
        self.assertIs(cc["BaseController"]["base_external"], True, "the base is not a framework type and not in the Target")
        self.assertIs(cc["OrdersController"]["base_external"], True, "an in-Target base with an external base is external too")
        self.assertIs(cc["PlainController"]["base_external"], False)
        eps = {f["detail"]["handler"]: f["detail"] for f in of(doc, "entry_point", type="route") if "handler" in f["detail"]}
        self.assertEqual(eps["OrdersController.Index"]["inherits"], ["BaseController"])
        self.assertIs(eps["OrdersController.Index"]["base_external"], True)
        self.assertIs(eps["PlainController.Index"]["base_external"], False)

    def test_controller_class_resolved_base_is_not_external(self):
        doc = run(target(**{
            "Controllers__Base_cs": f"{MVC}namespace Contoso.Web {{ public abstract class BaseController : Controller {{ }} }}\n",
            "Controllers__Orders_cs": ctrl_file(cls="OrdersController").replace(": Controller", ": BaseController"),
        }))
        self.assertEqual([f["detail"]["base_external"] for f in of(doc, "controller_class")], [False, False])

    def test_global_filter_auth_check(self):
        doc = run(target(**{
            "App_Start__FilterConfig_cs": f"{MVC}namespace Contoso.Web {{ public static class FilterConfig {{\n"
                                          "public static void RegisterGlobalFilters(GlobalFilterCollection filters)\n{\n"
                                          "filters.Add(new HandleErrorAttribute());\nfilters.Add(new StaffOnlyFilter());\n}\n}\n"
                                          "public class Startup { void Go() { GlobalFilters.Filters.Add(new AuthorizeAttribute()); } } }\n",
            "App_Start__WebApiConfig_cs": "using System.Web.Http;\nnamespace Contoso.Web { public static class WebApiConfig { public static void Register(HttpConfiguration config) {\n"
                                          "config.Filters.Add(new AuthorizeAttribute());\n} } }\n",
        }))
        got = sorted((f["path"].split("/")[-1], f["name"]) for f in of(doc, "auth_check", mechanism="global-filter"))
        self.assertEqual(got, [("FilterConfig.cs", "AuthorizeAttribute"), ("FilterConfig.cs", "StaffOnlyFilter"),
                               ("WebApiConfig.cs", "AuthorizeAttribute")], "HandleError is a global filter but not a guard")

    def test_promoted_helper_method_call(self):
        body = ("[HttpPost] public ActionResult Edit() { if (!HasRole(User, Roles.Admin, Groups.Ops)) { return new HttpUnauthorizedResult(); } "
                "var x = string.Format(Fmt.A, Fmt.B); Helper(1, 2); return View(); }")
        doc = run(target(**{"Controllers__Orders_cs": ctrl_file(body=body)}))
        calls = of(doc, "method_call")
        self.assertEqual([(f["name"], f["detail"]["arg_refs"], f["detail"]["applies_to"]) for f in calls],
                         [("HasRole", ["Groups.Ops", "Roles.Admin"], "OrdersController.Edit")],
                         "only an unqualified call with >= 2 constant references; not string.Format, not Helper(1, 2)")

    def test_const_def_under_if_and_no_value_for_secrets(self):
        src = ("namespace Contoso.Web { public static class K {\n#if DEBUG\n public const string Mode = \"Debug\";\n#else\n"
               " public const string Mode = \"Prod\";\n#endif\n public const string ApiToken = \"abc123def456\";\n"
               " public static readonly string Owner = \"pat@contoso.test\";\n } }\n")
        doc = run(target(K_cs=src))
        modes = sorted((f["detail"].get("under_if", []), f["detail"]["value"]) for f in of(doc, "const_def", qualified="K.Mode"))
        self.assertEqual(modes, [([], "Prod"), (["DEBUG"], "Debug")])
        tok = of(doc, "const_def", qualified="K.ApiToken")[0]["detail"]
        self.assertIs(tok["secret"], True)
        self.assertNotIn("value", tok)
        self.assertNotIn("value", of(doc, "const_def", qualified="K.Owner")[0]["detail"], "an email-like value is not recorded")
        self.assertNotIn("abc123def456", json.dumps(doc))
        self.assertNotIn("pat@contoso.test", json.dumps(doc))


class InTargetGuards(unittest.TestCase):
    GUARD = (MVC + "namespace Contoso.Web {{ public class {name}Attribute : AuthorizeAttribute {{\n{body}\n}} }}\n")

    def test_in_target_authorize_subclass(self):
        doc = run(target(**{
            "Infra__RoleGuard_cs": self.GUARD.format(name="RoleGuard", body=""),
            "Controllers__Orders_cs": ctrl_file(attrs='[RoleGuard(Roles = "Clerks,Auditors")]'),
        }))
        g = of(doc, "guard_class")[0]
        self.assertEqual((g["name"], g["detail"]["base_list"], g["detail"]["authorization_capable"],
                          g["detail"]["overrides_authorization"]), ("RoleGuardAttribute", ["AuthorizeAttribute"], True, False))
        ac = of(doc, "auth_check", via="custom")
        self.assertEqual(len(ac), 1)
        self.assertEqual((ac[0]["detail"]["roles"], ac[0]["detail"]["role_guard"]), (["Auditors", "Clerks"], True))
        self.assertEqual(of(doc, "guard_candidate"), [], "a guard declared in the Target is never a candidate")

    def test_subclass_overriding_authorizecore_is_unknown(self):
        body = "protected override bool AuthorizeCore(System.Web.HttpContextBase c) { return true; }"
        doc = run(target(**{
            "Infra__RoleGuard_cs": self.GUARD.format(name="RoleGuard", body=body),
            "Controllers__Orders_cs": ctrl_file(attrs='[RoleGuard(Roles = "Clerks")]'),
        }))
        self.assertIs(of(doc, "guard_class")[0]["detail"]["overrides_authorization"], True)
        d = of(doc, "auth_check", via="custom")[0]["detail"]
        self.assertIs(d["role_guard"], False, "an overridden AuthorizeCore says nothing about who is admitted")
        self.assertNotIn("roles", d)
        self.assertIs(d["overrides_authorization"], True)

    def test_override_is_inherited_through_the_target(self):
        doc = run(target(**{
            "Infra__A_cs": self.GUARD.format(name="Base", body="public override void OnAuthorization(AuthorizationContext c) { }"),
            "Infra__B_cs": f"{MVC}namespace Contoso.Web {{ public class StaffAttribute : BaseAttribute {{ }} }}\n",
            "Controllers__Orders_cs": ctrl_file(attrs='[Staff(Roles = "Clerks")]'),
        }))
        b = [f for f in of(doc, "guard_class") if f["name"] == "StaffAttribute"][0]["detail"]
        self.assertEqual((b["authorization_capable"], b["overrides_authorization"], b["base_external"]), (True, True, False))
        self.assertIs(of(doc, "auth_check", via="custom")[0]["detail"]["role_guard"], False)

    def test_iauthorizationfilter_implementer(self):
        src = (MVC + "namespace Contoso.Web { public class TokenFilterAttribute : System.Attribute, IAuthorizationFilter {\n"
               "public void OnAuthorization(AuthorizationContext c) { } } }\n")
        doc = run(target(Infra__Token_cs=src, Controllers__Orders_cs=ctrl_file(attrs="[TokenFilter]")))
        self.assertTrue(of(doc, "guard_class")[0]["detail"]["authorization_capable"])
        self.assertIs(of(doc, "auth_check", via="custom")[0]["detail"]["role_guard"], False)


class Candidates(unittest.TestCase):
    def _uses(self, n, attr="[ContosoGuard(\"Staff\")]"):
        files = {}
        for i in range(n):
            files[f"Controllers/C{i}Controller.cs"] = ctrl_file(attrs=attr, cls=f"C{i}Controller")
        return target(**{k.replace("/", "__").replace(".cs", "_cs"): v for k, v in files.items()})

    def test_guard_candidate_threshold(self):
        self.assertEqual(of(run(self._uses(2)), "guard_candidate"), [])
        c = of(run(self._uses(3)), "guard_candidate")
        self.assertEqual([(f["name"], f["detail"]["uses"], f["detail"]["arity_set"]) for f in c], [("ContosoGuard", 3, [1])])

    def test_uses_on_actions_count(self):
        body = "[ContosoGuard] public ActionResult A() { return View(); } [ContosoGuard] public ActionResult B() { return View(); }"
        doc = run(target(Controllers__A_cs=ctrl_file(attrs="[ContosoGuard]", body=body)))
        self.assertEqual(of(doc, "guard_candidate")[0]["detail"]["uses"], 3)

    def test_nonguard_attribute_listed_as_candidate(self):
        doc = run(self._uses(3, '[ContosoLayout("Wide")]'))
        self.assertEqual([f["name"] for f in of(doc, "guard_candidate")], ["ContosoLayout"],
                         "the question is the point: a layout attribute is listed too")

    def test_framework_attributes_are_not_candidates(self):
        doc = run(self._uses(4, "[Authorize][ValidateInput(false)]"))
        self.assertEqual(of(doc, "guard_candidate"), [])

    def test_in_target_non_guard_attribute_is_not_a_candidate(self):
        src = "namespace Contoso.Web { public class WideAttribute : System.Web.Mvc.ActionFilterAttribute { } }\n"
        files = self._uses(3, "[Wide]")
        files["Infra/Wide.cs"] = src
        self.assertEqual(of(run(files), "guard_candidate"), [])

    def test_declared_auth_attribute(self):
        files = self._uses(3)
        files["appdoc-context.md"] = "Auth attributes: ContosoGuard\n"
        doc = run(files)
        d = of(doc, "auth_check", via="declared")
        self.assertEqual(len(d), 3)
        self.assertTrue(all(f["name"] == "[ContosoGuard]" for f in d))
        self.assertEqual(of(doc, "guard_candidate"), [])
        self.assertEqual([f["detail"].get("context_unmatched") for f in of(doc, "context_directive")], [None])

    def test_declared_guard_without_args_is_unknown_reach(self):
        files = {"Controllers__A_cs": ctrl_file(attrs="[SiteGuard]"),
                 "Controllers__B_cs": ctrl_file(attrs='[SiteGuard(Roles = "Clerks")]', cls="BController"),
                 "appdoc-context.md": "Auth attributes: SiteGuard\n"}
        doc = run(target(**files))
        by = {f["path"].split("/")[-1]: f["detail"] for f in of(doc, "auth_check", via="declared")}
        self.assertEqual((by["A.cs"]["arity"], by["A.cs"]["role_guard"]), (0, False))
        self.assertNotIn("roles", by["A.cs"])
        self.assertEqual((by["B.cs"]["role_guard"], by["B.cs"]["roles"]), (True, ["Clerks"]))


CONSTS = ("namespace Contoso.Web { public static class Roles { public const string Admin = \"SiteAdmins\"; "
          "public const string Mail = \"ops@contoso.test\"; public const string Mixed = \"A, B\"; }\n"
          "public static class Accounts { public const string ServicePassword = \"not-a-real-pw-0001\"; "
          "public const string Name = \"svc-site\"; } }\n")


class Arguments(unittest.TestCase):
    def guard_use(self, attrs, extra=None, ctx=None):
        files = {"Infra__Consts_cs": CONSTS, "Controllers__Orders_cs": ctrl_file(attrs=attrs)}
        files.update(extra or {})
        if ctx:
            files["appdoc-context.md"] = ctx
        doc = run(target(**files))
        return doc, of(doc, "guard_use")[0]["detail"], json.dumps(doc)

    def test_const_role_argument_name_and_value(self):
        _, d, _ = self.guard_use("[SiteGuard(Roles.Admin, 1)]")
        self.assertEqual((d["role_ref"], d["role"], d["role_arg"]), ("Roles.Admin", "SiteAdmins", "positional"))

    def test_const_roles_named_argument(self):
        _, d, _ = self.guard_use("[Authorize(Roles = Roles.Mixed)]")
        self.assertEqual((d["role_ref"], d["role"], d["role_arg"], d["namespace"]),
                         ("Roles.Mixed", ["A", "B"], "named", "System.Web.Mvc"))

    def test_secret_constant_not_resolved(self):
        doc, d, text = self.guard_use("[SiteGuard(Roles.Admin, Accounts.Name, Accounts.ServicePassword)]")
        self.assertEqual(d["arg_kinds"], ["const", "const", "secret"])
        self.assertNotIn("not-a-real-pw-0001", text)
        d2 = of(run(target(Infra__Consts_cs=CONSTS, Controllers__Orders_cs=ctrl_file(attrs="[SiteGuard(Accounts.ServicePassword)]"))), "guard_use")[0]["detail"]
        self.assertEqual(d2["arg_kinds"], ["secret"])
        self.assertNotIn("role", d2)
        self.assertNotIn("role_ref", d2, "a secret constant is not resolved and not offered as a role")

    def test_secret_by_value_shape_is_secret_argument(self):
        consts = 'namespace Contoso.Web { public static class Keys { public const string Label = "Bearer eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0In0.abcDEF123456ghi"; } }\n'
        doc = run(target(Infra__K_cs=consts, Controllers__Orders_cs=ctrl_file(attrs="[SiteGuard(Keys.Label)]")))
        self.assertEqual(of(doc, "guard_use")[0]["detail"]["arg_kinds"], ["secret"])
        self.assertNotIn("eyJhbGci", json.dumps(doc))

    def test_users_argument_counted_only(self):
        doc, d, text = self.guard_use('[Authorize(Users = "pat@contoso.test, SAM@contoso.test, CONTOSO\\\\lee, contoso\\\\LEE")]')
        self.assertEqual(d["users_named"], 3)
        self.assertNotIn("role", d)
        for leak in ("pat@contoso", "SAM@", "lee"):
            self.assertNotIn(leak, text.replace("Contoso", ""), leak)

    def test_email_and_sid_roles_are_counted_not_recorded(self):
        _, d, text = self.guard_use('[Authorize(Roles = "Clerks, pat@contoso.test, S-1-5-21-111-222-333-1001")]')
        self.assertEqual((d["role"], d["users_named"]), ("Clerks", 2))
        self.assertNotIn("S-1-5-21", text)
        _, d, text = self.guard_use("[SiteGuard(Roles.Mail)]")
        self.assertNotIn("role", d)
        self.assertNotIn("ops@contoso.test", text)

    def test_arity_recorded(self):
        _, d, _ = self.guard_use('[SiteGuard(Roles.Admin, "x", Accounts.Name, Mode = Roles.Admin)]')
        self.assertEqual(d["arity"], 4)
        self.assertEqual(d["arg_kinds"], ["const", "const", "const", "literal"])
        _, d, _ = self.guard_use("[SiteGuard]")
        self.assertEqual((d["arity"], d["arg_kinds"]), (0, []))

    def test_non_literal_role_argument(self):
        _, d, _ = self.guard_use('[SiteGuard("Staff" + Suffix())]')
        self.assertEqual(d["role_ref"], "expression")
        self.assertNotIn("role", d)
        self.assertEqual(d["arg_kinds"], ["expression"])
        _, d, _ = self.guard_use("[SiteGuard(Roles.Missing)]")
        self.assertEqual((d["role_ref"], "role" in d), ("Roles.Missing", False), "a constant outside the Target is only named")

    def test_ambiguous_constant_is_not_resolved(self):
        other = 'namespace Other { public static class Roles { public const string Admin = "OtherAdmins"; } }\n'
        _, d, _ = self.guard_use("[SiteGuard(Roles.Admin)]", {"Infra__Other_cs": other})
        self.assertEqual(d["role_ref"], "Roles.Admin")
        self.assertNotIn("role", d, "two constants of one qualified name with different values stay unresolved")

    def test_constant_resolves_across_files_and_pool(self):
        files = target(Infra__Consts_cs=CONSTS, Controllers__Orders_cs=ctrl_file(attrs="[SiteGuard(Roles.Admin)]"))
        for i in range(60):
            files[f"Pad/P{i}.cs"] = f"namespace Pad {{ public class P{i} {{ }} }}\n"
        doc = run(files, workers=4)
        self.assertEqual(of(doc, "guard_use")[0]["detail"]["role"], "SiteAdmins")


class Promotion(unittest.TestCase):
    def test_auth_method_promotion_lists_all_constants(self):
        base = (MVC + "namespace Contoso.Web { public abstract class BaseController : Controller {\n"
                "protected bool HasRole(System.Security.Principal.IPrincipal u, string a, string b) { return u.IsInRole(a) || u.IsInRole(b); }\n} }\n")
        consts = ("namespace Contoso.Web { public static class Roles { public const string A = \"RoleA\"; public const string B = \"RoleB\"; "
                  "public const string C = \"RoleC\"; public const string D = \"RoleD\"; } }\n")
        c1 = ctrl_file(attrs="[SiteGuard(Roles.A, Roles.B)]", cls="OneController",
                       body="public ActionResult X() { if (!HasRole(User, Roles.A, Roles.B)) { return null; } return View(); }").replace(": Controller", ": BaseController")
        c2 = ctrl_file(cls="TwoController", body="public ActionResult Y() { return HasRole(User, Roles.C, Roles.D) ? View() : null; }").replace(": Controller", ": BaseController")
        doc = run(target(Controllers__Base_cs=base, Infra__K_cs=consts, Controllers__One_cs=c1, Controllers__Two_cs=c2))
        calls = of(doc, "auth_check", via="call")
        self.assertEqual({f["name"] for f in calls}, {"HasRole()"})
        self.assertEqual(sorted(r for f in calls for r in f["detail"]["role_refs"]), ["Roles.A", "Roles.B", "Roles.C", "Roles.D"],
                         "every constant of every call, not only those that appear in attributes")
        self.assertEqual(sorted(r for f in calls for r in f["detail"]["roles"]), ["RoleA", "RoleB", "RoleC", "RoleD"])
        self.assertTrue(all(f["detail"]["mechanism"] == "inbody" for f in calls), "an in-body check, never `none`")

    def test_call_without_guard_constants_is_not_promoted(self):
        c = ctrl_file(body="public ActionResult X() { return Pick(Colours.Red, Colours.Blue); }")
        doc = run(target(Controllers__One_cs=c))
        self.assertEqual(of(doc, "auth_check", via="call"), [])

    def test_guard_shapes_table(self):
        consts = CONSTS
        files = {"Infra__K_cs": consts}
        files["Controllers__A_cs"] = ctrl_file(attrs="[SiteGuard(Roles.Admin, Accounts.Name)]", cls="AController")
        files["Controllers__B_cs"] = ctrl_file(attrs="[SiteGuard(Roles.Admin, Accounts.Name)]", cls="BController")
        files["Controllers__C_cs"] = ctrl_file(attrs="[SiteGuard(Roles.Admin)]", cls="CController")
        files["Controllers__D_cs"] = ctrl_file(attrs="[Authorize]", cls="DController")
        doc = run(target(**files))
        rows = [(r["attribute"], r["arg_kinds"], r["uses"]) for r in aspnet_guards.guard_shapes(doc["facts"])]
        self.assertEqual(rows, [("Authorize", [], 1), ("SiteGuard", ["const"], 1), ("SiteGuard", ["const", "const"], 2)])

    def test_method_overrides_class_arity_marked(self):
        body = '[SiteGuard(Roles.Admin)] public ActionResult Edit() { return View(); } [SiteGuard(Roles.Admin, Accounts.Name)] public ActionResult Del() { return View(); }'
        doc = run(target(Infra__K_cs=CONSTS, Controllers__A_cs=ctrl_file(attrs="[SiteGuard(Roles.Admin, Accounts.Name)]", body=body)))
        by = {f["detail"]["applies_to"]: f["detail"] for f in of(doc, "guard_use")}
        self.assertIs(by["OrdersController.Edit"].get("arity_override"), True, "method arity 1 differs from class arity 2")
        self.assertNotIn("arity_override", by["OrdersController.Del"])
        self.assertNotIn("arity_override", by["OrdersController"])
        rows = aspnet_guards.guard_shapes(doc["facts"])
        self.assertEqual([(r["arg_kinds"], r["overrides"]) for r in rows], [(["const"], 1), (["const", "const"], 0)])


class WebApi(unittest.TestCase):
    API = ("using System.Web.Http;\nnamespace Contoso.Web { [Authorize] public class ItemsController : ApiController { public string Get() { return \"\"; } } }\n")
    MVCC = ("using System.Web.Mvc;\nnamespace Contoso.Web { [Authorize] public class HomeController : Controller { public ActionResult Index() { return View(); } } }\n")
    BEARER = "namespace Contoso.Web { public class Auth { void Go(Owin.IAppBuilder app) { app.UseOAuthBearerAuthentication(null); } } }\n"

    def test_web_api_authorize_separate_pipeline(self):
        doc = run(target(Controllers__Items_cs=self.API, Controllers__Home_cs=self.MVCC, Infra__Auth_cs=self.BEARER))
        by = {f["path"].split("/")[-1]: f["detail"] for f in of(doc, "guard_use", attribute="Authorize")}
        self.assertEqual(by["Items.cs"]["namespace"], "System.Web.Http")
        self.assertIs(by["Items.cs"]["api_pipeline"], True)
        self.assertEqual(by["Home.cs"]["namespace"], "System.Web.Mvc")
        self.assertNotIn("api_pipeline", by["Home.cs"], "not mixed with MVC")
        ac = {f["path"].split("/")[-1]: f["detail"] for f in of(doc, "auth_check", mechanism="attribute") if "via" not in f["detail"]}
        self.assertIs(ac["Items.cs"]["api_pipeline"], True)
        self.assertEqual(ac["Home.cs"]["namespace"], "System.Web.Mvc")
        self.assertNotIn("api_pipeline", ac["Home.cs"])

    def test_no_bearer_no_api_pipeline(self):
        doc = run(target(Controllers__Items_cs=self.API))
        d = of(doc, "guard_use", attribute="Authorize")[0]["detail"]
        self.assertEqual(d["namespace"], "System.Web.Http")
        self.assertNotIn("api_pipeline", d)

    def test_qualified_attribute_wins_over_using(self):
        src = self.API.replace("[Authorize]", "[System.Web.Mvc.Authorize]")
        d = of(run(target(Controllers__Items_cs=src)), "guard_use", attribute="Authorize")[0]["detail"]
        self.assertEqual(d["namespace"], "System.Web.Mvc")


class CoreHooks(unittest.TestCase):
    PROJ = '<Project Sdk="Microsoft.NET.Sdk.Web"><PropertyGroup><TargetFramework>net8.0</TargetFramework></PropertyGroup></Project>\n'

    def test_core_controller_guards_and_constants(self):
        files = {
            "Web.csproj": self.PROJ,
            "Program.cs": "var b = WebApplication.CreateBuilder(args); var app = b.Build(); app.Run();\n",
            "Infra/Consts.cs": 'namespace Contoso.Web { public static class Roles { public const string Admin = "SiteAdmins"; } }\n',
            "Infra/Gate.cs": "using Microsoft.AspNetCore.Mvc.Filters;\nnamespace Contoso.Web { public class GateAttribute : Attribute, IAuthorizationFilter {\npublic void OnAuthorization(AuthorizationFilterContext c) { } } }\n",
            "Controllers/OrdersController.cs": "using Microsoft.AspNetCore.Authorization;\nusing Microsoft.AspNetCore.Mvc;\nnamespace Contoso.Web {\n"
                                               "[Authorize(Roles = Roles.Admin)] [Gate] public class OrdersController : Controller { public IActionResult Index() => View(); } }\n",
        }
        doc = run(files)
        self.assertEqual([f["stack"] for f in of(doc, "controller_class")], ["aspnet-core"])
        use = of(doc, "guard_use", attribute="Authorize")[0]
        self.assertEqual((use["stack"], use["detail"]["role"], use["detail"]["namespace"]),
                         ("aspnet-core", "SiteAdmins", "Microsoft.AspNetCore.Authorization"))
        self.assertEqual(of(doc, "auth_check", via="custom")[0]["name"], "[Gate]")
        self.assertEqual(of(doc, "const_def", qualified="Roles.Admin")[0]["detail"]["value"], "SiteAdmins")
        route = [f for f in of(doc, "entry_point", type="route")][0]
        self.assertEqual((route["detail"]["inherits"], route["detail"]["base_external"]), (["Controller"], False))


class SummarySection(unittest.TestCase):
    def test_unclassified_attributes_listed_and_pure_function_of_facts(self):
        from appdoc import summary
        doc = run(Candidates()._uses(3, '[ContosoLayout("Wide")]'))
        text = summary.render_summary(doc)
        self.assertEqual(text, summary.render_summary(json.loads(json.dumps(doc))))
        sec = text.split("## Unclassified controller attributes")[1].split("\n## ")[0]
        self.assertIn("| `ContosoLayout` | 3 | 1 |", sec)
        self.assertIn("Auth attributes:", sec)

    def test_empty_section_for_an_aspnet_target_never_claims_absence(self):
        from appdoc import summary
        text = summary.render_summary(run(target(Controllers__A_cs=ctrl_file())))
        self.assertIn("## Unclassified controller attributes\n\nNone extracted. This is not proof of absence.", text)

    def test_no_section_for_other_stacks(self):
        from appdoc import summary
        text = summary.render_summary(run({"app.py": "import flask\napp = flask.Flask(__name__)\n"}))
        self.assertNotIn("Unclassified controller attributes", text)


class Conformance(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.doc = _portal()

    def test_new_kinds_use_closed_detail_keys(self):
        for f in self.doc["facts"]:
            if f["kind"] in ("guard_use", "guard_class", "guard_candidate", "const_def", "method_call", "controller_class", "auth_check"):
                self.assertLessEqual(set(f["detail"]), F.DETAIL_KEYS[f["kind"]], f"{f['kind']} {f['name']}")

    def test_no_auth_value_equals_secret_location(self):
        """R19: no guard Fact detail value equals a value held at a secret_location (read from the source line)."""
        values = set()
        for f in self.doc["facts"]:
            if f["kind"] in ("config_key", "connection") and f["detail"].get("secret_location"):
                p = os.path.join(PORTAL, *f["path"].split("/"))
                if not os.path.isfile(p):
                    continue
                with open(p, encoding="utf-8-sig") as fh:
                    line = fh.read().split("\n")[f["line"] - 1]
                values |= {m for m in re.findall(r'"((?:[^"\\]|\\.)+)"', line)} - {f["name"]}
        self.assertIn("not-a-real-credential-0001", values, "the Target does hold a secret literal at a secret location")
        for f in self.doc["facts"]:
            if f["kind"] in ("auth_check", "guard_use", "guard_class", "guard_candidate", "const_def", "method_call"):
                flat = [f["name"]] + [str(x) for v in f["detail"].values() for x in (v if isinstance(v, list) else [v])]
                self.assertEqual(set(flat) & values, set(), f"{f['kind']} {f['name']}")

    def test_no_email_or_sid_in_guard_facts(self):
        for f in self.doc["facts"]:
            if f["kind"] in ("auth_check", "guard_use", "const_def"):
                text = json.dumps(f)
                self.assertNotRegex(text, r"[\w.]+@[\w.]+\.\w+")
                self.assertNotRegex(text, r"S-1-\d")


def _portal(workers=0, use_cache=False, out=None):
    with tempfile.TemporaryDirectory() as tmp:
        root = os.path.join(tmp, "t")
        shutil.copytree(PORTAL, root)
        for i in range(60):                                      # cross PARALLEL_THRESHOLD so workers > 1 uses the pool
            with open(os.path.join(root, f"Pad{i}.txt"), "w") as fh:
                fh.write("x\n")
        text, _ = extract.extract(root, out or os.path.join(tmp, "out"), workers=workers, use_cache=use_cache, no_ownership=True)
    return json.loads(text)


class Determinism(unittest.TestCase):
    def test_aspnet_raw_facts_serial_equals_pool(self):
        self.assertEqual(_portal(0), _portal(4))

    def test_raw_facts_warm_equals_cold(self):
        with tempfile.TemporaryDirectory() as out:
            cold = _portal(0, True, out)
            warm = _portal(0, True, out)
            nocache = _portal(0, False)
        self.assertEqual(cold, warm)
        self.assertEqual(warm, nocache)

    def test_post_pass_is_a_pure_function_of_the_facts(self):
        doc = _portal()
        facts = [F.Fact.from_json(d) for d in doc["facts"]]
        import random
        random.Random(7).shuffle(facts)
        once = aspnet_guards.promote(list(facts))
        a = sorted({f for f in once}, key=lambda f: f.sort_key())
        facts2 = [f for f in facts]
        facts2.reverse()
        b = sorted({f for f in aspnet_guards.promote(facts2)}, key=lambda f: f.sort_key())
        self.assertEqual(a, b)


if __name__ == "__main__":
    unittest.main()
