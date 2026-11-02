"""Facts extraction for the python-flask sample Target (named facts, secrets, determinism)."""

import json
import os
import tempfile
import unittest

from appdoc import extract

SAMPLE = os.path.join(os.path.dirname(__file__), "samples", "python-flask")

# Secret-looking literals planted in admin/views.py. None may appear in the Facts file.
SECRETS = [
    "Zx9-Legacy-Pa55w0rd",
    "Sup3rS3cretPw",
    "tok_live_8f3a91c2d7e04b5a9c61",
    "abc123secretvalue",
]


def _run():
    with tempfile.TemporaryDirectory() as out:
        text, _ = extract.extract(SAMPLE, out)
    return text, json.loads(text)


class PythonFlaskFacts(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.text, cls.doc = _run()
        cls.facts = [f for f in cls.doc["facts"] if f["stack"] == "python-flask"]

    def has(self, kind, path, line, name, **detail):
        for f in self.facts:
            if (f["kind"], f["path"], f["line"], f["name"]) == (kind, path, line, name):
                if all(f["detail"].get(k) == v for k, v in detail.items()):
                    return
        self.fail(f"missing fact {kind} {path}:{line} {name} {detail}")

    def lacks(self, kind, path, name):
        for f in self.facts:
            if (f["kind"], f["path"], f["name"]) == (kind, path, name):
                self.fail(f"unexpected fact {kind} {path} {name}")

    def test_stack_detected(self):
        self.assertIn("python-flask", [s["name"] for s in self.doc["stacks"]])
        self.assertNotIn("python", [s["name"] for s in self.doc["stacks"]])

    def test_routes(self):
        self.has("entry_point", "app.py", 17, "/health", type="route", method="GET", handler="health")
        self.has("entry_point", "routes.py", 14, "/api/tickets", method="GET", handler="list_tickets", prefix_unresolved=True)
        self.has("entry_point", "routes.py", 22, "/api/tickets", method="POST", handler="create_new_ticket")
        self.has("entry_point", "routes.py", 32, "/api/tickets/<int:ticket_id>", method="GET", handler="get_single_ticket")
        self.has("entry_point", "routes.py", 41, "/api/tickets/<int:ticket_id>", method="DELETE", handler="close_ticket")

    def test_blueprint_prefix_and_methods(self):
        self.has("entry_point", "admin/views.py", 33, "/admin/users", method="GET", handler="users")
        self.has("entry_point", "admin/views.py", 33, "/admin/users", method="POST")
        self.has("entry_point", "admin/views.py", 44, "/admin/purge", method="GET", handler="purge")
        for f in self.facts:
            if f["path"] == "admin/views.py" and f["kind"] == "entry_point":
                self.assertNotIn("prefix_unresolved", f["detail"])

    def test_data_access(self):
        self.has("data_access", "data/db.py", 37, "helpdesk_tickets", type="sql", operation="select")
        self.has("data_access", "data/db.py", 66, "helpdesk_tickets", type="sql", operation="insert")
        self.has("data_access", "data/db.py", 90, "helpdesk_tickets", type="sql", operation="delete")
        self.has("data_access", "admin/views.py", 28, "helpdesk_agents", type="entity")
        self.has("data_access", "admin/views.py", 40, "helpdesk_teams", type="sql", operation="select")
        self.has("data_access", "admin/views.py", 47, "usp_PurgeClosedTickets", type="stored_procedure")
        self.has("data_access", "admin/views.py", 48, "usp_RebuildIndexes", type="stored_procedure")
        self.has("data_access", "admin/views.py", 49, "helpdesk_tickets", type="sql", operation="update")

    def test_connections_and_config(self):
        self.has("connection", "data/db.py", 28, "psycopg2.connect", secret_location=True)
        self.has("connection", "admin/views.py", 19, "create_engine", secret_location=True)
        self.has("connection", "admin/views.py", 20, "pyodbc.connect", secret_location=True)
        self.has("config_key", "data/db.py", 22, "DB_PASSWORD", source="code", secret_location=True)
        self.has("config_key", "app.py", 25, "PORT", source="code", secret_location=False)
        self.has("config_key", "admin/views.py", 59, "ADMIN_EMAIL", source="code")

    def test_external_calls(self):
        self.has("external_call", "services/itsm.py", 27, "{SUPPORT_API_URL}/tickets/{ticket_id}/status", type="http")
        self.has("external_call", "admin/views.py", 52, "https://hooks.internal/notify", type="http")
        self.has("external_call", "admin/views.py", 50, "/usr/bin/backup", type="process")
        self.has("external_call", "admin/views.py", 51, "smtp.internal", type="email")
        self.has("external_call", "admin/views.py", 53, "/var/log/purge.log", type="file")

    def test_auth(self):
        self.has("auth_check", "admin/views.py", 34, "@login_required", mechanism="login")
        self.has("auth_check", "admin/views.py", 35, '@roles_required("admin", "supervisor")', roles=["admin", "supervisor"])
        self.has("auth_check", "admin/views.py", 37, 'current_user.has_role("admin")')

    def test_messages(self):
        self.has("message", "routes.py", 27, "subject is required", context="validation")
        self.has("message", "routes.py", 37, "ticket not found", context="error")
        self.has("message", "admin/views.py", 38, "admins only", context="error")
        self.has("message", "admin/views.py", 39, "User list refreshed", context="info")
        self.has("message", "admin/views.py", 55, "purge failed: nothing to purge")

    def test_comments_yield_nothing(self):
        self.lacks("entry_point", "admin/views.py", "/admin/old-route")
        self.lacks("message", "admin/views.py", "commented out message")

    def test_no_secret_values_in_facts(self):
        for s in SECRETS:
            self.assertNotIn(s, self.text, f"secret value leaked: {s[:4]}...")

    def test_byte_identical_two_runs(self):
        self.assertEqual(_run()[0], _run()[0])


if __name__ == "__main__":
    unittest.main()
