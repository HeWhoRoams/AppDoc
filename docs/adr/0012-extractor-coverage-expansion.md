# ADR 0012: Extractor coverage expansion (2.5.0)

- **Status:** Accepted (2026-11-23)
- **Decision area:** Facts; Stacks

## Context

The 2.4 examples under-reported what a reader can see in the code: Razor components were not
`ui_page`, Entity Framework sets and queries were not `data_access`, `HttpClient` calls were not
`external_call`, Go had no `connection`, `schema_object` or template pages, and Flask's
`SQLAlchemy(app)` was not a `connection`.

## Decision

1. Add these detections as ordinary Stack emissions, each declared in the Stack's capabilities and
   in `facts.DETAIL_KEYS`, and each exercised by a sample so the conformance test fails if a claim
   is not backed by output:
   `aspnet_core` Razor `ui_page`, EF `data_access type=ef`, `HttpClient` `external_call`;
   `go` `connection`, xorm `schema_object`, shallow `templates/**/*.html` `ui_page`;
   `python-flask` `SQLAlchemy(...)` `connection`.
2. EF query Facts are one per source line, so a line with several query calls is one Fact.
3. Go reads `.html` files only under a `templates` directory.
4. The change bumps `facts.SCHEMA` to `appdoc-facts/6` and `EXTRACTOR_VERSION` to 2 (the constant was replaced by the bundle hash in 2.6.0).

## Consequences

- Facts counts rise for Targets that use these libraries; the four examples are regenerated.
- Detection stays name-based; it does not follow data flow.
