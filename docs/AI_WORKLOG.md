# AI Worklog

Append only. Each entry records what the user asked for, what Claude Code did, and what was actually run.

---

## 2026-10-13 — Session 1, Step 1: environment & input inspection

**Context.** The user produced the requirements, architecture, database schema, API contract, `SPEC.md`, the content
transcription (`journey_content.yaml`) and the asset crops in a **prior Claude chat planning session**. The raw export of
that session will be placed in `docs/ai-history/`.

**Objective.** SPEC §13 step 1: inspect the environment and inputs, then write `CLAUDE.md` and `docs/IMPLEMENTATION_PLAN.md`.

**User's instructions (summary).** Implement the approved Journey/lesson feature (Flutter + Node/Express/Postgres) by
following SPEC §13 step by step, without redesigning approved decisions. Ask about anything the spec doesn't cover. Commit
locally after each step and don't push without asking. Keep this worklog truthful. If Node is not 22, report it before going further.

**What Claude Code did.**
- First attempt ran in a Claude Code cloud container: a fresh clone without `docs/planning/` or the reference pack.
  Claude Code reported the missing inputs; that container's local commit does not exist in this repo. The user then said
  to continue in the local folder `D:\HealthTick`, where all inputs are present.
- Local inspection: branch `main` (up to date with `origin/main`, single commit `baffc08 first commit`).
  Uncommitted user change in `.gitignore` adds `/docs`. Claude Code left it untouched (see open issues).
- Read `SPEC.md` in full. Confirmed the schema SQL, the reference pack (45 PNGs, `manifest.json`, content YAML, README) and the
  reference video are present. Two copies of `journey_content.yaml` exist (`Resources/` and `Resources/reference_pack/content/`);
  their SHA-256 hashes match.
- Inspected the scaffolding: both app folders are stock templates (Flutter counter app, express-generator with Jade).
- Recorded tool versions in `IMPLEMENTATION_PLAN.md`.
- Wrote `CLAUDE.md`, `docs/IMPLEMENTATION_PLAN.md`, this worklog and `docs/ai-history/README.md`.

**Decisions (Claude Code).**
- The SPEC/brief spell the reference folder `Resouces/`, but on disk it is `Resources/` (already git-ignored). Claude Code
  uses the on-disk path and will ignore both spellings in step 2.

**Commands run.** `git status`, `git branch -a`, `git log`, `git diff`, `Get-ChildItem docs,Resources -Recurse`,
`Get-Command` for each tool, `node --version` (v24.19.0), `npm --version` (11.17.0), `flutter --version` (3.44.9 / Dart 3.12.2),
`flutter doctor -v` (Android toolchain: licence status unknown; Visual Studio missing, irrelevant for Android),
`java -version` via Android Studio jbr (25.0.2), `adb --version` / `adb devices` (no devices), `emulator -list-avds`
(`Medium_Phone`), `docker version` / `docker ps` (engine not running), `Get-FileHash` on both YAML copies (identical).

**Tests.** None (no code yet).

**Questions raised and the user's decisions (asked within this step).**
1. Node is v24.19.0, but SPEC §7.1 requires Node 22 LTS. **User decision:** proceed on Node 24. `package.json` will declare
   `engines.node >=22` so it also runs on 22. The deviation is recorded in the plan.
2. The user's uncommitted `.gitignore` change ignored `/docs`. That would have kept every required deliverable out of git.
   **User decision:** ignore only `/docs/planning/`. Claude Code applied this; `docs/planning/SPEC.md` and the schema stay private.

**Bug found and fixed.** The first `.gitignore` rewrite used PowerShell 5.1 `Set-Content -Encoding utf8`, which writes a BOM.
That breaks the first ignore pattern. The file was rewritten from Bash without a BOM and checked with `git check-ignore -v`.

**Open issues.**
- The Docker Desktop engine was not running. Claude Code launched Docker Desktop; it is needed from step 2.
- Android SDK licences may need `flutter doctor --android-licenses` before the APK build (step 12).

---

## 2026-10-13 — Session 1, Step 2: Docker Compose, env and ignore files

**Objective.** SPEC §13 step 2: Docker Compose for Postgres, root `.env.example`, `.gitignore`.

**What Claude Code did.**
- `docker-compose.yml`: service `postgres` (`postgres:16-alpine`), host port `${POSTGRES_HOST_PORT:-5433}` → 5432, named volume
  `healthtick_pgdata`, `pg_isready` healthcheck, credentials from the root `.env` (compose fails fast if they are unset).
- `docker/postgres/init.sql` creates `healthtick_dev` and `healthtick_test`.
- `.env.example` (placeholders) and a local `.env` (git-ignored, not committed).
- `.gitignore`: both `Resources/` spellings, `docs/planning/`, `.env*` except `.env.example`, Node/Flutter build outputs, editor files.
- `.gitattributes`: forces LF for `*.sh/*.sql/*.yml/*.yaml`, so files mounted into the Linux container are not CRLF on Windows.

**Decisions.**
- Claude Code made the host port configurable (`POSTGRES_HOST_PORT`, default 5433 per SPEC), so a port clash doesn't require editing the compose file.
- Port 5433 was already held by the user's unrelated container `jobtracker-db-1`. **User decision:** stop that container
  (`docker stop`; its data volume is untouched). Note: Docker Desktop may restart it later because of its restart policy.

**Commands run / results.**
- `docker stop jobtracker-db-1` → stopped.
- `docker compose up -d` → `healthtick-postgres` started. Health status became `healthy`.
- `psql` inside the container: databases `healthtick_dev` and `healthtick_test` exist. Server: `PostgreSQL 16.15 … (Alpine)`.
- `docker port healthtick-postgres` → `5432/tcp -> 0.0.0.0:5433`.
- `git check-ignore -v .env` → ignored by `.gitignore`.

**Open issues.** None.

---

## 2026-10-13 — Session 1, Step 3: backend scaffold, config, logging, errors, /health, test harness

**Objective.** SPEC §13 step 3.

**User's decisions in this step.** The user approved `git rm` of the express-generator template
(`app.js`, `bin/www`, `routes/`, `views/*.jade`, `public/`, old `package.json`).

**What Claude Code did.**
- New `user_journey_backend/package.json` (ESM, `engines.node >=22`). Scripts: `dev`, `start`, `build`, `typecheck`, `lint`,
  `format`, `test`, `test:unit`, `test:integration`, `db:migrate`, `db:migrate:test`, `db:codegen`. More are added in later steps.
- `tsconfig.json` (strict, `noUncheckedIndexedAccess`, NodeNext), `tsconfig.build.json`, `eslint.config.js` (flat config,
  typescript-eslint + prettier), `.prettierrc.json`, `vitest.config.ts`, `.env.example`, and a local `.env` (ignored).
- `src/config/env.ts`: Zod-validated env (SPEC §3.2) that reports every invalid variable and exits.
  `TEST_DATABASE_URL` must end in `_test`. `.env` is loaded with Node's built-in `process.loadEnvFile`.
- `src/lib/errors.ts` (`AppError` + the SPEC §6.1 code→status table), `src/lib/logger.ts` (pino with header redaction).
- Middleware: `requestId` (echo a well-formed `X-Request-Id` or generate one), `validate` (Zod; parsed values go on `req.valid`
  because Express 5's `req.query` is read-only), `notFound`, `errorHandler` (AppError / Zod / body-parser → client codes;
  anything else → `INTERNAL_ERROR`, logged server-side only).
- `src/app.ts` (`createApp(deps)`, no listen) follows the SPEC §7.3 middleware order. `src/server.ts` handles listen and graceful shutdown.
- `src/db/kysely.ts`: pool size 10. int8 is parsed as a number and `date` kept as a string.
- Test harness: `test/helpers/testDb.ts` refuses any database not ending in `_test`. `globalSetup` checks the test database
  is reachable. `fileParallelism: false` because integration tests share one database.

**Decisions (Claude Code).**
- **Extra dependencies beyond SPEC §7.1:**
  - `yaml`: parses the YAML seed content.
  - `kysely-codegen`: named by SPEC §7.2 for `db:codegen`.
  - `@types/*`: TypeScript type packages.
  - No `dotenv`, because Node ≥ 21.7 has `process.loadEnvFile`.
- **TypeScript 6.0.3, not 7.0.2:** typescript-eslint 8.71 supports `typescript <6.1.0`.
- **`@types/node@^22`:** keeps the code within the Node 22 API surface, even though the runtime is Node 24.
- **`/health` path:** served at both `/health` and `/api/v1/health`. SPEC §6.2 lists it under `/api/v1`, but §6.1 treats it like
  `/static`, which is root-level. Neither path requires `X-User-Id`. The 503 body is
  `{ data: { status: "degraded", db: "unavailable" } }`; SPEC only fixes `db: "unavailable"`.
- **helmet:** `crossOriginResourcePolicy: cross-origin`, so static images also load from a Flutter web build.
- **Request ID:** an incoming `X-Request-Id` is echoed only if it matches `[A-Za-z0-9._:-]{1,128}` (log-injection safety); otherwise one is generated.
- **Body-parser errors:** malformed JSON and an oversized body both map to 400 `VALIDATION_ERROR`, since the SPEC has no code for them.

**Bugs found and fixed.**
- ESLint `preserve-caught-error` flagged the re-thrown error in `globalSetup`; added `{ cause }`.
- A long multi-file Bash heredoc was cut off mid-file. The affected test files were rewritten with the Write tool.

**Commands and tests actually run.**
- `npm install …` (0 vulnerabilities). npm 11 skipped esbuild's postinstall, but `tsx` and `vitest` work without it.
- `npx tsc --noEmit` → exit 0. `npx eslint .` → clean. `npx prettier --check .` → "All matched files use Prettier code style!"
- `npx vitest run` → `Test Files  3 passed (3)` / `Tests  16 passed (16)`. Covers:
  - Env parsing and the test-DB guard.
  - Error mapping: AppError, Zod, unknown-field rejection, malformed JSON, 500 without SQL, 404 envelope.
  - `/health` returns 200, and 503 when the DB is unreachable.
  - Static serving: cache headers, no directory listing, traversal returns 404.
- Smoke test: `npx tsx src/server.ts`, then `curl /health` → `{"data":{"status":"ok","db":"ok"}}`.
  `curl /api/v1/nope` → 404 envelope with `X-Request-Id`. The server was stopped with `taskkill`.

**Open issues.** None.

---

## 2026-10-13 — Session 1, Step 4: migration 001, codegen, test database

**Objective.** SPEC §13 step 4: schema v1 as migration 001 verbatim, codegen, migrate the test database.

**What Claude Code did.**
- Copied `docs/planning/healthtick_schema_v1.sql` to `src/db/migrations/001_schema_v1.sql` **byte-identical**
  (SHA-256 `1480f771…ab9c71` for both). `.gitattributes` keeps it LF.
- `src/db/migrations/index.ts` registers migrations explicitly (a static provider, not file-system discovery, which is fragile
  on Windows/tsx). 001 runs the SQL file with `sql.raw` (multi-statement, simple query protocol).
  `src/db/migrate.ts` (`migrateToLatest`) and `scripts/migrate.ts` (`--test` targets `TEST_DATABASE_URL`).
- `scripts/codegen.ts` runs kysely-codegen against `DATABASE_URL`. Mappings: `int8 → number` and `date → string`, to match the
  pg type parsers. Migration tables are excluded. It generated `src/db/types.ts` (23 tables).
- `build` now also copies `.sql` migrations into `dist/` (`scripts/copy-sql.mjs`).
- Test harness: `globalSetup` now **drops and recreates `healthtick_test`** (name checked to end in `_test`) and migrates it fresh on
  every run, as SPEC §11.2 requires. Only the `_test` database is touched, as the project rules allow.
- `test/integration/schema.test.ts` checks:
  - 23 tables exist and re-migrating is a no-op.
  - Content triggers bump `content_state.version` and NOTIFY on commit.
  - User tables don't bump the version, and `updated_at` is maintained.
  - A CHECK constraint (`ck_graded_is_choice`) is enforced.

**Finding (no change to the schema).** The content triggers are `FOR EACH STATEMENT`, so a transaction with N content statements
bumps the version N times and sends N `content_changed` notifications at commit (the test asserts exactly this). Two consequences
for step 5/6:
1. The SSE layer will coalesce notifications that arrive in a short burst into one event carrying the latest version. This is
   how "`demo:set-node-count` emits exactly one event" (SPEC §11.2) will hold.
2. Statement-level triggers fire even when a statement affects zero rows. For the seed to be idempotent (a rerun "changes nothing",
   including the content version), the seeder must diff against the existing rows and issue no statement for unchanged rows.

**Bugs found and fixed.**
- Kysely 0.29 moved `Migrator` to the `kysely/migration` subpath; the root import failed at runtime. Fixed the imports.
- `migrateToLatest(db: Kysely<unknown>)` didn't accept the typed `Kysely<DB>`; changed it to `Kysely<any>`, as Kysely's own
  migration API does.

**Commands and tests actually run.**
- `npm run db:migrate` → "Migrated healthtick_dev: 001_schema_v1". Second run → "healthtick_dev is already up to date".
- `npm run db:migrate:test` → "Migrated healthtick_test: 001_schema_v1".
- `npm run db:codegen` → "✓ Introspected 23 tables and generated .\src\db\types.ts".
- `npm run build` → `dist/db/migrations/` contains `001_schema_v1.sql` and `index.js`.
- `npx tsc --noEmit` → OK. `npx eslint .` → clean. `npx prettier --check .` → all formatted.
- `npx vitest run` → `Test Files  4 passed (4)` / `Tests  20 passed (20)`.

**Open issues.** None.

---

## 2026-10-13 — Session 1, Step 5: reference pack, Fluent Emoji, seeder, validator, reset/demo scripts

**Objective.** SPEC §13 step 5.

**What Claude Code did.**
- **Reference pack:**
  - Copied `journey_content.yaml` → `seed/journey_content.yaml` and `manifest.json` → `seed/asset-manifest.json`.
  - Copied the 45 PNG crops → `static/assets/`.
- **Fluent Emoji:** downloaded the 9 assets with `replace_with` from `microsoft/fluentui-emoji`, using the 3D PNGs from commit `1ffb34c7…`.
  - Each upstream path was verified (HTTP 200) before use. None of the 9 has skin-tone variants, so all come from `<Name>/3D/`.
  - Downloads went into an empty scratch folder and were checked for a PNG signature (all 256×256) before copying.
  - Result: 5 crops replaced (`callout_ten_minutes`, `icon_zone_1..4`) and 4 new files (`feedback_correct`, `node_insider_*`).
  - Wrote `static/assets/ATTRIBUTION.md` with the upstream paths and the MIT text, diffed against the upstream LICENSE.
- **Content library:**
  - `src/lib/markup.ts`: markup validator; the scanning rule is documented for the Flutter parser to mirror.
  - `src/lib/assets.ts`: relative asset URLs and PNG size reader.
  - `src/content/schema.ts`: strict Zod schema for the YAML and manifest. Only `provenance`, `notes` and `corrections` are allowed as documentation keys.
  - `src/content/model.ts`: normalised model, placeholder expansion, plain-string options.
  - `src/content/validate.ts`: every SPEC §7.6 rule.
- **Admin library:**
  - `src/admin/seed.ts`: a diffing upsert by key in one transaction.
  - `src/admin/nodeCount.ts`.
  - `src/admin/progress.ts`.
- **Scripts:** `content:validate`, `db:seed` (`--test`), `progress:reset [--user]`, `demo:set-node-count --level --count`.

**Decisions (Claude Code; open details not fixed by the SPEC).**
- **Seeder idempotency.** The schema's statement-level triggers fire even for statements that change no rows. The seeder therefore
  reads existing rows, compares them (jsonb compared with a stable key order) and issues statements only for real differences.
  A rerun issues zero writes, so the content version is unchanged.
- **Pages and blocks:**
  - Pages are identified by (lesson, position). A page whose type changes is replaced.
  - Blocks are compared as a whole tree per page; any difference replaces that page's blocks.
  - Options are identified by position, so their ids survive label edits, since answers reference option ids.
- **Rows the YAML doesn't mention** (e.g. demo nodes) are never deleted. The seeder unpublishes or deactivates them and moves them after the YAML rows.
  So `db:seed` restores the YAML journey, and `demo:set-node-count` can republish the same demo nodes later.
- **Empty `explanation: ""`** is stored as NULL (no explanation on the feedback card).
- **Single-choice questions** store `max_selections = 1` (SPEC example payload; schema `ck_single_choice_max`).
- **Media sizes:** `media_assets.width/height` come from the actual PNG file, not the manifest. The Fluent replacements are 256×256, not the crop sizes.
- **`demo:set-node-count`** details:
  - Demo node titles continue the "Day N" numbering (e.g. Insider `demo_insider_l2_4` → "Day 10").
  - The demo lesson is "Demo lesson i", with a heading and paragraph and the YAML placeholder template's CTA and completion copy.
  - The icon is reused from the level's last lesson node.
  - The count must be 0–60 (the SPEC engine-test range).
- **Content validator extras** beyond the SPEC list, each catching a real failure mode:
  - Unknown/typo keys.
  - Duplicate keys.
  - Unknown `{{…}}` tokens.
  - `answer_key` only on free-text questions.
  - Duplicate option labels (a DB unique constraint).
  - At least one active feedback message per outcome.
  - The required `ui_assets` exist.

**Bugs found and fixed.**
- **Content YAML bug, caught by the new validator.** In the checkpoint quiz, the option
  `{ label: Wanting to eat because you see tasty food, even when you're not hungry, correct: true }` is an unquoted
  YAML flow mapping. The comma splits it, so the label became "Wanting to eat because you see tasty food" plus a stray key.
  Claude Code quoted the label **in the backend copy** (`seed/journey_content.yaml`) only; the original in `Resources/` is untouched.
  This is a syntax fix that restores the evidently intended text, not a content change.
- An inline Python-or-Node edit command hung (the Windows `python` Store stub) and was stopped. The edits were redone with the Edit tool.
- The test regex for the "exactly one correct option (found 2)" message was wrong in the test, not in the validator; fixed the test.

**Commands and tests actually run.**
- `npm run content:validate` → "Content OK: 2 statuses, 30 lessons (19 placeholders), 74 pages, 49 assets." (exit 0).
  Before the YAML fix it exited 1 with the issue above.
- `npm run db:seed` (dev): run 1 inserted media_assets=49, app_copy=54, feedback_reasons=6, answer_feedback_messages=6,
  journey_statuses=2, journey_levels=2, journey_nodes=10, lessons=30, lesson_pages=74, page_blocks=291, page_questions=18,
  question_options=60, at content version 205. Run 2: inserted none / updated none / deleted none, version still 205.
- `npm run demo:set-node-count -- --level insider_l2 --count 5` (created `demo_insider_l2_4/5`), then `--count 3`, `5`, `3`
  (unpublish and republish), then `--level nope` → "Unknown level" (exit 1). Insider ended at 3 published nodes.
- `npm run progress:reset` → all deletes 0 (no progress yet), total reset. `db:seed` afterwards → no changes.
- `npx tsc --noEmit` OK. `npx eslint .` clean. `npx prettier --check .` clean.
- `npx vitest run` → `Test Files  7 passed (7)` / `Tests  61 passed (61)`. New tests cover:
  - Markup and the validator rules, including that the real content validates.
  - Placeholder expansion.
  - Seed tree shape and idempotency (identical row counts, unchanged version, zero writes).
  - In-place edits that keep option ids.
  - set-node-count up/down/republish, checkpoint last, invalid input.
  - A later seed restoring the YAML nodes.
  - progress:reset.

**Open issues.** The SSE "exactly one event" part of the `demo:set-node-count` test needs the events module (step 6).

---

## 2026-10-13 — Session 1, Step 6: API modules (app-config, home, journey, lessons, attempts, search, saved, feedback, events)

**Objective.** SPEC §13 step 6: every endpoint in SPEC §6.2 with unit and integration tests.

**What Claude Code did.**
- **Shared:**
  - `middleware/userContext` (X-User-Id → 401 `USER_NOT_IDENTIFIED` for missing, malformed or unknown ids).
  - `lib/time.ts` (local dates in `APP_TIMEZONE`, streak).
  - `lib/rng.ts` (injectable RNG, weighted pick).
  - `container.ts`, which wires repositories → services → controllers → routes.
- **journey:**
  - `journey.rules.ts`: pure §4.2/4.3/4.6/4.10 rules.
  - The repository loads the published tree with every ancestor published.
  - `JourneySnapshot` (tree + states + progress) is reused by home, lessons, search, saved, feedback and attempts.
  - `GET /journey` sends ETag `W/"c{version}-p{stamp}"` and returns 304 on `If-None-Match`.
- **app-config:** `GET /bootstrap` (copy, ui assets, active feedback reasons, user).
- **home:** `GET /home` (streak, today's task).
- **lessons:** `GET /lessons/:id`. 404 if not visible, 403 if locked. Options are selected **without** `is_correct`. Accordion children are nested.
- **attempts:**
  - Start / answer / complete / abandon, with pure `attempts.grading.ts` (§4.7) and the points rule.
  - Answer locks the attempt row, upserts the answer, replaces the options and picks feedback with the injected RNG.
  - Complete runs in one transaction:
    - attempt `FOR UPDATE`, then the user row `FOR UPDATE`, using one `now()` timestamp throughout;
    - idempotent replay of a completed attempt;
    - 409 `CONTENT_CHANGED` vs 422 `INCOMPLETE_ATTEMPT` by content version;
    - ledger row, total, progress upsert;
    - node completion and `unlockedNodeId`.
- **search:**
  - Full-text (`websearch_to_tsquery`) OR `word_similarity` ≥ 0.5 OR a case-insensitive title substring (LIKE wildcards escaped).
  - Score is `ts_rank + word_similarity`; journey sort uses global order.
- **saved:** idempotent PUT/DELETE.
- **feedback:** `FEEDBACK_INVALID` rules.
- **events:**
  - `db/listen.ts` (`ContentListener`): one shared LISTEN connection, reconnecting with 1/2/5/10/30 s backoff and re-reading the version after a reconnect.
  - It **coalesces** the NOTIFY burst of one transaction (150 ms window) into one `change`.
  - `EventsHub` sends `retry: 5000` + `hello`, `content_changed`, and a shared `ping` heartbeat.
- `server.ts` graceful shutdown, in SPEC §7.5 order: stop accepting → end SSE streams → stop the listener → destroy the pool.

**Decisions (Claude Code; details the SPEC leaves open).**
- **`ui_assets`:** the YAML map has no schema table, so the seeder stores it as reserved `app_copy` keys `ui_asset.<name>`.
  `/bootstrap` moves those into `assets` (camelCase: `lockedNode`, `completionMedal`) and leaves them out of `copy`.
  The validator rejects YAML copy keys that use that prefix.
- **ETag `userProgressStamp`** is `max(user_lesson_progress.last_completed_at)` in epoch ms, and the response sends `Cache-Control: private, no-cache`.
- **Lesson `completedAt`** = `first_completed_at`. **Node `completedAt`** = `user_node_completions.completed_at`.
- **Error choices for answers:**
  - A page outside the attempt's lesson → 404 `NOT_FOUND`.
  - Wrong body kind (text for a choice question or vice versa) → 422 `ANSWER_INVALID`.
  - Duplicate option ids count once.
  - Both or neither of `optionIds`/`text` → 400 `VALIDATION_ERROR` (Zod union of strict objects).
- **Feedback errors:** an unknown reason, or a `pageId` not in the lesson → 422 `FEEDBACK_INVALID`.
- **Idempotent complete replay** returns the stored points. `nodeCompleted` is recomputed by matching the node completion
  timestamp to the attempt's `completed_at`, which is the same transaction timestamp.
- **Feedback pool order** is by `key`, so the injected RNG gives deterministic results in tests.
- **The SSE `/events` route also requires X-User-Id**, since SPEC §6.1 exempts only `/health` and `/static`. The Flutter client will send it.

**Bugs found and fixed.**
- `assetOrNull` didn't accept the nullable columns of a LEFT JOIN (TS error); widened its parameter type.
- A test expectation used the wrong headline: the pool is ordered by key, so rng=0 picks `incorrect_dont_worry`. Fixed the test to match the documented ordering.
- First manual SSE check showed 1 of 2 events, because the curl stream ended (12 s timeout) before the second script. Rerunning with a 40 s window showed both events.
- The dev DB was seeded before the `ui_asset.*` change; reseeding inserted the 2 rows (`app_copy=2`).

**Commands and tests actually run.**
- `npx tsc --noEmit` OK. `npx eslint .` clean.
- `npx vitest run` twice → `Test Files  14 passed (14)` / `Tests  136 passed (136)` both times. Integration coverage:
  - Auth 401 ×3.
  - bootstrap.
  - home: fresh, after completion, all done.
  - journey: structure, fresh states, ETag/304, ETag change, node unlock.
  - lessons: payload, no `is_correct`/`isCorrect`/`"correct"` in the JSON, all block types, 403/404/400, unpublished parent hides children.
  - search: "procrast", both sorts, limit, validation, wildcard escaping, unpublished hidden.
  - attempts:
    - wrong/correct feedback, RNG rotation, ungraded and re-answer;
    - 422 for another question's option, wrong body kind and free-text rules; 400 for body shape; 404 for a foreign attempt or page;
    - 422 `INCOMPLETE_ATTEMPT`, 409 `CONTENT_CHANGED` with a question added mid-attempt;
    - first vs replay points; **2 concurrent completes → exactly one ledger row**;
    - checkpoint unlocks Insider; abandon semantics.
  - saved: idempotent.
  - feedback: validation.
  - SSE (real HTTP + LISTEN): retry/hello/content_changed, **set-node-count → exactly one event** plus the updated journey, ping, disconnect cleanup, 401.
- Manual smoke test against the dev DB with `npx tsx src/server.ts`:
  - `GET /home` and `/journey` return the seeded data. `GET /bootstrap` → contentVersion 226.
  - A curl SSE stream while running `demo:set-node-count --count 5` then `--count 3` showed `hello {226}`,
    `content_changed {228}`, `content_changed {230}`: exactly one event per script run.

**Open issues.** None for the backend. The Flutter app starts in step 7.

---

## 2026-10-13 — Session 1, Step 7: Flutter scaffold, theme, core layers

**Objective.** SPEC §13 step 7: Flutter scaffold, theme, and the core layers (network, errors, SSE, markup, routing, DI).

**What Claude Code did.**
- **Dependencies:** added the SPEC §8.1 packages (versions in `IMPLEMENTATION_PLAN.md`) and removed `cupertino_icons`.
  Dev-only additions:
  - `build_runner` (needed to run freezed/json_serializable).
  - SDK `integration_test` (for SPEC §11.4).
- `analysis_options.yaml`: formatter width 120; generated files excluded from analysis. Generated `*.g.dart` / `*.freezed.dart`
  are committed so a clean clone builds without running the generator first.
- **Core:**
  - `config/env.dart`: dart-defines `API_BASE_URL` (default `http://10.0.2.2:3000`), `DEMO_USER_ID`, and asset URL resolution (SPEC §3.4).
  - `theme/tokens.dart` + `theme.dart`: SPEC §9.1 tokens, dark only.
  - `error/failure.dart`: sealed `NetworkFailure`, `TimeoutFailure`, `ServerFailure(code)` (with locked/not-found/content-changed helpers),
    `ParsingFailure`, `UnexpectedFailure`; each maps to an `app_copy` key. `error/app_exception.dart`.
  - `copy/app_copy.dart`: `AppCopy` (bootstrap copy) and `FallbackMessages`, the only hardcoded UI text, covering error/retry keys only.
  - `network/api_client.dart`: Dio with 10 s/15 s timeouts and the `X-User-Id` interceptor. It unwraps `{data}`, maps every error,
    and has `getConditional` for the journey ETag/304.
  - `network/sse_client.dart`: incremental `SseParser` (chunks, CRLF, multi-line data), `ReconnectPolicy` (1/2/5/10/30 s),
    and `SseClient` over a Dio stream.
  - `markup/markup_parser.dart`: a pure parser using the same scanning rule as the backend validator. Malformed input → plain text, never throws.
    Also `TokenResolver` (`{{user.name}}`, `{{answer.key}}` → value or "—", unknown tokens literal + logged) and `markup_text.dart`
    (highlight `#D9F2C4` on `#111111`).
  - **Widgets:**
    - `RemoteImage`: cached, with a pulsing placeholder, a broken-image fallback, and a test hook (`debugBuilder`) because plugins are unavailable in widget tests.
    - `PrimaryButton`: shows a spinner while loading.
    - `ErrorView`, `LoadingView`, `showToast`.
  - `routing/router.dart`: go_router routes per SPEC §8.3, plus a `RouteObserver`. `di.dart` (get_it), `app.dart`, `main.dart`.
- **app_config feature:** `BootstrapDto` (json_serializable, `checked: true`) → `Bootstrap` entity, a repository, and `AppConfigCubit`
  (freezed sealed state `loading / ready / failure`; a failed reload keeps the loaded config).
- **Android:** `INTERNET` permission, `usesCleartextTraffic="true"` (the local API is plain HTTP), and the label "HealthTick".
- Home/Journey/Search/Lesson pages are empty stubs for now (no text), filled in steps 8–9.
- Removed the template `test/widget_test.dart`, which tested the counter app.

**Decisions (Claude Code).**
- **freezed 3.2.5:** freezed 4.x requires Dart ≥ 3.13; this machine has Dart 3.12.2.
- **Mixed DTO approach:** json_serializable for flat DTOs, freezed for bloc states, and hand-written parsing for polymorphic lesson blocks,
  so unknown block/node types can be skipped or defaulted defensively (SPEC §8.5).
- **`DEMO_USER_ID` default** is the seeded demo user id; it's seed data rather than environment config, so the default keeps `flutter run` working.
- **CONTENT_CHANGED dialog text:** there is no copy key for it, so the dialog will show the server error message
  ("The lesson content changed during this attempt") with the `error.retry` label. This avoids hardcoded text.

**Bugs found and fixed.**
- Dio 5.11 added `DioExceptionType.transformTimeout`, so the error switch was non-exhaustive. It is now mapped to `TimeoutFailure`.
- A placeholder `typedef CheckedFromJsonException` was wrong; it now imports the real class from json_annotation.
- The AndroidManifest edit via a Node script silently did nothing because the file uses CRLF. Redone with the Edit tool and verified.

**Commands and tests actually run.**
- `flutter pub add …` (resolved; versions above). `dart run build_runner build --delete-conflicting-outputs` → "Built … wrote 3 outputs".
- `flutter analyze` → "No issues found!"
- `flutter test` → `00:02 +33: All tests passed!` Covers:
  - Markup parser and interpolation (nesting, tokens in formats, malformed fallback, paragraphs, "—", unknown tokens).
  - Error mapping (timeouts, connection/socket, envelopes incl. LESSON_LOCKED/NOT_FOUND/CONTENT_CHANGED, non-JSON → Parsing, unexpected).
  - ApiClient with a mocked Dio (envelope unwrap, DTO type mismatch → ParsingFailure).
  - Dio config and the X-User-Id interceptor; asset URL resolution.
  - SSE parser (chunks, CRLF, multi-line) and reconnect policy.
  - Bootstrap DTO, including a malformed payload; AppConfigCubit (bloc_test).

**Open issues.** None.

---

## 2026-10-13 — Session 1, Step 8: Home, Journey (layout engine first), Search

**Objective.** SPEC §13 step 8.

**What Claude Code did.**
- **Layout engine** (`journey/presentation/layout/journey_layout_engine.dart`, pure; written and tested first). SPEC §9.4 ratios:
  - Node `0.26W`, ring `0.035W`; card `0.9W×0.46W`; rows `0.49W` apart.
  - Centre row at `0.5W`, pair rows at `0.30W/0.72W`. A checkpoint takes its own centred row as a `0.39W×0.42W` arch, and the next card overlaps it by `0.12W`.
  - Connectors (stroke `0.025W`):
    - card→first node: straight vertical;
    - centre→left / left→centre: a cubic S-curve with both control points at `x=c`, so `x(½)=0.08W`;
    - left→right: straight;
    - right→centre: a curve reaching `0.92W`.
    - Completed colour if the END node is completed.
  - Hit rects are at least 48 dp.
- **Journey:**
  - Domain entities; defensive parsing (unknown type → lesson, unknown state → locked); `popoverActionFor` (§4.6).
  - Repository with ETag caching (`If-None-Match`, 304 → cached).
  - `JourneyCubit` (freezed): `loading / failure / loaded{selectedNodeId, activity: idle|reloading|refreshing, transientError+errorId, scrollToTopId, pulseNodeId}`.
    Actions: `load / reload / silentRefresh / selectNode / clearSelection / pulse`.
  - Widgets:
    - `JourneyPathView`: Stack of painter, cards and nodes, plus the popover and a barrier that closes it on an outside tap. The scroll height is extended so the popover fits; `Scrollable.ensureVisible` runs over 250 ms.
    - `StatusCard`: API colours, 8 dp solid offset shadow, illustration on the left 40%.
    - `JourneyNodeView`: ring drawn by Flutter, icon clipped to a circle, the bootstrap `lockedNode` asset for locked nodes, a green check badge, a 300 ms shake when locked, and a pulse.
    - `NodePopover`: width `min(0.84W, 340)`, clamped; 12 dp pointer; 180 ms fade+scale; state icons; primary button; "Completed On d MMM yyyy".
  - `JourneyPage`: app bar with back, title, outlined Reload/Search. Spinner, ErrorView+Retry, empty state, a reload overlay
    (200 ms fade, copy title/subtitle, scroll to top on success), and transient-error snackbars. A checkpoint opens its lesson directly.
    A locked tap shows the `journey.locked.message` snackbar.
- `open_lesson.dart`: pushes `/lesson/:id`. On return it refreshes Home and Journey, reopens the node's popover (not for checkpoints),
  and pulses `unlockedNodeId`.
- **Home:** `HomeDto` (json_serializable) → `HomeData`, and `HomeCubit` (silent refresh keeps data).
  `HomePage`: avatar initial, streak, health points, today's task + `JOURNEY ›`, task card (lesson, or all-done → Journey),
  a skeleton, ErrorView+Retry, pull-to-refresh.
- **Search:** DTO, repository, `SearchBloc` (300 ms debounce via a timer; request ids make sure only the latest response is applied;
  under 2 characters → empty state; sort re-runs immediately; retry). `SearchPage`: title `search.placeholder`, outlined autofocus
  field, a bottom-right sort menu (`search.sort.*`), and result rows with the "status · level · node" subtitle and a lock icon.
  A locked result → snackbar.
- DI registers the repositories, the app-wide cubits (AppConfig/Home/Journey) and a `SearchBloc` factory. `app.dart` provides the cubits.
- **Tests:**
  - `test/helpers/fixtures.dart`: test copy and journey JSON generators.
  - `test/helpers/harness.dart`: real theme and providers, a GoRouter with stub lesson/search routes, fake images, phone screen size.

**Decisions (Claude Code; details the SPEC leaves open).**
- **Engine spacings not fixed by the SPEC:**
  - top padding `0.04W`;
  - card bottom → first row centre `0.30W`;
  - last node → next card `0.20W` (when there's no checkpoint);
  - card → card `0.10W`;
  - bottom padding `0.12W`.
  - A single node left over in a pair row stays at `0.30W`.
- **Engine test "total height increases monotonically"** is checked as non-decreasing for every count 0–60. Adding the second node
  of a pair row legitimately does not add height. A separate test asserts strict growth whenever a new row is started.
- **Available nodes** use the same ring colour as completed ones (`#BDBDBD`), and the selected node gets a white ring. The SPEC defines only completed and locked ring colours.
- **The empty journey state** reuses `error.not_found.message` (no dedicated copy key exists) with Retry.
- **A locked checkpoint** renders the arch at 55% opacity with a lock icon.

**Bugs found and fixed.**
- Flutter's `Path.getBounds()` includes Bézier control points, so the first bounds assertions failed (−10.7 px).
  The engine was correct; the tests now sample the curve with `computeMetrics`.
- The hidden reload overlay kept an indeterminate spinner ticking, which made `pumpAndSettle` time out and would waste frames in the app.
  Now only the spinner is wrapped in `TickerMode(enabled: visible)`, so the overlay's fade-out still animates.
- The test harness's stub lesson page didn't receive taps (an empty `SizedBox` doesn't hit-test); added `HitTestBehavior.opaque`.
- Renamed the domain `CardTheme` to `StatusCardTheme` to avoid clashing with Material's `CardTheme`.

**Commands and tests actually run.**
- `dart run build_runner build --delete-conflicting-outputs` → "Built … wrote 10 outputs". `flutter analyze` → "No issues found!"
- `flutter test test/journey/journey_layout_engine_test.dart` → `+13: All tests passed!`
  (counts 0–60 × widths 320/360/411/480, with and without a checkpoint).
- `flutter test` → `00:11 +91: All tests passed!`. Covers:
  - Engine; journey DTO incl. malformed and unknown type/state; popover actions.
  - `JourneyCubit`: all states incl. silent-refresh failure keeping data.
  - `HomeCubit`; `SearchBloc`: debounce → 1 request, stale response ignored, under-2-chars, sort, failure→retry.
  - Widgets:
    - Journey with 1/7/25 nodes + checkpoint;
    - popover open, close, outside tap, DO IT AGAIN + Completed On;
    - START → lesson → return reopens the popover;
    - locked snackbar; checkpoint direct open;
    - loading, error+retry, empty, reload overlay, silent-refresh failure snackbar.
  - Home: content, task opens lesson, all-done, skeleton → error → retry.
  - Search: states, locked snackbar, sort menu.

**Open issues.** Not yet run on an emulator or device; that's planned for step 11.

---

## 2026-10-13 — Session 1, Step 9: lesson player

**Objective.** SPEC §13 step 9: blocks, questions, feedback, exit sheet, menu, completion.

**What Claude Code did.**
- **Domain/data:**
  - Sealed `LessonBlock` types, `Question`, `LessonPage`, `Lesson`, `AnswerFeedback`, `LessonCompletion`, `LessonRepository`.
  - Hand-written `lesson_dto.dart`: unknown or malformed blocks are **skipped with a debug log** and the page still renders.
    An unknown `responseType` renders the page as content.
  - `LessonRepositoryImpl`: GET lesson, POST attempts, PUT answers, POST complete/abandon, PUT/DELETE saved, POST feedback.
- **`LessonPlayerBloc`:**
  - SPEC §8.4 events: `Started, OptionToggled, TextChanged, CtaPressed, BackPressed, ExitConfirmed, RetryPressed, SaveToggled, FeedbackSubmitted`.
  - State (freezed): lesson, attemptId, pageIndex, answers per page, showingFeedbackFor, feedback, hpCounter, submitting,
    inlineError, completion, isSaved, plus loadFailure/feedback flags.
  - One-shot effects (`ToastEffect`, `ShowExitSheetEffect`, `ContentChangedEffect`, `FeedbackSentEffect`, `CloseEffect`) carry an `effectId`.
  - **CTA:**
    - content → next page (+1 counter), or complete on the last page;
    - question → local validation (`lesson.choice.validation_message`, or `lesson.free_text.validation_title` + the question's
      `validationMessage`), then PUT; feedback → card, otherwise advance;
    - feedback card → advance.
  - **Back:** feedback → question with the selection kept; page N>0 → N−1 (−1 counter); page 0 → exit sheet.
  - **Errors:**
    - `ExitConfirmed` → abandon fire-and-forget → pop `abandoned`.
    - Failed answer/complete → inline error + Retry, place kept.
    - `CONTENT_CHANGED` → dialog that restarts the lesson.
    - `LESSON_LOCKED`/`NOT_FOUND` → message, then pop.
  - `freeTextAnswers` feeds `{{answer.key}}`.
- **UI (`lesson_player_page.dart` + widgets):**
  - Top bar: back, a progress bar animated over 250 ms to `(pageIndex+1)/pageCount`, heart-pulse icon + counter.
  - `AnimatedSwitcher` 220 ms crossfade with a new scroll view per page (back to the top).
  - Bottom bar: inline error + Retry, full-width CTA with the content's label (spinner while submitting), ⋮.
  - **Blocks:** heading 22 bold; paragraph; bulleted/numbered lists; full-width image (radius 12, aspect ratio from the asset,
    shimmer, broken fallback); callout (56 dp icon + text); icon heading (24 dp + coloured bold text); accordion
    (chevron, 200 ms `AnimatedSize`); spacer.
  - **Questions:** option cards (radius-12 border, radio or checkbox, brighter border + filled indicator when selected);
    free text (min 4 lines, counter when `maxLength`).
  - **Feedback card:** illustration ~0.3W, bold centred headline, `answer_prefix` + **highlighted** correct answer(s), explanation paragraphs.
  - **Exit sheet:** title/message, confirm/cancel.
  - **⋮ menu:** Save row toggling `menu.save`/`menu.saved` with a check, plus the "DONE! Bookmark Added 😁" toast, and Send feedback.
  - **Feedback dialog:** bootstrap reasons as checkboxes, Other text field, footer, SUBMIT disabled until valid,
    `other_required` hint when Others is ticked, inline error on failure, toast on success.
  - **Completion screen:** medal (lesson asset or bootstrap medal) scales in over 400 ms with a light sparkle; headline,
    bordered message card, server `healthPointsEarned`, Continue → pop `completed` (+ `unlockedNodeId`).
  - Android system back is routed through `PopScope` to `BackPressed`.

**Decisions (Claude Code).**
- **Health-point counter** follows SPEC §4.12: +1 per forward page move (after the feedback card), −1 on Back, never below 0.
  Completing on the last page doesn't increment it. The completion screen shows the server's `healthPointsEarned` as "+N".
- **Option selection** is ignored while the feedback card is showing or a submit is in flight. Multiple choice ignores selections beyond `maxSelections`.
- **Free-text length** is counted in code points (`runes`), matching the backend.
- **Save** is optimistic and reverts with an error toast on failure.

**Bugs found and fixed.**
- **Real app bug:** the ⋮ button's tap handler called `context.bootstrap`, a provider `select`, outside `build`, which threw an assertion when tapped.
  Feedback reasons are now read during `build`.
- **Real UX bug:** floating toasts covered the bottom CTA, so a tap right after a validation toast hit the toast.
  `showToast` now floats above bottom bars (bottom margin 96).
- Test fixes, not app fixes:
  - The highlight check now walks nested spans.
  - The counter assertion reads the `Text` directly.
  - The CONTENT_CHANGED widget test now throws the real `AppException(ServerFailure('CONTENT_CHANGED'))`.
  - The fixture `completion` was renamed to avoid a clash with the `flutter_test` matcher of the same name.
- Lint `prefer_initializing_formals` → the bloc takes `required this.repository`.

**Commands and tests actually run.**
- `dart run build_runner build --delete-conflicting-outputs` → wrote 4 outputs. `flutter analyze` → "No issues found!"
- `flutter test test/lesson` → `00:05 +39: All tests passed!`
- `flutter test` → `00:15 +130: All tests passed!`. New lesson coverage:
  - DTO: every block type, unknown/malformed skipped, unknown response type, malformed lesson, answer and completion payloads.
  - Bloc, every §8.4 transition:
    - start, locked → close, load failure → retry;
    - content CTA; choice and free-text validation toasts;
    - graded → feedback → advance; ungraded advances directly;
    - failed submit → retry; completion + Continue exit; CONTENT_CHANGED; failed complete;
    - Back from feedback, page N and page 0; ExitConfirmed abandons;
    - selection rules; interpolation source; save success and revert; feedback error → success.
  - Widgets:
    - each block type incl. highlight colours and accordion expand; malformed markup → plain text;
    - progress and counter; single choice + feedback card + Back keeps selection; multiple choice; free text + interpolation;
    - inline error + Retry; exit sheet cancel/confirm; Android system back; ⋮ save toggle + toast;
    - feedback dialog validation (disabled → Others requires text → error → success toast);
    - completion screen; CONTENT_CHANGED restart.

**Open issues.** Not yet exercised against the real API on a device or emulator (step 11).

---

## 2026-10-13 — Session 1, Step 10: content sync, lifecycle refresh, final error states

**Objective.** SPEC §13 step 10.

**What Claude Code did.**
- `core/sync/content_sync_service.dart` (`ContentSyncService`, a `WidgetsBindingObserver`):
  - Owns the SSE stream (`SseClient.connect`). Reconnects using `ReconnectPolicy` (1/2/5/10/30 s, reset after a `hello`).
  - Tracks `lastVersion`: the first `hello` only records it; a newer `content_changed` or `hello` →
    `JourneyCubit.silentRefresh`, `HomeCubit.refresh`, `AppConfigCubit.load`, plus the `journey.updated.toast` **only if the Journey is visible**.
  - On a reconnect it always refetches silently, even when the version is unchanged (SPEC §10 "refetch on reconnect"; ETags keep it cheap).
  - App resume → silent refresh + immediate reconnect. Pause → the stream is closed (no background connection).
  - Never touches the lesson player, so a lesson in progress finishes with the content it loaded.
- **Journey visibility:** `JourneyPage` is now `RouteAware` through the router's `appRouteObserver` and sets `JourneyVisibility.instance.visible`.
- `app.dart`:
  - Starts and stops the sync service. App-level toasts go through a `scaffoldMessengerKey`, positioned above bottom bars.
  - `HealthTickApp(enableContentSync: false)` is available for tests.
- **Final error states:** every Retry (Home, Journey, Search, Lesson) also calls `context.reloadConfigIfFailed()`. If the API was down at
  start-up, copy recovers together with the screen. Before this, titles would have stayed on the empty/fallback copy until a content change.

**Decisions (Claude Code).**
- **Background pause:** the SSE stream is closed while the app is paused. The SPEC only requires a refresh on resume; this saves battery.
- **"Journey visible"** = the Journey route is the top route. Content changes while a lesson or Search is open still refresh the data, without a toast.

**Bugs found and fixed.**
- A Bash `node -e` command interpreted backticks in a doc comment as command substitution, producing an empty reference in a comment. Fixed the comment.

**Commands and tests actually run.**
- `flutter analyze` → "No issues found!"
- `flutter test test/core/content_sync_service_test.dart` → `+6: All tests passed!`. Covers:
  - First hello records the version; a newer change refreshes all three targets + toast.
  - Stale/duplicate/ping/garbage events are ignored.
  - No toast when the Journey isn't visible.
  - A dropped stream reconnects; a newer version → refresh + toast; same version → silent refetch.
  - Connect failures back off through the policy delays.
  - Pause closes / resume reconnects and refreshes.
- `flutter test` → `00:24 +138: All tests passed!`. New:
  - Lesson load failure → Retry recovers.
  - Home with the API down at start shows FallbackMessages; Retry reloads both the copy and the data.

**Open issues.** On-device verification is step 11.

---

## 2026-10-13 — Session 2, Step 11 (in progress): E2E on the emulator; paused by the user

**Context.** The previous Claude Code session ended mid-step (context/session limit). This session resumed from `git status` and the worklog.

**What Claude Code did.**
- **E2E test:** `integration_test/app_flow_test.dart` implements the SPEC §11.4 flow:
  Home → Journey → node 1 → welcome lesson → back (popover open) → finish node 1 → graded lesson in node 2 answered wrong → feedback card → complete → Home health total increased.
- **Gradle heap:** the first emulator build crashed the Gradle JVM. The Flutter template's `org.gradle.jvmargs=-Xmx8G` exceeds this machine's
  7.4 GB RAM (0.8 GB free with the emulator and Docker running). Lowered it to `-Xmx2G` (+ `kotlin.daemon.jvmargs=-Xmx1G`).
  Removed the JVM crash log and git-ignored `android/.kotlin/` and `hs_err_pid*.log`.
- **Manual run:** built a debug APK, installed it and screenshotted it. Home and Journey render live API data: streak 1, 23 points;
  card, path, centre/pair rows, S-curves, completed check, locked colours.

**Commands and tests actually run.**
- `npm run progress:reset`, then `flutter test integration_test/app_flow_test.dart -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:3000`
  → `01:54 +1: All tests passed!` (backend on the dev DB; emulator `Medium_Phone`, Android 16 KB page-size image).
- `flutter build apk --debug --dart-define=API_BASE_URL=http://10.0.2.2:3000`, `adb install`, then screenshots.

**Bugs found, not yet fixed (open).**
1. **Images don't render on the emulator.** Cards and node icons stay on the loading placeholder.
   - The PNGs *are* downloaded into `cache/libCachedImageData`, but the cache manager's sqflite database was never created (`databases/` is empty).
   - So `CachedNetworkImage`'s store never completes. Root cause not yet confirmed.
   - A diagnostic `flutter run` with verbose cache logging failed: the Dart compiler exited unexpectedly, probably low memory. The temporary
     logging line in `main.dart` was reverted.
   - The E2E test passed because it checks behaviour, not pixels.
2. The Home avatar initial is dark text on a dark circle (low contrast).

**User instruction.** The user asked to pause emulator testing, leave the code working and commit, then implement the journey fill
animation (next entry). Step 11 resumes afterwards.
