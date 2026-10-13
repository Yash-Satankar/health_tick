# HealthTick Journey — Implementation Specification v1

Status: **draft for approval**. Once approved, this file is the authority for the build.
Precedence when sources disagree: **this SPEC > `healthtick_schema_v1.sql` > `reference_pack/content/journey_content.yaml` > the reference video**. Anything not covered here must be raised as a question, not invented.

---

## 1. Scope

**In scope**
- Minimal Home: avatar initial, streak, health points, "today's task" card, JOURNEY link.
- Journey page: status/level cards, dynamic node path, popover, Reload, Search, real-time updates.
- Lesson player: content pages, question pages (single, multiple, free text), feedback card, exit sheet, ⋮ menu (Save Lesson, Send feedback), completion screen.
- Search screen.
- Backend: Express + PostgreSQL implementing everything above; seed, validate, reset and demo scripts.
- Tests, documentation, AI worklog, Android APK.

**Out of scope**
- Video mode, authentication, health gems, trackers, bottom navigation, light theme, admin UI, localisation beyond `en`, offline caching to disk, iOS build.

---

## 2. Repository layout

The Git repository root is `D:/HealthTick` (remote `github.com/Yash-Satankar/health_tick`).

```
D:/HealthTick/
  docker-compose.yml          Postgres for dev + test
  docker/postgres/init.sql    creates healthtick_dev and healthtick_test
  docs/
    IMPLEMENTATION_PLAN.md
    API_SPECIFICATION.md
    DATABASE_DESIGN.md
    AI_WORKLOG.md
    ai-history/               raw exported conversations (added by the user)
  user_journey/               Flutter app
  user_journey_backend/       Express API
    seed/journey_content.yaml       copied from reference_pack
    seed/asset-manifest.json        copied from reference_pack/assets/manifest.json
    static/assets/*.png             copied from reference_pack/assets
    static/assets/ATTRIBUTION.md    Fluent Emoji (MIT) attribution
  Resouces/                   reference video + reference_pack (NOT committed; add to .gitignore)
  README.md
```

---

## 3. Environment and configuration

### 3.1 Docker
- Service `postgres`, image `postgres:16-alpine`.
- Host port `5433` → container port `5432`.
- Named volume for data.
- Healthcheck: `pg_isready`.
- The init script creates `healthtick_dev` and `healthtick_test`.
- Credentials come from the root `.env`, with a committed `.env.example`.

### 3.2 Backend environment
All variables are validated with Zod at startup; the process exits with a clear message if any is invalid.

| Var | Example | Notes |
|---|---|---|
| `NODE_ENV` | development | development / test / production |
| `PORT` | 3000 | |
| `DATABASE_URL` | postgres://healthtick:healthtick@localhost:5433/healthtick_dev | |
| `TEST_DATABASE_URL` | …/healthtick_test | Tests refuse to run against any database whose name doesn't end in `_test` |
| `LOG_LEVEL` | info | |
| `CORS_ORIGINS` | * (dev) | Comma-separated list |
| `SSE_HEARTBEAT_MS` | 25000 | |
| `APP_TIMEZONE` | Asia/Kolkata | Used for streak and "today" |
| `DEMO_USER_ID` | 00000000-0000-4000-8000-000000000001 | Used by the seeder and scripts only |

### 3.3 Flutter
Configuration is passed with `--dart-define`:
- `API_BASE_URL`: default `http://10.0.2.2:3000` for the emulator. Use `http://localhost:3000` with `adb reverse tcp:3000 tcp:3000` for a USB-connected phone.
- `DEMO_USER_ID`: the seeded demo user's UUID.

Nothing environment-specific is hardcoded.

### 3.4 Asset URLs
The API returns asset URLs **relative** to the API origin, for example `/static/assets/node_psychology.png`. Flutter resolves them against `API_BASE_URL`. This means the emulator and a physical device both work without changing backend configuration.

---

## 4. Domain rules (server is the authority)

### 4.1 Ordering and visibility
- **Global order:** `status.position`, then `level.position`, then `node.position`. Within a node, lessons are ordered by `lesson.position`, and within a lesson, pages by `page.position`.
- **Visibility:** only rows with `is_published = true` are returned or counted. An unpublished parent hides all of its children.

### 4.2 Node state (per user)
- `completed`: a `user_node_completions` row exists.
- `available`: not completed, and either it is the first published node in global order, or the node immediately before it is `completed`.
- `locked`: otherwise.

A completed node stays completed even if lessons are added to it later.

### 4.3 Lesson state (per user)
- `completed`: a `user_lesson_progress` row exists.
- `available`: the node is not locked and the lesson isn't completed. A lesson is also available if the node is `completed`, so every lesson in a finished node can be replayed. For a node that is only `available`, a lesson is available only if it is the first lesson or the previous lesson is completed.
- `locked`: otherwise.

### 4.4 Node completion
When a lesson is completed, if every published lesson in its node now has a progress row, insert into `user_node_completions` in the **same transaction**.

### 4.5 Checkpoint
- A checkpoint node has exactly one lesson (enforced by the content validator).
- Tapping an available or completed checkpoint opens its lesson directly, with no popover.
- Tapping a locked checkpoint behaves like tapping any locked node.

### 4.6 Popover primary button
| Node state | Label (`app_copy` key) | Opens |
|---|---|---|
| completed | `journey.popover.do_it_again` | the first lesson |
| available, no lesson completed yet | `journey.popover.start` | the first lesson |
| available, at least one lesson completed | `journey.popover.continue` | the first available, not-completed lesson |

Lesson rows can be tapped when their state is not `locked`.

### 4.7 Attempts
- `POST /lessons/:id/attempts` returns 403 `LESSON_LOCKED` if the lesson is locked. Otherwise it creates an `in_progress` attempt that records the current `content_version`.
- An answer can only be submitted for an `in_progress` attempt that belongs to the requesting user; for any other user's attempt, return 404 `NOT_FOUND`. The page must be a question page of the attempt's lesson.
- **Grading:**
  - `single_choice`: exactly one option id.
  - `multiple_choice`: between `min_selections` (default 1) and `max_selections` (default unlimited) distinct ids.
  - `free_text`: the trimmed text must meet `min_length` (default 1) and `max_length` (default 2000).
  - Invalid input returns 422 `ANSWER_INVALID`.
  - A graded question is correct only if the selected set **exactly equals** the set of correct options. Ungraded questions get `is_correct = null` and no feedback.
- **Feedback message:** weighted random choice among active messages for the outcome. The random number generator must be injectable so tests are deterministic.
- **Re-answering:** answering the same page again in the same attempt replaces the previous answer (upsert answer, replace selected options).

### 4.8 Completing an attempt (single transaction; attempt row locked with `SELECT … FOR UPDATE`)
1. If the attempt is already `completed`, return the stored result. This makes the call idempotent: it awards nothing new and returns the same response fields.
2. If the attempt is `abandoned`, return 409 `ATTEMPT_NOT_ACTIVE`.
3. Every current question page of the lesson must have an answer in this attempt.
   - If any are missing and `attempt.content_version` differs from the current version, return 409 `CONTENT_CHANGED`.
   - If any are missing and the version is the same, return 422 `INCOMPLETE_ATTEMPT`.
4. Points:
   - On the first completion of this lesson by this user, `healthPointsEarned` equals the number of published pages in the lesson.
   - On any later completion it is 0.
   - When points are earned, write a ledger row (`reason = lesson_completed`, `lesson_attempt_id`) and increment `users.health_points_total` in the same transaction.
5. Upsert `user_lesson_progress`: set `first_completed_at` once; update `last_completed_at` and `completion_count` every time.
6. Apply the node-completion rule (4.4). Compute `unlockedNodeId`: the next node in global order that became `available` in this transaction, or `null`.
7. Mark the attempt `completed`, storing `completed_at` and `health_points_earned`.

### 4.9 Abandon
Moves an `in_progress` attempt to `abandoned`. Abandoning an already abandoned attempt succeeds silently; abandoning a completed attempt returns 409.

### 4.10 Streak and today's task
- **Streak:** the number of consecutive calendar days in `APP_TIMEZONE` that have at least one completed attempt, ending today or yesterday. Otherwise it is 0.
- **Today's task:** the first `available`, not-completed lesson in global order, or `null` if every lesson is completed.

### 4.11 Text interpolation (client side)
- `{{user.name}}` is replaced with `bootstrap.user.displayName`.
- `{{answer.<key>}}` is replaced with the free-text answer the user gave for that key earlier in the **current attempt**. If there is none, it is replaced with `—`.
- Unknown tokens are rendered literally and logged.

### 4.12 Lesson health-point counter (client display only)
- Starts at 0.
- Goes up by 1 each time the user moves forward to the next page (after the feedback card, if there is one).
- Goes down by 1 on Back.
- The completion screen shows the server's `healthPointsEarned`; the header total comes from the server.

---

## 5. Inline markup

The grammar applies inside `text`, list `items` and `explanation`.

- **Formatting:** `**bold**`, `*italic*`, `==highlight==`. Formats can nest.
- **Tokens:** `{{user.name}}` and `{{answer.key}}`.
- **Line breaks:** a blank line in an `explanation` starts a new paragraph.

Validation and rendering rules:
- **Server:** the seed validator rejects unbalanced markers.
- **Flutter:** a pure parser converts the markup into styled text spans. Malformed input falls back to plain text and never throws.
- **Highlight style:** pale green background `#D9F2C4` with near-black text `#111111`, matching the reference.

---

## 6. REST API (`/api/v1`)

### 6.1 Conventions
- **User header:** every route except `/health` and `/static` requires `X-User-Id` (a UUID). If it is missing or not a valid UUID, return 401 `USER_NOT_IDENTIFIED`. If no such user exists, also return 401.
- **Success response:** `{ "data": … }`.
- **Error response:** `{ "error": { "code", "message", "details?", "requestId" } }`.
- **Request ID:** every response includes an `X-Request-Id` header, echoed from the request or generated.
- **Validation:** Zod validates params, query and body. Unknown body fields are rejected.

**Asset object** (used in many responses):
`{ "url": "/static/assets/x.png", "width": 112, "height": 112, "alt": "…", "format": "png" }`

| Code | HTTP | When |
|---|---|---|
| `VALIDATION_ERROR` | 400 | Bad params, query or body shape |
| `USER_NOT_IDENTIFIED` | 401 | Missing, invalid or unknown user |
| `LESSON_LOCKED` | 403 | Lesson or attempt start on a locked lesson |
| `NOT_FOUND` | 404 | Unknown or unpublished id, or a resource belonging to another user |
| `ATTEMPT_NOT_ACTIVE` | 409 | Answer or complete on a non-active attempt |
| `CONTENT_CHANGED` | 409 | See 4.8 |
| `ANSWER_INVALID` | 422 | Answer violates the question's rules |
| `INCOMPLETE_ATTEMPT` | 422 | See 4.8 |
| `FEEDBACK_INVALID` | 422 | No reason and no comment, or "Others" ticked without a comment |
| `INTERNAL_ERROR` | 500 | Anything unexpected. No stack trace or SQL is ever sent to the client |

### 6.2 Endpoints

**`GET /health`** (no header) → `{ "data": { "status": "ok", "db": "ok" } }`. Returns 503 with `db: "unavailable"` if the database is unreachable.

**`GET /bootstrap`**
```json
{ "data": {
  "contentVersion": 42,
  "user": { "id": "…", "displayName": "Yash", "healthPointsTotal": 37 },
  "copy": { "journey.title": "Your Journey", "…": "…" },
  "assets": { "lockedNode": {"url":"…"}, "completionMedal": {"url":"…"} },
  "feedbackReasons": [ { "id": "…", "key": "others", "label": "Others", "requiresText": true } ]
} }
```

**`GET /home`**
```json
{ "data": {
  "user": { "displayName": "Yash", "healthPointsTotal": 37, "streakDays": 2 },
  "todayTask": { "lessonId": "…", "lessonTitle": "Keystone Habit #3: …", "nodeId": "…", "statusTitle": "Beginner" }
} }
```
`todayTask` is `null` when everything is completed.

**`GET /journey`**
- Response header `ETag: W/"c{contentVersion}-p{userProgressStamp}"`, where `userProgressStamp` is the epoch-ms of the user's latest completion (0 if none).
- If the request's `If-None-Match` matches, respond 304.

```json
{ "data": {
  "contentVersion": 42,
  "statuses": [ {
    "id": "…", "key": "beginner", "title": "Beginner",
    "cardTheme": { "backgroundColor": "#F9E4C9", "shadowColor": "#DBC4A5", "textColor": "#1C1C1C" },
    "levels": [ {
      "id": "…", "key": "beginner_l1", "label": "LEVEL-1", "title": "Psychology of weight",
      "illustration": { "url": "…" },
      "nodes": [ {
        "id": "…", "key": "beginner_day_1", "type": "lesson", "title": "Day 1",
        "icon": { "url": "…" }, "state": "completed", "completedAt": "2026-10-12T10:00:00Z",
        "lessons": [ { "id": "…", "title": "Welcome to Health Tick!", "state": "completed", "completedAt": "…" } ]
      } ]
    } ]
  } ]
} }
```

**`GET /lessons/search?q=&sort=relevance|journey&limit=`**
- `q`: trimmed, 2 to 100 characters.
- `limit`: 1 to 50, default 20.
- Matching combines full-text search with trigram similarity on the title, which allows partial words.
- `relevance` ranks by `ts_rank` plus similarity; `journey` sorts by global order.
- Placeholder and unpublished lessons follow the normal visibility rules.

```json
{ "data": { "query": "procrast", "results": [ {
  "lessonId": "…", "title": "Procrastination for health", "summary": "",
  "nodeId": "…", "nodeTitle": "Day 5", "levelLabel": "LEVEL-1", "statusTitle": "Beginner", "state": "completed"
} ] } }
```

**`GET /lessons/:lessonId`** returns 403 `LESSON_LOCKED` if the lesson is locked. **Never include `is_correct`.**
```json
{ "data": {
  "id": "…", "title": "…", "nodeId": "…", "nodeType": "lesson", "isSaved": false, "pageCount": 13,
  "pages": [ {
    "id": "…", "position": 0, "type": "question", "ctaLabel": "NEXT",
    "blocks": [ { "id": "…", "type": "paragraph", "text": "First question is - *What is Calorie Density?*" } ],
    "question": {
      "responseType": "single_choice", "isGraded": true,
      "minSelections": null, "maxSelections": 1,
      "answerKey": null, "inputPlaceholder": null, "minLength": null, "maxLength": null,
      "validationMessage": null,
      "options": [ { "id": "…", "label": "The total calories I eat in one day" } ]
    }
  } ]
} }
```
Block shapes (each also has `id` and `type`):

| Type | Fields |
|---|---|
| `heading` | `text` |
| `paragraph` | `text` |
| `bulleted_list` / `numbered_list` | `items[]` |
| `image` | `asset` |
| `callout` | `text`, `asset` |
| `icon_heading` | `text`, `color`, `asset?` |
| `accordion` | `title`, `children[]` |
| `spacer` | `size` |

**`POST /lessons/:lessonId/attempts`** → 201
`{ "data": { "attemptId": "…", "lessonId": "…", "startedAt": "…", "contentVersion": 42 } }`

**`PUT /attempts/:attemptId/answers/:pageId`**
- Body: `{ "optionIds": ["…"] }` **or** `{ "text": "…" }` (exactly one of the two).
- Response 200:
```json
{ "data": { "pageId": "…", "isCorrect": false, "feedback": {
  "headline": "Not quite, but I appreciate your effort.",
  "illustration": { "url": "…" },
  "correctAnswers": ["The number of calories in a food per gram of its weight"],
  "explanation": "…or null"
} } }
```
`feedback` is `null` for ungraded questions.

**`POST /attempts/:attemptId/complete`** → 200
```json
{ "data": {
  "attemptId": "…", "lessonId": "…", "completedAt": "…",
  "firstCompletion": true, "healthPointsEarned": 13, "healthPointsTotal": 50,
  "nodeCompleted": false, "unlockedNodeId": null,
  "completion": { "headline": "You have won the day 😎", "message": "…", "asset": { "url": "…" } }
} }
```

**`POST /attempts/:attemptId/abandon`** → 204.

**`PUT /lessons/:lessonId/saved`** → 200 `{ "data": { "lessonId": "…", "isSaved": true } }`. **`DELETE`** on the same path returns the same shape with `isSaved: false`. Both are idempotent.

**`POST /lessons/:lessonId/feedback`**
- Body: `{ "reasonIds": ["…"], "comment": "…", "pageId": "…" }`; `comment` and `pageId` are optional.
- Response: 201 `{ "data": { "feedbackId": "…" } }`.

**`GET /events`** (Server-Sent Events)
- Headers: `Content-Type: text/event-stream`, `Cache-Control: no-cache`, `X-Accel-Buffering: no`.
- On connect, send `retry: 5000` followed by `event: hello` with `{"version":N}`.
- On every Postgres `content_changed` notification, send `event: content_changed` with `{"version":N}`.
- Send `event: ping` every `SSE_HEARTBEAT_MS`.
- One `LISTEN` connection is shared by all SSE clients and reconnects automatically. Clients are removed on disconnect.

**`GET /static/assets/:file`**
- Served by `express.static` with `Cache-Control: public, max-age=3600` and ETag enabled.
- Directory listing is off, and path traversal must be impossible.

---

## 7. Backend architecture

### 7.1 Stack
- Node 22 LTS, TypeScript in strict mode, Express 5, Kysely with `pg`, Zod, pino and pino-http, helmet, cors.
- Vitest and Supertest for tests; tsx for development; ESLint and Prettier.
- Use the latest stable versions compatible with Node 22. Record the chosen versions in `IMPLEMENTATION_PLAN.md`.

### 7.2 Folder structure
```
src/
  app.ts                 builds the Express app (no listen) — used by tests
  server.ts              listen + graceful shutdown
  config/env.ts
  db/{kysely.ts, types.ts (kysely-codegen), migrations/, listen.ts}
  lib/{errors.ts, markup.ts, rng.ts, time.ts, assets.ts}
  middleware/{requestId, userContext, validate, notFound, errorHandler}
  modules/
    app-config/  home/  journey/  lessons/  attempts/  search/  feedback/  saved/  events/
      each: *.routes.ts, *.controller.ts, *.service.ts, *.repository.ts, *.schemas.ts
scripts/{migrate, seed, validate-content, reset-progress, set-node-count, codegen}.ts
test/{unit, integration, helpers}
```
Each layer has one job:
- Controllers handle HTTP mapping only.
- Services hold business rules and receive repositories through their constructors.
- Repositories contain Kysely queries only.

### 7.3 Middleware order
`requestId` → `pino-http` → `helmet` → `cors` → `express.json({limit: '100kb'})` → static → `/api/v1` routes → `notFound` → `errorHandler`.

### 7.4 Logging and errors
- **Never log:** request bodies, free-text answers or connection strings.
- **Redact:** the `authorization` and `cookie` headers.
- **Error handler:** maps `AppError` to its code. Zod errors become `VALIDATION_ERROR`. Postgres errors and anything unknown become `INTERNAL_ERROR`, and their details are logged on the server only.

### 7.5 Database access
- Pool size 10.
- Use transactions wherever section 4 says "same transaction".
- **Graceful shutdown on SIGINT/SIGTERM:** stop accepting connections, end SSE streams, release the LISTEN client, then close the pool.

### 7.6 Scripts (npm)
- `db:migrate`, `db:migrate:test`, `db:codegen`.
- **`db:seed`:**
  - **YAML shape notes:** question `options` may be plain strings (treated as `{label, correct: false}`) or `{label, correct}` objects. `provenance`, `notes` and `corrections` keys are documentation only and are not stored. Accordion `children` become `page_blocks` rows with `parent_block_id` set.
  1. Validates the YAML and the manifest with Zod.
  2. Expands placeholder lessons into pages.
  3. Upserts everything by `key` inside **one transaction**.
  4. Is idempotent: running it again changes nothing.
  5. Creates the demo user if missing.
- **`content:validate`:**
  - **Checkpoints:** a checkpoint has exactly one published lesson.
  - **Pages and options:** every lesson has at least one page; choice questions have at least 2 options; graded single-choice questions have exactly one correct option; graded multiple-choice questions have at least one; free-text questions have no options.
  - **Answer keys:** every `{{answer.key}}` refers to an `answer_key` on an earlier page of the same lesson.
  - **Blocks and markup:** accordion children belong to an accordion parent; markup is balanced.
  - **Assets:** every referenced asset file exists.
  - The script exits non-zero if any rule fails.
- **`progress:reset [--user <uuid>]`:** deletes that user's attempts, progress, node completions, saved lessons and ledger rows, and resets their total.
- **`demo:set-node-count --level <levelKey> --count <n>`:**
  - Sets the number of published **lesson** nodes in that level.
  - Extra nodes are unpublished, never deleted.
  - Missing nodes are created with the keys `demo_<level>_<i>`, one placeholder lesson each, and a reused icon.
  - The checkpoint always stays last.
  - The change runs in one transaction, so the app receives a single real-time update.

---

## 8. Flutter architecture

### 8.1 Packages
`flutter_bloc`, `bloc_test`, `freezed`, `json_serializable`, `dio`, `go_router`, `get_it`, `cached_network_image`, `flutter_svg`, `lottie`, `intl`, `mocktail`. Use the latest stable versions compatible with the installed Flutter SDK. Don't add packages beyond these without recording the reason in the worklog.

### 8.2 Structure
```
lib/
  main.dart, app.dart, di.dart
  core/
    config/ env.dart
    network/ api_client.dart, interceptors.dart, sse_client.dart
    error/ app_exception.dart, failure.dart (sealed)
    routing/ router.dart
    theme/ tokens.dart, theme.dart
    markup/ markup_parser.dart, markup_text.dart
    widgets/ remote_image.dart, primary_button.dart, error_view.dart, loading_view.dart, toast.dart
    sync/ content_sync_service.dart
  features/
    app_config/  home/  journey/  search/  lesson/
      data/ (dto, remote_data_source, repository_impl)
      domain/ (entities, repository interface)
      presentation/ (bloc|cubit, pages, widgets)
```

### 8.3 Routes
- `/` → Home.
- `/journey` → Journey.
- `/journey/search` → Search.
- `/lesson/:lessonId` → Lesson player. It returns a `LessonExit` result (`completed` or `abandoned`, with `nodeId`) so the Journey can reopen that node's popover.

### 8.4 State
- **`AppConfigCubit`:** loading → ready(bootstrap) / failure.
- **`HomeCubit`:** loading → ready / failure. It refreshes on route return and on content change.
- **`JourneyCubit`**, with these states:
  - `loading`, then `loaded(journey, selectedNodeId?)`.
  - `reloading` (overlay over the current path), triggered by the Reload button.
  - `refreshing` (silent), triggered by content change or app resume.
  - `failure` (no data yet).
  - `loaded` with a `transientError` (keeps the existing data and shows a snackbar).

  Actions: `load`, `reload`, `silentRefresh`, `selectNode`, `clearSelection`.
- **`LessonPlayerBloc`:**
  - Events: `Started`, `OptionToggled`, `TextChanged`, `CtaPressed`, `BackPressed`, `ExitConfirmed`, `RetryPressed`, `SaveToggled`, `FeedbackSubmitted`.
  - State: lesson, attemptId, pageIndex, answers (per page), `showingFeedbackFor`, feedback payload, hpCounter, `submitting`, `inlineError`, `completion?`, `isSaved`.
  - **CTA on a content page:** go to the next page, or call complete if it is the last page.
  - **CTA on a question page:** validate locally. If invalid, show a toast (choice questions: `lesson.choice.validation_message`; free-text questions: `lesson.free_text.validation_title` plus the question's `validationMessage`). If valid, PUT the answer. Show the feedback card if the response includes feedback; otherwise advance.
  - **CTA on the feedback card:** advance.
  - **Back:** from the feedback card, return to the question with the selection kept. From page N>0, go to page N−1. From page 0, show the exit sheet.
  - **Android system back** behaves exactly like the Back arrow.
- **`SearchBloc`:** 300 ms debounce, only the latest request is processed, queries shorter than 2 characters show the empty state, and the sort can be switched.
- **`ContentSyncService`:**
  - Owns the SSE connection and reconnects with backoff of 1, 2, 5, 10 and 30 seconds.
  - Tracks the last known version.
  - When a newer version arrives, it calls `silentRefresh` on the Journey and Home cubits, reloads app config, and shows the `journey.updated.toast` if the Journey is visible.
  - It also triggers a silent refresh when the app resumes.
  - **A lesson in progress is never interrupted:** it finishes with the content it loaded.

### 8.5 Networking and error mapping
- **Dio settings:** connect timeout 10 s, receive timeout 15 s. An interceptor adds `X-User-Id`.
- **Error mapping:**
  - Socket and connection errors → `NetworkFailure`.
  - Timeouts → `TimeoutFailure`.
  - Error envelopes → `ServerFailure(code)`, with special handling for `LESSON_LOCKED`, `NOT_FOUND` and `CONTENT_CHANGED`.
  - Non-JSON responses or DTO parse exceptions → `ParsingFailure`.
  - Anything else → `UnexpectedFailure`.
- Every failure maps to an `app_copy` message. If the copy itself hasn't loaded, use a short fallback string kept in a single `FallbackMessages` class, which is the **only** place allowed to hold hardcoded UI text.
- **Defensive parsing:** an unknown block type is skipped (a debug log is written) and the rest of the page still renders. An unknown node type is rendered as a lesson node. An unknown state is treated as locked.

---

## 9. Screen specifications

### 9.1 Theme tokens (dark only, values sampled from the reference)
| Token | Value |
|---|---|
| Page background | `#000000` |
| Primary text | `#FFFFFF` |
| Secondary text | `#BDBDBD` |
| Completed path, node ring | `#BDBDBD` |
| Locked path, locked ring | `#2A2A2A` |
| Popover / card surface | `#1E1E1E` |
| Completed check | `#3DBE8B` |
| Primary button | `#F5F5F5` fill, `#111111` text |
| Disabled button | `#3A3A3A` |
| Highlight | `#D9F2C4` |
| Health accent | `#5DBB8A` |

Fonts: Roboto (default). Body 16, heading 22 bold, CTA 16 bold uppercase as provided by the content.

### 9.2 Home
- **Header:** a row with an avatar (circle, user's initial), streak (flame icon and number) and health points (heart-pulse icon and number).
- **"today's task" title row** with a `JOURNEY ›` link on the right.
- **Task card:** shows the lesson title, or the all-done text. Tapping it opens the lesson, or the Journey if everything is done.
- **States:** loading skeleton, error with retry, pull-to-refresh.

### 9.3 Journey
- **App bar:** back arrow, the `journey.title` copy, and outlined `Reload` and `Search` buttons.
- **Path:** a vertical scroll containing the layout from 9.4.
- **Popover:**
  - Anchored below the tapped node with a 12 dp pointer.
  - Width is `min(0.84 × content width, 340 dp)`, horizontally clamped to the screen.
  - Rows show an icon for the lesson state (green check, outline circle or lock), then the title.
  - Below the rows are the primary button and, for completed nodes, "Completed On {d MMM yyyy}".
  - It fades and scales in over 180 ms.
  - Opening it auto-scrolls so the whole popover is visible (`Scrollable.ensureVisible`, 250 ms).
  - Tapping outside it or on ⊗ closes it.
- **Locked node tap:** a 300 ms shake plus a `journey.locked.message` snackbar.
- **Reload:** translucent overlay showing the spinner and the reloading title and subtitle (200 ms fade). On success, scroll to the top.
- **States:**
  - First load: full-screen spinner.
  - First-load failure: `ErrorView` with retry.
  - Empty (no statuses): message with retry.
  - Silent refresh: data is swapped without any loader.

### 9.4 Path layout engine
`JourneyLayoutEngine.compute(items, contentWidth)` is a pure function. It returns positioned rectangles for every card and node, a list of connector segments (`Path` plus `completed` flag), and the total height.

- **Content width:** `W = min(screenWidth, 480)`, centered on the screen.
- **Node:** diameter `D = 0.26W`, with a ring of `0.035W` drawn by Flutter and the icon clipped to a circle inside it.
- **Card:** width `0.9W`, height `0.46W`, radius 16, a solid offset shadow of 8 dp in `shadowColor`, the illustration on the left 40%, and the text on the right ("Status" label / title / level label / level title).
- **Row pattern after each card:** a centered node (x = 0.5W), then a pair row (x = 0.30W and 0.72W), and so on alternating. Rows are `0.49W` apart (center to center). A checkpoint always takes its own centered row.
- **Checkpoint:** the arch image is `0.39W` wide by `0.42W` tall. The next status's card overlaps the bottom of the arch by `0.12W`, as in the video.
- **Connectors:**
  - Stroke width `0.025W`, round caps.
  - Card → first node: a straight vertical line.
  - Center → left of pair: an S-curve that bulges out to x = 0.08W.
  - Left → right of the pair: a straight horizontal line.
  - Right of pair → next center: an S-curve that bulges out to x = 0.92W.
  - ~~A segment is drawn in the completed color if the node it **ends** at is completed.~~ *Superseded 2026-10-13 (verified against the reference video, 4.9–6.2 s):*
  - **Fill rule:** a segment is **filled** (completed colour) if the node it leads into is `completed` **or** `available`, and drawn in the **track** (locked) colour if that node is `locked`. This includes card → first-node connectors and the connector that runs from a checkpoint (or the previous level's last node) down through the next status card into its first node (drawn behind the card).
  - The engine outputs connectors as **one ordered sequence in path order** (top to bottom), each with its `start` and `length` (PathMetric), plus `filledLength` = total length of the contiguous filled prefix (it stops at the first segment into a locked node).
- **Fill animation:**
  - The painter draws every segment in the track colour, then the filled colour along the sequence up to `animatedLength`, using `PathMetric.extractPath` for the partially filled segment (same stroke width and round caps, so the leading edge is rounded). Like water flowing down the path to the furthest unlocked node; locked sections stay dark.
  - `animatedLength` is driven by an `AnimationController` passed to the `CustomPainter` as `repaint:`; the node Stack is not rebuilt per frame.
  - Duration ∝ distance: `lengthToFill / (2.5 × W)` seconds, clamped to 0.4–2.0 s, `Curves.easeOut`.
  - Triggers: first load and Reload animate from 0 to `filledLength`; a silent refresh or returning from a lesson that unlocked a node animates from the previous `filledLength` to the new one; if `filledLength` shrinks (progress reset, content change) jump to the new value without animating.
  - If `MediaQuery.disableAnimations` is true, draw the final state immediately.
- **Hit targets:** each node is tappable within its full circle, which is never smaller than 48 dp.
- **Engine tests:** for node counts 0–60 in each level, nothing overlaps, everything stays within `[0, W]`, and the total height increases monotonically.

### 9.5 Search
- **App bar:** back arrow and the `search.placeholder` title.
- **Search field:** outlined, with a search icon, autofocused.
- A small sort button at the bottom right opens a menu (`search.sort.*`).
- **Results:** each row shows the title, a "status · level · node" subtitle and a lock icon if the lesson is locked. Tapping an available lesson opens it; tapping a locked one shows the locked snackbar.
- **States:** empty prompt, loading, no results, error with retry.

### 9.6 Lesson player
- **Top bar:** back arrow, a progress bar animated over 250 ms to `(pageIndex + 1) / pageCount`, and a heart-pulse icon with the counter.
- **Body:** a scrollable column of blocks.
  - Images: full width, radius 12, aspect ratio from the asset, placeholder shimmer while loading, broken-image fallback.
  - Callout: 56 dp icon followed by text.
  - Icon heading: 24 dp icon and colored bold text.
  - Accordion: tappable title with a chevron, animated expand over 200 ms.
- **Question options:** cards with a radius-12 border and a radio circle (single choice) or checkbox (multiple choice). The selected option has a brighter border and a filled indicator.
- **Free text:** multiline box, minimum 4 lines, counter shown when `maxLength` is set.
- **Bottom bar:** a full-width CTA showing the content's label (a spinner replaces the label while submitting) and a ⋮ button.
- **Page change:** 220 ms crossfade, with the body scrolled back to the top.
- **Feedback card:**
  - Replaces the page body inside a bordered card.
  - Contents: illustration (≈ 0.3W), centered bold headline, then the `answer_prefix` copy followed by the correct answer(s), **highlighted**, then the explanation.
  - The CTA keeps the page's label.
- **Exit sheet:** a modal bottom sheet with the title, message and two buttons (`exit.confirm`, `exit.cancel`). Confirming sends abandon (fire-and-forget) and pops the route with `abandoned`.
- **⋮ menu sheet:**
  - Save row: toggles between `menu.save` and `menu.saved` with a check, and shows the "DONE! Bookmark Added 😁" toast when saved.
  - `menu.feedback` opens the feedback dialog: title, subtitle, checkbox list from bootstrap reasons, an "Other" text field, footer and SUBMIT. SUBMIT is disabled until the input is valid; there's an inline error on failure and a toast on success.
- **Completion screen:**
  - The medal (or the lesson's asset) scales in over 400 ms with a light sparkle effect.
  - Shows the headline and a bordered card with the message.
  - A `Continue` button pops with `completed`.
  - If the server returns an `unlockedNodeId`, the Journey briefly pulses that node after returning.
- **Errors:**
  - Lesson fails to load: `ErrorView` with retry.
  - Answer or complete fails: an inline error above the CTA with Retry; the user's place is kept.
  - `CONTENT_CHANGED`: a dialog explaining the lesson was updated, with a button to restart it.
  - `LESSON_LOCKED` or `NOT_FOUND`: a message, then pop back.

---

## 10. Error handling matrix

| Situation | Backend | App behaviour |
|---|---|---|
| Server unreachable | — | Offline copy + Retry; existing data kept |
| Timeout | — | Timeout copy + Retry |
| 4xx with a known code | Error envelope | Mapped message; locked/not-found pop back |
| 500 | Logged with request id | Generic server copy + Retry |
| Malformed JSON or DTO mismatch | — | `ParsingFailure` → unexpected copy + Retry; detail logged in debug |
| Unknown block or node type | — | Skipped or treated safely; page still renders |
| Missing image | 404 from static | Placeholder icon; layout unaffected |
| SSE drops | — | Silent reconnect with backoff; refetch on reconnect |
| DB down at startup | `/health` 503, exit on migrate failure | — |

---

## 11. Test plan
A test may only be reported as passing if it was actually run and passed.

### 11.1 Backend unit tests
- Unlock rules (4.2–4.3) using in-memory fixtures.
- Grading for single, multiple and free-text questions.
- Points rule, including first completion vs replay.
- Streak calculation, including timezone boundaries.
- The markup validator.
- Content validator rules.
- Placeholder expansion.

### 11.2 Backend integration tests (real `healthtick_test`, migrated fresh; truncate between tests)
- **Every endpoint:** happy path plus each documented error code.
- **Journey:** ETag/304 behavior; states change correctly after completions.
- **Lesson payload:** never contains `is_correct`.
- **Answers:** a graded answer returns feedback; an option from another question returns 422; a locked lesson returns 403.
- **Completion:** idempotent under 2 concurrent requests (exactly one ledger row); unlocks the next node; `CONTENT_CHANGED` when a question is added mid-attempt.
- **Search:** finds "procrast"; both sort orders work.
- **Saved and feedback:** toggling saved is idempotent; feedback validation works.
- **SSE:** a test client receives `hello`, then `content_changed` after a content update.
- **Seed:** idempotent (running it twice produces an identical row count); `demo:set-node-count` changes the journey response and emits exactly one event.

### 11.3 Flutter tests
- **Unit:** layout engine (9.4), markup parser, interpolation, DTO parsing including malformed responses, repository error mapping (mocked Dio), SSE line parser and reconnect policy.
- **bloc_test:**
  - `JourneyCubit`: all states, including silent refresh failure keeping data.
  - `LessonPlayerBloc`: every transition in 8.4, including Back from feedback, invalid free text, a failed submit then retry, completion and `CONTENT_CHANGED`.
  - `SearchBloc`: debounce and stale responses.
  - `HomeCubit`.
- **Widget tests:**
  - Journey with 1, 7 and 25 nodes plus a checkpoint, with popover open and closed, and loading/error/empty states.
  - Each block type.
  - Single, multiple and free-text question pages.
  - Feedback card, exit sheet, ⋮ menu, feedback dialog validation, completion screen.
  - Search states.

### 11.4 End to end (only if an emulator or device is available)
An `integration_test` running against the local backend:
Home → Journey → open node 1 → complete the welcome lesson → back to the Journey (popover open) → open a graded lesson → answer wrong → feedback → complete → check that the health total increased.

If no device is available, record the exact manual steps in the worklog instead.

### 11.5 Manual verification checklist
Kept in `IMPLEMENTATION_PLAN.md`:
- Every reference behavior, with its video timestamp.
- Real-time node count change using `demo:set-node-count`.
- APK install and run on a phone over `adb reverse`.

---

## 12. Documentation and AI worklog

- **`README.md`:** prerequisites; Docker start-up; environment setup; migrate, codegen and seed; running the API; running the app on an emulator and on a device (`adb reverse`); running all tests; building the release APK; demonstrating real-time changes; project structure; known limitations.
- **`docs/API_SPECIFICATION.md`:** section 6 as implemented, with curl examples.
- **`docs/DATABASE_DESIGN.md`:** ER overview, every table and why it exists, the constraints, the triggers and NOTIFY mechanism, and the seed/validate flow.
- **`docs/IMPLEMENTATION_PLAN.md`:** phases, the chosen versions, and status. Updated at the end of each phase.
- **`docs/AI_WORKLOG.md`:** one entry per working session or phase, appended only. Each entry records:
  - Date and the objective of the phase.
  - A summary of the user's instructions.
  - What Claude Code did, and the files created or modified.
  - Decisions made and why.
  - Bugs found and how they were fixed.
  - The commands and tests **actually run**, with their results.
  - Open issues.

  Earlier entries are never rewritten, backdated or invented. Claude's own work is attributed to Claude; the user's decisions are attributed to the user.
- **`docs/ai-history/`:** raw exports, added by the user. Claude Code only creates a README there explaining what goes in it.

---

## 13. Build order (commit at the end of each step, using Conventional Commits)

1. **Inspect:** Git status, tool versions (Node, npm, Flutter, Dart, Java, Android SDK, Docker), existing scaffolding and the reference pack. Write `IMPLEMENTATION_PLAN.md`. Stop only if there is a genuine blocker.
2. Docker Compose, root `.env.example`, `.gitignore` (including `Resouces/`, `.env`, build outputs).
3. Backend scaffold, config, logging, error handling, `/health` and the test harness.
4. Migration 001 (schema v1, verbatim), codegen, then migrate the test database.
5. Copy the reference pack into the backend; download and attribute the Fluent Emoji assets; write the seeder, the content validator and the reset/demo scripts; seed the dev database.
6. Modules: app-config, home, journey, lessons, attempts, search, saved, feedback, events. Write unit and integration tests alongside each one.
7. Flutter scaffold, theme, core layers (network, errors, SSE, markup, routing, DI).
8. Home, then Journey (layout engine first, with tests), then Search.
9. Lesson player (blocks, questions, feedback, exit sheet, menu, completion).
10. Content sync, lifecycle refresh, final error states.
11. Full test run (backend and Flutter), fixes, the E2E test if a device is available.
12. Documentation and worklog completion; release APK build (`flutter build apk --release` with dart-defines); final report.

---

## 14. Acceptance criteria

1. With the database seeded, the Journey shows Beginner (LEVEL-1, 6 nodes and a checkpoint) and Insider (LEVEL-2, 3 nodes) in the reference layout and colors. A fresh user has node 1 available and everything else locked.
2. Running `demo:set-node-count --level insider_l2 --count 5` while the app is open updates the path **without user action** within 3 seconds, with no overlap or clipping. Reverting to 3 works the same way.
3. Tapping a node opens its popover with the correct lessons and states. The checkpoint opens its lesson directly.
4. All six transcribed lessons render as in the reference: text, highlights, lists, callouts, icon headings, accordions and images.
5. Graded questions show the feedback card with a rotating headline, the highlighted correct answer and the explanation. Ungraded multiple-choice questions advance directly. Free-text questions enforce input and are interpolated on the following page.
6. Back and exit behavior matches 8.4. Abandoned attempts award nothing.
7. Completing a lesson persists across app restarts. Points are awarded on first completion only. Finishing a node's last lesson unlocks the next node immediately. The checkpoint unlocks Insider.
8. Search finds lessons by partial title, shows their locked state, opens available lessons and sorts both ways.
9. Reload shows the overlay and refetches. With the API stopped, every screen shows the correct error state and recovers on Retry.
10. Save Lesson and Send feedback persist in the database. Validation errors appear in the UI.
11. No API response contains correct answers, stack traces or SQL.
12. All backend and Flutter tests pass in a real run. `content:validate` passes.
13. The README instructions work from a clean clone. The APK installs and completes the flow in 11.4 on a device.
14. All four documents are present and accurate, `AI_WORKLOG.md` is truthful, and no secrets are committed.
