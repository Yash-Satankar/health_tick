# Implementation Plan — HealthTick Journey

Build order follows `docs/planning/SPEC.md` §13. Status is updated at the end of each step.

## Environment (recorded 2026-10-13, user's Windows machine `D:\HealthTick`)

| Tool | Version / status |
|---|---|
| OS | Windows 11 Home Single Language 10.0.26300 |
| Node | **v24.19.0**: deviation from SPEC §7.1 (Node 22 LTS), approved by the user 2026-10-13; `engines.node >=22` |
| npm | 11.17.0 |
| Flutter | 3.44.9 stable (framework 6b182d2c75, 2026-08-05) |
| Dart | 3.12.2 |
| Java | OpenJDK 25.0.2 (Android Studio `jbr`; `java` not on PATH, `JAVA_HOME` unset) |
| Android SDK | `%LOCALAPPDATA%\Android\Sdk`; platforms android-35/36/37.0; build-tools 36.0.0/37.0.0 |
| adb | 1.0.41 (`platform-tools`, not on PATH); no device attached at inspection |
| Emulator | 37.1.11.0; AVD `Medium_Phone` |
| Android licences | `flutter doctor`: "license status unknown" |
| Docker | Docker Desktop installed; **engine not running** at inspection |
| ffmpeg | not installed (optional; only for extracting video frames) |
| psql | not installed (not needed; Postgres runs in Docker) |

### Backend package versions (chosen in step 3)
| Package | Version | Note |
|---|---|---|
| express | 5.3.0 | |
| kysely / pg | 0.29.6 / 8.23.1 | |
| zod | 4.6.7 | |
| pino / pino-http | 10.4.0 / 11.0.0 | |
| helmet / cors | 8.3.0 / 2.8.6 | |
| yaml | 2.9.1 | extra: YAML seed parsing |
| typescript | 6.0.3 | 7.0.2 exists, but typescript-eslint 8.71 requires `<6.1` |
| tsx / vitest / supertest | 4.23.15 / 5.0.4 / 7.3.1 | |
| eslint / typescript-eslint / prettier | 10.12.0 / 8.71.2 / 3.9.10 | |
| kysely-codegen | 0.20.0 | |
| @types/node | ^22 | API surface pinned to Node 22 |

Flutter package versions are recorded here in step 7.

## Inputs check

| Input | Status |
|---|---|
| `docs/planning/SPEC.md` | ✅ present (draft v1, 703 lines) |
| `docs/planning/healthtick_schema_v1.sql` | ✅ present |
| `Resources/reference_pack/content/journey_content.yaml` | ✅ present (identical copy also at `Resources/journey_content.yaml`) |
| `Resources/reference_pack/assets/` | ✅ 45 PNGs + `manifest.json` |
| `Resources/reference_pack/README.md` | ✅ present |
| `Resources/WhatsApp Video 2026-10-12 at 22.24.20.mp4` | ✅ present (58 MB) |
| `user_journey/` | Stock `flutter create` counter template (SDK ^3.12.2, `cupertino_icons`, `flutter_lints`) |
| `user_journey_backend/` | Stock `express-generator` template (Express 4.16, Jade, plain JS, no DB). Will be replaced in step 3 |

Folder spelling: SPEC/brief say `Resouces/`; on disk it is `Resources/` (already in `.gitignore`).

## Steps (SPEC §13)

| # | Step | Status |
|---|---|---|
| 1 | Inspect environment & inputs; write CLAUDE.md + this plan | ✅ done |
| 2 | Docker Compose, root `.env.example`, `.gitignore` | ✅ done |
| 3 | Backend scaffold, config, logging, error handling, `/health`, test harness | ✅ done |
| 4 | Migration 001 (schema v1 verbatim), codegen, migrate test DB | ✅ done |
| 5 | Reference pack copy, Fluent Emoji download + attribution, seeder, validator, reset/demo scripts, seed dev DB | ✅ done |
| 6 | Modules: app-config, home, journey, lessons, attempts, search, saved, feedback, events (+ tests) | ⏳ |
| 7 | Flutter scaffold, theme, core layers (network, errors, SSE, markup, routing, DI) | ⏳ |
| 8 | Home, Journey (layout engine first, with tests), Search | ⏳ |
| 9 | Lesson player (blocks, questions, feedback, exit sheet, menu, completion) | ⏳ |
| 10 | Content sync, lifecycle refresh, final error states | ⏳ |
| 11 | Full test run, fixes, E2E if a device/emulator is available | ⏳ |
| 12 | Docs + worklog completion, release APK, final report | ⏳ |

## Manual verification checklist (SPEC §11.5)
Filled in during steps 8–12 (reference behaviours with video timestamps, real-time node-count change, APK on phone).
