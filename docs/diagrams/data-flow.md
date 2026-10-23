# Data Flow Diagram

_Generated: 2026-10-22 10:29:37_

## What This View Explains

This view traces input sources, processing transformations, and output channels so teams can reason about data movement and side effects.

## Diagram

```mermaid
flowchart LR
    %% Solid edges: runtime request/data flow. Dashed edges: structural/config/dependency links.
    subgraph inputs["Input Boundary"]
        config_concurrency_cancel_in_4184c67a["concurrency.cancel-in-progress"]
        config_concurrency_group_4353a474["concurrency.group"]
        config_github_copilot_chat_ex_3233c7ea["github.copilot.chat.executions.enabled"]
        config_jobs_hygiene_name_a7867886["jobs.hygiene.name"]
        config_jobs_hygiene_runs_on_f616492a["jobs.hygiene.runs-on"]
        config_jobs_hygiene_steps_run_348a44cb["jobs.hygiene.steps.run"]
        config_jobs_hygiene_steps_she_e80f611f["jobs.hygiene.steps.shell"]
        config_jobs_hygiene_steps_0_81f99013["jobs.hygiene.steps(0)"]
        config_jobs_hygiene_steps_1_1f5e909e["jobs.hygiene.steps(1)"]
        config_jobs_hygiene_steps_2_93e42ea2["jobs.hygiene.steps(2)"]
        config_jobs_hygiene_steps_3_74378ec2["jobs.hygiene.steps(3)"]
        config_jobs_tests_name_93d08342["jobs.tests.name"]
    end
    subgraph processing["Core Transformations"]
        component_core_processing_6d28d771["Core Processing"]
    end
    class component_core_processing_6d28d771 component
    class config_concurrency_cancel_in_4184c67a config
    class config_concurrency_group_4353a474 config
    class config_github_copilot_chat_ex_3233c7ea config
    class config_jobs_hygiene_name_a7867886 config
    class config_jobs_hygiene_runs_on_f616492a config
    class config_jobs_hygiene_steps_run_348a44cb config
    class config_jobs_hygiene_steps_she_e80f611f config
    class config_jobs_hygiene_steps_0_81f99013 config
    class config_jobs_hygiene_steps_1_1f5e909e config
    class config_jobs_hygiene_steps_2_93e42ea2 config
    class config_jobs_hygiene_steps_3_74378ec2 config
    class config_jobs_tests_name_93d08342 config
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
- Coverage snapshot: 13 nodes, 0 edges, 0 inbound interfaces, 0 outbound integrations.

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

