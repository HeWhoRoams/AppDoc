"""Java Spring Stack: runs the real pipeline on tests/samples/java-spring."""

import json
import os
import tempfile
import unittest

from appdoc import extract
from appdoc.stacks import java_spring

SAMPLE = os.path.join(os.path.dirname(__file__), "samples", "java-spring")
J = "src/main/java/com/acme/"
W = "src/main/webapp/"

# (kind, path, line, name)
EXPECTED = [
    ("entry_point", J + "TicketsController.java", 29, "/api/tickets"),
    ("entry_point", J + "TicketsController.java", 53, "/api/tickets/{id}"),
    ("entry_point", "src/main/java/com/example/app/AuditLogController.java", 18, "/audit-log"),
    # class-level prefix + multi-line annotation + value = {"/a","/b"}
    ("entry_point", J + "api/OrderController.java", 18, "/api/orders/search"),
    ("entry_point", J + "api/OrderController.java", 18, "/api/orders/find"),
    ("entry_point", J + "api/OrderController.java", 26, "/api/orders/{id}/cancel"),
    ("entry_point", J + "api/OrderController.java", 34, "OrderController.nightlySweep"),
    ("entry_point", J + "api/OrderController.java", 40, "/api/orders/wild/*"),
    ("entry_point", W + "WEB-INF/web.xml", 10, "/reports/*"),
    ("entry_point", W + "WEB-INF/struts.xml", 4, "/billing/invoice"),
    ("entry_point", W + "WEB-INF/applicationContext.xml", 8, "/legacy/orders.htm"),
    ("entry_point", W + "admin/dashboard.jsp", None, W + "admin/dashboard.jsp"),
    ("data_access", J + "Ticket.java", 15, "tickets"),
    ("data_access", "src/main/java/com/example/app/AuditLog.java", 19, "audit_logs"),
    ("data_access", J + "TicketRepository.java", 10, "TicketRepository"),
    ("data_access", J + "api/OrderRepository.java", 8, "order_items"),
    ("data_access", J + "api/OrderRepository.java", 12, "OrderAudit"),
    ("data_access", J + "api/OrderController.java", 36, "orders"),
    ("data_access", J + "api/OrderDao.java", 18, "order_log"),
    ("data_access", J + "api/OrderDao.java", 19, "customers"),
    ("data_access", J + "api/OrderDao.java", 20, "sp_close_order"),
    ("data_access", "src/main/resources/mappers/OrderMapper.xml", 3, "open_orders"),
    ("data_access", "src/main/resources/mappers/OrderMapper.xml", 6, "orders"),
    ("connection", W + "WEB-INF/applicationContext.xml", 3, "legacyDataSource"),
    ("connection", J + "api/OrderDao.java", 33, "ordersDataSource"),
    ("connection", J + "api/OrderDao.java", 30, "jdbc/OrdersDS"),
    ("external_call", J + "TicketService.java", 42, "/intake/tickets"),
    ("external_call", J + "api/OrderDao.java", 25, "/var/spool/orders.csv"),
    ("external_call", J + "api/OrderDao.java", 27, "JavaMailSender"),
    ("external_call", J + "api/OrderDao.java", 28, "https://pricing.acme.internal/v1"),
    ("external_call", J + "api/OrderDao.java", 29, "/usr/bin/convert"),
    ("auth_check", J + "api/OrderController.java", 25, "hasAnyRole('ADMIN','CLERK')"),
    ("auth_check", J + "config/SecurityConfig.java", 8, 'antMatchers("/admin/**", "/ops/*").hasRole("ADMIN")'),
    ("auth_check", W + "WEB-INF/web.xml", 12, "security-constraint /admin/*"),
    ("message", J + "TicketService.java", 35, "ticket not found:"),
    ("message", J + "api/OrderController.java", 29, "Order id must be positive"),
    ("message", J + "api/OrderController.java", 31, "Order already shipped"),
]

# Things that must NOT produce facts (commented-out code, ignored XML).
ABSENT_NAMES = ["/commented-out", "/dead-block", "ghost_table", "/ghost", "/api/orders/commented-out"]

SECRET_VALUES = ["FakeP@ss123", "PropsP@ss999", "Sup3rS3cretPw!", "BeanP@ss777", "XmlDsP@ss555",
                 "abc123XYZ", "tickets_user", "props_user", "legacy_user"]


def run(out):
    text, _ = extract.extract(SAMPLE, out)
    return text


class JavaSpringTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory()
        cls.text = run(cls.tmp.name)
        cls.doc = json.loads(cls.text)
        cls.facts = [f for f in cls.doc["facts"] if f["stack"] == "java-spring"]

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def test_stack_detected(self):
        names = [s["name"] for s in self.doc["stacks"] if s["stack"] == "java-spring"]
        self.assertEqual(names, ["java-spring"])
        self.assertFalse([s for s in self.doc["stacks"] if s["name"] == "java" and not s["detail"]["supported"]])

    def test_expected_facts_present(self):
        have = {(f["kind"], f["path"], f["line"], f["name"]) for f in self.facts}
        have |= {(f["kind"], f["path"], f["line"], f["name"]) for f in self.doc["stacks"]}
        missing = [e for e in EXPECTED if e not in have]
        self.assertEqual(missing, [])

    def test_details(self):
        def find(kind, path, line, name):
            return next(f for f in self.facts if (f["kind"], f["path"], f["line"], f["name"]) == (kind, path, line, name))
        d = find("entry_point", J + "api/OrderController.java", 26, "/api/orders/{id}/cancel")["detail"]
        self.assertEqual((d["method"], d["handler"], d["type"]), ("POST", "OrderController.cancel", "route"))
        self.assertEqual(find("entry_point", J + "api/OrderController.java", 34, "OrderController.nightlySweep")["detail"]["type"], "job")
        self.assertEqual(find("entry_point", W + "admin/dashboard.jsp", None, W + "admin/dashboard.jsp")["detail"]["inputs"], ["query"])
        self.assertTrue(find("connection", J + "api/OrderDao.java", 33, "ordersDataSource")["detail"]["secret_location"])
        self.assertTrue(find("connection", W + "WEB-INF/applicationContext.xml", 3, "legacyDataSource")["detail"]["secret_location"])
        self.assertFalse(find("connection", J + "api/OrderDao.java", 30, "jdbc/OrdersDS")["detail"]["secret_location"])
        self.assertEqual(find("auth_check", J + "api/OrderController.java", 25, "hasAnyRole('ADMIN','CLERK')")["detail"]["roles"], ["ADMIN", "CLERK"])
        q = find("data_access", J + "api/OrderRepository.java", 8, "order_items")["detail"]
        self.assertEqual((q["type"], q["operation"]), ("sql", "select"))
        self.assertEqual(find("data_access", J + "api/OrderDao.java", 20, "sp_close_order")["detail"]["type"], "stored_procedure")

    def test_commented_out_code_yields_nothing(self):
        names = {f["name"] for f in self.facts}
        for n in ABSENT_NAMES:
            self.assertNotIn(n, names)
        self.assertFalse([f for f in self.facts if f["path"].endswith("OrderController.java") and f["line"] in (15, 16)])

    def test_config_files_left_to_generic(self):
        self.assertFalse([f for f in self.facts if f["path"].endswith((".properties", ".yml", "pom.xml"))])

    def test_kinds_and_detail_types_valid(self):
        for f in self.facts:
            d = f["detail"]
            if f["kind"] == "entry_point":
                self.assertIn(d["type"], {"route", "page", "handler", "job"})
            if f["kind"] == "data_access":
                self.assertIn(d["type"], {"stored_procedure", "sql", "entity", "repository"})
                self.assertIn("operation", d)
            if f["kind"] == "external_call":
                self.assertIn(d["type"], {"http", "email", "com", "file", "process"})
            if f["kind"] == "auth_check":
                self.assertIn("mechanism", d)
                self.assertLessEqual(len(f["name"]), 120)
            if f["kind"] == "message":
                self.assertIn(d["context"], {"error", "validation", "info"})
                self.assertLessEqual(len(f["name"]), 200)

    def test_no_secret_value_in_facts(self):
        for v in SECRET_VALUES:
            self.assertNotIn(v, self.text)

    def test_deterministic(self):
        with tempfile.TemporaryDirectory() as a, tempfile.TemporaryDirectory() as b:
            self.assertEqual(run(a).encode(), run(b).encode())

    def test_detect_paths_only(self):
        st = java_spring.STACK
        self.assertEqual(st.detect(["a.py"]), [])
        self.assertEqual(st.detect(["pom.xml"]), [])
        self.assertEqual(st.detect(["pom.xml", "A.java"]), ["pom.xml"])
        self.assertEqual(st.detect(["WEB-INF/struts-config.xml".replace("-config", ""), "x.txt"]), ["WEB-INF/struts.xml"])
        self.assertEqual(st.detect(["web/index.jsp"]), ["web/index.jsp"])


class JavaSpringUnitTest(unittest.TestCase):
    def extract(self, path, text):
        return [(f.kind, f.line, f.name, f.detail_dict()) for f in java_spring.STACK.extract(path, text)]

    def test_string_with_slash_star_does_not_eat_code(self):
        src = 'class A {\n  void c(H h){ h.antMatchers("/api/*").permitAll(); }\n  @GetMapping("/after")\n  String x(){return "";}\n}\n/* end */\n'
        names = [n for k, _, n, _ in self.extract("A.java", src)]
        self.assertIn("/after", names)

    def test_secret_shaped_url_not_recorded(self):
        src = 'class A { void m(RestTemplate rt){ rt.getForObject("https://bob:hunter2pw@h.example/x?token=zzz", String.class); } }'
        out = json.dumps(self.extract("A.java", src))
        self.assertNotIn("hunter2pw", out)
        self.assertNotIn("zzz", out)

    def test_non_spring_xml_ignored(self):
        self.assertEqual(self.extract("a/config.xml", "<root><x/></root>"), [])
        self.assertEqual(self.extract("pom.xml", "<project><beans/></project>"), [])


if __name__ == "__main__":
    unittest.main()
