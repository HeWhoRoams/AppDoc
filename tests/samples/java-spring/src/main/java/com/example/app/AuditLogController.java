package com.example.app;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Minimal REST controller under the Spring Initializr default `com.example`
 * package. AppDoc golden BUG B regression pin: before the scope fix, any source
 * dir whose path segment matched `sample|samples|example|examples` was excluded
 * from the api-inventory scan, so the /audit-log route (and its sibling @Entity)
 * were silently dropped. The presence of /audit-log in the api-inventory proves
 * a `com.example` path is scanned, not wiped.
 */
@RestController
public class AuditLogController {

    // GET /audit-log — a read-only endpoint served from the com.example package.
    @GetMapping("/audit-log")
    public String auditLog() {
        return "audit-log";
    }
}
