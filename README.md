# HealthTick Journey

A recreation of the HealthTick **Journey and lesson** feature:

- `user_journey/`: Flutter app (Android). It only lays out and renders. Every title, label, colour, lesson text, feedback headline and node count comes from the API.
- `user_journey_backend/`: Node.js + Express 5 + PostgreSQL API (TypeScript strict, Kysely, Zod) with real-time updates over Server-Sent Events.

Docs: [API specification](docs/API_SPECIFICATION.md) · [Database design](docs/DATABASE_DESIGN.md) ·
[Implementation plan](docs/IMPLEMENTATION_PLAN.md) · [AI worklog](docs/AI_WORKLOG.md)

---

## Prerequisites

| Tool | Version used | Notes |
|---|---|---|
| Docker Desktop | 29.x | Postgres 16 runs in Docker on host port **5433** |
| Node.js | ≥ 22 (built and tested on 24.19) | npm 10+ |
| Flutter | 3.44.x (Dart 3.12) | `flutter doctor` should be green for Android |
| Android SDK + emulator or phone | API 35+ | `adb` from `platform-tools` |

## Quick start (short path)

```powershell
# 1. Database
copy .env.example .env                       # Postgres credentials for docker compose
docker compose up -d                         # creates healthtick_dev + healthtick_test

# 2. API
cd user_journey_backend
copy .env.example .env                       # use the same password as the root .env
npm install
npm run db:migrate
npm run db:seed                              # validates + seeds content and the demo user
npm run dev                                  # http://localhost:3000  (GET /health)

# 3. App (new terminal; Android emulator running)
cd user_journey
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000
```

## Environment

- **Root `.env`** (docker compose): `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_HOST_PORT` (default 5433).
- **`user_journey_backend/.env`** is validated with Zod at start-up; the process exits if any value is invalid.

  | Var | Example |
  |---|---|
  | `NODE_ENV` | `development` |
  | `PORT` | `3000` |
  | `DATABASE_URL` | `postgres://healthtick:<pw>@localhost:5433/healthtick_dev` |
  | `TEST_DATABASE_URL` | `postgres://healthtick:<pw>@localhost:5433/healthtick_test` (must end in `_test`) |
  | `LOG_LEVEL` | `info` |
  | `CORS_ORIGINS` | `*` |
  | `SSE_HEARTBEAT_MS` | `25000` |
  | `APP_TIMEZONE` | `Asia/Kolkata` |
  | `DEMO_USER_ID` | `00000000-0000-4000-8000-000000000001` |

- **Flutter** (`--dart-define`):
  - `API_BASE_URL`: default `http://10.0.2.2:3000` (the emulator's alias for the host).
  - `DEMO_USER_ID`: default is the seeded demo user.

## Backend scripts

| Script | What it does |
|---|---|
| `npm run dev` / `npm start` | API with watch / without watch |
| `npm run db:migrate` / `db:migrate:test` | Applies migration 001 (the approved schema, verbatim) |
| `npm run db:codegen` | Regenerates `src/db/types.ts` from the dev DB (kysely-codegen) |
| `npm run content:validate` | Validates `seed/journey_content.yaml`, the asset manifest and the asset files; exits 1 on failure |
| `npm run db:seed` | Validates, then upserts all content by key in one transaction. Idempotent: a rerun writes nothing |
| `npm run progress:reset [-- --user <uuid>]` | Clears a user's progress (default: the demo user) |
| `npm run demo:set-node-count -- --level <levelKey> --count <n>` | Changes the number of published lesson nodes in a level (real-time demo) |
| `npm test` | Unit + integration tests (rebuilds `healthtick_test` from scratch) |
| `npm run lint` / `typecheck` / `format:check` | ESLint / tsc / Prettier |

## Running the app

**Emulator**

```powershell
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000
```

**Physical phone over USB** (the API stays on your PC):

```powershell
adb reverse tcp:3000 tcp:3000
flutter run --dart-define=API_BASE_URL=http://localhost:3000
```

## Tests

```powershell
# Backend (needs Docker Postgres running)
cd user_journey_backend
npm test                      # → Test Files 14 passed, Tests 136 passed

# Flutter
cd user_journey
flutter analyze
flutter test                  # → +145: All tests passed!

# End-to-end (emulator + API on the dev DB)
cd user_journey_backend; npm run progress:reset; npm run dev
cd user_journey
flutter test integration_test/app_flow_test.dart --dart-define=API_BASE_URL=http://10.0.2.2:3000
```

The E2E test plays: Home → Journey → node 1 → welcome lesson → back (popover reopened) → the rest of node 1 → a graded lesson
answered wrong (feedback card) → complete → the health-point total on Home increased. It needs a fresh demo user
(`progress:reset`).

## Release APK

```powershell
cd user_journey
flutter build apk --release --dart-define=API_BASE_URL=http://localhost:3000 --dart-define=DEMO_USER_ID=00000000-0000-4000-8000-000000000001
# → build/app/outputs/flutter-apk/app-release.apk
adb install -r build/app/outputs/flutter-apk/app-release.apk
adb reverse tcp:3000 tcp:3000      # API on your PC at :3000
```

The APK is signed with the debug key (Flutter template default). For an emulator build, use `API_BASE_URL=http://10.0.2.2:3000`.

## Demonstrating real-time changes

1. Run the API and open the app on the Journey page.
2. In another terminal: `npm run demo:set-node-count -- --level insider_l2 --count 5`
3. Within about 2 seconds the app shows "Your journey was updated" and the Insider level has 5 nodes (Day 10 and Day 11 added), with no user action.
4. Revert with `--count 3`. Nodes are unpublished, never deleted. `npm run db:seed` also restores the YAML journey.

How it works: content triggers bump `content_state.version` and `NOTIFY content_changed`. The API holds one shared `LISTEN`
connection, coalesces the burst of notifications from one transaction, and pushes a single `content_changed` SSE event. The app's
`ContentSyncService` refreshes Journey, Home and copy silently, and the path fill animates only the newly unlocked part.

## Project structure

```
docker-compose.yml, docker/postgres/init.sql     Postgres 16 (dev + test databases)
user_journey_backend/
  src/app.ts, server.ts, container.ts             Express app (no listen), server + graceful shutdown, DI wiring
  src/config/env.ts                               Zod-validated environment
  src/db/                                         Kysely, migrations (001 = schema v1 verbatim), LISTEN client
  src/lib/                                        errors, markup validator, rng, time/streak, assets
  src/middleware/                                 requestId, userContext, validate, notFound, errorHandler
  src/modules/<feature>/                          app-config, home, journey, lessons, attempts, search, saved, feedback, events
                                                  (routes / controller / service / repository / schemas)
  src/content/, src/admin/                        content schema + validator, seeder, demo/reset scripts
  seed/journey_content.yaml, seed/asset-manifest.json, static/assets/
  scripts/, test/{unit,integration,helpers}
user_journey/
  lib/core/                                       config, network (Dio, SSE), errors, copy, markup, routing, theme, widgets, sync
  lib/features/{app_config,home,journey,search,lesson}/{data,domain,presentation}
  test/, integration_test/
docs/                                             API, database, plan, AI worklog, ai-history/
```

## Known limitations

- Android only. Light theme, video mode, authentication, bottom navigation and offline disk caching of API data are out of scope (SPEC §1).
- No authentication: the app sends the seeded demo user's id in `X-User-Id`.
- The lesson images are crops from a 576 px-wide recording, so they are slightly soft on high-DPI screens.
- Lesson bodies that never appear in the reference are authored or placeholders (marked by `provenance` in the content YAML).
- The release APK is debug-signed.
