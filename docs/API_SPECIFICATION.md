# HealthTick Journey API (as implemented)

Base URL: `http://localhost:3000`. All JSON routes live under **`/api/v1`**. This document describes the implementation of
SPEC §6; the response samples below were captured from the running API with the seeded content.

## Conventions

- **User:** every route except `/health` and `/static/*` requires `X-User-Id: <uuid>`. A missing, malformed or unknown id →
  `401 USER_NOT_IDENTIFIED`. The seeded demo user is `00000000-0000-4000-8000-000000000001`.
- **Success:** `{ "data": … }`.
- **Error:** `{ "error": { "code", "message", "details?", "requestId" } }`. Stack traces and SQL are never sent; unexpected errors are
  logged on the server with the request id.
- **Request id:** every response has `X-Request-Id`. A well-formed incoming one (`[A-Za-z0-9._:-]{1,128}`) is echoed; otherwise one is generated.
- **Validation:** params, query and body are validated with Zod. Unknown body fields are rejected (`400 VALIDATION_ERROR`, with `details`).
  Malformed JSON and bodies over 100 kB also return `400 VALIDATION_ERROR`.
- **Asset object:** `{ "url": "/static/assets/x.png", "width": 114, "height": 114, "alt": "…", "format": "png" }`. The URL is relative to the
  API origin; the app resolves it against `API_BASE_URL`.

| Code | HTTP | When |
|---|---|---|
| `VALIDATION_ERROR` | 400 | Bad params, query or body shape |
| `USER_NOT_IDENTIFIED` | 401 | Missing, invalid or unknown user |
| `LESSON_LOCKED` | 403 | Reading, or starting an attempt on, a locked lesson |
| `NOT_FOUND` | 404 | Unknown or unpublished id; another user's attempt; a page that isn't in the attempt's lesson; unknown route |
| `ATTEMPT_NOT_ACTIVE` | 409 | Answering or completing an abandoned attempt; answering a completed one; abandoning a completed one |
| `CONTENT_CHANGED` | 409 | Complete with missing answers and the content version changed since the attempt started |
| `ANSWER_INVALID` | 422 | The answer violates the question's rules, includes an option of another question, or is the wrong kind |
| `INCOMPLETE_ATTEMPT` | 422 | Complete with missing answers, same content version (`details.missingPageIds`) |
| `FEEDBACK_INVALID` | 422 | No reason and no comment; a "requires text" reason (Others) without a comment; unknown reason; page not in lesson |
| `INTERNAL_ERROR` | 500 | Anything unexpected |

```bash
U="X-User-Id: 00000000-0000-4000-8000-000000000001"
curl -s localhost:3000/api/v1/home
# {"error":{"code":"USER_NOT_IDENTIFIED","message":"A valid X-User-Id header is required","requestId":"4f639f87-…"}}
```

---

## Health

### `GET /health` (also `GET /api/v1/health`), no user header
`200 {"data":{"status":"ok","db":"ok"}}`, or `503 {"data":{"status":"degraded","db":"unavailable"}}` when the database is unreachable.

## App config

### `GET /api/v1/bootstrap`
```bash
curl -s -H "$U" localhost:3000/api/v1/bootstrap
```
```json
{ "data": {
  "contentVersion": 234,
  "user": { "id": "00000000-0000-4000-8000-000000000001", "displayName": "Yash", "healthPointsTotal": 23 },
  "copy": { "journey.title": "Your Journey", "journey.reload": "Reload", "…": "…" },
  "assets": {
    "lockedNode": { "url": "/static/assets/node_locked.png", "width": 114, "height": 114, "alt": "Locked", "format": "png" },
    "completionMedal": { "url": "/static/assets/ui_completion_medal.png", "width": 229, "height": 287, "alt": "Congratulations medal", "format": "png" }
  },
  "feedbackReasons": [ { "id": "…", "key": "too_text_heavy", "label": "Too text heavy", "requiresText": false },
                       { "id": "…", "key": "others", "label": "Others", "requiresText": true } ]
} }
```
`assets` comes from the content YAML's `ui_assets` (stored as reserved `ui_asset.*` copy rows; they are not included in `copy`).

## Home

### `GET /api/v1/home`
```json
{ "data": {
  "user": { "displayName": "Yash", "healthPointsTotal": 23, "streakDays": 1 },
  "todayTask": { "lessonId": "25e700fa-…", "lessonTitle": "No zone is off-limits", "nodeId": "77c2e7e2-…", "statusTitle": "Beginner" }
} }
```
- `streakDays`: consecutive calendar days in `APP_TIMEZONE` with at least one completed attempt, ending today or yesterday.
- `todayTask`: the first available, not-completed lesson in global order; `null` when everything is done.

## Journey

### `GET /api/v1/journey`
- Response header `ETag: W/"c{contentVersion}-p{userProgressStamp}"` (e.g. `W/"c234-p1791868358724"`).
  `userProgressStamp` is the epoch-ms of the user's latest completion (0 if none). `Cache-Control: private, no-cache`.
- A matching `If-None-Match` returns `304` with no body.
```bash
curl -s -i -H "$U" -H 'If-None-Match: W/"c234-p1791868358724"' localhost:3000/api/v1/journey   # → 304
```
```json
{ "data": { "contentVersion": 234, "statuses": [ {
  "id": "…", "key": "beginner", "title": "Beginner",
  "cardTheme": { "backgroundColor": "#F9E4C9", "shadowColor": "#DBC4A5", "textColor": "#1C1C1C" },
  "levels": [ { "id": "…", "key": "beginner_l1", "label": "LEVEL-1", "title": "Psychology of weight",
    "illustration": { "url": "/static/assets/card_beginner_illustration.png", "…": "…" },
    "nodes": [ { "id": "…", "key": "beginner_day_1", "type": "lesson", "title": "Day 1",
      "icon": { "url": "/static/assets/node_psychology.png", "…": "…" },
      "state": "completed", "completedAt": "2026-10-13T05:12:38.724Z",
      "lessons": [ { "id": "…", "title": "Welcome to Health Tick!", "state": "completed", "completedAt": "…" } ] } ] } ] } ] } }
```
- **States:**
  - Node: `completed` if a completion row exists; `available` if it is the first published node or the previous node is completed; otherwise `locked`.
  - Lesson: `completed`, otherwise `available` within a completed node (replay), or within an available node when it is the first lesson or the
    previous lesson is completed; otherwise `locked`.
- **Visibility:** only published rows with every ancestor published. Lesson `completedAt` is the first completion; node `completedAt` is the node completion time.

## Lessons

### `GET /api/v1/lessons/search?q=&sort=relevance|journey&limit=`
`q`: 2–100 characters after trimming. `limit`: 1–50, default 20. A lesson matches by full-text search, `word_similarity` ≥ 0.5 on the title, or a
case-insensitive title substring (LIKE wildcards escaped). `relevance` = `ts_rank + word_similarity`; `journey` = global order.
```bash
curl -s -H "$U" "localhost:3000/api/v1/lessons/search?q=procrast&limit=1"
```
```json
{"data":{"query":"procrast","results":[{"lessonId":"2ed5f79f-…","title":"Procrastination for health","summary":"","nodeId":"76e78248-…","nodeTitle":"Day 5","levelLabel":"LEVEL-1","statusTitle":"Beginner","state":"locked"}]}}
```

### `GET /api/v1/lessons/:lessonId`
`403 LESSON_LOCKED` if locked; `404` if unknown or unpublished. **Correctness is never included** (options are `{ id, label }` only).
```json
{ "data": { "id": "…", "title": "Keystone Habit #2: Balance your food zones", "nodeId": "…", "nodeType": "lesson",
  "isSaved": false, "pageCount": 13,
  "pages": [ { "id": "…", "position": 1, "type": "question", "ctaLabel": "NEXT",
    "blocks": [ { "id": "…", "type": "paragraph", "text": "First question is - *What is Calorie Density?*" } ],
    "question": { "responseType": "single_choice", "isGraded": true, "minSelections": null, "maxSelections": 1,
      "answerKey": null, "inputPlaceholder": null, "minLength": null, "maxLength": null, "validationMessage": null,
      "options": [ { "id": "…", "label": "The total calories I eat in one day" } ] } } ] } }
```
Block shapes (each with `id`, `type`): `heading {text}`, `paragraph {text}`, `bulleted_list|numbered_list {items[]}`, `image {asset}`,
`callout {text, asset}`, `icon_heading {text, color, asset?}`, `accordion {title, children[]}`, `spacer {size}`.
Text uses the inline markup `**bold**`, `*italic*`, `==highlight==`, `{{user.name}}`, `{{answer.<key>}}`; the app resolves the tokens.

### `PUT /api/v1/lessons/:lessonId/saved` · `DELETE /api/v1/lessons/:lessonId/saved`
Idempotent. `200 {"data":{"lessonId":"…","isSaved":true|false}}`.

### `POST /api/v1/lessons/:lessonId/feedback`
Body `{ "reasonIds": ["uuid"], "comment"?: "≤1000 chars", "pageId"?: "uuid" }` → `201 {"data":{"feedbackId":"…"}}`.
```bash
curl -s -H "$U" -H 'Content-Type: application/json' -d '{"reasonIds":["<others-id>"],"comment":"Image did not load"}' \
  localhost:3000/api/v1/lessons/<lessonId>/feedback
```

## Attempts

### `POST /api/v1/lessons/:lessonId/attempts` → `201`
`{"data":{"attemptId":"…","lessonId":"…","startedAt":"…","contentVersion":234}}`. Returns `403 LESSON_LOCKED` for a locked lesson.

### `PUT /api/v1/attempts/:attemptId/answers/:pageId`
Body: exactly one of `{ "optionIds": ["uuid"] }` or `{ "text": "…" }`.
- **Grading:**
  - single choice: exactly 1 option;
  - multiple choice: between `minSelections` (default 1) and `maxSelections` distinct options;
  - free text: trimmed length between `minLength` (default 1) and `maxLength` (default 2000).
- Graded answers are correct only when the selected set equals the correct set. Re-answering a page replaces the earlier answer.
- The feedback headline is a weighted random pick among the active messages for the outcome.
```json
{ "data": { "pageId": "…", "isCorrect": false, "feedback": {
  "headline": "That's not correct, but don't worry—you've got this.",
  "illustration": { "url": "/static/assets/feedback_oops_sign.png", "…": "…" },
  "correctAnswers": ["Raisins"],
  "explanation": "Raisins are simply dehydrated grapes. …" } } }
```
`feedback` is `null` (and `isCorrect` is `null`) for ungraded questions.

### `POST /api/v1/attempts/:attemptId/complete`
Runs in one transaction with the attempt (and then the user) row locked `FOR UPDATE`. Calling it again for a completed attempt returns the stored result and awards nothing.
```json
{ "data": { "attemptId": "…", "lessonId": "…", "completedAt": "…", "firstCompletion": true,
  "healthPointsEarned": 3, "healthPointsTotal": 3, "nodeCompleted": false, "unlockedNodeId": null,
  "completion": { "headline": "You have won the day 😎", "message": "Rewatching programs can reignite your motivation and keep you on track.",
    "asset": { "url": "/static/assets/ui_completion_medal.png", "…": "…" } } } }
```
- Points: on the first completion, one point per published page; 0 on a replay. Each award writes a ledger row and updates the user total.
- When every published lesson of the node is done, the node completion is written in the same transaction, and `unlockedNodeId` is the next node in global order.

### `POST /api/v1/attempts/:attemptId/abandon` → `204`
Abandoning an already abandoned attempt also returns `204`; abandoning a completed attempt returns `409 ATTEMPT_NOT_ACTIVE`.

## Real-time

### `GET /api/v1/events` (Server-Sent Events; requires `X-User-Id`)
Headers: `Content-Type: text/event-stream`, `Cache-Control: no-cache`, `X-Accel-Buffering: no`.
```bash
curl -sN -H "$U" localhost:3000/api/v1/events
# retry: 5000
#
# event: hello
# data: {"version":226}
#
# event: content_changed
# data: {"version":228}
```
- One shared `LISTEN content_changed` connection serves every client and reconnects with backoff.
- The schema's statement-level triggers send one NOTIFY per content statement. The listener coalesces each burst (150 ms window) into a
  single event carrying the latest version, so one `demo:set-node-count` run produces exactly one event.
- `event: ping` is sent every `SSE_HEARTBEAT_MS`.

## Static assets

### `GET /static/assets/:file`
`express.static`: `Cache-Control: public, max-age=3600`, ETag, no directory listing, dotfiles denied. Path traversal and missing files
return the JSON `404` envelope.
