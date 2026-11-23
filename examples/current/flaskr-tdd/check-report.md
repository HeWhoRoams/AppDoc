# Check: PASS

**Scope.** Run by AppDoc 2.6.0 (bundle c0768e029882). This Check verifies **resolution and structure**: every Citation points to a real file and line inside the Target (see the Citation register), and every Evidence Register row's anchor text appears in the lines it cites. It does **not** judge whether a claim's wording follows from those lines; that is the source-to-claim audit, recorded in `evidence.jsonl`. A PASS is not an accuracy certification.

## Universal claims cite single lines (advisory)

1 universal claim cites only single lines. This is not a problem; `appdoc check --strict` fails on it.

- line 152: `All three pages of the Target are catalogued (`project/templates/index.html:1`, `project/templates/login.html:1`, `project/templates/search.html:1`).`

## Citation precision (advisory)

1 citation is broader than the claim needs. This is not a problem; `appdoc check --strict` fails on it. Fix: cite the specific lines the claim rests on (`path:start-end`, at most 100 lines), and split a cell that cites many sources.

- line 288: `project/app.py:1-125` spans 125 lines (more than 100) and is this claim's only lined Citation

## Template 2.7 previews (advisory)

4 findings would fail a template 2.7 document. This document is on template 2.4, so none of them fails it; they need no action yet.

- C17 line 1: evidence.jsonl line 1: the audit scope text holds an ID or a number. Fix: describe only the method; coverage is computed (fails from template 2.7)
- C9 line 276: 10.1 row V-9 (High) outranks the row before it (V-8, Low). Fix: move the row; keep its ID (fails from template 2.7)
- C9 line 375: 15 row R-6 (Medium) outranks the row before it (R-5, Low). Fix: move the row; keep its ID (fails from template 2.7)
- C9 line 378: 15 row R-9 (High) outranks the row before it (R-8, Medium). Fix: move the row; keep its ID (fails from template 2.7)

## Gaps declared: Unknown by absence
Advisory only; this is not a problem.

- deployment runbook is Unknown by absence (no appdoc-context.md); add one to fill section 16.5 Rollback, Backup and Restore

## Citation register

| Doc line | Cited path | Line/range | Resolved |
|---|---|---|---|
| 12 | `project/templates/index.html` | 71-78 | yes |
| 13 | `project/templates/login.html` | 31 | yes |
| 14 | `project/templates/index.html` | 35-36 | yes |
| 15 | `project/static/main.js` | 7-21 | yes |
| 16 | `project/templates/search.html` | 39 | yes |
| 17 | `create_db.py` | 7-12 | yes |
| 18 | `project/app.py` | 21-32 | yes |
| 19 | `.github/workflows/main.yml` | 1-29 | yes |
| 23 | `project/` |  | yes |
| 27 | `.github/workflows/main.yml` |  | yes |
| 27 | `LICENSE` |  | yes |
| 27 | `Procfile` |  | yes |
| 27 | `README.md` |  | yes |
| 27 | `README.md` | 1013-1083 | yes |
| 27 | `create_db.py` |  | yes |
| 27 | `docs/` |  | yes |
| 27 | `flaskr-app.png` |  | yes |
| 27 | `project/` |  | yes |
| 27 | `project/flaskr.db` |  | yes |
| 27 | `project/static/style.css` |  | yes |
| 27 | `requirements.txt` |  | yes |
| 27 | `runtime.txt` |  | yes |
| 27 | `tdd.png` |  | yes |
| 27 | `tests/` |  | yes |
| 38 | `project/` |  | yes |
| 39 | `.github/` |  | yes |
| 40 | `tests/` |  | yes |
| 47 | `README.md` | 3 | yes |
| 47 | `project/app.py` | 56-112 | yes |
| 51 | `project/app.py` | 1-125 | yes |
| 51 | `project/app.py` | 26-32 | yes |
| 51 | `project/app.py` | 36-40 | yes |
| 51 | `project/models.py` | 4-8 | yes |
| 51 | `project/templates/index.html` | 5-9 | yes |
| 57 | `project/app.py` |  | yes |
| 57 | `project/app.py` | 36-125 | yes |
| 58 | `project/models.py` |  | yes |
| 58 | `project/models.py` | 4-8 | yes |
| 59 | `project/templates/` |  | yes |
| 59 | `project/templates/index.html` | 1-86 | yes |
| 59 | `project/templates/login.html` | 1-62 | yes |
| 59 | `project/templates/search.html` | 1-65 | yes |
| 60 | `project/static/main.js` |  | yes |
| 60 | `project/static/main.js` | 5-24 | yes |
| 61 | `create_db.py` |  | yes |
| 61 | `create_db.py` | 7-12 | yes |
| 62 | `tests/app_test.py` |  | yes |
| 62 | `tests/app_test.py` | 1-88 | yes |
| 63 | `Procfile` |  | yes |
| 63 | `Procfile` | 1 | yes |
| 78 | `project/app.py` | 56-125 | yes |
| 78 | `project/static/main.js` | 11 | yes |
| 78 | `project/templates/index.html` | 5-9 | yes |
| 82 | `project/app.py` | 100 | yes |
| 82 | `project/app.py` | 45-53 | yes |
| 82 | `project/app.py` | 66-67 | yes |
| 82 | `project/app.py` | 75-87 | yes |
| 82 | `project/models.py` | 4-14 | yes |
| 96 | `project/app.py` | 56-60 | yes |
| 96 | `project/models.py` | 4 | yes |
| 96 | `project/templates/index.html` | 72-77 | yes |
| 97 | `project/app.py` | 63-72 | yes |
| 97 | `project/app.py` | 66-72 | yes |
| 98 | `project/app.py` | 23-24 | yes |
| 98 | `project/app.py` | 75-88 | yes |
| 98 | `project/app.py` | 80-83 | yes |
| 99 | `project/app.py` | 91-96 | yes |
| 99 | `project/app.py` | 91-96 | yes |
| 100 | `project/app.py` | 103-112 | yes |
| 100 | `project/app.py` | 99-112 | yes |
| 101 | `project/app.py` | 115-121 | yes |
| 101 | `project/app.py` | 117-120 | yes |
| 101 | `project/templates/search.html` | 51-52 | yes |
| 102 | `project/static/main.js` | 7-20 | yes |
| 102 | `project/static/main.js` | 7-21 | yes |
| 103 | `create_db.py` | 7-12 | yes |
| 103 | `create_db.py` | 7-12 | yes |
| 109 | `Procfile` |  | yes |
| 109 | `README.md` |  | yes |
| 109 | `create_db.py` |  | yes |
| 109 | `requirements.txt` |  | yes |
| 109 | `requirements.txt` | 1-8 | yes |
| 109 | `runtime.txt` |  | yes |
| 109 | `runtime.txt` | 1 | yes |
| 110 | `project/` |  | yes |
| 110 | `requirements.txt` | 1-2 | yes |
| 111 | `.github/` |  | yes |
| 111 | `.github/workflows/main.yml` | 1-29 | yes |
| 112 | `project/flaskr.db` |  | yes |
| 112 | `tests/` |  | yes |
| 112 | `tests/app_test.py` | 1-88 | yes |
| 118 | `project/app.py` | 21-125 | yes |
| 118 | `project/app.py` | 23-24 | yes |
| 118 | `project/app.py` | 48 | yes |
| 118 | `project/app.py` | 85 | yes |
| 122 | `project/app.py` | 100 | yes |
| 122 | `project/app.py` | 45-53 | yes |
| 123 | `project/app.py` | 66-67 | yes |
| 124 | `project/app.py` | 115-121 | yes |
| 124 | `project/app.py` | 56-60 | yes |
| 124 | `project/app.py` | 75-88 | yes |
| 124 | `project/app.py` | 91-96 | yes |
| 125 | `project/templates/index.html` | 19 | yes |
| 125 | `project/templates/index.html` | 35 | yes |
| 126 | `create_db.py` | 7-12 | yes |
| 132 | `project/app.py` | 56-60 | yes |
| 132 | `project/app.py` | 56-60 | yes |
| 133 | `project/app.py` | 66-72 | yes |
| 134 | `project/app.py` | 75-88 | yes |
| 134 | `project/app.py` | 91-96 | yes |
| 135 | `project/app.py` | 99-112 | yes |
| 136 | `project/app.py` | 115-121 | yes |
| 136 | `project/app.py` | 115-121 | yes |
| 138 | `project/app.py` | 56-125 | yes |
| 144 | `project/templates/index.html` | 1 | yes |
| 148 | `project/app.py` | 56-60 | yes |
| 148 | `project/app.py` | 72 | yes |
| 148 | `project/app.py` | 87 | yes |
| 148 | `project/app.py` | 96 | yes |
| 148 | `project/templates/index.html` | 17-77 | yes |
| 148 | `project/templates/index.html` | 35 | yes |
| 148 | `project/templates/index.html` | 73-74 | yes |
| 148 | `project/templates/index.html` | 77 | yes |
| 148 | `project/templates/search.html` | 17-19 | yes |
| 149 | `project/app.py` | 75-88 | yes |
| 149 | `project/app.py` | 75-88 | yes |
| 149 | `project/app.py` | 81 | yes |
| 149 | `project/app.py` | 83 | yes |
| 149 | `project/templates/index.html` | 19-22 | yes |
| 149 | `project/templates/login.html` | 25-53 | yes |
| 149 | `project/templates/search.html` | 21-24 | yes |
| 150 | `project/app.py` | 115-121 | yes |
| 150 | `project/app.py` | 115-121 | yes |
| 150 | `project/app.py` | 119-121 | yes |
| 150 | `project/templates/index.html` | 17 | yes |
| 150 | `project/templates/search.html` | 39-57 | yes |
| 150 | `project/templates/search.html` | 54 | yes |
| 152 | `project/templates/index.html` | 1 | yes |
| 152 | `project/templates/login.html` | 1 | yes |
| 152 | `project/templates/search.html` | 1 | yes |
| 158 | `project/app.py` | 56-60 | yes |
| 159 | `project/templates/index.html` | 72-77 | yes |
| 160 | `project/templates/index.html` | 31-35 | yes |
| 162 | `project/app.py` | 26 | yes |
| 162 | `project/app.py` | 56-60 | yes |
| 166 | `project/app.py` | 88 | yes |
| 167 | `project/app.py` | 80-83 | yes |
| 168 | `project/app.py` | 84-87 | yes |
| 169 | `project/app.py` | 91-96 | yes |
| 170 | `tests/app_test.py` | 55-64 | yes |
| 172 | `project/app.py` | 23-24 | yes |
| 172 | `project/app.py` | 80-88 | yes |
| 176 | `project/templates/index.html` | 35-36 | yes |
| 177 | `project/app.py` | 66-67 | yes |
| 178 | `project/app.py` | 68-72 | yes |
| 179 | `tests/app_test.py` | 67-77 | yes |
| 181 | `project/app.py` | 68 | yes |
| 181 | `project/app.py` | 70 | yes |
| 185 | `project/static/main.js` | 7-11 | yes |
| 186 | `project/app.py` | 48-50 | yes |
| 187 | `project/app.py` | 106-109 | yes |
| 187 | `project/app.py` | 112 | yes |
| 188 | `project/static/main.js` | 15-20 | yes |
| 189 | `tests/app_test.py` | 80-88 | yes |
| 191 | `project/app.py` | 106-109 | yes |
| 191 | `project/app.py` | 110-112 | yes |
| 191 | `project/static/main.js` | 20 | yes |
| 195 | `project/templates/search.html` | 39 | yes |
| 196 | `project/app.py` | 117-121 | yes |
| 197 | `project/templates/search.html` | 51-52 | yes |
| 199 | `project/templates/search.html` | 50-57 | yes |
| 203 | `create_db.py` |  | yes |
| 203 | `create_db.py` | 7-12 | yes |
| 204 | `README.md` | 1717 | yes |
| 206 | `create_db.py` | 7-12 | yes |
| 206 | `project/app.py` | 26 | yes |
| 214 | `create_db.py` | 7-12 | yes |
| 214 | `project/app.py` | 106-107 | yes |
| 214 | `project/app.py` | 118 | yes |
| 214 | `project/app.py` | 22-31 | yes |
| 214 | `project/app.py` | 40 | yes |
| 214 | `project/app.py` | 59 | yes |
| 214 | `project/app.py` | 69-70 | yes |
| 214 | `project/app.py` | 75-96 | yes |
| 218 | `project/app.py` | 106 | yes |
| 218 | `project/app.py` | 59 | yes |
| 218 | `project/models.py` | 4-8 | yes |
| 224 | `project/templates/index.html` | 5-9 | yes |
| 224 | `project/templates/login.html` | 5-9 | yes |
| 224 | `project/templates/search.html` | 5-9 | yes |
| 230 | `project/models.py` | 4-7 | yes |
| 230 | `project/templates/index.html` | 74 | yes |
| 236 | `project/models.py` | 5 | yes |
| 237 | `project/models.py` | 6 | yes |
| 238 | `project/models.py` | 7 | yes |
| 240 | `.gitignore` |  | yes |
| 240 | `.gitignore` | 5 | yes |
| 240 | `project/flaskr.db` |  | yes |
| 240 | `project/flaskr.db` |  | yes |
| 246 | `project/app.py` | 1-125 | yes |
| 246 | `project/app.py` | 110-112 | yes |
| 246 | `project/app.py` | 21-32 | yes |
| 247 | `project/static/main.js` | 1-3 | yes |
| 247 | `project/static/main.js` | 18 | yes |
| 247 | `project/static/main.js` | 23 | yes |
| 247 | `project/templates/index.html` | 5-9 | yes |
| 247 | `project/templates/index.html` | 5-9 | yes |
| 253 | `project/app.py` | 25 | yes |
| 253 | `project/app.py` | 48 | yes |
| 253 | `project/app.py` | 75-88 | yes |
| 254 | `project/app.py` | 66-67 | yes |
| 255 | `project/app.py` | 80-83 | yes |
| 256 | `project/app.py` | 71-72 | yes |
| 257 | `project/app.py` | 110-112 | yes |
| 257 | `project/app.py` | 26-32 | yes |
| 258 | `project/models.py` | 5 | yes |
| 258 | `project/templates/index.html` | 73 | yes |
| 258 | `project/templates/search.html` | 54 | yes |
| 259 | `project/templates/index.html` | 77 | yes |
| 260 | `project/app.py` | 109 | yes |
| 260 | `project/app.py` | 49 | yes |
| 268 | `project/app.py` | 24 | yes |
| 268 | `project/app.py` | 26 | yes |
| 268 | `project/app.py` | 80 | yes |
| 268 | `project/templates/login.html` | 53 | yes |
| 269 | `project/app.py` | 25 | yes |
| 269 | `project/app.py` | 48 | yes |
| 269 | `project/app.py` | 66 | yes |
| 269 | `project/app.py` | 85 | yes |
| 270 | `project/templates/index.html` | 74 | yes |
| 270 | `project/templates/search.html` | 55 | yes |
| 270 | `tests/app_test.py` | 77 | yes |
| 270 | `tests/app_test.py` | 77 | yes |
| 271 | `project/app.py` | 21-32 | yes |
| 271 | `project/app.py` | 99 | yes |
| 271 | `project/static/main.js` | 7-11 | yes |
| 271 | `project/templates/index.html` | 36 | yes |
| 271 | `requirements.txt` | 1-4 | yes |
| 272 | `project/app.py` | 23 | yes |
| 272 | `project/app.py` | 81 | yes |
| 272 | `project/app.py` | 83 | yes |
| 272 | `project/templates/login.html` | 53 | yes |
| 273 | `project/app.py` | 111-112 | yes |
| 274 | `project/models.py` | 5 | yes |
| 274 | `project/templates/search.html` | 54 | yes |
| 275 | `project/app.py` | 118-120 | yes |
| 275 | `project/app.py` | 59 | yes |
| 275 | `project/templates/search.html` | 51-52 | yes |
| 276 | `project/app.py` | 22 | yes |
| 276 | `project/app.py` | 26 | yes |
| 276 | `project/app.py` | 40 | yes |
| 276 | `tests/app_test.py` | 13-21 | yes |
| 276 | `tests/app_test.py` | 43-46 | yes |
| 277 | `.gitignore` | 5 | yes |
| 277 | `project/flaskr.db` |  | yes |
| 277 | `project/models.py` | 4-8 | yes |
| 283 | `Procfile` | 1 | yes |
| 283 | `project/app.py` | 21-32 | yes |
| 284 | `project/templates/index.html` | 36-70 | yes |
| 284 | `project/templates/login.html` | 31-50 | yes |
| 284 | `requirements.txt` | 1-8 | yes |
| 285 | `project/app.py` | 75-88 | yes |
| 286 | `project/app.py` | 21-32 | yes |
| 287 | `project/app.py` | 75-88 | yes |
| 287 | `requirements.txt` | 1-8 | yes |
| 288 | `project/app.py` | 1-125 | yes |
| 289 | `Procfile` | 1 | yes |
| 289 | `project/models.py` | 1-14 | yes |
| 290 | `project/app.py` | 23-26 | yes |
| 300 | `README.md` | 3 | yes |
| 301 | `.github/workflows/main.yml` | 19-29 | yes |
| 301 | `.github/workflows/main.yml` | 3 | yes |
| 302 | `tests/app_test.py` |  | yes |
| 302 | `tests/app_test.py` | 38-52 | yes |
| 302 | `tests/app_test.py` | 55-64 | yes |
| 302 | `tests/app_test.py` | 67-77 | yes |
| 302 | `tests/app_test.py` | 80-88 | yes |
| 304 | `project/app.py` | 40 | yes |
| 304 | `project/flaskr.db` |  | yes |
| 304 | `project/flaskr.db` |  | yes |
| 304 | `tests/app_test.py` | 13-16 | yes |
| 304 | `tests/app_test.py` | 19-21 | yes |
| 304 | `tests/app_test.py` | 43-46 | yes |
| 308 | `project/app.py` | 23-25 | yes |
| 309 | `.github/workflows/main.yml` | 23-29 | yes |
| 310 | `tests/app_test.py` | 1-88 | yes |
| 328 | `project/app.py` | 75-87 | yes |
| 328 | `project/app.py` | 99-112 | yes |
| 328 | `project/static/main.js` | 7-20 | yes |
| 339 | `project/models.py` | 4-7 | yes |
| 345 | `project/templates/index.html` | 72-77 | yes |
| 346 | `project/models.py` | 4-7 | yes |
| 347 | `project/app.py` | 48 | yes |
| 348 | `project/app.py` | 45-53 | yes |
| 349 | `project/app.py` | 49 | yes |
| 349 | `project/templates/index.html` | 31-35 | yes |
| 350 | `project/app.py` | 26 | yes |
| 351 | `project/app.py` | 25 | yes |
| 352 | `project/app.py` | 38 | yes |
| 353 | `Procfile` | 1 | yes |
| 354 | `create_db.py` |  | yes |
| 354 | `create_db.py` | 7-12 | yes |
| 361 | `.github/workflows/main.yml` | 1-29 | yes |
| 362 | `project/app.py` | 23-25 | yes |
| 363 | `project/app.py` | 21-32 | yes |
| 364 | `project/app.py` | 106-107 | yes |
| 379 | `create_db.py` |  | yes |
| 379 | `project/flaskr.db` |  | yes |
| 383 | `LICENSE` |  | yes |
| 389 | `.github/workflows/main.yml` | 11 | yes |
| 389 | `runtime.txt` | 1 | yes |
| 390 | `requirements.txt` | 1-4 | yes |
| 390 | `requirements.txt` | 6-8 | yes |
| 391 | `Procfile` | 1 | yes |
| 395 | `project/` |  | yes |
| 395 | `project/app.py` | 22 | yes |
| 395 | `project/app.py` | 26 | yes |
| 395 | `project/app.py` | 26-31 | yes |
| 396 | `create_db.py` |  | yes |
| 396 | `create_db.py` | 7-12 | yes |
| 396 | `project/flaskr.db` |  | yes |
| 396 | `requirements.txt` | 1-8 | yes |
| 396 | `tests/app_test.py` | 19-21 | yes |
| 400 | `project/app.py` | 21-32 | yes |
| 400 | `project/app.py` | 85 | yes |
| 400 | `project/app.py` | 94 | yes |
| 400 | `project/app.py` | 94 | yes |
| 406 | `create_db.py` |  | yes |
| 406 | `create_db.py` | 7-12 | yes |
| 406 | `project/app.py` | 110-112 | yes |
| 406 | `project/app.py` | 118-120 | yes |
| 406 | `project/app.py` | 26 | yes |
| 406 | `project/app.py` | 59-60 | yes |
| 406 | `project/app.py` | 69-70 | yes |
| 406 | `project/app.py` | 75-96 | yes |
| 407 | `project/app.py` | 110-112 | yes |
| 408 | `project/app.py` | 25 | yes |
| 408 | `project/app.py` | 50 | yes |
| 408 | `project/app.py` | 67 | yes |
| 409 | `project/app.py` | 28-29 | yes |
| 415 | `.github/workflows/main.yml` | 19-22 | yes |
| 416 | `.github/workflows/main.yml` | 23-29 | yes |
| 417 | `Procfile` | 1 | yes |
| 417 | `README.md` | 1082-1083 | yes |
| 422 | `project/app.py` | 23-25 | yes |
| 429 | `project/app.py` | 24 | yes |
| 430 | `project/app.py` | 25 | yes |
| 431 | `project/app.py` | 22 | yes |
| 432 | `project/app.py` | 23 | yes |
| 433 | `project/app.py` | 31 | yes |
| 434 | `project/app.py` | 32 | yes |
| 443 | `project/app.py` | 80 | yes |
| 444 | `project/app.py` | 82 | yes |
| 445 | `project/app.py` | 25 | yes |
| 446 | `project/app.py` | 26 | yes |
| 447 | `project/app.py` | 22 | yes |

## Verification

**Source-to-claim audit:** performed (auditor: independent). 91 rows: 80 Supported, 7 Corrected, 1 Downgraded, 1 Dismissed, 2 Answerable.

| Section | IDs with a register row |
|---|---|
| 4 | 8 of 8 |
| 6 | 3 of 3 |
| 8.1 | 1 of 1 |
| 8.3 | 1 of 1 |
| 10.1 | 10 of 10 |
| 14 | 5 of 5 |
| 15 | 5 of 10 |
| 7 (workflows) | 6 of 6 |
