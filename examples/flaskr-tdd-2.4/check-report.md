# Check: PASS

**Scope.** Run by AppDoc 2.4.0. This Check verifies **resolution and structure**: every Citation points to a real file and line inside the Target (see the Citation register), and every Evidence Register row's anchor text appears in the lines it cites. It does **not** judge whether a claim's wording follows from those lines; that is the source-to-claim audit, recorded in `evidence.jsonl`. A PASS is not an accuracy certification.

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
| 46 | `docs/appdoc-2.2-seeded/` |  | yes |
| 47 | `docs/appdoc-2.2/` |  | yes |
| 52 | `README.md` | 3 | yes |
| 52 | `project/app.py` | 56-112 | yes |
| 56 | `project/app.py` | 1-125 | yes |
| 56 | `project/app.py` | 26-32 | yes |
| 56 | `project/app.py` | 36-40 | yes |
| 56 | `project/models.py` | 4-8 | yes |
| 56 | `project/templates/index.html` | 5-9 | yes |
| 62 | `project/app.py` |  | yes |
| 62 | `project/app.py` | 36-125 | yes |
| 63 | `project/models.py` |  | yes |
| 63 | `project/models.py` | 4-8 | yes |
| 64 | `project/templates/` |  | yes |
| 64 | `project/templates/index.html` | 1-86 | yes |
| 64 | `project/templates/login.html` | 1-62 | yes |
| 64 | `project/templates/search.html` | 1-65 | yes |
| 65 | `project/static/main.js` |  | yes |
| 65 | `project/static/main.js` | 5-24 | yes |
| 66 | `create_db.py` |  | yes |
| 66 | `create_db.py` | 7-12 | yes |
| 67 | `tests/app_test.py` |  | yes |
| 67 | `tests/app_test.py` | 1-88 | yes |
| 68 | `Procfile` |  | yes |
| 68 | `Procfile` | 1 | yes |
| 83 | `project/app.py` | 56-125 | yes |
| 83 | `project/static/main.js` | 11 | yes |
| 83 | `project/templates/index.html` | 5-9 | yes |
| 87 | `project/app.py` | 100 | yes |
| 87 | `project/app.py` | 45-53 | yes |
| 87 | `project/app.py` | 66-67 | yes |
| 87 | `project/app.py` | 75-87 | yes |
| 87 | `project/models.py` | 4-14 | yes |
| 101 | `project/app.py` | 56-60 | yes |
| 101 | `project/models.py` | 4 | yes |
| 101 | `project/templates/index.html` | 72-77 | yes |
| 102 | `project/app.py` | 63-72 | yes |
| 102 | `project/app.py` | 66-72 | yes |
| 103 | `project/app.py` | 23-24 | yes |
| 103 | `project/app.py` | 75-88 | yes |
| 103 | `project/app.py` | 80-83 | yes |
| 104 | `project/app.py` | 91-96 | yes |
| 104 | `project/app.py` | 91-96 | yes |
| 105 | `project/app.py` | 103-112 | yes |
| 105 | `project/app.py` | 99-112 | yes |
| 106 | `project/app.py` | 115-121 | yes |
| 106 | `project/app.py` | 117-120 | yes |
| 106 | `project/templates/search.html` | 51-52 | yes |
| 107 | `project/static/main.js` | 7-20 | yes |
| 107 | `project/static/main.js` | 7-21 | yes |
| 108 | `create_db.py` | 7-12 | yes |
| 108 | `create_db.py` | 7-12 | yes |
| 114 | `docs/` |  | yes |
| 114 | `docs/` |  | yes |
| 115 | `Procfile` |  | yes |
| 115 | `README.md` |  | yes |
| 115 | `create_db.py` |  | yes |
| 115 | `requirements.txt` |  | yes |
| 115 | `requirements.txt` | 1-8 | yes |
| 115 | `runtime.txt` |  | yes |
| 115 | `runtime.txt` | 1 | yes |
| 116 | `project/` |  | yes |
| 116 | `requirements.txt` | 1-2 | yes |
| 117 | `.github/` |  | yes |
| 117 | `.github/workflows/main.yml` | 1-29 | yes |
| 118 | `project/flaskr.db` |  | yes |
| 118 | `tests/` |  | yes |
| 118 | `tests/app_test.py` | 1-88 | yes |
| 124 | `project/app.py` | 21-125 | yes |
| 124 | `project/app.py` | 23-24 | yes |
| 124 | `project/app.py` | 48 | yes |
| 124 | `project/app.py` | 85 | yes |
| 128 | `project/app.py` | 100 | yes |
| 128 | `project/app.py` | 45-53 | yes |
| 129 | `project/app.py` | 66-67 | yes |
| 130 | `project/app.py` | 115-121 | yes |
| 130 | `project/app.py` | 56-60 | yes |
| 130 | `project/app.py` | 75-88 | yes |
| 130 | `project/app.py` | 91-96 | yes |
| 131 | `project/templates/index.html` | 19 | yes |
| 131 | `project/templates/index.html` | 35 | yes |
| 132 | `create_db.py` | 7-12 | yes |
| 138 | `project/app.py` | 56-60 | yes |
| 138 | `project/app.py` | 56-60 | yes |
| 139 | `project/app.py` | 66-72 | yes |
| 140 | `project/app.py` | 75-88 | yes |
| 140 | `project/app.py` | 91-96 | yes |
| 141 | `project/app.py` | 99-112 | yes |
| 142 | `project/app.py` | 115-121 | yes |
| 142 | `project/app.py` | 115-121 | yes |
| 144 | `project/app.py` | 56-125 | yes |
| 150 | `project/templates/index.html` | 1 | yes |
| 154 | `project/app.py` | 56-60 | yes |
| 154 | `project/app.py` | 72 | yes |
| 154 | `project/app.py` | 87 | yes |
| 154 | `project/app.py` | 96 | yes |
| 154 | `project/templates/index.html` | 17-77 | yes |
| 154 | `project/templates/index.html` | 35 | yes |
| 154 | `project/templates/index.html` | 73-74 | yes |
| 154 | `project/templates/index.html` | 77 | yes |
| 154 | `project/templates/search.html` | 17-19 | yes |
| 155 | `project/app.py` | 75-88 | yes |
| 155 | `project/app.py` | 75-88 | yes |
| 155 | `project/app.py` | 81 | yes |
| 155 | `project/app.py` | 83 | yes |
| 155 | `project/templates/index.html` | 19-22 | yes |
| 155 | `project/templates/login.html` | 25-53 | yes |
| 155 | `project/templates/search.html` | 21-24 | yes |
| 156 | `project/app.py` | 115-121 | yes |
| 156 | `project/app.py` | 115-121 | yes |
| 156 | `project/app.py` | 119-121 | yes |
| 156 | `project/templates/index.html` | 17 | yes |
| 156 | `project/templates/search.html` | 39-57 | yes |
| 156 | `project/templates/search.html` | 54 | yes |
| 158 | `project/templates/index.html` | 1 | yes |
| 158 | `project/templates/login.html` | 1 | yes |
| 158 | `project/templates/search.html` | 1 | yes |
| 164 | `project/app.py` | 56-60 | yes |
| 165 | `project/templates/index.html` | 72-77 | yes |
| 166 | `project/templates/index.html` | 31-35 | yes |
| 168 | `project/app.py` | 26 | yes |
| 168 | `project/app.py` | 56-60 | yes |
| 172 | `project/app.py` | 88 | yes |
| 173 | `project/app.py` | 80-83 | yes |
| 174 | `project/app.py` | 84-87 | yes |
| 175 | `project/app.py` | 91-96 | yes |
| 176 | `tests/app_test.py` | 55-64 | yes |
| 178 | `project/app.py` | 23-24 | yes |
| 178 | `project/app.py` | 80-88 | yes |
| 182 | `project/templates/index.html` | 35-36 | yes |
| 183 | `project/app.py` | 66-67 | yes |
| 184 | `project/app.py` | 68-72 | yes |
| 185 | `tests/app_test.py` | 67-77 | yes |
| 187 | `project/app.py` | 68 | yes |
| 187 | `project/app.py` | 70 | yes |
| 191 | `project/static/main.js` | 7-11 | yes |
| 192 | `project/app.py` | 48-50 | yes |
| 193 | `project/app.py` | 106-109 | yes |
| 193 | `project/app.py` | 112 | yes |
| 194 | `project/static/main.js` | 15-20 | yes |
| 195 | `tests/app_test.py` | 80-88 | yes |
| 197 | `project/app.py` | 106-109 | yes |
| 197 | `project/app.py` | 110-112 | yes |
| 197 | `project/static/main.js` | 20 | yes |
| 201 | `project/templates/search.html` | 39 | yes |
| 202 | `project/app.py` | 117-121 | yes |
| 203 | `project/templates/search.html` | 51-52 | yes |
| 205 | `project/templates/search.html` | 50-57 | yes |
| 209 | `create_db.py` |  | yes |
| 209 | `create_db.py` | 7-12 | yes |
| 210 | `README.md` | 1717 | yes |
| 212 | `create_db.py` | 7-12 | yes |
| 212 | `project/app.py` | 26 | yes |
| 220 | `create_db.py` | 7-12 | yes |
| 220 | `project/app.py` | 106-107 | yes |
| 220 | `project/app.py` | 118 | yes |
| 220 | `project/app.py` | 22-31 | yes |
| 220 | `project/app.py` | 40 | yes |
| 220 | `project/app.py` | 59 | yes |
| 220 | `project/app.py` | 69-70 | yes |
| 220 | `project/app.py` | 75-96 | yes |
| 224 | `project/app.py` | 106 | yes |
| 224 | `project/app.py` | 59 | yes |
| 224 | `project/models.py` | 4-8 | yes |
| 230 | `project/templates/index.html` | 5-9 | yes |
| 230 | `project/templates/login.html` | 5-9 | yes |
| 230 | `project/templates/search.html` | 5-9 | yes |
| 236 | `project/models.py` | 4-7 | yes |
| 236 | `project/templates/index.html` | 74 | yes |
| 242 | `project/models.py` | 5 | yes |
| 243 | `project/models.py` | 6 | yes |
| 244 | `project/models.py` | 7 | yes |
| 246 | `.gitignore` |  | yes |
| 246 | `.gitignore` | 5 | yes |
| 246 | `project/flaskr.db` |  | yes |
| 246 | `project/flaskr.db` |  | yes |
| 252 | `project/app.py` | 1-125 | yes |
| 252 | `project/app.py` | 110-112 | yes |
| 252 | `project/app.py` | 21-32 | yes |
| 253 | `project/static/main.js` | 1-3 | yes |
| 253 | `project/static/main.js` | 18 | yes |
| 253 | `project/static/main.js` | 23 | yes |
| 253 | `project/templates/index.html` | 5-9 | yes |
| 253 | `project/templates/index.html` | 5-9 | yes |
| 259 | `project/app.py` | 25 | yes |
| 259 | `project/app.py` | 48 | yes |
| 259 | `project/app.py` | 75-88 | yes |
| 260 | `project/app.py` | 66-67 | yes |
| 261 | `project/app.py` | 80-83 | yes |
| 262 | `project/app.py` | 71-72 | yes |
| 263 | `project/app.py` | 110-112 | yes |
| 263 | `project/app.py` | 26-32 | yes |
| 264 | `project/models.py` | 5 | yes |
| 264 | `project/templates/index.html` | 73 | yes |
| 264 | `project/templates/search.html` | 54 | yes |
| 265 | `project/templates/index.html` | 77 | yes |
| 266 | `project/app.py` | 109 | yes |
| 266 | `project/app.py` | 49 | yes |
| 274 | `project/app.py` | 24 | yes |
| 274 | `project/app.py` | 26 | yes |
| 274 | `project/app.py` | 80 | yes |
| 274 | `project/templates/login.html` | 53 | yes |
| 275 | `project/app.py` | 25 | yes |
| 275 | `project/app.py` | 48 | yes |
| 275 | `project/app.py` | 66 | yes |
| 275 | `project/app.py` | 85 | yes |
| 276 | `project/templates/index.html` | 74 | yes |
| 276 | `project/templates/search.html` | 55 | yes |
| 276 | `tests/app_test.py` | 77 | yes |
| 276 | `tests/app_test.py` | 77 | yes |
| 277 | `project/app.py` | 21-32 | yes |
| 277 | `project/app.py` | 99 | yes |
| 277 | `project/static/main.js` | 7-11 | yes |
| 277 | `project/templates/index.html` | 36 | yes |
| 277 | `requirements.txt` | 1-4 | yes |
| 278 | `project/app.py` | 23 | yes |
| 278 | `project/app.py` | 81 | yes |
| 278 | `project/app.py` | 83 | yes |
| 278 | `project/templates/login.html` | 53 | yes |
| 279 | `project/app.py` | 111-112 | yes |
| 280 | `project/models.py` | 5 | yes |
| 280 | `project/templates/search.html` | 54 | yes |
| 281 | `project/app.py` | 118-120 | yes |
| 281 | `project/app.py` | 59 | yes |
| 281 | `project/templates/search.html` | 51-52 | yes |
| 282 | `project/app.py` | 22 | yes |
| 282 | `project/app.py` | 26 | yes |
| 282 | `project/app.py` | 40 | yes |
| 282 | `tests/app_test.py` | 13-21 | yes |
| 282 | `tests/app_test.py` | 43-46 | yes |
| 283 | `.gitignore` | 5 | yes |
| 283 | `project/flaskr.db` |  | yes |
| 283 | `project/models.py` | 4-8 | yes |
| 289 | `Procfile` | 1 | yes |
| 289 | `project/app.py` | 21-32 | yes |
| 290 | `project/templates/index.html` | 36-70 | yes |
| 290 | `project/templates/login.html` | 31-50 | yes |
| 290 | `requirements.txt` | 1-8 | yes |
| 291 | `project/app.py` | 75-88 | yes |
| 292 | `project/app.py` | 21-32 | yes |
| 293 | `project/app.py` | 75-88 | yes |
| 293 | `requirements.txt` | 1-8 | yes |
| 294 | `project/app.py` | 1-125 | yes |
| 295 | `Procfile` | 1 | yes |
| 295 | `project/models.py` | 1-14 | yes |
| 296 | `project/app.py` | 23-26 | yes |
| 306 | `README.md` | 3 | yes |
| 307 | `.github/workflows/main.yml` | 19-29 | yes |
| 307 | `.github/workflows/main.yml` | 3 | yes |
| 308 | `tests/app_test.py` |  | yes |
| 308 | `tests/app_test.py` | 38-52 | yes |
| 308 | `tests/app_test.py` | 55-64 | yes |
| 308 | `tests/app_test.py` | 67-77 | yes |
| 308 | `tests/app_test.py` | 80-88 | yes |
| 310 | `project/app.py` | 40 | yes |
| 310 | `project/flaskr.db` |  | yes |
| 310 | `project/flaskr.db` |  | yes |
| 310 | `tests/app_test.py` | 13-16 | yes |
| 310 | `tests/app_test.py` | 19-21 | yes |
| 310 | `tests/app_test.py` | 43-46 | yes |
| 314 | `project/app.py` | 23-25 | yes |
| 315 | `.github/workflows/main.yml` | 23-29 | yes |
| 316 | `tests/app_test.py` | 1-88 | yes |
| 334 | `project/app.py` | 75-87 | yes |
| 334 | `project/app.py` | 99-112 | yes |
| 334 | `project/static/main.js` | 7-20 | yes |
| 345 | `project/models.py` | 4-7 | yes |
| 351 | `project/templates/index.html` | 72-77 | yes |
| 352 | `project/models.py` | 4-7 | yes |
| 353 | `project/app.py` | 48 | yes |
| 354 | `project/app.py` | 45-53 | yes |
| 355 | `project/app.py` | 49 | yes |
| 355 | `project/templates/index.html` | 31-35 | yes |
| 356 | `project/app.py` | 26 | yes |
| 357 | `project/app.py` | 25 | yes |
| 358 | `project/app.py` | 38 | yes |
| 359 | `Procfile` | 1 | yes |
| 360 | `create_db.py` |  | yes |
| 360 | `create_db.py` | 7-12 | yes |
| 367 | `.github/workflows/main.yml` | 1-29 | yes |
| 368 | `project/app.py` | 23-25 | yes |
| 369 | `project/app.py` | 21-32 | yes |
| 370 | `project/app.py` | 106-107 | yes |
| 385 | `create_db.py` |  | yes |
| 385 | `project/flaskr.db` |  | yes |
| 389 | `LICENSE` |  | yes |
| 389 | `docs/` |  | yes |
| 395 | `.github/workflows/main.yml` | 11 | yes |
| 395 | `runtime.txt` | 1 | yes |
| 396 | `requirements.txt` | 1-4 | yes |
| 396 | `requirements.txt` | 6-8 | yes |
| 397 | `Procfile` | 1 | yes |
| 401 | `project/` |  | yes |
| 401 | `project/app.py` | 22 | yes |
| 401 | `project/app.py` | 26 | yes |
| 401 | `project/app.py` | 26-31 | yes |
| 402 | `create_db.py` |  | yes |
| 402 | `create_db.py` | 7-12 | yes |
| 402 | `project/flaskr.db` |  | yes |
| 402 | `requirements.txt` | 1-8 | yes |
| 402 | `tests/app_test.py` | 19-21 | yes |
| 406 | `project/app.py` | 21-32 | yes |
| 406 | `project/app.py` | 85 | yes |
| 406 | `project/app.py` | 94 | yes |
| 406 | `project/app.py` | 94 | yes |
| 412 | `create_db.py` |  | yes |
| 412 | `create_db.py` | 7-12 | yes |
| 412 | `project/app.py` | 110-112 | yes |
| 412 | `project/app.py` | 118-120 | yes |
| 412 | `project/app.py` | 26 | yes |
| 412 | `project/app.py` | 59-60 | yes |
| 412 | `project/app.py` | 69-70 | yes |
| 412 | `project/app.py` | 75-96 | yes |
| 413 | `project/app.py` | 110-112 | yes |
| 414 | `project/app.py` | 25 | yes |
| 414 | `project/app.py` | 50 | yes |
| 414 | `project/app.py` | 67 | yes |
| 415 | `project/app.py` | 28-29 | yes |
| 421 | `.github/workflows/main.yml` | 19-22 | yes |
| 422 | `.github/workflows/main.yml` | 23-29 | yes |
| 423 | `Procfile` | 1 | yes |
| 423 | `README.md` | 1082-1083 | yes |
| 428 | `project/app.py` | 23-25 | yes |
| 435 | `project/app.py` | 24 | yes |
| 436 | `project/app.py` | 25 | yes |
| 437 | `project/app.py` | 22 | yes |
| 438 | `project/app.py` | 23 | yes |
| 439 | `project/app.py` | 26 | yes |
| 440 | `project/app.py` | 31 | yes |
| 441 | `project/app.py` | 32 | yes |
| 448 | `project/app.py` | 80 | yes |
| 449 | `project/app.py` | 82 | yes |
| 450 | `project/app.py` | 25 | yes |
| 451 | `project/app.py` | 26 | yes |
| 452 | `project/app.py` | 22 | yes |

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
