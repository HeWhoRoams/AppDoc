# Internal Flow Diagram

_Generated: 2026-02-20 14:53:50_

## What This View Explains

This view shows how requests move from callers into core processing components and then to data models or external integrations.

## Diagram

```mermaid
flowchart LR
    subgraph actors["Actors"]
        actor_user_calling_system_16ed03d7["User / Calling System"]
    end
    subgraph processing["Application Processing"]
        component_core_processing_6d28d771["Core Processing"]
    end
    subgraph data["Models and Data"]
        config_jobs_syntax_gate_steps_b0ed346a["jobs.syntax-gate.steps.shell"]
        config_on_push_branches_1_81342622["on.push.branches[1]"]
        config_jobs_syntax_gate_steps_fea78b6a["jobs.syntax-gate.steps[2]"]
        config_jobs_syntax_gate_steps_c21bece1["jobs.syntax-gate.steps[0]"]
        config_jobs_syntax_gate_steps_f955e977["jobs.syntax-gate.steps[1]"]
        config_outputtype_6b096b77["OutputType"]
        config_targetframework_e88a9e43["TargetFramework"]
        config_github_copilot_chat_ex_3233c7ea["github.copilot.chat.executions.enabled"]
        config_on_push_branches_0_2a450bbd["on.push.branches[0]"]
        config_name_6ae99955["name"]
        config_jobs_syntax_gate_runs_1cc1bd48["jobs.syntax-gate.runs-on"]
    end
    subgraph dependencies["Supporting Dependencies"]
        dependency_system_data_sqlclient_e3d7e359["System.Data.SqlClient"]
        dependency_microsoft_codeanalysis_fd218333["Microsoft.CodeAnalysis.CSharp"]
        dependency_newtonsoft_json_9312eef4["Newtonsoft.Json"]
        dependency_microsoft_aspnetcore_m_5b325717["Microsoft.AspNetCore.Mvc"]
        dependency_system_net_http_78413594["System.Net.Http"]
        dependency_sampleapp_common_73198f78["SampleApp.Common"]
        dependency_rabbitmq_client_db152832["RabbitMQ.Client"]
        dependency_entityframework_3a81b759["EntityFramework"]
        dependency_microsoft_extensions_h_ebeb2ae5["Microsoft.Extensions.Hosting.WindowsServices"]
    end
    component_core_processing_6d28d771 -->|uses| dependency_entityframework_3a81b759
    component_core_processing_6d28d771 -->|uses| dependency_microsoft_aspnetcore_m_5b325717
    component_core_processing_6d28d771 -->|uses| dependency_microsoft_codeanalysis_fd218333
    component_core_processing_6d28d771 -->|uses| dependency_microsoft_extensions_h_ebeb2ae5
    component_core_processing_6d28d771 -->|uses| dependency_newtonsoft_json_9312eef4
    component_core_processing_6d28d771 -->|uses| dependency_rabbitmq_client_db152832
    component_core_processing_6d28d771 -->|uses| dependency_sampleapp_common_73198f78
    component_core_processing_6d28d771 -->|uses| dependency_system_data_sqlclient_e3d7e359
    component_core_processing_6d28d771 -->|uses| dependency_system_net_http_78413594
    config_github_copilot_chat_ex_3233c7ea -->|configures| component_core_processing_6d28d771
    config_jobs_syntax_gate_runs_1cc1bd48 -->|configures| component_core_processing_6d28d771
    config_jobs_syntax_gate_steps_b0ed346a -->|configures| component_core_processing_6d28d771
    config_jobs_syntax_gate_steps_c21bece1 -->|configures| component_core_processing_6d28d771
    config_jobs_syntax_gate_steps_f955e977 -->|configures| component_core_processing_6d28d771
    config_jobs_syntax_gate_steps_fea78b6a -->|configures| component_core_processing_6d28d771
    config_name_6ae99955 -->|configures| component_core_processing_6d28d771
    config_on_push_branches_0_2a450bbd -->|configures| component_core_processing_6d28d771
    config_on_push_branches_1_81342622 -->|configures| component_core_processing_6d28d771
    config_outputtype_6b096b77 -->|configures| component_core_processing_6d28d771
    config_targetframework_e88a9e43 -->|configures| component_core_processing_6d28d771
    class dependency_system_data_sqlclient_e3d7e359 dependency
    class dependency_microsoft_codeanalysis_fd218333 dependency
    class dependency_newtonsoft_json_9312eef4 dependency
    class config_jobs_syntax_gate_steps_b0ed346a config
    class config_on_push_branches_1_81342622 config
    class config_jobs_syntax_gate_steps_fea78b6a config
    class dependency_microsoft_aspnetcore_m_5b325717 dependency
    class config_jobs_syntax_gate_steps_c21bece1 config
    class dependency_system_net_http_78413594 dependency
    class dependency_sampleapp_common_73198f78 dependency
    class component_core_processing_6d28d771 component
    class dependency_rabbitmq_client_db152832 dependency
    class dependency_entityframework_3a81b759 dependency
    class config_jobs_syntax_gate_steps_f955e977 config
    class config_outputtype_6b096b77 config
    class dependency_microsoft_extensions_h_ebeb2ae5 dependency
    class config_targetframework_e88a9e43 config
    class config_github_copilot_chat_ex_3233c7ea config
    class config_on_push_branches_0_2a450bbd config
    class config_name_6ae99955 config
    class actor_user_calling_system_16ed03d7 actor
    class config_jobs_syntax_gate_runs_1cc1bd48 config
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
- Coverage snapshot: 22 nodes, 20 edges, 0 inbound interfaces, 0 outbound integrations.

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

