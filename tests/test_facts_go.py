"""Facts extraction for the go sample Target (routes with group prefixes, commands, jobs, config, SQL, calls)."""

import json
import os
import tempfile
import unittest

from appdoc import extract
from appdoc.stacks import go

SAMPLE = os.path.join(os.path.dirname(__file__), "samples", "go")


def _run():
    with tempfile.TemporaryDirectory() as out:
        text, _ = extract.extract(SAMPLE, out)
    return text, json.loads(text)


class GoFacts(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.text, cls.doc = _run()
        cls.facts = [f for f in cls.doc["facts"] if f["stack"] == "go"]

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

    def of(self, kind, path, **detail):
        return [f for f in self.facts if f["kind"] == kind and f["path"] == path
                and all(f["detail"].get(k) == v for k, v in detail.items())]

    def test_stack_detected(self):
        found = [s for s in self.doc["stacks"] if s["name"] == "go" and s["stack"] == "go"]
        self.assertEqual(len(found), 1)
        self.assertEqual(found[0]["detail"]["marker_files"], ["go.mod"])

    def test_detect_needs_go_mod_and_non_vendored_source(self):
        st = go.STACK
        self.assertEqual(st.detect(["svc/go.mod", "svc/main.go"]), ["svc/go.mod"])
        self.assertEqual(st.detect(["main.go"]), [])
        self.assertEqual(st.detect(["go.mod", "vendor/x/y.go"]), [])
        self.assertEqual(st.detect(["go.mod", "README.md"]), [])

    def test_chi_routes_and_route_prefixes(self):
        self.has("entry_point", "main.go", 13, "/health", type="route", method="GET", handler="healthHandler", middleware=[])
        self.has("entry_point", "main.go", 16, "/api/items", method="GET", handler="listItems")
        self.has("entry_point", "main.go", 17, "/api/items", method="POST", handler="createItem", middleware=["requireAuth"])
        self.has("entry_point", "main.go", 19, "/api/admin/items/{id}", method="DELETE", handler="deleteItem")

    def test_stdlib_routes(self):
        self.has("entry_point", "main.go", 24, "/legacy/{id}", method="GET", handler="legacyHandler")
        self.has("entry_point", "main.go", 25, "/ping", method="ANY", handler="pingHandler")

    def test_gitea_style_group_prefix_accumulation(self):
        p = "routers/web.go"
        self.has("entry_point", p, 6, "/", method="GET", handler="Home")
        self.has("entry_point", p, 8, "/user/login", method="GET", handler="auth.SignIn")
        self.has("entry_point", p, 9, "/user/login", method="POST", handler="auth.SignInPost", middleware=["web.Bind"])
        self.has("entry_point", p, 11, "/user/settings", method="GET", handler="settings.Profile", middleware=["reqSignIn"])
        self.has("entry_point", p, 12, "/user/settings/avatar", method="POST", handler="settings.AvatarPost",
                 middleware=["reqSignIn", "web.Bind"])
        self.has("entry_point", p, 17, "/user/logout", method="GET", handler="auth.SignOut",
                 middleware=["optSignIn", "reqToken"])

    def test_combo_chain_over_two_lines(self):
        p = "routers/web.go"
        self.has("entry_point", p, 13, "/user/settings/account", method="GET", handler="settings.Account")
        self.has("entry_point", p, 14, "/user/settings/account", method="POST", handler="settings.AccountPost")

    def test_methods_any_and_inline_handler(self):
        p = "routers/web.go"
        self.has("entry_point", p, 20, "/assets/*", method="GET,HEAD", handler="public.Files")
        self.has("entry_point", p, 21, "/ping", method="ANY", handler="Ping")
        self.has("entry_point", p, 22, "/redirect", method="GET", handler="inline")

    def test_helper_function_prefix_is_unresolved(self):
        self.has("entry_point", "routers/web.go", 29, "/move", method="POST", handler="board.Move", prefix_unresolved=True)
        self.assertEqual(self.of("entry_point", "routers/web.go", prefix_unresolved=True).__len__(), 1)

    def test_commented_routes_yield_nothing(self):
        self.lacks("entry_point", "main.go", "/old-health")
        self.lacks("entry_point", "main.go", "/commented-block")
        self.lacks("entry_point", "routers/web.go", "/disabled")

    def test_auth_checks(self):
        self.has("auth_check", "main.go", 12, "jwtMiddleware", mechanism="jwt", scope="use")
        self.has("auth_check", "main.go", 17, "requireAuth", scope="route")
        self.has("auth_check", "routers/web.go", 10, "reqSignIn", scope="group")
        self.has("auth_check", "routers/web.go", 16, "reqToken", scope="group")
        self.lacks("auth_check", "routers/web.go", "optSignIn")

    def test_commands(self):
        self.has("entry_point", "cmd/commands.go", 10, "web", type="command", framework="urfave/cli",
                 handler="runWeb", usage="Start the web server")
        self.has("entry_point", "cmd/commands.go", 24, "admin", type="command")
        self.has("entry_point", "cmd/commands.go", 28, "sync", type="command", handler="runSync")
        self.has("entry_point", "cmd/commands.go", 36, "migrate", type="command", framework="cobra",
                 handler="runMigrate", usage="Run database migrations")
        self.lacks("entry_point", "cmd/commands.go", "port")  # a flag, not a command

    def test_jobs_schedule_enabled_handler(self):
        p = "services/cron/tasks.go"
        self.has("entry_point", p, 6, "cleanup_sessions", type="job", schedule="@every 24h", enabled=True,
                 handler="session.DeleteOld")
        self.has("entry_point", p, 18, "rebuild_index", type="job", schedule="@annually", enabled=False,
                 handler="search.Rebuild")
        self.has("entry_point", p, 28, "weekly_report", type="job", schedule="0 6 * * 1", enabled=True, handler="runReport")
        self.has("entry_point", p, 37, "syncMirrors", type="job", schedule="@every 5m", enabled=None, handler="syncMirrors")
        self.assertEqual(len(self.of("entry_point", p, type="job")), 4)  # the RegisterTask wrapper is not a job

    def test_config_reads(self):
        p = "store/store.go"
        self.has("config_key", p, 12, "server.DOMAIN", source="code", use="read", secret_location=False)
        self.has("config_key", p, 13, "server.HTTP_PORT", use="read")
        self.has("config_key", p, 14, "security.SECRET_KEY", use="read", secret_location=True)
        self.has("config_key", p, 15, "DB_PASSWORD", use="read", via="env", secret_location=True)
        self.has("config_key", p, 16, "FEATURE_X", use="read", via="env", secret_location=False)
        self.has("config_key", "main.go", 28, "LISTEN_ADDR", use="read", via="env", secret_location=False)

    def test_sql(self):
        p = "store/store.go"
        self.has("data_access", p, 20, "users", type="sql", operation="select")
        self.has("data_access", p, 22, "sessions", type="sql", operation="delete")
        self.has("data_access", p, 23, "orders", type="sql", operation="select")
        self.has("data_access", p, 23, "users", type="sql", operation="select")
        self.has("data_access", p, 25, "users", type="sql", operation="update")
        self.assertEqual(len(self.of("data_access", p)), 5)  # "git gc" is not SQL

    def test_external_calls(self):
        p = "store/store.go"
        self.has("external_call", p, 30, "https://api.example.com/v1/ping", type="http", method="GET", call="http.NewRequest")
        self.has("external_call", p, 32, "https://hooks.example.com/notify", call="http.Get")  # query and user info cut
        self.has("external_call", p, 33, "http.NewRequestWithContext", method="POST")
        self.has("external_call", p, 34, "http.Post")

    def test_no_secret_shapes_or_values_in_facts(self):
        for s in ("abc", "pw@", "hunter"):
            self.assertNotIn(s, " ".join(f["name"] for f in self.facts))

    def test_byte_identical_two_runs(self):
        self.assertEqual(_run()[0], _run()[0])


if __name__ == "__main__":
    unittest.main()
