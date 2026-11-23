# Check: PASS

**Scope.** Run by AppDoc 2.5.0. This Check verifies **resolution and structure**: every Citation points to a real file and line inside the Target (see the Citation register), and every Evidence Register row's anchor text appears in the lines it cites. It does **not** judge whether a claim's wording follows from those lines; that is the source-to-claim audit, recorded in `evidence.jsonl`. A PASS is not an accuracy certification.

## Universal claims cite single lines (advisory)

1 universal claim cites only single lines. This is not a problem; `appdoc check --strict` fails on it.

- line 436: `2. A scheduled job starts due workflow schedules every minute (`services/cron/tasks_actions.go:59`).`

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
| 56 | `docker/` |  | yes |
| 57 | `tools/` |  | yes |
| 58 | `build/` |  | yes |
| 59 | `docs/` |  | yes |
| 60 | `assets/` |  | yes |
| 61 | `snap/` |  | yes |
| 62 | `.devcontainer/` |  | yes |
| 63 | `custom/` |  | yes |
| 68 | `modules/git/tests/repos/repo2_empty/` |  | yes |
| 69 | `routers/private/tests/repos/repo1_hook_verification/objects/tmp_objdir-incoming-a21648/` |  | yes |
| 70 | `templates/custom/` |  | yes |
| 71 | `tests/gitea-repositories-meta/org26/repo_external_tracker.git/` |  | yes |
| 72 | `tests/gitea-repositories-meta/org26/repo_external_tracker_alpha.git/` |  | yes |
| 73 | `tests/gitea-repositories-meta/org26/repo_external_tracker_numeric.git/` |  | yes |
| 74 | `tests/gitea-repositories-meta/org3/repo3.git/` |  | yes |
| 75 | `tests/gitea-repositories-meta/org3/repo3.git/hooks/` |  | yes |
| 76 | `tests/gitea-repositories-meta/org3/repo3.git/objects/` |  | yes |
| 77 | `tests/gitea-repositories-meta/org3/repo5.git/` |  | yes |
| 81 | `package.json` |  | yes |
| 81 | `pyproject.toml` |  | yes |
| 81 | `web_src/` |  | yes |
| 83 | `CONTRIBUTING.md` |  | yes |
| 83 | `MAINTAINERS` |  | yes |
| 83 | `build/` |  | yes |
| 83 | `modelmigration/` |  | yes |
| 83 | `options/locale/` |  | yes |
| 83 | `public/` |  | yes |
| 83 | `templates/` |  | yes |
| 83 | `templates/swagger/` |  | yes |
| 83 | `tests/` |  | yes |
| 83 | `web_src/` |  | yes |
| 87 | `README.md` | 14-19 | yes |
| 87 | `routers/api/actions/runner/runner.go` | 30 | yes |
| 87 | `routers/init.go` | 176-207 | yes |
| 95 | `cmd/main.go` |  | yes |
| 95 | `modules/ssh/server.go` |  | yes |
| 95 | `routers/init.go` | 172 | yes |
| 95 | `routers/init.go` | 176-207 | yes |
| 97 | `custom/conf/app.example.ini` | 1592 | yes |
| 97 | `custom/conf/app.example.ini` | 1666 | yes |
| 97 | `custom/conf/app.example.ini` | 1798 | yes |
| 97 | `custom/conf/app.example.ini` | 1899 | yes |
| 97 | `custom/conf/app.example.ini` | 1940 | yes |
| 97 | `custom/conf/app.example.ini` | 1974 | yes |
| 97 | `custom/conf/app.example.ini` | 2891 | yes |
| 97 | `custom/conf/app.example.ini` | 363-396 | yes |
| 97 | `modules/hcaptcha/hcaptcha.go` | 96 | yes |
| 97 | `routers/api/actions/runner/interceptor.go` | 46 | yes |
| 97 | `routers/init.go` | 115 | yes |
| 97 | `services/auth/source/` |  | yes |
| 97 | `services/cron/tasks_extended.go` | 163-168 | yes |
| 97 | `services/migrations/github_graphql.go` | 166 | yes |
| 97 | `services/webhook/deliver.go` | 277 | yes |
| 103 | `cmd/admin.go` | 22 | yes |
| 103 | `cmd/doctor.go` | 28 | yes |
| 103 | `cmd/dump.go` | 26 | yes |
| 103 | `cmd/generate.go` | 22 | yes |
| 103 | `cmd/hook.go` | 33 | yes |
| 103 | `cmd/main.go` |  | yes |
| 103 | `cmd/manager.go` | 18 | yes |
| 103 | `cmd/migrate.go` | 19 | yes |
| 103 | `cmd/web.go` | 332-392 | yes |
| 103 | `cmd/web.go` | 39-76 | yes |
| 104 | `routers/` |  | yes |
| 104 | `routers/api/actions/actions.go` | 17 | yes |
| 104 | `routers/api/packages/api.go` |  | yes |
| 104 | `routers/api/v1/api.go` | 939 | yes |
| 104 | `routers/init.go` | 176-214 | yes |
| 104 | `routers/private/internal.go` | 71 | yes |
| 104 | `routers/web/web.go` | 257-321 | yes |
| 105 | `services/` |  | yes |
| 105 | `services/actions/run.go` |  | yes |
| 105 | `services/auth/auth.go` |  | yes |
| 105 | `services/cron/cron.go` |  | yes |
| 105 | `services/mailer/` |  | yes |
| 105 | `services/migrations/` |  | yes |
| 105 | `services/pull/` |  | yes |
| 105 | `services/repository/` |  | yes |
| 105 | `services/webhook/deliver.go` | 274 | yes |
| 106 | `modelmigration/migrations.go` |  | yes |
| 106 | `models/` |  | yes |
| 106 | `models/issues/issue.go` | 130 | yes |
| 106 | `models/repo/repo.go` | 225 | yes |
| 106 | `models/user/user.go` | 197 | yes |
| 107 | `modules/` |  | yes |
| 107 | `modules/egress/` |  | yes |
| 107 | `modules/git/` |  | yes |
| 107 | `modules/indexer/` |  | yes |
| 107 | `modules/log/` |  | yes |
| 107 | `modules/markup/` |  | yes |
| 107 | `modules/queue/` |  | yes |
| 107 | `modules/setting/session.go` | 64 | yes |
| 107 | `modules/storage/minio.go` | 129 | yes |
| 108 | `package.json` | 3-6 | yes |
| 108 | `templates/` |  | yes |
| 108 | `web_src/` |  | yes |
| 109 | `routers/init.go` | 114-173 | yes |
| 132 | `routers/init.go` | 172 | yes |
| 132 | `routers/init.go` | 176-207 | yes |
| 132 | `routers/private/internal.go` | 71-78 | yes |
| 136 | `routers/web/web.go` | 124-158 | yes |
| 136 | `routers/web/web.go` | 160-165 | yes |
| 137 | `models/auth/access_token_scope.go` | 58-90 | yes |
| 137 | `routers/api/v1/api.go` | 277-308 | yes |
| 137 | `routers/api/v1/api.go` | 851-862 | yes |
| 138 | `services/auth/basic.go` | 71-146 | yes |
| 139 | `routers/web/web.go` | 177-245 | yes |
| 139 | `routers/web/web.go` | 893-909 | yes |
| 140 | `routers/api/v1/api.go` | 311-318 | yes |
| 140 | `routers/api/v1/api.go` | 350-357 | yes |
| 140 | `routers/api/v1/api.go` | 391-410 | yes |
| 140 | `routers/api/v1/api.go` | 421 | yes |
| 141 | `routers/private/internal.go` | 25-43 | yes |
| 142 | `routers/api/actions/runner/interceptor.go` | 46-107 | yes |
| 143 | `routers/web/auth/auth.go` | 326-365 | yes |
| 143 | `services/auth/signin.go` | 104-125 | yes |
| 143 | `services/auth/signin.go` | 27-100 | yes |
| 144 | `custom/conf/app.example.ini` | 525-527 | yes |
| 144 | `modules/setting/security.go` | 193-197 | yes |
| 144 | `routers/api/v1/api.go` | 226-229 | yes |
| 205 | `cmd/web.go` | 285-286 | yes |
| 205 | `custom/conf/app.example.ini` | 442 | yes |
| 205 | `routers/install/routes.go` | 30-32 | yes |
| 206 | `routers/web/auth/auth.go` | 288 | yes |
| 206 | `routers/web/auth/auth.go` | 289-292 | yes |
| 206 | `routers/web/auth/auth.go` | 302-306 | yes |
| 206 | `routers/web/auth/auth.go` | 326-345 | yes |
| 206 | `routers/web/web.go` | 567-594 | yes |
| 206 | `routers/web/web.go` | 725-741 | yes |
| 207 | `models/auth/oauth2.go` | 57-59 | yes |
| 207 | `routers/web/web.go` | 362 | yes |
| 207 | `routers/web/web.go` | 521 | yes |
| 207 | `routers/web/web.go` | 592-606 | yes |
| 207 | `routers/web/web.go` | 605 | yes |
| 208 | `models/auth/access_token.go` | 43 | yes |
| 208 | `models/user/user.go` | 197 | yes |
| 208 | `routers/web/web.go` | 198-211 | yes |
| 208 | `routers/web/web.go` | 608-723 | yes |
| 208 | `routers/web/web.go` | 723 | yes |
| 209 | `models/repo/repo.go` | 225 | yes |
| 209 | `routers/web/repo/repo.go` | 193-260 | yes |
| 209 | `routers/web/repo/repo.go` | 222 | yes |
| 209 | `routers/web/web.go` | 1071-1075 | yes |
| 209 | `routers/web/web.go` | 1158-1260 | yes |
| 209 | `routers/web/web.go` | 1430-1500 | yes |
| 209 | `routers/web/web.go` | 1744-1747 | yes |
| 209 | `routers/web/web.go` | 893 | yes |
| 210 | `models/issues/issue.go` | 130 | yes |
| 210 | `models/issues/pull.go` | 170 | yes |
| 210 | `routers/web/repo/issue_new.go` | 331 | yes |
| 210 | `routers/web/repo/pull.go` | 1088 | yes |
| 210 | `routers/web/repo/pull.go` | 1110 | yes |
| 210 | `routers/web/repo/pull.go` | 1195 | yes |
| 210 | `routers/web/web.go` | 1308-1416 | yes |
| 210 | `routers/web/web.go` | 1365 | yes |
| 210 | `routers/web/web.go` | 1628-1657 | yes |
| 211 | `models/project/project.go` | 184 | yes |
| 211 | `routers/api/v1/api.go` | 754 | yes |
| 211 | `routers/api/v1/api.go` | 768-806 | yes |
| 211 | `routers/web/web.go` | 1112-1140 | yes |
| 211 | `routers/web/web.go` | 1519-1540 | yes |
| 211 | `routers/web/web.go` | 330-348 | yes |
| 211 | `routers/web/web.go` | 341 | yes |
| 212 | `routers/web/repo/wiki.go` |  | yes |
| 212 | `routers/web/web.go` | 1586-1600 | yes |
| 212 | `routers/web/web.go` | 1589 | yes |
| 213 | `models/actions/run.go` | 79 | yes |
| 213 | `models/secret/secret.go` | 95 | yes |
| 213 | `routers/api/actions/artifacts.go` | 119-124 | yes |
| 213 | `routers/api/actions/runner/interceptor.go` | 46-107 | yes |
| 213 | `routers/api/actions/runner/runner.go` | 30 | yes |
| 213 | `routers/init.go` | 196-207 | yes |
| 213 | `routers/web/web.go` | 1541-1585 | yes |
| 213 | `routers/web/web.go` | 479-510 | yes |
| 213 | `services/actions/run.go` |  | yes |
| 214 | `cmd/web.go` | 345-347 | yes |
| 214 | `models/asymkey/ssh_key.go` | 57 | yes |
| 214 | `models/git/lfs.go` | 89 | yes |
| 214 | `routers/common/lfs.go` | 18-29 | yes |
| 214 | `routers/private/hook_pre_receive.go` | 111-135 | yes |
| 214 | `routers/private/hook_pre_receive.go` | 75 | yes |
| 214 | `routers/private/serv.go` | 68 | yes |
| 214 | `routers/web/githttp.go` | 13-24 | yes |
| 215 | `models/organization/team.go` | 134-138 | yes |
| 215 | `routers/api/v1/api.go` | 1736 | yes |
| 215 | `routers/api/v1/api.go` | 1801 | yes |
| 215 | `routers/api/v1/api.go` | 421-577 | yes |
| 215 | `routers/web/web.go` | 937-1068 | yes |
| 215 | `routers/web/web.go` | 937-1068 | yes |
| 216 | `models/packages/package.go` | 18 | yes |
| 216 | `routers/api/packages/api.go` | 107-111 | yes |
| 216 | `routers/api/packages/api.go` | 107-548 | yes |
| 216 | `routers/api/packages/api.go` | 44-65 | yes |
| 216 | `routers/api/packages/api.go` | 543 | yes |
| 216 | `routers/init.go` | 188-194 | yes |
| 216 | `routers/web/web.go` | 1080-1110 | yes |
| 216 | `routers/web/web.go` | 671-690 | yes |
| 217 | `routers/api/v1/api.go` | 111-146 | yes |
| 217 | `routers/api/v1/api.go` | 277-308 | yes |
| 217 | `routers/api/v1/api.go` | 851-862 | yes |
| 217 | `routers/api/v1/api.go` | 939-1878 | yes |
| 217 | `routers/web/web.go` | 1769-1772 | yes |
| 218 | `routers/api/v1/api.go` | 1829 | yes |
| 218 | `routers/api/v1/api.go` | 350 | yes |
| 218 | `routers/web/admin/audit.go` |  | yes |
| 218 | `routers/web/web.go` | 746 | yes |
| 218 | `routers/web/web.go` | 746-870 | yes |
| 218 | `routers/web/web.go` | 787 | yes |
| 219 | `routers/private/internal.go` | 25-43 | yes |
| 219 | `routers/private/internal.go` | 80-100 | yes |
| 220 | `models/webhook/webhook.go` | 148 | yes |
| 220 | `modules/setting/webhook.go` | 26 | yes |
| 220 | `routers/web/web.go` | 449-476 | yes |
| 220 | `services/webhook/deliver.go` | 262 | yes |
| 220 | `services/webhook/deliver.go` | 274-290 | yes |
| 220 | `services/webhook/deliver.go` | 277 | yes |
| 220 | `services/webhook/deliver.go` | 278 | yes |
| 221 | `models/activities/notification.go` | 115 | yes |
| 221 | `routers/api/v1/api.go` | 1046-1054 | yes |
| 221 | `routers/web/web.go` | 1759-1767 | yes |
| 221 | `routers/web/web.go` | 426-431 | yes |
| 221 | `routers/web/web.go` | 590 | yes |
| 221 | `routers/web/web.go` | 885 | yes |
| 221 | `routers/web/web.go` | 886-887 | yes |
| 222 | `custom/conf/app.example.ini` | 1592 | yes |
| 222 | `routers/api/v1/api.go` | 1058 | yes |
| 222 | `routers/common/codesearch.go` |  | yes |
| 222 | `routers/web/web.go` | 358 | yes |
| 222 | `routers/web/web.go` | 519 | yes |
| 222 | `routers/web/web.go` | 539-556 | yes |
| 223 | `cmd/web.go` | 244-259 | yes |
| 223 | `cmd/web.go` | 255-256 | yes |
| 223 | `routers/install/routes.go` | 36 | yes |
| 223 | `routers/web/metrics.go` | 16-33 | yes |
| 223 | `routers/web/web.go` | 1774 | yes |
| 223 | `routers/web/web.go` | 1774-1792 | yes |
| 223 | `routers/web/web.go` | 264 | yes |
| 223 | `routers/web/web.go` | 290-298 | yes |
| 224 | `cmd/actions.go` | 17 | yes |
| 224 | `cmd/admin.go` | 22 | yes |
| 224 | `cmd/doctor.go` | 28 | yes |
| 224 | `cmd/dump.go` | 26 | yes |
| 224 | `cmd/generate.go` | 22 | yes |
| 224 | `cmd/manager.go` | 18 | yes |
| 224 | `cmd/migrate.go` | 19 | yes |
| 224 | `cmd/serv.go` | 40 | yes |
| 224 | `cmd/web.go` | 39 | yes |
| 225 | `custom/conf/app.example.ini` | 2143 | yes |
| 225 | `services/cron/cron.go` | 17-24 | yes |
| 225 | `services/cron/tasks_actions.go` | 27 | yes |
| 225 | `services/cron/tasks_basic.go` | 31 | yes |
| 225 | `services/cron/tasks_extended.go` | 26 | yes |
| 231 | `modules/` |  | yes |
| 231 | `modules/setting/session.go` | 64 | yes |
| 231 | `modules/storage/minio.go` | 129 | yes |
| 232 | `Makefile` | 436 | yes |
| 232 | `tests/` |  | yes |
| 232 | `tests/integration/admin_audit_test.go` |  | yes |
| 233 | `services/` |  | yes |
| 233 | `services/cron/cron.go` |  | yes |
| 233 | `services/webhook/deliver.go` | 274 | yes |
| 234 | `templates/` |  | yes |
| 234 | `templates/swagger/v1-swagger.generated.json` |  | yes |
| 235 | `modules/setting` |  | yes |
| 235 | `routers/` |  | yes |
| 235 | `routers/init.go` | 176-214 | yes |
| 236 | `public/` |  | yes |
| 236 | `routers/web/web.go` | 265 | yes |
| 237 | `models/` |  | yes |
| 237 | `models/repo/repo.go` | 225 | yes |
| 237 | `models/user/user.go` | 197 | yes |
| 238 | `package.json` | 3-6 | yes |
| 238 | `web_src/` |  | yes |
| 239 | `cmd/migrate.go` | 26-43 | yes |
| 239 | `modelmigration/` |  | yes |
| 240 | `options/` |  | yes |
| 240 | `options/locale/locale_en-US.json` |  | yes |
| 241 | `cmd/` |  | yes |
| 241 | `cmd/main.go` |  | yes |
| 242 | `Dockerfile` |  | yes |
| 243 | `.github/` |  | yes |
| 243 | `.github/workflows/pull-db-tests.yml` | 1 | yes |
| 244 | `contrib/` |  | yes |
| 244 | `contrib/upgrade.sh` | 1-12 | yes |
| 245 | `docs/` |  | yes |
| 245 | `docs/community-governance.md` | 1 | yes |
| 245 | `docs/development.md` |  | yes |
| 246 | `Dockerfile` | 89 | yes |
| 246 | `docker/` |  | yes |
| 246 | `docker/root/usr/bin/entrypoint` |  | yes |
| 247 | `tools/` |  | yes |
| 247 | `tools/test-integration.sh` |  | yes |
| 248 | `build/` |  | yes |
| 248 | `build/generate-emoji.go` | 81 | yes |
| 249 | `assets/` |  | yes |
| 249 | `assets/logo.svg` |  | yes |
| 250 | `snap/` |  | yes |
| 250 | `snap/snapcraft.yaml` |  | yes |
| 251 | `.devcontainer/` |  | yes |
| 251 | `.devcontainer/devcontainer.json` |  | yes |
| 252 | `custom/` |  | yes |
| 252 | `custom/conf/app.example.ini` | 1 | yes |
| 258 | `routers/web/web.go` | 353-358 | yes |
| 259 | `routers/api/v1/api.go` | 259-273 | yes |
| 260 | `routers/api/v1/api.go` | 350-357 | yes |
| 260 | `routers/web/web.go` | 238-244 | yes |
| 261 | `models/user/user.go` | 139-151 | yes |
| 261 | `routers/web/web.go` | 183-199 | yes |
| 262 | `models/organization/team.go` | 134-138 | yes |
| 262 | `routers/api/v1/api.go` | 421 | yes |
| 262 | `routers/api/v1/api.go` | 537 | yes |
| 262 | `routers/api/v1/api.go` | 548 | yes |
| 263 | `models/perm/access/access.go` | 33 | yes |
| 263 | `models/repo/collaboration.go` | 30 | yes |
| 263 | `routers/web/web.go` | 893-909 | yes |
| 264 | `routers/web/web.go` | 911-917 | yes |
| 265 | `models/auth/access_token_scope.go` | 18-27 | yes |
| 265 | `models/auth/access_token_scope.go` | 20 | yes |
| 265 | `models/auth/access_token_scope.go` | 58-90 | yes |
| 266 | `models/auth/oauth2.go` | 57-59 | yes |
| 267 | `models/deploykey/deploykey.go` | 58 | yes |
| 267 | `routers/web/web.go` | 136-138 | yes |
| 268 | `routers/api/actions/runner/interceptor.go` | 46-107 | yes |
| 268 | `services/auth/basic.go` | 111-116 | yes |
| 269 | `routers/api/v1/api.go` | 111-146 | yes |
| 269 | `routers/web/admin/users.go` | 568-585 | yes |
| 269 | `routers/web/web.go` | 787 | yes |
| 270 | `routers/api/v1/api.go` | 857-859 | yes |
| 270 | `routers/web/web.go` | 147-150 | yes |
| 271 | `models/auth/source.go` | 143 | yes |
| 271 | `modules/setting/security.go` | 193-197 | yes |
| 272 | `routers/private/internal.go` | 25-43 | yes |
| 276 | `routers/web/web.go` | 353-360 | yes |
| 276 | `routers/web/web.go` | 746 | yes |
| 276 | `routers/web/web.go` | 893-909 | yes |
| 276 | `routers/web/web.go` | 919-935 | yes |
| 277 | `routers/web/web.go` | 179 | yes |
| 277 | `routers/web/web.go` | 220-225 | yes |
| 278 | `routers/api/v1/api.go` | 1044-1054 | yes |
| 278 | `routers/api/v1/api.go` | 148 | yes |
| 278 | `routers/api/v1/api.go` | 249 | yes |
| 278 | `routers/api/v1/api.go` | 311-318 | yes |
| 278 | `routers/api/v1/api.go` | 369-410 | yes |
| 279 | `routers/api/packages/api.go` | 107-111 | yes |
| 279 | `routers/api/packages/api.go` | 107-134 | yes |
| 279 | `routers/api/packages/api.go` | 44-65 | yes |
| 279 | `routers/api/packages/api.go` | 543 | yes |
| 280 | `routers/private/hook_pre_receive.go` | 111-135 | yes |
| 281 | `routers/private/internal.go` | 25-43 | yes |
| 282 | `routers/api/v1/api.go` | 1016-1036 | yes |
| 282 | `routers/web/metrics.go` | 16-20 | yes |
| 282 | `routers/web/web.go` | 1769-1772 | yes |
| 282 | `routers/web/web.go` | 265-298 | yes |
| 282 | `routers/web/web.go` | 296 | yes |
| 282 | `routers/web/web.go` | 520-532 | yes |
| 282 | `routers/web/web.go` | 590 | yes |
| 282 | `routers/web/web.go` | 725-734 | yes |
| 282 | `routers/web/websocket/websocket.go` | 42 | yes |
| 283 | `services/actions/token_permission_design.md` | 34-40 | yes |
| 283 | `services/actions/token_permission_design.md` | 7-14 | yes |
| 290 | `cmd/web.go` | 285-286 | yes |
| 291 | `routers/web/web.go` | 215-218 | yes |
| 291 | `routers/web/web.go` | 569 | yes |
| 292 | `custom/conf/app.example.ini` | 841 | yes |
| 292 | `routers/web/web.go` | 571 | yes |
| 293 | `routers/web/web.go` | 592-598 | yes |
| 294 | `routers/web/web.go` | 608-723 | yes |
| 295 | `routers/web/web.go` | 1073 | yes |
| 296 | `routers/web/web.go` | 1158 | yes |
| 296 | `routers/web/web.go` | 893 | yes |
| 297 | `routers/web/web.go` | 1455-1459 | yes |
| 298 | `routers/web/web.go` | 1331 | yes |
| 299 | `routers/web/web.go` | 1365 | yes |
| 300 | `routers/web/repo/pull.go` | 1118-1119 | yes |
| 300 | `routers/web/web.go` | 1655 | yes |
| 301 | `routers/web/web.go` | 898 | yes |
| 302 | `routers/web/web.go` | 1589 | yes |
| 303 | `routers/web/web.go` | 1541-1585 | yes |
| 304 | `routers/api/actions/runner/interceptor.go` | 46-107 | yes |
| 305 | `routers/private/hook_pre_receive.go` | 114 | yes |
| 306 | `routers/web/githttp.go` | 13-24 | yes |
| 307 | `routers/api/v1/api.go` | 421 | yes |
| 308 | `routers/api/packages/api.go` | 107-111 | yes |
| 308 | `routers/api/packages/api.go` | 44-65 | yes |
| 309 | `routers/api/v1/api.go` | 311-318 | yes |
| 310 | `routers/api/v1/api.go` | 1016-1036 | yes |
| 311 | `routers/api/v1/api.go` | 118-143 | yes |
| 312 | `routers/api/v1/api.go` | 350-357 | yes |
| 313 | `routers/web/web.go` | 238-244 | yes |
| 314 | `routers/web/web.go` | 787 | yes |
| 315 | `routers/web/web.go` | 829-842 | yes |
| 316 | `routers/private/internal.go` | 25-43 | yes |
| 317 | `routers/web/web.go` | 1198-1215 | yes |
| 318 | `routers/web/web.go` | 1759-1767 | yes |
| 319 | `custom/conf/app.example.ini` | 853 | yes |
| 319 | `modules/setting/service.go` | 163-168 | yes |
| 319 | `routers/web/web.go` | 539-556 | yes |
| 320 | `routers/web/web.go` | 298 | yes |
| 321 | `routers/web/metrics.go` | 16-33 | yes |
| 322 | `cmd/main.go` |  | yes |
| 323 | `routers/init.go` | 172 | yes |
| 324 | `models/auth/access_token_scope.go` | 65-66 | yes |
| 324 | `routers/api/v1/api.go` | 277-308 | yes |
| 330 | `routers/web/web.go` | 257-321 | yes |
| 334 | `routers/install/routes.go` | 30-32 | yes |
| 335 | `routers/web/home.go` |  | yes |
| 335 | `routers/web/web.go` | 264 | yes |
| 336 | `routers/web/auth/auth.go` | 288-346 | yes |
| 336 | `routers/web/web.go` | 566-569 | yes |
| 336 | `routers/web/web.go` | 588 | yes |
| 337 | `routers/web/web.go` | 571 | yes |
| 338 | `routers/web/auth/auth.go` | 348-365 | yes |
| 339 | `routers/web/web.go` | 730-733 | yes |
| 340 | `routers/web/auth/oauth2_provider.go` | 372-376 | yes |
| 340 | `routers/web/web.go` | 592-598 | yes |
| 341 | `routers/web/web.go` | 888-891 | yes |
| 342 | `routers/web/web.go` | 608-723 | yes |
| 343 | `routers/web/web.go` | 539-556 | yes |
| 344 | `routers/web/repo/repo.go` | 193 | yes |
| 344 | `routers/web/web.go` | 1071-1075 | yes |
| 345 | `routers/web/web.go` | 1724-1739 | yes |
| 346 | `routers/web/web.go` | 1158-1260 | yes |
| 347 | `routers/web/repo/issue_view.go` |  | yes |
| 347 | `routers/web/web.go` | 1308-1310 | yes |
| 348 | `routers/web/web.go` | 1331 | yes |
| 349 | `routers/web/repo/pull_merge_box.go` |  | yes |
| 349 | `routers/web/web.go` | 1628-1657 | yes |
| 350 | `routers/web/web.go` | 1453-1480 | yes |
| 351 | `routers/web/web.go` | 1480-1500 | yes |
| 352 | `routers/web/web.go` | 1586-1600 | yes |
| 353 | `routers/web/web.go` | 1541-1585 | yes |
| 354 | `routers/web/web.go` | 1112-1140 | yes |
| 354 | `routers/web/web.go` | 1519-1540 | yes |
| 355 | `routers/web/web.go` | 937-1068 | yes |
| 356 | `routers/web/web.go` | 1080-1110 | yes |
| 357 | `routers/web/admin/admin.go` |  | yes |
| 357 | `routers/web/web.go` | 746-870 | yes |
| 358 | `routers/web/web.go` | 1759-1767 | yes |
| 359 | `routers/web/web.go` | 306-309 | yes |
| 360 | `routers/web/web.go` | 1774-1792 | yes |
| 366 | `cmd/web.go` | 285-286 | yes |
| 366 | `custom/conf/app.example.ini` | 442 | yes |
| 367 | `cmd/web.go` | 136-153 | yes |
| 367 | `routers/init.go` | 107-111 | yes |
| 368 | `routers/install/routes.go` | 30-31 | yes |
| 368 | `routers/install/routes.go` | 32 | yes |
| 369 | `cmd/web.go` | 168-171 | yes |
| 369 | `cmd/web.go` | 297 | yes |
| 371 | `cmd/web.go` | 153-157 | yes |
| 375 | `routers/web/auth/auth.go` | 289-292 | yes |
| 375 | `routers/web/web.go` | 569 | yes |
| 376 | `routers/web/auth/auth.go` | 302-306 | yes |
| 377 | `services/auth/signin.go` | 104-125 | yes |
| 377 | `services/auth/signin.go` | 27-92 | yes |
| 378 | `services/auth/signin.go` | 94-95 | yes |
| 378 | `services/auth/signin.go` | 96-98 | yes |
| 379 | `routers/web/auth/auth.go` | 328-343 | yes |
| 379 | `routers/web/auth/auth.go` | 348-364 | yes |
| 380 | `routers/web/auth/auth.go` | 376-380 | yes |
| 382 | `routers/web/auth/auth.go` | 310-312 | yes |
| 386 | `routers/web/repo/repo.go` | 193 | yes |
| 386 | `routers/web/web.go` | 1071-1075 | yes |
| 387 | `routers/web/repo/repo.go` | 197-201 | yes |
| 388 | `routers/web/repo/repo.go` | 203-247 | yes |
| 388 | `routers/web/repo/repo.go` | 222 | yes |
| 389 | `routers/web/repo/repo.go` | 253-260 | yes |
| 390 | `routers/web/repo/repo.go` | 250 | yes |
| 392 | `routers/web/repo/repo.go` | 211-214 | yes |
| 396 | `routers/web/web.go` | 1331 | yes |
| 397 | `routers/web/repo/issue_new.go` | 336-341 | yes |
| 397 | `routers/web/repo/issue_new.go` | 343-349 | yes |
| 398 | `routers/web/repo/issue_new.go` | 351-354 | yes |
| 399 | `routers/web/repo/issue_new.go` | 361-366 | yes |
| 400 | `routers/web/repo/issue_new.go` | 368-379 | yes |
| 402 | `routers/web/repo/issue_new.go` | 356-359 | yes |
| 402 | `routers/web/repo/issue_new.go` | 379-380 | yes |
| 406 | `routers/web/repo/pull.go` | 1088-1097 | yes |
| 406 | `routers/web/web.go` | 1640 | yes |
| 406 | `routers/web/web.go` | 1655 | yes |
| 407 | `routers/web/repo/pull.go` | 1099-1107 | yes |
| 408 | `routers/web/repo/pull.go` | 1110 | yes |
| 409 | `routers/web/repo/pull.go` | 1181-1183 | yes |
| 409 | `routers/web/repo/pull.go` | 1195 | yes |
| 410 | `routers/web/repo/pull.go` | 1275 | yes |
| 412 | `routers/web/repo/pull.go` | 1118-1119 | yes |
| 412 | `routers/web/repo/pull.go` | 1196-1230 | yes |
| 416 | `routers/web/githttp.go` | 13-14 | yes |
| 417 | `cmd/serv.go` | 40 | yes |
| 417 | `routers/private/internal.go` | 87-88 | yes |
| 417 | `routers/private/serv.go` | 68 | yes |
| 418 | `routers/private/hook_pre_receive.go` | 75-106 | yes |
| 418 | `routers/private/internal.go` | 84 | yes |
| 419 | `routers/private/hook_pre_receive.go` | 114-135 | yes |
| 420 | `routers/private/hook_post_receive.go` | 80 | yes |
| 420 | `routers/private/internal.go` | 85 | yes |
| 422 | `routers/private/hook_pre_receive.go` | 129-133 | yes |
| 422 | `routers/private/internal.go` | 27-31 | yes |
| 426 | `routers/web/web.go` | 449-461 | yes |
| 426 | `routers/web/web.go` | 464-476 | yes |
| 427 | `modules/setting/webhook.go` | 26 | yes |
| 427 | `services/webhook/deliver.go` | 274-279 | yes |
| 428 | `services/webhook/deliver.go` | 281-300 | yes |
| 429 | `services/webhook/deliver.go` | 262-267 | yes |
| 431 | `services/webhook/deliver.go` | 263-265 | yes |
| 435 | `routers/init.go` | 167 | yes |
| 435 | `routers/init.go` | 196-207 | yes |
| 436 | `services/cron/tasks_actions.go` | 59 | yes |
| 437 | `routers/api/actions/runner/interceptor.go` | 46-66 | yes |
| 437 | `routers/api/actions/runner/runner.go` | 30-36 | yes |
| 438 | `models/actions/task.go` | 68 | yes |
| 438 | `models/actions/task_output.go` | 24 | yes |
| 438 | `models/actions/task_step.go` | 62 | yes |
| 439 | `routers/api/actions/artifacts.go` | 119-124 | yes |
| 440 | `services/cron/tasks_actions.go` | 27 | yes |
| 440 | `services/cron/tasks_actions.go` | 37 | yes |
| 440 | `services/cron/tasks_actions.go` | 47 | yes |
| 440 | `services/cron/tasks_actions.go` | 70-80 | yes |
| 442 | `routers/api/actions/runner/interceptor.go` | 59-66 | yes |
| 446 | `routers/web/admin/users.go` | 568-585 | yes |
| 446 | `routers/web/web.go` | 784-788 | yes |
| 447 | `cmd/admin_user_change_password.go` | 22 | yes |
| 447 | `cmd/admin_user_create.go` | 24 | yes |
| 447 | `cmd/admin_user_delete.go` | 22 | yes |
| 447 | `cmd/admin_user_disable_2fa.go` | 21 | yes |
| 447 | `cmd/admin_user_generate_access_token.go` | 19 | yes |
| 447 | `cmd/admin_user_list.go` | 19 | yes |
| 447 | `cmd/admin_user_must_change_password.go` | 18 | yes |
| 448 | `services/cron/tasks_basic.go` | 88 | yes |
| 449 | `cmd/audit.go` | 15-16 | yes |
| 455 | `contrib/upgrade.sh` | 14-17 | yes |
| 455 | `contrib/upgrade.sh` | 76 | yes |
| 456 | `contrib/upgrade.sh` | 79-83 | yes |
| 456 | `contrib/upgrade.sh` | 89-94 | yes |
| 457 | `contrib/upgrade.sh` | 101-116 | yes |
| 457 | `contrib/upgrade.sh` | 54 | yes |
| 458 | `contrib/upgrade.sh` | 124-136 | yes |
| 460 | `contrib/upgrade.sh` | 60-61 | yes |
| 468 | `custom/conf/app.example.ini` | 353-400 | yes |
| 468 | `custom/conf/app.example.ini` | 367 | yes |
| 468 | `models/db/engine.go` | 112 | yes |
| 468 | `routers/init.go` | 136 | yes |
| 469 | `custom/conf/app.example.ini` | 1048 | yes |
| 469 | `custom/conf/app.example.ini` | 748 | yes |
| 469 | `modules/git/` |  | yes |
| 469 | `routers/init.go` | 115 | yes |
| 470 | `custom/conf/app.example.ini` | 1974-1985 | yes |
| 470 | `modules/setting/session.go` | 64 | yes |
| 471 | `custom/conf/app.example.ini` | 1940 | yes |
| 471 | `routers/init.go` | 128 | yes |
| 472 | `custom/conf/app.example.ini` | 1666 | yes |
| 472 | `services/webhook/deliver.go` | 281 | yes |
| 473 | `custom/conf/app.example.ini` | 1653 | yes |
| 473 | `modules/nosql/manager_redis.go` | 244 | yes |
| 474 | `custom/conf/app.example.ini` | 1592 | yes |
| 474 | `modules/indexer/internal/elasticsearch/indexer.go` | 284 | yes |
| 474 | `routers/init.go` | 150 | yes |
| 475 | `custom/conf/app.example.ini` | 2891-3002 | yes |
| 475 | `modules/storage/azureblob.go` | 226 | yes |
| 475 | `modules/storage/minio.go` | 129 | yes |
| 476 | `custom/conf/app.example.ini` | 1798 | yes |
| 476 | `services/mailer/sender/smtp.go` | 49 | yes |
| 477 | `custom/conf/app.example.ini` | 1899-1930 | yes |
| 477 | `services/mailer/incoming/incoming.go` | 63 | yes |
| 478 | `models/auth/source.go` | 137-147 | yes |
| 478 | `services/auth/source/ldap/source_search.go` | 181 | yes |
| 478 | `services/auth/source/smtp/auth.go` | 59 | yes |
| 479 | `custom/conf/app.example.ini` | 147-163 | yes |
| 479 | `modules/ssh/server.go` |  | yes |
| 479 | `routers/init.go` | 162 | yes |
| 480 | `routers/api/actions/actions.go` | 25 | yes |
| 480 | `routers/api/actions/runner/runner.go` | 30-36 | yes |
| 480 | `routers/init.go` | 196-207 | yes |
| 481 | `custom/conf/app.example.ini` | 3018 | yes |
| 481 | `services/gitproxy/` |  | yes |
| 485 | `cmd/migrate.go` | 26-43 | yes |
| 485 | `modelmigration/v1_10/v100.go` | 55 | yes |
| 485 | `modelmigration/v1_11/v106.go` | 25 | yes |
| 485 | `models/db/engine.go` | 112 | yes |
| 485 | `models/db/engine_init.go` | 34 | yes |
| 491 | `custom/conf/app.example.ini` | 880 | yes |
| 491 | `modules/hcaptcha/hcaptcha.go` | 96 | yes |
| 491 | `modules/mcaptcha/mcaptcha.go` | 41 | yes |
| 491 | `modules/mcaptcha/mcaptcha.go` | 44 | yes |
| 491 | `modules/recaptcha/recaptcha.go` | 33 | yes |
| 491 | `modules/recaptcha/recaptcha.go` | 35 | yes |
| 491 | `modules/turnstile/turnstile.go` | 47 | yes |
| 492 | `modules/indexer/internal/elasticsearch/indexer.go` | 284 | yes |
| 493 | `modules/lfs/http_client.go` | 236 | yes |
| 494 | `modules/storage/azureblob.go` | 226 | yes |
| 495 | `modules/updatechecker/update_checker.go` | 31-35 | yes |
| 495 | `modules/updatechecker/update_checker.go` | 37 | yes |
| 495 | `services/cron/tasks_extended.go` | 163 | yes |
| 496 | `routers/web/auth/oauth.go` | 313 | yes |
| 497 | `routers/web/repo/migrate.go` | 125 | yes |
| 497 | `services/migrations/bitbucket.go` | 179 | yes |
| 497 | `services/migrations/bitbucketserver.go` | 349 | yes |
| 497 | `services/migrations/codebase.go` | 128 | yes |
| 497 | `services/migrations/codecommit.go` | 300 | yes |
| 497 | `services/migrations/common.go` | 28 | yes |
| 497 | `services/migrations/github_graphql.go` | 166 | yes |
| 497 | `services/migrations/onedev.go` | 120 | yes |
| 498 | `services/webhook/deliver.go` | 277 | yes |
| 498 | `services/webhook/deliver.go` | 278 | yes |
| 498 | `services/webhook/deliver.go` | 39 | yes |
| 498 | `services/webhook/deliver.go` | 50 | yes |
| 498 | `services/webhook/deliver.go` | 67 | yes |
| 498 | `services/webhook/deliver.go` | 79 | yes |
| 498 | `services/webhook/matrix.go` | 55 | yes |
| 498 | `services/webhook/payloader.go` | 112 | yes |
| 499 | `build/generate-emoji.go` | 81 | yes |
| 499 | `build/generate-gitignores.go` | 45 | yes |
| 500 | `models/unittest/mock_http.go` | 87 | yes |
| 501 | `contrib/upgrade.sh` | 103-105 | yes |
| 501 | `contrib/upgrade.sh` | 108-115 | yes |
| 501 | `contrib/upgrade.sh` | 81 | yes |
| 502 | `modules/private/internal.go` | 89 | yes |
| 502 | `routers/private/internal.go` | 71 | yes |
| 508 | `models/user/user.go` | 101 | yes |
| 509 | `models/user/email_address.go` | 93 | yes |
| 510 | `models/auth/access_token.go` | 20 | yes |
| 511 | `models/auth/twofactor.go` | 60 | yes |
| 512 | `models/auth/webauthn.go` | 61 | yes |
| 513 | `models/auth/oauth2.go` | 57-59 | yes |
| 514 | `models/auth/source.go` | 137 | yes |
| 514 | `services/auth/source/ldap/source.go` | 58-74 | yes |
| 515 | `models/auth/session.go` | 24 | yes |
| 516 | `models/repo/repo.go` | 153 | yes |
| 517 | `models/perm/access/access.go` | 33 | yes |
| 517 | `models/repo/collaboration.go` | 30 | yes |
| 517 | `models/repo/repo_unit.go` | 53 | yes |
| 518 | `models/issues/comment.go` | 373 | yes |
| 518 | `models/issues/issue.go` | 130 | yes |
| 518 | `models/issues/pull.go` | 170 | yes |
| 518 | `models/issues/review.go` | 155 | yes |
| 519 | `models/repo/attachment.go` | 42 | yes |
| 519 | `models/repo/release.go` | 94 | yes |
| 520 | `models/organization/team.go` | 134-138 | yes |
| 521 | `models/asymkey/gpg_key.go` | 42 | yes |
| 521 | `models/asymkey/ssh_key.go` | 57 | yes |
| 521 | `models/deploykey/deploykey.go` | 58 | yes |
| 522 | `models/webhook/hooktask.go` | 81 | yes |
| 522 | `models/webhook/webhook.go` | 123 | yes |
| 523 | `models/secret/secret.go` | 39 | yes |
| 524 | `models/actions/run.go` | 79 | yes |
| 524 | `models/actions/runner.go` | 207 | yes |
| 524 | `models/actions/runner_token.go` | 45 | yes |
| 524 | `models/actions/task.go` | 68 | yes |
| 525 | `models/packages/package.go` | 18 | yes |
| 525 | `models/packages/package_blob.go` | 26 | yes |
| 525 | `models/packages/package_file.go` | 20 | yes |
| 525 | `models/packages/package_version.go` | 23 | yes |
| 526 | `models/git/lfs.go` | 89 | yes |
| 526 | `models/git/lfs_lock.go` | 31 | yes |
| 527 | `models/activities/action.go` | 154 | yes |
| 527 | `models/activities/notification.go` | 115 | yes |
| 528 | `models/audit/audit_event.go` | 19 | yes |
| 529 | `models/system/appstate.go` | 24 | yes |
| 529 | `models/system/notice.go` | 37 | yes |
| 529 | `models/system/setting.go` | 35 | yes |
| 531 | `models/user/user.go` | 101-185 | yes |
| 535 | `models/user/user.go` | 102 | yes |
| 536 | `models/user/user.go` | 103 | yes |
| 537 | `models/user/user.go` | 104 | yes |
| 538 | `models/user/user.go` | 107 | yes |
| 539 | `models/user/user.go` | 110 | yes |
| 540 | `models/user/user.go` | 111 | yes |
| 541 | `models/user/user.go` | 115 | yes |
| 542 | `models/user/user.go` | 118 | yes |
| 543 | `models/user/user.go` | 123-124 | yes |
| 544 | `models/user/user.go` | 130 | yes |
| 545 | `models/user/user.go` | 139 | yes |
| 546 | `models/user/user.go` | 144 | yes |
| 547 | `models/user/user.go` | 151 | yes |
| 548 | `models/user/user.go` | 155 | yes |
| 549 | `models/user/user.go` | 167 | yes |
| 551 | `models/repo/repo.go` | 153-221 | yes |
| 555 | `models/repo/repo.go` | 154 | yes |
| 556 | `models/repo/repo.go` | 155 | yes |
| 557 | `models/repo/repo.go` | 158 | yes |
| 558 | `models/repo/repo.go` | 160 | yes |
| 559 | `models/repo/repo.go` | 163 | yes |
| 560 | `models/repo/repo.go` | 186 | yes |
| 561 | `models/repo/repo.go` | 188 | yes |
| 562 | `models/repo/repo.go` | 189 | yes |
| 563 | `models/repo/repo.go` | 198-199 | yes |
| 564 | `models/repo/repo.go` | 201-202 | yes |
| 565 | `models/repo/repo.go` | 211 | yes |
| 567 | `models/auth/access_token.go` | 20-33 | yes |
| 571 | `models/auth/access_token.go` | 21 | yes |
| 572 | `models/auth/access_token.go` | 22 | yes |
| 573 | `models/auth/access_token.go` | 25 | yes |
| 574 | `models/auth/access_token.go` | 27 | yes |
| 576 | `models/auth/twofactor.go` | 60-68 | yes |
| 580 | `models/auth/twofactor.go` | 61 | yes |
| 581 | `models/auth/twofactor.go` | 62 | yes |
| 582 | `models/auth/twofactor.go` | 107-108 | yes |
| 583 | `models/auth/twofactor.go` | 66 | yes |
| 585 | `models/webhook/webhook.go` | 123-144 | yes |
| 589 | `models/webhook/webhook.go` | 124 | yes |
| 590 | `models/webhook/webhook.go` | 125-126 | yes |
| 591 | `models/webhook/webhook.go` | 128 | yes |
| 592 | `models/webhook/webhook.go` | 132 | yes |
| 593 | `models/webhook/webhook.go` | 141 | yes |
| 595 | `models/secret/secret.go` | 39-46 | yes |
| 599 | `models/secret/secret.go` | 41 | yes |
| 600 | `models/secret/secret.go` | 42 | yes |
| 601 | `models/secret/secret.go` | 43 | yes |
| 602 | `models/secret/secret.go` | 44 | yes |
| 604 | `models/auth/source.go` | 137-147 | yes |
| 608 | `models/auth/source.go` | 138 | yes |
| 609 | `models/auth/source.go` | 140 | yes |
| 610 | `models/auth/source.go` | 141 | yes |
| 611 | `models/auth/source.go` | 143 | yes |
| 612 | `models/auth/source.go` | 144 | yes |
| 612 | `services/auth/source/ldap/source.go` | 58-74 | yes |
| 618 | `custom/conf/app.example.ini` | 353-400 | yes |
| 618 | `routers/init.go` | 137 | yes |
| 618 | `routers/init.go` | 68-74 | yes |
| 619 | `custom/conf/app.example.ini` | 797 | yes |
| 619 | `routers/init.go` | 115-116 | yes |
| 619 | `routers/init.go` | 116 | yes |
| 620 | `custom/conf/app.example.ini` | 1994-1997 | yes |
| 620 | `modules/setting/session.go` | 64 | yes |
| 621 | `routers/init.go` | 128 | yes |
| 622 | `services/webhook/deliver.go` | 281-284 | yes |
| 622 | `services/webhook/deliver.go` | 292-300 | yes |
| 622 | `services/webhook/deliver.go` | 293 | yes |
| 623 | `modules/nosql/manager_redis.go` | 244-253 | yes |
| 624 | `routers/init.go` | 150 | yes |
| 625 | `routers/init.go` | 125 | yes |
| 626 | `cmd/web.go` | 131-133 | yes |
| 626 | `services/mailer/sender/smtp.go` | 49 | yes |
| 627 | `services/mailer/incoming/incoming.go` | 63 | yes |
| 628 | `routers/web/auth/auth.go` | 312 | yes |
| 628 | `services/auth/signin.go` | 104-110 | yes |
| 628 | `services/auth/signin.go` | 80-82 | yes |
| 629 | `modules/ssh/server.go` |  | yes |
| 630 | `routers/api/actions/runner/interceptor.go` | 33 | yes |
| 630 | `routers/api/actions/runner/interceptor.go` | 59-66 | yes |
| 631 | `services/gitproxy/` |  | yes |
| 632 | `modules/hcaptcha/hcaptcha.go` | 96 | yes |
| 633 | `modules/indexer/internal/elasticsearch/indexer.go` | 284 | yes |
| 634 | `modules/lfs/http_client.go` | 236 | yes |
| 635 | `modules/storage/azureblob.go` | 226 | yes |
| 636 | `modules/updatechecker/update_checker.go` | 37 | yes |
| 636 | `services/cron/tasks_extended.go` | 163 | yes |
| 637 | `routers/web/auth/oauth.go` | 313 | yes |
| 638 | `services/migrations/common.go` | 28 | yes |
| 639 | `custom/conf/app.example.ini` | 1780 | yes |
| 639 | `services/webhook/deliver.go` | 262-268 | yes |
| 639 | `services/webhook/deliver.go` | 267 | yes |
| 639 | `services/webhook/deliver.go` | 275-279 | yes |
| 640 | `build/generate-emoji.go` | 81 | yes |
| 641 | `models/unittest/mock_http.go` | 87 | yes |
| 642 | `contrib/upgrade.sh` | 105 | yes |
| 642 | `contrib/upgrade.sh` | 124-138 | yes |
| 642 | `contrib/upgrade.sh` | 61 | yes |
| 643 | `modules/private/internal.go` | 90-97 | yes |
| 643 | `routers/private/internal.go` | 37 | yes |
| 649 | `cmd/generate.go` | 56 | yes |
| 649 | `modules/private/internal.go` | 90-92 | yes |
| 649 | `routers/private/internal.go` | 36-39 | yes |
| 650 | `cmd/web.go` | 212-214 | yes |
| 651 | `cmd/web.go` | 173-177 | yes |
| 652 | `cmd/web.go` | 195-205 | yes |
| 653 | `cmd/web.go` | 285-290 | yes |
| 653 | `custom/conf/app.example.ini` | 442 | yes |
| 654 | `routers/web/web.go` | 730-733 | yes |
| 654 | `services/auth/signin.go` | 38-42 | yes |
| 654 | `services/auth/signin.go` | 80-82 | yes |
| 655 | `cmd/admin_user_must_change_password.go` | 18 | yes |
| 655 | `routers/web/web.go` | 198-206 | yes |
| 656 | `models/user/user.go` | 151 | yes |
| 656 | `routers/api/v1/api.go` | 888-891 | yes |
| 656 | `routers/web/web.go` | 786 | yes |
| 657 | `models/auth/access_token_scope.go` | 58-90 | yes |
| 657 | `routers/api/v1/api.go` | 261-263 | yes |
| 657 | `routers/api/v1/api.go` | 297-306 | yes |
| 658 | `routers/api/v1/api.go` | 311-318 | yes |
| 659 | `routers/api/v1/api.go` | 138-142 | yes |
| 660 | `custom/conf/app.example.ini` | 1780 | yes |
| 660 | `custom/conf/app.example.ini` | 539-562 | yes |
| 660 | `services/webhook/deliver.go` | 262-268 | yes |
| 661 | `routers/private/hook_pre_receive.go` | 128-135 | yes |
| 661 | `routers/private/hook_pre_receive.go` | 137 | yes |
| 662 | `routers/web/repo/pull.go` | 1195-1230 | yes |
| 663 | `routers/web/metrics.go` | 21-31 | yes |
| 664 | `cmd/actions.go` | 27 | yes |
| 664 | `routers/api/actions/runner/interceptor.go` | 59-66 | yes |
| 672 | `custom/conf/app.example.ini` | 520 | yes |
| 672 | `routers/api/v1/api.go` | 932-935 | yes |
| 672 | `services/auth/oauth2.go` | 84-97 | yes |
| 673 | `custom/conf/app.example.ini` | 861 | yes |
| 673 | `routers/api/v1/api.go` | 855 | yes |
| 673 | `routers/web/auth/auth.go` | 308-324 | yes |
| 673 | `routers/web/web.go` | 190-194 | yes |
| 673 | `services/auth/signin.go` | 104-125 | yes |
| 673 | `services/auth/signin.go` | 104-125 | yes |
| 673 | `services/auth/signin.go` | 27-100 | yes |
| 674 | `custom/conf/app.example.ini` | 572 | yes |
| 674 | `custom/conf/app.example.ini` | 576 | yes |
| 674 | `modules/setting/audit.go` | 24 | yes |
| 674 | `routers/api/v1/api.go` | 129-131 | yes |
| 674 | `routers/web/admin/users.go` | 585 | yes |
| 674 | `routers/web/web.go` | 787 | yes |
| 674 | `services/audit/event.go` | 131-134 | yes |
| 675 | `custom/conf/app.example.ini` | 2756-2758 | yes |
| 675 | `routers/web/metrics.go` | 17-20 | yes |
| 676 | `routers/private/internal.go` | 33-38 | yes |
| 677 | `models/auth/twofactor.go` | 102-108 | yes |
| 678 | `models/webhook/webhook.go` | 132 | yes |
| 678 | `models/webhook/webhook.go` | 141 | yes |
| 678 | `models/webhook/webhook.go` | 224-228 | yes |
| 679 | `routers/web/auth/auth.go` | 467-469 | yes |
| 679 | `routers/web/web.go` | 734 | yes |
| 680 | `modules/private/internal.go` | 74-77 | yes |
| 681 | `custom/conf/app.example.ini` | 1926-1927 | yes |
| 681 | `modules/setting/incoming_email.go` | 23 | yes |
| 682 | `custom/conf/app.example.ini` | 1845 | yes |
| 682 | `custom/conf/app.example.ini` | 2108 | yes |
| 682 | `models/auth/source.go` | 100-102 | yes |
| 682 | `modules/nosql/manager_redis.go` | 239-253 | yes |
| 682 | `modules/setting/migrations.go` | 53 | yes |
| 682 | `modules/setting/migrations.go` | 53 | yes |
| 682 | `modules/setting/webhook.go` | 26 | yes |
| 682 | `modules/setting/webhook.go` | 36 | yes |
| 682 | `modules/storage/minio.go` | 129 | yes |
| 682 | `services/auth/source/ldap/source_search.go` | 181 | yes |
| 682 | `services/auth/source/smtp/auth.go` | 59 | yes |
| 682 | `services/mailer/incoming/incoming.go` | 63 | yes |
| 682 | `services/mailer/sender/smtp.go` | 49 | yes |
| 682 | `services/migrations/http_client.go` | 38 | yes |
| 682 | `services/webhook/deliver.go` | 278 | yes |
| 683 | `modules/updatechecker/update_checker.go` | 31-37 | yes |
| 683 | `services/cron/tasks_extended.go` | 163-168 | yes |
| 683 | `services/cron/tasks_extended.go` | 163-168 | yes |
| 684 | `custom/conf/app.example.ini` | 445 | yes |
| 684 | `custom/conf/app.example.ini` | 446 | yes |
| 684 | `models/auth/twofactor.go` | 102 | yes |
| 684 | `models/secret/secret.go` | 79 | yes |
| 684 | `models/webhook/webhook.go` | 224 | yes |
| 684 | `modules/setting/security.go` | 147-152 | yes |
| 684 | `modules/setting/security.go` | 149-150 | yes |
| 684 | `routers/install/install.go` | 392-399 | yes |
| 684 | `services/auth/source/ldap/source.go` | 58-65 | yes |
| 684 | `services/auth/source/ldap/source.go` | 58-65 | yes |
| 685 | `custom/conf/app.example.ini` | 576 | yes |
| 685 | `models/audit/audit_event.go` | 22-38 | yes |
| 685 | `services/cron/tasks_extended.go` | 141-154 | yes |
| 691 | `cmd/web.go` | 356-368 | yes |
| 692 | `cmd/web.go` | 339-343 | yes |
| 692 | `custom/conf/app.example.ini` | 476-479 | yes |
| 693 | `routers/web/web.go` | 179 | yes |
| 693 | `routers/web/web.go` | 220-225 | yes |
| 694 | `routers/web/auth/auth.go` | 326-345 | yes |
| 695 | `models/auth/source.go` | 143 | yes |
| 695 | `modules/setting/security.go` | 193-197 | yes |
| 695 | `routers/api/v1/api.go` | 226-229 | yes |
| 696 | `modules/setting/session.go` | 64 | yes |
| 696 | `modules/web/middleware/cookie.go` | 71-73 | yes |
| 697 | `routers/web/auth/auth.go` | 288-346 | yes |
| 697 | `services/auth/signin.go` | 27-100 | yes |
| 698 | `custom/conf/app.example.ini` | 1022 | yes |
| 698 | `routers/common/qos.go` | 49-52 | yes |
| 699 | `modules/setting/audit.go` | 24 | yes |
| 699 | `services/audit/event.go` | 131-134 | yes |
| 700 | `custom/conf/app.example.ini` | 576 | yes |
| 700 | `models/audit/audit_event.go` | 22-38 | yes |
| 701 | `cmd/dump.go` | 26 | yes |
| 701 | `contrib/upgrade.sh` | 130 | yes |
| 702 | `cmd/restore_repo.go` | 18 | yes |
| 702 | `contrib/upgrade.sh` | 130-132 | yes |
| 703 | `cmd/generate.go` | 56-81 | yes |
| 703 | `custom/conf/app.example.ini` | 446-456 | yes |
| 704 | `modules/auth/password/hash/hash.go` | 116 | yes |
| 705 | `custom/conf/app.example.ini` | 539-544 | yes |
| 705 | `modules/updatechecker/update_checker.go` | 31-35 | yes |
| 705 | `services/migrations/http_client.go` | 37 | yes |
| 705 | `services/webhook/deliver.go` | 277 | yes |
| 706 | `Makefile` | 497-499 | yes |
| 712 | `README.md` | 14-19 | yes |
| 713 | `MAINTAINERS` |  | yes |
| 713 | `docs/community-governance.md` | 132 | yes |
| 713 | `docs/community-governance.md` | 161 | yes |
| 713 | `docs/community-governance.md` | 186 | yes |
| 714 | `CONTRIBUTING.md` | 147 | yes |
| 714 | `CONTRIBUTING.md` | 53 | yes |
| 714 | `docs/community-governance.md` | 35 | yes |
| 716 | `CONTRIBUTING.md` | 277 | yes |
| 716 | `README.md` | 32-38 | yes |
| 717 | `.github/workflows/release-create-tag.yml` | 14 | yes |
| 717 | `.github/workflows/release-nightly.yml` | 37 | yes |
| 717 | `.github/workflows/release-tag-version.yml` | 16 | yes |
| 717 | `CONTRIBUTING.md` | 231-256 | yes |
| 717 | `docs/release-management.md` |  | yes |
| 718 | `Makefile` | 368 | yes |
| 718 | `docs/testing.md` | 10 | yes |
| 719 | `.github/workflows/pull-db-tests.yml` | 173 | yes |
| 719 | `.github/workflows/pull-db-tests.yml` | 18 | yes |
| 719 | `.github/workflows/pull-db-tests.yml` | 220 | yes |
| 719 | `.github/workflows/pull-db-tests.yml` | 248 | yes |
| 719 | `.github/workflows/pull-db-tests.yml` | 93 | yes |
| 719 | `Makefile` | 436 | yes |
| 719 | `tests/integration/` |  | yes |
| 719 | `tests/integration/actions_oidc_test.go` |  | yes |
| 719 | `tests/integration/admin_audit_test.go` |  | yes |
| 720 | `Makefile` | 453 | yes |
| 720 | `modelmigration/migrationtest/` |  | yes |
| 721 | `.github/workflows/pull-e2e-tests.yml` | 18 | yes |
| 721 | `Makefile` | 473 | yes |
| 721 | `tests/e2e/` |  | yes |
| 722 | `Makefile` | 373 | yes |
| 722 | `vitest.config.ts` |  | yes |
| 722 | `web_src/` |  | yes |
| 723 | `tests/fuzz/` |  | yes |
| 724 | `.github/workflows/pull-compliance.yml` | 18-81 | yes |
| 724 | `Makefile` | 269 | yes |
| 732 | `custom/conf/app.example.ini` |  | yes |
| 757 | `routers/init.go` | 172 | yes |
| 757 | `routers/init.go` | 176-207 | yes |
| 757 | `routers/private/internal.go` | 71-78 | yes |
| 774 | `routers/private/hook_post_receive.go` | 80 | yes |
| 774 | `routers/private/hook_pre_receive.go` | 75-109 | yes |
| 774 | `routers/private/internal.go` | 84-88 | yes |
| 774 | `routers/private/serv.go` | 68 | yes |
| 794 | `routers/web/auth/auth.go` | 288-365 | yes |
| 794 | `services/auth/signin.go` | 27-100 | yes |
| 807 | `models/auth/access_token.go` | 22 | yes |
| 807 | `models/auth/twofactor.go` | 62 | yes |
| 807 | `models/repo/repo.go` | 155 | yes |
| 807 | `models/secret/secret.go` | 42 | yes |
| 807 | `models/user/user.go` | 118 | yes |
| 807 | `models/webhook/webhook.go` | 125 | yes |
| 807 | `routers/web/repo/issue_new.go` | 369 | yes |
| 819 | `contrib/service/systemd/gitea.service` |  | yes |
| 819 | `custom/conf/app.example.ini` | 476-479 | yes |
| 819 | `docker/root/usr/bin/entrypoint` |  | yes |
| 825 | `routers/web/web.go` | 166 | yes |
| 826 | `routers/web/web.go` | 903-909 | yes |
| 827 | `models/auth/access_token_scope.go` | 58-90 | yes |
| 828 | `models/auth/access_token_scope.go` | 60 | yes |
| 829 | `routers/api/v1/api.go` | 111-146 | yes |
| 829 | `routers/web/web.go` | 787 | yes |
| 830 | `routers/private/internal.go` | 25-43 | yes |
| 831 | `custom/conf/app.example.ini` | 442 | yes |
| 832 | `models/auth/source.go` | 137-147 | yes |
| 833 | `custom/conf/app.example.ini` | 539-562 | yes |
| 834 | `models/repo/mirror.go` | 41 | yes |
| 835 | `routers/web/repo/migrate.go` | 125 | yes |
| 836 | `README.md` | 14-19 | yes |
| 837 | `routers/api/actions/runner/runner.go` | 30 | yes |
| 838 | `models/actions/scoped_workflow.go` | 41 | yes |
| 839 | `routers/api/packages/api.go` | 543-548 | yes |
| 840 | `routers/common/lfs.go` | 18-29 | yes |
| 841 | `routers/private/internal.go` | 84-86 | yes |
| 842 | `models/webhook/webhook.go` | 123 | yes |
| 843 | `models/git/protected_branch.go` | 83 | yes |
| 844 | `models/deploykey/deploykey.go` | 58 | yes |
| 845 | `routers/web/web.go` | 136-138 | yes |
| 846 | `custom/conf/app.example.ini` | 1666 | yes |
| 847 | `services/cron/cron.go` | 17-24 | yes |
| 848 | `models/audit/audit_event.go` | 19 | yes |
| 849 | `routers/api/v1/api.go` | 1010-1013 | yes |
| 850 | `custom/conf/app.example.ini` | 580-594 | yes |
| 851 | `routers/common/qos.go` | 46-52 | yes |
| 852 | `routers/common/maintenancemode.go` |  | yes |
| 853 | `cmd/doctor.go` | 28-41 | yes |
| 854 | `cmd/dump.go` | 26 | yes |
| 855 | `routers/web/passkey.go` |  | yes |
| 855 | `routers/web/web.go` | 581-586 | yes |
| 861 | `templates/` |  | yes |
| 864 | `cmd/restore_repo.go` | 18 | yes |
| 865 | `contrib/upgrade.sh` | 132 | yes |
| 866 | `routers/web/web.go` | 190-194 | yes |
| 867 | `modules/setting/session.go` | 64 | yes |
| 868 | `models/auth/source.go` | 143 | yes |
| 868 | `modules/setting/security.go` | 193-197 | yes |
| 869 | `custom/conf/app.example.ini` | 536-537 | yes |
| 869 | `web_src/` |  | yes |
| 870 | `docs/appdoc/facts-summary.md` | 5 | yes |
| 890 | `modules/setting/security.go` | 193-197 | yes |
| 901 | `web_src/` |  | yes |
| 907 | `Dockerfile` | 12 | yes |
| 907 | `Dockerfile` | 3 | yes |
| 907 | `Dockerfile` | 51 | yes |
| 908 | `package.json` | 3-6 | yes |
| 909 | `routers/init.go` | 115-119 | yes |
| 910 | `.github/workflows/pull-db-tests.yml` | 173 | yes |
| 910 | `.github/workflows/pull-db-tests.yml` | 18 | yes |
| 910 | `.github/workflows/pull-db-tests.yml` | 220 | yes |
| 910 | `.github/workflows/pull-db-tests.yml` | 93 | yes |
| 910 | `custom/conf/app.example.ini` | 363-396 | yes |
| 911 | `Dockerfile` | 14-15 | yes |
| 915 | `cmd/admin_user_create.go` | 24 | yes |
| 915 | `cmd/migrate.go` | 26-43 | yes |
| 915 | `routers/init.go` | 136 | yes |
| 915 | `routers/install/routes.go` | 31 | yes |
| 916 | `models/fixtures/` |  | yes |
| 916 | `models/unittest/` |  | yes |
| 917 | `cmd/web.go` | 212-214 | yes |
| 917 | `cmd/web.go` | 218 | yes |
| 918 | `custom/conf/app.example.ini` | 1592 | yes |
| 918 | `custom/conf/app.example.ini` | 1653 | yes |
| 918 | `custom/conf/app.example.ini` | 1666 | yes |
| 918 | `custom/conf/app.example.ini` | 1940 | yes |
| 918 | `custom/conf/app.example.ini` | 1974 | yes |
| 918 | `custom/conf/app.example.ini` | 2891 | yes |
| 919 | `cmd/migrate_storage.go` | 30-51 | yes |
| 923 | `custom/conf/app.example.ini` | 1979-2000 | yes |
| 923 | `modules/setting/session.go` | 39 | yes |
| 924 | `modules/setting/session.go` | 64 | yes |
| 924 | `modules/web/middleware/cookie.go` | 71-73 | yes |
| 925 | `custom/conf/app.example.ini` | 459 | yes |
| 926 | `models/auth/access_token.go` | 20-33 | yes |
| 927 | `custom/conf/app.example.ini` | 626-632 | yes |
| 928 | `routers/api/actions/runner/interceptor.go` | 97-105 | yes |
| 934 | `routers/init.go` | 68-74 | yes |
| 935 | `custom/conf/app.example.ini` | 453-456 | yes |
| 935 | `routers/private/internal.go` | 27-31 | yes |
| 936 | `cmd/web.go` | 212-214 | yes |
| 937 | `cmd/manager.go` | 73 | yes |
| 937 | `contrib/upgrade.sh` | 125 | yes |
| 938 | `contrib/upgrade.sh` | 127 | yes |
| 938 | `contrib/upgrade.sh` | 132 | yes |
| 938 | `contrib/upgrade.sh` | 60-61 | yes |
| 939 | `services/cron/tasks_actions.go` | 27 | yes |
| 939 | `services/cron/tasks_actions.go` | 37 | yes |
| 940 | `services/webhook/deliver.go` | 263-267 | yes |
| 941 | `cmd/web.go` | 255-256 | yes |
| 941 | `custom/conf/app.example.ini` | 302 | yes |
| 947 | `.github/workflows/release-nightly.yml` | 37 | yes |
| 947 | `.github/workflows/release-tag-version.yml` | 16 | yes |
| 947 | `Dockerfile` | 3 | yes |
| 947 | `Dockerfile` | 3-51 | yes |
| 947 | `Makefile` | 477 | yes |
| 947 | `Makefile` | 477-483 | yes |
| 947 | `Makefile` | 510 | yes |
| 948 | `.github/workflows/pull-db-tests.yml` | 115 | yes |
| 948 | `.github/workflows/pull-db-tests.yml` | 173 | yes |
| 948 | `.github/workflows/pull-db-tests.yml` | 18 | yes |
| 948 | `.github/workflows/pull-db-tests.yml` | 220 | yes |
| 948 | `.github/workflows/pull-db-tests.yml` | 93 | yes |
| 948 | `Makefile` | 368 | yes |
| 948 | `Makefile` | 368 | yes |
| 948 | `Makefile` | 436 | yes |
| 948 | `Makefile` | 453 | yes |
| 948 | `Makefile` | 473 | yes |
| 949 | `Dockerfile` | 89 | yes |
| 949 | `cmd/web.go` | 39 | yes |
| 949 | `cmd/web.go` | 39-76 | yes |
| 949 | `contrib/service/systemd/gitea.service` |  | yes |
| 949 | `docker/root/usr/bin/entrypoint` |  | yes |
| 950 | `cmd/migrate.go` | 26-43 | yes |
| 950 | `contrib/upgrade.sh` |  | yes |
| 950 | `contrib/upgrade.sh` | 124 | yes |
| 950 | `contrib/upgrade.sh` | 124-136 | yes |
| 951 | `contrib/upgrade.sh` | 132 | yes |
| 952 | `cmd/dump.go` | 26 | yes |
| 952 | `cmd/dump.go` | 26-92 | yes |
| 952 | `cmd/dump_repo.go` | 28 | yes |
| 952 | `contrib/upgrade.sh` | 130 | yes |
| 953 | `cmd/restore_repo.go` | 18 | yes |
| 953 | `cmd/restore_repo.go` | 18-40 | yes |
| 954 | `cmd/actions.go` | 27 | yes |
| 954 | `cmd/admin_regenerate.go` | 18-26 | yes |
| 954 | `cmd/generate.go` | 33 | yes |
| 954 | `cmd/generate.go` | 33-81 | yes |
| 954 | `custom/conf/app.example.ini` | 445 | yes |
| 954 | `modules/setting/security.go` | 147-152 | yes |
| 956 | `cmd/admin.go` | 22-77 | yes |
| 956 | `cmd/admin_auth.go` | 22-31 | yes |
| 956 | `cmd/admin_auth_ldap.go` | 179-212 | yes |
| 956 | `cmd/admin_auth_oauth.go` | 137-148 | yes |
| 956 | `cmd/admin_auth_smtp.go` | 75-89 | yes |
| 956 | `cmd/admin_user.go` | 30 | yes |
| 956 | `cmd/admin_user_change_type.go` | 19 | yes |
| 956 | `cmd/cert.go` | 31 | yes |
| 956 | `cmd/config.go` | 19 | yes |
| 956 | `cmd/docs.go` | 18 | yes |
| 956 | `cmd/doctor.go` | 41-65 | yes |
| 956 | `cmd/doctor.go` | 81 | yes |
| 956 | `cmd/doctor_convert.go` | 18 | yes |
| 956 | `cmd/embedded.go` | 29-72 | yes |
| 956 | `cmd/keys.go` | 21 | yes |
| 956 | `cmd/manager.go` | 34-95 | yes |
| 956 | `cmd/manager_logging.go` | 18-49 | yes |
| 963 | `custom/conf/app.example.ini` | 446 | yes |
| 964 | `custom/conf/app.example.ini` | 453 | yes |
| 965 | `docker/root/etc/templates/app.ini` | 30 | yes |
| 966 | `modules/setting/lfs.go` | 79 | yes |
| 967 | `modules/setting/oauth2.go` | 147 | yes |
| 968 | `modules/setting/security.go` | 167 | yes |
| 969 | `modules/setting/security.go` | 175 | yes |
| 970 | `modules/setting/security.go` | 180 | yes |
| 971 | `modules/setting/security.go` | 181 | yes |
| 972 | `modules/setting/security.go` | 209 | yes |
| 973 | `modules/setting/security.go` | 224 | yes |
| 974 | `modules/setting/service.go` | 140 | yes |
| 975 | `modules/setting/service.go` | 173 | yes |
| 976 | `modules/setting/service.go` | 183 | yes |
| 977 | `modules/setting/service.go` | 185 | yes |
| 978 | `modules/setting/service.go` | 188 | yes |
| 979 | `modules/setting/service.go` | 190 | yes |
| 980 | `modules/setting/service.go` | 193 | yes |
| 981 | `modules/setting/storage.go` | 109 | yes |
| 982 | `modules/setting/storage.go` | 118 | yes |
| 983 | `routers/install/install.go` | 356 | yes |
| 984 | `cmd/web.go` | 180 | yes |
| 985 | `cmd/web.go` | 323 | yes |
| 986 | `custom/conf/app.example.ini` | 363 | yes |
| 987 | `custom/conf/app.example.ini` | 364 | yes |
| 988 | `custom/conf/app.example.ini` | 365 | yes |
| 989 | `custom/conf/app.example.ini` | 366 | yes |
| 990 | `custom/conf/app.example.ini` | 442 | yes |
| 991 | `custom/conf/app.example.ini` | 663 | yes |
| 992 | `custom/conf/app.example.ini` | 666 | yes |
| 993 | `docker/root/etc/templates/app.ini` | 1 | yes |
| 994 | `docker/root/etc/templates/app.ini` | 2 | yes |
| 995 | `docker/root/etc/templates/app.ini` | 5 | yes |
| 996 | `docker/root/etc/templates/app.ini` | 14 | yes |
| 997 | `docker/root/etc/templates/app.ini` | 17 | yes |
| 998 | `docker/root/etc/templates/app.ini` | 18 | yes |
| 999 | `docker/root/etc/templates/app.ini` | 19 | yes |
| 1000 | `docker/root/etc/templates/app.ini` | 20 | yes |
| 1001 | `docker/root/etc/templates/app.ini` | 21 | yes |
| 1002 | `docker/root/etc/templates/app.ini` | 22 | yes |
| 1003 | `docker/root/etc/templates/app.ini` | 25 | yes |
| 1004 | `docker/root/etc/templates/app.ini` | 31 | yes |
| 1005 | `docker/root/etc/templates/app.ini` | 34 | yes |
| 1006 | `docker/root/etc/templates/app.ini` | 37 | yes |
| 1007 | `docker/root/etc/templates/app.ini` | 40 | yes |
| 1008 | `docker/root/etc/templates/app.ini` | 41 | yes |
| 1009 | `docker/root/etc/templates/app.ini` | 49 | yes |
| 1010 | `docker/root/etc/templates/app.ini` | 56 | yes |
| 1011 | `docker/root/etc/templates/app.ini` | 57 | yes |
| 1012 | `docker/rootless/etc/templates/app.ini` | 2 | yes |
| 1013 | `docker/rootless/etc/templates/app.ini` | 24 | yes |
| 1014 | `modules/setting/actions.go` | 133 | yes |
| 1015 | `modules/setting/actions.go` | 134 | yes |
| 1016 | `modules/setting/actions.go` | 135 | yes |
| 1017 | `modules/setting/admin.go` | 31 | yes |
| 1018 | `modules/setting/admin.go` | 32 | yes |
| 1019 | `modules/setting/admin.go` | 33 | yes |
| 1020 | `modules/setting/admin.go` | 34 | yes |
| 1021 | `modules/setting/attachment.go` | 29 | yes |
| 1022 | `modules/setting/attachment.go` | 30 | yes |
| 1023 | `modules/setting/attachment.go` | 31 | yes |
| 1024 | `modules/setting/attachment.go` | 32 | yes |
| 1025 | `modules/setting/cache.go` | 47 | yes |
| 1026 | `modules/setting/cache.go` | 51 | yes |
| 1027 | `modules/setting/camo.go` | 22 | yes |
| 1028 | `modules/setting/database.go` | 63 | yes |
| 1029 | `modules/setting/database.go` | 64 | yes |
| 1030 | `modules/setting/database.go` | 65 | yes |
| 1031 | `modules/setting/database.go` | 69 | yes |
| 1032 | `modules/setting/database.go` | 75 | yes |
| 1033 | `modules/setting/database.go` | 77 | yes |
| 1034 | `modules/setting/database.go` | 79 | yes |
| 1035 | `modules/setting/database.go` | 83 | yes |
| 1036 | `modules/setting/database.go` | 85 | yes |
| 1037 | `modules/setting/database.go` | 87 | yes |
| 1038 | `modules/setting/database.go` | 88 | yes |
| 1039 | `modules/setting/database.go` | 89 | yes |
| 1040 | `modules/setting/database.go` | 90 | yes |
| 1041 | `modules/setting/git.go` | 96 | yes |
| 1042 | `modules/setting/global_lock.go` | 21 | yes |
| 1043 | `modules/setting/global_lock.go` | 25 | yes |
| 1044 | `modules/setting/i18n.go` | 59 | yes |
| 1045 | `modules/setting/i18n.go` | 63 | yes |
| 1046 | `modules/setting/indexer.go` | 55 | yes |
| 1047 | `modules/setting/indexer.go` | 63 | yes |
| 1048 | `modules/setting/indexer.go` | 76 | yes |
| 1049 | `modules/setting/indexer.go` | 78 | yes |
| 1050 | `modules/setting/indexer.go` | 79 | yes |
| 1051 | `modules/setting/indexer.go` | 80 | yes |
| 1052 | `modules/setting/indexer.go` | 81 | yes |
| 1053 | `modules/setting/indexer.go` | 85 | yes |
| 1054 | `modules/setting/indexer.go` | 86 | yes |
| 1055 | `modules/setting/indexer.go` | 88 | yes |
| 1056 | `modules/setting/indexer.go` | 89 | yes |
| 1057 | `modules/setting/indexer.go` | 90 | yes |
| 1058 | `modules/setting/indexer.go` | 91 | yes |
| 1059 | `modules/setting/indexer.go` | 92 | yes |
| 1060 | `modules/setting/indexer.go` | 93 | yes |
| 1061 | `modules/setting/lfs.go` | 63 | yes |
| 1062 | `modules/setting/log.go` | 39 | yes |
| 1063 | `modules/setting/log.go` | 40 | yes |
| 1064 | `modules/setting/log.go` | 49 | yes |
| 1065 | `modules/setting/log.go` | 51 | yes |
| 1066 | `modules/setting/log.go` | 52 | yes |
| 1067 | `modules/setting/log.go` | 59 | yes |
| 1068 | `modules/setting/log.go` | 64 | yes |
| 1069 | `modules/setting/log.go` | 65 | yes |
| 1070 | `modules/setting/log.go` | 67 | yes |
| 1071 | `modules/setting/log.go` | 73 | yes |
| 1072 | `modules/setting/log.go` | 74 | yes |
| 1073 | `modules/setting/log.go` | 80 | yes |
| 1074 | `modules/setting/log.go` | 86 | yes |
| 1075 | `modules/setting/log.go` | 87 | yes |
| 1076 | `modules/setting/log.go` | 93 | yes |
| 1077 | `modules/setting/mailer.go` | 72 | yes |
| 1078 | `modules/setting/mailer.go` | 81 | yes |
| 1079 | `modules/setting/mailer.go` | 91 | yes |
| 1080 | `modules/setting/mailer.go` | 92 | yes |
| 1081 | `modules/setting/mailer.go` | 95 | yes |
| 1082 | `modules/setting/mailer.go` | 101 | yes |
| 1083 | `modules/setting/mailer.go` | 103 | yes |
| 1084 | `modules/setting/mailer.go` | 104 | yes |
| 1085 | `modules/setting/mailer.go` | 105 | yes |
| 1086 | `modules/setting/mailer.go` | 106 | yes |
| 1087 | `modules/setting/mailer.go` | 107 | yes |
| 1088 | `modules/setting/mailer.go` | 108 | yes |
| 1089 | `modules/setting/mailer.go` | 109 | yes |
| 1090 | `modules/setting/mailer.go` | 109 | yes |
| 1091 | `modules/setting/mailer.go` | 163 | yes |
| 1092 | `modules/setting/mailer.go` | 218 | yes |
| 1093 | `modules/setting/mailer.go` | 228 | yes |
| 1094 | `modules/setting/markup.go` | 80 | yes |
| 1095 | `modules/setting/markup.go` | 137 | yes |
| 1096 | `modules/setting/markup.go` | 178 | yes |
| 1097 | `modules/setting/markup.go` | 183 | yes |
| 1098 | `modules/setting/markup.go` | 184 | yes |
| 1099 | `modules/setting/markup.go` | 191 | yes |
| 1100 | `modules/setting/markup.go` | 245 | yes |
| 1101 | `modules/setting/markup.go` | 251 | yes |
| 1102 | `modules/setting/markup.go` | 261 | yes |
| 1103 | `modules/setting/markup.go` | 262 | yes |
| 1104 | `modules/setting/markup.go` | 272 | yes |
| 1105 | `modules/setting/markup.go` | 281 | yes |
| 1106 | `modules/setting/markup.go` | 287 | yes |
| 1107 | `modules/setting/migrations.go` | 24 | yes |
| 1108 | `modules/setting/migrations.go` | 25 | yes |
| 1109 | `modules/setting/migrations.go` | 28 | yes |
| 1110 | `modules/setting/migrations.go` | 53 | yes |
| 1111 | `modules/setting/oauth2.go` | 65 | yes |
| 1112 | `modules/setting/oauth2.go` | 67 | yes |
| 1116 | `custom/conf/app.example.ini` |  | yes |
| 1116 | `docker/root/etc/templates/app.ini` |  | yes |
| 1116 | `docker/rootless/etc/templates/app.ini` |  | yes |
| 1116 | `options/label/Advanced.yaml` |  | yes |
| 1121 | `modules/setting/security.go` | 167 | yes |
| 1121 | `modules/setting/security.go` | 175 | yes |
| 1123 | `custom/conf/app.example.ini` | 1927 | yes |
| 1123 | `custom/conf/app.example.ini` | 520 | yes |
| 1123 | `custom/conf/app.example.ini` | 841 | yes |
| 1123 | `custom/conf/app.example.ini` | 861 | yes |
| 1123 | `modules/setting/incoming_email.go` | 23 | yes |
| 1123 | `modules/setting/security.go` | 224 | yes |
| 1123 | `modules/setting/service.go` | 141 | yes |
| 1123 | `modules/setting/service.go` | 172 | yes |
| 1127 | `custom/conf/app.example.ini` | 442 | yes |
| 1128 | `custom/conf/app.example.ini` | 446 | yes |
| 1129 | `custom/conf/app.example.ini` | 453 | yes |
| 1130 | `custom/conf/app.example.ini` | 520 | yes |
| 1131 | `custom/conf/app.example.ini` | 542 | yes |
| 1132 | `custom/conf/app.example.ini` | 572 | yes |
| 1133 | `custom/conf/app.example.ini` | 576 | yes |
| 1134 | `custom/conf/app.example.ini` | 2758 | yes |
| 1135 | `custom/conf/app.example.ini` | 1991 | yes |
| 1136 | `custom/conf/app.example.ini` | 853 | yes |
| 1137 | `custom/conf/app.example.ini` | 861 | yes |
| 1138 | `custom/conf/app.example.ini` | 841 | yes |
| 1139 | `custom/conf/app.example.ini` | 1022 | yes |
| 1140 | `custom/conf/app.example.ini` | 1927 | yes |
| 1180 | `custom/conf/app.example.ini` | 2143 | yes |
| 1180 | `services/cron/tasks_actions.go` | 27-80 | yes |
| 1180 | `services/cron/tasks_basic.go` | 31 | yes |
| 1180 | `services/cron/tasks_basic.go` | 88 | yes |
| 1180 | `services/cron/tasks_extended.go` | 141-146 | yes |
| 1180 | `services/cron/tasks_extended.go` | 197-199 | yes |

## Verification

**Source-to-claim audit:** performed (auditor: independent). 141 rows: 121 Supported, 14 Corrected, 2 Downgraded, 4 Answerable.

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
