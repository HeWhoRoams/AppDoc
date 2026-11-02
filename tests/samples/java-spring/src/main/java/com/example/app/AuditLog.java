package com.example.app;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

/**
 * AuditLog domain entity (JPA) under the Spring Initializr default `com.example`
 * package. This is the AppDoc golden's BUG B regression pin: before the scope
 * fix, any source dir whose path segment matched `sample|samples|example|examples`
 * was excluded from the api-inventory + data-model scans, so every @Entity and
 * @GetMapping under `com/example/...` was silently dropped. The presence of this
 * class (and its /audit-log endpoint) in the generated artifacts proves a
 * `com.example` path is scanned, not wiped.
 */
@Entity
@Table(name = "audit_logs")
public class AuditLog {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id")
    private long id;

    @Column(name = "action", nullable = false, length = 64)
    private String action = "created";

    @Column(name = "actor", length = 128)
    private String actor;

    @Column(name = "detail", length = 512)
    private String detail;

    public long getId() { return id; }
    public void setId(long id) { this.id = id; }

    public String getAction() { return action; }
    public void setAction(String action) { this.action = action; }

    public String getActor() { return actor; }
    public void setActor(String actor) { this.actor = actor; }

    public String getDetail() { return detail; }
    public void setDetail(String detail) { this.detail = detail; }
}
