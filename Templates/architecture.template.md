
---

# 2) `architecture.template.md` (v2.0)

```markdown
# $ARGUMENTS — Architecture Overview

---
# METADATA
---
title: "Architecture"
app: "$ARGUMENTS"
template: "architecture.template.md"
version: "2.0"
generated_by: "AppDoc Agent"
generated_at: "$DATE_GENERATED"
sources_scanned: $SOURCES_SCANNED
---

## 1. Application Summary
- **Purpose:** $APP_DESCRIPTION_PURPOSE
- **Primary Functionality:** $APP_FEATURE_SUMMARY
- **Primary Audience / Consumers:** $APP_AUDIENCE
- **Core Technologies (detected):** $TECH_STACK_PRIMARY
- **Primary Entry Points / Binaries:** $CODE_ENTRYPOINT_LIST
- **Major Dependencies & Libraries:** $DEPENDENCY_LIST
- **Build / Run Environment:** $ENVIRONMENT_DETAILS

---

## 2. System Architecture

### 2.1 Layered Overview
| Layer | Purpose | Primary Modules | Key Dependencies |
|-------|---------|-----------------|------------------|
| Presentation | $LAYER_PRESENTATION_PURPOSE | $LAYER_PRESENTATION_MODULES | $LAYER_PRESENTATION_DEPENDENCIES |
| Business Logic | $LAYER_LOGIC_PURPOSE | $LAYER_LOGIC_MODULES | $LAYER_LOGIC_DEPENDENCIES |
| Data Access | $LAYER_DATA_PURPOSE | $LAYER_DATA_MODULES | $LAYER_DATA_DEPENDENCIES |
| Integration | $LAYER_INTEGRATION_PURPOSE | $LAYER_INTEGRATION_MODULES | $LAYER_INTEGRATION_DEPENDENCIES |

### 2.2 Internal Components & Responsibilities
For each major component discovered, replicate the block below:

- **Module Name:** $COMPONENT_NAME
- **Short Description:** $COMPONENT_PURPOSE
- **Key Classes / Files:** $COMPONENT_KEY_FUNCTIONS
- **Public Interfaces / APIs:** $COMPONENT_INTERFACES
- **Primary Dependencies:** $COMPONENT_DEPENDENCIES
- **Calls/Consumers:** $COMPONENT_CONSUMERS
- **Trace Evidence:** $COMPONENT_TRACE (e.g., `src/service/x.cs:123`)

(Repeat per component)

---

### 2.3 Data Flow & Communication
- **Inbound Sources:** $INBOUND_DATA_SOURCES
- **Outbound Destinations:** $OUTBOUND_DATA_TARGETS
- **Data Transformation Steps:** $DATA_TRANSFORMATION_LOGIC
- **Communication Patterns (sync/async):** $INTERNAL_COMMUNICATION_PATTERN
- **Protocols & Payload Formats:** $COMMUNICATION_PROTOCOLS

---

## 3. Integrations and External Systems
Populate a table of detected integrations:

| Integration Name | Type (DB/API/Queue) | Purpose | Config Placeholder | Notes / Where Used |
|------------------|----------------------|---------|--------------------|--------------------|
| $INTEGRATION_NAME | $INTEGRATION_TYPE | $INTEGRATION_PURPOSE | $INTEGRATION_CONFIG_PLACEHOLDER | $INTEGRATION_NOTES |

---

## 4. Configuration & Deployment
- **Config Files Found:** $CONFIG_FILES
- **Env Variables / Config Keys:** $ENV_VARIABLES
- **Secrets Management Approach:** $SECRETS_METHOD
- **Deployment Targets / Artifacts:** $DEPLOYMENT_ARTIFACTS
- **CI/CD Pipelines / Steps:** $CICD_PIPELINE_SUMMARY

---

## 5. Operational Concerns & Observations
- **Known Limitations:** $KNOWN_LIMITATIONS
- **Performance/Scaling Notes:** $PERF_SCALING_NOTES
- **Logging & Monitoring Hooks:** $LOG_MONITORING_NOTES
- **Security Observations:** $SECURITY_OBSERVATIONS

---

## 6. Gaps & Outstanding Placeholders
- $MISSING_DATA_NOTES (list placeholder names with brief description)
- For each item, create corresponding task(s) in `Documentation Tasks.md` using `$PLACEHOLDER` as the reference.

---

## 7. References
- Related docs: `logic-and-workflows.md`, `audit-report.md`, `Documentation Tasks.md`
- Source evidence listing (file paths or tests): $REFERENCE_FILES

*(end of architecture document)*
