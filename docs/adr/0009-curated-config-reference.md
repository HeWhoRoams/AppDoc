# ADR 0009: A curated, generated configuration reference that never records values

- **Status:** Accepted (2026-11-11)
- **Decision area:** Facts; Template; Generated blocks

## Context

The 2.2 `config-reference` block listed every `config_key` Fact. On gitea that was about 9,000 rows,
nearly all commented defaults in a sample `app.ini`, which no reader can use. On flaskr it listed
`USERNAME` as "defined at" a read site and omitted `SECRET_KEY`, which the app loads from a module
constant with `from_object`. Reviewers asked for a "Default" column; the extractor deliberately
never records values, because detecting which values are secrets is heuristic.

## Decision

1. No config value is ever recorded in Facts or in the block. The reference names keys and
   locations only.
2. **Define first.** Each `config_key` Fact has `use` = `define` (the file or code that sets it) or
   `read` (code that consumes it). A key is listed at its first definition; it falls back to its
   first read only when no definition exists. Flask `from_object` modules and `app.config[...] =`
   assignments count as definitions.
3. Only application-role keys outside test code are listed. Build, CI and orchestration keys are
   excluded as in 2.2.
4. **Commented defaults are counted, not listed.** The trailer says how many there are and where
   (`Shown N of M application keys; K commented defaults in <files> are not listed (see
   facts.json)`).
5. **Order and cap.** Secret locations first, then by path and line; at most 150 rows. The "N of M
   shown" figures are computed by `fill`, never written by hand.
6. Effects of keys that matter are written by hand in an optional `Key | Effect | Evidence` table
   below the block. C10 requires each Key cell to name a `config_key` Fact, so the table cannot
   describe a key that does not exist.

## Consequences

- The block is a map of where to look, not a description of what each key does or its default.
  The hand table and the writer's reading carry that.
- A key defined only in an unscanned folder or an extensionless file shows up as a read, or not at
  all. The 2.1 block lists pruned folders.
- Truncation is visible: a reader sees that rows are missing and by how many.

## Amendment (2026-11-23, 2.5.0): role split by read kind

A key read from code is no longer always application configuration. A per-file `read_kind` (`env` for
environment-variable reads, `file` otherwise) feeds a post-pass that assigns role `env` to
environment-variable reads, `ci` to reads in CI or build files, and `app` to the rest. Only `app`
keys appear in the application table; the trailer counts the `env` and `ci` keys it excludes. Keys of
roles `env` and `ci` are not `secret_location`, because the variable is the name of a secret held
elsewhere, not the secret itself. The cache keeps pre-promotion Facts, so the split stays in the
post-pass.

## Amendment (2026-11-23, 2.6.0): file-level promotion and segment-aware secret naming

1. **File-level promotion.** Role `app` was assigned key by key, so a file that an application
   plainly reads (a gitea `app.ini` read through `setting.Cfg.Section(...).Key("X")`) still had
   most of its keys classified as `unclassified`, and 16.6 listed a few keys and called the rest
   "not classified". In the post-pass, any unclassified key in a file that has at least one
   code-read key (matched through `_key_variants`: the full name and the last dotted segment, so
   `server.HTTP_PORT` in an INI matches a read of `HTTP_PORT`) becomes `app`. File promotion runs
   after the read-kind split and never promotes `env` or `ci` keys. The trailer guard raises an
   internal error if a file is both `app` and "not classified".
2. **Segment-aware secret names.** `secret_location` was a substring test, so `MIN_PASSWORD_LENGTH`
   was a secret location. `secrets.is_secret_key` now tokenizes the name on separators and camel
   case. A name is a secret when it has a secret noun (password, passwd, pwd, secret, token, credential,
   sas) or a secret pair (api key, private key, account key, connection string) and none of a closed set of modifiers: `length min max size count ttl lifetime expiry
   expires minutes seconds hours days algo algorithm hash complexity policy check pwn enable enabled
   disable disabled allow require required form cache uri url path file header name type mode scope
   scopes regex pattern`. The set is closed and lives in code, not in configuration.
3. **`secret_ref`.** A name whose modifier is `uri`, `path` or `file` (`SECRET_KEY_URI`) is not a
   secret location but refers to one; the Fact carries `secret_ref: true` (a `DETAIL_KEYS` entry)
   and still holds no value.
4. **Two predicates (2.6.0).** `secrets.is_secret_key` is the display predicate for `secret_location`
   and stays precise. `secrets.never_record_value(key)` is true when `is_secret_key` is true **or** the
   pre-2.6 broad substring test matches (`PasswordHash`, `TOKEN_CACHE`, `PASSWORD_FILE`). R19 gates
   value recording and value resolution with `never_record_value` only. A `config_key` Fact never
   carries a value; a test asserts it.
5. The finding-candidate and secret-shape scan (C6, `find_secret_shapes`) is independent of key
   naming and is unchanged; a test proves it.

