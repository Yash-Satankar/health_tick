# Claude Code prompt — HealthTick Journey

You are the implementation engineer for a technical assessment: recreate the **Journey and lesson feature** of the HealthTick health app. You'll build a Flutter app and a Node.js/Express/PostgreSQL backend. Every piece of UI data comes from the backend; the app only lays it out and renders it.

The requirements, architecture, database schema, API contract and content have **already been analysed and approved** in a separate planning session. Your job is to implement them faithfully, verify them with real test runs, and document the work truthfully. Do **not** redesign approved decisions.

---

## 1. Inputs (read all of them before changing anything)

| Path (repo root `D:/HealthTick`) | What it is |
|---|---|
| `docs/planning/SPEC.md` | **The authority.** Scope, domain rules, full API contract, layout measurements, state flows, error handling, test plan, build order (§13), acceptance criteria (§14) |
| `docs/planning/healthtick_schema_v1.sql` | Approved PostgreSQL schema. Becomes migration 001 **without changes** |
| `Resouces/reference_pack/content/journey_content.yaml` | All seed content and UI copy, with provenance tags |
| `Resouces/reference_pack/assets/` + `manifest.json` | 45 cropped illustrations; the manifest lists 9 Fluent Emoji assets to download or replace |
| `Resouces/reference_pack/README.md` | Pack notes and known limitations |
| `Resouces/*.mp4` | The original reference video (dark mode). Use it to check behaviour; if `ffmpeg` is available you may extract frames |
| `user_journey/`, `user_journey_backend/` | Initial scaffolding, possibly empty. Inspect it; don't assume what it contains |

**When sources disagree, the order of precedence is:** SPEC.md > schema > content YAML > video. If something genuinely isn't covered by any of them, **ask me** rather than inventing behaviour. Small implementation details that the spec leaves open (for example, an internal helper's name) are your call; record them in the worklog.

---

## 2. Working rules (also write these into a root `CLAUDE.md` so they persist across sessions)

1. **Inspect before you change anything:** Git status and branch, existing files, tool versions, running containers. Protect any uncommitted work you find.
2. **Never run destructive commands without my explicit approval.** This includes `git reset --hard`, `git clean`, force-push, deleting directories outside build outputs, dropping or recreating the **dev** database, or `docker volume rm`. Recreating `healthtick_test` inside the test harness is allowed.
3. **Never commit secrets.** `.env` files are git-ignored; commit `.env.example` files with placeholder values only. `Resouces/` is git-ignored.
4. **Follow SPEC §13 step by step.** After each step:
   - Run that step's checks.
   - Make a Conventional Commit, locally only.
   - Append to `docs/AI_WORKLOG.md`.
   - Update the status in `docs/IMPLEMENTATION_PLAN.md`.
   - Give me a short progress note.

   **Don't stop after planning or scaffolding.** Continue to a tested result unless there is a genuine blocker (a missing tool you can't install, a decision the spec doesn't cover, or a destructive action that needs my approval).
5. **Be truthful about tests.** Report a test as passing only if you ran it and it passed in this session, and quote the actual summary line. If something can't be run (no emulator, no network), say so and write down the exact manual steps.
6. **Fix problems; don't just list them.** When a test fails, find the root cause and fix it. Never weaken or skip a test to make it pass unless I approve. Record the bug and the fix in the worklog.
7. **No hardcoded UI data in Flutter.** Node counts, titles, lesson text, labels, colours of status cards, feedback headlines and menu text must all come from the API. The only exceptions:
   - Layout and theme tokens (SPEC §9).
   - The `FallbackMessages` class (SPEC §8.5).
8. **Keep dependencies lean.** Use only the packages listed in SPEC §7.1 and §8.1. If one more is genuinely needed, explain why in the worklog first.
9. **Don't push to GitHub without asking.** At the end, ask me before pushing to `origin`.

---

## 3. Environment notes

- **OS:** Windows. Use PowerShell-compatible commands, and keep npm scripts cross-platform (`tsx`, `cross-env` if needed). Docker Desktop is installed.
- **Database:** Postgres runs via `docker-compose.yml` on host port **5433** (SPEC §3.1). Node runs on the host, not in Docker.
- **Version check:** confirm Node (needs 22 LTS), npm, Flutter, Dart, Java/JDK, the Android SDK, `adb` and `ffmpeg`. Record the versions in `IMPLEMENTATION_PLAN.md`. If Node isn't 22, tell me before going further.
- **Fluent Emoji assets:**
  - Download the 9 assets listed with `replace_with` in `manifest.json` from `microsoft/fluentui-emoji` (MIT). Use the 3D PNGs.
  - Verify each path actually exists. Emoji with skin-tone variants keep their files under `Default/3D/`.
  - Save each with the manifest's file name and add `static/assets/ATTRIBUTION.md`.
  - If a download fails, keep the existing crop (for the 5 replacements) or tell me (for the 4 new assets). Don't substitute other artwork silently.
- **App on a device:** a physical phone reaches the API via `adb reverse tcp:3000 tcp:3000` with `API_BASE_URL=http://localhost:3000`. The emulator uses `http://10.0.2.2:3000`.

---

## 4. What "done" means

Everything in **SPEC §14 (acceptance criteria)** is met and verified, including:

- **Backend:** migrations, seed (idempotent), `content:validate`, all modules, SSE real-time updates and the scripts in SPEC §7.6.
- **Flutter:**
  - The Home, Journey (layout engine), Search and lesson player screens.
  - The content sync service.
  - Every loading, empty, error and retry state.
- **Tests:** all tests in SPEC §11, **actually run and passing**. Run the end-to-end test if an emulator or device is available.
- **Docs:** `README.md`, `docs/API_SPECIFICATION.md`, `docs/DATABASE_DESIGN.md`, `docs/IMPLEMENTATION_PLAN.md` and `docs/AI_WORKLOG.md`, all accurate (SPEC §12). Also `docs/ai-history/README.md`, explaining that it holds the raw conversation exports I'll add.
- **APK:** a release build via `flutter build apk --release` with the dart-defines, if the toolchain allows. Report the output path.

---

## 5. AI worklog rules (`docs/AI_WORKLOG.md`)

The assessors will read this file, so it must be honest and useful.

- **Append only.** One entry per step or session, never rewritten or backdated. If an earlier entry was wrong, add a correction entry.
- **Entry contents:**
  - Date.
  - Objective.
  - *My instructions*, briefly summarised.
  - *What Claude Code did*.
  - Decisions and their rationale.
  - Files created or modified.
  - Bugs found and fixed.
  - **Commands and tests actually run, with their results.**
  - Open issues.
- **First entry:** note that requirements, schema, API, spec, content transcription and asset crops were produced in a prior Claude chat planning session. The raw export of that session will be in `docs/ai-history/`.
- **Attribution:** never attribute my decisions to yourself, or yours to me.

---

## 6. Reporting

- **After each step:** 3–6 lines covering what was done, the checks run with results, and what comes next.
- **Final report:**
  - The completed features, mapped to each SPEC §14 criterion (met / not met / partially, with evidence).
  - Files and folders created.
  - Final test summary lines (backend and Flutter).
  - How to run everything (the README's short path).
  - The APK location.
  - Known limitations and anything still outstanding.
  - A reminder for me to export this Claude Code session (with `/export`, or by copying the session file) into `docs/ai-history/`.

## 7. Resuming in a new session

If you're starting fresh or your context was reset, first read `CLAUDE.md`, `docs/IMPLEMENTATION_PLAN.md` and the latest `docs/AI_WORKLOG.md` entries. Then check `git log` and continue from the first unfinished step.

---

**Begin with SPEC §13 step 1: inspect the environment and inputs, write `CLAUDE.md` and `docs/IMPLEMENTATION_PLAN.md`, report what you found, then continue.**
