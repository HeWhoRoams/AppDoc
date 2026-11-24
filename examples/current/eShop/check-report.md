# Check: PASS

**Scope.** Run by AppDoc 2.7.1 (bundle bf8cdbec967b). This Check verifies **resolution and structure**: every Citation points to a real file and line inside the Target (see the Citation register), and every Evidence Register row's anchor text appears in the lines it cites. It does **not** judge whether a claim's wording follows from those lines; that is the source-to-claim audit, recorded in `evidence.jsonl`. A PASS is not an accuracy certification.

## Audit exclusions

The audit record declares sections the audit did not cover:

- 12: diagrams are not audited as claims
- 16.6: configuration reference block is generated and opaque
- 16.7: scheduled jobs block is generated and opaque
- 2.1: scan coverage block is generated and opaque

## Citation register

| Doc line | Cited path | Line/range | Resolved |
|---|---|---|---|
| 12 | `README.md` | 52 | yes |
| 12 | `src/eShop.AppHost/AppHost.cs` | 4-105 | yes |
| 13 | `src/Catalog.API/Apis/CatalogApi.cs` | 22-97 | yes |
| 13 | `src/WebApp/Components/Pages/Catalog/Catalog.razor` | 1 | yes |
| 14 | `src/Catalog.API/Apis/CatalogApi.cs` | 100-117 | yes |
| 15 | `src/WebApp/Components/Pages/Checkout/Checkout.razor` | 1 | yes |
| 15 | `src/WebApp/Services/BasketState.cs` | 78-109 | yes |
| 16 | `src/OrderProcessor/Services/GracePeriodManagerService.cs` | 15-62 | yes |
| 16 | `src/Ordering.Domain/AggregatesModel/OrderAggregate/Order.cs` | 99-153 | yes |
| 17 | `src/Ordering.API/Apis/OrdersApi.cs` | 11-12 | yes |
| 18 | `src/Identity.API/Quickstart/Account/AccountController.cs` | 40-193 | yes |
| 19 | `src/Webhooks.API/Apis/WebHooksApi.cs` | 13-82 | yes |
| 20 | `src/WebApp/Components/Chatbot/ChatState.cs` | 19-93 | yes |
| 21 | `src/Catalog.API/Program.cs` | 5-26 | yes |
| 37 | `src/` |  | yes |
| 38 | `tests/` |  | yes |
| 39 | `.github/` |  | yes |
| 40 | `e2e/` |  | yes |
| 41 | `.config/` |  | yes |
| 42 | `img/` |  | yes |
| 43 | `build/` |  | yes |
| 44 | `.aspire/` |  | yes |
| 45 | `.devcenter/` |  | yes |
| 46 | `.vscode/` |  | yes |
| 51 | `src/ClientApp/Platforms/MacCatalyst/` |  | yes |
| 51 | `src/ClientApp/Platforms/iOS/` |  | yes |
| 52 | `src/HybridApp/` |  | yes |
| 52 | `src/WebApp/wwwroot/` |  | yes |
| 53 | `src/HybridApp/Platforms/MacCatalyst/` |  | yes |
| 53 | `src/HybridApp/Platforms/iOS/` |  | yes |
| 54 | `src/HybridApp/wwwroot/` |  | yes |
| 54 | `src/WebApp/` |  | yes |
| 57 | `e2e/` |  | yes |
| 57 | `package.json` |  | yes |
| 59 | `.github/skills/` |  | yes |
| 59 | `e2e/` |  | yes |
| 59 | `src/ClientApp/` |  | yes |
| 59 | `src/HybridApp/` |  | yes |
| 59 | `src/Identity.API/wwwroot/` |  | yes |
| 59 | `src/WebApp/wwwroot/` |  | yes |
| 61 | `src/ClientApp/ClientApp.csproj` | 4 | yes |
| 61 | `src/ClientApp/Platforms/MacCatalyst/` |  | yes |
| 61 | `src/ClientApp/Platforms/MacCatalyst/Program.cs` | 5-14 | yes |
| 61 | `src/ClientApp/Platforms/iOS/` |  | yes |
| 61 | `src/ClientApp/Platforms/iOS/Program.cs` | 5-14 | yes |
| 61 | `src/HybridApp/` |  | yes |
| 61 | `src/HybridApp/` |  | yes |
| 61 | `src/HybridApp/HybridApp.csproj` | 4 | yes |
| 61 | `src/HybridApp/HybridApp.csproj` | 4 | yes |
| 61 | `src/HybridApp/Platforms/MacCatalyst/` |  | yes |
| 61 | `src/HybridApp/Platforms/iOS/` |  | yes |
| 61 | `src/HybridApp/wwwroot/` |  | yes |
| 61 | `src/WebApp/` |  | yes |
| 61 | `src/WebApp/wwwroot/` |  | yes |
| 61 | `src/WebApp/wwwroot/` |  | yes |
| 61 | `src/eShop.AppHost/AppHost.cs` | 71-79 | yes |
| 65 | `README.md` | 1-3 | yes |
| 65 | `src/WebhookClient/Components/Pages/AddWebhook.razor` | 1 | yes |
| 69 | `src/Webhooks.API/Services/WebhooksSender.cs` | 13-32 | yes |
| 69 | `src/eShop.AppHost/AppHost.cs` | 7 | yes |
| 69 | `src/eShop.AppHost/AppHost.cs` | 9-20 | yes |
| 69 | `src/eShop.AppHost/Extensions.cs` | 50-86 | yes |
| 75 | `src/eShop.AppHost/AppHost.cs` | 4-105 | yes |
| 76 | `src/WebApp/Program.cs` | 1-34 | yes |
| 77 | `src/Catalog.API/Extensions/Extensions.cs` | 1-51 | yes |
| 77 | `src/Catalog.API/Program.cs` | 5-26 | yes |
| 78 | `src/Ordering.API/Program.cs` | 1-25 | yes |
| 78 | `src/Ordering.Domain/AggregatesModel/OrderAggregate/Order.cs` | 5-186 | yes |
| 79 | `src/Basket.API/Program.cs` | 1-14 | yes |
| 79 | `src/Basket.API/Repositories/RedisBasketRepository.cs` | 1-56 | yes |
| 80 | `src/Identity.API/Program.cs` | 1-57 | yes |
| 81 | `src/WebhookClient/Endpoints/WebhookEndpoints.cs` | 9-55 | yes |
| 81 | `src/Webhooks.API/Program.cs` | 1-24 | yes |
| 82 | `src/OrderProcessor/Services/GracePeriodManagerService.cs` | 7-64 | yes |
| 82 | `src/PaymentProcessor/IntegrationEvents/EventHandling/OrderStatusChangedToStockConfirmedIntegrationEventHandler.cs` | 3-34 | yes |
| 83 | `src/EventBusRabbitMQ/RabbitMQEventBus.cs` | 13-224 | yes |
| 83 | `src/IntegrationEventLogEF/Services/IntegrationEventLogService.cs` | 3-60 | yes |
| 84 | `src/eShop.ServiceDefaults/Extensions.cs` | 14-129 | yes |
| 85 | `src/eShop.AppHost/AppHost.cs` | 61-64 | yes |
| 85 | `src/eShop.AppHost/Extensions.cs` | 88-153 | yes |
| 86 | `src/ClientApp/ClientApp.csproj` | 4 | yes |
| 86 | `src/HybridApp/HybridApp.csproj` | 4 | yes |
| 114 | `src/WebApp/Extensions/Extensions.cs` | 31-40 | yes |
| 114 | `src/eShop.AppHost/AppHost.cs` | 9-103 | yes |
| 118 | `src/Basket.API/Grpc/BasketService.cs` | 12-20 | yes |
| 118 | `src/Catalog.API/Program.cs` | 5-26 | yes |
| 118 | `src/Identity.API/Configuration/Config.cs` | 40-190 | yes |
| 118 | `src/Identity.API/Program.cs` | 18-37 | yes |
| 118 | `src/Identity.API/Quickstart/Account/AccountController.cs` | 95 | yes |
| 118 | `src/Ordering.API/Program.cs` | 21-22 | yes |
| 118 | `src/WebApp/Extensions/Extensions.cs` | 66-87 | yes |
| 118 | `src/WebhookClient/Extensions/Extensions.cs` | 21-40 | yes |
| 118 | `src/Webhooks.API/Program.cs` | 20-21 | yes |
| 118 | `src/eShop.ServiceDefaults/AuthenticationExtensions.cs` | 33-50 | yes |
| 173 | `src/Catalog.API/Apis/CatalogApi.cs` | 22-57 | yes |
| 173 | `src/Catalog.API/Apis/CatalogApi.cs` | 84-97 | yes |
| 173 | `src/Catalog.API/Program.cs` | 7-9 | yes |
| 174 | `src/Catalog.API/Apis/CatalogApi.cs` | 100-117 | yes |
| 174 | `src/Catalog.API/Apis/CatalogApi.cs` | 359-453 | yes |
| 175 | `src/Catalog.API/Apis/CatalogApi.cs` | 286-338 | yes |
| 175 | `src/Catalog.API/Apis/CatalogApi.cs` | 60-71 | yes |
| 175 | `src/Catalog.API/Services/CatalogAI.cs` | 7-76 | yes |
| 176 | `src/Ordering.API/Apis/OrdersApi.cs` | 16-17 | yes |
| 177 | `src/Ordering.API/Apis/OrdersApi.cs` | 13-15 | yes |
| 177 | `src/Ordering.API/Application/Queries/OrderQueries.cs` | 6-52 | yes |
| 178 | `src/Ordering.API/Apis/OrdersApi.cs` | 11-12 | yes |
| 178 | `src/Ordering.Domain/AggregatesModel/OrderAggregate/Order.cs` | 130-153 | yes |
| 179 | `src/Basket.API/Grpc/BasketService.cs` | 12-111 | yes |
| 179 | `src/Basket.API/Proto/basket.proto` | 8-10 | yes |
| 180 | `src/Identity.API/Quickstart/Account/AccountController.cs` | 40-199 | yes |
| 180 | `src/Identity.API/Quickstart/Account/ExternalController.cs` | 34-64 | yes |
| 180 | `src/Identity.API/Quickstart/Home/HomeController.cs` | 24-56 | yes |
| 181 | `src/Webhooks.API/Apis/WebHooksApi.cs` | 13-82 | yes |
| 182 | `src/WebhookClient/Endpoints/AuthenticationEndpoints.cs` | 12-17 | yes |
| 182 | `src/WebhookClient/Endpoints/WebhookEndpoints.cs` | 16-50 | yes |
| 182 | `src/WebhookClient/Services/HooksRepository.cs` | 5-30 | yes |
| 183 | `src/WebApp/Components/Pages/Cart/CartPage.razor` | 1 | yes |
| 183 | `src/WebApp/Components/Pages/Catalog/Catalog.razor` | 1 | yes |
| 183 | `src/WebApp/Components/Pages/Item/ItemPage.razor` | 1 | yes |
| 183 | `src/WebApp/Extensions/Extensions.cs` | 31-40 | yes |
| 184 | `src/WebApp/Components/Chatbot/ChatState.cs` | 19-93 | yes |
| 184 | `src/WebApp/Components/Chatbot/Chatbot.razor` | 101-126 | yes |
| 184 | `src/WebApp/Extensions/Extensions.cs` | 94-109 | yes |
| 185 | `src/EventBusRabbitMQ/RabbitMQEventBus.cs` | 13-224 | yes |
| 185 | `src/OrderProcessor/Services/GracePeriodManagerService.cs` | 15-62 | yes |
| 185 | `src/Shared/MigrateDbContextExtensions.cs` | 76-88 | yes |
| 186 | `src/PaymentProcessor/IntegrationEvents/EventHandling/OrderStatusChangedToStockConfirmedIntegrationEventHandler.cs` | 8-30 | yes |
| 187 | `src/eShop.AppHost/AppHost.cs` | 62-64 | yes |
| 187 | `src/eShop.AppHost/Extensions.cs` | 88-153 | yes |
| 188 | `src/HybridApp/Components/Pages/Catalog/Catalog.razor` | 1 | yes |
| 188 | `src/HybridApp/Components/Pages/Item/ItemPage.razor` | 1 | yes |
| 189 | `src/eShop.ServiceDefaults/Extensions.cs` | 108-128 | yes |
| 189 | `src/eShop.ServiceDefaults/OpenApi.Extensions.cs` | 24-42 | yes |
| 190 | `src/Identity.API/Quickstart/Consent/ConsentController.cs` | 33-76 | yes |
| 190 | `src/Identity.API/Quickstart/Device/DeviceController.cs` | 28-60 | yes |
| 190 | `src/Identity.API/Quickstart/Diagnostics/DiagnosticsController.cs` | 11-20 | yes |
| 190 | `src/Identity.API/Quickstart/Grants/GrantsController.cs` | 33-43 | yes |
| 191 | `src/WebApp/Components/Pages/Checkout/Checkout.razor` | 1 | yes |
| 191 | `src/WebApp/Components/Pages/User/LogIn.razor` | 1 | yes |
| 191 | `src/WebApp/Components/Pages/User/LogOut.razor` | 1 | yes |
| 191 | `src/WebApp/Components/Pages/User/Orders.razor` | 1 | yes |
| 191 | `src/WebApp/Extensions/Extensions.cs` | 38-40 | yes |
| 197 | `src/Catalog.API/` |  | yes |
| 198 | `src/Ordering.API/` |  | yes |
| 199 | `src/Ordering.Domain/` |  | yes |
| 200 | `src/Ordering.Infrastructure/` |  | yes |
| 201 | `src/Basket.API/` |  | yes |
| 202 | `src/Identity.API/` |  | yes |
| 203 | `src/Webhooks.API/` |  | yes |
| 204 | `src/WebhookClient/` |  | yes |
| 205 | `src/WebApp/` |  | yes |
| 206 | `src/WebAppComponents/` |  | yes |
| 207 | `src/OrderProcessor/` |  | yes |
| 208 | `src/PaymentProcessor/` |  | yes |
| 209 | `src/EventBus/` |  | yes |
| 210 | `src/EventBusRabbitMQ/` |  | yes |
| 211 | `src/IntegrationEventLogEF/` |  | yes |
| 212 | `src/Shared/` |  | yes |
| 213 | `src/eShop.AppHost/` |  | yes |
| 214 | `src/eShop.ServiceDefaults/` |  | yes |
| 215 | `src/ClientApp/` |  | yes |
| 216 | `src/HybridApp/` |  | yes |
| 217 | `tests/` |  | yes |
| 218 | `.github/` |  | yes |
| 219 | `e2e/` |  | yes |
| 220 | `build/` |  | yes |
| 220 | `build/acr-build/queue-all.ps1` | 4 | yes |
| 220 | `build/multiarch-manifests/create-manifests.ps1` | 10 | yes |
| 221 | `.config/` |  | yes |
| 222 | `img/` |  | yes |
| 223 | `.aspire/` |  | yes |
| 224 | `.devcenter/` |  | yes |
| 224 | `.devcenter/catalog/definitions/imagedefinition.yaml` | 1 | yes |
| 225 | `.vscode/` |  | yes |
| 231 | `src/Identity.API/Configuration/Config.cs` | 18-26 | yes |
| 231 | `src/Identity.API/Configuration/Config.cs` | 44-188 | yes |
| 231 | `src/Identity.API/UsersSeed.cs` | 8-96 | yes |
| 235 | `src/Ordering.API/Program.cs` | 21-22 | yes |
| 235 | `src/Webhooks.API/Program.cs` | 20-21 | yes |
| 235 | `src/eShop.ServiceDefaults/AuthenticationExtensions.cs` | 49 | yes |
| 236 | `src/Basket.API/Grpc/BasketService.cs` | 12-34 | yes |
| 236 | `src/Basket.API/Grpc/BasketService.cs` | 36-69 | yes |
| 237 | `src/Catalog.API/Apis/CatalogApi.cs` | 22-117 | yes |
| 237 | `src/Catalog.API/Program.cs` | 5-26 | yes |
| 238 | `src/WebApp/Components/Pages/Cart/CartPage.razor` | 6 | yes |
| 238 | `src/WebApp/Components/Pages/Checkout/Checkout.razor` | 6 | yes |
| 238 | `src/WebApp/Components/Pages/User/LogIn.razor` | 3 | yes |
| 238 | `src/WebApp/Components/Pages/User/Orders.razor` | 2 | yes |
| 239 | `src/Identity.API/Quickstart/Account/AccountController.cs` | 7 | yes |
| 239 | `src/Identity.API/Quickstart/Consent/ConsentController.cs` | 10 | yes |
| 239 | `src/Identity.API/Quickstart/Device/DeviceController.cs` | 6 | yes |
| 239 | `src/Identity.API/Quickstart/Diagnostics/DiagnosticsController.cs` | 8 | yes |
| 239 | `src/Identity.API/Quickstart/Grants/GrantsController.cs` | 10 | yes |
| 240 | `src/WebhookClient/Endpoints/WebhookEndpoints.cs` | 13-50 | yes |
| 241 | `src/Ordering.API/Application/Queries/OrderQueries.cs` | 37-40 | yes |
| 241 | `src/Ordering.API/Application/Queries/OrderQueries.cs` | 6-13 | yes |
| 241 | `src/Webhooks.API/Apis/WebHooksApi.cs` | 15-16 | yes |
| 247 | `src/Catalog.API/Apis/CatalogApi.cs` | 22-117 | yes |
| 248 | `src/Catalog.API/Apis/CatalogApi.cs` | 60-71 | yes |
| 249 | `src/Ordering.API/Program.cs` | 21-22 | yes |
| 250 | `src/Basket.API/Grpc/BasketService.cs` | 12-34 | yes |
| 250 | `src/Basket.API/Grpc/BasketService.cs` | 36-111 | yes |
| 251 | `src/Identity.API/Quickstart/Account/AccountController.cs` | 7 | yes |
| 252 | `src/Webhooks.API/Apis/WebHooksApi.cs` | 13-82 | yes |
| 253 | `src/WebhookClient/Endpoints/WebhookEndpoints.cs` | 13-50 | yes |
| 254 | `src/WebApp/Components/Pages/Catalog/Catalog.razor` | 1 | yes |
| 254 | `src/WebApp/Components/Pages/Checkout/Checkout.razor` | 6 | yes |
| 255 | `src/WebApp/Components/Chatbot/ChatState.cs` | 96-111 | yes |
| 255 | `src/WebApp/Components/Layout/MainLayout.razor` | 9 | yes |
| 256 | `src/eShop.AppHost/Extensions.cs` | 142-143 | yes |
| 260 | `src/eShop.ServiceDefaults/OpenApi.Extensions.cs` | 24 | yes |
| 262 | `src/Identity.API/Configuration/Config.cs` | 18-26 | yes |
| 262 | `src/eShop.ServiceDefaults/AuthenticationExtensions.cs` | 33-50 | yes |
| 268 | `src/WebApp/Components/Pages/Catalog/Catalog.razor` | 1 | yes |
| 272 | `src/WebApp/Components/Pages/Catalog/Catalog.razor` | 1 | yes |
| 273 | `src/WebApp/Components/Pages/Item/ItemPage.razor` | 1 | yes |
| 273 | `src/WebApp/Components/Pages/Item/ItemPage.razor` | 113 | yes |
| 274 | `src/WebApp/Components/Pages/Cart/CartPage.razor` | 6 | yes |
| 275 | `src/WebApp/Components/Pages/Checkout/Checkout.razor` | 1 | yes |
| 275 | `src/WebApp/Services/BasketState.cs` | 78-109 | yes |
| 276 | `src/WebApp/Components/Pages/User/Orders.razor` | 1 | yes |
| 277 | `src/WebApp/Components/Pages/User/LogIn.razor` | 1 | yes |
| 278 | `src/WebApp/Components/Pages/User/LogOut.razor` | 1 | yes |
| 279 | `src/WebApp/Components/Chatbot/Chatbot.razor` | 101-108 | yes |
| 279 | `src/WebApp/Components/Chatbot/Chatbot.razor` | 50-62 | yes |
| 279 | `src/WebApp/Components/Layout/MainLayout.razor` | 9 | yes |
| 280 | `src/Identity.API/Quickstart/Account/AccountController.cs` | 7 | yes |
| 280 | `src/Identity.API/Views/Account/Login.cshtml` | 1 | yes |
| 281 | `src/Identity.API/Views/Account/LoggedOut.cshtml` | 1 | yes |
| 281 | `src/Identity.API/Views/Account/Logout.cshtml` | 1 | yes |
| 282 | `src/Identity.API/Views/Account/AccessDenied.cshtml` | 1 | yes |
| 283 | `src/Identity.API/Views/Consent/Index.cshtml` | 1 | yes |
| 284 | `src/Identity.API/Views/Device/Success.cshtml` | 1 | yes |
| 284 | `src/Identity.API/Views/Device/UserCodeCapture.cshtml` | 1 | yes |
| 284 | `src/Identity.API/Views/Device/UserCodeConfirmation.cshtml` | 1 | yes |
| 285 | `src/Identity.API/Views/Diagnostics/Index.cshtml` | 1 | yes |
| 286 | `src/Identity.API/Views/Grants/Index.cshtml` | 1 | yes |
| 287 | `src/Identity.API/Quickstart/Home/HomeController.cs` | 26-34 | yes |
| 287 | `src/Identity.API/Quickstart/Home/HomeController.cs` | 49-53 | yes |
| 287 | `src/Identity.API/Views/Home/Index.cshtml` | 1 | yes |
| 287 | `src/Identity.API/Views/Shared/Error.cshtml` | 1 | yes |
| 287 | `src/Identity.API/Views/Shared/Redirect.cshtml` | 1 | yes |
| 288 | `src/WebhookClient/Components/Pages/Home/Home.razor` | 1 | yes |
| 289 | `src/WebhookClient/Components/Pages/AddWebhook.razor` | 1 | yes |
| 289 | `src/WebhookClient/Components/Pages/AddWebhook.razor` | 41-51 | yes |
| 289 | `src/WebhookClient/Components/Pages/AddWebhook.razor` | 9-17 | yes |
| 290 | `src/WebhookClient/Components/Pages/Error.razor` | 1 | yes |
| 290 | `src/WebhookClient/Components/Pages/LogIn.razor` | 1 | yes |
| 291 | `src/HybridApp/Components/Pages/Catalog/Catalog.razor` | 1 | yes |
| 291 | `src/HybridApp/Components/Pages/Catalog/Catalog.razor` | 10 | yes |
| 291 | `src/HybridApp/Components/Pages/Catalog/Catalog.razor` | 37-59 | yes |
| 291 | `src/HybridApp/Components/Pages/Item/ItemPage.razor` | 1 | yes |
| 291 | `src/HybridApp/Components/Pages/Item/ItemPage.razor` | 21-28 | yes |
| 291 | `src/HybridApp/Components/Pages/Item/ItemPage.razor` | 4 | yes |
| 291 | `src/HybridApp/Components/Pages/Item/ItemPage.razor` | 42-43 | yes |
| 292 | `src/ClientApp/AppShell.xaml` | 3 | yes |
| 292 | `src/ClientApp/Services/Identity/IdentityMockService.cs` | 1 | yes |
| 292 | `src/ClientApp/Views/LoginView.xaml` | 3 | yes |
| 292 | `src/ClientApp/Views/ProfileView.xaml` | 3 | yes |
| 292 | `src/ClientApp/Views/SettingsView.xaml` | 3 | yes |
| 293 | `src/ClientApp/Views/CatalogItemView.xaml` | 3 | yes |
| 293 | `src/ClientApp/Views/CatalogView.xaml` | 2 | yes |
| 293 | `src/ClientApp/Views/FiltersView.xaml` | 3 | yes |
| 293 | `src/ClientApp/Views/MapView.xaml` | 3 | yes |
| 294 | `src/ClientApp/Views/BasketView.xaml` | 2 | yes |
| 294 | `src/ClientApp/Views/CheckoutView.xaml` | 3 | yes |
| 294 | `src/ClientApp/Views/CustomNavigationView.xaml` | 3 | yes |
| 294 | `src/ClientApp/Views/OrderDetailView.xaml` | 3 | yes |
| 294 | `src/HybridApp/MainPage.xaml` | 2 | yes |
| 300 | `src/WebAppComponents/Services/CatalogService.cs` | 17-22 | yes |
| 301 | `src/Catalog.API/Apis/CatalogApi.cs` | 131-166 | yes |
| 302 | `src/Catalog.API/Apis/CatalogApi.cs` | 294-337 | yes |
| 303 | `src/Catalog.API/Apis/CatalogApi.cs` | 251-273 | yes |
| 305 | `src/Catalog.API/Apis/CatalogApi.cs` | 229-234 | yes |
| 305 | `src/Catalog.API/Extensions/Extensions.cs` | 38-48 | yes |
| 309 | `src/Catalog.API/Apis/CatalogApi.cs` | 100-117 | yes |
| 310 | `src/Catalog.API/Apis/CatalogApi.cs` | 415-437 | yes |
| 311 | `src/Catalog.API/Apis/CatalogApi.cs` | 373-412 | yes |
| 312 | `src/Catalog.API/Apis/CatalogApi.cs` | 439-453 | yes |
| 314 | `src/Catalog.API/Apis/CatalogApi.cs` | 381-386 | yes |
| 314 | `src/Catalog.API/IntegrationEvents/CatalogIntegrationEventService.cs` | 21-25 | yes |
| 314 | `src/IntegrationEventLogEF/Services/IntegrationEventLogService.cs` | 19-23 | yes |
| 318 | `src/WebApp/Services/BasketState.cs` | 33-56 | yes |
| 319 | `src/WebApp/Components/Pages/Checkout/Checkout.razor` | 101-126 | yes |
| 320 | `src/WebApp/Services/BasketState.cs` | 78-109 | yes |
| 320 | `src/WebApp/Services/OrderingService.cs` | 12-18 | yes |
| 321 | `src/Ordering.API/Apis/OrdersApi.cs` | 118-166 | yes |
| 321 | `src/Ordering.API/Application/Commands/IdentifiedCommandHandler.cs` | 39-102 | yes |
| 322 | `src/Ordering.API/Application/Validations/CreateOrderCommandValidator.cs` | 6-16 | yes |
| 323 | `src/Basket.API/IntegrationEvents/EventHandling/OrderStartedIntegrationEventHandler.cs` | 14 | yes |
| 323 | `src/Ordering.API/Application/Behaviors/TransactionBehavior.cs` | 52 | yes |
| 323 | `src/Ordering.API/Application/Commands/CreateOrderCommandHandler.cs` | 33 | yes |
| 323 | `src/Ordering.API/Application/Commands/CreateOrderCommandHandler.cs` | 35-51 | yes |
| 323 | `src/Ordering.Domain/AggregatesModel/OrderAggregate/Order.cs` | 52-65 | yes |
| 325 | `src/Ordering.API/Apis/OrdersApi.cs` | 135 | yes |
| 325 | `src/Ordering.API/Apis/OrdersApi.cs` | 157-166 | yes |
| 325 | `src/WebApp/Services/OrderingService.cs` | 17 | yes |
| 329 | `src/Ordering.Domain/AggregatesModel/OrderAggregate/Order.cs` | 99-153 | yes |
| 330 | `src/OrderProcessor/Services/GracePeriodManagerService.cs` | 43-61 | yes |
| 330 | `src/OrderProcessor/appsettings.json` | 14-17 | yes |
| 331 | `src/Catalog.API/IntegrationEvents/EventHandling/OrderStatusChangedToAwaitingValidationIntegrationEventHandler.cs` | 9-33 | yes |
| 332 | `src/PaymentProcessor/IntegrationEvents/EventHandling/OrderStatusChangedToStockConfirmedIntegrationEventHandler.cs` | 8-30 | yes |
| 333 | `src/Catalog.API/IntegrationEvents/EventHandling/OrderStatusChangedToPaidIntegrationEventHandler.cs` | 9-17 | yes |
| 334 | `src/Ordering.API/Application/Commands/CancelOrderCommandHandler.cs` | 19-30 | yes |
| 334 | `src/Ordering.Domain/AggregatesModel/OrderAggregate/Order.cs` | 142-153 | yes |
| 336 | `src/EventBusRabbitMQ/RabbitMQEventBus.cs` | 170-180 | yes |
| 340 | `src/WebApp/Extensions/Extensions.cs` | 66-87 | yes |
| 341 | `src/Identity.API/Quickstart/Account/AccountController.cs` | 60-95 | yes |
| 342 | `src/Identity.API/Quickstart/Account/AccountController.cs` | 97-140 | yes |
| 343 | `src/Identity.API/Quickstart/Account/AccountController.cs` | 166-193 | yes |
| 345 | `src/Identity.API/Quickstart/Account/AccountController.cs` | 95 | yes |
| 349 | `src/Webhooks.API/Apis/WebHooksApi.cs` | 35-64 | yes |
| 350 | `src/Webhooks.API/Model/WebhookSubscriptionRequest.cs` | 10-27 | yes |
| 351 | `src/Webhooks.API/Services/GrantUrlTesterService.cs` | 5-35 | yes |
| 352 | `src/Webhooks.API/IntegrationEvents/OrderStatusChangedToShippedIntegrationEventHandler.cs` | 11-18 | yes |
| 352 | `src/Webhooks.API/Services/WebhooksRetriever.cs` | 5-8 | yes |
| 352 | `src/Webhooks.API/Services/WebhooksSender.cs` | 5-32 | yes |
| 353 | `src/Webhooks.API/Apis/WebHooksApi.cs` | 66-82 | yes |
| 354 | `src/WebhookClient/Endpoints/WebhookEndpoints.cs` | 16-50 | yes |
| 356 | `src/Webhooks.API/Apis/WebHooksApi.cs` | 61 | yes |
| 356 | `src/Webhooks.API/Services/WebhooksSender.cs` | 32 | yes |
| 360 | `src/WebApp/Components/Layout/MainLayout.razor` | 2-9 | yes |
| 361 | `src/WebApp/Components/Chatbot/Chatbot.razor` | 101-113 | yes |
| 362 | `src/WebApp/Components/Chatbot/ChatState.cs` | 39-48 | yes |
| 362 | `src/WebApp/Components/Chatbot/ChatState.cs` | 69-93 | yes |
| 363 | `src/WebApp/Components/Chatbot/ChatState.cs` | 96-167 | yes |
| 364 | `src/WebApp/Components/Chatbot/MessageProcessor.cs` | 10-32 | yes |
| 366 | `src/WebApp/Components/Chatbot/ChatState.cs` | 84-91 | yes |
| 370 | `README.md` | 49-55 | yes |
| 370 | `aspire.config.json` | 1-5 | yes |
| 371 | `src/eShop.AppHost/AppHost.cs` | 9-79 | yes |
| 372 | `src/Catalog.API/Extensions/Extensions.cs` | 24 | yes |
| 372 | `src/Identity.API/Program.cs` | 12 | yes |
| 372 | `src/Shared/MigrateDbContextExtensions.cs` | 58-74 | yes |
| 373 | `src/eShop.AppHost/AppHost.cs` | 81-86 | yes |
| 375 | `README.md` | 44-45 | yes |
| 375 | `src/Shared/MigrateDbContextExtensions.cs` | 48-55 | yes |
| 383 | `src/Catalog.API/Extensions/Extensions.cs` | 15 | yes |
| 383 | `src/eShop.AppHost/AppHost.cs` | 17 | yes |
| 384 | `src/Identity.API/Program.cs` | 7 | yes |
| 384 | `src/eShop.AppHost/AppHost.cs` | 18 | yes |
| 385 | `src/Ordering.API/Extensions/Extensions.cs` | 17 | yes |
| 385 | `src/eShop.AppHost/AppHost.cs` | 19 | yes |
| 386 | `src/Webhooks.API/Extensions/Extensions.cs` | 10 | yes |
| 386 | `src/eShop.AppHost/AppHost.cs` | 20 | yes |
| 387 | `src/Basket.API/appsettings.json` | 14 | yes |
| 387 | `src/eShop.AppHost/AppHost.cs` | 9 | yes |
| 388 | `src/Basket.API/appsettings.json` | 15 | yes |
| 388 | `src/eShop.AppHost/AppHost.cs` | 10-11 | yes |
| 389 | `src/Catalog.API/Extensions/Extensions.cs` | 43 | yes |
| 390 | `src/WebApp/Extensions/Extensions.cs` | 102 | yes |
| 394 | `src/Basket.API/Repositories/RedisBasketRepository.cs` | 5-56 | yes |
| 394 | `src/Catalog.API/Apis/CatalogApi.cs` | 317-331 | yes |
| 394 | `src/Catalog.API/Infrastructure/CatalogContext.cs` | 14-16 | yes |
| 394 | `src/Identity.API/Data/ApplicationDbContext.cs` | 1 | yes |
| 394 | `src/OrderProcessor/Services/GracePeriodOrdersRepository.cs` | 23-28 | yes |
| 394 | `src/Ordering.Infrastructure/OrderingContext.cs` | 12-16 | yes |
| 394 | `src/Webhooks.API/Infrastructure/WebhooksContext.cs` | 10 | yes |
| 400 | `src/WebApp/Extensions/Extensions.cs` | 31 | yes |
| 401 | `src/WebApp/Extensions/Extensions.cs` | 34 | yes |
| 402 | `src/WebApp/Extensions/Extensions.cs` | 38 | yes |
| 403 | `src/WebhookClient/Extensions/Extensions.cs` | 19 | yes |
| 404 | `src/Webhooks.API/Services/WebhooksSender.cs` | 32 | yes |
| 405 | `src/Webhooks.API/Services/GrantUrlTesterService.cs` | 21 | yes |
| 406 | `src/eShop.ServiceDefaults/HttpClientExtensions.cs` | 48 | yes |
| 407 | `src/WebApp/Components/Chatbot/ChatState.cs` | 78 | yes |
| 408 | `src/Catalog.API/Services/CatalogAI.cs` | 61 | yes |
| 409 | `src/eShop.ServiceDefaults/AuthenticationExtensions.cs` | 38-39 | yes |
| 410 | `src/WebApp/Program.cs` | 32 | yes |
| 411 | `src/EventBusRabbitMQ/RabbitMQEventBus.cs` | 31-111 | yes |
| 413 | `tests/Catalog.FunctionalTests/CatalogApiTests.cs` | 13 | yes |
| 419 | `src/Catalog.API/Model/CatalogItem.cs` | 7-47 | yes |
| 420 | `src/Ordering.Domain/AggregatesModel/OrderAggregate/Order.cs` | 5-35 | yes |
| 421 | `src/Ordering.Domain/AggregatesModel/OrderAggregate/OrderItem.cs` | 5-19 | yes |
| 422 | `src/Ordering.Domain/AggregatesModel/BuyerAggregate/Buyer.cs` | 5-15 | yes |
| 423 | `src/Ordering.Domain/AggregatesModel/BuyerAggregate/PaymentMethod.cs` | 5-16 | yes |
| 424 | `src/Webhooks.API/Model/WebhookSubscription.cs` | 3-13 | yes |
| 425 | `src/Identity.API/Models/ApplicationUser.cs` | 4-30 | yes |
| 426 | `src/Basket.API/Model/CustomerBasket.cs` | 3 | yes |
| 432 | `src/Catalog.API/Model/CatalogItem.cs` | 9 | yes |
| 433 | `src/Catalog.API/Model/CatalogItem.cs` | 12 | yes |
| 434 | `src/Catalog.API/Model/CatalogItem.cs` | 14 | yes |
| 435 | `src/Catalog.API/Model/CatalogItem.cs` | 16 | yes |
| 436 | `src/Catalog.API/Model/CatalogItem.cs` | 18 | yes |
| 437 | `src/Catalog.API/Model/CatalogItem.cs` | 20 | yes |
| 438 | `src/Catalog.API/Model/CatalogItem.cs` | 24 | yes |
| 439 | `src/Catalog.API/Model/CatalogItem.cs` | 29 | yes |
| 440 | `src/Catalog.API/Model/CatalogItem.cs` | 40 | yes |
| 446 | `src/Ordering.Domain/AggregatesModel/OrderAggregate/Order.cs` | 5 | yes |
| 447 | `src/Ordering.Domain/AggregatesModel/OrderAggregate/Order.cs` | 12 | yes |
| 448 | `src/Ordering.Domain/AggregatesModel/OrderAggregate/Order.cs` | 14 | yes |
| 449 | `src/Ordering.Domain/AggregatesModel/OrderAggregate/Order.cs` | 18 | yes |
| 450 | `src/Ordering.Domain/AggregatesModel/OrderAggregate/Order.cs` | 35 | yes |
| 451 | `src/Ordering.Domain/AggregatesModel/BuyerAggregate/Buyer.cs` | 9 | yes |
| 452 | `src/Ordering.Domain/AggregatesModel/BuyerAggregate/Buyer.cs` | 11 | yes |
| 453 | `src/Ordering.Infrastructure/EntityConfigurations/PaymentMethodEntityTypeConfiguration.cs` | 27-31 | yes |
| 454 | `src/Ordering.Infrastructure/EntityConfigurations/PaymentMethodEntityTypeConfiguration.cs` | 17-20 | yes |
| 455 | `src/Ordering.Domain/AggregatesModel/BuyerAggregate/PaymentMethod.cs` | 11 | yes |
| 457 | `src/Identity.API/Models/ApplicationUser.cs` | 4-30 | yes |
| 457 | `src/Webhooks.API/Model/WebhookSubscription.cs` | 3-13 | yes |
| 461 | `src/Webhooks.API/Model/WebhookSubscription.cs` | 10 | yes |
| 462 | `src/Webhooks.API/Model/WebhookSubscription.cs` | 11 | yes |
| 463 | `src/Webhooks.API/Model/WebhookSubscription.cs` | 13 | yes |
| 464 | `src/Identity.API/Models/ApplicationUser.cs` | 7 | yes |
| 465 | `src/Identity.API/Models/ApplicationUser.cs` | 9 | yes |
| 466 | `src/Identity.API/Models/ApplicationUser.cs` | 17-25 | yes |
| 467 | `src/Identity.API/Models/ApplicationUser.cs` | 27-29 | yes |
| 473 | `src/Shared/MigrateDbContextExtensions.cs` | 44-46 | yes |
| 473 | `src/Shared/MigrateDbContextExtensions.cs` | 48-55 | yes |
| 473 | `src/eShop.ServiceDefaults/Extensions.cs` | 50-83 | yes |
| 474 | `src/Shared/MigrateDbContextExtensions.cs` | 44-46 | yes |
| 474 | `src/Shared/MigrateDbContextExtensions.cs` | 48-55 | yes |
| 474 | `src/eShop.ServiceDefaults/Extensions.cs` | 50-83 | yes |
| 475 | `src/Shared/MigrateDbContextExtensions.cs` | 44-46 | yes |
| 475 | `src/Shared/MigrateDbContextExtensions.cs` | 48-55 | yes |
| 475 | `src/eShop.ServiceDefaults/Extensions.cs` | 50-83 | yes |
| 476 | `src/Shared/MigrateDbContextExtensions.cs` | 44-46 | yes |
| 476 | `src/Shared/MigrateDbContextExtensions.cs` | 48-55 | yes |
| 476 | `src/eShop.ServiceDefaults/Extensions.cs` | 50-83 | yes |
| 477 | `src/Basket.API/Grpc/BasketService.cs` | 53 | yes |
| 477 | `src/Basket.API/Repositories/RedisBasketRepository.cs` | 34-48 | yes |
| 477 | `src/Basket.API/Repositories/RedisBasketRepository.cs` | 41-46 | yes |
| 478 | `src/EventBusRabbitMQ/RabbitMQEventBus.cs` | 170-180 | yes |
| 478 | `src/EventBusRabbitMQ/RabbitMQEventBus.cs` | 22 | yes |
| 478 | `src/EventBusRabbitMQ/RabbitMQEventBus.cs` | 59-88 | yes |
| 479 | `src/Catalog.API/Apis/CatalogApi.cs` | 294-305 | yes |
| 479 | `src/Catalog.API/Services/CatalogAI.cs` | 64-67 | yes |
| 479 | `src/eShop.ServiceDefaults/Extensions.cs` | 22-29 | yes |
| 480 | `src/WebApp/Components/Chatbot/ChatState.cs` | 84-91 | yes |
| 480 | `src/WebApp/Components/Chatbot/ChatState.cs` | 86-89 | yes |
| 481 | `src/WebApp/Components/Chatbot/ChatState.cs` | 145-148 | yes |
| 481 | `src/eShop.ServiceDefaults/Extensions.cs` | 74-76 | yes |
| 482 | `src/WebAppComponents/Services/CatalogService.cs` | 11-67 | yes |
| 482 | `src/eShop.ServiceDefaults/Extensions.cs` | 74-76 | yes |
| 483 | `src/WebApp/Services/OrderingService.cs` | 17 | yes |
| 484 | `src/WebhookClient/Services/WebHooksClient.cs` | 1-12 | yes |
| 485 | `src/Webhooks.API/Services/WebhooksSender.cs` | 27-30 | yes |
| 485 | `src/Webhooks.API/Services/WebhooksSender.cs` | 32 | yes |
| 485 | `src/Webhooks.API/Services/WebhooksSender.cs` | 5-11 | yes |
| 486 | `src/Webhooks.API/Services/GrantUrlTesterService.cs` | 17-31 | yes |
| 486 | `src/Webhooks.API/Services/GrantUrlTesterService.cs` | 29-34 | yes |
| 487 | `src/eShop.ServiceDefaults/HttpClientExtensions.cs` | 36-48 | yes |
| 488 | `src/WebApp/Components/Chatbot/ChatState.cs` | 84-91 | yes |
| 488 | `src/eShop.ServiceDefaults/Extensions.cs` | 64 | yes |
| 489 | `src/Catalog.API/Apis/CatalogApi.cs` | 392 | yes |
| 489 | `src/Catalog.API/Apis/CatalogApi.cs` | 431 | yes |
| 489 | `src/Catalog.API/Services/CatalogAI.cs` | 64-67 | yes |
| 490 | `src/eShop.ServiceDefaults/AuthenticationExtensions.cs` | 33-50 | yes |
| 490 | `src/eShop.ServiceDefaults/AuthenticationExtensions.cs` | 33-50 | yes |
| 490 | `src/eShop.ServiceDefaults/AuthenticationExtensions.cs` | 38-39 | yes |
| 491 | `src/WebApp/Program.cs` | 32 | yes |
| 491 | `src/WebApp/Program.cs` | 32 | yes |
| 491 | `src/eShop.ServiceDefaults/Extensions.cs` | 22-29 | yes |
| 492 | `src/EventBusRabbitMQ/RabbitMQEventBus.cs` | 113-125 | yes |
| 492 | `src/EventBusRabbitMQ/RabbitMQEventBus.cs` | 177-180 | yes |
| 492 | `src/EventBusRabbitMQ/RabbitMQEventBus.cs` | 22 | yes |
| 498 | `src/Ordering.API/Apis/OrdersApi.cs` | 29 | yes |
| 498 | `src/Ordering.API/Apis/OrdersApi.cs` | 58 | yes |
| 499 | `src/Ordering.API/Apis/OrdersApi.cs` | 135 | yes |
| 500 | `src/Ordering.API/Apis/OrdersApi.cs` | 45 | yes |
| 500 | `src/Ordering.Domain/AggregatesModel/OrderAggregate/Order.cs` | 142-148 | yes |
| 501 | `src/Ordering.API/Apis/OrdersApi.cs` | 74 | yes |
| 501 | `src/Ordering.Domain/AggregatesModel/OrderAggregate/Order.cs` | 130-135 | yes |
| 502 | `src/WebhookClient/Endpoints/WebhookEndpoints.cs` | 28 | yes |
| 503 | `src/Webhooks.API/Apis/WebHooksApi.cs` | 61 | yes |
| 503 | `src/Webhooks.API/Services/GrantUrlTesterService.cs` | 7-10 | yes |
| 504 | `src/Webhooks.API/Apis/WebHooksApi.cs` | 32 | yes |
| 504 | `src/Webhooks.API/Apis/WebHooksApi.cs` | 81 | yes |
| 505 | `src/WebApp/Components/Chatbot/Chatbot.razor` | 50-62 | yes |
| 505 | `src/eShop.AppHost/AppHost.cs` | 88 | yes |
| 506 | `src/WebApp/Components/Chatbot/ChatState.cs` | 84-91 | yes |
| 507 | `src/WebApp/Components/Chatbot/ChatState.cs` | 145-148 | yes |
| 508 | `src/Catalog.API/Apis/CatalogApi.cs` | 258-267 | yes |
| 509 | `src/EventBusRabbitMQ/RabbitMQEventBus.cs` | 170-180 | yes |
| 510 | `src/Shared/MigrateDbContextExtensions.cs` | 48-55 | yes |
| 518 | `src/Catalog.API/Apis/CatalogApi.cs` | 100-117 | yes |
| 518 | `src/Catalog.API/Apis/CatalogApi.cs` | 396-405 | yes |
| 518 | `src/Catalog.API/Program.cs` | 5-26 | yes |
| 518 | `src/eShop.AppHost/AppHost.cs` | 62-64 | yes |
| 518 | `src/eShop.AppHost/Extensions.cs` | 142-143 | yes |
| 519 | `src/Identity.API/Program.cs` | 29 | yes |
| 519 | `src/Identity.API/Program.cs` | 37 | yes |
| 519 | `src/Identity.API/tempkey.jwk` | 1 | yes |
| 520 | `src/Ordering.API/Apis/OrdersApi.cs` | 11-13 | yes |
| 520 | `src/Ordering.API/Application/Commands/CancelOrderCommandHandler.cs` | 19-30 | yes |
| 520 | `src/Ordering.API/Application/Queries/OrderQueries.cs` | 15-34 | yes |
| 520 | `src/Ordering.API/Application/Queries/OrderQueries.cs` | 6-35 | yes |
| 520 | `src/Ordering.API/Program.cs` | 21-22 | yes |
| 520 | `src/eShop.ServiceDefaults/AuthenticationExtensions.cs` | 49 | yes |
| 521 | `src/Identity.API/Configuration/Config.cs` | 118 | yes |
| 521 | `src/Identity.API/Configuration/Config.cs` | 52 | yes |
| 521 | `src/Identity.API/Configuration/Config.cs` | 82 | yes |
| 521 | `src/Identity.API/Program.cs` | 12 | yes |
| 521 | `src/Identity.API/UsersSeed.cs` | 33 | yes |
| 521 | `src/Identity.API/UsersSeed.cs` | 78 | yes |
| 522 | `.github/workflows/playwright.yml` | 37-38 | yes |
| 522 | `src/Identity.API/appsettings.Development.json` | 3 | yes |
| 522 | `src/WebApp/Extensions/Extensions.cs` | 78 | yes |
| 522 | `src/WebhookClient/Extensions/Extensions.cs` | 54 | yes |
| 522 | `src/WebhookClient/appsettings.json` | 10 | yes |
| 523 | `src/Identity.API/UsersSeed.cs` | 33 | yes |
| 523 | `src/Identity.API/Views/Account/Login.cshtml` | 46 | yes |
| 524 | `src/WebApp/Components/Chatbot/ChatState.cs` | 72 | yes |
| 524 | `src/WebApp/Components/Chatbot/ChatState.cs` | 78 | yes |
| 524 | `src/WebApp/Components/Chatbot/ChatState.cs` | 96-111 | yes |
| 524 | `src/WebApp/Extensions/Extensions.cs` | 94-109 | yes |
| 524 | `src/eShop.AppHost/AppHost.cs` | 81-86 | yes |
| 524 | `src/eShop.AppHost/Extensions.cs` | 67-86 | yes |
| 525 | `src/WebApp/Components/Chatbot/Chatbot.razor` | 42-47 | yes |
| 525 | `src/WebApp/Components/Chatbot/MessageProcessor.cs` | 10-32 | yes |
| 526 | `src/Webhooks.API/Apis/WebHooksApi.cs` | 35-64 | yes |
| 526 | `src/Webhooks.API/Model/WebhookSubscriptionRequest.cs` | 10-20 | yes |
| 526 | `src/Webhooks.API/Services/GrantUrlTesterService.cs` | 5-35 | yes |
| 527 | `src/Webhooks.API/IntegrationEvents/OrderStatusChangedToShippedIntegrationEvent.cs` | 3 | yes |
| 527 | `src/Webhooks.API/IntegrationEvents/OrderStatusChangedToShippedIntegrationEventHandler.cs` | 11-18 | yes |
| 527 | `src/Webhooks.API/Services/WebhooksRetriever.cs` | 5-8 | yes |
| 528 | `src/WebhookClient/Endpoints/WebhookEndpoints.cs` | 13 | yes |
| 528 | `src/WebhookClient/Endpoints/WebhookEndpoints.cs` | 33-50 | yes |
| 528 | `src/WebhookClient/Services/HooksRepository.cs` | 7 | yes |
| 528 | `src/WebhookClient/appsettings.json` | 1-12 | yes |
| 529 | `src/eShop.ServiceDefaults/AuthenticationExtensions.cs` | 24-28 | yes |
| 529 | `src/eShop.ServiceDefaults/AuthenticationExtensions.cs` | 46 | yes |
| 529 | `src/eShop.ServiceDefaults/AuthenticationExtensions.cs` | 49 | yes |
| 530 | `src/EventBusRabbitMQ/RabbitMQEventBus.cs` | 170-180 | yes |
| 531 | `src/Ordering.API/Apis/OrdersApi.cs` | 157-166 | yes |
| 531 | `src/WebApp/Services/BasketState.cs` | 107-108 | yes |
| 531 | `src/WebApp/Services/OrderingService.cs` | 17 | yes |
| 532 | `src/Ordering.API/Apis/OrdersApi.cs` | 130 | yes |
| 532 | `src/Ordering.API/Apis/OrdersApi.cs` | 130 | yes |
| 532 | `src/Ordering.API/Apis/OrdersApi.cs` | 134 | yes |
| 532 | `src/Ordering.API/Apis/OrdersApi.cs` | 149-153 | yes |
| 532 | `src/Ordering.API/Application/Commands/CreateOrderCommand.cs` | 53 | yes |
| 532 | `src/Ordering.API/Application/Commands/IdentifiedCommandHandler.cs` | 80 | yes |
| 533 | `src/Catalog.API/Apis/CatalogApi.cs` | 323 | yes |
| 533 | `src/Catalog.API/Services/CatalogAI.cs` | 66 | yes |
| 533 | `src/WebhookClient/Endpoints/WebhookEndpoints.cs` | 35 | yes |
| 533 | `src/Webhooks.API/Services/GrantUrlTesterService.cs` | 17 | yes |
| 534 | `src/Catalog.API/Extensions/Extensions.cs` | 23 | yes |
| 534 | `src/Identity.API/Configuration/Config.cs` | 148 | yes |
| 534 | `src/Identity.API/Configuration/Config.cs` | 90 | yes |
| 534 | `src/Identity.API/Program.cs` | 28-36 | yes |
| 534 | `src/Identity.API/Program.cs` | 9-12 | yes |
| 534 | `src/WebApp/Extensions/Extensions.cs` | 82 | yes |
| 534 | `src/eShop.ServiceDefaults/AuthenticationExtensions.cs` | 39 | yes |
| 535 | `src/Ordering.API/Apis/OrdersApi.cs` | 140 | yes |
| 535 | `src/Ordering.API/Application/Validations/CreateOrderCommandValidator.cs` | 11 | yes |
| 536 | `src/EventBusRabbitMQ/RabbitMQEventBus.cs` | 163-166 | yes |
| 537 | `src/Webhooks.API/IntegrationEvents/OrderStatusChangedToPaidIntegrationEventHandler.cs` | 6 | yes |
| 537 | `src/Webhooks.API/Services/GrantUrlTesterService.cs` | 3 | yes |
| 538 | `src/eShop.AppHost/AppHost.cs` | 12-14 | yes |
| 539 | `src/PaymentProcessor/appsettings.json` | 13-15 | yes |
| 539 | `src/WebApp/Services/BasketState.cs` | 100-103 | yes |
| 545 | `src/WebApp/Program.cs` | 17-26 | yes |
| 546 | `src/WebApp/Extensions/Extensions.cs` | 31 | yes |
| 546 | `src/eShop.ServiceDefaults/AuthenticationExtensions.cs` | 39 | yes |
| 547 | `src/Identity.API/Quickstart/Account/AccountController.cs` | 60 | yes |
| 547 | `src/WebApp/Program.cs` | 24 | yes |
| 547 | `src/WebhookClient/Endpoints/AuthenticationEndpoints.cs` | 14 | yes |
| 548 | `src/Identity.API/Models/ManageViewModels/IndexViewModel.cs` | 11 | yes |
| 548 | `src/Identity.API/Quickstart/Account/AccountController.cs` | 95 | yes |
| 549 | `src/WebApp/Extensions/Extensions.cs` | 71 | yes |
| 550 | `src/Catalog.API/Program.cs` | 5-26 | yes |
| 550 | `src/Identity.API/Program.cs` | 1-57 | yes |
| 551 | `src/Identity.API/Quickstart/Account/AccountController.cs` | 95 | yes |
| 552 | `src/Identity.API/Program.cs` | 23-26 | yes |
| 553 | `src/eShop.AppHost/AppHost.cs` | 12-15 | yes |
| 554 | `README.md` | 99-101 | yes |
| 555 | `src/Catalog.API/Program.cs` | 5-26 | yes |
| 556 | `src/Ordering.API/Application/Commands/CancelOrderCommandHandler.cs` | 19-30 | yes |
| 556 | `src/Ordering.API/Application/Queries/OrderQueries.cs` | 6-13 | yes |
| 557 | `src/Webhooks.API/Model/WebhookSubscriptionRequest.cs` | 10-20 | yes |
| 557 | `src/Webhooks.API/Services/WebhooksSender.cs` | 13-32 | yes |
| 558 | `src/EventBusRabbitMQ/RabbitMQEventBus.cs` | 177-180 | yes |
| 559 | `src/WebApp/Components/Chatbot/ChatState.cs` | 69-111 | yes |
| 559 | `src/WebApp/Components/Chatbot/Chatbot.razor` | 101-126 | yes |
| 560 | `src/Catalog.API/Program.cs` | 7-9 | yes |
| 560 | `tests/Catalog.FunctionalTests/CatalogApiTests.cs` | 237 | yes |
| 561 | `src/Ordering.API/Application/Validations/CreateOrderCommandValidator.cs` | 6-16 | yes |
| 562 | `src/eShop.ServiceDefaults/Extensions.cs` | 115-125 | yes |
| 569 | `es-metadata.yml` | 3-4 | yes |
| 572 | `CONTRIBUTING.md` | 1 | yes |
| 573 | `.github/dependabot.yml` | 7-12 | yes |
| 573 | `.github/workflows/playwright.yml` | 1-34 | yes |
| 573 | `.github/workflows/pr-validation.yml` | 1-29 | yes |
| 574 | `tests/Application.UnitTests/WebhookTests.cs` | 10-40 | yes |
| 575 | `tests/Basket.FunctionalTests/RedisBasketRepositoryTests.cs` | 1 | yes |
| 575 | `tests/Basket.UnitTests/BasketServiceTests.cs` | 1 | yes |
| 576 | `tests/Catalog.FunctionalTests/CatalogApiTests.cs` | 13-237 | yes |
| 577 | `tests/Ordering.FunctionalTests/OrderingApiTests.cs` | 1 | yes |
| 577 | `tests/Ordering.UnitTests/Domain/OrderAggregateTest.cs` | 1 | yes |
| 578 | `tests/Webhooks.FunctionalTests/WebhooksApiTests.cs` | 1 | yes |
| 579 | `tests/eShop.AppHost.UnitTests/AppHostConfigurationTests.cs` | 1 | yes |
| 580 | `tests/ClientApp.UnitTests/ViewModels/CatalogViewModelTests.cs` | 1 | yes |
| 581 | `e2e/CheckoutTest.spec.ts` | 1 | yes |
| 581 | `playwright.config.ts` | 86-87 | yes |
| 602 | `src/WebApp/Components/Chatbot/ChatState.cs` | 69-111 | yes |
| 621 | `src/Catalog.API/IntegrationEvents/EventHandling/OrderStatusChangedToAwaitingValidationIntegrationEventHandler.cs` | 9-33 | yes |
| 621 | `src/Ordering.API/Application/Commands/CreateOrderCommandHandler.cs` | 29-52 | yes |
| 637 | `src/Catalog.API/Model/CatalogItem.cs` | 7-47 | yes |
| 637 | `src/Ordering.Domain/AggregatesModel/OrderAggregate/Order.cs` | 5-35 | yes |
| 655 | `src/eShop.AppHost/AppHost.cs` | 25-27 | yes |
| 655 | `src/eShop.AppHost/AppHost.cs` | 62-63 | yes |
| 655 | `src/eShop.AppHost/AppHost.cs` | 71-73 | yes |
| 661 | `src/eShop.AppHost/AppHost.cs` | 4 | yes |
| 662 | `README.md` | 3 | yes |
| 663 | `src/Basket.API/Grpc/BasketService.cs` | 8-10 | yes |
| 664 | `src/WebApp/Components/Chatbot/ChatState.cs` | 9-48 | yes |
| 665 | `src/Catalog.API/Services/CatalogAI.cs` | 75 | yes |
| 666 | `src/IntegrationEventLogEF/Services/IntegrationEventLogService.cs` | 34-44 | yes |
| 667 | `src/OrderProcessor/appsettings.json` | 14-17 | yes |
| 668 | `src/Webhooks.API/Services/GrantUrlTesterService.cs` | 5-35 | yes |
| 669 | `src/Ordering.API/Application/Commands/IdentifiedCommandHandler.cs` | 39-102 | yes |
| 670 | `src/EventBusRabbitMQ/RabbitMQEventBus.cs` | 31-111 | yes |
| 671 | `src/eShop.AppHost/AppHost.cs` | 62-64 | yes |
| 672 | `src/Catalog.API/Program.cs` | 7-9 | yes |
| 673 | `src/Ordering.API/Apis/OrdersApi.cs` | 22-24 | yes |
| 674 | `src/eShop.AppHost/AppHost.cs` | 81-86 | yes |
| 675 | `src/WebhookClient/Endpoints/WebhookEndpoints.cs` | 13 | yes |
| 712 | `src/Ordering.API/Apis/OrdersApi.cs` | 134 | yes |
| 725 | `src/Catalog.API/Program.cs` | 5-26 | yes |
| 725 | `src/Catalog.API/Program.cs` | 5-26 | yes |
| 731 | `README.md` | 17-26 | yes |
| 731 | `global.json` | 2-6 | yes |
| 731 | `package.json` | 1-17 | yes |
| 731 | `src/WebApp/WebApp.csproj` | 4 | yes |
| 731 | `src/eShop.AppHost/eShop.AppHost.csproj` | 1 | yes |
| 735 | `src/Basket.API/Repositories/RedisBasketRepository.cs` | 13-16 | yes |
| 735 | `src/Catalog.API/Infrastructure/CatalogContext.cs` | 20 | yes |
| 735 | `src/Catalog.API/Infrastructure/CatalogContextSeed.cs` | 25 | yes |
| 735 | `src/EventBusRabbitMQ/RabbitMQEventBus.cs` | 20 | yes |
| 735 | `src/Identity.API/UsersSeed.cs` | 8-96 | yes |
| 735 | `src/Ordering.API/Infrastructure/OrderingContextSeed.cs` | 9-24 | yes |
| 735 | `src/Shared/MigrateDbContextExtensions.cs` | 58-74 | yes |
| 735 | `src/eShop.AppHost/AppHost.cs` | 17-20 | yes |
| 739 | `src/Identity.API/Configuration/Config.cs` | 73-74 | yes |
| 739 | `src/Identity.API/Program.cs` | 21 | yes |
| 739 | `src/Identity.API/Quickstart/Account/AccountOptions.cs` | 10 | yes |
| 739 | `src/WebApp/Extensions/Extensions.cs` | 62-71 | yes |
| 739 | `src/WebApp/appsettings.json` | 12 | yes |
| 745 | `src/Shared/MigrateDbContextExtensions.cs` | 48-55 | yes |
| 746 | `src/EventBusRabbitMQ/RabbitMQEventBus.cs` | 170-180 | yes |
| 747 | `src/WebApp/Components/Chatbot/Chatbot.razor` | 50-62 | yes |
| 747 | `src/eShop.AppHost/AppHost.cs` | 88 | yes |
| 748 | `src/Catalog.API/Apis/CatalogApi.cs` | 294-305 | yes |
| 749 | `src/Webhooks.API/Services/WebhooksSender.cs` | 32 | yes |
| 755 | `.github/workflows/pr-validation.yml` | 27 | yes |
| 756 | `.github/workflows/playwright.yml` | 34 | yes |
| 756 | `.github/workflows/pr-validation.yml` | 29 | yes |
| 757 | `README.md` | 117-118 | yes |
| 757 | `README.md` | 129-130 | yes |
| 758 | `README.md` | 142 | yes |
| 762 | `README.md` | 99-101 | yes |
| 769 | `src/WebApp/Extensions/Extensions.cs` | 78 | yes |
| 770 | `src/WebhookClient/Endpoints/WebhookEndpoints.cs` | 13 | yes |
| 771 | `src/WebhookClient/appsettings.json` | 10 | yes |
| 772 | `.aspire/settings.json` | 2 | yes |
| 773 | `src/Basket.API/appsettings.json` | 4 | yes |
| 774 | `src/Basket.API/appsettings.json` | 5 | yes |
| 775 | `src/Basket.API/appsettings.json` | 10 | yes |
| 776 | `src/Basket.API/appsettings.json` | 18 | yes |
| 777 | `src/Basket.API/appsettings.json` | 21 | yes |
| 778 | `src/Catalog.API/Extensions/Extensions.cs` | 38 | yes |
| 779 | `src/Catalog.API/appsettings.json` | 10 | yes |
| 780 | `src/Catalog.API/appsettings.json` | 13 | yes |
| 781 | `src/Catalog.API/appsettings.json` | 14 | yes |
| 782 | `src/Catalog.API/appsettings.json` | 15 | yes |
| 783 | `src/Catalog.API/appsettings.json` | 25 | yes |
| 784 | `src/Identity.API/Configuration/Config.cs` | 84 | yes |
| 785 | `src/Identity.API/Configuration/Config.cs` | 120 | yes |
| 786 | `src/Identity.API/Configuration/Config.cs` | 151 | yes |
| 787 | `src/Identity.API/Configuration/Config.cs` | 166 | yes |
| 788 | `src/Identity.API/Configuration/Config.cs` | 181 | yes |
| 789 | `src/Identity.API/appsettings.json` | 8 | yes |
| 790 | `src/Identity.API/appsettings.json` | 9 | yes |
| 791 | `src/Identity.API/appsettings.json` | 10 | yes |
| 792 | `src/Identity.API/appsettings.json` | 11 | yes |
| 793 | `src/OrderProcessor/appsettings.Development.json` | 5 | yes |
| 794 | `src/OrderProcessor/appsettings.Development.json` | 6 | yes |
| 795 | `src/OrderProcessor/appsettings.json` | 15 | yes |
| 796 | `src/OrderProcessor/appsettings.json` | 16 | yes |
| 797 | `src/Ordering.API/appsettings.json` | 8 | yes |
| 798 | `src/Ordering.API/appsettings.json` | 19 | yes |
| 799 | `src/Ordering.API/appsettings.json` | 20 | yes |
| 800 | `src/Ordering.API/appsettings.json` | 32 | yes |
| 801 | `src/PaymentProcessor/appsettings.Development.json` | 4 | yes |
| 802 | `src/PaymentProcessor/appsettings.json` | 15 | yes |
| 803 | `src/WebApp/Extensions/Extensions.cs` | 60 | yes |
| 804 | `src/WebApp/Extensions/Extensions.cs` | 61 | yes |
| 805 | `src/WebApp/appsettings.json` | 12 | yes |
| 806 | `src/Webhooks.API/appsettings.json` | 30 | yes |
| 807 | `src/Webhooks.API/appsettings.json` | 33 | yes |
| 808 | `src/eShop.AppHost/Extensions.cs` | 15 | yes |
| 809 | `src/eShop.AppHost/appsettings.json` | 6 | yes |
| 810 | `src/eShop.ServiceDefaults/AuthenticationExtensions.cs` | 22 | yes |
| 811 | `src/eShop.ServiceDefaults/AuthenticationExtensions.cs` | 35 | yes |
| 812 | `src/eShop.ServiceDefaults/AuthenticationExtensions.cs` | 36 | yes |
| 813 | `src/eShop.ServiceDefaults/Extensions.cs` | 87 | yes |
| 814 | `src/eShop.ServiceDefaults/OpenApi.Extensions.cs` | 17 | yes |
| 815 | `src/eShop.ServiceDefaults/OpenApi.Extensions.cs` | 55 | yes |
| 816 | `src/eShop.ServiceDefaults/OpenApi.Extensions.cs` | 77 | yes |
| 817 | `src/eShop.ServiceDefaults/OpenApi.Extensions.cs` | 77 | yes |
| 821 | `ci.yml` |  | yes |
| 821 | `es-metadata.yml` |  | yes |
| 836 | `src/EventBusRabbitMQ/RabbitMQEventBus.cs` | 226-232 | yes |
| 836 | `src/OrderProcessor/Services/GracePeriodManagerService.cs` | 15-61 | yes |
| 836 | `src/OrderProcessor/appsettings.json` | 14-17 | yes |
| 836 | `src/Shared/MigrateDbContextExtensions.cs` | 76-88 | yes |
| 842 | `README.md` | 19-26 | yes |
| 843 | `.github/workflows/pr-validation.yml` | 26-27 | yes |
| 844 | `.github/workflows/pr-validation.yml` | 27 | yes |
| 845 | `README.md` | 52 | yes |
| 846 | `README.md` | 83 | yes |
| 848 | `README.md` | 44-45 | yes |
| 848 | `README.md` | 89-91 | yes |
| 848 | `global.json` | 2-6 | yes |

## Verification

**Source-to-claim audit:** performed (auditor: independent). 157 rows (16 superseded): 153 Supported, 3 Corrected, 0 Downgraded, 1 Answerable.

| Section | IDs with a register row |
|---|---|
| 4 | 19 of 19 |
| 6 | 23 of 23 |
| 8.1 | 8 of 8 |
| 8.3 | 12 of 12 |
| 10.1 | 22 of 22 |
| 14 | 8 of 8 |
| 15 | 24 of 24 |
| 7 (workflows) | 8 of 8 |
