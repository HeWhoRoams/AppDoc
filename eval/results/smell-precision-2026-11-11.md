# Smell (finding-candidate) precision, 2026-11-11

Command: `python eval/smell_precision.py <target>`. Every hit was read in its source and labeled by hand.
Test-file hits are carried as `test: true` Facts and are excluded from check rule C12, so they are listed apart and not counted.

| Pattern | Target | Hits (non-test) | True positives | Notes |
|---|---|---|---|---|
| logger-type-mismatch | eShop | 2 | 2 | `Webhooks.API/IntegrationEvents/OrderStatusChangedToPaidIntegrationEventHandler.cs:6` (logger typed for the Shipped handler); `Webhooks.API/Services/GrantUrlTesterService.cs:3` (logger typed for the interface, low severity). Test-file hit: `OrdersWebApiTest.cs:14` (mock logger, not a finding). |
| flash-without-redirect | spring-petclinic | 2 | 2 | `OwnerController.java:80` and `:157` (flash set, then the form view is returned). |
| distinct-auth-errors | flaskr-tdd | 1 | 1 | `project/app.py:81`. Test-file hit: `tests/app_test.py:62` (asserts the same messages). |
| unescaped-template-output | flaskr-tdd | 2 | 2 | `index.html:74`, `search.html:55` (`entry.text` with the `safe` filter). |
| state-change-on-get | flaskr-tdd | 1 | 1 | `project/app.py:99` (`GET /delete/<int:post_id>` runs `.delete()`). |
| actuator-exposed | spring-petclinic | 1 | 1 | `application.properties:21`. |
| hardcoded-credential-constant | flaskr-tdd | 2 | 2 | `PASSWORD` (`app.py:24`), `SECRET_KEY` (`app.py:25`). |
| all patterns | gitea | 0 | 0 | Go/JS/TS only: no pattern applies. |
| all patterns | helpweb | 0 | 0 | No `ILogger<T>` mismatch, `[HttpGet]` state change, `Html.Raw`, or credential constant found by an independent grep. |

Overall: 11 of 11 non-test hits are true positives (100%). Counting the 2 test-file hits as false positives: 11 of 13 (85%).
No pattern exceeded 20 hits on any Target and none was dropped.

## Tightening applied during the run

- `hardcoded-credential-constant`: the name must END in a credential word (`Password`, `Secret`, `Token`, `ApiKey`, `SECRET_KEY`), so `TOKEN_URL` and `PASSWORD_FIELD` are not reported; values that are URLs, `${...}` references, empty, or look like a key name (`csrf_token`, `X-Auth-Token`) are skipped.
- `flash-without-redirect`: the check is on the first `return` after each `addFlashAttribute(` in the same method, and `return CONSTANT;` counts as a view name (the petclinic hits return `VIEWS_OWNER_CREATE_OR_UPDATE_FORM`, not a literal).
- `distinct-auth-errors`: a literal that also contains "password" (`Invalid username or password`) is not an "unknown user" message.
- `state-change-on-get` (ASP.NET): `.Add(`/`.Remove(` count only on a `*Context`/`Db*` member chain or with `SaveChanges`/`ExecuteSql`, not on lists.

## Performance

Smell extraction over all of gitea (6,437 files): 0.17 s. Over helpweb (6,787 files): 0.36 s.
