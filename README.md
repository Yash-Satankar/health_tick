# HealthTick Journey

## Submission overview

**What was built.** A working recreation of the HealthTick **Journey and lesson** feature. A Flutter Android app shows a minimal Home screen and
the Journey path: status/level cards and a dynamic node path whose fill animates up to the furthest unlocked node. It also has a node
popover, search, and a full lesson player with content blocks, single/multiple/free-text questions, a feedback card, an exit sheet,
save/feedback menus and a completion screen. Everything the app shows (node counts, titles, lesson text, labels, colours, feedback
headlines) comes from a Node.js/PostgreSQL backend that enforces the progress rules (unlocking, grading, points, streak) and pushes
content changes to the app in real time over Server-Sent Events.

**Tech stack.**
- **App:** Flutter 3.44 / Dart 3.12, flutter_bloc, freezed, json_serializable, dio, go_router, get_it, cached_network_image.
- **Backend:** Node.js 24 (≥ 22) / TypeScript strict, Express 5, Kysely + pg, Zod, pino, helmet; Vitest + Supertest.
- **Database:** PostgreSQL 16 in Docker; LISTEN/NOTIFY → SSE for real-time updates.

**Links.**
- Demo video: [Demo Video](https://drive.google.com/file/d/1FGYouHtjvntXfHgZcrLNMu0FejTukbU9/view?usp=sharing). It was recorded from an automated, scripted walkthrough (`integration_test`, profile build) running on a
  real device (OnePlus Nord CE, Android 13) against the local backend. The real-time step was triggered from the laptop.
  See [Recording the demo video](#recording-the-demo-video).
- APK (GitHub release v1.0.0): https://github.com/Yash-Satankar/health_tick/releases/download/v1.0.0/app-release.apk

**Important: the APK needs a locally running backend.** The release APK is built with `API_BASE_URL=http://localhost:3000` and talks to
the API on your PC through `adb reverse`:

```powershell
docker compose up -d                                   # Postgres (see Quick start for the one-time .env, migrate and seed)
cd user_journey_backend; npm run dev                   # API on http://localhost:3000
adb install -r app-release.apk                         # phone connected over USB with USB debugging on
adb reverse tcp:3000 tcp:3000                          # phone's localhost:3000 → PC's port 3000
```
Then open **HealthTick** on the phone. Without the backend running and `adb reverse` set up, the app shows its offline error state with Retry.

**Docs and AI history.**
- [`docs/planning/`](docs/planning/): the approved SPEC and schema from the planning chat.
- [`docs/AI_WORKLOG.md`](docs/AI_WORKLOG.md): the step-by-step record of the AI-assisted build.
- [`docs/ai-history/`](docs/ai-history/): the raw conversation exports.
- [`docs/IMPLEMENTATION_PLAN.md`](docs/IMPLEMENTATION_PLAN.md): versions, status and the manual verification checklist.
- [`docs/API_SPECIFICATION.md`](docs/API_SPECIFICATION.md) and [`docs/DATABASE_DESIGN.md`](docs/DATABASE_DESIGN.md).

**Known limitations.**
- The app has run on a physical phone (OnePlus Nord CE, Android 13; the profile build used for the demo walkthrough). The **release** APK
  itself was smoke-tested on the Android emulator with the same `adb reverse` setup. It is debug-signed.
- Most of the manual visual checklist against the reference video is still open. That behaviour is covered by widget, integration and end-to-end tests.
- Android only. Light theme, video mode, authentication, bottom navigation and offline disk caching of API data are out of scope.
- No authentication: the app identifies itself as the seeded demo user via `X-User-Id`.
- Lesson images are crops from a 576 px-wide recording, so they're slightly soft on high-DPI screens. Content that never appears in the
  reference is authored or a placeholder (marked by `provenance` in the content YAML).
- Deviations, approved by the user: Node 24 instead of 22; freezed 3.2.5 (freezed 4 needs a newer Dart); the Gradle heap was lowered to 2 GB.
  After the planning phase, the path fill rule and fill animation were corrected against the reference video (SPEC §9.4).

---

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

## Recording the demo video

`scripts/record-demo.ps1` records the demo end to end from a USB-connected phone. It needs Docker Postgres running, port 3000 free
(the script starts and owns its own API process), and [scrcpy](https://github.com/Genymobile/scrcpy) (`winget install --id Genymobile.scrcpy -e`).

```powershell
powershell -ExecutionPolicy Bypass -File scripts\record-demo.ps1 [-Device <adb serial>]
# → demo/demo_raw.mp4 (git-ignored), plus demo/shots/*.png verification screenshots and logs
```

What the script does:
1. Sets up the phone: `adb reverse`, show touches, Do Not Disturb, stay awake.
2. Resets the demo progress.
3. Runs `integration_test/demo_walkthrough_test.dart` with `flutter drive --profile`. This is a human-paced walkthrough.
4. Reacts to the `DEMO_MARKER:*` lines the test prints:
   - starts scrcpy recording;
   - changes the Insider node count to 5 and back to 3 (the real-time step);
   - stops the API and restarts it after 6 s (the offline step).
5. Finishes the recording cleanly by closing the scrcpy window, so the mp4 is finalised.
6. Restores the phone settings and resets progress.

Some phones (e.g. OnePlus/ColorOS) block changing global settings such as Do Not Disturb over adb unless *USB debugging (Security settings)* is enabled. In that case, turn on Do Not Disturb by hand.

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
