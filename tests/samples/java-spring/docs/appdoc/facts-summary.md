# Facts summary

- Target: `java-spring`
- Commit: `none`
- Git history: none
- Schema: `appdoc-facts/2`

> Facts show what the extractors found. An empty list is not proof that something is absent: the extractors only recognise the patterns of the Stacks below, so read the source before writing "none". Facts from test code are marked `test` in `facts.json` and left out of the lists.

## Stacks

| Stack | Supported | Files read | Marker files |
|---|---|---|---|
| java-spring | yes | 17 | `pom.xml`, `src/main/webapp/WEB-INF/applicationContext.xml`, `src/main/webapp/WEB-INF/struts.xml`, `src/main/webapp/admin/dashboard.jsp` |

## Counts

| Kind | Count |
|---|---|
| auth_check | 7 |
| config_key | 12 |
| connection | 4 |
| data_access | 12 |
| dependency | 3 |
| entry_point | 15 |
| external_call | 6 |
| file | 20 |
| message | 3 |

| Stack | Facts |
|---|---|
| generic | 36 |
| java-spring | 46 |

## Top folders by file count

| Folder | Files | Entry points | Data access | External calls |
|---|---|---|---|---|
| `src` | 18 | 15 | 12 | 6 |
| `(root)` | 2 | 0 | 0 | 0 |

## Largest source files

| File | Lines |
|---|---|
| `src/main/java/com/acme/Ticket.java` | 62 |
| `src/main/java/com/acme/TicketService.java` | 61 |
| `src/main/java/com/acme/TicketsController.java` | 57 |
| `src/main/java/com/example/app/AuditLog.java` | 48 |
| `src/main/java/com/acme/api/OrderController.java` | 44 |
| `src/main/java/com/acme/api/OrderDao.java` | 37 |
| `pom.xml` | 34 |
| `src/main/resources/application.yml` | 26 |
| `src/main/java/com/example/app/AuditLogController.java` | 22 |
| `src/main/java/com/acme/Application.java` | 16 |
| `src/main/webapp/WEB-INF/web.xml` | 16 |
| `src/main/java/com/acme/api/OrderRepository.java` | 14 |
| `src/main/resources/application.properties` | 14 |
| `README.md` | 13 |
| `src/main/java/com/acme/TicketRepository.java` | 13 |
| `src/main/java/com/acme/config/SecurityConfig.java` | 13 |
| `src/main/webapp/WEB-INF/applicationContext.xml` | 10 |
| `src/main/resources/mappers/OrderMapper.xml` | 9 |
| `src/main/webapp/WEB-INF/struts.xml` | 6 |
| `src/main/webapp/admin/dashboard.jsp` | 6 |

## Entry points

- `/api/tickets` — `src/main/java/com/acme/TicketsController.java:29`
- `/api/tickets/{id}` — `src/main/java/com/acme/TicketsController.java:35`
- `/api/tickets` — `src/main/java/com/acme/TicketsController.java:41`
- `/api/tickets/{id}` — `src/main/java/com/acme/TicketsController.java:47`
- `/api/tickets/{id}` — `src/main/java/com/acme/TicketsController.java:53`
- `/api/orders/find` — `src/main/java/com/acme/api/OrderController.java:18`
- `/api/orders/search` — `src/main/java/com/acme/api/OrderController.java:18`
- `/api/orders/{id}/cancel` — `src/main/java/com/acme/api/OrderController.java:26`
- `OrderController.nightlySweep` — `src/main/java/com/acme/api/OrderController.java:34`
- `/api/orders/wild/*` — `src/main/java/com/acme/api/OrderController.java:40`
- `/audit-log` — `src/main/java/com/example/app/AuditLogController.java:18`
- `/legacy/orders.htm` — `src/main/webapp/WEB-INF/applicationContext.xml:8`
- `/billing/invoice` — `src/main/webapp/WEB-INF/struts.xml:4`
- `/reports/*` — `src/main/webapp/WEB-INF/web.xml:10`
- `src/main/webapp/admin/dashboard.jsp` — `src/main/webapp/admin/dashboard.jsp`

## Data access

- `tickets` — `src/main/java/com/acme/Ticket.java:15`
- `TicketRepository` — `src/main/java/com/acme/TicketRepository.java:10`
- `orders` — `src/main/java/com/acme/api/OrderController.java:36`
- `order_log` — `src/main/java/com/acme/api/OrderDao.java:18`
- `customers` — `src/main/java/com/acme/api/OrderDao.java:19`
- `sp_close_order` — `src/main/java/com/acme/api/OrderDao.java:20`
- `OrderRepository` — `src/main/java/com/acme/api/OrderRepository.java:6`
- `order_items` — `src/main/java/com/acme/api/OrderRepository.java:8`
- `OrderAudit` — `src/main/java/com/acme/api/OrderRepository.java:12`
- `audit_logs` — `src/main/java/com/example/app/AuditLog.java:19`
- `open_orders` — `src/main/resources/mappers/OrderMapper.xml:3`
- `orders` — `src/main/resources/mappers/OrderMapper.xml:6`

## Connections (locations only)

- `jdbc/OrdersDS` — `src/main/java/com/acme/api/OrderDao.java:30`
- `ordersDataSource` — `src/main/java/com/acme/api/OrderDao.java:33`
- `spring.datasource.url` — `src/main/resources/application.properties:11`
- `legacyDataSource` — `src/main/webapp/WEB-INF/applicationContext.xml:3`

## Config keys flagged as secret locations

- `spring.datasource.password` — `src/main/resources/application.properties:13`
- `spring.datasource.password` — `src/main/resources/application.yml:11`

## External calls

- `/intake/tickets` — `src/main/java/com/acme/TicketService.java:42`
- `/var/spool/orders.csv` — `src/main/java/com/acme/api/OrderDao.java:25`
- `Files` — `src/main/java/com/acme/api/OrderDao.java:26`
- `JavaMailSender` — `src/main/java/com/acme/api/OrderDao.java:27`
- `https://pricing.acme.internal/v1` — `src/main/java/com/acme/api/OrderDao.java:28`
- `/usr/bin/convert` — `src/main/java/com/acme/api/OrderDao.java:29`

## Auth checks

- `hasAnyRole('ADMIN','CLERK')` — `src/main/java/com/acme/api/OrderController.java:25`
- `antMatchers("/admin/**", "/ops/*").hasRole("ADMIN")` — `src/main/java/com/acme/config/SecurityConfig.java:8`
- `antMatchers("/public/**").permitAll()` — `src/main/java/com/acme/config/SecurityConfig.java:9`
- `anyRequest().authenticated()` — `src/main/java/com/acme/config/SecurityConfig.java:10`
- `formLogin()` — `src/main/java/com/acme/config/SecurityConfig.java:11`
- `security-constraint /admin/*` — `src/main/webapp/WEB-INF/web.xml:12`
- `hasRole('ADMIN')` — `src/main/webapp/admin/dashboard.jsp:5`
