"""Generic extractor: config `use`, DDL schema objects, ownership files, and the new summary sections."""

import json
import os
import tempfile
import unittest

from appdoc import extract
from appdoc.stacks import generic
from appdoc.summary import render_summary

HERE = os.path.dirname(os.path.abspath(__file__))
SAMPLE = os.path.join(HERE, "samples", "generic")


def facts_of(path, text, kind, siblings=None):
    return [f for f in generic.extract(path, text, siblings) if f.kind == kind]


def sample_doc():
    text, summary = extract.extract(SAMPLE, os.path.join(tempfile.gettempdir(), "appdoc-unused-out"))
    return json.loads(text), summary


def objects(doc, **want):
    return [f for f in doc["facts"] if f["kind"] == "schema_object"
            and all(f["detail"].get(k) == v for k, v in want.items())]


class ConfigUseTests(unittest.TestCase):
    def test_config_file_keys_are_defines_and_keep_role(self):
        cases = {
            "src/application.properties": "a.b=1\n",
            "config/app.yml": "a:\n  b: 1\n",
            "custom/app.ini": "[s]\nKEY = 1\n",
            "appsettings.json": '{"A": {"B": 1}}',
            ".env": "A=1\n",
        }
        for path, text in cases.items():
            keys = facts_of(path, text, "config_key")
            self.assertTrue(keys, path)
            for f in keys:
                self.assertEqual(f.detail_dict()["use"], "define", path)
                self.assertIn("role", f.detail_dict())

    def test_commented_ini_default_is_still_a_define_and_commented(self):
        (f,) = facts_of("custom/app.ini", "[s]\n;PORT = 3000\n", "config_key")
        d = f.detail_dict()
        self.assertEqual((d["use"], d["commented"]), ("define", True))


class ConfigNoiseTests(unittest.TestCase):
    def test_tooling_and_fixture_config_is_not_application_config(self):
        cases = {
            # Gitea paths found in a real run
            "models/fixtures/user.yml": "test",
            "modelmigration/fixtures/Test_AddRepoIDForAttachment/issue.yml": "test",
            "modules/actions/jobparser/testdata/has_needs.in.yaml": "test",
            "modules/migration/file_format_testdata/issue_a.yml": "test",
            "templates/mail/repo/release.devtest.yml": "test",
            "tests/e2e/e2e.ini": "test",
            "e2e/playwright.config.json": "test",
            "src/main/resources/test/application.yml": "test",
            "crowdin.yml": "build",
            "snap/snapcraft.yaml": "build",
            "contrib/development/vscode/settings.json": "build",
            "tools/lint/config.ini": "build",
            "scripts/ci/settings.yml": "build",
            "docs/examples/app.ini": "build",
            "examples/demo/appsettings.json": "build",
            ".devcontainer/devcontainer.env.yml": "build",
            # framework-defined names are app; other config names are unclassified (1.4A)
            "custom/conf/app.example.ini": "unclassified",
            "docker/root/etc/templates/app.ini": "unclassified",
            "src/Identity.API/appsettings.json": "app",
            "config/settings.yml": "unclassified",
            "config/settings.json": "app",
            "docker-compose.yml": "orchestration",
            ".github/workflows/ci.yml": "ci",
        }
        for path, role in cases.items():
            self.assertEqual(generic.config_role(path), role, path)

    def test_test_config_keys_are_marked_test_so_the_reference_skips_them(self):
        keys = facts_of("models/fixtures/user.yml", "id: 1\nname: x\n", "config_key")
        self.assertEqual(len(keys), 2)
        for f in keys:
            self.assertTrue(f.detail_dict().get("test"), f)

    def test_json_dotenv_and_dotnet_config_get_a_role_too(self):
        (f,) = facts_of("contrib/dev/settings.json", '{"A": 1}', "config_key")
        self.assertEqual(f.detail_dict()["role"], "build")
        (f,) = facts_of("tools/.env", "A=1\n", "config_key")
        self.assertEqual(f.detail_dict()["role"], "build")
        (f,) = facts_of("tools/app.config", '<configuration><appSettings><add key="K" value="v"/></appSettings></configuration>',
                        "config_key")
        self.assertEqual(f.detail_dict()["role"], "build")
        (f,) = facts_of("src/appsettings.json", '{"A": 1}', "config_key")
        self.assertEqual(f.detail_dict()["role"], "app")

    def test_extract_keeps_the_test_path_rule_in_one_place(self):
        from appdoc import facts
        self.assertIs(extract.is_test_path, facts.is_test_path)


APPSETTINGS = """{
  // comment with "Audience": "orders"
  "Logging": { "LogLevel": { "Default": "Information" } },
  "Identity": {
    "Audience": "orders",
    // "orders": { [ ] }
    "Scopes": {
      "orders": "Orders API",
      "basket": "Basket API"
    },
    "Url": "http://x/{not-a-key}"
  },
  "ConnectionStrings": { "Default": "x" },
  "Default": 1
}
"""


class JsonConfigLineTests(unittest.TestCase):
    def lines(self, text=APPSETTINGS):
        return {f.name: f.line for f in facts_of("src/appsettings.json", text, "config_key")} | {
            f"conn:{f.name}": f.line for f in facts_of("src/appsettings.json", text, "connection")}

    def test_nested_keys_map_to_their_own_line(self):
        got = self.lines()
        self.assertEqual(got["Identity:Audience"], 5)
        self.assertEqual(got["Identity:Scopes:orders"], 8)
        self.assertEqual(got["Identity:Scopes:basket"], 9)
        self.assertEqual(got["Identity:Url"], 11)
        self.assertEqual(got["Logging:LogLevel:Default"], 3)
        self.assertEqual(got["Default"], 14)
        self.assertEqual(got["conn:Default"], 13)

    def test_crlf_does_not_shift_lines(self):
        got = self.lines(APPSETTINGS.replace("\n", "\r\n"))
        self.assertEqual(got["Identity:Scopes:orders"], 8)

    def test_walker_skips_line_and_block_comments(self):
        text = '{\n // "X": {\n /* "Y": [ \n */ "A": {\n "B": 1 }\n}\n'
        self.assertEqual(generic._json_key_lines(text), {"A": 4, "A:B": 5})

    def test_arrays_and_escaped_quotes_are_walked(self):
        text = '{\n "A": ["x", {"B": 1}],\n "C": "q\\"D\\": 1",\n "D": 2\n}\n'
        got = self.lines(text)
        self.assertEqual((got["A"], got["C"], got["D"]), (2, 3, 4))

    def test_walker_returns_what_it_found_on_malformed_text(self):
        self.assertEqual(generic._json_key_lines("{ not json at all"), {})
        self.assertEqual(generic._json_key_lines('{"A": {"B": 1}'), {"A": 1, "A:B": 1})


class DdlTests(unittest.TestCase):
    def test_sample_postgres_tables_and_function_index(self):
        doc, _ = sample_doc()
        pg = "db/postgres/schema.sql"
        tables = {f["name"]: f for f in objects(doc, type="table", dialect="postgres")}
        self.assertEqual(sorted(tables), ["accounts", "projects"])
        self.assertEqual(tables["accounts"]["path"], pg)
        self.assertEqual(tables["accounts"]["line"], 2)
        self.assertEqual(tables["accounts"]["detail"]["columns"],
                         ["id INT pk", "name TEXT not null", "balance NUMERIC(12,2)"])
        self.assertEqual(tables["projects"]["detail"]["columns"],
                         ["id INT pk", "title TEXT not null", "note TEXT", "account_id INT not null"])
        idx = {f["name"]: f["detail"] for f in objects(doc, type="index")}
        self.assertEqual(idx["unique_account_project_title"]["expression"], "account_id, LOWER(title)")
        self.assertTrue(idx["unique_account_project_title"]["unique"])
        self.assertEqual(idx["unique_account_project_title"]["table"], "projects")
        self.assertFalse(idx["idx_projects_title"]["unique"])
        self.assertEqual(idx["idx_projects_note"]["method"], "gin")

    def test_index_line_is_the_create_line(self):
        doc, _ = sample_doc()
        (f,) = [f for f in objects(doc, type="index") if f["name"] == "unique_account_project_title"]
        self.assertEqual(f["line"], 18)

    def test_constraint_lines_and_commas_in_defaults_do_not_become_columns(self):
        (t,) = [f for f in facts_of("db/postgres/schema.sql",
                                    "CREATE TABLE t (a INT, b TEXT DEFAULT 'x, y', CHECK (a > 0), UNIQUE (a, b));", "schema_object")
                if f.detail_dict()["type"] == "table"]
        self.assertEqual(t.detail_dict()["columns"], ["a INT", "b TEXT"])

    def test_foreign_keys_inline_column_and_alter(self):
        doc, _ = sample_doc()
        fks = objects(doc, type="fk")
        by_table = {(f["path"], f["detail"]["table"], f["detail"]["expression"]): f for f in fks}
        self.assertIn(("db/postgres/schema.sql", "projects", "account_id"), by_table)
        self.assertEqual(by_table[("db/postgres/schema.sql", "projects", "account_id")]["detail"]["references"],
                         "accounts(id)")
        mysql = "db/mysql/schema.sql"
        self.assertEqual(by_table[(mysql, "projects", "account_id")]["detail"]["references"], "accounts(id)")
        alter = by_table[(mysql, "tasks", "project_id")]
        self.assertEqual((alter["name"], alter["detail"]["references"]), ("fk_tasks_projects", "projects(id)"))
        self.assertEqual(alter["detail"]["dialect"], "mysql")

    def test_insert_only_file_yields_nothing(self):
        doc, _ = sample_doc()
        self.assertEqual([f for f in doc["facts"] if f["path"] == "db/postgres/data.sql" and f["kind"] != "file"], [])

    def test_comments_are_ignored_and_line_numbers_kept(self):
        text = "-- CREATE TABLE no (a INT);\n/* CREATE TABLE nope (a INT);\n */\n\nCREATE TABLE yes (a INT);\n"
        out = facts_of("schema.sql", text, "schema_object")
        self.assertEqual([(f.name, f.line) for f in out], [("yes", 5)])

    def test_dialect_from_path(self):
        cases = {"db/postgresql/s.sql": "postgres", "db/mysql/s.sql": "mysql", "db/h2/s.sql": "h2",
                 "db/hsqldb/s.sql": "hsqldb", "sqlite/s.sql": "sqlite", "oracle/s.sql": "oracle",
                 "db/sqlserver/s.sql": "mssql", "db/mssql/s.sql": "mssql", "db/s.sql": None}
        for path, want in cases.items():
            (f,) = facts_of(path, "CREATE TABLE t (a INT);", "schema_object")
            self.assertEqual(f.detail_dict()["dialect"], want, path)

    def test_columns_are_capped_and_counted(self):
        body = ", ".join(f"c{i} INT" for i in range(70))
        (f,) = facts_of("s.sql", f"CREATE TABLE wide ({body});", "schema_object")
        d = f.detail_dict()
        self.assertEqual((len(d["columns"]), d["column_count"]), (60, 70))
        self.assertEqual(d["columns"][0], "c0 INT")  # order kept

    def test_long_expression_is_truncated(self):
        cols = ", ".join(f"column_{i}" for i in range(40))
        (idx,) = [f for f in facts_of("s.sql", f"CREATE INDEX i ON t ({cols});", "schema_object")]
        self.assertEqual(len(idx.detail_dict()["expression"]), 120)

    def test_non_sql_file_is_not_read_as_ddl(self):
        self.assertEqual(facts_of("notes.txt", "CREATE TABLE t (a INT);", "schema_object"), [])


class OwnerFileTests(unittest.TestCase):
    def test_codeowners_entries_exclude_comments_and_blank_lines(self):
        doc, _ = sample_doc()
        (f,) = [f for f in doc["facts"] if f["kind"] == "owner_file" and f["path"] == "CODEOWNERS"]
        self.assertEqual((f["detail"]["entries"], f["detail"]["kind"]), (2, "codeowners"))

    def test_no_names_or_emails_are_recorded(self):
        doc, summary = sample_doc()
        blob = json.dumps(doc) + summary
        for needle in ("alice", "example.com", "@example-org", "platform"):
            self.assertNotIn(needle, blob)

    def test_contributing_counts_all_lines(self):
        doc, _ = sample_doc()
        (f,) = [f for f in doc["facts"] if f["kind"] == "owner_file" and f["path"] == "CONTRIBUTING.md"]
        self.assertEqual((f["detail"]["entries"], f["detail"]["kind"]), (4, "contributing"))

    def test_recognised_paths_and_kinds(self):
        cases = {"CODEOWNERS": "codeowners", ".github/CODEOWNERS": "codeowners", "docs/CODEOWNERS": "codeowners",
                 "MAINTAINERS": "maintainers", "MAINTAINERS.md": "maintainers", "OWNERS": "maintainers",
                 "CONTRIBUTING.md": "contributing", "GOVERNANCE.md": "governance"}
        for path, kind in cases.items():
            (f,) = facts_of(path, "# c\nx\n", "owner_file")
            self.assertEqual((f.name, f.detail_dict()["kind"]), (path, kind))
        for path in ("src/OWNERS", "a/CONTRIBUTING.md", "README.md"):
            self.assertEqual(facts_of(path, "x\n", "owner_file"), [], path)


class SummaryTests(unittest.TestCase):
    def test_sample_summary_sections(self):
        _, s = sample_doc()
        self.assertIn("## Schema objects", s)
        self.assertIn("| table | postgres | 2 |", s)
        self.assertIn("| index | postgres | 3 |", s)
        self.assertIn("`account_id, LOWER(title)`", s)
        self.assertIn("| `accounts` | postgres | 3 |", s)
        self.assertIn("## Ownership files", s)
        self.assertIn("| `CODEOWNERS` | codeowners | 2 |", s)
        self.assertIn("## UI pages", s)
        self.assertNotIn("## Finding candidates", s)  # no pattern-capable stack in the sample

    def test_summary_is_deterministic(self):
        self.assertEqual(sample_doc()[1], sample_doc()[1])

    def base(self, facts, stacks=()):
        return {"schema": "s", "target": {"name": "t", "commit": None, "history": "none"},
                "stacks": list(stacks), "facts": facts}

    def test_schema_rows_are_capped_with_n_of_m(self):
        facts = [{"kind": "schema_object", "stack": "generic", "path": "s.sql", "line": i, "name": f"i{i:03d}",
                  "detail": {"type": "index", "table": "t", "unique": False, "expression": "a", "dialect": None}}
                 for i in range(1, 51)]
        s = render_summary(self.base(facts))
        self.assertIn("40 of 50 shown", s)
        self.assertIn("`i040`", s)
        self.assertNotIn("`i041`", s)

    def test_finding_candidates_table(self):
        sm = lambda p, path, line, **d: {"kind": "smell", "stack": "python-flask", "path": path, "line": line,
                                         "name": p, "detail": {"pattern": p, **d}}
        facts = [sm("state-change-on-get", "b.py", 9), sm("state-change-on-get", "a.py", 3, fid="deadbeef"),
                 sm("state-change-on-get", "a.py", 40), sm("state-change-on-get", "a.py", 50),
                 sm("actuator-exposed", "p.properties", 1),
                 {**sm("actuator-exposed", "tests/t.py", 1), "detail": {"pattern": "actuator-exposed", "test": True}}]
        s = render_summary(self.base(facts, [{"name": "python-flask", "detail": {}}]))
        self.assertIn("| Pattern | Count | First locations | id |", s)
        row = [ln for ln in s.splitlines() if ln.startswith("| `state-change-on-get`")][0]
        self.assertIn("| 4 | `a.py:3`, `a.py:40`, `a.py:50` | `deadbeef`,", row)
        self.assertNotIn("b.py:9", row)
        self.assertIn("| `actuator-exposed` | 1 | `p.properties:1` |", s)

    def test_none_extracted_only_for_pattern_stacks(self):
        flask = self.base([], [{"name": "python-flask", "detail": {}}])
        self.assertIn("Finding candidates: none extracted", render_summary(flask))
        go = self.base([], [{"name": "go", "detail": {}}])
        self.assertNotIn("Finding candidates", render_summary(go))
        self.assertNotIn("Finding candidates", render_summary(self.base([])))


class ConfigRoleUnclassifiedTests(unittest.TestCase):
    def test_lone_config_file_is_unclassified(self):
        self.assertEqual(generic.config_role("custom/conf/ClientRes.properties"), "unclassified")
        self.assertEqual(generic.config_role("config/settings.yml"), "unclassified")

    def test_framework_names_are_app(self):
        self.assertEqual(generic.config_role("src/main/resources/application.properties"), "app")
        self.assertEqual(generic.config_role("src/main/resources/application-dev.yml"), "app")
        self.assertEqual(generic.config_role("src/Identity.API/appsettings.json"), "app")
        self.assertEqual(generic.config_role("web.config"), "app")
        self.assertEqual(generic.config_role(".env"), "app")
        self.assertEqual(generic.config_role(".env.local"), "app")

    def test_message_bundle_with_locale_sibling_is_none(self):
        sibs = {"ClientRes.properties", "ClientRes_en.properties", "ClientRes_de.properties"}
        self.assertEqual(generic.config_role("custom/ClientRes.properties", sibs), None)
        self.assertEqual(generic.config_role("custom/ClientRes_en.properties", sibs), None)

    def test_lone_properties_without_sibling_is_unclassified(self):
        self.assertEqual(generic.config_role("custom/ClientRes.properties", {"ClientRes.properties"}), "unclassified")

    def test_bundle_detection_ignores_different_base(self):
        sibs = {"ClientRes.properties", "Other_en.properties"}
        self.assertEqual(generic.config_role("custom/ClientRes.properties", sibs), "unclassified")

    def test_extract_passes_siblings(self):
        # a file with a locale sibling yields no config_key Facts (bundle)
        self.assertEqual(facts_of("custom/ClientRes.properties", "a=1\n", "config_key",
                                  {"ClientRes.properties", "ClientRes_en.properties"}), [])
        # a lone file yields config_key Facts with role unclassified
        keys = facts_of("custom/ClientRes.properties", "a=1\n", "config_key", {"ClientRes.properties"})
        self.assertEqual(len(keys), 1)
        self.assertEqual(keys[0].detail_dict()["role"], "unclassified")

    def test_unclassified_promoted_to_app_when_key_read_from_code(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        root = os.path.join(tmp.name, "target")
        os.makedirs(os.path.join(root, "custom"))
        with open(os.path.join(root, "requirements.txt"), "w") as fh:
            fh.write("flask\n")
        with open(os.path.join(root, "app.py"), "w") as fh:
            fh.write("import os\nPORT = os.environ.get('PORT')\n")
        with open(os.path.join(root, "custom", "ClientRes.properties"), "w") as fh:
            fh.write("PORT=8080\n")
        text, _ = extract.extract(root, os.path.join(tmp.name, "out"))
        doc = json.loads(text)
        roles = {f["name"]: f["detail"].get("role") for f in doc["facts"] if f["kind"] == "config_key"}
        self.assertEqual(roles.get("PORT"), "app")


class FilePromotionTests(unittest.TestCase):
    def _keys(self, files):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        root = os.path.join(tmp.name, "target")
        for rel, text in files.items():
            full = os.path.join(root, rel)
            os.makedirs(os.path.dirname(full), exist_ok=True)
            with open(full, "w") as fh:
                fh.write(text)
        out = os.path.join(tmp.name, "out")
        doc = json.loads(extract.extract(root, out)[0])
        self.assertEqual(doc, json.loads(extract.extract(root, out)[0]), "warm run differs from cold run")
        return {(f["path"], f["name"]): f["detail"] for f in doc["facts"] if f["kind"] == "config_key"}

    APP = ("from flask import Flask\nimport os\napp = Flask(__name__)\n"
           "a = app.config['HTTP_PORT']\nb = os.getenv('RUNNER')\n")

    def test_file_level_promotion(self):
        keys = self._keys({
            "requirements.txt": "flask\n", "app.py": self.APP,
            "conf/app.ini": "[server]\nHTTP_PORT = 3000\nDOMAIN = x\n[other]\nUNRELATED = 1\n",
            "conf/lone.ini": "[a]\nZED = 1\n",
            ".github/workflows/ci.yml": "env:\n  RUNNER: x\n"})
        self.assertEqual({d["role"] for (p, n), d in keys.items() if p == "conf/app.ini"}, {"app"})
        self.assertEqual(keys[("conf/lone.ini", "a.ZED")]["role"], "unclassified")
        self.assertEqual(keys[("app.py", "RUNNER")]["role"], "env")      # env keys are never promoted
        self.assertTrue(all(d["role"] == "ci" for (p, n), d in keys.items() if p.startswith(".github/")))

    def test_file_promotion_leaves_a_ci_file_alone(self):
        keys = self._keys({"requirements.txt": "flask\n", "app.py": self.APP,
                           ".github/workflows/ci.yml": "env:\n  HTTP_PORT: 1\n"})
        self.assertEqual({d["role"] for (p, n), d in keys.items() if p.startswith(".github/")}, {"ci"})

    def test_ini_section_key_variants(self):
        self.assertEqual(extract._key_variants("server.HTTP_PORT"), {"server.HTTP_PORT", "HTTP_PORT"})
        self.assertEqual(extract._key_variants("PORT"), {"PORT"})
        by_last = self._keys({"requirements.txt": "flask\n", "app.py": self.APP, "conf/a.ini": "[server]\nHTTP_PORT = 3\n"})
        self.assertEqual(by_last[("conf/a.ini", "server.HTTP_PORT")]["role"], "app")
        by_full = self._keys({"requirements.txt": "flask\n",
                              "app.py": "from flask import Flask\napp = Flask(__name__)\nx = app.config['server.HTTP_PORT']\n",
                              "conf/a.ini": "[server]\nHTTP_PORT = 3\nDOMAIN = d\n"})
        self.assertEqual({d["role"] for d in by_full.values() if d.get("source") != "code"}, {"app"})


class ConfigRoleSplitTests(unittest.TestCase):
    """T25.21/T25.22: code reads are split into env / ci / app in the post-pass."""

    def _keys(self, files):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        root = os.path.join(tmp.name, "target")
        for rel, text in files.items():
            full = os.path.join(root, rel)
            os.makedirs(os.path.dirname(full), exist_ok=True)
            with open(full, "w") as fh:
                fh.write(text)
        out = os.path.join(tmp.name, "out")
        doc = json.loads(extract.extract(root, out)[0])
        # a second, warm run must give the same answer (the cache stores pre-promotion Facts)
        self.assertEqual(doc, json.loads(extract.extract(root, out)[0]))
        return {(f["path"], f["name"]): f["detail"] for f in doc["facts"] if f["kind"] == "config_key"}

    def test_env_key_role_env(self):
        keys = self._keys({"requirements.txt": "flask\n",
                           "app.py": "import os\nfrom flask import Flask\napp = Flask(__name__)\n"
                                     "a = os.getenv('GO')\nb = app.config['DEBUG']\n"})
        self.assertEqual(keys[("app.py", "GO")]["role"], "env")
        self.assertEqual(keys[("app.py", "DEBUG")]["role"], "app")

    def test_ci_key_role_ci(self):
        keys = self._keys({"requirements.txt": "flask\n", "app.py": "x = 1\n",
                           ".github/workflows/ci.yml": "env:\n  BUILD_FLAG: 1\n"})
        ci = [d for (p, n), d in keys.items() if p.startswith(".github/")]
        self.assertTrue(ci)
        self.assertTrue(all(d["role"] == "ci" for d in ci))

    def test_env_key_not_secret(self):
        keys = self._keys({"requirements.txt": "flask\n",
                           "app.py": "import os\nfrom flask import Flask\napp = Flask(__name__)\n"
                                     "a = os.getenv('SSH_ORIGINAL_COMMAND')\nb = os.getenv('API_TOKEN')\n"
                                     "c = app.config['DB_PASSWORD']\n"})
        self.assertFalse(keys[("app.py", "API_TOKEN")]["secret_location"])
        self.assertTrue(keys[("app.py", "DB_PASSWORD")]["secret_location"])


    def test_unclassified_secret_key_keeps_flag(self):
        """An INI key no code reads stays `unclassified` and keeps its secret flag (never set on env or ci keys)."""
        keys = self._keys({"requirements.txt": "flask\n", "app.py": "x = 1\n",
                           "conf/db.ini": "[db]\nDB_PASSWORD = hunter2value\n"})
        d = keys[("conf/db.ini", "db.DB_PASSWORD")]
        self.assertEqual(d["role"], "unclassified")
        self.assertIs(d["secret_location"], True)


if __name__ == "__main__":
    unittest.main()
