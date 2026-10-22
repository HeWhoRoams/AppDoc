# Data Lineage (Core)

_Generated: 2026-10-17 18:41:01_

## What This View Explains

This partitioned data-lineage view isolates a subset of data nodes to keep lineage review readable while preserving deterministic topology.

## Diagram

```mermaid
flowchart LR
    %% Solid edges: runtime request/data flow. Dashed edges: structural/config/dependency links.
    subgraph inputs["Input Boundary"]
        config_github_copilot_chat_ex_3233c7ea["github.copilot.chat.executions.enabled"]
        config_itsm_base_url_386a0b40["itsm.base-url"]
        config_jobs_golden_test_cshar_a550e61a["jobs.golden-test-csharp-core.name"]
        config_jobs_golden_test_cshar_56738826["jobs.golden-test-csharp-core.runs-on"]
        config_jobs_golden_test_cshar_86c8eb3e["jobs.golden-test-csharp-core.steps.shell"]
        config_jobs_golden_test_cshar_7ca31392["jobs.golden-test-csharp-core.steps.uses"]
        config_jobs_golden_test_cshar_8a0b4f2d["jobs.golden-test-csharp-core.steps(0)"]
        config_jobs_golden_test_cshar_3e4d8917["jobs.golden-test-csharp-core.steps(1)"]
        config_jobs_golden_test_cshar_e6aa6fbd["jobs.golden-test-csharp-core.steps(2)"]
        config_jobs_golden_test_cshar_b2b231cf["jobs.golden-test-csharp-core.steps(3)"]
        config_jobs_golden_test_cshar_3b25b092["jobs.golden-test-csharp.name"]
        config_jobs_golden_test_cshar_b895bb4e["jobs.golden-test-csharp.runs-on"]
    end
    subgraph processing["Core Transformations"]
        component_core_processing_6d28d771["Core Processing"]
    end
    config_itsm_base_url_386a0b40 -.->|configures| component_core_processing_6d28d771
    class component_core_processing_6d28d771 component
    class config_github_copilot_chat_ex_3233c7ea config
    class config_itsm_base_url_386a0b40 config
    class config_jobs_golden_test_cshar_a550e61a config
    class config_jobs_golden_test_cshar_56738826 config
    class config_jobs_golden_test_cshar_86c8eb3e config
    class config_jobs_golden_test_cshar_7ca31392 config
    class config_jobs_golden_test_cshar_8a0b4f2d config
    class config_jobs_golden_test_cshar_3e4d8917 config
    class config_jobs_golden_test_cshar_e6aa6fbd config
    class config_jobs_golden_test_cshar_b2b231cf config
    class config_jobs_golden_test_cshar_3b25b092 config
    class config_jobs_golden_test_cshar_b895bb4e config
classDef actor fill:#0f172a,stroke:#0f172a,color:#ffffff,stroke-width:1px
classDef inbound fill:#dcfce7,stroke:#166534,color:#166534,stroke-width:1px
classDef outbound fill:#ffedd5,stroke:#9a3412,color:#9a3412,stroke-width:1px
classDef component fill:#dbeafe,stroke:#1d4ed8,color:#1d4ed8,stroke-width:1px
classDef data fill:#fef9c3,stroke:#854d0e,color:#854d0e,stroke-width:1px
classDef config fill:#f5f3ff,stroke:#5b21b6,color:#5b21b6,stroke-width:1px
classDef external fill:#fee2e2,stroke:#991b1b,color:#991b1b,stroke-width:1px
classDef dependency fill:#ede9fe,stroke:#4338ca,color:#4338ca,stroke-width:1px
```

## Reading Notes

- Solid arrows represent deterministic code-evidenced relationships.
- Nodes are filtered and ordered for readability; full detail remains in evidence artifacts.
- Coverage snapshot: 13 nodes, 1 edges, 0 inbound interfaces, 0 outbound integrations.

## Evidence Refs

- cfg-0001
- cfg-0002
- cfg-0003
- cfg-0004
- cfg-0005
- cfg-0006
- cfg-0007
- cfg-0008
- cfg-0009
- cfg-0010
- cfg-0011
- cfg-0012

