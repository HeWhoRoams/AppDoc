# Facts summary

- Target: `eShop`
- Commit: `913acea66708a59595351174cee9b29f37179d29`
- Git history: shallow
- Schema: `appdoc-facts/5`

> Facts show what the extractors found. An empty list is not proof that something is absent: the extractors only recognise the patterns of the Stacks below, so read the source before writing "none". Facts from test code are marked `test` in `facts.json` and left out of the lists.

## Stacks

| Stack | Supported | Files read | Marker files |
|---|---|---|---|
| node | no (generic only) | 1 | `package.json` |
| aspnet-core | yes | 630 | `src/Basket.API/Basket.API.csproj`, `src/Basket.API/Program.cs`, `src/Catalog.API/Catalog.API.csproj`, `src/Catalog.API/Program.cs`, `src/ClientApp/ClientApp.csproj` |

## Counts

| Kind | Count |
|---|---|
| auth_check | 15 |
| config_key | 258 |
| connection | 15 |
| data_access | 9 |
| dependency | 117 |
| entry_point | 97 |
| external_call | 7 |
| file | 1163 |
| message | 9 |
| owner_file | 1 |
| smell | 3 |
| ui_page | 13 |

| Stack | Facts |
|---|---|
| aspnet-core | 200 |
| generic | 1507 |

## Scan coverage

Files found: 1163 = scanned 1163 + pruned 0 + ignored by `.appdocignore` 0.

No folders were pruned.

## Config files

| Application config file | Keys |
|---|---|
| `src/Identity.API/Configuration/Config.cs` | 14 |
| `src/Webhooks.API/appsettings.json` | 14 |
| `src/Ordering.API/appsettings.json` | 12 |
| `src/Catalog.API/appsettings.json` | 8 |
| `src/Identity.API/appsettings.json` | 6 |
| `src/eShop.ServiceDefaults/OpenApi.Extensions.cs` | 6 |
| `src/Basket.API/appsettings.json` | 5 |
| `src/OrderProcessor/appsettings.json` | 5 |
| `src/WebApp/Extensions/Extensions.cs` | 5 |
| `src/WebApp/appsettings.json` | 5 |
| `src/PaymentProcessor/appsettings.Development.json` | 4 |
| `src/PaymentProcessor/appsettings.json` | 4 |
| `src/WebhookClient/Extensions/Extensions.cs` | 4 |
| `src/WebhookClient/appsettings.json` | 4 |
| `src/OrderProcessor/appsettings.Development.json` | 3 |
| `src/Webhooks.API/appsettings.Development.json` | 3 |
| `src/eShop.AppHost/appsettings.json` | 3 |
| `src/eShop.ServiceDefaults/AuthenticationExtensions.cs` | 3 |
| `src/eShop.ServiceDefaults/OpenApiOptionsExtensions.cs` | 3 |
| `src/WebApp/appsettings.Development.json` | 2 |
| `src/WebhookClient/Endpoints/WebhookEndpoints.cs` | 2 |
| `src/WebhookClient/appsettings.Development.json` | 2 |
| `.aspire/settings.json` | 1 |
| `src/Catalog.API/Extensions/Extensions.cs` | 1 |
| `src/eShop.AppHost/Extensions.cs` | 1 |
| … 1 more files | |

- build: 2 files, 20 keys (not application settings)
- ci: 7 files, 91 keys (not application settings)

## Top folders by file count

| Folder | Files | Entry points | Data access | External calls |
|---|---|---|---|---|
| `src` | 990 | 97 | 9 | 5 |
| `tests` | 61 | 0 | 0 | 2 |
| `.github` | 54 | 0 | 0 | 0 |
| `(root)` | 23 | 0 | 0 | 0 |
| `docs` | 18 | 0 | 0 | 0 |
| `e2e` | 5 | 0 | 0 | 0 |
| `.config` | 4 | 0 | 0 | 0 |
| `img` | 3 | 0 | 0 | 0 |
| `build` | 2 | 0 | 0 | 0 |
| `.aspire` | 1 | 0 | 0 | 0 |
| `.devcenter` | 1 | 0 | 0 | 0 |
| `.vscode` | 1 | 0 | 0 | 0 |

## Largest source files

| File | Lines |
|---|---|
| `docs/appdoc-2.3/facts.json` | 23741 |
| `docs/appdoc-2.2/facts.json` | 22042 |
| `docs/appdoc/facts.json` | 21711 |
| `src/Identity.API/wwwroot/fonts/Oswald-Medium.svg` | 3232 |
| `src/Identity.API/wwwroot/fonts/Oswald-SemiBold.svg` | 3197 |
| `src/Identity.API/wwwroot/fonts/Oswald-Bold.svg` | 3184 |
| `src/Identity.API/wwwroot/fonts/Oswald-Light.svg` | 2902 |
| `src/Identity.API/wwwroot/fonts/Oswald-ExtraLight.svg` | 2860 |
| `src/Identity.API/wwwroot/fonts/Oswald-Regular.svg` | 2720 |
| `src/Identity.API/wwwroot/fonts/Montserrat-Bold.svg` | 1933 |
| `docs/appdoc-2.3/application-documentation.md` | 1919 |
| `src/Identity.API/wwwroot/fonts/Montserrat-Regular.svg` | 1743 |
| `src/Identity.API/wwwroot/css/site.css` | 1494 |
| `docs/appdoc-2.3/check-report.md` | 1339 |
| `docs/appdoc-2.2/check-report.md` | 1292 |
| `src/Catalog.API/Catalog.API.json` | 1288 |
| `docs/appdoc/check-report.md` | 1223 |
| `src/ClientApp/Services/Basket/Protos/Basket.cs` | 1152 |
| `src/Catalog.API/Catalog.API_v2.json` | 1065 |
| `docs/appdoc-2.2/application-documentation.md` | 957 |
| `src/Catalog.API/Setup/catalog.json` | 810 |
| `docs/appdoc/application-documentation.md` | 803 |
| `src/WebApp/wwwroot/css/app.css` | 574 |
| `tests/Catalog.FunctionalTests/CatalogApiTests.cs` | 507 |
| `.gitignore` | 495 |

## Entry points

- `/api/catalog/items` — `src/Catalog.API/Apis/CatalogApi.cs:22`
- `/api/catalog/items` — `src/Catalog.API/Apis/CatalogApi.cs:27`
- `/api/catalog/items/by` — `src/Catalog.API/Apis/CatalogApi.cs:32`
- `/api/catalog/items/{id:int}` — `src/Catalog.API/Apis/CatalogApi.cs:37`
- `/api/catalog/items/by/{name:minlength(1)}` — `src/Catalog.API/Apis/CatalogApi.cs:42`
- `/api/catalog/items/{id:int}/pic` — `src/Catalog.API/Apis/CatalogApi.cs:47`
- `/api/catalog/items/facets` — `src/Catalog.API/Apis/CatalogApi.cs:53`
- `/api/catalog/items/withsemanticrelevance/{text:minlength(1)}` — `src/Catalog.API/Apis/CatalogApi.cs:60`
- `/api/catalog/items/withsemanticrelevance` — `src/Catalog.API/Apis/CatalogApi.cs:67`
- `/api/catalog/items/type/{typeId}/brand/{brandId?}` — `src/Catalog.API/Apis/CatalogApi.cs:74`
- `/api/catalog/items/type/all/brand/{brandId:int?}` — `src/Catalog.API/Apis/CatalogApi.cs:79`
- `/api/catalog/catalogtypes` — `src/Catalog.API/Apis/CatalogApi.cs:84`
- `/api/catalog/catalogbrands` — `src/Catalog.API/Apis/CatalogApi.cs:91`
- `/api/catalog/items` — `src/Catalog.API/Apis/CatalogApi.cs:100`
- `/api/catalog/items/{id:int}` — `src/Catalog.API/Apis/CatalogApi.cs:105`
- `/api/catalog/items` — `src/Catalog.API/Apis/CatalogApi.cs:110`
- `/api/catalog/items/{id:int}` — `src/Catalog.API/Apis/CatalogApi.cs:114`
- `RabbitMQEventBus` — `src/EventBusRabbitMQ/RabbitMQEventBus.cs:13`
- `/` — `src/HybridApp/Components/Pages/Catalog/Catalog.razor:1`
- `/item/{itemId:int}` — `src/HybridApp/Components/Pages/Item/ItemPage.razor:1`
- `/Account/Login` — `src/Identity.API/Quickstart/Account/AccountController.cs:40`
- `/Account/Login` — `src/Identity.API/Quickstart/Account/AccountController.cs:53`
- `/Account/Login` — `src/Identity.API/Quickstart/Account/AccountController.cs:61`
- `/Account/Login` — `src/Identity.API/Quickstart/Account/AccountController.cs:139`
- `/Account/Logout` — `src/Identity.API/Quickstart/Account/AccountController.cs:147`
- `/Account/Logout` — `src/Identity.API/Quickstart/Account/AccountController.cs:159`
- `/Account/Logout` — `src/Identity.API/Quickstart/Account/AccountController.cs:167`
- `/Account/Logout` — `src/Identity.API/Quickstart/Account/AccountController.cs:193`
- `/Account/AccessDenied` — `src/Identity.API/Quickstart/Account/AccountController.cs:197`
- `/Account/AccessDenied` — `src/Identity.API/Quickstart/Account/AccountController.cs:199`
- `/External/Challenge` — `src/Identity.API/Quickstart/Account/ExternalController.cs:34`
- `/External/Callback` — `src/Identity.API/Quickstart/Account/ExternalController.cs:64`
- `/Consent/Index` — `src/Identity.API/Quickstart/Consent/ConsentController.cs:33`
- `/Consent/Index` — `src/Identity.API/Quickstart/Consent/ConsentController.cs:38`
- `/Consent/Index` — `src/Identity.API/Quickstart/Consent/ConsentController.cs:41`
- `/Consent/Index` — `src/Identity.API/Quickstart/Consent/ConsentController.cs:49`
- `/Consent/Index` — `src/Identity.API/Quickstart/Consent/ConsentController.cs:73`
- `/Consent/Index` — `src/Identity.API/Quickstart/Consent/ConsentController.cs:76`
- `/Device/Index` — `src/Identity.API/Quickstart/Device/DeviceController.cs:28`
- `/Device/Index` — `src/Identity.API/Quickstart/Device/DeviceController.cs:32`
- `/Device/Index` — `src/Identity.API/Quickstart/Device/DeviceController.cs:35`
- `/Device/Index` — `src/Identity.API/Quickstart/Device/DeviceController.cs:38`
- `/Device/UserCodeCapture` — `src/Identity.API/Quickstart/Device/DeviceController.cs:43`
- `/Device/UserCodeCapture` — `src/Identity.API/Quickstart/Device/DeviceController.cs:46`
- `/Device/UserCodeCapture` — `src/Identity.API/Quickstart/Device/DeviceController.cs:48`
- `/Device/Callback` — `src/Identity.API/Quickstart/Device/DeviceController.cs:53`
- `/Device/Callback` — `src/Identity.API/Quickstart/Device/DeviceController.cs:58`
- `/Device/Callback` — `src/Identity.API/Quickstart/Device/DeviceController.cs:60`
- `/Diagnostics/Index` — `src/Identity.API/Quickstart/Diagnostics/DiagnosticsController.cs:11`
- `/Diagnostics/Index` — `src/Identity.API/Quickstart/Diagnostics/DiagnosticsController.cs:20`
- … 47 more in `facts.json`

## Data access

- `CatalogItem` — `src/Catalog.API/Infrastructure/CatalogContext.cs:14`
- `CatalogBrand` — `src/Catalog.API/Infrastructure/CatalogContext.cs:15`
- `CatalogType` — `src/Catalog.API/Infrastructure/CatalogContext.cs:16`
- `Order` — `src/Ordering.Infrastructure/OrderingContext.cs:12`
- `OrderItem` — `src/Ordering.Infrastructure/OrderingContext.cs:13`
- `PaymentMethod` — `src/Ordering.Infrastructure/OrderingContext.cs:14`
- `Buyer` — `src/Ordering.Infrastructure/OrderingContext.cs:15`
- `CardType` — `src/Ordering.Infrastructure/OrderingContext.cs:16`
- `WebhookSubscription` — `src/Webhooks.API/Infrastructure/WebhooksContext.cs:10`

## Connections (locations only)

- `Redis` — `src/Basket.API/appsettings.json:14`
- `EventBus` — `src/Basket.API/appsettings.json:15`
- `textEmbeddingModel` — `src/Catalog.API/Extensions/Extensions.cs:43`
- `CatalogDB` — `src/Catalog.API/appsettings.Development.json:3`
- `EventBus` — `src/Catalog.API/appsettings.json:19`
- `IdentityDB` — `src/Identity.API/appsettings.Development.json:3`
- `postgres` — `src/OrderProcessor/appsettings.Development.json:10`
- `EventBus` — `src/OrderProcessor/appsettings.json:9`
- `orderingdb` — `src/Ordering.API/Extensions/Extensions.cs:17`
- `OrderingDB` — `src/Ordering.API/appsettings.Development.json:3`
- `EventBus` — `src/Ordering.API/appsettings.json:24`
- `EventBus` — `src/PaymentProcessor/appsettings.json:9`
- `chatModel` — `src/WebApp/Extensions/Extensions.cs:102`
- `WebHooksDB` — `src/Webhooks.API/appsettings.Development.json:10`
- `EventBus` — `src/Webhooks.API/appsettings.json:24`

## Config keys flagged as secret locations

- `permissions.id-token` — `.github/skills/aspire-deployment/references/github-actions-azure-csharp.yml:9`
- `jobs.deploy.steps.env.Parameters__admin_password` — `.github/skills/aspire-deployment/references/github-actions-azure-csharp.yml:53`
- `permissions.id-token` — `.github/skills/aspire-deployment/references/github-actions-azure-typescript.yml:9`
- `jobs.deploy.steps.env.Parameters__admin_password` — `.github/skills/aspire-deployment/references/github-actions-azure-typescript.yml:53`
- `jobs.test.steps.env.PASSWORD` — `.github/workflows/playwright.yml:38`
- `TokenLifetimeMinutes` — `src/Identity.API/appsettings.json:10`
- `PermanentTokenLifetimeDays` — `src/Identity.API/appsettings.json:11`
- `ClientSecret` — `src/WebApp/Extensions/Extensions.cs:78`
- `ValidateToken` — `src/WebhookClient/Endpoints/WebhookEndpoints.cs:13`
- `WebhookClientOptions:Token` — `src/WebhookClient/Endpoints/WebhookEndpoints.cs:14`
- `ClientSecret` — `src/WebhookClient/Extensions/Extensions.cs:54`
- `WebhookClientOptions:Token` — `src/WebhookClient/appsettings.json:10`
- (4 more in test code, not listed)

## External calls

- `http://basket-api` — `src/WebApp/Extensions/Extensions.cs:31`
- `CatalogService` — `src/WebApp/Extensions/Extensions.cs:34`
- `OrderingService` — `src/WebApp/Extensions/Extensions.cs:38`
- `WebhooksClient` — `src/WebhookClient/Extensions/Extensions.cs:19`
- `http://webhooks-api` — `src/WebhookClient/Extensions/Extensions.cs:19`
- (2 more in test code, not listed)

## Auth checks

- `[AllowAnonymous]` — `src/Identity.API/Quickstart/Account/AccountController.cs:7`
- `[AllowAnonymous]` — `src/Identity.API/Quickstart/Account/ExternalController.cs:4`
- `[Authorize]` — `src/Identity.API/Quickstart/Consent/ConsentController.cs:10`
- `[Authorize]` — `src/Identity.API/Quickstart/Device/DeviceController.cs:6`
- `[Authorize]` — `src/Identity.API/Quickstart/Diagnostics/DiagnosticsController.cs:8`
- `[Authorize]` — `src/Identity.API/Quickstart/Grants/GrantsController.cs:10`
- `[AllowAnonymous]` — `src/Identity.API/Quickstart/Home/HomeController.cs:7`
- `.RequireAuthorization()` — `src/Ordering.API/Program.cs:22`
- `[Authorize]` — `src/WebApp/Components/Pages/Cart/CartPage.razor:6`
- `[Authorize]` — `src/WebApp/Components/Pages/Checkout/Checkout.razor:6`
- `User.Identity.IsAuthenticated` — `src/WebApp/Components/Pages/Item/ItemPage.razor:113`
- `[Authorize]` — `src/WebApp/Components/Pages/User/LogIn.razor:3`
- `[Authorize]` — `src/WebApp/Components/Pages/User/Orders.razor:2`
- `[Authorize]` — `src/WebhookClient/Components/Pages/LogIn.razor:3`
- `.RequireAuthorization()` — `src/Webhooks.API/Program.cs:21`

## Schema objects

None extracted. This is not proof of absence.

## Ownership files

| File | Kind | Entries |
|---|---|---|
| `CONTRIBUTING.md` | contributing | 38 |

## UI pages

- `src/ClientApp/AppShell.xaml:3` — eShop.ClientApp.AppShell, Catalog,Login,Main,Map,Profile
- `src/ClientApp/Views/BasketView.xaml:2` — eShop.ClientApp.Views.BasketView
- `src/ClientApp/Views/CatalogItemView.xaml:3` — eShop.ClientApp.Views.CatalogItemView
- `src/ClientApp/Views/CatalogView.xaml:2` — eShop.ClientApp.Views.CatalogView
- `src/ClientApp/Views/CheckoutView.xaml:3` — eShop.ClientApp.Views.CheckoutView
- `src/ClientApp/Views/CustomNavigationView.xaml:3` — eShop.ClientApp.Views.CustomNavigationView
- `src/ClientApp/Views/FiltersView.xaml:3` — eShop.ClientApp.Views.FiltersView
- `src/ClientApp/Views/LoginView.xaml:3` — eShop.ClientApp.Views.LoginView
- `src/ClientApp/Views/MapView.xaml:3` — eShop.ClientApp.Views.MapView
- `src/ClientApp/Views/OrderDetailView.xaml:3` — eShop.ClientApp.Views.OrderDetailView
- `src/ClientApp/Views/ProfileView.xaml:3` — eShop.ClientApp.Views.ProfileView
- `src/ClientApp/Views/SettingsView.xaml:3` — eShop.ClientApp.Views.SettingsView
- `src/HybridApp/MainPage.xaml:2` — eShop.HybridApp.MainPage

## Finding candidates

| Pattern | Count | First locations | id |
|---|---|---|---|
| `logger-type-mismatch` | 2 | `src/Webhooks.API/IntegrationEvents/OrderStatusChangedToPaidIntegrationEventHandler.cs:6`, `src/Webhooks.API/Services/GrantUrlTesterService.cs:3` | `1a9e722a`, `4f05c1b3` |
