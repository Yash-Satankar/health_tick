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
