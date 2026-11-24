# ADR 0019: Effective protection is evaluated at the application layer, per build configuration

- **Status:** Accepted (2.8.0)
- **Decision area:** Facts (W1, W2, W4 `guard.py`, `urlauth.py`, `configs.py`); Generated blocks (`access-model`, template 5.4); Check (C22)
- **Builds on:** ADR 0016 (P1 to P6), ADR 0018
- **Rules:** R17, R20

## Context

Writers described access from the presence of an attribute or a configuration file: "the admin pages require a role", "anonymous users can reach this". Both were wrong in ways the code could show. An `<authorization>` rule decides a URL before the filter runs; a build-configuration transform changes the production value; an external attribute with no definition in the Target may allow or deny anything. A document that says "no guard" is an absence claim, and an absence claim is only true when every place the guard could live was read.

## Decision

1. **Effective values per build configuration (R17).** `configs.apply` gives each configuration (from transform file names, project `Condition` groups and the solution configurations) its own copy of every `security_setting` and `access_rule` of the project-root `Web.config`; a transform never overwrites the base Fact. A configuration with no transform is `config_status: base`. A value that depends on an operation or locator the engine cannot evaluate is `unknown_transform`, with value `unknown`, never the base value. The production configuration is `Release` unless `appdoc-context.md` declares `Production config: <name>`. Transforms run at publish or package time only, and only on the project-root `Web.config`; a nested `Web.config` gets none.
2. **Effective protection per handler (W4).** `guard.apply` is a post-pass over Facts and reads no source. For each handler of an `aspnet` Target it builds the URL set, evaluates URL authorization as a chain (`urlauth.evaluate`: nearest rule first, `<clear/>` and `<remove/>` applied, first match decides, the machine rule `allow *` last), ANDs the filters, and records the reach of three **archetype principals** (`anon`, `auth`, `role:<R>`). It labels the handler `no_app_restriction`, `signed_in_any`, `role_restricted`, `denied` or `unknown`, with `reasons` codes. `unknown` is never collapsed into `allow` or `none`.
3. **R20: an absence claim needs a closed world.** `unknown` (with a reason) is emitted when a base type is outside the Target, a hook such as `OnActionExecuting` is overridden, the method body checks the user, a filter provider is registered, a named user could be the caller, a configuration file is unparsed or external, or the URL set is open. An external attribute used three or more times and not declared in `appdoc-context.md` (`Auth attributes:`) is a `guard_candidate`; a handler stacked on an undeclared candidate is `unknown`, never `signed_in_any`.
4. **The disclosure line (W4).** The `access-model` block (5.4) begins with a fixed sentence: application-layer evaluation only; IIS authentication, server-level configuration, network exposure, group membership and effective permissions are not in the repository. It is part of the generated block, so C7 (generated blocks match what `fill` writes) fails a document that lacks it. SKILL.md tells the writer to say "application layer only" wherever access is described, and not to write "anonymous users can" without explicit anonymity in `reasons`.
5. **C22 (area and protection coverage).** Every non-root MVC area must be the folder of a 4.1 row, and every handler file that holds a `state_changing` handler, or one labelled `no_app_restriction`, `signed_in_any` or `unknown`, must be cited (the citation map is shared with C13: R5). Undeclared guard candidates are an advisory, and fail under `--strict`. A read-only, role-restricted handler file stays a C13 advisory (R8: no threshold heuristic).
6. **Scope: .NET only.** The work covers .NET Framework (`aspnet`, MVC 5 and Web API 2 conventions) and, for mechanism only, ASP.NET Core (`guard_mechanism`, no `reach`; `none` only when no authentication or authorization service token exists anywhere in the Target). The same failure class (an access matrix in configuration, an external guard, an environment-switched mode) exists in Spring and Express. Nothing here detects it, and the README says so.

## Residual risk

The `access-model` block is an attack-surface summary of the Target, so the document's distribution should follow the Target's own access rules.

Prose the writer puts in 5.1 and 5.2 has no rows to key, so it stays **outside the audit plan** (the plan keys rows, not paragraphs). That is an accepted risk, mitigated by C21 (every mandatory file is cited with a line) and C22 (every area and every unprotected or unknown handler file is cited). Those rules prove a file was cited, not that the sentence is right. Section 5.3, a table, is planned per row (`5.3/<slug>`). The new generated blocks (`access-model`, `connections`, `integrations`, `pipeline`, `repo-docs`) are opaque and unaudited: the Check masks them, A.1 lists them as not audited, and an audit row never certifies one. That also keeps `doc_sha` and sealed rows stable when a later release fills a block.

## Consequences

- **Positive:** the document can say, per configuration and per principal, what the application layer does, and it says when it cannot know. A handler with no restriction is a named list, not a feeling.
- **Negative:** with undeclared guard candidates present nearly every handler file is `unknown` and so mandatory under C22 until the owner declares the guards. Facts grow by one copy of each setting per configuration.
- **Rejected:** overwriting the base value with the transform's (a lie for every other configuration); evaluating IIS settings (not in the repository); a threshold heuristic for which read-only handlers must be cited.
