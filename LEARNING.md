# Learning Log

Concepts learned, problems I got stuck on, and how they were solved.

## 2026-10-27 — First deploy to Render

### Thruster vs. Render's port
- **Problem:** The Dockerfile from `rails new` starts Thruster on port 80, which proxies to
  Puma on 3000. Render sends traffic to `$PORT` (10000), so with the default CMD nothing
  would listen there.
- **Fix:** `dockerCommand: ./bin/rails server` in `render.yaml`. Puma binds to `$PORT`
  directly. Render's edge already does TLS and HTTP/2, which is what Thruster is for.
- **Lesson:** The `CMD` in a Dockerfile is only a default, and the platform can override it.

### One `DATABASE_URL`, four databases
- **Problem:** Rails 8 production uses four databases (primary, cache, queue, cable). Render
  gives one `DATABASE_URL`. Setting `database:` next to `url:` in `database.yml` did not
  work: **values parsed from `url` override individual keys.**
- **Fix:** Derive each URL from `DATABASE_URL` with only the path replaced.

### A regex broke every environment, including CI
- **Problem:** The first version replaced the database name with a regex. CI's URL has no
  database path (`postgres://...@localhost:5432`), so the regex mangled it. CI failed even
  though the code was only for `production:`.
- **Why:** Rails evaluates the ERB in the **whole** `database.yml` in every environment,
  not just the section for the current one.
- **Fix:** Parse with `URI(url)` and set `uri.path`. Use a real parser for structured strings.

### CI needs `db/schema.rb` and `test/system/`
- `bin/rails db:test:prepare` loads `db/schema.rb`. A new app with no migrations has no
  schema file, so we committed an empty one.
- Git does not track empty directories. The CI system-test job needs `test/system/`, so we
  added `test/system/.keep`.

### Render Postgres disk
- The Blueprint's default disk is large, and disk size can grow but never shrink. We set
  `diskSizeGB: 1` before the first deploy.

### Check: `/up`
- `rails/health#show` returns 200 if the app boots without exceptions. It does **not**
  query the database, so a green `/up` does not prove the DB works. That needs a page that
  reads from the DB.

## 2026-10-29 — `uninitialized constant TranscribeRecordingJob::Transcription`

- **Problem:** Uploading a recording returned a 500 error in development. All tests passed,
  and running the job with `bin/rails runner` worked.
- **Why:** Rails sets Zeitwerk's autoload roots (`app/models`, `app/jobs`, …) **when the
  server boots**. The dev server had been running since before `app/services/` existed, so
  it never learned to look there. Code *reloading* picks up new files inside known roots,
  but not a brand-new `app/*` directory. Tests and `runner` start a fresh process, so they
  saw it.
- **Fix:** Restart the server.
- **Lesson:** After creating a new top-level folder under `app/`, restart `bin/dev`.
  Check with `bin/rails runner 'puts Rails.autoloaders.main.dirs'`.
