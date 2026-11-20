"""Integration fixture for AppDoc's shared integration catalog.

Exercises the six non-DB system-connection types the catalog detects (cache, queue,
object_storage, grpc, ldap, search). Most endpoints are plain hosts; ``get_cache_cred``
embeds a ``user:pass@`` credential in its URL so the redaction tests can prove the driver
name is extracted while the credential value is redacted from ``facts.json``.
"""

import redis
import kafka
import boto3
import grpc
import ldap3
import elasticsearch


def get_cache():
    return redis.Redis.from_url("redis://cache.internal:6379/0")


def get_cache_cred():
    # A credential-bearing URL: the catalog must redact the ``user:pass@`` value so it
    # never appears in facts.json (only the driver name and a secret_location flag).
    return redis.Redis.from_url("redis://user:pass@r2.internal:6379")


def get_queue():
    return kafka.KafkaProducer(bootstrap_servers="kafka.internal:9092")


def get_storage():
    return boto3.client("s3", region_name="us-east-1")


def get_billing():
    return grpc.insecure_channel("billing.internal:9000")


def get_directory():
    return ldap3.Server("ldap://ad.internal", port=636, use_ssl=True)


def get_search():
    return elasticsearch.Elasticsearch(["http://search.internal:9200"])
