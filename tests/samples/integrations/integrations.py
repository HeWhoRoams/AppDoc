"""Integration fixture for AppDoc's shared integration catalog.

Exercises the six non-DB system-connection types the catalog detects (cache, queue,
object_storage, grpc, ldap, search). No secret value is present: every endpoint is a
plain host (no ``user:pass@`` credential, no ``Password=``/``Pwd=``), so the Facts carry
locations only.
"""

import redis
import kafka
import boto3
import grpc
import ldap3
import elasticsearch


def get_cache():
    return redis.Redis.from_url("redis://cache.internal:6379/0")


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
