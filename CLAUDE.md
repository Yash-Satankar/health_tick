# CLAUDE.md — HealthTick Journey

Persistent working rules for Claude Code sessions in this repository.

## Project
Recreate the HealthTick **Journey + lesson** feature:
- `user_journey/`: Flutter app. It only lays out and renders; all UI data comes from the API.
- `user_journey_backend/`: Node.js / Express 5 / PostgreSQL backend (TypeScript strict).

## Authoritative inputs (precedence order)
1. `docs/planning/SPEC.md`: scope, API contract, layout, state flows, tests, build order §13, acceptance §14
2. `docs/planning/healthtick_schema_v1.sql`: becomes migration 001 **verbatim**
3. `Resources/reference_pack/content/journey_content.yaml` (+ `assets/`, `assets/manifest.json`, `README.md`)
4. `Resources/*.mp4`: reference video (dark mode)

Note: the SPEC and brief spell the folder `Resouces/`; on disk it is `Resources/`. Use the on-disk path.

If something is not covered by any of these, **ask the user** rather than inventing behaviour.
Small open implementation details are Claude's call and must be recorded in `docs/AI_WORKLOG.md`.

## Working rules
1. Inspect before changing: git status/branch, existing files, tool versions, running containers. Protect uncommitted work.
2. No destructive commands without explicit approval: `git reset --hard`, `git clean`, force-push, deleting dirs outside
   build outputs, dropping/recreating the **dev** DB, `docker volume rm`. Recreating `healthtick_test` inside the test harness is allowed.
3. Never commit secrets. `.env` files are git-ignored; commit `.env.example` with placeholders only. `Resources/` (and `Resouces/`) are git-ignored.
4. Follow SPEC §13 step by step. After each step: run its checks → Conventional Commit (local only) → append to
   `docs/AI_WORKLOG.md` → update `docs/IMPLEMENTATION_PLAN.md` → short progress note (3–6 lines).
   Don't stop after planning/scaffolding unless genuinely blocked (missing tool, uncovered decision, destructive action).
5. Be truthful about tests: report a pass only if it was run in this session; quote the actual summary line.
   If something can't be run, say so and write the exact manual steps.
6. Fix root causes; never weaken or skip a test without approval. Record bugs + fixes in the worklog.
7. No hardcoded UI data in Flutter (node counts, titles, lesson text, labels, status-card colours, feedback headlines,
   menu text). Only exceptions: layout/theme tokens (SPEC §9) and the `FallbackMessages` class (SPEC §8.5).
8. Lean dependencies: only packages in SPEC §7.1 / §8.1. Justify any addition in the worklog *before* adding it.
9. Never push to GitHub without asking the user.

## Environment
- Windows 11. Use PowerShell-compatible commands; npm scripts must be cross-platform (`tsx`, `cross-env`).
- Postgres via `docker-compose.yml` on host port **5433**; Node runs on the host, not in Docker.
- Android SDK: `%LOCALAPPDATA%\Android\Sdk` (adb in `platform-tools`, AVD `Medium_Phone`). JDK: Android Studio `jbr`.
- Device: `adb reverse tcp:3000 tcp:3000` + `--dart-define=API_BASE_URL=http://localhost:3000`.
  Emulator: `http://10.0.2.2:3000`.

## Worklog (`docs/AI_WORKLOG.md`)
Append only. Never rewrite or backdate; add a correction entry instead. Each entry has: date, objective, the user's instructions
(summary), what Claude Code did, decisions + rationale, files created/modified, bugs found/fixed, commands and tests
**actually run** with results, and open issues. Never attribute the user's decisions to Claude or vice versa.

## Resuming in a new session
Read this file, `docs/IMPLEMENTATION_PLAN.md`, the latest `docs/AI_WORKLOG.md` entries and `git log`, then continue
from the first unfinished step.
