# Check: PASS

**Scope.** Run by AppDoc 2.7.1 (bundle bf8cdbec967b). This Check verifies **resolution and structure**: every Citation points to a real file and line inside the Target (see the Citation register), and every Evidence Register row's anchor text appears in the lines it cites. It does **not** judge whether a claim's wording follows from those lines; that is the source-to-claim audit, recorded in `evidence.jsonl`. A PASS is not an accuracy certification.

## Audit exclusions

The audit record declares sections the audit did not cover:

- 12: diagrams were not compared with source beyond their captions
- 16.6: generated configuration reference block is owned by the Check and fill, not audited
- 16.7: generated scheduled-jobs block is owned by the Check and fill, not audited
- 2.1: generated scan-coverage block is owned by the Check and fill, not audited
- 3.2: diagram was not compared with source beyond its caption

## Gaps declared: Unknown by absence
Advisory only; this is not a problem.

- deployment runbook is Unknown by absence (no appdoc-context.md); add one to fill section 16.5 Rollback, Backup and Restore

## Citation register

| Doc line | Cited path | Line/range | Resolved |
|---|---|---|---|
| 12 | `project/app.py` | 75-88 | yes |
| 12 | `project/templates/login.html` | 25-27 | yes |
| 13 | `project/app.py` | 63-72 | yes |
| 14 | `project/app.py` | 99-112 | yes |
| 14 | `project/static/main.js` | 8-20 | yes |
| 15 | `project/app.py` | 115-121 | yes |
| 15 | `project/templates/search.html` | 51-58 | yes |
| 16 | `create_db.py` | 7-12 | yes |
| 16 | `project/app.py` | 26-31 | yes |
| 17 | `project/app.py` | 22-25 | yes |
| 18 | `.github/workflows/main.yml` | 27-29 | yes |
| 18 | `tests/app_test.py` | 11-21 | yes |
| 24 | `.github/` |  | yes |
| 24 | `.github/workflows/main.yml` | 23-29 | yes |
| 24 | `Procfile` | 1 | yes |
| 24 | `README.md` |  | yes |
| 24 | `flaskr-app.png` |  | yes |
| 24 | `project/` |  | yes |
| 24 | `project/flaskr.db` |  | yes |
| 24 | `project/static/style.css` |  | yes |
| 24 | `tdd.png` |  | yes |
| 24 | `tests/` |  | yes |
| 35 | `project/` |  | yes |
| 36 | `.github/` |  | yes |
| 37 | `tests/` |  | yes |
| 44 | `README.md` | 3 | yes |
| 44 | `project/app.py` | 56-121 | yes |
| 49 | `README.md` | 1082-1083 | yes |
| 49 | `project/app.py` | 26-31 | yes |
| 49 | `project/app.py` | 36-40 | yes |
| 49 | `project/models.py` | 4-7 | yes |
| 49 | `project/static/main.js` | 1-26 | yes |
| 49 | `project/templates/index.html` |  | yes |
| 49 | `project/templates/index.html` | 8 | yes |
| 49 | `project/templates/login.html` |  | yes |
| 49 | `project/templates/search.html` |  | yes |
| 49 | `tests/app_test.py` | 1-88 | yes |
| 56 | `project/app.py` |  | yes |
| 56 | `project/app.py` | 21-32 | yes |
| 56 | `project/app.py` | 36-40 | yes |
| 56 | `project/app.py` | 45-53 | yes |
| 56 | `project/app.py` | 56-121 | yes |
| 57 | `project/models.py` |  | yes |
| 57 | `project/models.py` | 4-7 | yes |
| 58 | `project/static/main.js` |  | yes |
| 58 | `project/static/main.js` | 8-20 | yes |
| 58 | `project/templates/` |  | yes |
| 59 | `create_db.py` |  | yes |
| 59 | `create_db.py` | 7-9 | yes |
| 60 | `tests/app_test.py` |  | yes |
| 60 | `tests/app_test.py` | 11-88 | yes |
| 61 | `Procfile` |  | yes |
| 61 | `Procfile` | 1 | yes |
| 74 | `project/app.py` | 40 | yes |
| 74 | `project/models.py` | 4 | yes |
| 74 | `project/templates/index.html` | 8 | yes |
| 78 | `project/app.py` | 25 | yes |
| 78 | `project/app.py` | 48-50 | yes |
| 78 | `project/app.py` | 66-67 | yes |
| 78 | `project/app.py` | 80-83 | yes |
| 78 | `project/app.py` | 85 | yes |
| 78 | `project/app.py` | 94 | yes |
| 78 | `project/app.py` | 99-101 | yes |
| 92 | `project/app.py` | 56-60 | yes |
| 92 | `project/models.py` | 4 | yes |
| 92 | `project/templates/index.html` |  | yes |
| 92 | `project/templates/index.html` | 71-78 | yes |
| 93 | `project/app.py` | 63-72 | yes |
| 93 | `project/app.py` | 66-72 | yes |
| 93 | `project/models.py` | 4-11 | yes |
| 94 | `project/app.py` | 75-88 | yes |
| 94 | `project/app.py` | 80-87 | yes |
| 94 | `project/templates/login.html` |  | yes |
| 95 | `project/app.py` | 91-96 | yes |
| 95 | `project/app.py` | 94-96 | yes |
| 96 | `project/app.py` | 103-112 | yes |
| 96 | `project/app.py` | 99-112 | yes |
| 96 | `project/models.py` | 4 | yes |
| 96 | `project/static/main.js` |  | yes |
| 96 | `project/static/main.js` | 8-20 | yes |
| 97 | `project/app.py` | 115-121 | yes |
| 97 | `project/templates/search.html` |  | yes |
| 97 | `project/templates/search.html` | 51-52 | yes |
| 98 | `create_db.py` | 7-9 | yes |
| 98 | `create_db.py` | 9 | yes |
| 98 | `project/app.py` | 40 | yes |
| 102 | `create_db.py` | 7-9 | yes |
| 102 | `project/app.py` | 56-121 | yes |
| 106 | `project/` |  | yes |
| 106 | `project/app.py` | 36 | yes |
| 106 | `requirements.txt` | 1-2 | yes |
| 107 | `Procfile` | 1 | yes |
| 107 | `Procfile` | 1 | yes |
| 107 | `create_db.py` | 7-12 | yes |
| 107 | `requirements.txt` | 1-8 | yes |
| 108 | `requirements.txt` | 8 | yes |
| 108 | `tests/` |  | yes |
| 108 | `tests/app_test.py` | 38-88 | yes |
| 109 | `.github/` |  | yes |
| 109 | `.github/workflows/main.yml` | 1 | yes |
| 109 | `.github/workflows/main.yml` | 3-29 | yes |
| 115 | `project/app.py` | 23-24 | yes |
| 115 | `project/app.py` | 85 | yes |
| 115 | `project/templates/index.html` | 19-27 | yes |
| 115 | `project/templates/index.html` | 35 | yes |
| 119 | `project/app.py` | 115 | yes |
| 119 | `project/app.py` | 49 | yes |
| 119 | `project/app.py` | 50 | yes |
| 119 | `project/app.py` | 56 | yes |
| 119 | `project/app.py` | 66-67 | yes |
| 119 | `project/app.py` | 67 | yes |
| 119 | `project/app.py` | 75 | yes |
| 119 | `project/app.py` | 91 | yes |
| 119 | `project/app.py` | 99-101 | yes |
| 119 | `project/templates/index.html` | 35 | yes |
| 125 | `project/app.py` | 56-60 | yes |
| 125 | `project/app.py` | 56-60 | yes |
| 126 | `project/app.py` | 66-67 | yes |
| 126 | `project/app.py` | 68-72 | yes |
| 127 | `project/app.py` | 75-96 | yes |
| 127 | `project/app.py` | 75-96 | yes |
| 128 | `project/app.py` | 104-112 | yes |
| 128 | `project/app.py` | 48-50 | yes |
| 129 | `project/app.py` | 115-121 | yes |
| 129 | `project/app.py` | 115-121 | yes |
| 130 | `create_db.py` | 7-9 | yes |
| 130 | `create_db.py` | 7-9 | yes |
| 131 | `project/app.py` | 56-121 | yes |
| 131 | `project/app.py` | 56-121 | yes |
| 137 | `project/templates/index.html` |  | yes |
| 137 | `project/templates/login.html` |  | yes |
| 137 | `project/templates/search.html` |  | yes |
| 141 | `project/app.py` | 56-60 | yes |
| 141 | `project/static/main.js` | 8-20 | yes |
| 141 | `project/templates/index.html` | 17-79 | yes |
| 141 | `project/templates/index.html` | 35 | yes |
| 141 | `project/templates/index.html` | 74 | yes |
| 141 | `project/templates/index.html` | 77 | yes |
| 141 | `project/templates/search.html` | 17-19 | yes |
| 142 | `project/app.py` | 115 | yes |
| 142 | `project/app.py` | 115-121 | yes |
| 142 | `project/app.py` | 121 | yes |
| 142 | `project/templates/index.html` | 17 | yes |
| 142 | `project/templates/search.html` | 39-58 | yes |
| 143 | `project/app.py` | 75 | yes |
| 143 | `project/app.py` | 75-88 | yes |
| 143 | `project/app.py` | 81 | yes |
| 143 | `project/app.py` | 83 | yes |
| 143 | `project/templates/index.html` | 20 | yes |
| 143 | `project/templates/login.html` | 25-27 | yes |
| 143 | `project/templates/login.html` | 53 | yes |
| 149 | `project/app.py` | 88 | yes |
| 149 | `project/templates/login.html` | 31-52 | yes |
| 150 | `project/app.py` | 80-83 | yes |
| 151 | `project/app.py` | 85-87 | yes |
| 152 | `project/app.py` | 94-96 | yes |
| 153 | `tests/app_test.py` | 55-64 | yes |
| 155 | `project/app.py` | 22-26 | yes |
| 155 | `project/app.py` | 80-88 | yes |
| 159 | `project/templates/index.html` | 36-65 | yes |
| 160 | `project/app.py` | 66-67 | yes |
| 161 | `project/app.py` | 68-72 | yes |
| 161 | `project/models.py` | 9-11 | yes |
| 162 | `project/app.py` | 68 | yes |
| 162 | `project/models.py` | 6-7 | yes |
| 163 | `tests/app_test.py` | 67-77 | yes |
| 165 | `project/app.py` | 66-67 | yes |
| 165 | `project/app.py` | 69-70 | yes |
| 169 | `project/static/main.js` | 8-11 | yes |
| 170 | `project/app.py` | 48-50 | yes |
| 171 | `project/app.py` | 106-107 | yes |
| 171 | `project/app.py` | 108-112 | yes |
| 171 | `project/static/main.js` | 20 | yes |
| 172 | `project/app.py` | 106-108 | yes |
| 172 | `tests/app_test.py` | 80-88 | yes |
| 174 | `project/app.py` | 110-112 | yes |
| 174 | `project/static/main.js` | 14-20 | yes |
| 178 | `project/app.py` | 59-60 | yes |
| 179 | `project/app.py` | 117-120 | yes |
| 179 | `project/templates/search.html` | 51-52 | yes |
| 180 | `project/app.py` | 121 | yes |
| 181 | `project/models.py` | 5 | yes |
| 181 | `project/static/main.js` | 10-11 | yes |
| 181 | `project/templates/search.html` | 54 | yes |
| 183 | `project/app.py` | 115-121 | yes |
| 183 | `project/app.py` | 118 | yes |
| 183 | `project/templates/search.html` | 51 | yes |
| 187 | `README.md` | 1421 | yes |
| 188 | `create_db.py` | 7-12 | yes |
| 189 | `project/app.py` | 26-29 | yes |
| 189 | `project/flaskr.db` |  | yes |
| 191 | `create_db.py` | 7-12 | yes |
| 199 | `project/app.py` | 26-31 | yes |
| 199 | `project/app.py` | 40 | yes |
| 203 | `project/app.py` | 106 | yes |
| 203 | `project/app.py` | 118 | yes |
| 203 | `project/app.py` | 59 | yes |
| 203 | `project/app.py` | 69 | yes |
| 203 | `requirements.txt` | 4 | yes |
| 207 | `project/app.py` | 1-125 | yes |
| 211 | `project/templates/index.html` | 5-9 | yes |
| 211 | `project/templates/index.html` | 8 | yes |
| 211 | `project/templates/login.html` | 8 | yes |
| 211 | `project/templates/search.html` | 8 | yes |
| 217 | `project/models.py` | 4-7 | yes |
| 217 | `project/templates/index.html` | 74 | yes |
| 221 | `project/models.py` | 5 | yes |
| 222 | `project/models.py` | 6 | yes |
| 223 | `project/models.py` | 7 | yes |
| 225 | `project/app.py` | 23-24 | yes |
| 231 | `project/app.py` | 1-125 | yes |
| 231 | `project/app.py` | 110-112 | yes |
| 231 | `project/app.py` | 36-40 | yes |
| 231 | `project/app.py` | 69-70 | yes |
| 232 | `project/templates/index.html` | 5-9 | yes |
| 238 | `project/app.py` | 23 | yes |
| 238 | `project/app.py` | 80-81 | yes |
| 239 | `project/app.py` | 82-83 | yes |
| 240 | `project/app.py` | 86 | yes |
| 240 | `project/app.py` | 95 | yes |
| 241 | `project/app.py` | 25 | yes |
| 241 | `project/app.py` | 48-50 | yes |
| 242 | `project/app.py` | 66-67 | yes |
| 243 | `project/app.py` | 69-70 | yes |
| 243 | `project/app.py` | 71-72 | yes |
| 243 | `project/templates/index.html` | 31-34 | yes |
| 244 | `project/app.py` | 106-109 | yes |
| 244 | `project/app.py` | 107 | yes |
| 245 | `project/app.py` | 110-111 | yes |
| 246 | `project/app.py` | 26-31 | yes |
| 246 | `project/templates/index.html` | 77 | yes |
| 247 | `project/app.py` | 119-121 | yes |
| 247 | `project/templates/search.html` | 51-52 | yes |
| 253 | `project/app.py` | 23-25 | yes |
| 257 | `project/app.py` | 22-26 | yes |
| 257 | `project/app.py` | 23-24 | yes |
| 257 | `project/app.py` | 66-67 | yes |
| 257 | `project/app.py` | 99-101 | yes |
| 257 | `project/templates/login.html` | 53 | yes |
| 258 | `project/app.py` | 25 | yes |
| 258 | `project/app.py` | 38 | yes |
| 258 | `project/app.py` | 48 | yes |
| 258 | `project/app.py` | 66 | yes |
| 259 | `project/app.py` | 66-67 | yes |
| 259 | `project/templates/index.html` | 74 | yes |
| 259 | `project/templates/search.html` | 55 | yes |
| 259 | `tests/app_test.py` | 76-77 | yes |
| 259 | `tests/app_test.py` | 77 | yes |
| 260 | `project/app.py` | 99-101 | yes |
| 260 | `project/static/main.js` | 8-11 | yes |
| 261 | `project/app.py` | 80-83 | yes |
| 261 | `project/templates/login.html` | 53 | yes |
| 262 | `project/app.py` | 110-112 | yes |
| 262 | `project/app.py` | 99-101 | yes |
| 263 | `.gitignore` |  | yes |
| 263 | `.gitignore` | 5 | yes |
| 263 | `project/app.py` | 22 | yes |
| 263 | `project/flaskr.db` |  | yes |
| 263 | `project/flaskr.db` |  | yes |
| 263 | `project/flaskr.db` |  | yes |
| 263 | `project/models.py` | 4-7 | yes |
| 269 | `Procfile` | 1 | yes |
| 269 | `project/app.py` | 21-32 | yes |
| 270 | `project/templates/index.html` | 36-65 | yes |
| 270 | `project/templates/login.html` | 31-52 | yes |
| 270 | `requirements.txt` | 1-8 | yes |
| 271 | `project/app.py` | 80-87 | yes |
| 272 | `project/app.py` | 21-32 | yes |
| 272 | `requirements.txt` | 1 | yes |
| 273 | `project/app.py` | 75-88 | yes |
| 273 | `requirements.txt` | 1-8 | yes |
| 274 | `project/app.py` | 1-100 | yes |
| 274 | `project/app.py` | 101-125 | yes |
| 275 | `.github/workflows/main.yml` | 3-29 | yes |
| 275 | `Procfile` | 1 | yes |
| 276 | `project/app.py` | 22-26 | yes |
| 277 | `project/app.py` | 66-67 | yes |
| 277 | `project/app.py` | 99-101 | yes |
| 283 | `LICENSE` | 3 | yes |
| 286 | `project/app.py` | 26-31 | yes |
| 286 | `project/templates/index.html` | 8 | yes |
| 287 | `README.md` |  | yes |
| 287 | `README.md` | 1-3 | yes |
| 288 | `.github/workflows/main.yml` | 23-29 | yes |
| 288 | `.github/workflows/main.yml` | 3 | yes |
| 288 | `README.md` | 1083 | yes |
| 289 | `tests/app_test.py` |  | yes |
| 289 | `tests/app_test.py` | 38-52 | yes |
| 289 | `tests/app_test.py` | 55-64 | yes |
| 289 | `tests/app_test.py` | 67-77 | yes |
| 289 | `tests/app_test.py` | 80-88 | yes |
| 293 | `.github/workflows/main.yml` | 3 | yes |
| 293 | `requirements.txt` |  | yes |
| 293 | `requirements.txt` | 1-8 | yes |
| 311 | `project/app.py` | 63-72 | yes |
| 311 | `project/app.py` | 75-87 | yes |
| 322 | `project/models.py` | 4-7 | yes |
| 328 | `README.md` | 3 | yes |
| 329 | `project/templates/index.html` | 71-75 | yes |
| 330 | `project/models.py` | 4-7 | yes |
| 331 | `project/app.py` | 85 | yes |
| 332 | `project/app.py` | 45-53 | yes |
| 333 | `project/app.py` | 71 | yes |
| 334 | `project/app.py` | 26 | yes |
| 335 | `project/app.py` | 25 | yes |
| 336 | `Procfile` |  | yes |
| 336 | `Procfile` | 1 | yes |
| 337 | `create_db.py` |  | yes |
| 337 | `create_db.py` | 7-12 | yes |
| 338 | `project/templates/index.html` | 8 | yes |
| 346 | `Procfile` | 1 | yes |
| 346 | `README.md` | 1083 | yes |
| 348 | `project/app.py` | 22-26 | yes |
| 350 | `project/app.py` | 23-25 | yes |
| 362 | `project/templates/login.html` | 53 | yes |
| 363 | `project/app.py` | 25 | yes |
| 364 | `project/templates/index.html` | 74 | yes |
| 364 | `project/templates/search.html` | 55 | yes |
| 365 | `project/app.py` | 99 | yes |
| 365 | `project/static/main.js` | 8 | yes |
| 377 | `.github/workflows/main.yml` |  | yes |
| 377 | `Procfile` |  | yes |
| 377 | `README.md` |  | yes |
| 377 | `create_db.py` |  | yes |
| 377 | `project/app.py` |  | yes |
| 377 | `project/models.py` |  | yes |
| 377 | `project/static/main.js` |  | yes |
| 377 | `project/static/style.css` |  | yes |
| 377 | `requirements.txt` |  | yes |
| 377 | `runtime.txt` |  | yes |
| 377 | `tests/app_test.py` |  | yes |
| 383 | `.github/workflows/main.yml` | 11 | yes |
| 383 | `requirements.txt` | 1-8 | yes |
| 383 | `runtime.txt` | 1 | yes |
| 387 | `create_db.py` | 9 | yes |
| 387 | `project/app.py` |  | yes |
| 387 | `project/app.py` | 22 | yes |
| 387 | `project/app.py` | 26 | yes |
| 387 | `tests/app_test.py` | 11-21 | yes |
| 391 | `project/app.py` | 21-32 | yes |
| 391 | `project/app.py` | 23-24 | yes |
| 391 | `project/app.py` | 25 | yes |
| 391 | `project/app.py` | 91-96 | yes |
| 397 | `create_db.py` | 7-9 | yes |
| 397 | `project/app.py` | 59 | yes |
| 398 | `project/app.py` | 28-29 | yes |
| 399 | `project/app.py` | 110-112 | yes |
| 400 | `project/app.py` | 25 | yes |
| 406 | `.github/workflows/main.yml` | 23-26 | yes |
| 407 | `.github/workflows/main.yml` | 27-29 | yes |
| 407 | `.github/workflows/main.yml` | 6 | yes |
| 408 | `Procfile` | 1 | yes |
| 408 | `README.md` | 1083 | yes |
| 413 | `project/app.py` | 23-25 | yes |
| 420 | `project/app.py` | 24 | yes |
| 421 | `project/app.py` | 25 | yes |
| 422 | `project/app.py` | 22 | yes |
| 423 | `project/app.py` | 23 | yes |
| 424 | `project/app.py` | 31 | yes |
| 425 | `project/app.py` | 32 | yes |
| 434 | `project/app.py` | 24 | yes |
| 434 | `project/app.py` | 82 | yes |
| 435 | `project/app.py` | 23 | yes |
| 435 | `project/app.py` | 80 | yes |
| 436 | `project/app.py` | 25 | yes |
| 437 | `project/app.py` | 26 | yes |
| 438 | `project/app.py` | 31 | yes |
| 446 | `.github/workflows/main.yml` | 3 | yes |
| 452 | `.github/workflows/main.yml` | 11 | yes |
| 452 | `runtime.txt` | 1 | yes |
| 453 | `.github/workflows/main.yml` | 22 | yes |
| 454 | `Procfile` | 1 | yes |
| 455 | `Procfile` | 1 | yes |
| 455 | `README.md` | 1263 | yes |
| 455 | `README.md` | 216 | yes |
| 456 | `.github/workflows/main.yml` | 29 | yes |
| 456 | `tests/app_test.py` | 45 | yes |
| 458 | `.github/workflows/main.yml` | 11 | yes |
| 458 | `Procfile` | 1 | yes |
| 458 | `README.md` | 1421 | yes |
| 458 | `runtime.txt` | 1 | yes |
| 458 | `tests/app_test.py` | 45 | yes |

## Verification

**Source-to-claim audit:** performed (auditor: independent). 63 rows (7 superseded): 55 Supported, 5 Corrected, 1 Downgraded, 1 Dismissed, 1 Answerable.

| Section | IDs with a register row |
|---|---|
| 4 | 7 of 7 |
| 6 | 3 of 3 |
| 8.1 | 1 of 1 |
| 8.3 | 1 of 1 |
| 10.1 | 7 of 7 |
| 14 | 5 of 5 |
| 15 | 10 of 12 |
| 7 (workflows) | 5 of 5 |
