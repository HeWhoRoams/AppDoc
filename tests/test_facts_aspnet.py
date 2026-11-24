"""ASP.NET (Web Forms / MVC 5) Stack: runs the real pipeline on tests/samples/aspnet."""

import json
import os
import re
import tempfile
import unittest

from appdoc import extract, scan

SAMPLE = os.path.join(os.path.dirname(__file__), "samples", "aspnet")


def run():
    with tempfile.TemporaryDirectory() as out:
        text, _ = extract.extract(SAMPLE, out)
    return text


class AspNetFacts(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.text = run()
        doc = json.loads(cls.text)
        cls.facts = [f for f in doc["facts"] if f["stack"] == "aspnet"]
        cls.stacks = doc["stacks"]

    def has(self, kind, path, line, name, **detail):
        for f in self.facts:
            if (f["kind"], f["path"], f["line"], f["name"]) == (kind, path, line, name) \
                    and all(f["detail"].get(k) == v for k, v in detail.items()):
                return True
        return False

    def test_stack_detected(self):
        self.assertIn("aspnet", [s["name"] for s in self.stacks])

    def test_expected_facts(self):
        expected = [
            # Web Forms pages and code-behind handlers
            ("entry_point", "index.aspx", 1, "/index.aspx", dict(type="page", codebehind="index.aspx.cs")),
            ("entry_point", "resetpwd.aspx", 1, "/resetpwd.aspx", dict(type="page", inputs=["Email", "reset"])),
            ("entry_point", "search.aspx", 1, "/search.aspx", dict(type="page", inputs=["TicketId", "lookup"])),
            ("entry_point", "Admin/users.aspx", 1, "/Admin/users.aspx", dict(type="page", master="~/Site.master")),
            ("entry_point", "index.aspx.cs", 9, "Page_Load", dict(type="handler", page="index.aspx")),
            ("entry_point", "Admin/users.aspx.cs", 20, "SaveBtn_Click", dict(type="handler", page="Admin/users.aspx")),
            ("entry_point", "Admin/users.aspx", 12, "Cancel_Click", dict(type="handler", page="Admin/users.aspx")),
            ("entry_point", "Global.asax.cs", 9, "Application_Start", dict(type="handler")),
            # MVC / Web API routes
            ("entry_point", "Controllers/TicketsController.cs", 16, "/Tickets/Index",
             dict(type="route", method="ANY", handler="TicketsController.Index")),
            ("entry_point", "Controllers/TicketsController.cs", 24, "/tickets/{id:int}",
             dict(type="route", method="GET", handler="TicketsController.Details")),
            ("entry_point", "Controllers/TicketsController.cs", 30, "/Tickets/Create",
             dict(type="route", method="POST")),
            ("entry_point", "Controllers/ApiTicketsController.cs", 10, "/api/v1/tickets/{id}", dict(method="GET")),
            ("entry_point", "TicketService.cs", 9, "/api/tickets", dict(method="GET", handler="TicketService.ListTickets")),
            ("entry_point", "TicketService.cs", 15, "/api/tickets", dict(method="POST")),
            ("entry_point", "App_Start/RouteConfig.cs", 10, "/tickets/view/{id}",
             dict(type="route", route_name="TicketDetail", handler="TicketsController.Details")),
            ("entry_point", "App_Start/RouteConfig.cs", 15, "/{controller}/{action}/{id}", dict(route_name="Default")),
            ("entry_point", "App_Start/RouteConfig.cs", 20, "/legacy/search", dict(handler="~/search.aspx")),
            # data access
            ("data_access", "index.aspx.cs", 16, "HelpDesk.Tickets", dict(type="sql", operation="select")),
            ("data_access", "resetpwd.aspx.cs", 17, "HelpDesk.usp_ResetPassword", dict(type="stored_procedure")),
            ("data_access", "search.aspx.cs", 20, "HelpDesk.usp_GetTicket", dict(type="stored_procedure")),
            ("data_access", "Admin/users.aspx.cs", 25, "HelpDesk.Users", dict(type="sql", operation="update")),
            ("data_access", "Admin/users.aspx.cs", 30, "HelpDesk.usp_AuditSave", dict(type="stored_procedure")),
            ("data_access", "Controllers/TicketsController.cs", 63, "Ticket", dict(type="entity")),
            ("data_access", "Controllers/TicketsController.cs", 64, "Customer", dict(type="entity")),
            # connections (locations only)
            ("connection", "DataAccess.cs", 10, "HelpDeskMain", dict(secret_location=True)),
            ("connection", "Admin/users.aspx.cs", 24, "inline connection string", dict(secret_location=True)),
            ("config_key", "Admin/users.aspx.cs", 10, "adminPassword", dict(secret_location=True)),
            ("config_key", "Controllers/TicketsController.cs", 14, "apiKey", dict(secret_location=True)),
            # external calls
            ("external_call", "resetpwd.aspx.cs", 33, "https://fixture.internal/itsm/api/ticket", dict(type="http")),
            ("external_call", "Controllers/TicketsController.cs", 41, "mail.fixture.internal", dict(type="email")),
            ("external_call", "Controllers/TicketsController.cs", 43, "~/App_Data/ticket-template.txt", dict(type="file")),
            ("external_call", "Controllers/TicketsController.cs", 44, "C:\\tools\\archive.exe", dict(type="process")),
            # auth checks
            ("auth_check", "Controllers/TicketsController.cs", 10, '[Authorize(Roles = "Admin,Support")]',
             dict(mechanism="attribute", roles=["Admin", "Support"])),
            ("auth_check", "Controllers/TicketsController.cs", 21, "[AllowAnonymous]", dict(mechanism="attribute")),
            ("auth_check", "Controllers/TicketsController.cs", 37, 'User.IsInRole("Supervisor")',
             dict(mechanism="role", roles=["Supervisor"])),
            ("auth_check", "Admin/users.aspx.cs", 14, 'Session["AdminUser"] == null', dict(mechanism="session")),
            # messages
            ("message", "Admin/users.aspx", 6, "User name is required.", dict(context="validation")),
            ("message", "Controllers/TicketsController.cs", 34, "Subject is required.", dict(context="validation")),
            ("message", "Admin/users.aspx.cs", 35, "Could not save the user.", dict(context="error")),
            ("message", "search.aspx.cs", 34, "Ticket not found.", dict(context="error")),
        ]
        missing = [e[:4] for e in expected if not self.has(*e[:4], **e[4])]
        self.assertEqual(missing, [])

    def test_commented_out_code_yields_nothing(self):
        names = " ".join(f["name"] for f in self.facts)
        for dead in ("Commented out", "commented-out", "Dead code", "Old_Click", "Retired", "/retired"):
            self.assertNotIn(dead, names)

    def test_not_a_core_file(self):
        # nothing is emitted for the other stack's sample and every fact uses only known kinds/types
        for f in self.facts:
            if f["kind"] == "entry_point":
                self.assertIn(f["detail"]["type"], ("route", "page", "handler", "job", "desktop"))
            if f["kind"] == "data_access":
                self.assertIn(f["detail"]["type"], ("stored_procedure", "sql", "entity", "repository"))

    def test_no_secret_values_in_facts(self):
        secrets = set()
        for sf in scan.walk(SAMPLE):
            if sf.skipped:
                continue
            body, _ = scan.read_text(SAMPLE, sf.path)
            secrets.update(re.findall(r"(?i)(?:password|pwd)\s*=\s*([^;\"'\s<>]{3,})", body))
            secrets.update(re.findall(r"(?i)(?:\w*(?:password|apikey|secret|token)\w*)\s*=\s*\"([^\"\s]{3,})\"", body))
        secrets.add("fakepass")
        secrets = {s for s in secrets if re.search(r"[A-Za-z0-9]", s)}
        self.assertTrue(secrets)
        for s in secrets:
            self.assertNotIn(s, self.text, f"secret value leaked: {s!r}")

    def test_two_runs_identical(self):
        self.assertEqual(run(), run())


# --------------------------------------------------------------------------- inline Targets (2.8, stream 4B)

GLOBAL_ASAX = '<%@ Application Codebehind="Global.asax.cs" Inherits="Contoso.Web.MvcApplication" Language="C#" %>\n'


def _target(files: dict) -> list:
    """Run the real pipeline on an inline Web Forms/MVC Target; return the ``aspnet`` Facts as dicts."""
    files = {"Global.asax": GLOBAL_ASAX, **files}
    with tempfile.TemporaryDirectory() as root, tempfile.TemporaryDirectory() as out:
        for rel, body in files.items():
            full = os.path.join(root, *rel.split("/"))
            os.makedirs(os.path.dirname(full), exist_ok=True)
            with open(full, "w", encoding="utf-8") as fh:
                fh.write(body)
        doc = json.loads(extract.extract(root, out)[0])
    return [f for f in doc["facts"] if f["stack"] == "aspnet"]


def _entries(facts, **want):
    return [f for f in facts if f["kind"] == "entry_point"
            and all(f["detail"].get(k) == v for k, v in want.items())]


def _routes(facts, handler=None):
    return sorted(f["name"] for f in _entries(facts, type="route")
                  if handler is None or f["detail"].get("handler") == handler)


def _controller(path, ns, cls, body, attrs="", base="Controller", usings="using System.Web.Mvc;\n"):
    return {path: f"{usings}\nnamespace {ns}\n{{\n{attrs}\npublic class {cls} : {base}\n{{\n{body}\n}}\n}}\n"}


class WebFormsAndDesktopHandlers(unittest.TestCase):
    FORM = (
        "using System;\nusing System.Windows.Forms;\nnamespace Contoso.Harness\n{\n"
        "public partial class MainForm : Form\n{\n"
        "    private void RunButton_Click(object sender, EventArgs e) { }\n"
        "    protected void Form_Load(object sender, EventArgs e) { }\n}\n"
        "static class Program\n{\n    [STAThread]\n    static void Main()\n    {\n"
        "        Application.EnableVisualStyles();\n        Application.Run(new MainForm());\n    }\n}\n}\n")
    PAGE = (
        "using System;\nnamespace Contoso.Web\n{\npublic partial class Default : System.Web.UI.Page\n{\n"
        "    protected void Page_Load(object sender, EventArgs e) { }\n}\n}\n")

    def test_winforms_handlers_not_entry_points(self):
        facts = _target({"Harness/MainForm.cs": self.FORM, "Web/Default.aspx.cs": self.PAGE,
                         "Web/Default.aspx": '<%@ Page Language="C#" CodeBehind="Default.aspx.cs" %>\n<html></html>\n'})
        handlers = {(f["path"], f["name"]) for f in _entries(facts, type="handler")}
        self.assertIn(("Web/Default.aspx.cs", "Page_Load"), handlers)
        self.assertEqual([h for h in handlers if h[0] == "Harness/MainForm.cs"], [])

    def test_codebehind_handlers_still_found(self):
        facts = _target({
            "Web/Plain.cs": self.PAGE.replace("Default", "Plain"),             # derives Page, not a code-behind name
            "Web/Panel.ascx.cs": self.PAGE.replace("System.Web.UI.Page", "UserControl").replace("Default", "Panel"),
        })
        handlers = {(f["path"], f["name"]) for f in _entries(facts, type="handler")}
        self.assertIn(("Web/Plain.cs", "Page_Load"), handlers)
        self.assertIn(("Web/Panel.ascx.cs", "Page_Load"), handlers)

    def test_controller_named_class_needs_mvc_base(self):
        body = "public ActionResult Index() { return null; }"
        files = {}
        files.update(_controller("Tools/PrinterController.cs", "Contoso.Tools", "PrinterController", body,
                                 base="object", usings="using System;\n"))
        files.update(_controller("Web/Controllers/HomeController.cs", "Contoso.Web", "HomeController", body))
        files.update(_controller("Web/Controllers/ReportController.cs", "Contoso.Web", "ReportController", body,
                                 base="BaseController", usings="using System;\n"))
        routes = _routes(_target(files))
        self.assertNotIn("/Printer/Index", routes)
        self.assertIn("/Home/Index", routes)
        self.assertIn("/Report/Index", routes)

    def test_desktop_main_entry_point(self):
        facts = _target({"Harness/MainForm.cs": self.FORM})
        desktop = _entries(facts, type="desktop")
        self.assertEqual([(f["path"], f["detail"].get("handler")) for f in desktop],
                         [("Harness/MainForm.cs", "Program.Main")])
        forms = [f for f in facts if f["kind"] == "ui_page"]
        self.assertEqual([(f["path"], f["name"], f["detail"].get("type")) for f in forms],
                         [("Harness/MainForm.cs", "MainForm", "form")])
        from appdoc.stacks import aspnet, capabilities_of
        self.assertIn("entry_point.desktop", capabilities_of(aspnet.STACK))

    def test_core_web_exe_main_not_desktop(self):
        program = ("using Microsoft.AspNetCore.Builder;\nnamespace Contoso.Api\n{\npublic class Program\n{\n"
                   "    public static void Main(string[] args)\n    {\n        var app = WebApplication.Create(args);\n"
                   "        app.Run();\n    }\n}\n}\n")
        facts = _target({"Api/Program.cs": program + "// System.Web\n"})
        self.assertEqual(_entries(facts, type="desktop"), [])
        self.assertEqual([f for f in facts if f["kind"] == "ui_page"], [])


class RouteFidelity(unittest.TestCase):
    def test_routearea_prefix_applied(self):
        files = _controller(
            "Areas/Admin/Controllers/UsersController.cs", "Contoso.Web.Areas.Admin.Controllers", "UsersController",
            '[Route("list")]\npublic ActionResult List() { return null; }',
            attrs='[RouteArea("Admin", AreaPrefix = "adm")]\n[RoutePrefix("users")]')
        facts = _target(files)
        self.assertEqual(_routes(facts), ["/adm/users/list"])
        e = _entries(facts, type="route")[0]["detail"]
        self.assertEqual((e["mvc_area"], e["mvc_area_path"]), ("Admin", "Areas/Admin"))

    def test_routearea_spacing_variants(self):
        for attr in ('[RouteArea ( "Admin" ,AreaPrefix="adm" )]', '[RouteAreaAttribute("Admin",  AreaPrefix =  "adm")]'):
            files = _controller("Areas/Admin/Controllers/UsersController.cs", "Contoso.Web", "UsersController",
                                '[Route("list")]\npublic ActionResult List() { return null; }', attrs=attr)
            self.assertEqual(_routes(_target(files)), ["/adm/list"], attr)

    def test_routearea_prefix_only(self):
        files = _controller(
            "Areas/Reports/Controllers/SalesController.cs", "Contoso.Web.Areas.Reports.Controllers", "SalesController",
            '[Route("monthly")]\npublic ActionResult Monthly() { return null; }', attrs='[RouteArea(AreaPrefix = "rpt")]')
        facts = _target(files)
        self.assertEqual(_routes(facts), ["/rpt/monthly"])
        self.assertEqual(_entries(facts, type="route")[0]["detail"]["mvc_area"], "Reports")

    def test_routearea_empty_is_root(self):
        files = _controller(
            "Areas/Legacy/Controllers/HomeController.cs", "Contoso.Web.Areas.Legacy.Controllers", "HomeController",
            '[Route("home/start")]\npublic ActionResult Start() { return null; }', attrs='[RouteArea("", AreaPrefix = "")]')
        facts = _target(files)
        self.assertEqual(_routes(facts), ["/home/start"])
        d = _entries(facts, type="route")[0]["detail"]
        self.assertNotIn("mvc_area", d)
        self.assertNotIn("mvc_area_path", d)

    def test_area_url_from_registration_literal(self):
        reg = ("using System.Web.Mvc;\nnamespace Contoso.Web.Areas.Admin\n{\n"
               "public class AdminAreaRegistration : AreaRegistration\n{\n"
               '    public override string AreaName { get { return "Admin"; } }\n'
               "    public override void RegisterArea(AreaRegistrationContext context)\n    {\n"
               '        context.MapRoute(\n            "Admin_default",\n            "adm/{controller}/{action}/{id}",\n'
               '            new { action = "Index", id = UrlParameter.Optional });\n    }\n}\n}\n')
        facts = _target({"Areas/Admin/AdminAreaRegistration.cs": reg})
        routes = _entries(facts, type="route")
        self.assertEqual([f["name"] for f in routes], ["/adm/{controller}/{action}/{id}"])
        self.assertEqual((routes[0]["detail"]["mvc_area"], routes[0]["detail"]["mvc_area_path"]),
                         ("Admin", "Areas/Admin"))

    def test_area_from_folder_not_namespace(self):
        files = _controller(
            "Areas/Reports/Controllers/SalesController.cs", "Contoso.Web.Areas.Billing.Controllers", "SalesController",
            "public ActionResult Index() { return null; }")
        files.update(_controller("Controllers/RootController.cs", "Contoso.Web.Areas.Billing.Controllers",
                                 "RootController", "public ActionResult Index() { return null; }"))
        facts = _target(files)
        by_handler = {f["detail"]["handler"]: f["detail"] for f in _entries(facts, type="route")}
        self.assertEqual(by_handler["SalesController.Index"]["mvc_area"], "Reports")
        self.assertEqual(by_handler["RootController.Index"]["mvc_area"], "Billing")  # no folder: namespace is the fallback

    def test_tilde_route_ignores_prefix(self):
        files = _controller(
            "Areas/Admin/Controllers/UsersController.cs", "Contoso.Web", "UsersController",
            '[Route("~/health")]\npublic ActionResult Health() { return null; }\n'
            '[Route("{id:int?}")]\npublic ActionResult Show(int? id) { return null; }',
            attrs='[RouteArea("Admin", AreaPrefix = "adm")]\n[RoutePrefix("users")]')
        facts = _target(files)
        self.assertEqual(_routes(facts), ["/adm/users/{id:int?}", "/health"])

    def test_attribute_route_excludes_conventional(self):
        files = _controller(
            "Controllers/OrdersController.cs", "Contoso.Web", "OrdersController",
            '[Route("{id}")]\npublic ActionResult Details(string id) { return null; }\n'
            "public ActionResult List() { return null; }\n"
            "[HttpGet]\npublic ActionResult Edit() { return null; }",
            attrs='[RoutePrefix("orders")]')
        facts = _target(files)
        self.assertEqual(_routes(facts, "OrdersController.Details"), ["/orders/{id}"])
        # the prefix belongs to attribute routes only: plain and verb-only actions stay conventional
        self.assertEqual(_routes(facts, "OrdersController.List"), ["/Orders/List"])
        self.assertEqual(_routes(facts, "OrdersController.Edit"), ["/Orders/Edit"])

    def test_actionname_rename(self):
        files = _controller(
            "Controllers/OrdersController.cs", "Contoso.Web", "OrdersController",
            '[ActionName("Show")]\npublic ActionResult Details() { return null; }')
        facts = _target(files)
        e = _entries(facts, type="route")
        self.assertEqual([(f["name"], f["detail"]["handler"]) for f in e], [("/Orders/Show", "OrdersController.Details")])

    def test_duplicate_route_collapsed(self):
        files = _controller(
            "Controllers/OrdersController.cs", "Contoso.Web", "OrdersController",
            '[Route("a")]\n[Route("b")]\n[Route("a")]\npublic ActionResult Pick() { return null; }')
        self.assertEqual(_routes(_target(files)), ["/a", "/b"])

    def test_mvc_area_on_every_mvc_entry_point(self):
        files = _controller(
            "Areas/Admin/Controllers/UsersController.cs", "Contoso.Web", "UsersController",
            "public ActionResult Index() { return null; }\n[HttpPost]\npublic ActionResult Save() { return null; }")
        for f in _entries(_target(files), type="route"):
            self.assertEqual(f["detail"]["mvc_area"], "Admin")
            self.assertEqual(f["detail"]["mvc_area_path"], "Areas/Admin")


class DetectIn(unittest.TestCase):
    """T28.25: ``aspnet.detect_in`` reads files, so a Web.config-only or Web API-only classic project is detected."""
    WEB_CONFIG = '<?xml version="1.0"?>\n<configuration>\n  <system.web>\n    <authentication mode="Windows" />\n  </system.web>\n</configuration>\n'
    CORE_STUB = ('<?xml version="1.0"?>\n<configuration>\n  <system.webServer>\n    <handlers>'
                 '<add name="aspNetCore" path="*" verb="*" modules="AspNetCoreModuleV2" /></handlers>\n'
                 '  </system.webServer>\n</configuration>\n')
    API = ("using System.Web.Http;\nnamespace Contoso.Api\n{\n    public class ItemsController : ApiController\n    {\n"
           "        public string Get(int id) { return \"x\"; }\n    }\n}\n")

    def _root(self, files):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        for rel, body in files.items():
            full = os.path.join(tmp.name, *rel.split("/"))
            os.makedirs(os.path.dirname(full), exist_ok=True)
            with open(full, "w", encoding="utf-8") as fh:
                fh.write(body)
        return tmp.name

    def _detect(self, files):
        from appdoc import stacks
        from appdoc.stacks import aspnet
        root = self._root(files)
        return stacks.detect(aspnet.STACK, sorted(files), root)[0]

    def test_detect_in_webconfig_only_project(self):
        self.assertEqual(self._detect({"Web.config": self.WEB_CONFIG}), ["Web.config"])
        self.assertEqual(self._detect({"src/App/web.config": self.WEB_CONFIG, "src/App/App.csproj": "<Project/>"}),
                         ["src/App/web.config"], "any case, any folder")
        root = self._root({"Web.config": self.WEB_CONFIG})
        with tempfile.TemporaryDirectory() as out:
            doc = json.loads(extract.extract(root, out, workers=0, use_cache=False)[0])
        self.assertIn("aspnet", [s["name"] for s in doc["stacks"]])
        self.assertTrue([f for f in doc["facts"] if f["kind"] == "security_setting" and f["stack"] == "aspnet"])

    def test_webconfig_without_system_web_is_not_a_marker(self):
        self.assertEqual(self._detect({"web.config": self.CORE_STUB}), [], "an IIS hosting stub for ASP.NET Core")
        self.assertEqual(self._detect({"web.config": "<configuration><system.web"}), [], "malformed")

    def test_classic_asp_site_with_a_webconfig_is_not_aspnet(self):
        self.assertEqual(self._detect({"web.config": self.WEB_CONFIG, "index.asp": "<% %>"}), [])

    def test_detect_in_webapi_only_project(self):
        self.assertEqual(self._detect({"Controllers/ItemsController.cs": self.API}), ["Controllers/ItemsController.cs"])
        core = self.API.replace("System.Web.Http", "Microsoft.AspNetCore.Mvc")
        self.assertEqual(self._detect({"Controllers/ItemsController.cs": core}), [])

    def test_detect_in_keeps_no_state_between_calls(self):
        from appdoc.stacks import aspnet
        classic = {"Web.config": self.WEB_CONFIG}
        other = {"README.md": "# nothing", "tools/build.cs": "class A {}"}
        before = dict(vars(aspnet.STACK))
        alone = (self._detect(classic), self._detect(other))
        interleaved = []
        a, b = self._root(classic), self._root(other)
        from appdoc import stacks
        for _ in range(2):
            interleaved.append((stacks.detect(aspnet.STACK, sorted(classic), a)[0], stacks.detect(aspnet.STACK, sorted(other), b)[0]))
        self.assertEqual(interleaved, [alone, alone], "two interleaved Targets give the results of two separate runs")
        self.assertEqual(dict(vars(aspnet.STACK)), before, "detection stores nothing on the Stack")
        self.assertEqual(before, {}, "no per-run attribute on the Stack instance at all")


if __name__ == "__main__":
    unittest.main()
