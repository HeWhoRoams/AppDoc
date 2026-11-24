# Check: PASS

**Scope.** Run by AppDoc 2.7.1 (bundle bf8cdbec967b). This Check verifies **resolution and structure**: every Citation points to a real file and line inside the Target (see the Citation register), and every Evidence Register row's anchor text appears in the lines it cites. It does **not** judge whether a claim's wording follows from those lines; that is the source-to-claim audit, recorded in `evidence.jsonl`. A PASS is not an accuracy certification.

## Audit exclusions

The audit record declares sections the audit did not cover:

- 12: diagrams are not audited
- 16.7: generated scheduled jobs block is not audited
- 2.1: generated scan coverage block is not audited
- 3.2: diagram is not audited

## Citation register

| Doc line | Cited path | Line/range | Resolved |
|---|---|---|---|
| 12 | `cmd/web.go` | 261-298 | yes |
| 12 | `routers/install/install.go` | 63 | yes |
| 13 | `models/auth/twofactor.go` | 125 | yes |
| 13 | `routers/web/auth/auth.go` | 288 | yes |
| 14 | `cmd/admin_user_create.go` | 24 | yes |
| 14 | `routers/web/auth/auth.go` | 552 | yes |
| 15 | `routers/api/v1/api.go` | 277-319 | yes |
| 15 | `routers/web/user/setting/applications.go` | 67 | yes |
| 16 | `routers/web/repo/migrate.go` | 125 | yes |
| 16 | `routers/web/repo/repo.go` | 193 | yes |
| 17 | `routers/private/serv.go` | 68 | yes |
| 17 | `routers/web/repo/githttp.go` | 62 | yes |
| 18 | `routers/web/repo/pull.go` | 1088 | yes |
| 18 | `services/pull/merge.go` | 308 | yes |
| 19 | `routers/web/repo/issue_new.go` | 331 | yes |
| 20 | `routers/api/actions/runner/runner.go` | 168 | yes |
| 20 | `services/actions/task.go` | 66 | yes |
| 21 | `routers/api/packages/api.go` | 92 | yes |
| 21 | `routers/api/packages/generic/generic.go` | 74 | yes |
| 22 | `services/webhook/deliver.go` | 147 | yes |
| 23 | `cmd/admin_user.go` | 30 | yes |
| 23 | `routers/web/admin/users.go` | 568 | yes |
| 24 | `services/cron/tasks.go` | 100 | yes |
| 24 | `services/cron/tasks_basic.go` | 31 | yes |
| 25 | `cmd/dump.go` | 26 | yes |
| 25 | `contrib/upgrade.sh` | 3 | yes |
| 26 | `routers/web/org/org.go` | 46 | yes |
| 26 | `routers/web/web.go` | 944 | yes |
| 27 | `custom/conf/app.example.ini` | 437 | yes |
| 27 | `modules/setting/security.go` | 134 | yes |
| 28 | `modules/setting/security.go` | 147 | yes |
| 28 | `routers/install/install.go` | 74 | yes |
| 34 | `package.json` | 1-10 | yes |
| 34 | `pyproject.toml` | 1-10 | yes |
| 34 | `services/cron/tasks_actions.go` | 27 | yes |
| 34 | `services/cron/tasks_basic.go` | 31 | yes |
| 34 | `services/cron/tasks_extended.go` | 26 | yes |
| 36 | `Dockerfile.rootless` | 40 | yes |
| 36 | `Dockerfile` | 41 | yes |
| 36 | `docker/root` |  | yes |
| 36 | `docker/rootless` |  | yes |
| 38 | `custom/conf/app.example.ini` | 1-60 | yes |
| 38 | `docker/root/etc/templates/app.ini` | 1-60 | yes |
| 38 | `docker/rootless/etc/templates/app.ini` | 1-57 | yes |
| 38 | `modelmigration/` |  | yes |
| 38 | `options/locale/` |  | yes |
| 38 | `public/` |  | yes |
| 38 | `templates/` |  | yes |
| 38 | `tests/` |  | yes |
| 38 | `web_src/` |  | yes |
| 51 | `modules/` |  | yes |
| 52 | `tests/` |  | yes |
| 53 | `services/` |  | yes |
| 54 | `templates/` |  | yes |
| 55 | `routers/` |  | yes |
| 56 | `public/` |  | yes |
| 57 | `models/` |  | yes |
| 58 | `web_src/` |  | yes |
| 59 | `modelmigration/` |  | yes |
| 60 | `options/` |  | yes |
| 61 | `cmd/` |  | yes |
| 62 | `.github/` |  | yes |
| 63 | `contrib/` |  | yes |
| 64 | `docker/` |  | yes |
| 65 | `tools/` |  | yes |
| 66 | `build/` |  | yes |
| 67 | `docs/` |  | yes |
| 68 | `assets/` |  | yes |
| 69 | `snap/` |  | yes |
| 70 | `.devcontainer/` |  | yes |
| 71 | `custom/` |  | yes |
| 78 | `README.md` | 14-20 | yes |
| 78 | `models/perm/access_mode.go` | 15-22 | yes |
| 78 | `models/user/user.go` | 140-151 | yes |
| 78 | `models/user/user.go` | 50-66 | yes |
| 80 | `custom/conf/app.example.ini` | 853 | yes |
| 80 | `modules/setting/service.go` | 141 | yes |
| 80 | `modules/setting/service.go` | 163 | yes |
| 84 | `Makefile` | 110-113 | yes |
| 84 | `cmd/hook.go` | 33 | yes |
| 84 | `cmd/serv.go` | 40 | yes |
| 84 | `modules/queue/manager.go` |  | yes |
| 84 | `modules/setting/ssh.go` | 20-21 | yes |
| 84 | `public/assets` |  | yes |
| 84 | `routers/init.go` | 176-207 | yes |
| 84 | `services/cron/tasks_basic.go` | 31 | yes |
| 84 | `vite.config.ts` | 1-12 | yes |
| 84 | `web_src/` |  | yes |
| 86 | `custom/conf/app.example.ini` | 1592-1666 | yes |
| 86 | `custom/conf/app.example.ini` | 2891-3017 | yes |
| 86 | `models/db/engine_init.go` | 28-34 | yes |
| 86 | `modules/auth/password/pwn/pwn.go` | 22 | yes |
| 86 | `modules/hcaptcha/hcaptcha.go` | 96 | yes |
| 86 | `modules/mcaptcha/mcaptcha.go` | 44 | yes |
| 86 | `modules/recaptcha/recaptcha.go` | 35 | yes |
| 86 | `modules/turnstile/turnstile.go` | 47 | yes |
| 86 | `routers/api/actions/actions.go` | 20-24 | yes |
| 86 | `routers/init.go` | 115-118 | yes |
| 86 | `services/auth/source/ldap/source.go` | 59 | yes |
| 86 | `services/cron/tasks_extended.go` | 168 | yes |
| 86 | `services/migrations/bitbucket.go` | 179 | yes |
| 86 | `services/migrations/github_graphql.go` | 166 | yes |
| 86 | `services/webhook/deliver.go` | 34-92 | yes |
| 92 | `./main.go` | 36-45 | yes |
| 92 | `cmd/` |  | yes |
| 92 | `cmd/hook.go` | 33 | yes |
| 92 | `cmd/keys.go` | 21 | yes |
| 92 | `cmd/serv.go` | 40 | yes |
| 92 | `cmd/web.go` | 41 | yes |
| 93 | `routers/` |  | yes |
| 93 | `routers/init.go` | 176-214 | yes |
| 93 | `routers/install/routes.go` | 19-40 | yes |
| 93 | `routers/web/web.go` | 257-321 | yes |
| 94 | `services/` |  | yes |
| 94 | `services/actions/task.go` | 66 | yes |
| 94 | `services/audit/event.go` |  | yes |
| 94 | `services/auth/group.go` | 1-60 | yes |
| 94 | `services/context/context.go` | 174-176 | yes |
| 94 | `services/cron/tasks_basic.go` | 31 | yes |
| 94 | `services/mailer/` |  | yes |
| 94 | `services/migrations/migrate.go` |  | yes |
| 94 | `services/pull/merge.go` | 308 | yes |
| 94 | `services/webhook/deliver.go` | 147 | yes |
| 95 | `modelmigration/` |  | yes |
| 95 | `models/` |  | yes |
| 95 | `models/audit/audit_event.go` | 20 | yes |
| 95 | `models/auth/access_token.go` | 20 | yes |
| 95 | `models/repo/repo.go` | 153 | yes |
| 95 | `models/user/user.go` | 101 | yes |
| 95 | `models/webhook/webhook.go` | 123 | yes |
| 95 | `routers/common/db.go` | 43-58 | yes |
| 96 | `./main.go` | 17-22 | yes |
| 96 | `modules/` |  | yes |
| 96 | `modules/cache/cache.go` |  | yes |
| 96 | `modules/egress/policies.go` | 86 | yes |
| 96 | `modules/indexer/issues/indexer.go` |  | yes |
| 96 | `modules/queue/manager.go` |  | yes |
| 96 | `modules/session/session.go` | 110-135 | yes |
| 96 | `modules/setting/security.go` | 134-215 | yes |
| 96 | `modules/storage/storage.go` |  | yes |
| 97 | `Makefile` | 110-116 | yes |
| 97 | `options/` |  | yes |
| 97 | `options/` |  | yes |
| 97 | `public/` |  | yes |
| 97 | `public/` |  | yes |
| 97 | `templates/` |  | yes |
| 97 | `templates/` |  | yes |
| 97 | `vite.config.ts` | 1-12 | yes |
| 97 | `web_src/` |  | yes |
| 97 | `web_src/` |  | yes |
| 98 | `.github/` |  | yes |
| 98 | `.github/workflows/pull-db-tests.yml` | 1-20 | yes |
| 98 | `Makefile` | 436-473 | yes |
| 98 | `build/` |  | yes |
| 98 | `build/generate-emoji.go` | 81 | yes |
| 98 | `tests/` |  | yes |
| 98 | `tools/` |  | yes |
| 122 | `cmd/hook.go` | 33 | yes |
| 122 | `cmd/serv.go` | 40 | yes |
| 122 | `routers/init.go` | 176-207 | yes |
| 126 | `routers/api/actions/runner/interceptor.go` | 56-66 | yes |
| 126 | `routers/api/packages/api.go` | 71-90 | yes |
| 126 | `routers/api/packages/auth.go` | 18-52 | yes |
| 126 | `routers/api/v1/api.go` | 851-862 | yes |
| 126 | `routers/private/internal.go` | 25-43 | yes |
| 126 | `routers/web/web.go` | 124-160 | yes |
| 126 | `services/auth/group.go` | 44-70 | yes |
| 128 | `modules/session/session.go` | 125-135 | yes |
| 128 | `modules/setting/session.go` | 64 | yes |
| 128 | `routers/api/v1/api.go` | 277-360 | yes |
| 128 | `routers/web/auth/auth.go` | 397-403 | yes |
| 128 | `routers/web/web.go` | 178-258 | yes |
| 128 | `routers/web/web.go` | 179 | yes |
| 128 | `routers/web/web.go` | 221 | yes |
| 128 | `routers/web/web.go` | 896-899 | yes |
| 128 | `services/context/context.go` | 174-176 | yes |
| 188 | `cmd/hook.go` | 33 | yes |
| 188 | `cmd/keys.go` | 21 | yes |
| 188 | `cmd/manager.go` | 18 | yes |
| 188 | `cmd/manager_logging.go` | 18 | yes |
| 188 | `cmd/serv.go` | 40 | yes |
| 188 | `cmd/web.go` | 232-238 | yes |
| 188 | `cmd/web.go` | 41 | yes |
| 188 | `modules/setting/security.go` | 134-215 | yes |
| 188 | `routers/private/internal.go` | 89-97 | yes |
| 189 | `cmd/admin.go` | 22 | yes |
| 189 | `cmd/admin_auth.go` | 22 | yes |
| 189 | `cmd/admin_auth_ldap.go` | 179 | yes |
| 189 | `cmd/admin_auth_oauth.go` | 137 | yes |
| 189 | `cmd/admin_auth_smtp.go` | 75 | yes |
| 189 | `cmd/admin_regenerate.go` | 18 | yes |
| 190 | `cmd/admin_user.go` | 30 | yes |
| 190 | `cmd/admin_user_change_password.go` | 22 | yes |
| 190 | `cmd/admin_user_change_type.go` | 19 | yes |
| 190 | `cmd/admin_user_create.go` | 24 | yes |
| 190 | `cmd/admin_user_delete.go` | 22 | yes |
| 190 | `cmd/admin_user_disable_2fa.go` | 21 | yes |
| 190 | `cmd/admin_user_generate_access_token.go` | 19 | yes |
| 190 | `cmd/admin_user_list.go` | 19 | yes |
| 190 | `cmd/admin_user_must_change_password.go` | 18 | yes |
| 191 | `cmd/doctor.go` | 28 | yes |
| 191 | `cmd/doctor_convert.go` | 18 | yes |
| 191 | `cmd/dump.go` | 26 | yes |
| 191 | `cmd/dump.go` | 26-30 | yes |
| 191 | `cmd/dump_repo.go` | 28 | yes |
| 191 | `cmd/migrate.go` | 19 | yes |
| 191 | `cmd/migrate.go` | 19-40 | yes |
| 191 | `cmd/migrate_storage.go` | 30 | yes |
| 191 | `cmd/restore_repo.go` | 18 | yes |
| 192 | `cmd/actions.go` | 17 | yes |
| 192 | `cmd/cert.go` | 31 | yes |
| 192 | `cmd/config.go` | 19 | yes |
| 192 | `cmd/docs.go` | 18 | yes |
| 192 | `cmd/embedded.go` | 29 | yes |
| 192 | `cmd/generate.go` | 22 | yes |
| 192 | `modules/setting/security.go` | 134-215 | yes |
| 193 | `routers/install/install.go` | 190 | yes |
| 193 | `routers/install/install.go` | 191-194 | yes |
| 193 | `routers/install/install.go` | 393-400 | yes |
| 193 | `routers/install/install.go` | 63 | yes |
| 193 | `routers/install/install.go` | 64-67 | yes |
| 193 | `routers/install/routes.go` | 30-32 | yes |
| 194 | `routers/web/auth/auth.go` | 288 | yes |
| 194 | `routers/web/auth/auth.go` | 397-403 | yes |
| 194 | `routers/web/auth/auth.go` | 552 | yes |
| 194 | `routers/web/auth/auth.go` | 560-603 | yes |
| 194 | `routers/web/web.go` | 567-607 | yes |
| 194 | `routers/web/web.go` | 725-747 | yes |
| 195 | `routers/web/auth/oauth2_wellknown.go` | 17 | yes |
| 195 | `routers/web/web.go` | 362-367 | yes |
| 195 | `routers/web/web.go` | 520-521 | yes |
| 195 | `routers/web/web.go` | 592-606 | yes |
| 196 | `routers/web/web.go` | 608-723 | yes |
| 196 | `routers/web/web.go` | 723 | yes |
| 197 | `routers/web/web.go` | 243-248 | yes |
| 197 | `routers/web/web.go` | 749-876 | yes |
| 198 | `routers/web/web.go` | 1067 | yes |
| 198 | `routers/web/web.go` | 937-1070 | yes |
| 198 | `routers/web/web.go` | 955-982 | yes |
| 199 | `routers/web/repo/repo.go` | 193 | yes |
| 199 | `routers/web/web.go` | 1071-1078 | yes |
| 199 | `routers/web/web.go` | 1146-1270 | yes |
| 200 | `routers/web/web.go` | 1418-1517 | yes |
| 200 | `routers/web/web.go` | 1586-1626 | yes |
| 200 | `routers/web/web.go` | 1658-1746 | yes |
| 200 | `routers/web/web.go` | 403-408 | yes |
| 201 | `routers/web/repo/pull.go` | 1088 | yes |
| 201 | `routers/web/repo/pull.go` | 1110-1139 | yes |
| 201 | `routers/web/web.go` | 1271-1417 | yes |
| 201 | `routers/web/web.go` | 1519-1540 | yes |
| 201 | `routers/web/web.go` | 1628-1657 | yes |
| 202 | `routers/common/lfs.go` | 17-29 | yes |
| 202 | `routers/web/githttp.go` | 12-24 | yes |
| 202 | `routers/web/repo/githttp.go` | 137-161 | yes |
| 202 | `routers/web/repo/githttp.go` | 197-199 | yes |
| 202 | `routers/web/repo/githttp.go` | 62-162 | yes |
| 202 | `routers/web/web.go` | 1750-1752 | yes |
| 203 | `routers/api/v1/api.go` | 1239-1730 | yes |
| 203 | `routers/api/v1/api.go` | 277-308 | yes |
| 203 | `routers/api/v1/api.go` | 378-418 | yes |
| 204 | `routers/api/v1/api.go` | 1011-1235 | yes |
| 204 | `routers/api/v1/api.go` | 1732-1880 | yes |
| 204 | `routers/api/v1/api.go` | 1827-1876 | yes |
| 205 | `routers/api/packages/api.go` | 42-58 | yes |
| 205 | `routers/api/packages/api.go` | 523 | yes |
| 205 | `routers/api/packages/api.go` | 92-110 | yes |
| 205 | `routers/init.go` | 188-194 | yes |
| 206 | `routers/api/actions/actions.go` | 15-27 | yes |
| 206 | `routers/api/actions/artifacts.go` | 108-130 | yes |
| 206 | `routers/api/actions/runner/interceptor.go` | 56-66 | yes |
| 206 | `routers/api/actions/runner/runner.go` | 168 | yes |
| 206 | `services/actions/task.go` | 66-73 | yes |
| 207 | `routers/web/web.go` | 1541-1584 | yes |
| 207 | `routers/web/web.go` | 1544-1573 | yes |
| 208 | `routers/private/internal.go` | 25-43 | yes |
| 208 | `routers/private/internal.go` | 71-100 | yes |
| 209 | `routers/api/v1/api.go` | 1828-1831 | yes |
| 209 | `services/cron/tasks_actions.go` | 27 | yes |
| 209 | `services/cron/tasks_basic.go` | 31 | yes |
| 209 | `services/cron/tasks_extended.go` | 26 | yes |
| 210 | `routers/web/web.go` | 448-480 | yes |
| 210 | `routers/web/web.go` | 706-718 | yes |
| 210 | `services/webhook/deliver.go` | 147 | yes |
| 210 | `services/webhook/deliver.go` | 186-192 | yes |
| 210 | `services/webhook/deliver.go` | 91 | yes |
| 211 | `routers/api/v1/repo/migrate.go` |  | yes |
| 211 | `routers/web/web.go` | 1073-1074 | yes |
| 211 | `routers/web/web.go` | 1146-1152 | yes |
| 211 | `services/migrations/http_client.go` | 37 | yes |
| 211 | `services/migrations/migrate.go` |  | yes |
| 212 | `cmd/web.go` | 238-257 | yes |
| 212 | `cmd/web.go` | 246-251 | yes |
| 212 | `routers/web/metrics.go` | 14-26 | yes |
| 212 | `routers/web/web.go` | 1769-1771 | yes |
| 212 | `routers/web/web.go` | 290-298 | yes |
| 212 | `routers/web/web.go` | 306-308 | yes |
| 212 | `routers/web/web.go` | 518-524 | yes |
| 212 | `routers/web/web.go` | 590 | yes |
| 218 | `modules/` |  | yes |
| 218 | `modules/setting/security.go` | 134-215 | yes |
| 219 | `Makefile` | 436-473 | yes |
| 219 | `tests/` |  | yes |
| 220 | `services/` |  | yes |
| 220 | `services/pull/merge.go` | 308 | yes |
| 221 | `routers/web/home.go` | 25 | yes |
| 221 | `templates/` |  | yes |
| 222 | `routers/` |  | yes |
| 222 | `routers/init.go` | 176-214 | yes |
| 223 | `public/` |  | yes |
| 223 | `routers/web/web.go` | 265 | yes |
| 224 | `models/` |  | yes |
| 224 | `models/user/user.go` | 101 | yes |
| 225 | `vite.config.ts` | 1-12 | yes |
| 225 | `web_src/` |  | yes |
| 226 | `modelmigration/` |  | yes |
| 226 | `routers/common/db.go` | 43-58 | yes |
| 227 | `Makefile` | 116 | yes |
| 227 | `options/` |  | yes |
| 228 | `./main.go` | 36-45 | yes |
| 228 | `cmd/` |  | yes |
| 229 | `.github/` |  | yes |
| 229 | `.github/workflows/pull-db-tests.yml` | 1-20 | yes |
| 230 | `contrib/` |  | yes |
| 230 | `contrib/upgrade.sh` | 1-6 | yes |
| 231 | `Dockerfile` | 41 | yes |
| 231 | `docker/` |  | yes |
| 232 | `Makefile` | 436-441 | yes |
| 232 | `tools/` |  | yes |
| 233 | `build/` |  | yes |
| 233 | `build/generate-emoji.go` | 81 | yes |
| 234 | `docs/` |  | yes |
| 234 | `docs/testing.md` | 1-6 | yes |
| 235 | `Makefile` | 631-633 | yes |
| 235 | `assets/` |  | yes |
| 236 | `snap/` |  | yes |
| 236 | `snap/snapcraft.yaml` | 1-3 | yes |
| 237 | `.devcontainer/` |  | yes |
| 238 | `custom/` |  | yes |
| 238 | `custom/conf/app.example.ini` | 1-60 | yes |
| 239 | `./main.go` |  | yes |
| 239 | `./main.go` | 36-45 | yes |
| 245 | `modules/setting/service.go` | 163-170 | yes |
| 245 | `routers/web/repo/githttp.go` | 130-146 | yes |
| 246 | `models/user/user.go` | 50-66 | yes |
| 246 | `services/auth/session.go` | 44-48 | yes |
| 247 | `models/user/user.go` | 113-151 | yes |
| 248 | `models/perm/access_mode.go` | 15-22 | yes |
| 248 | `models/unit/unit.go` | 23-36 | yes |
| 249 | `models/organization/team.go` | 72-73 | yes |
| 249 | `routers/api/v1/api.go` | 421-560 | yes |
| 250 | `models/auth/access_token_scope.go` | 58-90 | yes |
| 251 | `routers/api/actions/runner/interceptor.go` | 56-66 | yes |
| 251 | `routers/api/packages/auth.go` | 41-42 | yes |
| 251 | `routers/private/internal.go` | 25-43 | yes |
| 251 | `routers/web/web.go` | 136-138 | yes |
| 255 | `routers/web/web.go` | 1308-1309 | yes |
| 255 | `routers/web/web.go` | 1737 | yes |
| 255 | `routers/web/web.go` | 178-258 | yes |
| 255 | `routers/web/web.go` | 243-248 | yes |
| 256 | `routers/api/v1/api.go` | 111-146 | yes |
| 256 | `routers/api/v1/api.go` | 311-418 | yes |
| 256 | `routers/api/v1/api.go` | 864-922 | yes |
| 257 | `routers/api/v1/api.go` | 249-257 | yes |
| 258 | `routers/api/packages/api.go` | 42-90 | yes |
| 259 | `routers/install/routes.go` | 25-40 | yes |
| 259 | `routers/web/metrics.go` | 14-17 | yes |
| 259 | `routers/web/web.go` | 262-298 | yes |
| 259 | `routers/web/web.go` | 518-536 | yes |
| 260 | `routers/private/internal.go` | 25-43 | yes |
| 266 | `cmd/web.go` | 41 | yes |
| 267 | `routers/install/routes.go` | 30-32 | yes |
| 268 | `routers/web/web.go` | 567-590 | yes |
| 269 | `routers/web/web.go` | 592-606 | yes |
| 270 | `routers/web/web.go` | 608-723 | yes |
| 271 | `routers/web/web.go` | 749-876 | yes |
| 272 | `routers/web/web.go` | 937-1070 | yes |
| 273 | `routers/web/web.go` | 1071-1270 | yes |
| 274 | `routers/web/web.go` | 1271-1417 | yes |
| 275 | `routers/web/repo/githttp.go` | 130-161 | yes |
| 276 | `routers/api/v1/api.go` | 962-964 | yes |
| 277 | `routers/api/packages/api.go` | 42-58 | yes |
| 278 | `routers/web/web.go` | 1541-1573 | yes |
| 279 | `routers/private/internal.go` | 25-43 | yes |
| 280 | `routers/api/v1/api.go` | 1828-1831 | yes |
| 281 | `routers/web/web.go` | 706-718 | yes |
| 282 | `routers/web/web.go` | 1073-1074 | yes |
| 283 | `routers/web/web.go` | 290-298 | yes |
| 284 | `routers/api/v1/api.go` | 1876 | yes |
| 285 | `routers/api/v1/api.go` | 249-257 | yes |
| 291 | `templates/` |  | yes |
| 295 | `routers/install/install.go` | 190 | yes |
| 295 | `routers/install/routes.go` | 30-32 | yes |
| 295 | `templates/install.tmpl` | 41-42 | yes |
| 296 | `routers/web/home.go` | 27-49 | yes |
| 296 | `routers/web/web.go` | 518 | yes |
| 297 | `routers/web/auth/auth.go` | 310-366 | yes |
| 297 | `routers/web/web.go` | 567 | yes |
| 297 | `templates/user/auth/signin.tmpl` |  | yes |
| 298 | `routers/web/auth/auth.go` | 560-563 | yes |
| 298 | `routers/web/web.go` | 570 | yes |
| 298 | `templates/user/auth/signup.tmpl` |  | yes |
| 299 | `routers/web/web.go` | 575-580 | yes |
| 299 | `templates/user/auth/twofa.tmpl` |  | yes |
| 300 | `routers/web/web.go` | 732 | yes |
| 300 | `templates/user/auth/forgot_passwd.tmpl` |  | yes |
| 301 | `routers/web/web.go` | 593-598 | yes |
| 301 | `templates/user/auth/grant.tmpl` |  | yes |
| 302 | `routers/web/web.go` | 358 | yes |
| 302 | `routers/web/web.go` | 539-555 | yes |
| 302 | `templates/explore/repos.tmpl` |  | yes |
| 303 | `routers/web/user/home.go` | 79-137 | yes |
| 303 | `routers/web/web.go` | 956-957 | yes |
| 303 | `templates/user/dashboard/dashboard.tmpl` |  | yes |
| 304 | `routers/web/web.go` | 880-891 | yes |
| 304 | `routers/web/web.go` | 888 | yes |
| 304 | `templates/user/profile.tmpl` |  | yes |
| 305 | `routers/web/web.go` | 608-723 | yes |
| 305 | `templates/user/settings/profile.tmpl` |  | yes |
| 306 | `routers/web/repo/repo.go` | 193 | yes |
| 306 | `routers/web/web.go` | 1072-1073 | yes |
| 306 | `templates/repo/create.tmpl` |  | yes |
| 307 | `routers/web/repo/migrate.go` | 125 | yes |
| 307 | `routers/web/web.go` | 1074-1075 | yes |
| 307 | `templates/repo/migrate` |  | yes |
| 308 | `routers/web/repo/view_home.go` | 276 | yes |
| 308 | `routers/web/repo/view_home.go` | 349 | yes |
| 308 | `routers/web/web.go` | 1267 | yes |
| 308 | `templates/repo/home.tmpl` |  | yes |
| 309 | `routers/web/web.go` | 1308 | yes |
| 309 | `templates/repo/issue/list.tmpl` |  | yes |
| 310 | `routers/web/web.go` | 1323 | yes |
| 310 | `routers/web/web.go` | 1631 | yes |
| 310 | `templates/repo/issue/view.tmpl` |  | yes |
| 311 | `routers/web/web.go` | 1158-1166 | yes |
| 311 | `templates/repo/settings/options.tmpl` |  | yes |
| 312 | `routers/web/web.go` | 1541-1573 | yes |
| 312 | `templates/repo/actions/list.tmpl` |  | yes |
| 313 | `routers/web/web.go` | 1586-1592 | yes |
| 313 | `templates/repo/wiki` |  | yes |
| 314 | `routers/web/web.go` | 888 | yes |
| 314 | `templates/org/home.tmpl` |  | yes |
| 315 | `routers/web/web.go` | 749-752 | yes |
| 315 | `routers/web/web.go` | 750-752 | yes |
| 315 | `templates/admin/dashboard.tmpl` |  | yes |
| 316 | `routers/web/web.go` | 782-795 | yes |
| 316 | `routers/web/web.go` | 787 | yes |
| 316 | `templates/admin/user/list.tmpl` |  | yes |
| 317 | `routers/web/web.go` | 306-309 | yes |
| 317 | `templates/swagger/openapi-viewer.tmpl` |  | yes |
| 322 | `cmd/web.go` | 136-166 | yes |
| 322 | `cmd/web.go` | 285-286 | yes |
| 323 | `routers/install/install.go` | 113-114 | yes |
| 323 | `routers/install/install.go` | 70-100 | yes |
| 324 | `routers/install/install.go` | 212 | yes |
| 324 | `routers/install/install.go` | 239 | yes |
| 324 | `routers/install/install.go` | 393-400 | yes |
| 324 | `routers/install/install.go` | 429 | yes |
| 324 | `routers/install/install.go` | 452-470 | yes |
| 325 | `cmd/web.go` | 168-170 | yes |
| 325 | `routers/install/install.go` | 191-194 | yes |
| 325 | `routers/install/install.go` | 64-67 | yes |
| 327 | `cmd/web.go` | 152-156 | yes |
| 327 | `routers/install/install.go` | 212-215 | yes |
| 327 | `routers/install/install.go` | 239 | yes |
| 327 | `routers/install/install.go` | 64-67 | yes |
| 331 | `routers/web/auth/auth.go` | 288-306 | yes |
| 331 | `routers/web/auth/auth.go` | 308 | yes |
| 332 | `services/auth/signin.go` | 27-100 | yes |
| 333 | `routers/web/auth/auth.go` | 326-366 | yes |
| 333 | `routers/web/web.go` | 575-607 | yes |
| 333 | `routers/web/web.go` | 737-740 | yes |
| 334 | `routers/web/auth/auth.go` | 376-430 | yes |
| 335 | `routers/web/auth/auth.go` | 456-464 | yes |
| 335 | `routers/web/auth/auth.go` | 467-489 | yes |
| 337 | `routers/web/auth/auth.go` | 309-314 | yes |
| 337 | `routers/web/auth/auth.go` | 316-319 | yes |
| 341 | `modules/setting/service.go` | 141 | yes |
| 341 | `routers/web/auth/auth.go` | 552-612 | yes |
| 342 | `cmd/admin_user_create.go` | 24 | yes |
| 342 | `routers/web/web.go` | 784-785 | yes |
| 343 | `routers/web/auth/password.go` | 70-75 | yes |
| 343 | `routers/web/auth/password.go` | 82-86 | yes |
| 343 | `routers/web/auth/password.go` | 88-92 | yes |
| 343 | `routers/web/web.go` | 725-747 | yes |
| 344 | `routers/web/admin/users.go` | 590-608 | yes |
| 346 | `routers/web/auth/auth.go` | 584-603 | yes |
| 346 | `routers/web/auth/auth.go` | 594-600 | yes |
| 350 | `routers/web/user/setting/applications.go` | 67-120 | yes |
| 351 | `models/auth/access_token.go` | 46-61 | yes |
| 352 | `modules/setting/security.go` | 224 | yes |
| 352 | `services/auth/oauth2.go` | 83-110 | yes |
| 353 | `routers/api/v1/api.go` | 277-308 | yes |
| 354 | `routers/web/user/setting/applications.go` | 155-187 | yes |
| 356 | `routers/api/v1/api.go` | 303-306 | yes |
| 356 | `routers/api/v1/api.go` | 311-319 | yes |
| 360 | `routers/web/repo/repo.go` | 193-250 | yes |
| 360 | `routers/web/web.go` | 1072-1073 | yes |
| 361 | `routers/web/repo/migrate.go` | 125 | yes |
| 361 | `routers/web/repo/migrate.go` | 277-283 | yes |
| 362 | `services/migrations/http_client.go` | 37 | yes |
| 363 | `routers/web/repo/setting/setting.go` | 166-210 | yes |
| 363 | `routers/web/web.go` | 1158-1161 | yes |
| 363 | `routers/web/web.go` | 1261 | yes |
| 365 | `routers/web/repo/migrate.go` | 282 | yes |
| 365 | `routers/web/web.go` | 765-780 | yes |
| 369 | `routers/web/repo/githttp.go` | 41-46 | yes |
| 369 | `routers/web/web.go` | 1750-1757 | yes |
| 370 | `routers/web/repo/githttp.go` | 149-161 | yes |
| 370 | `routers/web/repo/githttp.go` | 197-199 | yes |
| 370 | `routers/web/repo/githttp.go` | 62-146 | yes |
| 371 | `cmd/serv.go` | 40 | yes |
| 371 | `routers/private/serv.go` | 140-262 | yes |
| 371 | `routers/private/serv.go` | 29-70 | yes |
| 372 | `cmd/hook.go` | 49-92 | yes |
| 372 | `routers/private/hook_pre_receive.go` | 75-111 | yes |
| 373 | `routers/private/hook_post_receive.go` | 91-96 | yes |
| 373 | `services/actions/notifier.go` | 548 | yes |
| 375 | `modules/setting/server.go` | 246 | yes |
| 375 | `routers/private/internal.go` | 25-30 | yes |
| 375 | `routers/private/serv.go` | 167 | yes |
| 375 | `routers/private/serv.go` | 59 | yes |
| 375 | `routers/web/repo/githttp.go` | 124-128 | yes |
| 379 | `routers/web/web.go` | 1628-1657 | yes |
| 380 | `routers/web/repo/pull.go` | 1088-1110 | yes |
| 381 | `routers/web/repo/pull.go` | 1111-1139 | yes |
| 382 | `routers/web/repo/pull.go` | 1160-1178 | yes |
| 382 | `routers/web/repo/pull.go` | 1195 | yes |
| 382 | `services/pull/merge.go` | 308 | yes |
| 383 | `routers/web/web.go` | 1640-1644 | yes |
| 385 | `routers/web/repo/pull.go` | 1134-1136 | yes |
| 389 | `routers/web/repo/issue_new.go` | 331 | yes |
| 389 | `routers/web/repo/issue_new.go` | 99 | yes |
| 389 | `routers/web/web.go` | 1327-1384 | yes |
| 390 | `routers/web/web.go` | 1386-1390 | yes |
| 390 | `routers/web/web.go` | 1392-1397 | yes |
| 390 | `routers/web/web.go` | 1399-1406 | yes |
| 390 | `routers/web/web.go` | 1415 | yes |
| 391 | `routers/web/web.go` | 1519-1540 | yes |
| 391 | `routers/web/web.go` | 336-348 | yes |
| 392 | `routers/web/web.go` | 1383-1384 | yes |
| 394 | `models/perm/access_mode.go` | 15-22 | yes |
| 394 | `routers/web/web.go` | 430-446 | yes |
| 398 | `services/actions/notifier_helper.go` | 151-160 | yes |
| 399 | `routers/api/actions/runner/runner.go` | 44-100 | yes |
| 400 | `routers/api/actions/runner/runner.go` | 168-215 | yes |
| 400 | `services/actions/task.go` | 66-100 | yes |
| 400 | `services/actions/task.go` | 73-75 | yes |
| 401 | `routers/api/actions/artifacts.go` | 108-130 | yes |
| 401 | `routers/api/actions/runner/runner.go` | 220-288 | yes |
| 402 | `routers/web/web.go` | 1541-1573 | yes |
| 402 | `services/cron/tasks_actions.go` | 27-80 | yes |
| 404 | `routers/api/actions/runner/interceptor.go` | 42-67 | yes |
| 404 | `routers/api/actions/runner/runner.go` | 57-59 | yes |
| 404 | `services/actions/task.go` | 73-75 | yes |
| 408 | `routers/api/packages/api.go` | 92-110 | yes |
| 409 | `routers/api/packages/api.go` | 332-339 | yes |
| 409 | `routers/api/packages/generic/generic.go` | 74-129 | yes |
| 410 | `routers/api/packages/generic/generic.go` | 130-139 | yes |
| 411 | `routers/web/web.go` | 671-690 | yes |
| 411 | `services/cron/tasks_basic.go` | 140 | yes |
| 413 | `routers/api/packages/api.go` | 42-58 | yes |
| 417 | `services/webhook/deliver.go` | 274-300 | yes |
| 417 | `services/webhook/webhook.go` |  | yes |
| 418 | `services/webhook/deliver.go` | 147-190 | yes |
| 418 | `services/webhook/deliver.go` | 277 | yes |
| 419 | `services/cron/tasks_basic.go` | 125 | yes |
| 419 | `services/webhook/deliver.go` | 200-272 | yes |
| 421 | `modules/egress/policies.go` | 86 | yes |
| 421 | `services/webhook/deliver.go` | 154-161 | yes |
| 425 | `routers/web/web.go` | 782-795 | yes |
| 426 | `routers/web/admin/users.go` | 568-587 | yes |
| 427 | `routers/web/auth/auth.go` | 472-483 | yes |
| 428 | `cmd/admin_user.go` | 30 | yes |
| 430 | `routers/web/admin/users.go` | 568-573 | yes |
| 430 | `routers/web/admin/users.go` | 598-608 | yes |
| 434 | `routers/init.go` | 171-172 | yes |
| 434 | `services/cron/cron.go` | 33-49 | yes |
| 435 | `services/cron/tasks_extended.go` | 140-143 | yes |
| 435 | `services/cron/tasks_extended.go` | 196-206 | yes |
| 436 | `routers/api/v1/api.go` | 1828-1831 | yes |
| 436 | `routers/web/admin/admin.go` | 178-186 | yes |
| 436 | `routers/web/web.go` | 752 | yes |
| 438 | `services/cron/tasks.go` | 100-140 | yes |
| 438 | `services/cron/tasks.go` | 151-156 | yes |
| 442 | `cmd/dump.go` | 26-30 | yes |
| 443 | `contrib/upgrade.sh` | 123-135 | yes |
| 443 | `contrib/upgrade.sh` | 3-6 | yes |
| 443 | `contrib/upgrade.sh` | 99-116 | yes |
| 444 | `routers/common/db.go` | 43-58 | yes |
| 444 | `services/versioned_migration/migration.go` | 14-23 | yes |
| 446 | `routers/common/db.go` | 53-56 | yes |
| 450 | `routers/web/org/org.go` | 48-50 | yes |
| 450 | `routers/web/web.go` | 944-947 | yes |
| 451 | `routers/web/org/org.go` | 66-78 | yes |
| 452 | `routers/web/web.go` | 1006-1035 | yes |
| 452 | `routers/web/web.go` | 1067 | yes |
| 452 | `routers/web/web.go` | 955-979 | yes |
| 452 | `routers/web/web.go` | 982-987 | yes |
| 453 | `routers/web/web.go` | 1040 | yes |
| 453 | `routers/web/web.go` | 966 | yes |
| 455 | `routers/web/org/org.go` | 48-50 | yes |
| 455 | `routers/web/org/org.go` | 71-78 | yes |
| 455 | `routers/web/web.go` | 1067 | yes |
| 455 | `routers/web/web.go` | 982-987 | yes |
| 462 | `custom/conf/app.example.ini` | 353-436 | yes |
| 462 | `models/db/engine_init.go` | 28-34 | yes |
| 462 | `modules/setting/database.go` | 15-17 | yes |
| 463 | `custom/conf/app.example.ini` | 1048-1160 | yes |
| 463 | `custom/conf/app.example.ini` | 748-815 | yes |
| 463 | `routers/init.go` | 115-118 | yes |
| 464 | `custom/conf/app.example.ini` | 1940-1972 | yes |
| 464 | `modules/cache/cache.go` | 21-39 | yes |
| 464 | `routers/init.go` | 128 | yes |
| 465 | `custom/conf/app.example.ini` | 1974-2003 | yes |
| 465 | `modules/session/session.go` | 110-135 | yes |
| 465 | `modules/setting/session.go` | 43-62 | yes |
| 466 | `custom/conf/app.example.ini` | 1666-1704 | yes |
| 466 | `modules/queue/manager.go` |  | yes |
| 466 | `services/webhook/deliver.go` | 274-300 | yes |
| 467 | `custom/conf/app.example.ini` | 1592-1651 | yes |
| 467 | `modules/indexer/issues/indexer.go` |  | yes |
| 467 | `services/indexer/` |  | yes |
| 468 | `custom/conf/app.example.ini` | 2891-3017 | yes |
| 468 | `modules/setting/storage.go` | 109-118 | yes |
| 468 | `modules/storage/storage.go` |  | yes |
| 469 | `custom/conf/app.example.ini` | 1798-1938 | yes |
| 469 | `modules/setting/mailer.go` |  | yes |
| 469 | `routers/web/auth/password.go` | 94 | yes |
| 469 | `services/mailer/` |  | yes |
| 470 | `cmd/admin_auth.go` | 22 | yes |
| 470 | `models/auth/source.go` | 137-148 | yes |
| 470 | `services/auth/signin.go` | 27-132 | yes |
| 470 | `services/auth/source/ldap/source.go` | 59 | yes |
| 474 | `modelmigration/v1_10/v100.go` | 55 | yes |
| 474 | `models/db/engine_init.go` | 28-60 | yes |
| 474 | `models/dbfs/dbfile.go` | 125 | yes |
| 474 | `models/dbfs/dbfile.go` | 300 | yes |
| 474 | `models/secret/secret.go` | 79 | yes |
| 474 | `models/webhook/webhook.go` | 215-224 | yes |
| 474 | `services/auth/source/ldap/source.go` | 59-70 | yes |
| 474 | `services/task/task.go` | 73-88 | yes |
| 480 | `custom/conf/app.example.ini` | 1780 | yes |
| 480 | `services/webhook/deliver.go` | 277 | yes |
| 480 | `services/webhook/deliver.go` | 34-92 | yes |
| 480 | `services/webhook/matrix.go` | 55 | yes |
| 480 | `services/webhook/payloader.go` | 112 | yes |
| 481 | `services/migrations/github_graphql.go` | 166 | yes |
| 481 | `services/migrations/http_client.go` | 37 | yes |
| 482 | `services/migrations/bitbucket.go` | 152 | yes |
| 482 | `services/migrations/bitbucket.go` | 179 | yes |
| 482 | `services/migrations/bitbucketserver.go` | 116 | yes |
| 482 | `services/migrations/bitbucketserver.go` | 349 | yes |
| 483 | `services/migrations/codebase.go` | 128 | yes |
| 483 | `services/migrations/codecommit.go` | 300 | yes |
| 483 | `services/migrations/common.go` | 28 | yes |
| 483 | `services/migrations/onedev.go` | 120 | yes |
| 484 | `modules/hcaptcha/hcaptcha.go` | 96 | yes |
| 484 | `modules/mcaptcha/mcaptcha.go` | 44 | yes |
| 484 | `modules/recaptcha/recaptcha.go` | 35 | yes |
| 484 | `modules/setting/service.go` | 180 | yes |
| 484 | `modules/turnstile/turnstile.go` | 47 | yes |
| 485 | `modules/updatechecker/update_checker.go` | 30-34 | yes |
| 485 | `modules/updatechecker/update_checker.go` | 37 | yes |
| 485 | `services/cron/tasks_extended.go` | 163-170 | yes |
| 486 | `modules/auth/password/pwn/pwn.go` | 44-49 | yes |
| 486 | `modules/auth/password/pwn/pwn.go` | 49 | yes |
| 486 | `modules/setting/security.go` | 180 | yes |
| 487 | `custom/conf/app.example.ini` | 1600 | yes |
| 487 | `modules/indexer/internal/elasticsearch/indexer.go` | 64-73 | yes |
| 488 | `modules/lfs/http_client.go` | 236 | yes |
| 489 | `custom/conf/app.example.ini` | 3002-3017 | yes |
| 489 | `modules/storage/azureblob.go` | 222-243 | yes |
| 490 | `routers/web/auth/oauth.go` | 302-307 | yes |
| 490 | `routers/web/auth/oauth.go` | 313 | yes |
| 490 | `routers/web/auth/oauth.go` | 313 | yes |
| 491 | `build/generate-emoji.go` | 81 | yes |
| 491 | `build/generate-gitignores.go` | 45 | yes |
| 492 | `models/unittest/mock_http.go` | 87 | yes |
| 498 | `models/user/user.go` | 101-181 | yes |
| 499 | `models/auth/access_token.go` | 20-33 | yes |
| 500 | `models/auth/twofactor.go` | 60-69 | yes |
| 501 | `models/auth/webauthn.go` | 61 | yes |
| 502 | `models/auth/oauth2.go` | 57-59 | yes |
| 503 | `models/auth/source.go` | 137-148 | yes |
| 504 | `models/auth/session.go` | 15-19 | yes |
| 505 | `models/repo/repo.go` | 153-198 | yes |
| 506 | `models/issues/comment.go` | 373 | yes |
| 506 | `models/issues/issue.go` | 130 | yes |
| 506 | `models/issues/pull.go` | 170 | yes |
| 507 | `models/packages/package.go` | 18 | yes |
| 507 | `models/packages/package_file.go` | 20 | yes |
| 507 | `models/packages/package_version.go` | 23 | yes |
| 508 | `models/webhook/hooktask.go` | 81 | yes |
| 508 | `models/webhook/webhook.go` | 123-145 | yes |
| 509 | `models/actions/run.go` | 79 | yes |
| 509 | `models/actions/runner.go` | 207 | yes |
| 509 | `models/secret/secret.go` | 95 | yes |
| 510 | `models/asymkey/ssh_key.go` | 57 | yes |
| 510 | `models/deploykey/deploykey.go` | 58 | yes |
| 511 | `models/audit/audit_event.go` | 19-37 | yes |
| 517 | `models/user/user.go` | 102 | yes |
| 518 | `models/user/user.go` | 103-104 | yes |
| 519 | `models/user/user.go` | 107 | yes |
| 520 | `models/user/user.go` | 110 | yes |
| 521 | `models/user/user.go` | 111 | yes |
| 522 | `models/user/user.go` | 123-124 | yes |
| 523 | `models/user/user.go` | 117-118 | yes |
| 524 | `models/user/user.go` | 141 | yes |
| 525 | `models/user/user.go` | 144 | yes |
| 526 | `models/user/user.go` | 151 | yes |
| 532 | `models/auth/access_token.go` | 21 | yes |
| 533 | `models/auth/access_token.go` | 22 | yes |
| 534 | `models/auth/access_token.go` | 24 | yes |
| 535 | `models/auth/access_token.go` | 25 | yes |
| 536 | `models/auth/access_token.go` | 26 | yes |
| 537 | `models/auth/access_token.go` | 27 | yes |
| 538 | `models/auth/access_token.go` | 28 | yes |
| 544 | `models/auth/twofactor.go` | 62 | yes |
| 545 | `models/auth/twofactor.go` | 101-112 | yes |
| 545 | `models/auth/twofactor.go` | 63 | yes |
| 546 | `models/auth/twofactor.go` | 64-65 | yes |
| 547 | `models/auth/twofactor.go` | 66 | yes |
| 553 | `models/webhook/webhook.go` | 125-126 | yes |
| 554 | `models/webhook/webhook.go` | 128 | yes |
| 555 | `models/webhook/webhook.go` | 132 | yes |
| 556 | `models/webhook/webhook.go` | 133 | yes |
| 557 | `models/webhook/webhook.go` | 141 | yes |
| 563 | `models/audit/audit_event.go` | 21 | yes |
| 564 | `models/audit/audit_event.go` | 22-24 | yes |
| 565 | `models/audit/audit_event.go` | 25-26 | yes |
| 566 | `models/audit/audit_event.go` | 30-32 | yes |
| 567 | `models/audit/audit_event.go` | 35 | yes |
| 568 | `models/audit/audit_event.go` | 36 | yes |
| 569 | `models/audit/audit_event.go` | 37 | yes |
| 575 | `modules/setting/database.go` | 87-88 | yes |
| 575 | `routers/common/db.go` | 21-41 | yes |
| 575 | `routers/common/db.go` | 28-37 | yes |
| 575 | `routers/common/db.go` | 32-33 | yes |
| 575 | `routers/common/db.go` | 53-56 | yes |
| 575 | `routers/web/healthcheck/check.go` | 76 | yes |
| 576 | `custom/conf/app.example.ini` | 796-810 | yes |
| 576 | `routers/init.go` | 116 | yes |
| 576 | `routers/init.go` | 116-119 | yes |
| 576 | `routers/init.go` | 59-66 | yes |
| 577 | `modules/cache/cache.go` | 27-32 | yes |
| 577 | `routers/init.go` | 128 | yes |
| 577 | `routers/web/auth/password.go` | 99-101 | yes |
| 577 | `routers/web/healthcheck/check.go` | 126-130 | yes |
| 577 | `routers/web/healthcheck/check.go` | 86 | yes |
| 578 | `modules/setting/session.go` | 62-66 | yes |
| 578 | `routers/common/middleware.go` | 110-116 | yes |
| 579 | `cmd/manager.go` | 73 | yes |
| 579 | `modules/setting/queue.go` | 30-46 | yes |
| 579 | `routers/web/web.go` | 772-780 | yes |
| 579 | `routers/web/web.go` | 772-780 | yes |
| 580 | `custom/conf/app.example.ini` | 1611-1612 | yes |
| 580 | `routers/init.go` | 150 | yes |
| 581 | `modules/storage/azureblob.go` | 151-153 | yes |
| 581 | `modules/storage/azureblob.go` | 222-243 | yes |
| 581 | `modules/storage/local.go` | 101 | yes |
| 581 | `modules/storage/local.go` | 86-90 | yes |
| 581 | `routers/init.go` | 125 | yes |
| 582 | `modules/setting/mailer.go` | 107 | yes |
| 582 | `routers/init.go` | 127 | yes |
| 582 | `services/mailer/` |  | yes |
| 583 | `routers/web/auth/auth.go` | 312 | yes |
| 583 | `routers/web/auth/auth.go` | 320-322 | yes |
| 583 | `services/auth/signin.go` | 100-132 | yes |
| 584 | `custom/conf/app.example.ini` | 1780 | yes |
| 584 | `modules/setting/webhook.go` | 34-35 | yes |
| 584 | `routers/web/web.go` | 706-718 | yes |
| 584 | `services/webhook/deliver.go` | 147-272 | yes |
| 584 | `services/webhook/deliver.go` | 154-161 | yes |
| 585 | `custom/conf/app.example.ini` | 2766-2775 | yes |
| 585 | `routers/web/repo/migrate.go` | 282 | yes |
| 585 | `services/task/migrate.go` | 67-68 | yes |
| 586 | `custom/conf/app.example.ini` | 2766-2775 | yes |
| 586 | `routers/web/repo/migrate.go` | 282 | yes |
| 586 | `services/task/migrate.go` | 67-68 | yes |
| 587 | `custom/conf/app.example.ini` | 2766-2775 | yes |
| 587 | `routers/web/repo/migrate.go` | 282 | yes |
| 587 | `services/task/migrate.go` | 67-68 | yes |
| 588 | `modules/hcaptcha/hcaptcha.go` | 96 | yes |
| 588 | `routers/web/auth/auth.go` | 303-305 | yes |
| 589 | `modules/updatechecker/update_checker.go` | 30-40 | yes |
| 589 | `services/cron/tasks.go` | 123-140 | yes |
| 590 | `modules/auth/password/pwn/pwn.go` | 49-52 | yes |
| 590 | `modules/httplib/client_request.go` | 144 | yes |
| 590 | `modules/httplib/client_request.go` | 23 | yes |
| 590 | `modules/httplib/client_request.go` | 40 | yes |
| 590 | `routers/web/auth/auth.go` | 594-600 | yes |
| 591 | `modules/indexer/internal/elasticsearch/indexer.go` | 64-73 | yes |
| 592 | `modules/lfs/http_client.go` | 236 | yes |
| 593 | `modules/storage/azureblob.go` | 151-153 | yes |
| 593 | `modules/storage/azureblob.go` | 222-243 | yes |
| 594 | `routers/web/auth/oauth.go` | 302-307 | yes |
| 595 | `build/generate-emoji.go` | 81 | yes |
| 596 | `models/unittest/mock_http.go` | 87 | yes |
| 602 | `cmd/web.go` | 152-156 | yes |
| 602 | `cmd/web.go` | 285-286 | yes |
| 603 | `cmd/web.go` | 213 | yes |
| 604 | `routers/private/internal.go` | 26-31 | yes |
| 604 | `routers/private/internal.go` | 34-40 | yes |
| 605 | `routers/web/web.go` | 160-165 | yes |
| 606 | `routers/api/v1/api.go` | 311-319 | yes |
| 606 | `routers/api/v1/api.go` | 864-877 | yes |
| 607 | `routers/api/v1/api.go` | 303-306 | yes |
| 608 | `routers/api/v1/api.go` | 249-257 | yes |
| 609 | `routers/api/v1/api.go` | 884-896 | yes |
| 610 | `routers/web/repo/githttp.go` | 124-128 | yes |
| 610 | `routers/web/repo/githttp.go` | 41-45 | yes |
| 611 | `routers/private/serv.go` | 160-175 | yes |
| 612 | `routers/common/db.go` | 29-41 | yes |
| 613 | `routers/common/db.go` | 53-56 | yes |
| 614 | `cmd/admin_user_disable_2fa.go` | 21 | yes |
| 614 | `models/auth/twofactor.go` | 125 | yes |
| 615 | `routers/api/actions/runner/interceptor.go` | 49-67 | yes |
| 615 | `routers/api/actions/runner/runner.go` | 57-59 | yes |
| 616 | `routers/api/packages/api.go` | 42-58 | yes |
| 617 | `routers/web/metrics.go` | 20-31 | yes |
| 618 | `options/locale/locale_en-US.json` | 383 | yes |
| 618 | `routers/web/web.go` | 198-205 | yes |
| 626 | `docker/root/etc/s6/gitea/setup` | 28-30 | yes |
| 626 | `docker/root/etc/templates/app.ini` | 30 | yes |
| 626 | `docker/root/etc/templates/app.ini` | 30 | yes |
| 626 | `routers/install/install.go` | 100 | yes |
| 626 | `routers/install/install.go` | 74 | yes |
| 626 | `templates/install.tmpl` | 42 | yes |
| 627 | `custom/conf/app.example.ini` | 872 | yes |
| 627 | `modules/setting/service.go` | 175 | yes |
| 627 | `services/auth/reverseproxy.go` | 110-118 | yes |
| 627 | `services/auth/reverseproxy.go` | 47-52 | yes |
| 627 | `services/auth/reverseproxy.go` | 64-68 | yes |
| 628 | `models/auth/twofactor.go` | 101-104 | yes |
| 628 | `modules/setting/security.go` | 147-151 | yes |
| 628 | `routers/install/install.go` | 393-400 | yes |
| 628 | `services/task/task.go` | 73-88 | yes |
| 629 | `custom/conf/app.example.ini` | 880 | yes |
| 629 | `modules/setting/security.go` | 167 | yes |
| 629 | `modules/setting/security.go` | 209-212 | yes |
| 629 | `modules/setting/service.go` | 258 | yes |
| 629 | `routers/web/auth/auth.go` | 303-322 | yes |
| 629 | `services/auth/signin.go` | 27-132 | yes |
| 630 | `modules/setting/security.go` | 224 | yes |
| 630 | `routers/api/v1/api.go` | 932-936 | yes |
| 630 | `services/auth/oauth2.go` | 83-97 | yes |
| 631 | `routers/private/internal.go` | 34-38 | yes |
| 632 | `modules/setting/metrics.go` | 13 | yes |
| 632 | `modules/setting/metrics.go` | 14 | yes |
| 632 | `routers/web/metrics.go` | 14-17 | yes |
| 633 | `models/webhook/webhook.go` | 132 | yes |
| 633 | `models/webhook/webhook.go` | 215-224 | yes |
| 633 | `services/webhook/deliver.go` | 91 | yes |
| 634 | `models/auth/twofactor.go` | 101-104 | yes |
| 635 | `routers/web/auth/auth.go` | 467-489 | yes |
| 635 | `routers/web/web.go` | 725-740 | yes |
| 635 | `routers/web/web.go` | 734 | yes |
| 636 | `cmd/web.go` | 244-257 | yes |
| 636 | `custom/conf/app.example.ini` | 302 | yes |
| 636 | `modules/setting/server.go` | 278 | yes |
| 642 | `cmd/web.go` | 343-366 | yes |
| 642 | `custom/conf/app.example.ini` | 63 | yes |
| 643 | `modules/setting/session.go` | 38-40 | yes |
| 643 | `routers/web/web.go` | 179 | yes |
| 643 | `routers/web/web.go` | 221 | yes |
| 644 | `modules/setting/security.go` | 196-199 | yes |
| 644 | `routers/web/auth/auth.go` | 326-366 | yes |
| 645 | `modules/session/session.go` | 125-135 | yes |
| 645 | `modules/web/middleware/cookie.go` | 60-75 | yes |
| 646 | `modules/setting/service.go` | 258 | yes |
| 646 | `routers/common/qos.go` | 38-60 | yes |
| 646 | `routers/web/auth/auth.go` | 288-322 | yes |
| 647 | `models/audit/audit_event.go` | 19-37 | yes |
| 647 | `modules/setting/audit.go` | 21-28 | yes |
| 648 | `cmd/dump.go` | 26-30 | yes |
| 648 | `cmd/restore_repo.go` | 18-25 | yes |
| 649 | `cmd/generate.go` | 22 | yes |
| 649 | `modules/setting/security.go` | 105-133 | yes |
| 649 | `modules/setting/security.go` | 147-150 | yes |
| 650 | `custom/conf/app.example.ini` | 539-562 | yes |
| 650 | `services/migrations/http_client.go` | 37 | yes |
| 650 | `services/webhook/deliver.go` | 277 | yes |
| 657 | `README.md` | 14-20 | yes |
| 658 | `CONTRIBUTING.md` | 265-267 | yes |
| 658 | `MAINTAINERS` |  | yes |
| 658 | `MAINTAINERS` |  | yes |
| 659 | `docs/community-governance.md` | 130-244 | yes |
| 659 | `docs/community-governance.md` | 35-130 | yes |
| 661 | `AGENTS.md` | 7 | yes |
| 661 | `README.md` | 34-38 | yes |
| 661 | `docs/` |  | yes |
| 662 | `.github/workflows/release-nightly.yml` | 37-61 | yes |
| 662 | `.github/workflows/release-tag-version.yml` | 33-34 | yes |
| 662 | `CONTRIBUTING.md` | 173-175 | yes |
| 662 | `CONTRIBUTING.md` | 263 | yes |
| 662 | `docs/release-management.md` | 1-74 | yes |
| 663 | `Makefile` | 368-370 | yes |
| 663 | `models/user/user_test.go` |  | yes |
| 663 | `services/pull/merge_test.go` |  | yes |
| 664 | `.github/workflows/pull-db-tests.yml` | 93-114 | yes |
| 664 | `Makefile` | 436-441 | yes |
| 664 | `tests/integration/` |  | yes |
| 664 | `tests/integration/actions_runner_test.go` |  | yes |
| 664 | `tests/integration/api_auth_test.go` |  | yes |
| 664 | `tests/integration/api_packages_test.go` |  | yes |
| 664 | `tests/integration/api_public_only_test.go` |  | yes |
| 664 | `tests/integration/auth_ldap_test.go` |  | yes |
| 664 | `tests/integration/git_push_test.go` |  | yes |
| 664 | `tests/integration/git_smart_http_test.go` |  | yes |
| 664 | `tests/integration/oauth_test.go` |  | yes |
| 664 | `tests/integration/pull_merge_test.go` |  | yes |
| 664 | `tests/integration/signin_test.go` |  | yes |
| 664 | `tests/integration/signup_test.go` |  | yes |
| 665 | `Makefile` | 453-465 | yes |
| 666 | `Makefile` | 473 | yes |
| 666 | `tests/e2e/` |  | yes |
| 666 | `tests/e2e/login.test.ts` |  | yes |
| 666 | `tests/e2e/pr-review.test.ts` |  | yes |
| 667 | `Makefile` | 373-375 | yes |
| 667 | `web_src/js/` |  | yes |
| 667 | `web_src/js/utils.test.ts` |  | yes |
| 668 | `tests/fuzz/fuzz_test.go` |  | yes |
| 672 | `./go.mod` | 3-5 | yes |
| 672 | `Dockerfile` | 3 | yes |
| 672 | `package.json` | 4-7 | yes |
| 673 | `.github/workflows/pull-db-tests.yml` | 93-248 | yes |
| 673 | `Makefile` | 266 | yes |
| 674 | `Makefile` | 498-500 | yes |
| 675 | `Makefile` | 221-227 | yes |
| 697 | `routers/web/githttp.go` | 12-24 | yes |
| 697 | `routers/web/repo/githttp.go` | 130-161 | yes |
| 697 | `routers/web/web.go` | 124-160 | yes |
| 715 | `cmd/hook.go` | 49-92 | yes |
| 715 | `cmd/serv.go` | 40 | yes |
| 715 | `routers/private/hook_pre_receive.go` | 75-111 | yes |
| 715 | `routers/private/serv.go` | 68 | yes |
| 728 | `routers/api/actions/runner/runner.go` | 168-288 | yes |
| 728 | `services/actions/notifier_helper.go` | 151-160 | yes |
| 728 | `services/actions/task.go` | 66-100 | yes |
| 742 | `models/audit/audit_event.go` | 22 | yes |
| 742 | `models/auth/access_token.go` | 22 | yes |
| 742 | `models/auth/twofactor.go` | 62 | yes |
| 742 | `models/user/user.go` | 117-118 | yes |
| 742 | `models/webhook/webhook.go` | 125-126 | yes |
| 744 | `Dockerfile.rootless` | 40 | yes |
| 744 | `Dockerfile.rootless` | 48 | yes |
| 744 | `Dockerfile` | 41 | yes |
| 744 | `Dockerfile` | 53 | yes |
| 750 | `services/context/context.go` | 174-176 | yes |
| 751 | `routers/web/web.go` | 1000-1040 | yes |
| 752 | `models/unit/unit.go` | 23-36 | yes |
| 753 | `models/perm/access_mode.go` | 15-22 | yes |
| 754 | `models/auth/access_token_scope.go` | 58-90 | yes |
| 755 | `models/auth/access_token_scope.go` | 60 | yes |
| 756 | `models/deploykey/deploykey.go` | 58 | yes |
| 756 | `routers/web/web.go` | 136-138 | yes |
| 757 | `models/auth/source.go` | 137-148 | yes |
| 758 | `services/auth/reverseproxy.go` | 47-52 | yes |
| 759 | `routers/web/admin/users.go` | 568-587 | yes |
| 760 | `routers/private/internal.go` | 25-43 | yes |
| 761 | `routers/init.go` | 184 | yes |
| 762 | `cmd/serv.go` | 40 | yes |
| 763 | `cmd/hook.go` | 49-92 | yes |
| 764 | `cmd/hook.go` | 92 | yes |
| 765 | `routers/api/actions/runner/runner.go` | 44-100 | yes |
| 766 | `routers/api/actions/runner/runner.go` | 51-60 | yes |
| 767 | `models/actions/run.go` | 79 | yes |
| 767 | `services/actions/task.go` | 66-100 | yes |
| 768 | `routers/web/web.go` | 507-514 | yes |
| 769 | `routers/api/packages/api.go` | 92-110 | yes |
| 770 | `routers/web/web.go` | 671-690 | yes |
| 771 | `routers/common/lfs.go` | 17-29 | yes |
| 772 | `modules/egress/policies.go` | 86 | yes |
| 773 | `routers/common/qos.go` | 38-60 | yes |
| 774 | `services/cron/tasks.go` | 100-140 | yes |
| 775 | `services/cron/tasks.go` | 139 | yes |
| 776 | `models/audit/audit_event.go` | 19-37 | yes |
| 777 | `modelmigration/v1_10/v100.go` | 55 | yes |
| 777 | `services/migrations/migrate.go` |  | yes |
| 778 | `models/repo/mirror.go` | 41 | yes |
| 778 | `services/cron/tasks_basic.go` | 31 | yes |
| 779 | `models/git/protected_branch.go` | 83 | yes |
| 780 | `models/user/user.go` | 60-62 | yes |
| 781 | `routers/install/install.go` | 64-67 | yes |
| 793 | `web_src/` |  | yes |
| 804 | `docker/root/etc/templates/app.ini` | 52 | yes |
| 804 | `routers/install/install.go` | 74 | yes |
| 805 | `modules/setting/security.go` | 196-199 | yes |
| 805 | `routers/web/auth/auth.go` | 303-322 | yes |
| 806 | `modules/setting/security.go` | 147-151 | yes |
| 807 | `modules/setting/security.go` | 224 | yes |
| 808 | `services/auth/reverseproxy.go` | 47-52 | yes |
| 809 | `custom/conf/app.example.ini` | 63 | yes |
| 809 | `modules/setting/session.go` | 64 | yes |
| 810 | `cmd/dump.go` | 26-30 | yes |
| 810 | `contrib/upgrade.sh` | 32 | yes |
| 811 | `routers/private/internal.go` | 37 | yes |
| 812 | `routers/web/metrics.go` | 14-17 | yes |
| 813 | `models/webhook/webhook.go` | 132 | yes |
| 813 | `models/webhook/webhook.go` | 215-224 | yes |
| 814 | `models/auth/twofactor.go` | 101-104 | yes |
| 815 | `routers/web/web.go` | 734 | yes |
| 816 | `cmd/web.go` | 244-257 | yes |
| 817 | `models/audit/audit_event.go` | 19-37 | yes |
| 827 | `./go.mod` | 3-5 | yes |
| 827 | `Dockerfile` | 3 | yes |
| 828 | `docs/build-setup.md` | 25-27 | yes |
| 828 | `package.json` | 4-7 | yes |
| 828 | `pyproject.toml` | 4 | yes |
| 829 | `Makefile` | 38-42 | yes |
| 829 | `modules/setting/database.go` | 15-17 | yes |
| 830 | `Dockerfile` | 55-66 | yes |
| 830 | `routers/init.go` | 115-119 | yes |
| 831 | `README.md` | 19-22 | yes |
| 835 | `docker/root/etc/templates/app.ini` | 25 | yes |
| 835 | `routers/common/db.go` | 43-58 | yes |
| 835 | `routers/install/install.go` | 267 | yes |
| 835 | `services/versioned_migration/migration.go` | 14-23 | yes |
| 836 | `cmd/web.go` | 213 | yes |
| 837 | `custom/conf/app.example.ini` | 1592-2003 | yes |
| 837 | `modules/setting/session.go` | 50-56 | yes |
| 841 | `modules/setting/session.go` | 44-76 | yes |
| 841 | `modules/setting/session.go` | 60 | yes |
| 842 | `modules/setting/security.go` | 145-153 | yes |
| 843 | `routers/web/auth/auth.go` | 326-366 | yes |
| 843 | `routers/web/auth/auth.go` | 397-403 | yes |
| 844 | `custom/conf/app.example.ini` | 626-632 | yes |
| 845 | `modules/auth/password/hash/setting.go` | 13 | yes |
| 851 | `modules/setting/database.go` | 87-88 | yes |
| 851 | `routers/common/db.go` | 29-41 | yes |
| 852 | `routers/common/db.go` | 53-56 | yes |
| 853 | `routers/private/internal.go` | 25-41 | yes |
| 854 | `cmd/web.go` | 213 | yes |
| 855 | `routers/api/actions/runner/interceptor.go` | 49-67 | yes |
| 856 | `routers/api/v1/api.go` | 1828-1831 | yes |
| 856 | `services/cron/tasks.go` | 123-140 | yes |
| 857 | `cmd/manager.go` | 18-95 | yes |
| 857 | `routers/common/qos.go` | 38-60 | yes |
| 857 | `routers/web/web.go` | 765-780 | yes |
| 863 | `.github/workflows/pull-compliance.yml` | 81-109 | yes |
| 863 | `Makefile` | 477-483 | yes |
| 864 | `Makefile` | 368-370 | yes |
| 864 | `Makefile` | 436-441 | yes |
| 864 | `Makefile` | 453-465 | yes |
| 864 | `Makefile` | 473 | yes |
| 865 | `.github/workflows/release-nightly.yml` | 101-186 | yes |
| 865 | `.github/workflows/release-nightly.yml` | 37-61 | yes |
| 865 | `.github/workflows/release-tag-version.yml` | 154-168 | yes |
| 865 | `.github/workflows/release-tag-version.yml` | 16-30 | yes |
| 865 | `Dockerfile.rootless` | 40 | yes |
| 865 | `Dockerfile` | 41 | yes |
| 865 | `docker/root` |  | yes |
| 865 | `docker/rootless` |  | yes |
| 866 | `contrib/upgrade.sh` | 123-135 | yes |
| 866 | `contrib/upgrade.sh` | 3-6 | yes |
| 866 | `contrib/upgrade.sh` | 99-116 | yes |
| 866 | `routers/common/db.go` | 43-58 | yes |
| 867 | `contrib/upgrade.sh` | 132 | yes |
| 868 | `cmd/dump.go` | 26-30 | yes |
| 868 | `contrib/upgrade.sh` | 32 | yes |
| 869 | `cmd/restore_repo.go` | 18-25 | yes |
| 870 | `cmd/generate.go` | 56-73 | yes |
| 870 | `modules/setting/security.go` | 147-150 | yes |
| 877 | `custom/conf/app.example.ini` | 446 | yes |
| 878 | `custom/conf/app.example.ini` | 453 | yes |
| 879 | `docker/root/etc/templates/app.ini` | 30 | yes |
| 880 | `modules/setting/lfs.go` | 79 | yes |
| 881 | `modules/setting/oauth2.go` | 147 | yes |
| 882 | `modules/setting/service.go` | 185 | yes |
| 883 | `modules/setting/service.go` | 188 | yes |
| 884 | `modules/setting/service.go` | 190 | yes |
| 885 | `modules/setting/service.go` | 193 | yes |
| 886 | `modules/setting/storage.go` | 109 | yes |
| 887 | `modules/setting/storage.go` | 118 | yes |
| 888 | `routers/install/install.go` | 356 | yes |
| 889 | `cmd/web.go` | 180 | yes |
| 890 | `cmd/web.go` | 323 | yes |
| 891 | `custom/conf/app.example.ini` | 363 | yes |
| 892 | `custom/conf/app.example.ini` | 364 | yes |
| 893 | `custom/conf/app.example.ini` | 365 | yes |
| 894 | `custom/conf/app.example.ini` | 366 | yes |
| 895 | `custom/conf/app.example.ini` | 442 | yes |
| 896 | `custom/conf/app.example.ini` | 603 | yes |
| 897 | `custom/conf/app.example.ini` | 663 | yes |
| 898 | `custom/conf/app.example.ini` | 666 | yes |
| 899 | `docker/root/etc/templates/app.ini` | 1 | yes |
| 900 | `docker/root/etc/templates/app.ini` | 2 | yes |
| 901 | `docker/root/etc/templates/app.ini` | 5 | yes |
| 902 | `docker/root/etc/templates/app.ini` | 8 | yes |
| 903 | `docker/root/etc/templates/app.ini` | 11 | yes |
| 904 | `docker/root/etc/templates/app.ini` | 14 | yes |
| 905 | `docker/root/etc/templates/app.ini` | 15 | yes |
| 906 | `docker/root/etc/templates/app.ini` | 16 | yes |
| 907 | `docker/root/etc/templates/app.ini` | 17 | yes |
| 908 | `docker/root/etc/templates/app.ini` | 18 | yes |
| 909 | `docker/root/etc/templates/app.ini` | 19 | yes |
| 910 | `docker/root/etc/templates/app.ini` | 20 | yes |
| 911 | `docker/root/etc/templates/app.ini` | 21 | yes |
| 912 | `docker/root/etc/templates/app.ini` | 22 | yes |
| 913 | `docker/root/etc/templates/app.ini` | 25 | yes |
| 914 | `docker/root/etc/templates/app.ini` | 31 | yes |
| 915 | `docker/root/etc/templates/app.ini` | 34 | yes |
| 916 | `docker/root/etc/templates/app.ini` | 37 | yes |
| 917 | `docker/root/etc/templates/app.ini` | 40 | yes |
| 918 | `docker/root/etc/templates/app.ini` | 41 | yes |
| 919 | `docker/root/etc/templates/app.ini` | 44 | yes |
| 920 | `docker/root/etc/templates/app.ini` | 49 | yes |
| 921 | `docker/root/etc/templates/app.ini` | 56 | yes |
| 922 | `docker/root/etc/templates/app.ini` | 57 | yes |
| 923 | `docker/root/etc/templates/app.ini` | 60 | yes |
| 924 | `docker/rootless/etc/templates/app.ini` | 2 | yes |
| 925 | `docker/rootless/etc/templates/app.ini` | 21 | yes |
| 926 | `docker/rootless/etc/templates/app.ini` | 24 | yes |
| 927 | `modules/setting/actions.go` | 133 | yes |
| 928 | `modules/setting/actions.go` | 134 | yes |
| 929 | `modules/setting/actions.go` | 135 | yes |
| 930 | `modules/setting/admin.go` | 31 | yes |
| 931 | `modules/setting/admin.go` | 32 | yes |
| 932 | `modules/setting/admin.go` | 33 | yes |
| 933 | `modules/setting/admin.go` | 34 | yes |
| 934 | `modules/setting/attachment.go` | 29 | yes |
| 935 | `modules/setting/attachment.go` | 30 | yes |
| 936 | `modules/setting/attachment.go` | 31 | yes |
| 937 | `modules/setting/attachment.go` | 32 | yes |
| 938 | `modules/setting/cache.go` | 47 | yes |
| 939 | `modules/setting/cache.go` | 51 | yes |
| 940 | `modules/setting/camo.go` | 22 | yes |
| 941 | `modules/setting/database.go` | 63 | yes |
| 942 | `modules/setting/database.go` | 64 | yes |
| 943 | `modules/setting/database.go` | 65 | yes |
| 944 | `modules/setting/database.go` | 69 | yes |
| 945 | `modules/setting/database.go` | 75 | yes |
| 946 | `modules/setting/database.go` | 77 | yes |
| 947 | `modules/setting/database.go` | 79 | yes |
| 948 | `modules/setting/database.go` | 83 | yes |
| 949 | `modules/setting/database.go` | 85 | yes |
| 950 | `modules/setting/database.go` | 87 | yes |
| 951 | `modules/setting/database.go` | 88 | yes |
| 952 | `modules/setting/database.go` | 89 | yes |
| 953 | `modules/setting/database.go` | 90 | yes |
| 954 | `modules/setting/git.go` | 96 | yes |
| 955 | `modules/setting/global_lock.go` | 21 | yes |
| 956 | `modules/setting/global_lock.go` | 25 | yes |
| 957 | `modules/setting/i18n.go` | 59 | yes |
| 958 | `modules/setting/i18n.go` | 63 | yes |
| 959 | `modules/setting/indexer.go` | 55 | yes |
| 960 | `modules/setting/indexer.go` | 63 | yes |
| 961 | `modules/setting/indexer.go` | 76 | yes |
| 962 | `modules/setting/indexer.go` | 78 | yes |
| 963 | `modules/setting/indexer.go` | 79 | yes |
| 964 | `modules/setting/indexer.go` | 80 | yes |
| 965 | `modules/setting/indexer.go` | 81 | yes |
| 966 | `modules/setting/indexer.go` | 85 | yes |
| 967 | `modules/setting/indexer.go` | 86 | yes |
| 968 | `modules/setting/indexer.go` | 88 | yes |
| 969 | `modules/setting/indexer.go` | 89 | yes |
| 970 | `modules/setting/indexer.go` | 90 | yes |
| 971 | `modules/setting/indexer.go` | 91 | yes |
| 972 | `modules/setting/indexer.go` | 92 | yes |
| 973 | `modules/setting/indexer.go` | 93 | yes |
| 974 | `modules/setting/lfs.go` | 63 | yes |
| 975 | `modules/setting/log.go` | 39 | yes |
| 976 | `modules/setting/log.go` | 40 | yes |
| 977 | `modules/setting/log.go` | 49 | yes |
| 978 | `modules/setting/log.go` | 51 | yes |
| 979 | `modules/setting/log.go` | 52 | yes |
| 980 | `modules/setting/log.go` | 59 | yes |
| 981 | `modules/setting/log.go` | 64 | yes |
| 982 | `modules/setting/log.go` | 65 | yes |
| 983 | `modules/setting/log.go` | 67 | yes |
| 984 | `modules/setting/log.go` | 73 | yes |
| 985 | `modules/setting/log.go` | 74 | yes |
| 986 | `modules/setting/log.go` | 80 | yes |
| 987 | `modules/setting/log.go` | 86 | yes |
| 988 | `modules/setting/log.go` | 87 | yes |
| 989 | `modules/setting/log.go` | 93 | yes |
| 990 | `modules/setting/mailer.go` | 72 | yes |
| 991 | `modules/setting/mailer.go` | 81 | yes |
| 992 | `modules/setting/mailer.go` | 91 | yes |
| 993 | `modules/setting/mailer.go` | 92 | yes |
| 994 | `modules/setting/mailer.go` | 95 | yes |
| 995 | `modules/setting/mailer.go` | 101 | yes |
| 996 | `modules/setting/mailer.go` | 103 | yes |
| 997 | `modules/setting/mailer.go` | 104 | yes |
| 998 | `modules/setting/mailer.go` | 105 | yes |
| 999 | `modules/setting/mailer.go` | 106 | yes |
| 1000 | `modules/setting/mailer.go` | 107 | yes |
| 1001 | `modules/setting/mailer.go` | 108 | yes |
| 1002 | `modules/setting/mailer.go` | 109 | yes |
| 1003 | `modules/setting/mailer.go` | 109 | yes |
| 1004 | `modules/setting/mailer.go` | 163 | yes |
| 1005 | `modules/setting/mailer.go` | 218 | yes |
| 1006 | `modules/setting/mailer.go` | 228 | yes |
| 1007 | `modules/setting/markup.go` | 80 | yes |
| 1008 | `modules/setting/markup.go` | 137 | yes |
| 1009 | `modules/setting/markup.go` | 178 | yes |
| 1010 | `modules/setting/markup.go` | 183 | yes |
| 1011 | `modules/setting/markup.go` | 184 | yes |
| 1012 | `modules/setting/markup.go` | 191 | yes |
| 1013 | `modules/setting/markup.go` | 245 | yes |
| 1014 | `modules/setting/markup.go` | 251 | yes |
| 1015 | `modules/setting/markup.go` | 261 | yes |
| 1016 | `modules/setting/markup.go` | 262 | yes |
| 1017 | `modules/setting/markup.go` | 272 | yes |
| 1018 | `modules/setting/markup.go` | 281 | yes |
| 1019 | `modules/setting/markup.go` | 287 | yes |
| 1020 | `modules/setting/migrations.go` | 24 | yes |
| 1021 | `modules/setting/migrations.go` | 25 | yes |
| 1022 | `modules/setting/migrations.go` | 28 | yes |
| 1023 | `modules/setting/migrations.go` | 53 | yes |
| 1024 | `modules/setting/oauth2.go` | 65 | yes |
| 1025 | `modules/setting/oauth2.go` | 67 | yes |
| 1026 | `modules/setting/oauth2.go` | 68 | yes |
| 1030 | `options/label/Advanced.yaml` |  | yes |
| 1037 | `custom/conf/app.example.ini` | 442 | yes |
| 1037 | `routers/install/install.go` | 64-74 | yes |
| 1038 | `modules/setting/security.go` | 147-151 | yes |
| 1039 | `modules/setting/security.go` | 224 | yes |
| 1040 | `modules/setting/security.go` | 193-199 | yes |
| 1041 | `modules/setting/service.go` | 141 | yes |
| 1042 | `modules/setting/service.go` | 175 | yes |
| 1043 | `modules/setting/metrics.go` | 14 | yes |
| 1043 | `routers/web/metrics.go` | 14-17 | yes |
| 1044 | `cmd/web.go` | 293-295 | yes |
| 1044 | `modules/setting/server.go` | 278 | yes |
| 1045 | `modules/setting/audit.go` | 21-28 | yes |
| 1085 | `services/cron/tasks_extended.go` | 140-143 | yes |
| 1085 | `services/cron/tasks_extended.go` | 163-170 | yes |
| 1091 | `./go.mod` | 3-5 | yes |
| 1091 | `docs/build-setup.md` | 13-27 | yes |
| 1091 | `package.json` | 4-7 | yes |
| 1092 | `Makefile` | 555-556 | yes |
| 1093 | `Makefile` | 477-478 | yes |
| 1094 | `Makefile` | 57 | yes |
| 1094 | `cmd/web.go` | 41 | yes |
| 1095 | `Makefile` | 368-370 | yes |
| 1097 | `Makefile` | 30-33 | yes |
| 1097 | `Makefile` | 373-375 | yes |
| 1097 | `Makefile` | 436-441 | yes |
| 1097 | `Makefile` | 453 | yes |
| 1097 | `Makefile` | 473 | yes |
| 1097 | `Makefile` | 555-575 | yes |
| 1097 | `Makefile` | 582-584 | yes |
| 1097 | `cmd/web.go` | 45-52 | yes |
| 1097 | `docs/development.md` | 38 | yes |
| 1097 | `go.mod` |  | yes |
| 1097 | `package.json` |  | yes |

## Verification

**Source-to-claim audit:** performed (auditor: independent). 159 rows (47 superseded): 156 Supported, 1 Corrected, 0 Downgraded, 2 Answerable.

| Section | IDs with a register row |
|---|---|
| 4 | 25 of 25 |
| 6 | 23 of 23 |
| 8.1 | 9 of 9 |
| 8.3 | 13 of 13 |
| 10.1 | 11 of 11 |
| 14 | 8 of 8 |
| 15 | 14 of 14 |
| 7 (workflows) | 15 of 15 |
