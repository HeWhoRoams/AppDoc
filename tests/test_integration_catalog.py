"""Phase 6a: the shared integration catalog yields typed ``connection`` Facts.

``Fact.detail.type`` is widened with the non-DB integration vocabulary (cache, queue,
object_storage, grpc, ldap, search) — a convention change, not a schema change. Detection is
additive: the new Facts appear, existing Facts are unchanged.
"""
import json
import os
import tempfile
import unittest

from appdoc import extract
from appdoc.stacks import integrations

HERE = os.path.dirname(os.path.abspath(__file__))
SAMPLE = os.path.join(HERE, "samples", "integrations")


def _run():
    with tempfile.TemporaryDirectory() as out:
        text, _ = extract.extract(SAMPLE, out)
    return text, json.loads(text)


class IntegrationCatalogFacts(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.text, cls.doc = _run()
        cls.conn_by_type: dict[str, list[dict]] = {}
        for f in cls.doc["facts"]:
            if f["kind"] == "connection":
                cls.conn_by_type.setdefault(f["detail"].get("type"), []).append(f)

    def has(self, type_, name):
        for f in self.conn_by_type.get(type_, []):
            if f["name"] == name:
                return f
        self.fail(f"no connection fact type={type_} name={name} "
                  f"(types present: {sorted(self.conn_by_type)})")

    def test_redis_kafka_s3_yield_three_typed_facts(self):
        r = self.has("cache", "redis.from_url")
        q = self.has("queue", "kafka.KafkaProducer")
        s = self.has("object_storage", "boto3.s3")
        for f in (r, q, s):
            self.assertEqual(f["stack"], "python-flask")
            self.assertFalse(f["detail"].get("secret_location"))
            self.assertFalse(f["detail"].get("test"))

    def test_all_six_integration_types_detected(self):
        for t in ("cache", "queue", "object_storage", "grpc", "ldap", "search"):
            self.assertIn(t, self.conn_by_type, f"missing integration type {t}")

    def test_fixture_yields_no_secret_flag_or_value(self):
        self.assertNotIn("Password=", self.text)
        self.assertNotIn("Pwd=", self.text)
        self.assertNotIn("fakepass", self.text)
        self.assertNotIn("user:pass@", self.text)

    def test_embedded_credential_is_redacted(self):
        # get_cache_cred embeds a `user:pass@` credential in a redis URL. The catalog
        # extracts the driver (redis.from_url) but redacts the credential, so the
        # `user:pass@` marker never appears in facts.json. This is now non-tautological:
        # the credential really is in the source and must be stripped from the output.
        self.assertIn("redis.from_url", self.text)    # the driver name is present
        self.assertNotIn("user:pass@", self.text)      # the credential is NOT
        self.assertNotIn("secretpw", self.text)        # (guard: no leaked password value)

    def test_catalog_scan_is_pure_and_typed(self):
        text = ('import redis, kafka, boto3\n'
                'r = redis.Redis.from_url("redis://c.internal:6379")\n'
                'p = kafka.KafkaProducer()\n'
                's = boto3.client("s3")\n')
        facts = integrations.scan_facts("python", "python-flask", "m.py", text)
        self.assertEqual([f.kind for f in facts], ["connection"] * len(facts))
        got = sorted((f.detail_dict()["type"], f.name) for f in facts)
        self.assertEqual(got, [("cache", "redis.from_url"), ("object_storage", "boto3.s3"),
                               ("queue", "kafka.KafkaProducer")])

    def test_catalog_scans_other_languages(self):
        # One row per language to prove the catalog is shared, not python-only.
        self.assertEqual(
            sorted(f.detail_dict()["type"] for f in
                   integrations.scan_facts("dotnet", "aspnet-core", "c.cs",
                                           'var r = new ConnectionMultiplexer("x");')),
            ["cache"])
        self.assertEqual(
            sorted(f.detail_dict()["type"] for f in
                   integrations.scan_facts("java", "java-spring", "J.java",
                                           'var r = new JedisPool(poolConfig);')),
            ["cache"])
        self.assertEqual(
            sorted(f.detail_dict()["type"] for f in
                   integrations.scan_facts("node", "node-express", "j.js",
                                           'const r = require("ioredis");')),
            ["cache"])

    def test_byte_identical_two_runs(self):
        self.assertEqual(_run()[0], _run()[0])


if __name__ == "__main__":
    unittest.main()
