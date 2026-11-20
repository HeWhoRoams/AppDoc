"""Shared integration catalog: non-DB system connections, detected once, per language.

This is the single source of truth for the **additive** (content) detection of the non-database
integration types that the per-stack extractors previously missed (see docs/performance-plan.md,
section 13, Phase 6a):

    cache, queue, object_storage, grpc, ldap, search

Each catalog row is ``type -> {language: [(compiled_regex, name_template)]}``. Every match yields
a ``connection`` Fact whose ``name`` is the driver/target identifier (a code identifier, never a
secret value) and whose ``detail.type`` is the integration type. This is a **convention** change:
``Fact.detail`` is free-form, so ``KINDS`` and ``SCHEMA`` in :mod:`appdoc.facts` are untouched.

Database connections and the per-call outbound ``external_call`` types (http/email/process/file)
are produced by the individual Stacks; this catalog only adds the missing *system-connection*
vocabulary on top. Detection is additive: the new Facts appear, existing Facts are unchanged.

Standard library only. Deterministic: the emitted Facts are a pure function of the (comment-
stripped) text, and the canonical Facts serialization sorts + de-duplicates them.
"""

from __future__ import annotations

import re
from typing import Iterable

from ..facts import Fact
from ..secrets import find_secret_shapes
from .base import line_of

# The integration types this catalog detects (the widened connection.type vocabulary).
INTEGRATION_TYPES = ("cache", "queue", "object_storage", "grpc", "ldap", "search")

# A credential-bearing URL (scheme://user:pass@...) in the call arguments -> flag secret_location.
_CRED_URL = re.compile(r"://[^/\s\"']+:[^/\s\"']@")


def _probe_secret(text: str, end: int) -> bool:
    """Light secret-location probe on the bounded argument window after a match (never records the value)."""
    seg = text[end:end + 200].split("\n", 1)[0]
    if _CRED_URL.search(seg):
        return True
    return bool(find_secret_shapes(seg))


def _name(m, template: str | None) -> str:
    if template is None:
        return m.group(0).rstrip("(").strip()
    gd = m.groupdict()
    try:
        return template.format(**gd)
    except (IndexError, KeyError):
        return m.group(0).rstrip("(").strip()


def scan_facts(language: str, stack_id: str, path: str, text: str) -> list[Fact]:
    """Yield ``connection`` Facts for catalog integrations present in ``text`` (comment-stripped).

    ``text`` must be comment-stripped so matches in comments are not reported. The result is a
    pure function of ``(language, stack_id, path, text)``; order here is canonical but the Facts
    are re-sorted and de-duplicated by the Facts serializer.
    """
    out: list[Fact] = []
    for type_ in INTEGRATION_TYPES:
        for rx, template in CATALOG.get(type_, {}).get(language, ()):
            for m in rx.finditer(text):
                name = _name(m, template)[:120]
                out.append(Fact.make("connection", stack_id, path, line_of(text, m.start()), name,
                                     type=type_, secret_location=_probe_secret(text, m.end())))
    return out


# ---------------------------------------------------------------- catalog
# (regex, name_template) per integration type per language. Call/require-based to stay specific.

CATALOG: dict[str, dict[str, list[tuple[re.Pattern, str | None]]]] = {
    "cache": {
        "python": [
            (re.compile(r"(?<![\w.])(?P<drv>redis|aioredis)\.(?:Redis\.)?(?P<obj>Redis|StrictRedis|from_url|ConnectionPool|Connection)\s*\("),
             "{drv}.{obj}"),
        ],
        "java": [
            (re.compile(r"\b(?:new\s+)?(?P<obj>Jedis|JedisPool|JedisPooled|ShardedJedisPool|ShardedJedis|LettuceConnectionFactory|JedisConnectionFactory|RedisTemplate)\s*\("),
             "{obj}"),
        ],
        "dotnet": [
            (re.compile(r"\bnew\s+(?P<obj>ConnectionMultiplexer)\s*\("), "{obj}"),
        ],
        "node": [
            (re.compile(r"\bnew\s+(?P<obj>Redis)\s*\("), "{obj}"),
            (re.compile(r"require\(\s*['\"](?P<obj>redis|ioredis)['\"]\s*\)"), "{obj}"),
        ],
    },
    "queue": {
        "python": [
            (re.compile(r"(?<![\w.])(?P<drv>pika)\.(?P<obj>BlockingConnection|Connection|select_connection|Channel)\s*\("),
             "{drv}.{obj}"),
            (re.compile(r"(?<![\w.])(?P<drv>confluent_kafka|kafka)\.(?P<obj>Producer|Consumer|KafkaProducer|KafkaConsumer)\s*\("),
             "{drv}.{obj}"),
            (re.compile(r"(?<![\w.])(?P<obj>KafkaProducer|KafkaConsumer)\s*\("), "{obj}"),
            (re.compile(r"(?<![\w.])boto3\.(?:client|resource)\(\s*['\"](?P<svc>sqs)['\"]"), "boto3.{svc}"),
            (re.compile(r"(?<![\w.])(?P<drv>kombu)\.Connection\s*\("), "{drv}.Connection"),
        ],
        "java": [
            (re.compile(r"\b(?:new\s+)?(?P<obj>KafkaTemplate|RabbitTemplate|DefaultKafkaProducerFactory|DefaultKafkaConsumerFactory|JmsTemplate)\s*\("),
             "{obj}"),
        ],
        "dotnet": [
            (re.compile(r"\bnew\s+(?P<obj>ConnectionFactory|ProducerBuilder|ConsumerBuilder)\s*\("), "{obj}"),
            (re.compile(r"\bBusBuilder\b|\bConfigureBus\b|\bAddMassTransit\b"), "MassTransit"),
        ],
        "node": [
            (re.compile(r"\bnew\s+(?P<obj>Kafka|SQS|EventBridge)\s*\("), "{obj}"),
            (re.compile(r"require\(\s*['\"](?P<obj>kafkajs|amqplib)['\"]\s*\)"), "{obj}"),
        ],
    },
    "object_storage": {
        "python": [
            (re.compile(r"(?<![\w.])boto3\.(?:client|resource)\(\s*['\"](?P<svc>s3)['\"]"), "boto3.{svc}"),
            (re.compile(r"(?<![\w.])(?P<obj>azure\.storage\.[\w.]+?)\s*\("), "{obj}"),
            (re.compile(r"(?<![\w.])(?P<obj>google\.cloud\.storage\.[\w.]+?)\s*\("), "{obj}"),
            (re.compile(r"(?<![\w.])(?P<drv>storage)\.Client\s*\("), "{drv}.Client"),
        ],
        "java": [
            (re.compile(r"\b(?:new\s+)?(?P<obj>AmazonS3|AmazonS3Client|S3Client|BlobServiceClient|BlobClient)\s*\("),
             "{obj}"),
        ],
        "dotnet": [
            (re.compile(r"\bnew\s+(?P<obj>BlobServiceClient|CloudBlobClient|AmazonS3Client|AmazonS3)\s*\("), "{obj}"),
        ],
        "node": [
            (re.compile(r"\bnew\s+(?P<obj>S3|BlobServiceClient)\s*\("), "{obj}"),
            (re.compile(r"require\(\s*['\"](?P<obj>aws-sdk|@azure/storage-blob)['\"]\s*\)"), "{obj}"),
        ],
    },
    "grpc": {
        "python": [
            (re.compile(r"(?<![\w.])(?P<drv>grpc)\.(?P<obj>insecure_channel|secure_channel|insecure_channel_async|secure_channel_async|Channel|Server|insecure_subchannel|secure_subchannel)\s*\("),
             "{drv}.{obj}"),
        ],
        "java": [
            (re.compile(r"\b(?P<obj>ManagedChannelBuilder|NettyChannelBuilder)\.forAddress\b"), "{obj}"),
        ],
        "dotnet": [
            (re.compile(r"\bGrpcChannel\b"), "GrpcChannel"),
            (re.compile(r"\bChannel\.Create(?:Insecure|Secure|FromTarget)\b"), "gRPC channel"),
        ],
        "node": [
            (re.compile(r"require\(\s*['\"](?P<obj>@grpc/grpc-js|@grpc/grpc-node)['\"]\s*\)"), "{obj}"),
            (re.compile(r"\bgrpc\.loadPackageDefinition\b"), "grpc"),
        ],
    },
    "ldap": {
        "python": [
            (re.compile(r"(?<![\w.])(?P<drv>ldap3)\.(?P<obj>Server|Connection|Tls)\s*\("), "{drv}.{obj}"),
            (re.compile(r"(?<![\w.])(?P<drv>ldap)\.initialize\s*\("), "{drv}.initialize"),
        ],
        "java": [
            (re.compile(r"\bnew\s+(?P<obj>InitialDirContext|LdapTemplate|DirContext|DirContextAuthenticator)\s*\("), "{obj}"),
        ],
        "dotnet": [
            (re.compile(r"\bnew\s+(?P<obj>DirectoryEntry|DirectorySearcher|PrincipalContext)\s*\("), "{obj}"),
        ],
        "node": [
            (re.compile(r"require\(\s*['\"](?P<obj>ldapjs|ldapts)['\"]\s*\)"), "{obj}"),
        ],
    },
    "search": {
        "python": [
            (re.compile(r"(?<![\w.])(?P<drv>elasticsearch|opensearchpy)\.(?P<obj>Elasticsearch|OpenSearch|ElasticsearchTransport)\s*\("),
             "{drv}.{obj}"),
        ],
        "java": [
            (re.compile(r"\b(?:new\s+)?(?P<obj>ElasticsearchClient|RestHighLevelClient|OpenSearchClient|SearchClient)\s*\("),
             "{obj}"),
        ],
        "dotnet": [
            (re.compile(r"\bnew\s+(?P<obj>ElasticClient|OpenSearchClient)\s*\("), "{obj}"),
        ],
        "node": [
            (re.compile(r"require\(\s*['\"](?P<obj>@elastic/elasticsearch|@opensearch-project/opensearch-js)['\"]\s*\)"),
             "{obj}"),
        ],
    },
}
