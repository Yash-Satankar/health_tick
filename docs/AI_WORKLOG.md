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
