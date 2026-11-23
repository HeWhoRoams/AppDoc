# Facts summary

- Target: `gitea`
- Commit: `a61ad4876a6c8e6b3803c74d4423615e2571613b`
- Git history: shallow
- Schema: `appdoc-facts/6`

> Facts show what the extractors found. An empty list is not proof that something is absent: the extractors only recognise the patterns of the Stacks below, so read the source before writing "none". Facts from test code are marked `test` in `facts.json` and left out of the lists.

## System Connections

> Derived deterministically from the `connection`, `external_call` and `dependency` Facts in `facts.json` - a pure function of the Facts, byte-identical across runs. A group with no rows is not proof of absence; the extractors only recognise the patterns of the detected Stacks.

### Integration map

app -> { database, http }

| System | Kind | Count | Drivers / targets |
|---|---|---:|---|
| Database | connection | 5 | `sql.Open`, `xorm.NewEngine` |
| Outbound HTTP | external call | 25 | `http.Get`, `http.NewRequest`, `http.NewRequestWithContext`, `https://challenges.cloudflare.com/turnstile/v0/siteverify` |

### Provenance

- **Database** - 5 x `sql.Open`, `xorm.NewEngine`
  - `models/db/engine_init.go:34`
  - `models/unittest/testdb.go:157`
  - `models/unittest/testdb.go:172`
  - ... 2 more in `facts.json`
- **Outbound HTTP** - 25 x `http.Get`, `http.NewRequest`, `http.NewRequestWithContext`, `https://challenges.cloudflare.com/turnstile/v0/siteverify`
  - `build/generate-emoji.go:81`
  - `build/generate-gitignores.go:45`
  - `models/unittest/mock_http.go:87`
  - ... 22 more in `facts.json`

### Dependencies

| Manager | Count | Examples |
|---|---:|---|
| go | 95 | `connectrpc.com/connect/v2`, `gitea.com/lunny/dingtalk_webhook`, `gitea.com/lunny/levelqueue`, `gitea.dev/actionslib`, `gitea.dev/sdk`, ... +90 more |
| npm | 97 | `@codemirror/autocomplete`, `@codemirror/commands`, `@codemirror/lang-json`, `@codemirror/lang-markdown`, `@codemirror/language`, ... +92 more |


## Stacks

| Stack | Supported | Files read | Marker files |
|---|---|---|---|
| go | yes | 3184 | `go.mod` |
| node | no (generic only) | 1 | `package.json` |
| python | no (generic only) | 1 | `pyproject.toml` |

## Counts

| Kind | Count |
|---|---|
| auth_check | 429 |
| config_key | 10601 |
| connection | 8 |
| data_access | 176 |
| dependency | 192 |
| entry_point | 1554 |
| external_call | 43 |
| file | 6415 |
| owner_file | 2 |
| schema_object | 116 |

| Stack | Facts |
|---|---|
| generic | 16713 |
| go | 2823 |

## Scan coverage

Files found: 6415 = scanned 6415 + pruned 0 + ignored by `.appdocignore` 0.

No folders were pruned.

## Config files

| Application config file | Keys |
|---|---|
| `custom/conf/app.example.ini` | 290 |
| `modules/setting/service.go` | 58 |
| `modules/setting/server.go` | 44 |
| `routers/install/install.go` | 42 |
| `docker/root/etc/templates/app.ini` | 28 |
| `docker/rootless/etc/templates/app.ini` | 26 |
| `modules/setting/security.go` | 24 |
| `modules/setting/storage.go` | 24 |
| `modules/setting/log.go` | 23 |
| `modules/setting/database.go` | 21 |
| `modules/setting/ssh.go` | 21 |
| `modules/setting/mailer.go` | 20 |
| `modules/setting/indexer.go` | 16 |
| `modules/setting/markup.go` | 14 |
| `modules/setting/picture.go` | 14 |
| `modules/setting/repository.go` | 11 |
| `modules/setting/session.go` | 10 |
| `modules/setting/task.go` | 9 |
| `modules/setting/oauth2.go` | 8 |
| `modules/setting/webhook.go` | 7 |
| `cmd/web.go` | 5 |
| `modules/setting/admin.go` | 4 |
| `modules/setting/attachment.go` | 4 |
| `modules/setting/cache.go` | 4 |
| `modules/setting/migrations.go` | 4 |
| … 14 more files | |

- build: 8 files, 124 keys (not application settings)
- ci: 30 files, 671 keys (not application settings)

## Top folders by file count

| Folder | Files | Entry points | Data access | External calls |
|---|---|---|---|---|
| `modules` | 1288 | 11 | 0 | 16 |
| `tests` | 886 | 3 | 8 | 3 |
| `services` | 746 | 36 | 22 | 20 |
| `templates` | 608 | 0 | 0 | 0 |
| `routers` | 519 | 1424 | 0 | 1 |
| `public` | 502 | 0 | 0 | 0 |
| `models` | 469 | 1 | 77 | 1 |
| `web_src` | 419 | 0 | 0 | 0 |
| `modelmigration` | 407 | 0 | 69 | 0 |
| `options` | 331 | 0 | 0 | 0 |
| `cmd` | 58 | 79 | 0 | 0 |
| `(root)` | 50 | 0 | 0 | 0 |
| `.github` | 33 | 0 | 0 | 0 |
| `contrib` | 31 | 0 | 0 | 0 |
| `docker` | 21 | 0 | 0 | 0 |
| `tools` | 19 | 0 | 0 | 0 |
| `build` | 10 | 0 | 0 | 2 |
| `docs` | 9 | 0 | 0 | 0 |
| `assets` | 4 | 0 | 0 | 0 |
| `snap` | 3 | 0 | 0 | 0 |
| `.devcontainer` | 1 | 0 | 0 | 0 |
| `custom` | 1 | 0 | 0 | 0 |

## Largest source files

| File | Lines |
|---|---|
| `templates/swagger/v1-openapi3.generated.json` | 37314 |
| `templates/swagger/v1-swagger.generated.json` | 34879 |
| `options/fileicon/material-icon-rules.json` | 13428 |
| `pnpm-lock.yaml` | 8452 |
| `web_src/fomantic/build/components/dropdown.js` | 4273 |
| `options/locale/locale_en-US.json` | 4055 |
| `options/locale/locale_pt-PT.json` | 4049 |
| `options/locale/locale_zh-CN.json` | 4049 |
| `options/locale/locale_ga-IE.json` | 4039 |
| `options/locale/locale_fr-FR.json` | 4035 |
| `options/locale/locale_de-DE.json` | 4023 |
| `options/locale/locale_ko-KR.json` | 4023 |
| `options/locale/locale_ja-JP.json` | 3972 |
| `options/locale/locale_pl-PL.json` | 3898 |
| `options/locale/locale_tr-TR.json` | 3609 |
| `options/locale/locale_pt-BR.json` | 3270 |
| `options/locale/locale_cs-CZ.json` | 3158 |
| `options/locale/locale_zh-TW.json` | 3150 |
| `custom/conf/app.example.ini` | 3087 |
| `options/locale/locale_uk-UA.json` | 3039 |
| `options/locale/locale_lv-LV.json` | 2905 |
| `options/locale/locale_el-GR.json` | 2864 |
| `options/locale/locale_ru-RU.json` | 2848 |
| `options/locale/locale_es-ES.json` | 2820 |
| `options/locale/locale_it-IT.json` | 2260 |

## Entry points

- `actions` — `cmd/actions.go:17`
- `generate-runner-token` — `cmd/actions.go:27`
- `admin` — `cmd/admin.go:22`
- `repo-sync-releases` — `cmd/admin.go:36`
- `regenerate` — `cmd/admin.go:44`
- `auth` — `cmd/admin.go:55`
- `sendmail` — `cmd/admin.go:77`
- `delete` — `cmd/admin_auth.go:22`
- `list` — `cmd/admin_auth.go:31`
- `add-ldap` — `cmd/admin_auth_ldap.go:179`
- `update-ldap` — `cmd/admin_auth_ldap.go:190`
- `add-ldap-simple` — `cmd/admin_auth_ldap.go:201`
- `update-ldap-simple` — `cmd/admin_auth_ldap.go:212`
- `add-oauth` — `cmd/admin_auth_oauth.go:137`
- `update-oauth` — `cmd/admin_auth_oauth.go:148`
- `update-smtp` — `cmd/admin_auth_smtp.go:75`
- `add-smtp` — `cmd/admin_auth_smtp.go:89`
- `hooks` — `cmd/admin_regenerate.go:18`
- `keys` — `cmd/admin_regenerate.go:26`
- `user` — `cmd/admin_user.go:30`
- `change-password` — `cmd/admin_user_change_password.go:22`
- `change-type` — `cmd/admin_user_change_type.go:19`
- `create` — `cmd/admin_user_create.go:24`
- `delete` — `cmd/admin_user_delete.go:22`
- `disable-2fa` — `cmd/admin_user_disable_2fa.go:21`
- `generate-access-token` — `cmd/admin_user_generate_access_token.go:19`
- `list` — `cmd/admin_user_list.go:19`
- `must-change-password` — `cmd/admin_user_must_change_password.go:18`
- `cert` — `cmd/cert.go:31`
- `edit-ini` — `cmd/config.go:19`
- `config` — `cmd/config.go:83`
- `docs` — `cmd/docs.go:18`
- `doctor` — `cmd/doctor.go:28`
- `check` — `cmd/doctor.go:41`
- `recreate-table` — `cmd/doctor.go:81`
- `convert` — `cmd/doctor_convert.go:18`
- `dump` — `cmd/dump.go:26`
- `dump-repo` — `cmd/dump_repo.go:28`
- `embedded` — `cmd/embedded.go:29`
- `list` — `cmd/embedded.go:42`
- `view` — `cmd/embedded.go:57`
- `extract` — `cmd/embedded.go:72`
- `generate` — `cmd/generate.go:22`
- `secret` — `cmd/generate.go:33`
- `ssh` — `cmd/generate.go:45`
- `INTERNAL_TOKEN` — `cmd/generate.go:56`
- `JWT_SECRET` — `cmd/generate.go:64`
- `SECRET_KEY` — `cmd/generate.go:73`
- `key` — `cmd/generate.go:81`
- `host-keys` — `cmd/generate.go:94`
- … 1484 more in `facts.json`
- (20 more in test code, not listed)

## Data access

- `repository` — `modelmigration/v1_10/v100.go:55`
- `team` — `modelmigration/v1_11/v105.go:22`
- `watch` — `modelmigration/v1_11/v106.go:25`
- `protected_branch` — `modelmigration/v1_11/v111.go:357`
- `protected_branch` — `modelmigration/v1_11/v111.go:360`
- `protected_branch` — `modelmigration/v1_11/v111.go:363`
- `attachment` — `modelmigration/v1_11/v112.go:46`
- `repository` — `modelmigration/v1_11/v114.go:44`
- `tracked_time` — `modelmigration/v1_11/v116.go:25`
- `repository` — `modelmigration/v1_12/v119.go:15`
- `repository` — `modelmigration/v1_12/v120.go:19`
- `issue_dependency` — `modelmigration/v1_12/v129.go:13`
- `issue_dependency` — `modelmigration/v1_12/v129.go:16`
- `webhook` — `modelmigration/v1_12/v130.go:101`
- `user` — `modelmigration/v1_13/v143.go:39`
- `comment` — `modelmigration/v1_13/v148.go:13`
- `repository` — `modelmigration/v1_14/v156.go:91`
- `hook_task` — `modelmigration/v1_14/v161.go:56`
- `webhook` — `modelmigration/v1_14/v162.go:47`
- `comment` — `modelmigration/v1_14/v169.go:13`
- `issue_label` — `modelmigration/v1_14/v176.go:51`
- `comment` — `modelmigration/v1_14/v176.go:64`
- `issue_label` — `modelmigration/v1_14/v177.go:31`
- `email_address` — `modelmigration/v1_15/v181.go:34`
- `issue_index` — `modelmigration/v1_15/v182.go:35`
- `attachment` — `modelmigration/v1_16/v193.go:25`
- `attachment` — `modelmigration/v1_16/v193.go:29`
- `commit_status_index` — `modelmigration/v1_16/v195.go:39`
- `team_unit` — `modelmigration/v1_16/v206.go:27`
- `webauthn_credential` — `modelmigration/v1_16/v210.go:187`
- `package_property` — `modelmigration/v1_17/v220.go:19`
- `package_property` — `modelmigration/v1_17/v220.go:22`
- `package_property` — `modelmigration/v1_17/v220.go:25`
- `milestone` — `modelmigration/v1_18/v229.go:48`
- `access_token` — `modelmigration/v1_19/v239.go:22`
- `repository` — `modelmigration/v1_20/v255.go:22`
- `repository` — `modelmigration/v1_21/v263.go:31`
- `repository` — `modelmigration/v1_21/v263.go:36`
- `repository` — `modelmigration/v1_21/v263.go:41`
- `commit_status` — `modelmigration/v1_21/v266.go:20`
- `package_property` — `modelmigration/v1_21/v270.go:20`
- `package_property` — `modelmigration/v1_21/v270.go:23`
- `action_artifact` — `modelmigration/v1_21/v274.go:32`
- `user` — `modelmigration/v1_22/v280.go:20`
- `user` — `modelmigration/v1_22/v280.go:23`
- `user` — `modelmigration/v1_22/v280.go:26`
- `repository` — `modelmigration/v1_22/v286.go:100`
- `badge` — `modelmigration/v1_22/v287.go:37`
- `repository` — `modelmigration/v1_22/v289.go:25`
- `hook_task` — `modelmigration/v1_22/v290.go:26`
- … 100 more in `facts.json`
- (26 more in test code, not listed)

## Connections (locations only)

- `xorm.NewEngine` — `models/db/engine_init.go:34`
- `sql.Open` — `models/unittest/testdb.go:157`
- `sql.Open` — `models/unittest/testdb.go:172`
- `sql.Open` — `models/unittest/testdb.go:187`
- `xorm.NewEngine` — `models/unittest/testdb.go:213`
- (3 more in test code, not listed)

## Config keys flagged as secret locations

- `api_token_env` — `crowdin.yml:2`
- `server.LFS_JWT_SECRET` — `custom/conf/app.example.ini:318`
- `server.LFS_JWT_SECRET_URI` — `custom/conf/app.example.ini:321`
- `database.PASSWD` — `custom/conf/app.example.ini:367`
- `database.PASSWD` — `custom/conf/app.example.ini:379`
- `database.PASSWD` — `custom/conf/app.example.ini:400`
- `security.SECRET_KEY` — `custom/conf/app.example.ini:446`
- `security.SECRET_KEY_URI` — `custom/conf/app.example.ini:450`
- `security.INTERNAL_TOKEN` — `custom/conf/app.example.ini:453`
- `security.INTERNAL_TOKEN_URI` — `custom/conf/app.example.ini:456`
- `security.MIN_PASSWORD_LENGTH` — `custom/conf/app.example.ini:482`
- `security.PASSWORD_COMPLEXITY` — `custom/conf/app.example.ini:505`
- `security.PASSWORD_HASH_ALGO` — `custom/conf/app.example.ini:508`
- `security.PASSWORD_CHECK_PWN` — `custom/conf/app.example.ini:511`
- `security.SUCCESSFUL_TOKENS_CACHE_SIZE` — `custom/conf/app.example.ini:515`
- `security.DISABLE_QUERY_AUTH_TOKEN` — `custom/conf/app.example.ini:520`
- `oauth2.JWT_SIGNING_PRIVATE_KEY_FILE` — `custom/conf/app.example.ini:611`
- `oauth2.JWT_SECRET` — `custom/conf/app.example.ini:615`
- `oauth2.JWT_SECRET_URI` — `custom/conf/app.example.ini:618`
- `oauth2.ACCESS_TOKEN_EXPIRATION_TIME` — `custom/conf/app.example.ini:626`
- `oauth2.REFRESH_TOKEN_EXPIRATION_TIME` — `custom/conf/app.example.ini:629`
- `oauth2.INVALIDATE_REFRESH_TOKENS` — `custom/conf/app.example.ini:632`
- `oauth2.MAX_TOKEN_LENGTH` — `custom/conf/app.example.ini:635`
- `service.RESET_PASSWD_CODE_LIVE_MINUTES` — `custom/conf/app.example.ini:825`
- `service.ENABLE_PASSWORD_SIGNIN_FORM` — `custom/conf/app.example.ini:865`
- `service.RECAPTCHA_SECRET` — `custom/conf/app.example.ini:892`
- `service.HCAPTCHA_SECRET` — `custom/conf/app.example.ini:896`
- `service.MCAPTCHA_SECRET` — `custom/conf/app.example.ini:904`
- `service.CF_TURNSTILE_SECRET` — `custom/conf/app.example.ini:909`
- `cors.ALLOW_CREDENTIALS` — `custom/conf/app.example.ini:1381`
- `mailer.PASSWD` — `custom/conf/app.example.ini:1866`
- `email.incoming.PASSWORD` — `custom/conf/app.example.ini:1921`
- `attachment.MINIO_SECRET_ACCESS_KEY` — `custom/conf/app.example.ini:2086`
- `attachment.AZURE_BLOB_ACCOUNT_KEY` — `custom/conf/app.example.ini:2123`
- `metrics.TOKEN` — `custom/conf/app.example.ini:2758`
- `storage.minio.MINIO_SECRET_ACCESS_KEY` — `custom/conf/app.example.ini:2978`
- `storage.azureblob.AZURE_BLOB_ACCOUNT_KEY` — `custom/conf/app.example.ini:3013`
- `database.PASSWD` — `docker/root/etc/templates/app.ini:30`
- `security.SECRET_KEY` — `docker/root/etc/templates/app.ini:53`
- `database.PASSWD` — `docker/rootless/etc/templates/app.ini:33`
- `security.SECRET_KEY` — `docker/rootless/etc/templates/app.ini:50`
- `database.PASSWD` — `modules/setting/database.go:61`
- `server.LFS_JWT_SECRET` — `modules/setting/lfs.go:79`
- `server.LFS_JWT_SECRET` — `modules/setting/lfs.go:80`
- `oauth2.JWT_SECRET` — `modules/setting/oauth2.go:147`
- `oauth2.JWT_SECRET` — `modules/setting/oauth2.go:148`
- `security.INTERNAL_TOKEN` — `modules/setting/security.go:137`
- `security.INTERNAL_TOKEN` — `modules/setting/security.go:138`
- `security.MIN_PASSWORD_LENGTH` — `modules/setting/security.go:167`
- `security.PASSWORD_HASH_ALGO` — `modules/setting/security.go:175`
- … 20 more in `facts.json`
- (8441 more in test code, not listed)

## External calls

- `http.Get` — `build/generate-emoji.go:81`
- `http.NewRequest` — `build/generate-gitignores.go:45`
- `http.NewRequest` — `models/unittest/mock_http.go:87`
- `http.NewRequestWithContext` — `modules/hcaptcha/hcaptcha.go:96`
- `http.NewRequestWithContext` — `modules/indexer/internal/elasticsearch/indexer.go:284`
- `http.NewRequestWithContext` — `modules/lfs/http_client.go:236`
- `http.NewRequestWithContext` — `modules/mcaptcha/mcaptcha.go:44`
- `http.NewRequestWithContext` — `modules/recaptcha/recaptcha.go:35`
- `http.NewRequestWithContext` — `modules/storage/azureblob.go:226`
- `https://challenges.cloudflare.com/turnstile/v0/siteverify` — `modules/turnstile/turnstile.go:47`
- `http.NewRequest` — `modules/updatechecker/update_checker.go:37`
- `http.NewRequestWithContext` — `routers/web/auth/oauth.go:313`
- `http.NewRequestWithContext` — `services/migrations/bitbucket.go:179`
- `http.NewRequestWithContext` — `services/migrations/bitbucketserver.go:349`
- `http.NewRequestWithContext` — `services/migrations/codebase.go:128`
- `http.NewRequestWithContext` — `services/migrations/codecommit.go:300`
- `http.NewRequestWithContext` — `services/migrations/common.go:28`
- `http.NewRequestWithContext` — `services/migrations/github_graphql.go:166`
- `http.NewRequestWithContext` — `services/migrations/onedev.go:120`
- `http.NewRequest` — `services/webhook/deliver.go:39`
- `http.NewRequest` — `services/webhook/deliver.go:50`
- `http.NewRequest` — `services/webhook/deliver.go:67`
- `http.NewRequest` — `services/webhook/deliver.go:79`
- `http.NewRequest` — `services/webhook/matrix.go:55`
- `http.NewRequest` — `services/webhook/payloader.go:112`
- (18 more in test code, not listed)

## Auth checks

- `reqPackageAccess` — `routers/api/packages/api.go:112`
- `reqPackageAccess` — `routers/api/packages/api.go:113`
- `reqPackageAccess` — `routers/api/packages/api.go:114`
- `reqPackageAccess` — `routers/api/packages/api.go:115`
- `reqPackageAccess` — `routers/api/packages/api.go:119`
- `reqPackageAccess` — `routers/api/packages/api.go:122`
- `reqPackageAccess` — `routers/api/packages/api.go:127`
- `reqPackageAccess` — `routers/api/packages/api.go:132`
- `reqPackageAccess` — `routers/api/packages/api.go:134`
- `reqPackageAccess` — `routers/api/packages/api.go:141`
- `reqPackageAccess` — `routers/api/packages/api.go:144`
- `reqPackageAccess` — `routers/api/packages/api.go:148`
- `reqPackageAccess` — `routers/api/packages/api.go:149`
- `reqPackageAccess` — `routers/api/packages/api.go:161`
- `reqPackageAccess` — `routers/api/packages/api.go:167`
- `reqPackageAccess` — `routers/api/packages/api.go:172`
- `reqPackageAccess` — `routers/api/packages/api.go:175`
- `reqPackageAccess` — `routers/api/packages/api.go:180`
- `reqPackageAccess` — `routers/api/packages/api.go:187`
- `reqPackageAccess` — `routers/api/packages/api.go:189`
- `reqPackageAccess` — `routers/api/packages/api.go:200`
- `reqPackageAccess` — `routers/api/packages/api.go:203`
- `reqPackageAccess` — `routers/api/packages/api.go:206`
- `reqPackageAccess` — `routers/api/packages/api.go:210`
- `reqPackageAccess` — `routers/api/packages/api.go:219`
- `reqPackageAccess` — `routers/api/packages/api.go:223`
- `reqPackageAccess` — `routers/api/packages/api.go:236`
- `reqPackageAccess` — `routers/api/packages/api.go:242`
- `reqPackageAccess` — `routers/api/packages/api.go:248`
- `reqPackageAccess` — `routers/api/packages/api.go:252`
- `reqPackageAccess` — `routers/api/packages/api.go:254`
- `reqPackageAccess` — `routers/api/packages/api.go:259`
- `reqPackageAccess` — `routers/api/packages/api.go:264`
- `reqPackageAccess` — `routers/api/packages/api.go:282`
- `reqPackageAccess` — `routers/api/packages/api.go:290`
- `reqPackageAccess` — `routers/api/packages/api.go:298`
- `reqPackageAccess` — `routers/api/packages/api.go:301`
- `reqPackageAccess` — `routers/api/packages/api.go:313`
- `reqPackageAccess` — `routers/api/packages/api.go:319`
- `reqPackageAccess` — `routers/api/packages/api.go:320`
- `reqPackageAccess` — `routers/api/packages/api.go:332`
- `reqPackageAccess` — `routers/api/packages/api.go:334`
- `reqPackageAccess` — `routers/api/packages/api.go:337`
- `reqPackageAccess` — `routers/api/packages/api.go:344`
- `reqPackageAccess` — `routers/api/packages/api.go:347`
- `reqPackageAccess` — `routers/api/packages/api.go:348`
- `reqPackageAccess` — `routers/api/packages/api.go:350`
- `reqPackageAccess` — `routers/api/packages/api.go:351`
- `reqPackageAccess` — `routers/api/packages/api.go:361`
- `reqPackageAccess` — `routers/api/packages/api.go:371`
- … 379 more in `facts.json`

## Schema objects

| Type | Dialect | Count |
|---|---|---|
| table | unspecified | 116 |

| Table | Dialect | Columns | Defined at |
|---|---|---|---|
| `Access` | unspecified | 0 | `models/perm/access/access.go:33` |
| `AccessToken` | unspecified | 0 | `models/auth/access_token.go:43` |
| `Action` | unspecified | 0 | `models/activities/action.go:154` |
| `ActionArtifact` | unspecified | 0 | `models/actions/artifact.go:53` |
| `ActionRun` | unspecified | 0 | `models/actions/run.go:79` |
| `ActionRunAttempt` | unspecified | 0 | `models/actions/run_attempt.go:47` |
| `ActionRunAttemptJobIDIndex` | unspecified | 0 | `models/actions/run_job.go:150` |
| `ActionRunIndex` | unspecified | 0 | `models/actions/run.go:80` |
| `ActionRunJob` | unspecified | 0 | `models/actions/run_job.go:149` |
| `ActionRunJobSummary` | unspecified | 0 | `models/actions/run_job_summary.go:57` |
| `ActionRunner` | unspecified | 0 | `models/actions/runner.go:207` |
| `ActionRunnerToken` | unspecified | 0 | `models/actions/runner_token.go:45` |
| `ActionSchedule` | unspecified | 0 | `models/actions/schedule.go:41` |
| `ActionScheduleSpec` | unspecified | 0 | `models/actions/schedule_spec.go:63` |
| `ActionScopedWorkflowSource` | unspecified | 0 | `models/actions/scoped_workflow.go:41` |
| `ActionTask` | unspecified | 0 | `models/actions/task.go:68` |
| `ActionTaskOutput` | unspecified | 0 | `models/actions/task_output.go:24` |
| `ActionTaskStep` | unspecified | 0 | `models/actions/task_step.go:62` |
| `ActionTasksVersion` | unspecified | 0 | `models/actions/tasks_version.go:28` |
| `ActionVariable` | unspecified | 0 | `models/actions/variable.go:48` |
| `AppState` | unspecified | 0 | `models/system/appstate.go:24` |
| `Attachment` | unspecified | 0 | `models/repo/attachment.go:42` |
| `AuthToken` | unspecified | 0 | `models/auth/auth_token.go:29` |
| `AutoMerge` | unspecified | 0 | `models/pull/automerge.go:35` |
| `Badge` | unspecified | 0 | `models/user/badge.go:41` |
| `Blocking` | unspecified | 0 | `models/user/block.go:41` |
| `Branch` | unspecified | 0 | `models/git/branch.go:155` |
| `Collaboration` | unspecified | 0 | `models/repo/collaboration.go:30` |
| `Column` | unspecified | 0 | `models/project/column.go:85` |
| `Comment` | unspecified | 0 | `models/issues/comment.go:373` |
| `CommitStatus` | unspecified | 0 | `models/git/commit_status.go:60` |
| `CommitStatusIndex` | unspecified | 0 | `models/git/commit_status.go:61` |
| `CommitStatusSummary` | unspecified | 0 | `models/git/commit_status_summary.go:26` |
| `ContentHistory` | unspecified | 0 | `models/issues/content_history.go:37` |
| `DeployKey` | unspecified | 0 | `models/deploykey/deploykey.go:58` |
| `EmailAddress` | unspecified | 0 | `models/user/email_address.go:93` |
| `EmailHash` | unspecified | 0 | `models/avatars/avatar.go:40` |
| `Event` | unspecified | 0 | `models/audit/audit_event.go:19` |
| `ExternalLoginUser` | unspecified | 0 | `models/user/external_login_user.go:79` |
| `Follow` | unspecified | 0 | `models/user/follow.go:25` |

40 of 116 shown; the rest are in `facts.json`.

## Ownership files

| File | Kind | Entries |
|---|---|---|
| `CONTRIBUTING.md` | contributing | 294 |
| `MAINTAINERS` | maintainers | 69 |

## UI pages

None extracted. This is not proof of absence.
