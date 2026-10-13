# Database design

PostgreSQL 16 (Docker, host port 5433). The schema is the approved `healthtick_schema_v1.sql`, applied **verbatim** as migration
`001_schema_v1` (`user_journey_backend/src/db/migrations/001_schema_v1.sql`; SHA-256 identical to the approved file).
Types for Kysely are generated with `npm run db:codegen`.

## Overview

```
content_state (1 row: version)                 ← bumped by every content statement → NOTIFY content_changed

media_assets ◄──────────────┬───────────────┬────────────────┬──────────────────┐
app_copy (key, locale)      │               │                │                  │
journey_statuses ─< journey_levels ─< journey_nodes ─< lessons ─< lesson_pages ─< page_blocks (self-parent: accordion children)
                                (illustration)  (icon)   (completion asset) └─ page_questions ─< question_options
answer_feedback_messages (illustration) · feedback_reasons

users ─< lesson_attempts ─< attempt_answers ─< attempt_answer_options (→ question_options)
users ─< user_lesson_progress (→ lessons) · user_node_completions (→ journey_nodes)
users ─< health_point_transactions (→ lesson_attempts) · saved_lessons (→ lessons)
users ─< lesson_feedback ─< lesson_feedback_reasons (→ feedback_reasons)
```

## Conventions (from the schema)
- **Keys:** UUID primary keys (`gen_random_uuid()`); identity `bigint` for the append-only ledger.
- **Stable keys:** every content row has a human-readable `key`, so seeds and scripts never need UUIDs.
- **Enumerations** are `text + CHECK` (easier to evolve than PG enums).
- **Ordering:** sibling order uses `position` with `UNIQUE … DEFERRABLE INITIALLY DEFERRED` constraints, so a reorder (e.g. `demo:set-node-count`
  moving the checkpoint last) fits in one transaction.
- **Timestamps:** `created_at` / `updated_at` on mutable tables, with `updated_at` maintained by trigger.
- **Visibility:** `is_published` on statuses, levels, nodes and lessons. The API returns or counts a row only if it **and every ancestor** are published.

## Tables

### Content
| Table | Why it exists | Notable constraints |
|---|---|---|
| `content_state` | One row holding the content `version`: part of the journey ETag and the payload of real-time notifications | `id = 1`, `version > 0` |
| `media_assets` | Images and icons served from `/static/assets` (URL, size, alt, format) | `key` unique; `kind`/`format` CHECKs |
| `app_copy` | All UI copy per locale (the app hardcodes none) | PK `(key, locale)`; key pattern |
| `journey_statuses` | Beginner, Insider…; card colours | hex-colour CHECKs; deferrable unique `position` |
| `journey_levels` | One card per level (`LEVEL-1`, title, illustration) | unique `(status_id, position)` |
| `journey_nodes` | The circles; their count and order are pure configuration | `node_type IN (lesson, checkpoint)`; unique `(level_id, position)` |
| `lessons` | Lesson metadata, completion headline/message/asset | generated `search_vector` (GIN) + trigram GIN index on `title` |
| `lesson_pages` | Ordered pages; `content` or `question`; CTA label | `UNIQUE (id, page_type)`, the target of the question FK |
| `page_blocks` | Rich blocks (heading, paragraph, lists, image, callout, icon heading, accordion, spacer) | `ck_block_shape` per type; a child must be on the same page as its parent (composite FK) |
| `page_questions` | Question rules (response type, grading, selection and length limits, answer key, explanation) | FK `(page_id, 'question')` → only question pages; `ck_graded_is_choice`, `ck_single_choice_max`, range checks |
| `question_options` | Options and correctness (correctness is never exposed by the lesson endpoint) | unique `(page_id, position)`, `(page_id, label)`, `(id, page_id)` |
| `answer_feedback_messages` | Rotating feedback headlines + illustrations per outcome, weighted | `weight > 0`; partial index on active rows |
| `feedback_reasons` | Checkbox reasons in the "Faced some issue?" dialog | `requires_text` for "Others" |

### User state
| Table | Why it exists | Notable constraints |
|---|---|---|
| `users` | Demo user (no auth); cached `health_points_total` | `health_points_total ≥ 0` |
| `lesson_attempts` | One per lesson start; records the `content_version` at start | status CHECK, consistent with `completed_at` / `abandoned_at` |
| `attempt_answers` | One answer per question per attempt (re-answering = upsert) | unique `(attempt_id, page_id)` |
| `attempt_answer_options` | Selected options | composite FKs guarantee the option belongs to the answered question |
| `user_lesson_progress` | Fast "completed" lookups; first/last completion; count | PK `(user_id, lesson_id)` |
| `user_node_completions` | Explicit node completion, so adding a lesson later never re-locks a node | PK `(user_id, node_id)` |
| `health_point_transactions` | Append-only points ledger | `lesson_attempt_id UNIQUE`: at most one award per attempt, even under concurrency |
| `saved_lessons` | Bookmarks | PK `(user_id, lesson_id)` → idempotent |
| `lesson_feedback`, `lesson_feedback_reasons` | Lesson feedback with optional page and comment | `comment ≤ 1000` |

## Triggers and NOTIFY

- `set_updated_at()`: a `BEFORE UPDATE` row trigger on every mutable table.
- `bump_content_version()`: an `AFTER INSERT OR UPDATE OR DELETE OR TRUNCATE … FOR EACH STATEMENT` trigger on all 12 content tables.
  It increments `content_state.version` and runs `pg_notify('content_changed', version)`. Notifications are delivered **on commit**.
- **Consequences, handled in code:**
  1. A transaction with N content statements sends N notifications. The API's single `LISTEN` client coalesces a burst (150 ms) into one SSE
     `content_changed` event with the latest version (verified by an integration test: `demo:set-node-count` → exactly one event).
  2. Statement triggers fire even for statements that change no rows. The seeder therefore **diffs before writing**, and a rerun issues zero
     statements, so the content version does not move.
- User-state tables have no content trigger, so progress changes never bump the content version. The journey ETag includes a per-user progress stamp instead.

## Transactions and concurrency

- **Completing an attempt** (SPEC §4.8) runs in one transaction:
  - attempt `SELECT … FOR UPDATE`, then the user row `FOR UPDATE`, then one `now()` for every timestamp;
  - ledger row + total update, progress upsert, node completion, attempt marked completed.
  - Two concurrent completes of the same attempt serialise on the row lock; the second returns the stored result (tested: exactly one ledger row).
- **Answering** locks the attempt row, so answers can't race a complete or abandon.
- `progress:reset` and `demo:set-node-count` each run in a single transaction.

## Seed and validate flow

```
seed/journey_content.yaml + seed/asset-manifest.json + static/assets/*.png
        │
        ▼  content:validate  (also run by db:seed and demo:set-node-count; exits 1 on any issue)
  Zod (strict: typos in keys are errors; provenance/notes/corrections are documentation only)
  → normalised model (placeholder lessons expanded into one page: heading = title, paragraph = summary)
  → rules:
      - checkpoint = exactly 1 lesson; every lesson ≥ 1 page;
      - choice ≥ 2 options; graded single = exactly 1 correct; graded multiple ≥ 1 correct; free text has no options;
      - {{answer.key}} refers to an answer_key on an earlier page; accordion children are not accordions;
      - balanced markup and known tokens; every asset is in the manifest and its file exists as a valid PNG;
      - at least one active feedback message per outcome; required ui_assets present
        │
        ▼  db:seed  (one transaction)
  diffing upsert by key: media_assets → app_copy (+ ui_asset.* rows) → feedback_reasons → answer_feedback_messages
  → statuses → levels → nodes → lessons → pages (by position) → questions/options (by position, ids kept) → blocks (tree compared per page)
  rows missing from the YAML are unpublished/deactivated and moved after the YAML rows (never deleted); demo user created if missing
```

## Test database

`healthtick_test` is dropped, recreated and migrated by the Vitest global setup on every run. The harness refuses any database whose
name doesn't end in `_test`. Tests truncate between suites and seed the real content.
