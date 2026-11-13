# Check: PASS

**Scope.** This Check verifies **resolution and structure**: every Citation points to a real file and line inside the Target (see the Citation register), and every Evidence Register row's anchor text appears in the lines it cites. It does **not** judge whether a claim's wording follows from those lines; that is the source-to-claim audit, recorded in `evidence.jsonl`. A PASS is not an accuracy certification.

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
| 38 | `docs/` |  | yes |
| 39 | `project/` |  | yes |
| 40 | `.github/` |  | yes |
| 41 | `tests/` |  | yes |
| 48 | `README.md` | 3 | yes |
| 48 | `project/app.py` | 56-112 | yes |
| 52 | `project/app.py` | 1-125 | yes |
| 52 | `project/app.py` | 26-32 | yes |
| 52 | `project/app.py` | 36-40 | yes |
| 52 | `project/models.py` | 4-8 | yes |
| 52 | `project/templates/index.html` | 5-9 | yes |
| 58 | `project/app.py` |  | yes |
| 58 | `project/app.py` | 36-125 | yes |
| 59 | `project/models.py` |  | yes |
| 59 | `project/models.py` | 4-8 | yes |
| 60 | `project/templates/` |  | yes |
| 60 | `project/templates/index.html` | 1-86 | yes |
| 60 | `project/templates/login.html` | 1-62 | yes |
| 60 | `project/templates/search.html` | 1-65 | yes |
| 61 | `project/static/main.js` |  | yes |
| 61 | `project/static/main.js` | 5-24 | yes |
| 62 | `create_db.py` |  | yes |
| 62 | `create_db.py` | 7-12 | yes |
| 63 | `tests/app_test.py` |  | yes |
| 63 | `tests/app_test.py` | 1-88 | yes |
| 64 | `Procfile` |  | yes |
| 64 | `Procfile` | 1 | yes |
| 79 | `project/app.py` | 56-125 | yes |
| 79 | `project/static/main.js` | 11 | yes |
| 79 | `project/templates/index.html` | 5-9 | yes |
| 83 | `project/app.py` | 100 | yes |
| 83 | `project/app.py` | 45-53 | yes |
| 83 | `project/app.py` | 66-67 | yes |
| 83 | `project/app.py` | 75-87 | yes |
| 83 | `project/models.py` | 4-14 | yes |
| 97 | `project/app.py` | 56-60 | yes |
| 97 | `project/models.py` | 4 | yes |
| 97 | `project/templates/index.html` | 72-77 | yes |
| 98 | `project/app.py` | 63-72 | yes |
| 98 | `project/app.py` | 66-72 | yes |
| 99 | `project/app.py` | 23-24 | yes |
| 99 | `project/app.py` | 75-88 | yes |
| 99 | `project/app.py` | 80-83 | yes |
| 100 | `project/app.py` | 91-96 | yes |
| 100 | `project/app.py` | 91-96 | yes |
| 101 | `project/app.py` | 103-112 | yes |
| 101 | `project/app.py` | 99-112 | yes |
| 102 | `project/app.py` | 115-121 | yes |
| 102 | `project/app.py` | 117-120 | yes |
| 102 | `project/templates/search.html` | 51-52 | yes |
| 103 | `project/static/main.js` | 7-20 | yes |
| 103 | `project/static/main.js` | 7-21 | yes |
| 104 | `create_db.py` | 7-12 | yes |
| 104 | `create_db.py` | 7-12 | yes |
| 110 | `docs/` |  | yes |
| 110 | `docs/` |  | yes |
| 111 | `Procfile` |  | yes |
| 111 | `README.md` |  | yes |
| 111 | `create_db.py` |  | yes |
| 111 | `requirements.txt` |  | yes |
| 111 | `requirements.txt` | 1-8 | yes |
| 111 | `runtime.txt` |  | yes |
| 111 | `runtime.txt` | 1 | yes |
| 112 | `project/` |  | yes |
| 112 | `requirements.txt` | 1-2 | yes |
| 113 | `.github/` |  | yes |
| 113 | `.github/workflows/main.yml` | 1-29 | yes |
| 114 | `project/flaskr.db` |  | yes |
| 114 | `tests/` |  | yes |
| 114 | `tests/app_test.py` | 1-88 | yes |
| 120 | `project/app.py` | 21-125 | yes |
| 120 | `project/app.py` | 23-24 | yes |
| 120 | `project/app.py` | 48 | yes |
| 120 | `project/app.py` | 85 | yes |
| 124 | `project/app.py` | 100 | yes |
| 124 | `project/app.py` | 45-53 | yes |
| 125 | `project/app.py` | 66-67 | yes |
| 126 | `project/app.py` | 115-121 | yes |
| 126 | `project/app.py` | 56-60 | yes |
| 126 | `project/app.py` | 75-88 | yes |
| 126 | `project/app.py` | 91-96 | yes |
| 127 | `project/templates/index.html` | 19 | yes |
| 127 | `project/templates/index.html` | 35 | yes |
| 128 | `create_db.py` | 7-12 | yes |
| 134 | `project/app.py` | 56-60 | yes |
| 134 | `project/app.py` | 56-60 | yes |
| 135 | `project/app.py` | 66-72 | yes |
| 136 | `project/app.py` | 75-88 | yes |
| 136 | `project/app.py` | 91-96 | yes |
| 137 | `project/app.py` | 99-112 | yes |
| 138 | `project/app.py` | 115-121 | yes |
| 138 | `project/app.py` | 115-121 | yes |
| 140 | `project/app.py` | 56-125 | yes |
| 146 | `project/templates/index.html` | 1 | yes |
| 150 | `project/app.py` | 56-60 | yes |
| 150 | `project/app.py` | 72 | yes |
| 150 | `project/app.py` | 87 | yes |
| 150 | `project/app.py` | 96 | yes |
| 150 | `project/templates/index.html` | 17-77 | yes |
| 150 | `project/templates/index.html` | 35 | yes |
| 150 | `project/templates/index.html` | 73-74 | yes |
| 150 | `project/templates/index.html` | 77 | yes |
| 150 | `project/templates/search.html` | 17-19 | yes |
| 151 | `project/app.py` | 75-88 | yes |
| 151 | `project/app.py` | 75-88 | yes |
| 151 | `project/app.py` | 81 | yes |
| 151 | `project/app.py` | 83 | yes |
| 151 | `project/templates/index.html` | 19-22 | yes |
| 151 | `project/templates/login.html` | 25-53 | yes |
| 151 | `project/templates/search.html` | 21-24 | yes |
| 152 | `project/app.py` | 115-121 | yes |
| 152 | `project/app.py` | 115-121 | yes |
| 152 | `project/app.py` | 119-121 | yes |
| 152 | `project/templates/index.html` | 17 | yes |
| 152 | `project/templates/search.html` | 39-57 | yes |
| 152 | `project/templates/search.html` | 54 | yes |
| 154 | `project/templates/index.html` | 1 | yes |
| 154 | `project/templates/login.html` | 1 | yes |
| 154 | `project/templates/search.html` | 1 | yes |
| 160 | `project/app.py` | 56-60 | yes |
| 161 | `project/templates/index.html` | 72-77 | yes |
| 162 | `project/templates/index.html` | 31-35 | yes |
| 164 | `project/app.py` | 26 | yes |
| 164 | `project/app.py` | 56-60 | yes |
| 168 | `project/app.py` | 88 | yes |
| 169 | `project/app.py` | 80-83 | yes |
| 170 | `project/app.py` | 84-87 | yes |
| 171 | `project/app.py` | 91-96 | yes |
| 172 | `tests/app_test.py` | 55-64 | yes |
| 174 | `project/app.py` | 23-24 | yes |
| 174 | `project/app.py` | 80-88 | yes |
| 178 | `project/templates/index.html` | 35-36 | yes |
| 179 | `project/app.py` | 66-67 | yes |
| 180 | `project/app.py` | 68-72 | yes |
| 181 | `tests/app_test.py` | 67-77 | yes |
| 183 | `project/app.py` | 68 | yes |
| 183 | `project/app.py` | 70 | yes |
| 187 | `project/static/main.js` | 7-11 | yes |
| 188 | `project/app.py` | 48-50 | yes |
| 189 | `project/app.py` | 106-109 | yes |
| 189 | `project/app.py` | 112 | yes |
| 190 | `project/static/main.js` | 15-20 | yes |
| 191 | `tests/app_test.py` | 80-88 | yes |
| 193 | `project/app.py` | 106-109 | yes |
| 193 | `project/app.py` | 110-112 | yes |
| 193 | `project/static/main.js` | 20 | yes |
| 197 | `project/templates/search.html` | 39 | yes |
| 198 | `project/app.py` | 117-121 | yes |
| 199 | `project/templates/search.html` | 51-52 | yes |
| 201 | `project/templates/search.html` | 50-57 | yes |
| 205 | `create_db.py` |  | yes |
| 205 | `create_db.py` | 7-12 | yes |
| 206 | `README.md` | 1717 | yes |
| 208 | `create_db.py` | 7-12 | yes |
| 208 | `project/app.py` | 26 | yes |
| 216 | `create_db.py` | 7-12 | yes |
| 216 | `project/app.py` | 106-107 | yes |
| 216 | `project/app.py` | 118 | yes |
| 216 | `project/app.py` | 22-31 | yes |
| 216 | `project/app.py` | 40 | yes |
| 216 | `project/app.py` | 59 | yes |
| 216 | `project/app.py` | 69-70 | yes |
| 216 | `project/app.py` | 75-96 | yes |
| 220 | `project/app.py` | 106 | yes |
| 220 | `project/app.py` | 59 | yes |
| 220 | `project/models.py` | 4-8 | yes |
| 226 | `project/templates/index.html` | 5-9 | yes |
| 226 | `project/templates/login.html` | 5-9 | yes |
| 226 | `project/templates/search.html` | 5-9 | yes |
| 232 | `project/models.py` | 4-7 | yes |
| 232 | `project/templates/index.html` | 74 | yes |
| 238 | `project/models.py` | 5 | yes |
| 239 | `project/models.py` | 6 | yes |
| 240 | `project/models.py` | 7 | yes |
| 242 | `.gitignore` |  | yes |
| 242 | `.gitignore` | 5 | yes |
| 242 | `project/flaskr.db` |  | yes |
| 242 | `project/flaskr.db` | 1 | yes |
| 242 | `test.db` | 1 | yes |
| 248 | `project/app.py` | 1-125 | yes |
| 248 | `project/app.py` | 110-112 | yes |
| 248 | `project/app.py` | 21-32 | yes |
| 249 | `project/static/main.js` | 1-3 | yes |
| 249 | `project/static/main.js` | 18 | yes |
| 249 | `project/static/main.js` | 23 | yes |
| 249 | `project/templates/index.html` | 5-9 | yes |
| 249 | `project/templates/index.html` | 5-9 | yes |
| 255 | `project/app.py` | 25 | yes |
| 255 | `project/app.py` | 48 | yes |
| 255 | `project/app.py` | 75-88 | yes |
| 256 | `project/app.py` | 66-67 | yes |
| 257 | `project/app.py` | 80-83 | yes |
| 258 | `project/app.py` | 71-72 | yes |
| 259 | `project/app.py` | 110-112 | yes |
| 259 | `project/app.py` | 26-32 | yes |
| 260 | `project/models.py` | 5 | yes |
| 260 | `project/templates/index.html` | 73 | yes |
| 260 | `project/templates/search.html` | 54 | yes |
| 261 | `project/templates/index.html` | 77 | yes |
| 262 | `project/app.py` | 109 | yes |
| 262 | `project/app.py` | 49 | yes |
| 270 | `project/app.py` | 24 | yes |
| 270 | `project/app.py` | 26 | yes |
| 270 | `project/app.py` | 80 | yes |
| 270 | `project/templates/login.html` | 53 | yes |
| 271 | `project/app.py` | 25 | yes |
| 271 | `project/app.py` | 48 | yes |
| 271 | `project/app.py` | 66 | yes |
| 271 | `project/app.py` | 85 | yes |
| 272 | `project/templates/index.html` | 74 | yes |
| 272 | `project/templates/search.html` | 55 | yes |
| 272 | `tests/app_test.py` | 77 | yes |
| 272 | `tests/app_test.py` | 77 | yes |
| 273 | `project/app.py` | 21-32 | yes |
| 273 | `project/app.py` | 99 | yes |
| 273 | `project/static/main.js` | 7-11 | yes |
| 273 | `project/templates/index.html` | 36 | yes |
| 273 | `requirements.txt` | 1-4 | yes |
| 274 | `project/app.py` | 23 | yes |
| 274 | `project/app.py` | 81 | yes |
| 274 | `project/app.py` | 83 | yes |
| 274 | `project/templates/login.html` | 53 | yes |
| 275 | `project/app.py` | 111-112 | yes |
| 276 | `project/models.py` | 5 | yes |
| 276 | `project/templates/search.html` | 54 | yes |
| 277 | `project/app.py` | 118-120 | yes |
| 277 | `project/app.py` | 59 | yes |
| 277 | `project/templates/search.html` | 51-52 | yes |
| 278 | `project/app.py` | 22 | yes |
| 278 | `project/app.py` | 26 | yes |
| 278 | `project/app.py` | 40 | yes |
| 278 | `tests/app_test.py` | 13-21 | yes |
| 278 | `tests/app_test.py` | 43-46 | yes |
| 279 | `.gitignore` | 5 | yes |
| 279 | `project/flaskr.db` | 1 | yes |
| 279 | `project/models.py` | 4-8 | yes |
| 279 | `test.db` | 1 | yes |
| 285 | `Procfile` | 1 | yes |
| 285 | `project/app.py` | 21-32 | yes |
| 286 | `project/templates/index.html` | 36-70 | yes |
| 286 | `project/templates/login.html` | 31-50 | yes |
| 286 | `requirements.txt` | 1-8 | yes |
| 287 | `project/app.py` | 75-88 | yes |
| 288 | `project/app.py` | 21-32 | yes |
| 289 | `project/app.py` | 75-88 | yes |
| 289 | `requirements.txt` | 1-8 | yes |
| 290 | `project/app.py` | 1-125 | yes |
| 291 | `Procfile` | 1 | yes |
| 291 | `project/models.py` | 1-14 | yes |
| 292 | `project/app.py` | 23-26 | yes |
| 302 | `README.md` | 3 | yes |
| 303 | `.github/workflows/main.yml` | 19-29 | yes |
| 303 | `.github/workflows/main.yml` | 3 | yes |
| 304 | `tests/app_test.py` |  | yes |
| 304 | `tests/app_test.py` | 38-52 | yes |
| 304 | `tests/app_test.py` | 55-64 | yes |
| 304 | `tests/app_test.py` | 67-77 | yes |
| 304 | `tests/app_test.py` | 80-88 | yes |
| 306 | `project/app.py` | 40 | yes |
| 306 | `project/flaskr.db` |  | yes |
| 306 | `project/flaskr.db` |  | yes |
| 306 | `tests/app_test.py` | 13-16 | yes |
| 306 | `tests/app_test.py` | 19-21 | yes |
| 306 | `tests/app_test.py` | 43-46 | yes |
| 310 | `project/app.py` | 23-25 | yes |
| 311 | `.github/workflows/main.yml` | 23-29 | yes |
| 312 | `tests/app_test.py` | 1-88 | yes |
| 330 | `project/app.py` | 75-87 | yes |
| 330 | `project/app.py` | 99-112 | yes |
| 330 | `project/static/main.js` | 7-20 | yes |
| 341 | `project/models.py` | 4-7 | yes |
| 347 | `project/templates/index.html` | 72-77 | yes |
| 348 | `project/models.py` | 4-7 | yes |
| 349 | `project/app.py` | 48 | yes |
| 350 | `project/app.py` | 45-53 | yes |
| 351 | `project/app.py` | 49 | yes |
| 351 | `project/templates/index.html` | 31-35 | yes |
| 352 | `project/app.py` | 26 | yes |
| 353 | `project/app.py` | 25 | yes |
| 354 | `project/app.py` | 38 | yes |
| 355 | `Procfile` | 1 | yes |
| 356 | `create_db.py` |  | yes |
| 356 | `create_db.py` | 7-12 | yes |
| 363 | `.github/workflows/main.yml` | 1-29 | yes |
| 364 | `project/app.py` | 23-25 | yes |
| 365 | `project/app.py` | 21-32 | yes |
| 366 | `project/app.py` | 106-107 | yes |
| 381 | `create_db.py` |  | yes |
| 381 | `project/flaskr.db` |  | yes |
| 385 | `LICENSE` |  | yes |
| 385 | `docs/` |  | yes |
| 391 | `.github/workflows/main.yml` | 11 | yes |
| 391 | `runtime.txt` | 1 | yes |
| 392 | `requirements.txt` | 1-4 | yes |
| 392 | `requirements.txt` | 6-8 | yes |
| 393 | `Procfile` | 1 | yes |
| 397 | `project/` |  | yes |
| 397 | `project/app.py` | 22 | yes |
| 397 | `project/app.py` | 26 | yes |
| 397 | `project/app.py` | 26-31 | yes |
| 398 | `create_db.py` |  | yes |
| 398 | `create_db.py` | 7-12 | yes |
| 398 | `project/flaskr.db` |  | yes |
| 398 | `requirements.txt` | 1-8 | yes |
| 398 | `tests/app_test.py` | 19-21 | yes |
| 402 | `project/app.py` | 21-32 | yes |
| 402 | `project/app.py` | 85 | yes |
| 402 | `project/app.py` | 94 | yes |
| 402 | `project/app.py` | 94 | yes |
| 408 | `create_db.py` |  | yes |
| 408 | `create_db.py` | 7-12 | yes |
| 408 | `project/app.py` | 110-112 | yes |
| 408 | `project/app.py` | 118-120 | yes |
| 408 | `project/app.py` | 26 | yes |
| 408 | `project/app.py` | 59-60 | yes |
| 408 | `project/app.py` | 69-70 | yes |
| 408 | `project/app.py` | 75-96 | yes |
| 409 | `project/app.py` | 110-112 | yes |
| 410 | `project/app.py` | 25 | yes |
| 410 | `project/app.py` | 50 | yes |
| 410 | `project/app.py` | 67 | yes |
| 411 | `project/app.py` | 28-29 | yes |
| 417 | `.github/workflows/main.yml` | 19-22 | yes |
| 418 | `.github/workflows/main.yml` | 23-29 | yes |
| 419 | `Procfile` | 1 | yes |
| 419 | `README.md` | 1082-1083 | yes |
| 424 | `project/app.py` | 23-25 | yes |
| 431 | `project/app.py` | 24 | yes |
| 432 | `project/app.py` | 25 | yes |
| 433 | `project/app.py` | 22 | yes |
| 434 | `project/app.py` | 23 | yes |
| 435 | `project/app.py` | 26 | yes |
| 436 | `project/app.py` | 31 | yes |
| 437 | `project/app.py` | 32 | yes |
| 444 | `project/app.py` | 80 | yes |
| 445 | `project/app.py` | 82 | yes |
| 446 | `project/app.py` | 25 | yes |
| 447 | `project/app.py` | 26 | yes |
| 448 | `project/app.py` | 22 | yes |

## Verification

**Source-to-claim audit:** performed (auditor: independent). 95 rows: 80 Supported, 11 Corrected, 1 Downgraded, 1 Dismissed, 2 Answerable.

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
