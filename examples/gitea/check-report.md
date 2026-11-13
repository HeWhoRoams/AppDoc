# Check: PASS

**Scope.** This Check verifies **resolution and structure**: every Citation points to a real file and line inside the Target (see the Citation register), and every Evidence Register row's anchor text appears in the lines it cites. It does **not** judge whether a claim's wording follows from those lines; that is the source-to-claim audit, recorded in `evidence.jsonl`. A PASS is not an accuracy certification.

## Citation register

| Doc line | Cited path | Line/range | Resolved |
|---|---|---|---|
| 12 | `cmd/web.go` | 285 | yes |
| 13 | `routers/web/auth/auth.go` | 288 | yes |
| 14 | `routers/web/repo/repo.go` | 193 | yes |
| 15 | `routers/web/repo/issue_new.go` | 331 | yes |
| 16 | `routers/web/repo/pull.go` | 1088 | yes |
| 17 | `routers/private/hook_pre_receive.go` | 75 | yes |
| 18 | `services/webhook/deliver.go` | 274 | yes |
| 19 | `services/cron/tasks_actions.go` | 27 | yes |
| 20 | `cmd/admin_user.go` | 30 | yes |
| 21 | `contrib/upgrade.sh` | 1 | yes |
| 22 | `cmd/dump.go` | 26 | yes |
| 22 | `cmd/restore_repo.go` | 18 | yes |
| 23 | `cmd/generate.go` | 33 | yes |
| 24 | `routers/api/v1/api.go` | 277 | yes |
| 25 | `custom/conf/app.example.ini` | 1 | yes |
| 26 | `routers/api/v1/api.go` | 111 | yes |
| 43 | `modules/` |  | yes |
| 44 | `tests/` |  | yes |
| 45 | `services/` |  | yes |
| 46 | `templates/` |  | yes |
| 47 | `routers/` |  | yes |
| 48 | `public/` |  | yes |
| 49 | `models/` |  | yes |
| 50 | `web_src/` |  | yes |
| 51 | `modelmigration/` |  | yes |
| 52 | `options/` |  | yes |
| 53 | `cmd/` |  | yes |
| 54 | `.github/` |  | yes |
| 55 | `contrib/` |  | yes |
| 56 | `docs/` |  | yes |
| 57 | `docker/` |  | yes |
| 58 | `tools/` |  | yes |
| 59 | `build/` |  | yes |
| 60 | `assets/` |  | yes |
| 61 | `snap/` |  | yes |
| 62 | `.devcontainer/` |  | yes |
| 63 | `custom/` |  | yes |
| 68 | `package.json` |  | yes |
| 68 | `pyproject.toml` |  | yes |
| 68 | `web_src/` |  | yes |
| 70 | `CONTRIBUTING.md` |  | yes |
| 70 | `MAINTAINERS` |  | yes |
| 70 | `build/` |  | yes |
| 70 | `modelmigration/` |  | yes |
| 70 | `options/locale/` |  | yes |
| 70 | `public/` |  | yes |
| 70 | `templates/` |  | yes |
| 70 | `templates/swagger/` |  | yes |
| 70 | `tests/` |  | yes |
| 70 | `web_src/` |  | yes |
| 74 | `README.md` | 14-19 | yes |
| 74 | `routers/api/actions/runner/runner.go` | 30 | yes |
| 74 | `routers/init.go` | 176-207 | yes |
| 82 | `cmd/main.go` |  | yes |
| 82 | `modules/ssh/server.go` |  | yes |
| 82 | `routers/init.go` | 172 | yes |
| 82 | `routers/init.go` | 176-207 | yes |
| 84 | `custom/conf/app.example.ini` | 1592 | yes |
| 84 | `custom/conf/app.example.ini` | 1666 | yes |
| 84 | `custom/conf/app.example.ini` | 1798 | yes |
| 84 | `custom/conf/app.example.ini` | 1899 | yes |
| 84 | `custom/conf/app.example.ini` | 1940 | yes |
| 84 | `custom/conf/app.example.ini` | 1974 | yes |
| 84 | `custom/conf/app.example.ini` | 2891 | yes |
| 84 | `custom/conf/app.example.ini` | 363-396 | yes |
| 84 | `modules/hcaptcha/hcaptcha.go` | 96 | yes |
| 84 | `routers/api/actions/runner/interceptor.go` | 46 | yes |
| 84 | `routers/init.go` | 115 | yes |
| 84 | `services/auth/source/` |  | yes |
| 84 | `services/cron/tasks_extended.go` | 163-168 | yes |
| 84 | `services/migrations/github_graphql.go` | 166 | yes |
| 84 | `services/webhook/deliver.go` | 277 | yes |
| 90 | `cmd/admin.go` | 22 | yes |
| 90 | `cmd/doctor.go` | 28 | yes |
| 90 | `cmd/dump.go` | 26 | yes |
| 90 | `cmd/generate.go` | 22 | yes |
| 90 | `cmd/hook.go` | 33 | yes |
| 90 | `cmd/main.go` |  | yes |
| 90 | `cmd/manager.go` | 18 | yes |
| 90 | `cmd/migrate.go` | 19 | yes |
| 90 | `cmd/web.go` | 332-392 | yes |
| 90 | `cmd/web.go` | 39-76 | yes |
| 91 | `routers/` |  | yes |
| 91 | `routers/api/actions/actions.go` | 17 | yes |
| 91 | `routers/api/packages/api.go` |  | yes |
| 91 | `routers/api/v1/api.go` | 939 | yes |
| 91 | `routers/init.go` | 176-214 | yes |
| 91 | `routers/private/internal.go` | 71 | yes |
| 91 | `routers/web/web.go` | 257-321 | yes |
| 92 | `services/` |  | yes |
| 92 | `services/actions/run.go` |  | yes |
| 92 | `services/auth/auth.go` |  | yes |
| 92 | `services/cron/cron.go` |  | yes |
| 92 | `services/mailer/` |  | yes |
| 92 | `services/migrations/` |  | yes |
| 92 | `services/pull/` |  | yes |
| 92 | `services/repository/` |  | yes |
| 92 | `services/webhook/deliver.go` | 274 | yes |
| 93 | `modelmigration/migrations.go` |  | yes |
| 93 | `models/` |  | yes |
| 93 | `models/issues/issue.go` | 130 | yes |
| 93 | `models/repo/repo.go` | 225 | yes |
| 93 | `models/user/user.go` | 197 | yes |
| 94 | `modules/` |  | yes |
| 94 | `modules/egress/` |  | yes |
| 94 | `modules/git/` |  | yes |
| 94 | `modules/indexer/` |  | yes |
| 94 | `modules/log/` |  | yes |
| 94 | `modules/markup/` |  | yes |
| 94 | `modules/queue/` |  | yes |
| 94 | `modules/setting/session.go` | 64 | yes |
| 94 | `modules/storage/minio.go` | 129 | yes |
| 95 | `package.json` | 3-6 | yes |
| 95 | `templates/` |  | yes |
| 95 | `web_src/` |  | yes |
| 96 | `routers/init.go` | 114-173 | yes |
| 119 | `routers/init.go` | 172 | yes |
| 119 | `routers/init.go` | 176-207 | yes |
| 119 | `routers/private/internal.go` | 71-78 | yes |
| 123 | `routers/web/web.go` | 124-158 | yes |
| 123 | `routers/web/web.go` | 160-165 | yes |
| 124 | `models/auth/access_token_scope.go` | 58-90 | yes |
| 124 | `routers/api/v1/api.go` | 277-308 | yes |
| 124 | `routers/api/v1/api.go` | 851-862 | yes |
| 125 | `services/auth/basic.go` | 71-146 | yes |
| 126 | `routers/web/web.go` | 177-245 | yes |
| 126 | `routers/web/web.go` | 893-909 | yes |
| 127 | `routers/api/v1/api.go` | 311-318 | yes |
| 127 | `routers/api/v1/api.go` | 350-357 | yes |
| 127 | `routers/api/v1/api.go` | 391-410 | yes |
| 127 | `routers/api/v1/api.go` | 421 | yes |
| 128 | `routers/private/internal.go` | 25-43 | yes |
| 129 | `routers/api/actions/runner/interceptor.go` | 46-107 | yes |
| 130 | `routers/web/auth/auth.go` | 326-365 | yes |
| 130 | `services/auth/signin.go` | 104-125 | yes |
| 130 | `services/auth/signin.go` | 27-100 | yes |
| 131 | `custom/conf/app.example.ini` | 525-527 | yes |
| 131 | `modules/setting/security.go` | 193-197 | yes |
| 131 | `routers/api/v1/api.go` | 226-229 | yes |
| 192 | `cmd/web.go` | 285-286 | yes |
| 192 | `custom/conf/app.example.ini` | 442 | yes |
| 192 | `routers/install/routes.go` | 30-32 | yes |
| 193 | `routers/web/auth/auth.go` | 288 | yes |
| 193 | `routers/web/auth/auth.go` | 289-292 | yes |
| 193 | `routers/web/auth/auth.go` | 302-306 | yes |
| 193 | `routers/web/auth/auth.go` | 326-345 | yes |
| 193 | `routers/web/web.go` | 567-594 | yes |
| 193 | `routers/web/web.go` | 725-741 | yes |
| 194 | `models/auth/oauth2.go` | 57-59 | yes |
| 194 | `routers/web/web.go` | 362 | yes |
| 194 | `routers/web/web.go` | 521 | yes |
| 194 | `routers/web/web.go` | 592-606 | yes |
| 194 | `routers/web/web.go` | 605 | yes |
| 195 | `models/auth/access_token.go` | 43 | yes |
| 195 | `models/user/user.go` | 197 | yes |
| 195 | `routers/web/web.go` | 198-211 | yes |
| 195 | `routers/web/web.go` | 608-723 | yes |
| 195 | `routers/web/web.go` | 723 | yes |
| 196 | `models/repo/repo.go` | 225 | yes |
| 196 | `routers/web/repo/repo.go` | 193-260 | yes |
| 196 | `routers/web/repo/repo.go` | 222 | yes |
| 196 | `routers/web/web.go` | 1071-1075 | yes |
| 196 | `routers/web/web.go` | 1158-1260 | yes |
| 196 | `routers/web/web.go` | 1430-1500 | yes |
| 196 | `routers/web/web.go` | 1744-1747 | yes |
| 196 | `routers/web/web.go` | 893 | yes |
| 197 | `models/issues/issue.go` | 130 | yes |
| 197 | `models/issues/pull.go` | 170 | yes |
| 197 | `routers/web/repo/issue_new.go` | 331 | yes |
| 197 | `routers/web/repo/pull.go` | 1088 | yes |
| 197 | `routers/web/repo/pull.go` | 1110 | yes |
| 197 | `routers/web/repo/pull.go` | 1195 | yes |
| 197 | `routers/web/web.go` | 1308-1416 | yes |
| 197 | `routers/web/web.go` | 1365 | yes |
| 197 | `routers/web/web.go` | 1628-1657 | yes |
| 198 | `models/project/project.go` | 184 | yes |
| 198 | `routers/api/v1/api.go` | 754 | yes |
| 198 | `routers/api/v1/api.go` | 768-806 | yes |
| 198 | `routers/web/web.go` | 1112-1140 | yes |
| 198 | `routers/web/web.go` | 1519-1540 | yes |
| 198 | `routers/web/web.go` | 330-348 | yes |
| 198 | `routers/web/web.go` | 341 | yes |
| 199 | `routers/web/repo/wiki.go` |  | yes |
| 199 | `routers/web/web.go` | 1586-1600 | yes |
| 199 | `routers/web/web.go` | 1589 | yes |
| 200 | `models/actions/run.go` | 79 | yes |
| 200 | `models/secret/secret.go` | 95 | yes |
| 200 | `routers/api/actions/artifacts.go` | 119-124 | yes |
| 200 | `routers/api/actions/runner/interceptor.go` | 46-107 | yes |
| 200 | `routers/api/actions/runner/runner.go` | 30 | yes |
| 200 | `routers/init.go` | 196-207 | yes |
| 200 | `routers/web/web.go` | 1541-1585 | yes |
| 200 | `routers/web/web.go` | 479-510 | yes |
| 200 | `services/actions/run.go` |  | yes |
| 201 | `cmd/web.go` | 345-347 | yes |
| 201 | `models/asymkey/ssh_key.go` | 57 | yes |
| 201 | `models/git/lfs.go` | 89 | yes |
| 201 | `routers/common/lfs.go` | 18-29 | yes |
| 201 | `routers/private/hook_pre_receive.go` | 111-135 | yes |
| 201 | `routers/private/hook_pre_receive.go` | 75 | yes |
| 201 | `routers/private/serv.go` | 68 | yes |
| 201 | `routers/web/githttp.go` | 13-24 | yes |
| 202 | `models/organization/team.go` | 134-138 | yes |
| 202 | `routers/api/v1/api.go` | 1736 | yes |
| 202 | `routers/api/v1/api.go` | 1801 | yes |
| 202 | `routers/api/v1/api.go` | 421-577 | yes |
| 202 | `routers/web/web.go` | 937-1068 | yes |
| 202 | `routers/web/web.go` | 937-1068 | yes |
| 203 | `models/packages/package.go` | 18 | yes |
| 203 | `routers/api/packages/api.go` | 107-111 | yes |
| 203 | `routers/api/packages/api.go` | 107-548 | yes |
| 203 | `routers/api/packages/api.go` | 44-65 | yes |
| 203 | `routers/api/packages/api.go` | 543 | yes |
| 203 | `routers/init.go` | 188-194 | yes |
| 203 | `routers/web/web.go` | 1080-1110 | yes |
| 203 | `routers/web/web.go` | 671-690 | yes |
| 204 | `routers/api/v1/api.go` | 111-146 | yes |
| 204 | `routers/api/v1/api.go` | 277-308 | yes |
| 204 | `routers/api/v1/api.go` | 851-862 | yes |
| 204 | `routers/api/v1/api.go` | 939-1878 | yes |
| 204 | `routers/web/web.go` | 1769-1772 | yes |
| 205 | `routers/api/v1/api.go` | 1829 | yes |
| 205 | `routers/api/v1/api.go` | 350 | yes |
| 205 | `routers/web/admin/audit.go` |  | yes |
| 205 | `routers/web/web.go` | 746 | yes |
| 205 | `routers/web/web.go` | 746-870 | yes |
| 205 | `routers/web/web.go` | 787 | yes |
| 206 | `routers/private/internal.go` | 25-43 | yes |
| 206 | `routers/private/internal.go` | 80-100 | yes |
| 207 | `models/webhook/webhook.go` | 148 | yes |
| 207 | `modules/setting/webhook.go` | 26 | yes |
| 207 | `routers/web/web.go` | 449-476 | yes |
| 207 | `services/webhook/deliver.go` | 262 | yes |
| 207 | `services/webhook/deliver.go` | 274-290 | yes |
| 207 | `services/webhook/deliver.go` | 277 | yes |
| 207 | `services/webhook/deliver.go` | 278 | yes |
| 208 | `models/activities/notification.go` | 115 | yes |
| 208 | `routers/api/v1/api.go` | 1046-1054 | yes |
| 208 | `routers/web/web.go` | 1759-1767 | yes |
| 208 | `routers/web/web.go` | 426-431 | yes |
| 208 | `routers/web/web.go` | 590 | yes |
| 208 | `routers/web/web.go` | 885 | yes |
| 208 | `routers/web/web.go` | 886-887 | yes |
| 209 | `custom/conf/app.example.ini` | 1592 | yes |
| 209 | `routers/api/v1/api.go` | 1058 | yes |
| 209 | `routers/common/codesearch.go` |  | yes |
| 209 | `routers/web/web.go` | 358 | yes |
| 209 | `routers/web/web.go` | 519 | yes |
| 209 | `routers/web/web.go` | 539-556 | yes |
| 210 | `cmd/web.go` | 244-259 | yes |
| 210 | `cmd/web.go` | 255-256 | yes |
| 210 | `routers/install/routes.go` | 36 | yes |
| 210 | `routers/web/metrics.go` | 16-33 | yes |
| 210 | `routers/web/web.go` | 1774 | yes |
| 210 | `routers/web/web.go` | 1774-1792 | yes |
| 210 | `routers/web/web.go` | 264 | yes |
| 210 | `routers/web/web.go` | 290-298 | yes |
| 211 | `cmd/actions.go` | 17 | yes |
| 211 | `cmd/admin.go` | 22 | yes |
| 211 | `cmd/doctor.go` | 28 | yes |
| 211 | `cmd/dump.go` | 26 | yes |
| 211 | `cmd/generate.go` | 22 | yes |
| 211 | `cmd/manager.go` | 18 | yes |
| 211 | `cmd/migrate.go` | 19 | yes |
| 211 | `cmd/serv.go` | 40 | yes |
| 211 | `cmd/web.go` | 39 | yes |
| 212 | `custom/conf/app.example.ini` | 2143 | yes |
| 212 | `services/cron/cron.go` | 17-24 | yes |
| 212 | `services/cron/tasks_actions.go` | 27 | yes |
| 212 | `services/cron/tasks_basic.go` | 31 | yes |
| 212 | `services/cron/tasks_extended.go` | 26 | yes |
| 218 | `modules/` |  | yes |
| 218 | `modules/setting/session.go` | 64 | yes |
| 218 | `modules/storage/minio.go` | 129 | yes |
| 219 | `Makefile` | 436 | yes |
| 219 | `tests/` |  | yes |
| 219 | `tests/integration/admin_audit_test.go` |  | yes |
| 220 | `services/` |  | yes |
| 220 | `services/cron/cron.go` |  | yes |
| 220 | `services/webhook/deliver.go` | 274 | yes |
| 221 | `templates/` |  | yes |
| 221 | `templates/swagger/v1-swagger.generated.json` |  | yes |
| 222 | `modules/setting` |  | yes |
| 222 | `routers/` |  | yes |
| 222 | `routers/init.go` | 176-214 | yes |
| 223 | `public/` |  | yes |
| 223 | `routers/web/web.go` | 265 | yes |
| 224 | `models/` |  | yes |
| 224 | `models/repo/repo.go` | 225 | yes |
| 224 | `models/user/user.go` | 197 | yes |
| 225 | `package.json` | 3-6 | yes |
| 225 | `web_src/` |  | yes |
| 226 | `cmd/migrate.go` | 26-43 | yes |
| 226 | `modelmigration/` |  | yes |
| 227 | `options/` |  | yes |
| 227 | `options/locale/locale_en-US.json` |  | yes |
| 228 | `cmd/` |  | yes |
| 228 | `cmd/main.go` |  | yes |
| 229 | `Dockerfile` |  | yes |
| 230 | `.github/` |  | yes |
| 230 | `.github/workflows/pull-db-tests.yml` | 1 | yes |
| 231 | `contrib/` |  | yes |
| 231 | `contrib/upgrade.sh` | 1-12 | yes |
| 232 | `docs/` |  | yes |
| 232 | `docs/community-governance.md` | 1 | yes |
| 232 | `docs/development.md` |  | yes |
| 233 | `Dockerfile` | 89 | yes |
| 233 | `docker/` |  | yes |
| 233 | `docker/root/usr/bin/entrypoint` |  | yes |
| 234 | `tools/` |  | yes |
| 234 | `tools/test-integration.sh` |  | yes |
| 235 | `build/` |  | yes |
| 235 | `build/generate-emoji.go` | 81 | yes |
| 236 | `assets/` |  | yes |
| 236 | `assets/logo.svg` |  | yes |
| 237 | `snap/` |  | yes |
| 237 | `snap/snapcraft.yaml` |  | yes |
| 238 | `.devcontainer/` |  | yes |
| 238 | `.devcontainer/devcontainer.json` |  | yes |
| 239 | `custom/` |  | yes |
| 239 | `custom/conf/app.example.ini` | 1 | yes |
| 245 | `routers/web/web.go` | 353-358 | yes |
| 246 | `routers/api/v1/api.go` | 259-273 | yes |
| 247 | `routers/api/v1/api.go` | 350-357 | yes |
| 247 | `routers/web/web.go` | 238-244 | yes |
| 248 | `models/user/user.go` | 139-151 | yes |
| 248 | `routers/web/web.go` | 183-199 | yes |
| 249 | `models/organization/team.go` | 134-138 | yes |
| 249 | `routers/api/v1/api.go` | 421 | yes |
| 249 | `routers/api/v1/api.go` | 537 | yes |
| 249 | `routers/api/v1/api.go` | 548 | yes |
| 250 | `models/perm/access/access.go` | 33 | yes |
| 250 | `models/repo/collaboration.go` | 30 | yes |
| 250 | `routers/web/web.go` | 893-909 | yes |
| 251 | `routers/web/web.go` | 911-917 | yes |
| 252 | `models/auth/access_token_scope.go` | 18-27 | yes |
| 252 | `models/auth/access_token_scope.go` | 20 | yes |
| 252 | `models/auth/access_token_scope.go` | 58-90 | yes |
| 253 | `models/auth/oauth2.go` | 57-59 | yes |
| 254 | `models/deploykey/deploykey.go` | 58 | yes |
| 254 | `routers/web/web.go` | 136-138 | yes |
| 255 | `routers/api/actions/runner/interceptor.go` | 46-107 | yes |
| 255 | `services/auth/basic.go` | 111-116 | yes |
| 256 | `routers/api/v1/api.go` | 111-146 | yes |
| 256 | `routers/web/admin/users.go` | 568-585 | yes |
| 256 | `routers/web/web.go` | 787 | yes |
| 257 | `routers/api/v1/api.go` | 857-859 | yes |
| 257 | `routers/web/web.go` | 147-150 | yes |
| 258 | `models/auth/source.go` | 143 | yes |
| 258 | `modules/setting/security.go` | 193-197 | yes |
| 259 | `routers/private/internal.go` | 25-43 | yes |
| 263 | `routers/web/web.go` | 353-360 | yes |
| 263 | `routers/web/web.go` | 746 | yes |
| 263 | `routers/web/web.go` | 893-909 | yes |
| 263 | `routers/web/web.go` | 919-935 | yes |
| 264 | `routers/web/web.go` | 179 | yes |
| 264 | `routers/web/web.go` | 220-225 | yes |
| 265 | `routers/api/v1/api.go` | 1044-1054 | yes |
| 265 | `routers/api/v1/api.go` | 148 | yes |
| 265 | `routers/api/v1/api.go` | 249 | yes |
| 265 | `routers/api/v1/api.go` | 311-318 | yes |
| 265 | `routers/api/v1/api.go` | 369-410 | yes |
| 266 | `routers/api/packages/api.go` | 107-111 | yes |
| 266 | `routers/api/packages/api.go` | 107-134 | yes |
| 266 | `routers/api/packages/api.go` | 44-65 | yes |
| 266 | `routers/api/packages/api.go` | 543 | yes |
| 267 | `routers/private/hook_pre_receive.go` | 111-135 | yes |
| 268 | `routers/private/internal.go` | 25-43 | yes |
| 269 | `routers/api/v1/api.go` | 1016-1036 | yes |
| 269 | `routers/web/metrics.go` | 16-20 | yes |
| 269 | `routers/web/web.go` | 1769-1772 | yes |
| 269 | `routers/web/web.go` | 265-298 | yes |
| 269 | `routers/web/web.go` | 296 | yes |
| 269 | `routers/web/web.go` | 520-532 | yes |
| 269 | `routers/web/web.go` | 590 | yes |
| 269 | `routers/web/web.go` | 725-734 | yes |
| 269 | `routers/web/websocket/websocket.go` | 42 | yes |
| 270 | `services/actions/token_permission_design.md` | 34-40 | yes |
| 270 | `services/actions/token_permission_design.md` | 7-14 | yes |
| 277 | `cmd/web.go` | 285-286 | yes |
| 278 | `routers/web/web.go` | 215-218 | yes |
| 278 | `routers/web/web.go` | 569 | yes |
| 279 | `custom/conf/app.example.ini` | 841 | yes |
| 279 | `routers/web/web.go` | 571 | yes |
| 280 | `routers/web/web.go` | 592-598 | yes |
| 281 | `routers/web/web.go` | 608-723 | yes |
| 282 | `routers/web/web.go` | 1073 | yes |
| 283 | `routers/web/web.go` | 1158 | yes |
| 283 | `routers/web/web.go` | 893 | yes |
| 284 | `routers/web/web.go` | 1455-1459 | yes |
| 285 | `routers/web/web.go` | 1331 | yes |
| 286 | `routers/web/web.go` | 1365 | yes |
| 287 | `routers/web/repo/pull.go` | 1118-1119 | yes |
| 287 | `routers/web/web.go` | 1655 | yes |
| 288 | `routers/web/web.go` | 898 | yes |
| 289 | `routers/web/web.go` | 1589 | yes |
| 290 | `routers/web/web.go` | 1541-1585 | yes |
| 291 | `routers/api/actions/runner/interceptor.go` | 46-107 | yes |
| 292 | `routers/private/hook_pre_receive.go` | 114 | yes |
| 293 | `routers/web/githttp.go` | 13-24 | yes |
| 294 | `routers/api/v1/api.go` | 421 | yes |
| 295 | `routers/api/packages/api.go` | 107-111 | yes |
| 295 | `routers/api/packages/api.go` | 44-65 | yes |
| 296 | `routers/api/v1/api.go` | 311-318 | yes |
| 297 | `routers/api/v1/api.go` | 1016-1036 | yes |
| 298 | `routers/api/v1/api.go` | 118-143 | yes |
| 299 | `routers/api/v1/api.go` | 350-357 | yes |
| 300 | `routers/web/web.go` | 238-244 | yes |
| 301 | `routers/web/web.go` | 787 | yes |
| 302 | `routers/web/web.go` | 829-842 | yes |
| 303 | `routers/private/internal.go` | 25-43 | yes |
| 304 | `routers/web/web.go` | 1198-1215 | yes |
| 305 | `routers/web/web.go` | 1759-1767 | yes |
| 306 | `custom/conf/app.example.ini` | 853 | yes |
| 306 | `modules/setting/service.go` | 163-168 | yes |
| 306 | `routers/web/web.go` | 539-556 | yes |
| 307 | `routers/web/web.go` | 298 | yes |
| 308 | `routers/web/metrics.go` | 16-33 | yes |
| 309 | `cmd/main.go` |  | yes |
| 310 | `routers/init.go` | 172 | yes |
| 311 | `models/auth/access_token_scope.go` | 65-66 | yes |
| 311 | `routers/api/v1/api.go` | 277-308 | yes |
| 317 | `routers/web/web.go` | 257-321 | yes |
| 321 | `routers/install/routes.go` | 30-32 | yes |
| 322 | `routers/web/home.go` |  | yes |
| 322 | `routers/web/web.go` | 264 | yes |
| 323 | `routers/web/auth/auth.go` | 288-346 | yes |
| 323 | `routers/web/web.go` | 566-569 | yes |
| 323 | `routers/web/web.go` | 588 | yes |
| 324 | `routers/web/web.go` | 571 | yes |
| 325 | `routers/web/auth/auth.go` | 348-365 | yes |
| 326 | `routers/web/web.go` | 730-733 | yes |
| 327 | `routers/web/auth/oauth2_provider.go` | 372-376 | yes |
| 327 | `routers/web/web.go` | 592-598 | yes |
| 328 | `routers/web/web.go` | 888-891 | yes |
| 329 | `routers/web/web.go` | 608-723 | yes |
| 330 | `routers/web/web.go` | 539-556 | yes |
| 331 | `routers/web/repo/repo.go` | 193 | yes |
| 331 | `routers/web/web.go` | 1071-1075 | yes |
| 332 | `routers/web/web.go` | 1724-1739 | yes |
| 333 | `routers/web/web.go` | 1158-1260 | yes |
| 334 | `routers/web/repo/issue_view.go` |  | yes |
| 334 | `routers/web/web.go` | 1308-1310 | yes |
| 335 | `routers/web/web.go` | 1331 | yes |
| 336 | `routers/web/repo/pull_merge_box.go` |  | yes |
| 336 | `routers/web/web.go` | 1628-1657 | yes |
| 337 | `routers/web/web.go` | 1453-1480 | yes |
| 338 | `routers/web/web.go` | 1480-1500 | yes |
| 339 | `routers/web/web.go` | 1586-1600 | yes |
| 340 | `routers/web/web.go` | 1541-1585 | yes |
| 341 | `routers/web/web.go` | 1112-1140 | yes |
| 341 | `routers/web/web.go` | 1519-1540 | yes |
| 342 | `routers/web/web.go` | 937-1068 | yes |
| 343 | `routers/web/web.go` | 1080-1110 | yes |
| 344 | `routers/web/admin/admin.go` |  | yes |
| 344 | `routers/web/web.go` | 746-870 | yes |
| 345 | `routers/web/web.go` | 1759-1767 | yes |
| 346 | `routers/web/web.go` | 306-309 | yes |
| 347 | `routers/web/web.go` | 1774-1792 | yes |
| 353 | `cmd/web.go` | 285-286 | yes |
| 353 | `custom/conf/app.example.ini` | 442 | yes |
| 354 | `cmd/web.go` | 136-153 | yes |
| 354 | `routers/init.go` | 107-111 | yes |
| 355 | `routers/install/routes.go` | 30-31 | yes |
| 355 | `routers/install/routes.go` | 32 | yes |
| 356 | `cmd/web.go` | 168-171 | yes |
| 356 | `cmd/web.go` | 297 | yes |
| 358 | `cmd/web.go` | 153-157 | yes |
| 362 | `routers/web/auth/auth.go` | 289-292 | yes |
| 362 | `routers/web/web.go` | 569 | yes |
| 363 | `routers/web/auth/auth.go` | 302-306 | yes |
| 364 | `services/auth/signin.go` | 104-125 | yes |
| 364 | `services/auth/signin.go` | 27-92 | yes |
| 365 | `services/auth/signin.go` | 94-95 | yes |
| 365 | `services/auth/signin.go` | 96-98 | yes |
| 366 | `routers/web/auth/auth.go` | 328-343 | yes |
| 366 | `routers/web/auth/auth.go` | 348-364 | yes |
| 367 | `routers/web/auth/auth.go` | 376-380 | yes |
| 369 | `routers/web/auth/auth.go` | 310-312 | yes |
| 373 | `routers/web/repo/repo.go` | 193 | yes |
| 373 | `routers/web/web.go` | 1071-1075 | yes |
| 374 | `routers/web/repo/repo.go` | 197-201 | yes |
| 375 | `routers/web/repo/repo.go` | 203-247 | yes |
| 375 | `routers/web/repo/repo.go` | 222 | yes |
| 376 | `routers/web/repo/repo.go` | 253-260 | yes |
| 377 | `routers/web/repo/repo.go` | 250 | yes |
| 379 | `routers/web/repo/repo.go` | 211-214 | yes |
| 383 | `routers/web/web.go` | 1331 | yes |
| 384 | `routers/web/repo/issue_new.go` | 336-341 | yes |
| 384 | `routers/web/repo/issue_new.go` | 343-349 | yes |
| 385 | `routers/web/repo/issue_new.go` | 351-354 | yes |
| 386 | `routers/web/repo/issue_new.go` | 361-366 | yes |
| 387 | `routers/web/repo/issue_new.go` | 368-379 | yes |
| 389 | `routers/web/repo/issue_new.go` | 356-359 | yes |
| 389 | `routers/web/repo/issue_new.go` | 379-380 | yes |
| 393 | `routers/web/repo/pull.go` | 1088-1097 | yes |
| 393 | `routers/web/web.go` | 1640 | yes |
| 393 | `routers/web/web.go` | 1655 | yes |
| 394 | `routers/web/repo/pull.go` | 1099-1107 | yes |
| 395 | `routers/web/repo/pull.go` | 1110 | yes |
| 396 | `routers/web/repo/pull.go` | 1181-1183 | yes |
| 396 | `routers/web/repo/pull.go` | 1195 | yes |
| 397 | `routers/web/repo/pull.go` | 1275 | yes |
| 399 | `routers/web/repo/pull.go` | 1118-1119 | yes |
| 399 | `routers/web/repo/pull.go` | 1196-1230 | yes |
| 403 | `routers/web/githttp.go` | 13-14 | yes |
| 404 | `cmd/serv.go` | 40 | yes |
| 404 | `routers/private/internal.go` | 87-88 | yes |
| 404 | `routers/private/serv.go` | 68 | yes |
| 405 | `routers/private/hook_pre_receive.go` | 75-106 | yes |
| 405 | `routers/private/internal.go` | 84 | yes |
| 406 | `routers/private/hook_pre_receive.go` | 114-135 | yes |
| 407 | `routers/private/hook_post_receive.go` | 80 | yes |
| 407 | `routers/private/internal.go` | 85 | yes |
| 409 | `routers/private/hook_pre_receive.go` | 129-133 | yes |
| 409 | `routers/private/internal.go` | 27-31 | yes |
| 413 | `routers/web/web.go` | 449-461 | yes |
| 413 | `routers/web/web.go` | 464-476 | yes |
| 414 | `modules/setting/webhook.go` | 26 | yes |
| 414 | `services/webhook/deliver.go` | 274-279 | yes |
| 415 | `services/webhook/deliver.go` | 281-300 | yes |
| 416 | `services/webhook/deliver.go` | 262-267 | yes |
| 418 | `services/webhook/deliver.go` | 263-265 | yes |
| 422 | `routers/init.go` | 167 | yes |
| 422 | `routers/init.go` | 196-207 | yes |
| 423 | `services/cron/tasks_actions.go` | 59 | yes |
| 424 | `routers/api/actions/runner/interceptor.go` | 46-66 | yes |
| 424 | `routers/api/actions/runner/runner.go` | 30-36 | yes |
| 425 | `models/actions/task.go` | 68 | yes |
| 425 | `models/actions/task_output.go` | 24 | yes |
| 425 | `models/actions/task_step.go` | 62 | yes |
| 426 | `routers/api/actions/artifacts.go` | 119-124 | yes |
| 427 | `services/cron/tasks_actions.go` | 27 | yes |
| 427 | `services/cron/tasks_actions.go` | 37 | yes |
| 427 | `services/cron/tasks_actions.go` | 47 | yes |
| 427 | `services/cron/tasks_actions.go` | 70-80 | yes |
| 429 | `routers/api/actions/runner/interceptor.go` | 59-66 | yes |
| 433 | `routers/web/admin/users.go` | 568-585 | yes |
| 433 | `routers/web/web.go` | 784-788 | yes |
| 434 | `cmd/admin_user_change_password.go` | 22 | yes |
| 434 | `cmd/admin_user_create.go` | 24 | yes |
| 434 | `cmd/admin_user_delete.go` | 22 | yes |
| 434 | `cmd/admin_user_disable_2fa.go` | 21 | yes |
| 434 | `cmd/admin_user_generate_access_token.go` | 19 | yes |
| 434 | `cmd/admin_user_list.go` | 19 | yes |
| 434 | `cmd/admin_user_must_change_password.go` | 18 | yes |
| 435 | `services/cron/tasks_basic.go` | 88 | yes |
| 436 | `cmd/audit.go` | 15-16 | yes |
| 442 | `contrib/upgrade.sh` | 14-17 | yes |
| 442 | `contrib/upgrade.sh` | 76 | yes |
| 443 | `contrib/upgrade.sh` | 79-83 | yes |
| 443 | `contrib/upgrade.sh` | 89-94 | yes |
| 444 | `contrib/upgrade.sh` | 101-116 | yes |
| 444 | `contrib/upgrade.sh` | 54 | yes |
| 445 | `contrib/upgrade.sh` | 124-136 | yes |
| 447 | `contrib/upgrade.sh` | 60-61 | yes |
| 455 | `custom/conf/app.example.ini` | 353-400 | yes |
| 455 | `custom/conf/app.example.ini` | 367 | yes |
| 455 | `models/db/engine.go` | 112 | yes |
| 455 | `routers/init.go` | 136 | yes |
| 456 | `custom/conf/app.example.ini` | 1048 | yes |
| 456 | `custom/conf/app.example.ini` | 748 | yes |
| 456 | `modules/git/` |  | yes |
| 456 | `routers/init.go` | 115 | yes |
| 457 | `custom/conf/app.example.ini` | 1974-1985 | yes |
| 457 | `modules/setting/session.go` | 64 | yes |
| 458 | `custom/conf/app.example.ini` | 1940 | yes |
| 458 | `routers/init.go` | 128 | yes |
| 459 | `custom/conf/app.example.ini` | 1666 | yes |
| 459 | `services/webhook/deliver.go` | 281 | yes |
| 460 | `custom/conf/app.example.ini` | 1653 | yes |
| 460 | `modules/nosql/manager_redis.go` | 244 | yes |
| 461 | `custom/conf/app.example.ini` | 1592 | yes |
| 461 | `modules/indexer/internal/elasticsearch/indexer.go` | 284 | yes |
| 461 | `routers/init.go` | 150 | yes |
| 462 | `custom/conf/app.example.ini` | 2891-3002 | yes |
| 462 | `modules/storage/azureblob.go` | 226 | yes |
| 462 | `modules/storage/minio.go` | 129 | yes |
| 463 | `custom/conf/app.example.ini` | 1798 | yes |
| 463 | `services/mailer/sender/smtp.go` | 49 | yes |
| 464 | `custom/conf/app.example.ini` | 1899-1930 | yes |
| 464 | `services/mailer/incoming/incoming.go` | 63 | yes |
| 465 | `models/auth/source.go` | 137-147 | yes |
| 465 | `services/auth/source/ldap/source_search.go` | 181 | yes |
| 465 | `services/auth/source/smtp/auth.go` | 59 | yes |
| 466 | `custom/conf/app.example.ini` | 147-163 | yes |
| 466 | `modules/ssh/server.go` |  | yes |
| 466 | `routers/init.go` | 162 | yes |
| 467 | `routers/api/actions/actions.go` | 25 | yes |
| 467 | `routers/api/actions/runner/runner.go` | 30-36 | yes |
| 467 | `routers/init.go` | 196-207 | yes |
| 468 | `custom/conf/app.example.ini` | 3018 | yes |
| 468 | `services/gitproxy/` |  | yes |
| 472 | `cmd/migrate.go` | 26-43 | yes |
| 472 | `modelmigration/v1_10/v100.go` | 55 | yes |
| 472 | `modelmigration/v1_11/v106.go` | 25 | yes |
| 472 | `models/db/engine.go` | 112 | yes |
| 478 | `custom/conf/app.example.ini` | 880 | yes |
| 478 | `modules/hcaptcha/hcaptcha.go` | 96 | yes |
| 478 | `modules/mcaptcha/mcaptcha.go` | 41 | yes |
| 478 | `modules/mcaptcha/mcaptcha.go` | 44 | yes |
| 478 | `modules/recaptcha/recaptcha.go` | 33 | yes |
| 478 | `modules/recaptcha/recaptcha.go` | 35 | yes |
| 478 | `modules/turnstile/turnstile.go` | 47 | yes |
| 479 | `modules/indexer/internal/elasticsearch/indexer.go` | 284 | yes |
| 480 | `modules/lfs/http_client.go` | 236 | yes |
| 481 | `modules/storage/azureblob.go` | 226 | yes |
| 482 | `modules/updatechecker/update_checker.go` | 31-35 | yes |
| 482 | `modules/updatechecker/update_checker.go` | 37 | yes |
| 482 | `services/cron/tasks_extended.go` | 163 | yes |
| 483 | `routers/web/auth/oauth.go` | 313 | yes |
| 484 | `routers/web/repo/migrate.go` | 125 | yes |
| 484 | `services/migrations/bitbucket.go` | 179 | yes |
| 484 | `services/migrations/bitbucketserver.go` | 349 | yes |
| 484 | `services/migrations/codebase.go` | 128 | yes |
| 484 | `services/migrations/codecommit.go` | 300 | yes |
| 484 | `services/migrations/common.go` | 28 | yes |
| 484 | `services/migrations/github_graphql.go` | 166 | yes |
| 484 | `services/migrations/onedev.go` | 120 | yes |
| 485 | `services/webhook/deliver.go` | 277 | yes |
| 485 | `services/webhook/deliver.go` | 278 | yes |
| 485 | `services/webhook/deliver.go` | 39 | yes |
| 485 | `services/webhook/deliver.go` | 50 | yes |
| 485 | `services/webhook/deliver.go` | 67 | yes |
| 485 | `services/webhook/deliver.go` | 79 | yes |
| 485 | `services/webhook/matrix.go` | 55 | yes |
| 485 | `services/webhook/payloader.go` | 112 | yes |
| 486 | `build/generate-emoji.go` | 81 | yes |
| 486 | `build/generate-gitignores.go` | 45 | yes |
| 487 | `models/unittest/mock_http.go` | 87 | yes |
| 488 | `contrib/upgrade.sh` | 103-105 | yes |
| 488 | `contrib/upgrade.sh` | 108-115 | yes |
| 488 | `contrib/upgrade.sh` | 81 | yes |
| 489 | `modules/private/internal.go` | 89 | yes |
| 489 | `routers/private/internal.go` | 71 | yes |
| 495 | `models/user/user.go` | 101 | yes |
| 496 | `models/user/email_address.go` | 93 | yes |
| 497 | `models/auth/access_token.go` | 20 | yes |
| 498 | `models/auth/twofactor.go` | 60 | yes |
| 499 | `models/auth/webauthn.go` | 61 | yes |
| 500 | `models/auth/oauth2.go` | 57-59 | yes |
| 501 | `models/auth/source.go` | 137 | yes |
| 501 | `services/auth/source/ldap/source.go` | 58-74 | yes |
| 502 | `models/auth/session.go` | 24 | yes |
| 503 | `models/repo/repo.go` | 153 | yes |
| 504 | `models/perm/access/access.go` | 33 | yes |
| 504 | `models/repo/collaboration.go` | 30 | yes |
| 504 | `models/repo/repo_unit.go` | 53 | yes |
| 505 | `models/issues/comment.go` | 373 | yes |
| 505 | `models/issues/issue.go` | 130 | yes |
| 505 | `models/issues/pull.go` | 170 | yes |
| 505 | `models/issues/review.go` | 155 | yes |
| 506 | `models/repo/attachment.go` | 42 | yes |
| 506 | `models/repo/release.go` | 94 | yes |
| 507 | `models/organization/team.go` | 134-138 | yes |
| 508 | `models/asymkey/gpg_key.go` | 42 | yes |
| 508 | `models/asymkey/ssh_key.go` | 57 | yes |
| 508 | `models/deploykey/deploykey.go` | 58 | yes |
| 509 | `models/webhook/hooktask.go` | 81 | yes |
| 509 | `models/webhook/webhook.go` | 123 | yes |
| 510 | `models/secret/secret.go` | 39 | yes |
| 511 | `models/actions/run.go` | 79 | yes |
| 511 | `models/actions/runner.go` | 207 | yes |
| 511 | `models/actions/runner_token.go` | 45 | yes |
| 511 | `models/actions/task.go` | 68 | yes |
| 512 | `models/packages/package.go` | 18 | yes |
| 512 | `models/packages/package_blob.go` | 26 | yes |
| 512 | `models/packages/package_file.go` | 20 | yes |
| 512 | `models/packages/package_version.go` | 23 | yes |
| 513 | `models/git/lfs.go` | 89 | yes |
| 513 | `models/git/lfs_lock.go` | 31 | yes |
| 514 | `models/activities/action.go` | 154 | yes |
| 514 | `models/activities/notification.go` | 115 | yes |
| 515 | `models/audit/audit_event.go` | 19 | yes |
| 516 | `models/system/appstate.go` | 24 | yes |
| 516 | `models/system/notice.go` | 37 | yes |
| 516 | `models/system/setting.go` | 35 | yes |
| 518 | `models/user/user.go` | 101-185 | yes |
| 522 | `models/user/user.go` | 102 | yes |
| 523 | `models/user/user.go` | 103 | yes |
| 524 | `models/user/user.go` | 104 | yes |
| 525 | `models/user/user.go` | 107 | yes |
| 526 | `models/user/user.go` | 110 | yes |
| 527 | `models/user/user.go` | 111 | yes |
| 528 | `models/user/user.go` | 115 | yes |
| 529 | `models/user/user.go` | 118 | yes |
| 530 | `models/user/user.go` | 123-124 | yes |
| 531 | `models/user/user.go` | 130 | yes |
| 532 | `models/user/user.go` | 139 | yes |
| 533 | `models/user/user.go` | 144 | yes |
| 534 | `models/user/user.go` | 151 | yes |
| 535 | `models/user/user.go` | 155 | yes |
| 536 | `models/user/user.go` | 167 | yes |
| 538 | `models/repo/repo.go` | 153-221 | yes |
| 542 | `models/repo/repo.go` | 154 | yes |
| 543 | `models/repo/repo.go` | 155 | yes |
| 544 | `models/repo/repo.go` | 158 | yes |
| 545 | `models/repo/repo.go` | 160 | yes |
| 546 | `models/repo/repo.go` | 163 | yes |
| 547 | `models/repo/repo.go` | 186 | yes |
| 548 | `models/repo/repo.go` | 188 | yes |
| 549 | `models/repo/repo.go` | 189 | yes |
| 550 | `models/repo/repo.go` | 198-199 | yes |
| 551 | `models/repo/repo.go` | 201-202 | yes |
| 552 | `models/repo/repo.go` | 211 | yes |
| 554 | `models/auth/access_token.go` | 20-33 | yes |
| 558 | `models/auth/access_token.go` | 21 | yes |
| 559 | `models/auth/access_token.go` | 22 | yes |
| 560 | `models/auth/access_token.go` | 25 | yes |
| 561 | `models/auth/access_token.go` | 27 | yes |
| 563 | `models/auth/twofactor.go` | 60-68 | yes |
| 567 | `models/auth/twofactor.go` | 61 | yes |
| 568 | `models/auth/twofactor.go` | 62 | yes |
| 569 | `models/auth/twofactor.go` | 107-108 | yes |
| 570 | `models/auth/twofactor.go` | 66 | yes |
| 572 | `models/webhook/webhook.go` | 123-144 | yes |
| 576 | `models/webhook/webhook.go` | 124 | yes |
| 577 | `models/webhook/webhook.go` | 125-126 | yes |
| 578 | `models/webhook/webhook.go` | 128 | yes |
| 579 | `models/webhook/webhook.go` | 132 | yes |
| 580 | `models/webhook/webhook.go` | 141 | yes |
| 582 | `models/secret/secret.go` | 39-46 | yes |
| 586 | `models/secret/secret.go` | 41 | yes |
| 587 | `models/secret/secret.go` | 42 | yes |
| 588 | `models/secret/secret.go` | 43 | yes |
| 589 | `models/secret/secret.go` | 44 | yes |
| 591 | `models/auth/source.go` | 137-147 | yes |
| 595 | `models/auth/source.go` | 138 | yes |
| 596 | `models/auth/source.go` | 140 | yes |
| 597 | `models/auth/source.go` | 141 | yes |
| 598 | `models/auth/source.go` | 143 | yes |
| 599 | `models/auth/source.go` | 144 | yes |
| 599 | `services/auth/source/ldap/source.go` | 58-74 | yes |
| 605 | `custom/conf/app.example.ini` | 353-400 | yes |
| 605 | `routers/init.go` | 137 | yes |
| 605 | `routers/init.go` | 68-74 | yes |
| 606 | `custom/conf/app.example.ini` | 797 | yes |
| 606 | `routers/init.go` | 115-116 | yes |
| 606 | `routers/init.go` | 116 | yes |
| 607 | `custom/conf/app.example.ini` | 1994-1997 | yes |
| 607 | `modules/setting/session.go` | 64 | yes |
| 608 | `routers/init.go` | 128 | yes |
| 609 | `services/webhook/deliver.go` | 281-284 | yes |
| 609 | `services/webhook/deliver.go` | 292-300 | yes |
| 609 | `services/webhook/deliver.go` | 293 | yes |
| 610 | `modules/nosql/manager_redis.go` | 244-253 | yes |
| 611 | `routers/init.go` | 150 | yes |
| 612 | `routers/init.go` | 125 | yes |
| 613 | `cmd/web.go` | 131-133 | yes |
| 613 | `services/mailer/sender/smtp.go` | 49 | yes |
| 614 | `services/mailer/incoming/incoming.go` | 63 | yes |
| 615 | `routers/web/auth/auth.go` | 312 | yes |
| 615 | `services/auth/signin.go` | 104-110 | yes |
| 615 | `services/auth/signin.go` | 80-82 | yes |
| 616 | `modules/ssh/server.go` |  | yes |
| 617 | `routers/api/actions/runner/interceptor.go` | 33 | yes |
| 617 | `routers/api/actions/runner/interceptor.go` | 59-66 | yes |
| 618 | `services/gitproxy/` |  | yes |
| 619 | `modules/hcaptcha/hcaptcha.go` | 96 | yes |
| 620 | `modules/indexer/internal/elasticsearch/indexer.go` | 284 | yes |
| 621 | `modules/lfs/http_client.go` | 236 | yes |
| 622 | `modules/storage/azureblob.go` | 226 | yes |
| 623 | `modules/updatechecker/update_checker.go` | 37 | yes |
| 623 | `services/cron/tasks_extended.go` | 163 | yes |
| 624 | `routers/web/auth/oauth.go` | 313 | yes |
| 625 | `services/migrations/common.go` | 28 | yes |
| 626 | `custom/conf/app.example.ini` | 1780 | yes |
| 626 | `services/webhook/deliver.go` | 262-268 | yes |
| 626 | `services/webhook/deliver.go` | 267 | yes |
| 626 | `services/webhook/deliver.go` | 275-279 | yes |
| 627 | `build/generate-emoji.go` | 81 | yes |
| 628 | `models/unittest/mock_http.go` | 87 | yes |
| 629 | `contrib/upgrade.sh` | 105 | yes |
| 629 | `contrib/upgrade.sh` | 124-138 | yes |
| 629 | `contrib/upgrade.sh` | 61 | yes |
| 630 | `modules/private/internal.go` | 90-97 | yes |
| 630 | `routers/private/internal.go` | 37 | yes |
| 636 | `cmd/generate.go` | 56 | yes |
| 636 | `modules/private/internal.go` | 90-92 | yes |
| 636 | `routers/private/internal.go` | 36-39 | yes |
| 637 | `cmd/web.go` | 212-214 | yes |
| 638 | `cmd/web.go` | 173-177 | yes |
| 639 | `cmd/web.go` | 195-205 | yes |
| 640 | `cmd/web.go` | 285-290 | yes |
| 640 | `custom/conf/app.example.ini` | 442 | yes |
| 641 | `routers/web/web.go` | 730-733 | yes |
| 641 | `services/auth/signin.go` | 38-42 | yes |
| 641 | `services/auth/signin.go` | 80-82 | yes |
| 642 | `cmd/admin_user_must_change_password.go` | 18 | yes |
| 642 | `routers/web/web.go` | 198-206 | yes |
| 643 | `models/user/user.go` | 151 | yes |
| 643 | `routers/api/v1/api.go` | 888-891 | yes |
| 643 | `routers/web/web.go` | 786 | yes |
| 644 | `models/auth/access_token_scope.go` | 58-90 | yes |
| 644 | `routers/api/v1/api.go` | 261-263 | yes |
| 644 | `routers/api/v1/api.go` | 297-306 | yes |
| 645 | `routers/api/v1/api.go` | 311-318 | yes |
| 646 | `routers/api/v1/api.go` | 138-142 | yes |
| 647 | `custom/conf/app.example.ini` | 1780 | yes |
| 647 | `custom/conf/app.example.ini` | 539-562 | yes |
| 647 | `services/webhook/deliver.go` | 262-268 | yes |
| 648 | `routers/private/hook_pre_receive.go` | 128-135 | yes |
| 648 | `routers/private/hook_pre_receive.go` | 137 | yes |
| 649 | `routers/web/repo/pull.go` | 1195-1230 | yes |
| 650 | `routers/web/metrics.go` | 21-31 | yes |
| 651 | `cmd/actions.go` | 27 | yes |
| 651 | `routers/api/actions/runner/interceptor.go` | 59-66 | yes |
| 659 | `custom/conf/app.example.ini` | 520 | yes |
| 659 | `routers/api/v1/api.go` | 932-935 | yes |
| 659 | `services/auth/oauth2.go` | 84-97 | yes |
| 660 | `custom/conf/app.example.ini` | 861 | yes |
| 660 | `routers/api/v1/api.go` | 855 | yes |
| 660 | `routers/web/auth/auth.go` | 308-324 | yes |
| 660 | `routers/web/web.go` | 190-194 | yes |
| 660 | `services/auth/signin.go` | 104-125 | yes |
| 660 | `services/auth/signin.go` | 104-125 | yes |
| 660 | `services/auth/signin.go` | 27-100 | yes |
| 661 | `custom/conf/app.example.ini` | 572 | yes |
| 661 | `custom/conf/app.example.ini` | 576 | yes |
| 661 | `modules/setting/audit.go` | 24 | yes |
| 661 | `routers/api/v1/api.go` | 129-131 | yes |
| 661 | `routers/web/admin/users.go` | 585 | yes |
| 661 | `routers/web/web.go` | 787 | yes |
| 661 | `services/audit/event.go` | 131-134 | yes |
| 662 | `custom/conf/app.example.ini` | 2756-2758 | yes |
| 662 | `routers/web/metrics.go` | 17-20 | yes |
| 663 | `routers/private/internal.go` | 33-38 | yes |
| 664 | `models/auth/twofactor.go` | 102-108 | yes |
| 665 | `models/webhook/webhook.go` | 132 | yes |
| 665 | `models/webhook/webhook.go` | 141 | yes |
| 665 | `models/webhook/webhook.go` | 224-228 | yes |
| 666 | `routers/web/auth/auth.go` | 467-469 | yes |
| 666 | `routers/web/web.go` | 734 | yes |
| 667 | `modules/private/internal.go` | 74-77 | yes |
| 668 | `custom/conf/app.example.ini` | 1926-1927 | yes |
| 668 | `modules/setting/incoming_email.go` | 23 | yes |
| 669 | `custom/conf/app.example.ini` | 1845 | yes |
| 669 | `custom/conf/app.example.ini` | 2108 | yes |
| 669 | `models/auth/source.go` | 100-102 | yes |
| 669 | `modules/nosql/manager_redis.go` | 239-253 | yes |
| 669 | `modules/setting/migrations.go` | 53 | yes |
| 669 | `modules/setting/migrations.go` | 53 | yes |
| 669 | `modules/setting/webhook.go` | 26 | yes |
| 669 | `modules/setting/webhook.go` | 36 | yes |
| 669 | `modules/storage/minio.go` | 129 | yes |
| 669 | `services/auth/source/ldap/source_search.go` | 181 | yes |
| 669 | `services/auth/source/smtp/auth.go` | 59 | yes |
| 669 | `services/mailer/incoming/incoming.go` | 63 | yes |
| 669 | `services/mailer/sender/smtp.go` | 49 | yes |
| 669 | `services/migrations/http_client.go` | 38 | yes |
| 669 | `services/webhook/deliver.go` | 278 | yes |
| 670 | `modules/updatechecker/update_checker.go` | 31-37 | yes |
| 670 | `services/cron/tasks_extended.go` | 163-168 | yes |
| 670 | `services/cron/tasks_extended.go` | 163-168 | yes |
| 671 | `custom/conf/app.example.ini` | 445 | yes |
| 671 | `custom/conf/app.example.ini` | 446 | yes |
| 671 | `models/auth/twofactor.go` | 102 | yes |
| 671 | `models/secret/secret.go` | 79 | yes |
| 671 | `models/webhook/webhook.go` | 224 | yes |
| 671 | `modules/setting/security.go` | 147-152 | yes |
| 671 | `modules/setting/security.go` | 149-150 | yes |
| 671 | `routers/install/install.go` | 392-399 | yes |
| 671 | `services/auth/source/ldap/source.go` | 58-65 | yes |
| 671 | `services/auth/source/ldap/source.go` | 58-65 | yes |
| 672 | `custom/conf/app.example.ini` | 576 | yes |
| 672 | `models/audit/audit_event.go` | 22-38 | yes |
| 672 | `services/cron/tasks_extended.go` | 141-154 | yes |
| 678 | `cmd/web.go` | 356-368 | yes |
| 679 | `cmd/web.go` | 339-343 | yes |
| 679 | `custom/conf/app.example.ini` | 476-479 | yes |
| 680 | `routers/web/web.go` | 179 | yes |
| 680 | `routers/web/web.go` | 220-225 | yes |
| 681 | `routers/web/auth/auth.go` | 326-345 | yes |
| 682 | `models/auth/source.go` | 143 | yes |
| 682 | `modules/setting/security.go` | 193-197 | yes |
| 682 | `routers/api/v1/api.go` | 226-229 | yes |
| 683 | `modules/setting/session.go` | 64 | yes |
| 683 | `modules/web/middleware/cookie.go` | 71-73 | yes |
| 684 | `routers/web/auth/auth.go` | 288-346 | yes |
| 684 | `services/auth/signin.go` | 27-100 | yes |
| 685 | `custom/conf/app.example.ini` | 1022 | yes |
| 685 | `routers/common/qos.go` | 49-52 | yes |
| 686 | `modules/setting/audit.go` | 24 | yes |
| 686 | `services/audit/event.go` | 131-134 | yes |
| 687 | `custom/conf/app.example.ini` | 576 | yes |
| 687 | `models/audit/audit_event.go` | 22-38 | yes |
| 688 | `cmd/dump.go` | 26 | yes |
| 688 | `contrib/upgrade.sh` | 130 | yes |
| 689 | `cmd/restore_repo.go` | 18 | yes |
| 689 | `contrib/upgrade.sh` | 130-132 | yes |
| 690 | `cmd/generate.go` | 56-81 | yes |
| 690 | `custom/conf/app.example.ini` | 446-456 | yes |
| 691 | `modules/auth/password/hash/hash.go` | 116 | yes |
| 692 | `custom/conf/app.example.ini` | 539-544 | yes |
| 692 | `modules/updatechecker/update_checker.go` | 31-35 | yes |
| 692 | `services/migrations/http_client.go` | 37 | yes |
| 692 | `services/webhook/deliver.go` | 277 | yes |
| 693 | `Makefile` | 497-499 | yes |
| 699 | `README.md` | 14-19 | yes |
| 700 | `MAINTAINERS` |  | yes |
| 700 | `docs/community-governance.md` | 132 | yes |
| 700 | `docs/community-governance.md` | 161 | yes |
| 700 | `docs/community-governance.md` | 186 | yes |
| 701 | `CONTRIBUTING.md` | 147 | yes |
| 701 | `CONTRIBUTING.md` | 53 | yes |
| 701 | `docs/community-governance.md` | 35 | yes |
| 703 | `CONTRIBUTING.md` | 277 | yes |
| 703 | `README.md` | 32-38 | yes |
| 704 | `.github/workflows/release-create-tag.yml` | 14 | yes |
| 704 | `.github/workflows/release-nightly.yml` | 37 | yes |
| 704 | `.github/workflows/release-tag-version.yml` | 16 | yes |
| 704 | `CONTRIBUTING.md` | 231-256 | yes |
| 704 | `docs/release-management.md` |  | yes |
| 705 | `Makefile` | 368 | yes |
| 705 | `docs/testing.md` | 10 | yes |
| 706 | `.github/workflows/pull-db-tests.yml` | 173 | yes |
| 706 | `.github/workflows/pull-db-tests.yml` | 18 | yes |
| 706 | `.github/workflows/pull-db-tests.yml` | 220 | yes |
| 706 | `.github/workflows/pull-db-tests.yml` | 248 | yes |
| 706 | `.github/workflows/pull-db-tests.yml` | 93 | yes |
| 706 | `Makefile` | 436 | yes |
| 706 | `tests/integration/` |  | yes |
| 706 | `tests/integration/actions_oidc_test.go` |  | yes |
| 706 | `tests/integration/admin_audit_test.go` |  | yes |
| 707 | `Makefile` | 453 | yes |
| 707 | `modelmigration/migrationtest/` |  | yes |
| 708 | `.github/workflows/pull-e2e-tests.yml` | 18 | yes |
| 708 | `Makefile` | 473 | yes |
| 708 | `tests/e2e/` |  | yes |
| 709 | `Makefile` | 373 | yes |
| 709 | `vitest.config.ts` |  | yes |
| 709 | `web_src/` |  | yes |
| 710 | `tests/fuzz/` |  | yes |
| 711 | `.github/workflows/pull-compliance.yml` | 18-81 | yes |
| 711 | `Makefile` | 269 | yes |
| 719 | `custom/conf/app.example.ini` |  | yes |
| 744 | `routers/init.go` | 172 | yes |
| 744 | `routers/init.go` | 176-207 | yes |
| 744 | `routers/private/internal.go` | 71-78 | yes |
| 761 | `routers/private/hook_post_receive.go` | 80 | yes |
| 761 | `routers/private/hook_pre_receive.go` | 75-109 | yes |
| 761 | `routers/private/internal.go` | 84-88 | yes |
| 761 | `routers/private/serv.go` | 68 | yes |
| 781 | `routers/web/auth/auth.go` | 288-365 | yes |
| 781 | `services/auth/signin.go` | 27-100 | yes |
| 794 | `models/auth/access_token.go` | 22 | yes |
| 794 | `models/auth/twofactor.go` | 62 | yes |
| 794 | `models/repo/repo.go` | 155 | yes |
| 794 | `models/secret/secret.go` | 42 | yes |
| 794 | `models/user/user.go` | 118 | yes |
| 794 | `models/webhook/webhook.go` | 125 | yes |
| 794 | `routers/web/repo/issue_new.go` | 369 | yes |
| 806 | `contrib/service/systemd/gitea.service` |  | yes |
| 806 | `custom/conf/app.example.ini` | 476-479 | yes |
| 806 | `docker/root/usr/bin/entrypoint` |  | yes |
| 812 | `routers/web/web.go` | 166 | yes |
| 813 | `routers/web/web.go` | 903-909 | yes |
| 814 | `models/auth/access_token_scope.go` | 58-90 | yes |
| 815 | `models/auth/access_token_scope.go` | 60 | yes |
| 816 | `routers/api/v1/api.go` | 111-146 | yes |
| 816 | `routers/web/web.go` | 787 | yes |
| 817 | `routers/private/internal.go` | 25-43 | yes |
| 818 | `custom/conf/app.example.ini` | 442 | yes |
| 819 | `models/auth/source.go` | 137-147 | yes |
| 820 | `custom/conf/app.example.ini` | 539-562 | yes |
| 821 | `models/repo/mirror.go` | 41 | yes |
| 822 | `routers/web/repo/migrate.go` | 125 | yes |
| 823 | `README.md` | 14-19 | yes |
| 824 | `routers/api/actions/runner/runner.go` | 30 | yes |
| 825 | `models/actions/scoped_workflow.go` | 41 | yes |
| 826 | `routers/api/packages/api.go` | 543-548 | yes |
| 827 | `routers/common/lfs.go` | 18-29 | yes |
| 828 | `routers/private/internal.go` | 84-86 | yes |
| 829 | `models/webhook/webhook.go` | 123 | yes |
| 830 | `models/git/protected_branch.go` | 83 | yes |
| 831 | `models/deploykey/deploykey.go` | 58 | yes |
| 832 | `routers/web/web.go` | 136-138 | yes |
| 833 | `custom/conf/app.example.ini` | 1666 | yes |
| 834 | `services/cron/cron.go` | 17-24 | yes |
| 835 | `models/audit/audit_event.go` | 19 | yes |
| 836 | `routers/api/v1/api.go` | 1010-1013 | yes |
| 837 | `custom/conf/app.example.ini` | 580-594 | yes |
| 838 | `routers/common/qos.go` | 46-52 | yes |
| 839 | `routers/common/maintenancemode.go` |  | yes |
| 840 | `cmd/doctor.go` | 28-41 | yes |
| 841 | `cmd/dump.go` | 26 | yes |
| 842 | `routers/web/passkey.go` |  | yes |
| 842 | `routers/web/web.go` | 581-586 | yes |
| 848 | `templates/` |  | yes |
| 851 | `cmd/restore_repo.go` | 18 | yes |
| 852 | `contrib/upgrade.sh` | 132 | yes |
| 853 | `routers/web/web.go` | 190-194 | yes |
| 854 | `modules/setting/session.go` | 64 | yes |
| 855 | `models/auth/source.go` | 143 | yes |
| 855 | `modules/setting/security.go` | 193-197 | yes |
| 856 | `custom/conf/app.example.ini` | 536-537 | yes |
| 856 | `web_src/` |  | yes |
| 857 | `docs/appdoc-2.3/facts-summary.md` | 5 | yes |
| 877 | `modules/setting/security.go` | 193-197 | yes |
| 888 | `web_src/` |  | yes |
| 894 | `Dockerfile` | 12 | yes |
| 894 | `Dockerfile` | 3 | yes |
| 894 | `Dockerfile` | 51 | yes |
| 895 | `package.json` | 3-6 | yes |
| 896 | `routers/init.go` | 115-119 | yes |
| 897 | `.github/workflows/pull-db-tests.yml` | 173 | yes |
| 897 | `.github/workflows/pull-db-tests.yml` | 18 | yes |
| 897 | `.github/workflows/pull-db-tests.yml` | 220 | yes |
| 897 | `.github/workflows/pull-db-tests.yml` | 93 | yes |
| 897 | `custom/conf/app.example.ini` | 363-396 | yes |
| 898 | `Dockerfile` | 14-15 | yes |
| 902 | `cmd/admin_user_create.go` | 24 | yes |
| 902 | `cmd/migrate.go` | 26-43 | yes |
| 902 | `routers/init.go` | 136 | yes |
| 902 | `routers/install/routes.go` | 31 | yes |
| 903 | `models/fixtures/` |  | yes |
| 903 | `models/unittest/` |  | yes |
| 904 | `cmd/web.go` | 212-214 | yes |
| 904 | `cmd/web.go` | 218 | yes |
| 905 | `custom/conf/app.example.ini` | 1592 | yes |
| 905 | `custom/conf/app.example.ini` | 1653 | yes |
| 905 | `custom/conf/app.example.ini` | 1666 | yes |
| 905 | `custom/conf/app.example.ini` | 1940 | yes |
| 905 | `custom/conf/app.example.ini` | 1974 | yes |
| 905 | `custom/conf/app.example.ini` | 2891 | yes |
| 906 | `cmd/migrate_storage.go` | 30-51 | yes |
| 910 | `custom/conf/app.example.ini` | 1979-2000 | yes |
| 910 | `modules/setting/session.go` | 39 | yes |
| 911 | `modules/setting/session.go` | 64 | yes |
| 911 | `modules/web/middleware/cookie.go` | 71-73 | yes |
| 912 | `custom/conf/app.example.ini` | 459 | yes |
| 913 | `models/auth/access_token.go` | 20-33 | yes |
| 914 | `custom/conf/app.example.ini` | 626-632 | yes |
| 915 | `routers/api/actions/runner/interceptor.go` | 97-105 | yes |
| 921 | `routers/init.go` | 68-74 | yes |
| 922 | `custom/conf/app.example.ini` | 453-456 | yes |
| 922 | `routers/private/internal.go` | 27-31 | yes |
| 923 | `cmd/web.go` | 212-214 | yes |
| 924 | `cmd/manager.go` | 73 | yes |
| 924 | `contrib/upgrade.sh` | 125 | yes |
| 925 | `contrib/upgrade.sh` | 127 | yes |
| 925 | `contrib/upgrade.sh` | 132 | yes |
| 925 | `contrib/upgrade.sh` | 60-61 | yes |
| 926 | `services/cron/tasks_actions.go` | 27 | yes |
| 926 | `services/cron/tasks_actions.go` | 37 | yes |
| 927 | `services/webhook/deliver.go` | 263-267 | yes |
| 928 | `cmd/web.go` | 255-256 | yes |
| 928 | `custom/conf/app.example.ini` | 302 | yes |
| 934 | `.github/workflows/release-nightly.yml` | 37 | yes |
| 934 | `.github/workflows/release-tag-version.yml` | 16 | yes |
| 934 | `Dockerfile` | 3 | yes |
| 934 | `Dockerfile` | 3-51 | yes |
| 934 | `Makefile` | 477 | yes |
| 934 | `Makefile` | 477-483 | yes |
| 934 | `Makefile` | 510 | yes |
| 935 | `.github/workflows/pull-db-tests.yml` | 115 | yes |
| 935 | `.github/workflows/pull-db-tests.yml` | 173 | yes |
| 935 | `.github/workflows/pull-db-tests.yml` | 18 | yes |
| 935 | `.github/workflows/pull-db-tests.yml` | 220 | yes |
| 935 | `.github/workflows/pull-db-tests.yml` | 93 | yes |
| 935 | `Makefile` | 368 | yes |
| 935 | `Makefile` | 368 | yes |
| 935 | `Makefile` | 436 | yes |
| 935 | `Makefile` | 453 | yes |
| 935 | `Makefile` | 473 | yes |
| 936 | `Dockerfile` | 89 | yes |
| 936 | `cmd/web.go` | 39 | yes |
| 936 | `cmd/web.go` | 39-76 | yes |
| 936 | `contrib/service/systemd/gitea.service` |  | yes |
| 936 | `docker/root/usr/bin/entrypoint` |  | yes |
| 937 | `cmd/migrate.go` | 26-43 | yes |
| 937 | `contrib/upgrade.sh` |  | yes |
| 937 | `contrib/upgrade.sh` | 124 | yes |
| 937 | `contrib/upgrade.sh` | 124-136 | yes |
| 938 | `contrib/upgrade.sh` | 132 | yes |
| 939 | `cmd/dump.go` | 26 | yes |
| 939 | `cmd/dump.go` | 26-92 | yes |
| 939 | `cmd/dump_repo.go` | 28 | yes |
| 939 | `contrib/upgrade.sh` | 130 | yes |
| 940 | `cmd/restore_repo.go` | 18 | yes |
| 940 | `cmd/restore_repo.go` | 18-40 | yes |
| 941 | `cmd/actions.go` | 27 | yes |
| 941 | `cmd/admin_regenerate.go` | 18-26 | yes |
| 941 | `cmd/generate.go` | 33 | yes |
| 941 | `cmd/generate.go` | 33-81 | yes |
| 941 | `custom/conf/app.example.ini` | 445 | yes |
| 941 | `modules/setting/security.go` | 147-152 | yes |
| 943 | `cmd/admin.go` | 22-77 | yes |
| 943 | `cmd/admin_auth.go` | 22-31 | yes |
| 943 | `cmd/admin_auth_ldap.go` | 179-212 | yes |
| 943 | `cmd/admin_auth_oauth.go` | 137-148 | yes |
| 943 | `cmd/admin_auth_smtp.go` | 75-89 | yes |
| 943 | `cmd/admin_user.go` | 30 | yes |
| 943 | `cmd/admin_user_change_type.go` | 19 | yes |
| 943 | `cmd/cert.go` | 31 | yes |
| 943 | `cmd/config.go` | 19 | yes |
| 943 | `cmd/docs.go` | 18 | yes |
| 943 | `cmd/doctor.go` | 41-65 | yes |
| 943 | `cmd/doctor.go` | 81 | yes |
| 943 | `cmd/doctor_convert.go` | 18 | yes |
| 943 | `cmd/embedded.go` | 29-72 | yes |
| 943 | `cmd/keys.go` | 21 | yes |
| 943 | `cmd/manager.go` | 34-95 | yes |
| 943 | `cmd/manager_logging.go` | 18-49 | yes |
| 950 | `custom/conf/app.example.ini` | 446 | yes |
| 951 | `custom/conf/app.example.ini` | 453 | yes |
| 952 | `docker/root/etc/templates/app.ini` | 30 | yes |
| 953 | `modules/setting/lfs.go` | 79 | yes |
| 954 | `modules/setting/oauth2.go` | 147 | yes |
| 955 | `modules/setting/security.go` | 167 | yes |
| 956 | `modules/setting/security.go` | 175 | yes |
| 957 | `modules/setting/security.go` | 180 | yes |
| 958 | `modules/setting/security.go` | 181 | yes |
| 959 | `modules/setting/security.go` | 209 | yes |
| 960 | `modules/setting/security.go` | 224 | yes |
| 961 | `modules/setting/service.go` | 140 | yes |
| 962 | `modules/setting/service.go` | 173 | yes |
| 963 | `modules/setting/service.go` | 183 | yes |
| 964 | `modules/setting/service.go` | 185 | yes |
| 965 | `modules/setting/service.go` | 188 | yes |
| 966 | `modules/setting/service.go` | 190 | yes |
| 967 | `modules/setting/service.go` | 193 | yes |
| 968 | `modules/setting/storage.go` | 109 | yes |
| 969 | `modules/setting/storage.go` | 118 | yes |
| 970 | `routers/install/install.go` | 356 | yes |
| 971 | `services/actions/init.go` | 24 | yes |
| 972 | `services/actions/init.go` | 25 | yes |
| 973 | `build/generate-go-licenses.go` | 213 | yes |
| 974 | `cmd/hook.go` | 174 | yes |
| 975 | `cmd/web.go` | 180 | yes |
| 976 | `cmd/web.go` | 270 | yes |
| 977 | `cmd/web.go` | 323 | yes |
| 978 | `custom/conf/app.example.ini` | 363 | yes |
| 979 | `custom/conf/app.example.ini` | 364 | yes |
| 980 | `custom/conf/app.example.ini` | 365 | yes |
| 981 | `custom/conf/app.example.ini` | 366 | yes |
| 982 | `custom/conf/app.example.ini` | 442 | yes |
| 983 | `custom/conf/app.example.ini` | 603 | yes |
| 984 | `custom/conf/app.example.ini` | 663 | yes |
| 985 | `custom/conf/app.example.ini` | 666 | yes |
| 986 | `docker/root/etc/templates/app.ini` | 1 | yes |
| 987 | `docker/root/etc/templates/app.ini` | 2 | yes |
| 988 | `docker/root/etc/templates/app.ini` | 5 | yes |
| 989 | `docker/root/etc/templates/app.ini` | 8 | yes |
| 990 | `docker/root/etc/templates/app.ini` | 11 | yes |
| 991 | `docker/root/etc/templates/app.ini` | 14 | yes |
| 992 | `docker/root/etc/templates/app.ini` | 15 | yes |
| 993 | `docker/root/etc/templates/app.ini` | 16 | yes |
| 994 | `docker/root/etc/templates/app.ini` | 17 | yes |
| 995 | `docker/root/etc/templates/app.ini` | 18 | yes |
| 996 | `docker/root/etc/templates/app.ini` | 19 | yes |
| 997 | `docker/root/etc/templates/app.ini` | 20 | yes |
| 998 | `docker/root/etc/templates/app.ini` | 21 | yes |
| 999 | `docker/root/etc/templates/app.ini` | 22 | yes |
| 1000 | `docker/root/etc/templates/app.ini` | 25 | yes |
| 1001 | `docker/root/etc/templates/app.ini` | 31 | yes |
| 1002 | `docker/root/etc/templates/app.ini` | 34 | yes |
| 1003 | `docker/root/etc/templates/app.ini` | 37 | yes |
| 1004 | `docker/root/etc/templates/app.ini` | 40 | yes |
| 1005 | `docker/root/etc/templates/app.ini` | 41 | yes |
| 1006 | `docker/root/etc/templates/app.ini` | 44 | yes |
| 1007 | `docker/root/etc/templates/app.ini` | 49 | yes |
| 1008 | `docker/root/etc/templates/app.ini` | 56 | yes |
| 1009 | `docker/root/etc/templates/app.ini` | 57 | yes |
| 1010 | `docker/root/etc/templates/app.ini` | 60 | yes |
| 1011 | `docker/rootless/etc/templates/app.ini` | 2 | yes |
| 1012 | `docker/rootless/etc/templates/app.ini` | 21 | yes |
| 1013 | `docker/rootless/etc/templates/app.ini` | 24 | yes |
| 1014 | `models/unittest/testdb.go` | 223 | yes |
| 1015 | `modules/egress/policies.go` | 50 | yes |
| 1016 | `modules/egress/policies.go` | 50 | yes |
| 1017 | `modules/git/git.go` | 165 | yes |
| 1018 | `modules/graceful/manager_windows.go` | 37 | yes |
| 1019 | `modules/private/internal.go` | 31 | yes |
| 1020 | `modules/setting/actions.go` | 133 | yes |
| 1021 | `modules/setting/actions.go` | 134 | yes |
| 1022 | `modules/setting/actions.go` | 135 | yes |
| 1023 | `modules/setting/admin.go` | 31 | yes |
| 1024 | `modules/setting/admin.go` | 32 | yes |
| 1025 | `modules/setting/admin.go` | 33 | yes |
| 1026 | `modules/setting/admin.go` | 34 | yes |
| 1027 | `modules/setting/attachment.go` | 29 | yes |
| 1028 | `modules/setting/attachment.go` | 30 | yes |
| 1029 | `modules/setting/attachment.go` | 31 | yes |
| 1030 | `modules/setting/attachment.go` | 32 | yes |
| 1031 | `modules/setting/cache.go` | 47 | yes |
| 1032 | `modules/setting/cache.go` | 51 | yes |
| 1033 | `modules/setting/camo.go` | 22 | yes |
| 1034 | `modules/setting/database.go` | 63 | yes |
| 1035 | `modules/setting/database.go` | 64 | yes |
| 1036 | `modules/setting/database.go` | 65 | yes |
| 1037 | `modules/setting/database.go` | 69 | yes |
| 1038 | `modules/setting/database.go` | 75 | yes |
| 1039 | `modules/setting/database.go` | 77 | yes |
| 1040 | `modules/setting/database.go` | 79 | yes |
| 1041 | `modules/setting/database.go` | 83 | yes |
| 1042 | `modules/setting/database.go` | 85 | yes |
| 1043 | `modules/setting/database.go` | 87 | yes |
| 1044 | `modules/setting/database.go` | 88 | yes |
| 1045 | `modules/setting/database.go` | 89 | yes |
| 1046 | `modules/setting/database.go` | 90 | yes |
| 1047 | `modules/setting/git.go` | 96 | yes |
| 1048 | `modules/setting/global_lock.go` | 21 | yes |
| 1049 | `modules/setting/global_lock.go` | 25 | yes |
| 1050 | `modules/setting/i18n.go` | 59 | yes |
| 1051 | `modules/setting/i18n.go` | 63 | yes |
| 1052 | `modules/setting/indexer.go` | 55 | yes |
| 1053 | `modules/setting/indexer.go` | 63 | yes |
| 1054 | `modules/setting/indexer.go` | 76 | yes |
| 1055 | `modules/setting/indexer.go` | 78 | yes |
| 1056 | `modules/setting/indexer.go` | 79 | yes |
| 1057 | `modules/setting/indexer.go` | 80 | yes |
| 1058 | `modules/setting/indexer.go` | 81 | yes |
| 1059 | `modules/setting/indexer.go` | 85 | yes |
| 1060 | `modules/setting/indexer.go` | 86 | yes |
| 1061 | `modules/setting/indexer.go` | 88 | yes |
| 1062 | `modules/setting/indexer.go` | 89 | yes |
| 1063 | `modules/setting/indexer.go` | 90 | yes |
| 1064 | `modules/setting/indexer.go` | 91 | yes |
| 1065 | `modules/setting/indexer.go` | 92 | yes |
| 1066 | `modules/setting/indexer.go` | 93 | yes |
| 1067 | `modules/setting/lfs.go` | 63 | yes |
| 1068 | `modules/setting/log.go` | 39 | yes |
| 1069 | `modules/setting/log.go` | 40 | yes |
| 1070 | `modules/setting/log.go` | 49 | yes |
| 1071 | `modules/setting/log.go` | 51 | yes |
| 1072 | `modules/setting/log.go` | 52 | yes |
| 1073 | `modules/setting/log.go` | 59 | yes |
| 1074 | `modules/setting/log.go` | 64 | yes |
| 1075 | `modules/setting/log.go` | 65 | yes |
| 1076 | `modules/setting/log.go` | 67 | yes |
| 1077 | `modules/setting/log.go` | 73 | yes |
| 1078 | `modules/setting/log.go` | 74 | yes |
| 1079 | `modules/setting/log.go` | 80 | yes |
| 1080 | `modules/setting/log.go` | 86 | yes |
| 1081 | `modules/setting/log.go` | 87 | yes |
| 1082 | `modules/setting/log.go` | 93 | yes |
| 1083 | `modules/setting/mailer.go` | 72 | yes |
| 1084 | `modules/setting/mailer.go` | 81 | yes |
| 1085 | `modules/setting/mailer.go` | 91 | yes |
| 1086 | `modules/setting/mailer.go` | 92 | yes |
| 1087 | `modules/setting/mailer.go` | 95 | yes |
| 1088 | `modules/setting/mailer.go` | 101 | yes |
| 1089 | `modules/setting/mailer.go` | 103 | yes |
| 1090 | `modules/setting/mailer.go` | 104 | yes |
| 1091 | `modules/setting/mailer.go` | 105 | yes |
| 1092 | `modules/setting/mailer.go` | 106 | yes |
| 1093 | `modules/setting/mailer.go` | 107 | yes |
| 1094 | `modules/setting/mailer.go` | 108 | yes |
| 1095 | `modules/setting/mailer.go` | 109 | yes |
| 1096 | `modules/setting/mailer.go` | 109 | yes |
| 1097 | `modules/setting/mailer.go` | 163 | yes |
| 1098 | `modules/setting/mailer.go` | 218 | yes |
| 1099 | `modules/setting/mailer.go` | 228 | yes |
| 1104 | `crowdin.yml` | 2 | yes |
| 1104 | `modelmigration/fixtures/Test_RemigrateU2FCredentials/expected_webauthn_credential.yml` | 3 | yes |
| 1104 | `models/fixtures/user.yml` | 11 | yes |
| 1104 | `modules/actions/jobparser/testdata/has_secrets.in.yaml` | 8 | yes |
| 1106 | `custom/conf/app.example.ini` | 1927 | yes |
| 1106 | `custom/conf/app.example.ini` | 520 | yes |
| 1106 | `custom/conf/app.example.ini` | 841 | yes |
| 1106 | `custom/conf/app.example.ini` | 861 | yes |
| 1106 | `modules/setting/incoming_email.go` | 23 | yes |
| 1106 | `modules/setting/security.go` | 224 | yes |
| 1106 | `modules/setting/service.go` | 141 | yes |
| 1106 | `modules/setting/service.go` | 172 | yes |
| 1110 | `custom/conf/app.example.ini` | 442 | yes |
| 1111 | `custom/conf/app.example.ini` | 446 | yes |
| 1112 | `custom/conf/app.example.ini` | 453 | yes |
| 1113 | `custom/conf/app.example.ini` | 520 | yes |
| 1114 | `custom/conf/app.example.ini` | 542 | yes |
| 1115 | `custom/conf/app.example.ini` | 572 | yes |
| 1116 | `custom/conf/app.example.ini` | 576 | yes |
| 1117 | `custom/conf/app.example.ini` | 2758 | yes |
| 1118 | `custom/conf/app.example.ini` | 1991 | yes |
| 1119 | `custom/conf/app.example.ini` | 853 | yes |
| 1120 | `custom/conf/app.example.ini` | 861 | yes |
| 1121 | `custom/conf/app.example.ini` | 841 | yes |
| 1122 | `custom/conf/app.example.ini` | 1022 | yes |
| 1123 | `custom/conf/app.example.ini` | 1927 | yes |
| 1163 | `custom/conf/app.example.ini` | 2143 | yes |
| 1163 | `services/cron/tasks_actions.go` | 27-80 | yes |
| 1163 | `services/cron/tasks_basic.go` | 31 | yes |
| 1163 | `services/cron/tasks_basic.go` | 88 | yes |
| 1163 | `services/cron/tasks_extended.go` | 141-146 | yes |
| 1163 | `services/cron/tasks_extended.go` | 197-199 | yes |

## Verification

**Source-to-claim audit:** performed (auditor: independent). 140 rows: 120 Supported, 14 Corrected, 2 Downgraded, 4 Answerable.

| Section | IDs with a register row |
|---|---|
| 4 | 10 of 21 |
| 6 | 3 of 27 |
| 8.1 | 2 of 14 |
| 8.3 | 5 of 12 |
| 10.1 | 14 of 14 |
| 14 | 10 of 10 |
| 15 | 4 of 22 |
| 7 (workflows) | 10 of 10 |
