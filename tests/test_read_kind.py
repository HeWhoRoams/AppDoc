"""T25.20: every stack's code config read says whether it reads an environment variable or a file."""
import unittest

from appdoc import facts as F
from appdoc.stacks import aspnet_core, go, java_spring, node_express, python_flask


def reads(stack, path, text):
    return {f.name: f.detail_dict().get("read_kind") for f in stack.STACK.extract(path, text)
            if f.kind == "config_key" and f.detail_dict().get("source") == "code"}


class ReadKindTests(unittest.TestCase):
    def test_read_kind_is_an_allowed_detail_key(self):
        self.assertIn("read_kind", F.DETAIL_KEYS["config_key"])

    def test_python_flask_read_kind(self):
        src = ("import os\nfrom flask import Flask\napp = Flask(__name__)\n"
               "a = os.getenv('E1')\nb = os.environ.get('E2')\nc = os.environ['E3']\n"
               "d = app.config['F1']\n")
        self.assertEqual(reads(python_flask, "app.py", src),
                         {"E1": "env", "E2": "env", "E3": "env", "F1": "file"})

    def test_go_read_kind(self):
        src = ('package main\nimport "os"\nfunc f() {\n a := os.Getenv("E1")\n b, _ := os.LookupEnv("E2")\n'
               ' c := viper.GetString("V1")\n}\n')
        self.assertEqual(reads(go, "main.go", src), {"E1": "env", "E2": "env", "V1": "file"})

    def test_node_read_kind(self):
        src = "const a = process.env.E1;\nconst b = process.env['E2'];\nconst {E3} = process.env;\n"
        self.assertEqual(reads(node_express, "app.js", src), {"E1": "env", "E2": "env", "E3": "env"})

    def test_aspnet_core_read_kind(self):
        src = ('class C { void M() {\n var a = Environment.GetEnvironmentVariable("E1");\n'
               ' var b = _configuration["F1"];\n var c = _configuration.GetValue<int>("F2");\n } }\n')
        self.assertEqual(reads(aspnet_core, "C.cs", src), {"E1": "env", "F1": "file", "F2": "file"})

    def test_java_read_kind(self):
        src = ('class C {\n  @Value("${f.one}") String a;\n  void m() {\n'
               '    String b = System.getenv("E1");\n    String c = env.getProperty("f.two");\n  }\n}\n')
        got = reads(java_spring, "src/C.java", src)
        self.assertEqual(got.get("f.one"), "file")
        self.assertEqual(got.get("E1"), "env")
        self.assertEqual(got.get("f.two"), "file")


if __name__ == "__main__":
    unittest.main()
