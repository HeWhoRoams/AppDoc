"""Classic ASP Stack: runs the real pipeline on tests/samples/classic-asp."""

import json
import os
import re
import tempfile
import unittest

from appdoc import extract, scan

SAMPLE = os.path.join(os.path.dirname(__file__), "samples", "classic-asp")


def run():
    with tempfile.TemporaryDirectory() as out:
        text, _ = extract.extract(SAMPLE, out)
    return text


class ClassicAspFacts(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.text = run()
        doc = json.loads(cls.text)
        cls.facts = [f for f in doc["facts"] if f["stack"] == "classic-asp"]
        cls.stacks = doc["stacks"]

    def has(self, kind, path, line, name, **detail):
        for f in self.facts:
            if (f["kind"], f["path"], f["line"], f["name"]) == (kind, path, line, name) \
                    and all(f["detail"].get(k) == v for k, v in detail.items()):
                return True
        return False

    def test_stack_detected(self):
        self.assertIn("classic-asp", [s["name"] for s in self.stacks])

    def test_expected_facts(self):
        expected = [
            ("entry_point", "index.asp", 1, "index.asp", dict(type="page", inputs=[])),
            ("entry_point", "new-ticket.asp", 1, "new-ticket.asp",
             dict(type="page", inputs=["CustomerName", "Status", "Subject", "TicketId", "action"])),
            ("entry_point", "search-ticket.asp", 1, "search-ticket.asp", dict(inputs=["id"])),
            ("entry_point", "admin/users.asp", 1, "admin/users.asp",
             dict(inputs=["REMOTE_USER", "UserName", "debug", "level", "page"])),
            ("dependency", "index.asp", 3, "common/helpers.inc", dict(manager="include")),
            ("dependency", "admin/users.asp", 1, "/common/helpers.inc", dict(manager="include", mode="virtual")),
            ("dependency", "admin/lookup.asp", 2, "missing-but-listed.inc", dict(manager="include")),
            ("data_access", "index.asp", 8, "HelpDesk.Tickets", dict(type="sql", operation="select")),
            ("data_access", "audit-log.asp", 7, "HelpDesk.AuditTrail", dict(type="sql", operation="select")),
            ("data_access", "search-ticket.asp", 13, "HelpDesk.Tickets", dict(type="sql", operation="select")),
            ("data_access", "new-ticket.asp", 17, "HelpDesk.usp_CreateTicket", dict(type="stored_procedure")),
            ("data_access", "admin-report.asp", 6, "HelpDesk.usp_GetMonthlyMetrics", dict(type="stored_procedure")),
            ("data_access", "admin/lookup.asp", 11, "HelpDesk.usp_LookupUser", dict(type="stored_procedure")),
            ("data_access", "admin/users.asp", 16, "HelpDesk.Users", dict(type="sql", operation="update")),
            ("data_access", "admin/users.asp", 20, "HelpDesk.usp_AuditLogin", dict(type="stored_procedure")),
            ("data_access", "admin/users.asp", 21, "HelpDesk.SessionCache", dict(type="sql", operation="delete")),
            ("data_access", "admin/users.asp", 22, "HelpDesk.UserLog", dict(type="sql", operation="insert")),
            ("connection", "new-ticket.asp", 11, "conn", dict(secret_location=True)),
            ("connection", "new-ticket.asp", 13, "conn", dict(secret_location=False)),
            ("connection", "common/helpers.inc", 6, "c", dict(secret_location=True)),
            ("connection", "admin/lookup.asp", 6, "strConn", dict(secret_location=True)),
            ("connection", "admin/lookup.asp", 9, "cn", dict(secret_location=True)),
            ("external_call", "admin/users.asp", 31, "Scripting.FileSystemObject", dict(type="file")),
            ("external_call", "admin/users.asp", 32, "CDO.Message", dict(type="email")),
            ("external_call", "admin/users.asp", 33, "MSXML2.ServerXMLHTTP.6.0", dict(type="http")),
            ("external_call", "admin/users.asp", 34, "HelpDesk.LegacyCom", dict(type="com")),
            ("auth_check", "admin/users.asp", 4, 'Session("Authenticated") <> True', dict(mechanism="session")),
            ("auth_check", "admin/users.asp", 7,
             'Session("UserRole") <> "Admin" And Session("UserRole") <> "Supervisor"',
             dict(roles=["Admin", "Supervisor"])),
            ("message", "new-ticket.asp", 24, "ERROR creating ticket:", dict(context="error")),
            ("message", "audit-log.asp", 9, "Failed to load audit trail:", dict(context="error")),
            ("message", "index.asp", 21, "query error:", dict(context="error")),
            ("message", "admin/users.asp", 13, "User name must be supplied.", dict(context="validation")),
            ("message", "admin/users.asp", 36, "Access denied for user:", dict(context="error")),
        ]
        missing = [e[:4] for e in expected if not self.has(*e[:4], **e[4])]
        self.assertEqual(missing, [])

    def test_no_false_positives(self):
        names = {(f["kind"], f["name"]) for f in self.facts}
        self.assertNotIn(("external_call", "Fake.Commented"), names)          # REM comment
        self.assertFalse([f for f in self.facts if "commented error" in f["name"]])
        # success-branch writes and non-error HTML are not messages
        self.assertFalse([f for f in self.facts if f["kind"] == "message" and f["name"] == "Saved."])
        # ADODB objects are covered by connection/data_access, not external_call
        self.assertFalse([f for f in self.facts if f["kind"] == "external_call" and f["name"].startswith("ADODB")])
        # no auth_check for the non-Session redirect in search-ticket.asp
        self.assertFalse([f for f in self.facts if f["kind"] == "auth_check" and f["path"] == "search-ticket.asp"])

    def test_no_secret_values(self):
        secrets = set()
        for sf in scan.walk(SAMPLE):
            if sf.skipped:
                continue
            src, _ = scan.read_text(SAMPLE, sf.path)
            secrets.update(re.findall(r"(?i)(?:password|pwd)=([^;\"\s]+)", src))
            secrets.update(re.findall(r"(?i)(?:user id|uid)=([^;\"\s]+)", src))
        secrets |= {"fakepass", "fakepass2", "fakepass3", "fakeuser"}
        for s in secrets:
            self.assertNotIn(s, self.text, f"secret value leaked: {s}")

    def test_deterministic(self):
        self.assertEqual(run(), run())


if __name__ == "__main__":
    unittest.main()
