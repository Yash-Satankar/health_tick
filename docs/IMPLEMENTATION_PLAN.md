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

### Flutter package versions (chosen in step 7; Flutter 3.44.9 / Dart 3.12.2)
| Package | Version | Note |
|---|---|---|
| flutter_bloc / bloc | 9.1.1 / 9.2.1 | |
| dio | 5.11.1 | |
| go_router | 18.0.2 | |
| get_it | 9.3.0 | |
| cached_network_image | 4.0.3 | |
| flutter_svg | 2.3.0 | listed in SPEC §8.1 |
| lottie | 3.6.1 | listed in SPEC §8.1 |
| intl | 0.20.2 | |
| freezed_annotation / freezed | 3.1.0 / 3.2.5 | freezed 4.x needs Dart ≥ 3.13; 3.2.5 is the newest stable for Dart 3.12 |
| json_annotation / json_serializable | 4.12.0 / 6.14.1 | |
| bloc_test / mocktail | 10.0.0 / 1.0.5 | |
| build_runner | 2.15.1 | extra (dev): required to run the freezed/json_serializable generators |
| integration_test | SDK | extra (dev, SDK): the SPEC §11.4 end-to-end test |

`cupertino_icons` (template default) was removed: not in SPEC §8.1.

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
| 6 | Modules: app-config, home, journey, lessons, attempts, search, saved, feedback, events (+ tests) | ✅ done |
| 7 | Flutter scaffold, theme, core layers (network, errors, SSE, markup, routing, DI) | ✅ done |
| 8 | Home, Journey (layout engine first, with tests), Search | ✅ done |
| 9 | Lesson player (blocks, questions, feedback, exit sheet, menu, completion) | ✅ done |
| 10 | Content sync, lifecycle refresh, final error states | ✅ done |
| 11 | Full test run, fixes, E2E if a device/emulator is available | ✅ done (emulator E2E passed; physical phone pending) |
| 12 | Docs + worklog completion, release APK, final report | ✅ done (APK: `user_journey/build/app/outputs/flutter-apk/app-release.apk`) |

### Post-SPEC change (2026-10-13)
**User-requested:** the path fill rule and fill animation. A segment is filled when the node it leads into is completed **or** available, and the fill flows along the path from the top. SPEC §9.4 is updated; see the worklog.

## Manual verification checklist (SPEC §11.5)

The timestamps come from the reference pack's provenance (manifest `source` and content YAML `provenance`). This machine has no ffmpeg, so
Claude Code did not re-extract frames. "✅" means verified on the Android emulator in session 2. "☐" means it still needs a manual check by the user, ideally on a phone.

| # | Reference behaviour | Video (s) | How to check | Status |
|---|---|---|---|---|
| 1 | Journey: Beginner card (LEVEL-1, illustration), centre/pair node rows, S-curves, checkpoint arch, Insider card | 5.6–17.2 | Open Journey, scroll | ✅ cards, icons, rows, curves (emulator screenshot); checkpoint/Insider ☐ (scroll) |
| 2 | Path fill flows from the top to the furthest unlocked node; locked sections dark | 4.9–6.2 | Open Journey / Reload | ✅ final state on emulator; partial state covered by widget test |
| 3 | Node popover: lessons with state icons, START/CONTINUE/DO IT AGAIN, "Completed On" | ~10–17 | Tap node 1 | ✅ via E2E (popover reopened after the lesson) ☐ visual |
| 4 | Welcome lesson: waving hand, numbered list 1–5, highlights, callout | 26–42 | Node 1 → START | ✅ played in E2E ☐ visual |
| 5 | Food zones: graded questions → "Not quite…" feedback card, highlighted correct answer, explanation; zone icon headings + accordions | 47–95 | Node 2 lesson | ✅ feedback card in E2E ☐ visual |
| 6 | Completion screen with medal, "You have won the day 😎" | 92 | Finish a lesson | ✅ E2E (+3 shown) |
| 7 | Mindful eating: testimonial image, highlighted bold list | 101–118 | Node 3 lesson | ☐ |
| 8 | Flavour centre: final graded question | 124–138 | Node 4 lesson | ☐ |
| 9 | Procrastination: ungraded multiple choice, two free-text answers, interpolated on the next page | 143–172 | Node 5 lesson | ☐ (widget-tested) |
| 10 | Visual hunger: graded recall question, callout with eyes | 180–192 | Node 6 lesson | ☐ |
| 11 | Checkpoint opens its lesson directly (no popover) and unlocks Insider | 196–199 | Tap checkpoint | ☐ (integration- and widget-tested) |
| 12 | Exit sheet, "Your progress will be lost", ⋮ menu Save Lesson toast, "Faced some issue ?" dialog | — | In any lesson | ☐ (widget-tested) |
| 13 | Real-time: `npm run demo:set-node-count -- --level insider_l2 --count 5` while the Journey is open | — | See README | ✅ emulator: toast + re-fetch about 2 s after commit; reverted to 3 |
| 14 | Reload overlay ("Reloading Your Journey") | — | Tap Reload | ☐ (widget-tested) |
| 15 | API stopped → every screen shows its error state and recovers on Retry | — | Stop `npm run dev` | ☐ (widget-tested per screen) |
| 16 | Release APK installs and runs the §11.4 flow on a phone over `adb reverse` | — | README "Release APK" | ☐ needs the user's phone |
