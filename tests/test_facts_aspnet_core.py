"""ASP.NET Core Stack: runs the real pipeline on tests/samples/aspnet-core."""

import json
import os
import re
import tempfile
import unittest

from appdoc import extract, scan

SAMPLE = os.path.join(os.path.dirname(__file__), "samples", "aspnet-core")


def run():
    with tempfile.TemporaryDirectory() as out:
        text, _ = extract.extract(SAMPLE, out)
    return text


class AspNetCoreFacts(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.text = run()
        doc = json.loads(cls.text)
        cls.facts = [f for f in doc["facts"] if f["stack"] == "aspnet-core"]
        cls.stacks = doc["stacks"]

    def has(self, kind, path, line, name, **detail):
        for f in self.facts:
            if (f["kind"], f["path"], f["line"], f["name"]) == (kind, path, line, name) \
                    and all(f["detail"].get(k) == v for k, v in detail.items()):
                return True
        return False

    def test_stack_detected(self):
        names = [s["name"] for s in self.stacks]
        self.assertIn("aspnet-core", names)
        self.assertNotIn("aspnet", names)

    def test_expected_facts(self):
        expected = [
            # attribute routes with [controller] substitution and class prefixes
            ("entry_point", "Controllers/OrdersController.cs", 21, "/api/v1/Orders",
             dict(type="route", method="GET", handler="OrdersController.ListOrders")),
            ("entry_point", "Controllers/OrdersController.cs", 30, "/api/v1/Orders/{id}", dict(method="GET")),
            ("entry_point", "Controllers/OrdersController.cs", 39, "/api/v1/Orders",
             dict(method="POST", handler="OrdersController.CreateOrder")),
            ("entry_point", "Controllers/StatusController.cs", 20, "/api/status", dict(method="GET")),
            ("entry_point", "Controllers/TicketsController.cs", 22, "/api/tickets", dict(method="GET", handler="TicketsController.List")),
            ("entry_point", "Controllers/TicketsController.cs", 31, "/api/tickets/{id}", dict(method="GET")),
            ("entry_point", "Controllers/TicketsController.cs", 41, "/api/tickets", dict(method="POST")),
            ("entry_point", "Controllers/AdminController.cs", 13, "/api/Admin/users/{id}", dict(method="GET")),
            ("entry_point", "Controllers/AdminController.cs", 27, "/api/Admin/{id}", dict(method="DELETE")),
            # minimal APIs with MapGroup prefix
            ("entry_point", "Endpoints/MinimalEndpoints.cs", 9, "/ping", dict(method="GET")),
            ("entry_point", "Endpoints/MinimalEndpoints.cs", 12, "/api/reports/daily",
             dict(method="GET", handler="ReportHandlers.Daily")),
            ("entry_point", "Endpoints/MinimalEndpoints.cs", 13, "/api/reports/{id}/export", dict(method="POST")),
            ("entry_point", "Endpoints/MinimalEndpoints.cs", 18, "/api/cache", dict(method="DELETE")),
            # Razor Pages
            ("entry_point", "Pages/Tickets/Index.cshtml", 1, "/Tickets", dict(type="page")),
            ("entry_point", "Pages/Tickets/Detail.cshtml", 1, "/Tickets/Detail/{id:int}", dict(type="page")),
            ("entry_point", "Pages/Tickets/Index.cshtml.cs", 7, "OnGet", dict(type="handler", method="GET")),
            ("entry_point", "Pages/Tickets/Index.cshtml.cs", 11, "OnPostAsync", dict(type="handler", method="POST")),
            # data access
            ("data_access", "Data/AppDbContext.cs", 8, "Ticket", dict(type="entity")),
            ("data_access", "Data/AppDbContext.cs", 9, "Comment", dict(type="entity")),
            ("data_access", "Data/AppDbContext.cs", 13, "dbo.Tickets", dict(type="sql", operation="select")),
            ("data_access", "Data/AppDbContext.cs", 18, "dbo.AuditLog", dict(type="sql", operation="delete")),
            ("data_access", "Data/AppDbContext.cs", 23, "dbo.usp_TouchTicket", dict(type="stored_procedure")),
            ("data_access", "Data/AppDbContext.cs", 24, "Comments", dict(type="sql", operation="select")),
            ("data_access", "Data/TicketRepository.cs", 12, "TicketRepository", dict(type="repository")),
            ("data_access", "Data/TicketRepository.cs", 27, "Tickets", dict(type="sql", operation="select")),
            ("data_access", "Data/TicketRepository.cs", 51, "Tickets", dict(type="sql", operation="insert")),
            # connections
            ("connection", "Data/TicketRepository.cs", 21, "Default", dict(secret_location=True)),
            ("connection", "Services/NotificationService.cs", 15, "Audit", dict(secret_location=True)),
            ("config_key", "Services/NotificationService.cs", 10, "_smtpPassword", dict(secret_location=True)),
            # external calls
            ("external_call", "Program.cs", 7, "StatusClient", dict(type="http")),
            ("external_call", "Controllers/StatusController.cs", 22, "StatusClient", dict(type="http")),
            ("external_call", "Services/NotificationService.cs", 20, "PagerClient", dict(type="http")),
            ("external_call", "Services/NotificationService.cs", 21, "https://pager.fixture.internal/v1/notify", dict(type="http")),
            ("external_call", "Services/NotificationService.cs", 22, "smtp.fixture.internal", dict(type="email")),
            ("external_call", "Services/NotificationService.cs", 23, "/var/log/helpdesk/notify.log", dict(type="file")),
            ("external_call", "Services/NotificationService.cs", 24, "/usr/bin/logger", dict(type="process")),
            # auth
            ("auth_check", "Controllers/OrdersController.cs", 12, "[Authorize]", dict(mechanism="attribute")),
            ("auth_check", "Controllers/AdminController.cs", 8, '[Authorize(Roles = "Admin,Support")]',
             dict(roles=["Admin", "Support"])),
            ("auth_check", "Controllers/AdminController.cs", 12, '[Authorize(Policy = "CanViewUsers")]',
             dict(policy="CanViewUsers")),
            ("auth_check", "Controllers/AdminController.cs", 22, "[AllowAnonymous]", dict(mechanism="attribute")),
            ("auth_check", "Endpoints/MinimalEndpoints.cs", 11, '.RequireAuthorization("ReportsPolicy")', dict(policy="ReportsPolicy")),
            ("auth_check", "Endpoints/MinimalEndpoints.cs", 18, ".RequireAuthorization()", dict(mechanism="minimal-api")),
            # messages
            ("message", "Controllers/TicketsController.cs", 45, "Subject is required.", dict(context="error")),
            ("message", "Controllers/AdminController.cs", 17, "User id must be positive.", dict(context="error")),
            ("message", "Controllers/AdminController.cs", 19, "No such user.", dict(context="error")),
            ("message", "Controllers/AdminController.cs", 30, "Removal is not supported.", dict(context="error")),
            ("message", "Endpoints/MinimalEndpoints.cs", 15, "Report id is invalid.", dict(context="error")),
        ]
        missing = [e[:4] for e in expected if not self.has(*e[:4], **e[4])]
        self.assertEqual(missing, [])

    def test_httpclient_call_supersedes_generic_http_emission(self):
        """One HttpClient call at a line is one external_call, not a plain http Fact plus a via:HttpClient Fact."""
        for path, line in (("Services/NotificationService.cs", 21), ("Services/PagerClient.cs", 9)):
            with self.subTest(path=path):
                at = [f for f in self.facts if f["kind"] == "external_call" and f["path"] == path and f["line"] == line]
                self.assertEqual(len(at), 1, at)
                self.assertEqual(at[0]["detail"].get("via"), "HttpClient")

    def test_commented_out_code_yields_nothing(self):
        names = " ".join(f["name"] for f in self.facts)
        self.assertNotIn("Commented out", names)
        self.assertNotIn("/ignored", names)

    def test_mvc_actions_returning_view_are_pages_with_resolved_views(self):
        C = "Controllers/HomeController.cs"
        self.assertTrue(self.has("entry_point", C, 9, "/Home/Index", type="page", handler="HomeController.Index",
                                 view="Views/Home/Index.cshtml", exists=True))
        self.assertTrue(self.has("entry_point", C, 14, "/Home/About", type="page", view="Views/Home/About.cshtml", exists=True))
        # Falls back to Views/Shared when the controller folder has no such view; expression-bodied action.
        self.assertTrue(self.has("entry_point", C, 22, "/Home/Fail", type="page", view="Views/Shared/Error.cshtml", exists=True))

    def test_view_that_does_not_exist_reports_expected_path(self):
        self.assertTrue(self.has("entry_point", "Controllers/HomeController.cs", 19, "/Home/Missing", type="page",
                                 view="Views/Home/NotThere.cshtml", exists=False))

    def test_view_exists_is_unknown_without_the_file_list(self):
        from appdoc.stacks import aspnet_core
        with open(os.path.join(SAMPLE, "Controllers", "HomeController.cs"), encoding="utf-8") as fh:
            text = fh.read()
        pages = [f.detail_dict() for f in aspnet_core.AspNetCoreStack().extract("src/Web/Controllers/HomeController.cs", text)
                 if f.detail_dict().get("type") == "page"]
        self.assertEqual({p["exists"] for p in pages}, {None})
        self.assertIn("src/Web/Views/Home/Index.cshtml", {p["view"] for p in pages})

    def test_controller_with_implicit_usings_is_still_extracted(self):
        from appdoc.stacks import aspnet_core
        src = ("namespace X;\npublic class DiagController : Controller\n{\n    public async Task<IActionResult> Index()\n"
               "    {\n        return View(model);\n    }\n}\n")
        got = [(f.detail_dict()["type"], f.line, f.detail_dict().get("view"))
               for f in aspnet_core.AspNetCoreStack().extract("src/Id/Quickstart/Diag/DiagController.cs", src)
               if f.kind == "entry_point"]
        self.assertEqual(sorted(got, key=str), [("page", 6, "src/Id/Views/Diag/Index.cshtml"), ("route", 4, None)])

    def test_view_files_are_pages(self):
        self.assertTrue(self.has("entry_point", "Views/Home/Index.cshtml", 1, "Views/Home/Index.cshtml", type="page",
                                 source="view", controller="Home"))
        self.assertTrue(self.has("entry_point", "Views/Shared/Error.cshtml", 1, "Views/Shared/Error.cshtml", type="page",
                                 source="view", controller=None))
        self.assertFalse([f for f in self.facts if f["path"] == "Views/Shared/_Layout.cshtml" and f["kind"] == "entry_point"])

    def test_xaml_pages(self):
        self.assertTrue(self.has("ui_page", "ClientApp/AppShell.xaml", 3, "HelpDesk.ClientApp.AppShell",
                                 x_class="HelpDesk.ClientApp.AppShell", root="Shell", route="settings,tickets"))
        self.assertTrue(self.has("ui_page", "ClientApp/Views/MainPage.xaml", 2, "HelpDesk.ClientApp.Views.MainPage",
                                 root="views:ContentPageBase", route=None))
        self.assertEqual([f for f in self.facts if f["kind"] == "ui_page" and f["path"] == "ClientApp/Styles.xaml"], [])
        self.assertNotIn("Commented.Shell", " ".join(f["name"] for f in self.facts))

    def test_background_services_and_hangfire_jobs(self):
        W = "Workers/DigestWorker.cs"
        self.assertTrue(self.has("entry_point", W, 6, "DigestWorker", type="job", schedule=None, enabled=True))
        self.assertTrue(self.has("entry_point", W, 25, "CleanupService", type="job", schedule=None, enabled=None))
        self.assertTrue(self.has("entry_point", W, 36, "close-stale", type="job", schedule="0 */6 * * *", scheduler="hangfire"))
        self.assertTrue(self.has("entry_point", W, 37, "daily-digest", type="job", schedule="Cron.Daily", handler="SendDigest"))

    def test_primary_constructor_hosted_service_is_a_job_and_abstract_base_is_not(self):
        W = "Workers/DigestWorker.cs"
        self.assertTrue(self.has("entry_point", W, 41, "QueueWorker", type="job", schedule=None, enabled=None))
        self.assertNotIn("WorkerBase", {f["name"] for f in self.facts if f["kind"] == "entry_point"})

    def test_configuration_reads(self):
        W = "Workers/DigestWorker.cs"
        self.assertTrue(self.has("config_key", W, 17, "Digest:IntervalMinutes", use="read", secret_location=False))
        self.assertTrue(self.has("config_key", W, 18, "Smtp:Host", use="read"))
        self.assertTrue(self.has("config_key", W, 19, "Smtp:ApiKey", use="read", secret_location=True))
        self.assertTrue(self.has("config_key", W, 20, "Digest", use="read"))
        self.assertTrue(self.has("config_key", W, 21, "DIGEST_TOKEN", use="read", secret_location=False, role="env"))

    def test_hardcoded_secret_constant_is_a_define(self):
        self.assertTrue(self.has("config_key", "Services/NotificationService.cs", 10, "_smtpPassword", use="define"))

    def test_kinds_and_types_valid(self):
        for f in self.facts:
            if f["kind"] == "entry_point":
                self.assertIn(f["detail"]["type"], ("route", "page", "handler", "job"))
            if f["kind"] == "data_access":
                self.assertIn(f["detail"]["type"], ("stored_procedure", "sql", "entity", "repository", "ef"))

    def test_no_secret_values_in_facts(self):
        secrets = set()
        for sf in scan.walk(SAMPLE):
            if sf.skipped:
                continue
            body, _ = scan.read_text(SAMPLE, sf.path)
            secrets.update(re.findall(r"(?i)(?:password|pwd)\s*=\s*([^;\"'\s<>]{3,})", body))
            secrets.update(re.findall(r"(?i)(?:\w*(?:password|apikey|secret|token)\w*)\s*=\s*\"([^\"\s]{3,})\"", body))
            secrets.update(re.findall(r"(?i)apikey=([\w\-]+)", body))
        secrets.add("fakepass")
        secrets = {s for s in secrets if re.search(r"[A-Za-z0-9]", s)}
        self.assertTrue(secrets)
        for s in secrets:
            self.assertNotIn(s, self.text, f"secret value leaked: {s!r}")

    def test_two_runs_identical(self):
        self.assertEqual(run(), run())

    def test_razor_ui_page(self):
        self.assertTrue(self.has("ui_page", "Pages/Counter.razor", 1, "Pages/Counter.razor",
                                 root="Pages/Counter.razor", route="/counter"))

    def test_ef_dbset_data_access(self):
        self.assertTrue(self.has("data_access", "Data/AppDbContext.cs", 8, "Tickets", type="ef", operation="set"))
        self.assertTrue(self.has("data_access", "Data/AppDbContext.cs", 9, "Comments", type="ef", operation="set",
                                 entity="Comment"))
        self.assertTrue(self.has("data_access", "Data/AppDbContext.cs", 18, "ExecuteSqlRaw", type="ef", operation="query"))
        qs = [f for f in self.facts if f["path"] == "Data/TicketQueries.cs" and f["kind"] == "data_access"]
        self.assertEqual([(f["line"], f["detail"]["operation"]) for f in qs], [(10, "query"), (12, "query")])

    def test_httpclient_external_call(self):
        self.assertTrue(self.has("external_call", "Services/PagerClient.cs", 9, "https://status.fixture.internal/v1/health",
                                 type="http", via="HttpClient", method="GET"))
        self.assertTrue(self.has("external_call", "Services/PagerClient.cs", 11, "HttpClient.SendAsync", via="HttpClient"))
        self.assertTrue(self.has("external_call", "Services/NotificationService.cs", 21,
                                 "https://pager.fixture.internal/v1/notify", via="HttpClient", method="POST"))


if __name__ == "__main__":
    unittest.main()
