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
        secrets.add("fakepass")
        secrets = {s for s in secrets if re.search(r"[A-Za-z0-9]", s)}
        self.assertTrue(secrets)
        for s in secrets:
            self.assertNotIn(s, self.text, f"secret value leaked: {s!r}")

    def test_two_runs_identical(self):
        self.assertEqual(run(), run())


if __name__ == "__main__":
    unittest.main()
