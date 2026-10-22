# tickets-service (Spring Boot)

A small, deterministic Spring Boot REST fixture used by the AppDoc golden-file
regression test to prove the framework-agnostic pipeline generalizes to a
Java / Spring Boot target.

## Run

```bash
mvn spring-boot:run
```

The service listens on `:8080` and exposes `/api/tickets`.
