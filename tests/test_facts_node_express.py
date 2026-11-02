"""Facts extraction for the node-express sample Target (named facts, secrets, determinism)."""

import json
import os
import tempfile
import unittest

from appdoc import extract

SAMPLE = os.path.join(os.path.dirname(__file__), "samples", "node-express")

# Secret-looking literals planted in src/admin/users.js. None may appear in the Facts file.
SECRETS = [
    "Sup3rS3cretPw-node",
    "acme_live_51HxYz0aBcDeFgHiJkLmNoPqR",
    "R00tPassw0rd!",
]


def _run():
    with tempfile.TemporaryDirectory() as out:
        text, _ = extract.extract(SAMPLE, out)
    return text, json.loads(text)


class NodeExpressFacts(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.text, cls.doc = _run()
        cls.facts = [f for f in cls.doc["facts"] if f["stack"] == "node-express"]

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
        self.assertIn("node-express", [s["name"] for s in self.doc["stacks"]])
        self.assertNotIn("node", [s["name"] for s in self.doc["stacks"]])

    def test_routes(self):
        self.has("entry_point", "src/index.ts", 10, "/health", type="route", method="GET", handler="inline")
        self.has("entry_point", "src/index.ts", 15, "/api", method="USE", handler="ticketsRouter")
        self.has("entry_point", "src/routes/tickets.ts", 12, "/api/tickets", method="GET", handler="inline", prefix_unresolved=True)
        self.has("entry_point", "src/routes/tickets.ts", 30, "/api/tickets", method="POST")
        self.has("entry_point", "src/routes/tickets.ts", 41, "/api/tickets/:id", method="DELETE")
        self.has("entry_point", "src/routes/tickets.ts", 54, "/api/tickets/summary",
                 method="GET", handler="getSummary", middleware=["requireAuth"])

    def test_mount_prefix_and_chained_route(self):
        self.has("entry_point", "src/admin/users.js", 23, "/admin/users", method="GET", handler="listUsers",
                 middleware=["passport.authenticate", "requireRole"])
        self.has("entry_point", "src/admin/users.js", 24, "/admin/users/:id", method="DELETE", handler="inline",
                 middleware=["adminGuard"])
        self.has("entry_point", "src/admin/users.js", 28, "/admin/jobs", method="POST")
        for f in self.facts:
            if f["path"] == "src/admin/users.js" and f["kind"] == "entry_point":
                self.assertNotIn("prefix_unresolved", f["detail"])

    def test_data_access(self):
        self.has("data_access", "src/data/db.ts", 17, "tickets", type="sql", operation="select")
        self.has("data_access", "src/data/db.ts", 30, "tickets", type="sql", operation="insert")
        self.has("data_access", "src/data/db.ts", 39, "tickets", type="sql", operation="delete")
        self.has("data_access", "src/admin/users.js", 21, "User", type="entity")
        self.has("data_access", "src/admin/users.js", 25, "users", type="sql", operation="delete")
        self.has("data_access", "src/admin/users.js", 32, "audit_log", type="sql", operation="insert")
        self.has("data_access", "src/admin/users.js", 33, "sp_archive_users", type="stored_procedure")

    def test_connections_and_config(self):
        self.has("connection", "src/data/db.ts", 5, "mysql.createPool", secret_location=True)
        self.has("connection", "src/admin/users.js", 6, "knex", secret_location=True)
        self.has("config_key", "src/data/db.ts", 9, "DB_PASSWORD", source="code", secret_location=True)
        self.has("config_key", "src/index.ts", 5, "PORT", source="code", secret_location=False)
        self.has("config_key", "src/services/itsm.ts", 3, "SUPPORT_API_URL", source="code")

    def test_external_calls(self):
        self.has("external_call", "src/services/itsm.ts", 13, "${SUPPORT_API_URL}/tickets/${ticketId}/status", type="http")
        self.has("external_call", "src/admin/users.js", 31, "https://hooks.internal/notify", type="http")
        self.has("external_call", "src/admin/users.js", 29, "node", type="process")
        self.has("external_call", "src/admin/users.js", 30, "/tmp/reindex.flag", type="file")

    def test_auth(self):
        self.has("auth_check", "src/routes/tickets.ts", 54, "requireAuth")
        self.has("auth_check", "src/admin/users.js", 23, "passport.authenticate('jwt')", mechanism="passport")
        self.has("auth_check", "src/admin/users.js", 23, "requireRole('admin')", roles=["admin"])
        self.has("auth_check", "src/admin/users.js", 24, "adminGuard", mechanism="guard")

    def test_messages(self):
        self.has("message", "src/routes/tickets.ts", 23, "ticket not found", context="error")
        self.has("message", "src/routes/tickets.ts", 33, "subject is required", context="validation")
        self.has("message", "src/admin/users.js", 26, "not allowed to delete", context="error")
        self.has("message", "src/admin/users.js", 34, "job queue unavailable", context="error")
        self.has("message", "src/services/itsm.ts", 19, "ITSM sync failed: HTTP ${response.status} for ticket ${ticketId}")

    def test_comments_yield_nothing(self):
        self.lacks("entry_point", "src/admin/users.js", "/commented-out")
        self.lacks("message", "src/admin/users.js", "commented message")

    def test_no_secret_values_in_facts(self):
        for s in SECRETS:
            self.assertNotIn(s, self.text, f"secret value leaked: {s[:4]}...")

    def test_byte_identical_two_runs(self):
        self.assertEqual(_run()[0], _run()[0])


if __name__ == "__main__":
    unittest.main()
