# Facts summary

- Target: `flaskr-tdd`
- Commit: `305122f48823d98fd7fe8de989af2821b3c5d46d`
- Git history: shallow
- Schema: `appdoc-facts/5`

> Facts show what the extractors found. An empty list is not proof that something is absent: the extractors only recognise the patterns of the Stacks below, so read the source before writing "none". Facts from test code are marked `test` in `facts.json` and left out of the lists.

## Stacks

| Stack | Supported | Files read | Marker files |
|---|---|---|---|
| python-flask | yes | 6 | `requirements.txt` |

## Counts

| Kind | Count |
|---|---|
| auth_check | 1 |
| config_key | 32 |
| data_access | 1 |
| dependency | 7 |
| entry_point | 7 |
| file | 47 |
| message | 5 |
| smell | 7 |

| Stack | Facts |
|---|---|
| generic | 66 |
| python-flask | 41 |

## Scan coverage

Files found: 47 = scanned 47 + pruned 0 + ignored by `.appdocignore` 0.

No folders were pruned.

## Config files

| Application config file | Keys |
|---|---|
| `project/app.py` | 9 |

- ci: 2 files, 10 keys (not application settings)

## Top folders by file count

| Folder | Files | Entry points | Data access | External calls |
|---|---|---|---|---|
| `docs` | 24 | 0 | 0 | 0 |
| `(root)` | 10 | 0 | 0 | 0 |
| `project` | 9 | 7 | 1 | 0 |
| `.github` | 2 | 0 | 0 | 0 |
| `tests` | 2 | 0 | 0 | 0 |

## Largest source files

| File | Lines |
|---|---|
| `README.md` | 1760 |
| `docs/appdoc-2.3/facts.json` | 1358 |
| `docs/appdoc-2.3/application-documentation.md` | 1218 |
| `docs/appdoc-2.2-seeded/facts.json` | 983 |
| `docs/appdoc-2.2/facts.json` | 983 |
| `docs/appdoc/facts.json` | 884 |
| `docs/appdoc/check-report.md` | 535 |
| `docs/appdoc/application-documentation.md` | 485 |
| `docs/appdoc-2.3/check-report.md` | 392 |
| `docs/appdoc-2.2-seeded/application-documentation.md` | 381 |
| `docs/appdoc-2.2/application-documentation.md` | 370 |
| `docs/appdoc-2.2-seeded/check-report.md` | 247 |
| `docs/appdoc-2.2/check-report.md` | 247 |
| `docs/appdoc-2.3/facts-summary.md` | 140 |
| `project/app.py` | 125 |
| `docs/appdoc-2.2-seeded/facts-summary.md` | 113 |
| `docs/appdoc-2.2/facts-summary.md` | 113 |
| `docs/appdoc-2.3/evidence.jsonl` | 96 |
| `docs/appdoc/facts-summary.md` | 93 |
| `tests/app_test.py` | 88 |
| `project/templates/index.html` | 86 |
| `project/static/style.css` | 74 |
| `project/templates/search.html` | 65 |
| `docs/appdoc/verification.md` | 63 |
| `project/templates/login.html` | 62 |

## Entry points

- `/` — `project/app.py:56`
- `/add` — `project/app.py:63`
- `/login` — `project/app.py:75`
- `/login` — `project/app.py:75`
- `/logout` — `project/app.py:91`
- `/delete/<int:post_id>` — `project/app.py:99`
- `/search/` — `project/app.py:115`

## Data access

- `Post` — `project/models.py:4`

## Connections (locations only)

None extracted. This is not proof of absence.

## Config keys flagged as secret locations

- `PASSWORD` — `project/app.py:24`
- `SECRET_KEY` — `project/app.py:25`
- `PASSWORD` — `project/app.py:82`
- (13 more in test code, not listed)

## External calls

None extracted. This is not proof of absence.

## Auth checks

- `@login_required` — `project/app.py:100`

## Schema objects

None extracted. This is not proof of absence.

## Ownership files

None extracted. This is not proof of absence.

## UI pages

None extracted. This is not proof of absence.

## Finding candidates

| Pattern | Count | First locations | id |
|---|---|---|---|
| `distinct-auth-errors` | 1 | `project/app.py:81` | `d4f98c3a` |
| `hardcoded-credential-constant` | 2 | `project/app.py:24`, `project/app.py:25` | `59dac88f`, `764f37d9` |
| `state-change-on-get` | 1 | `project/app.py:99` | `0d713910` |
| `unescaped-template-output` | 2 | `project/templates/index.html:74`, `project/templates/search.html:55` | `e7b549e6`, `a8db4dc9` |
