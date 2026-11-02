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

    def test_commented_out_code_yields_nothing(self):
        names = " ".join(f["name"] for f in self.facts)
        self.assertNotIn("Commented out", names)
        self.assertNotIn("/ignored", names)

    def test_kinds_and_types_valid(self):
        for f in self.facts:
            if f["kind"] == "entry_point":
                self.assertIn(f["detail"]["type"], ("route", "page", "handler", "job"))
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
            secrets.update(re.findall(r"(?i)apikey=([\w\-]+)", body))
        secrets.add("fakepass")
        secrets = {s for s in secrets if re.search(r"[A-Za-z0-9]", s)}
        self.assertTrue(secrets)
        for s in secrets:
            self.assertNotIn(s, self.text, f"secret value leaked: {s!r}")

    def test_two_runs_identical(self):
        self.assertEqual(run(), run())


if __name__ == "__main__":
    unittest.main()
