-- =====================================================================
-- HealthTick Journey — PostgreSQL schema, DRAFT v1 (for review)
-- Target: PostgreSQL 15+
-- Status: design draft. NOT yet executed against a database.
--         Claude Code will turn this into the first migration and
--         verify it with integration tests.
--
-- Conventions
--   * UUID primary keys (gen_random_uuid, core since PG13) for entities;
--     identity bigint for append-only ledgers.
--   * Every content row has a stable, human-readable `key` so seeds and
--     scripts can reference rows without knowing UUIDs.
--   * Enumerations are TEXT + CHECK (easier to evolve than PG ENUM types).
--   * Sibling ordering uses `position` with DEFERRABLE unique constraints,
--     so a reorder can be done inside one transaction.
--   * created_at / updated_at on mutable tables; updated_at kept by trigger.
--   * Any change to content tables bumps content_state.version and emits
--     NOTIFY 'content_changed' -> the API pushes it to the app over SSE.
-- =====================================================================

CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- ---------------------------------------------------------------------
-- Shared trigger functions
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION set_updated_at() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END $$;

-- Single-row table holding the current content version (used as ETag and
-- as the payload of real-time change notifications).
CREATE TABLE content_state (
  id          smallint    PRIMARY KEY DEFAULT 1 CHECK (id = 1),
  version     bigint      NOT NULL DEFAULT 1 CHECK (version > 0),
  updated_at  timestamptz NOT NULL DEFAULT now()
);
INSERT INTO content_state (id) VALUES (1);

CREATE OR REPLACE FUNCTION bump_content_version() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE v bigint;
BEGIN
  UPDATE content_state
     SET version = version + 1, updated_at = now()
   WHERE id = 1
  RETURNING version INTO v;
  PERFORM pg_notify('content_changed', v::text);  -- delivered on COMMIT
  RETURN NULL;
END $$;

-- =====================================================================
-- CONTENT (configuration) — everything the app renders comes from here
-- =====================================================================

-- Images, icons and animations (served by the backend or a CDN).
CREATE TABLE media_assets (
  id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  key         text        NOT NULL UNIQUE CHECK (key ~ '^[a-z0-9_.-]+$'),
  kind        text        NOT NULL CHECK (kind IN ('image', 'icon', 'animation')),
  format      text        NOT NULL CHECK (format IN ('png', 'webp', 'jpg', 'svg', 'lottie')),
  url         text        NOT NULL,          -- absolute, or relative to ASSET_BASE_URL
  width       integer     CHECK (width  > 0),
  height      integer     CHECK (height > 0),
  alt_text    text        NOT NULL DEFAULT '',
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now()
);

-- Static UI copy (titles, button labels, sheet texts, toasts…), per locale.
CREATE TABLE app_copy (
  key          text        NOT NULL CHECK (key ~ '^[a-z0-9_.]+$'),
  locale       text        NOT NULL DEFAULT 'en' CHECK (locale ~ '^[a-z]{2}(-[A-Z]{2})?$'),
  value        text        NOT NULL,
  description  text,
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (key, locale)
);

-- Beginner, Insider, …
CREATE TABLE journey_statuses (
  id                     uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  key                    text        NOT NULL UNIQUE CHECK (key ~ '^[a-z0-9_]+$'),
  title                  text        NOT NULL CHECK (length(title) BETWEEN 1 AND 60),
  position               integer     NOT NULL CHECK (position >= 0),
  card_background_color  text        NOT NULL CHECK (card_background_color ~ '^#[0-9A-Fa-f]{6}$'),
  card_shadow_color      text        NOT NULL CHECK (card_shadow_color     ~ '^#[0-9A-Fa-f]{6}$'),
  card_text_color        text        NOT NULL CHECK (card_text_color       ~ '^#[0-9A-Fa-f]{6}$'),
  is_published           boolean     NOT NULL DEFAULT true,
  created_at             timestamptz NOT NULL DEFAULT now(),
  updated_at             timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_status_position UNIQUE (position) DEFERRABLE INITIALLY DEFERRED
);

-- A status contains 1..n levels; each level renders one card on the path.
CREATE TABLE journey_levels (
  id                     uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  status_id              uuid        NOT NULL REFERENCES journey_statuses(id) ON DELETE RESTRICT,
  key                    text        NOT NULL UNIQUE CHECK (key ~ '^[a-z0-9_]+$'),
  label                  text        NOT NULL CHECK (length(label) BETWEEN 1 AND 30),   -- 'LEVEL-1'
  title                  text        NOT NULL CHECK (length(title) BETWEEN 1 AND 80),   -- 'Psychology of weight'
  position               integer     NOT NULL CHECK (position >= 0),
  illustration_asset_id  uuid        REFERENCES media_assets(id) ON DELETE RESTRICT,
  is_published           boolean     NOT NULL DEFAULT true,
  created_at             timestamptz NOT NULL DEFAULT now(),
  updated_at             timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_level_position UNIQUE (status_id, position) DEFERRABLE INITIALLY DEFERRED
);

-- The circles. Count and order are pure configuration.
CREATE TABLE journey_nodes (
  id             uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  level_id       uuid        NOT NULL REFERENCES journey_levels(id) ON DELETE RESTRICT,
  key            text        NOT NULL UNIQUE CHECK (key ~ '^[a-z0-9_]+$'),
  node_type      text        NOT NULL CHECK (node_type IN ('lesson', 'checkpoint')),
  title          text        NOT NULL CHECK (length(title) BETWEEN 1 AND 80),   -- accessibility/search, e.g. 'Day 3'
  position       integer     NOT NULL CHECK (position >= 0),
  icon_asset_id  uuid        NOT NULL REFERENCES media_assets(id) ON DELETE RESTRICT,
  is_published   boolean     NOT NULL DEFAULT true,
  created_at     timestamptz NOT NULL DEFAULT now(),
  updated_at     timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_node_position UNIQUE (level_id, position) DEFERRABLE INITIALLY DEFERRED
);
-- Rule enforced by the content validator (not expressible as a simple
-- constraint): a 'checkpoint' node has exactly one published lesson.

CREATE TABLE lessons (
  id                   uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  node_id              uuid        NOT NULL REFERENCES journey_nodes(id) ON DELETE RESTRICT,
  key                  text        NOT NULL UNIQUE CHECK (key ~ '^[a-z0-9_]+$'),
  title                text        NOT NULL CHECK (length(title) BETWEEN 1 AND 120),
  summary              text        NOT NULL DEFAULT '',
  position             integer     NOT NULL CHECK (position >= 0),
  completion_headline  text        NOT NULL,                 -- 'You have won the day 😎'
  completion_message   text        NOT NULL,                 -- varies per lesson
  completion_asset_id  uuid        REFERENCES media_assets(id) ON DELETE RESTRICT,  -- null -> default medal
  is_published         boolean     NOT NULL DEFAULT true,
  search_vector        tsvector    GENERATED ALWAYS AS (
                         to_tsvector('english', coalesce(title, '') || ' ' || coalesce(summary, ''))
                       ) STORED,
  created_at           timestamptz NOT NULL DEFAULT now(),
  updated_at           timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_lesson_position UNIQUE (node_id, position) DEFERRABLE INITIALLY DEFERRED
);
CREATE INDEX ix_lessons_search_vector ON lessons USING gin (search_vector);
CREATE INDEX ix_lessons_title_trgm   ON lessons USING gin (title gin_trgm_ops);

CREATE TABLE lesson_pages (
  id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  lesson_id   uuid        NOT NULL REFERENCES lessons(id) ON DELETE CASCADE,
  position    integer     NOT NULL CHECK (position >= 0),
  page_type   text        NOT NULL CHECK (page_type IN ('content', 'question')),
  cta_label   text        NOT NULL CHECK (length(cta_label) BETWEEN 1 AND 40),  -- 'THAT'S IMPRACTICAL!'
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_page_position UNIQUE (lesson_id, position) DEFERRABLE INITIALLY DEFERRED,
  CONSTRAINT uq_page_id_type  UNIQUE (id, page_type)      -- target of composite FK below
);

-- Rich content of a page (also the intro/prompt above a question's options).
-- Inline text uses a small validated markup:
--   **bold**  *italic*  ==highlight==  {{user.name}}  {{answer.<answer_key>}}
CREATE TABLE page_blocks (
  id               uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  page_id          uuid        NOT NULL REFERENCES lesson_pages(id) ON DELETE CASCADE,
  parent_block_id  uuid,                         -- set only for children of an accordion
  position         integer     NOT NULL CHECK (position >= 0),
  block_type       text        NOT NULL CHECK (block_type IN (
                     'heading', 'paragraph', 'bulleted_list', 'numbered_list',
                     'image', 'callout', 'icon_heading', 'accordion', 'spacer')),
  content          jsonb       NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(content) = 'object'),
  media_asset_id   uuid        REFERENCES media_assets(id) ON DELETE RESTRICT,
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_block_id_page UNIQUE (id, page_id),
  -- a child block must live on the same page as its parent
  CONSTRAINT fk_block_parent FOREIGN KEY (parent_block_id, page_id)
    REFERENCES page_blocks (id, page_id) ON DELETE CASCADE,
  -- minimal shape guarantees; full JSON schema is validated by the API
  CONSTRAINT ck_block_shape CHECK (
    CASE block_type
      WHEN 'heading'       THEN content ? 'text'
      WHEN 'paragraph'     THEN content ? 'text'
      WHEN 'bulleted_list' THEN jsonb_typeof(content -> 'items') = 'array'
      WHEN 'numbered_list' THEN jsonb_typeof(content -> 'items') = 'array'
      WHEN 'image'         THEN media_asset_id IS NOT NULL
      WHEN 'callout'       THEN content ? 'text' AND media_asset_id IS NOT NULL
      WHEN 'icon_heading'  THEN content ? 'text'
      WHEN 'accordion'     THEN content ? 'title'
      WHEN 'spacer'        THEN true
      ELSE false
    END)
);
CREATE UNIQUE INDEX ux_blocks_top_position
  ON page_blocks (page_id, position) WHERE parent_block_id IS NULL;
CREATE UNIQUE INDEX ux_blocks_child_position
  ON page_blocks (parent_block_id, position) WHERE parent_block_id IS NOT NULL;
CREATE INDEX ix_blocks_media ON page_blocks (media_asset_id) WHERE media_asset_id IS NOT NULL;

-- Question metadata; exists only for pages whose page_type = 'question'.
CREATE TABLE page_questions (
  page_id             uuid        PRIMARY KEY,
  page_type           text        NOT NULL DEFAULT 'question' CHECK (page_type = 'question'),
  response_type       text        NOT NULL CHECK (response_type IN ('single_choice', 'multiple_choice', 'free_text')),
  is_graded           boolean     NOT NULL DEFAULT false,
  min_selections      smallint    CHECK (min_selections >= 0),
  max_selections      smallint    CHECK (max_selections >= 1),
  answer_key          text        CHECK (answer_key ~ '^[a-z][a-z0-9_]*$'),  -- enables {{answer.key}}
  input_placeholder   text,
  min_length          smallint    CHECK (min_length >= 0),
  max_length          smallint    CHECK (max_length BETWEEN 1 AND 2000),
  validation_message  text,       -- e.g. the 'please write your thoughts' toast
  explanation         text,       -- shown on the feedback card (markup allowed)
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT fk_question_page FOREIGN KEY (page_id, page_type)
    REFERENCES lesson_pages (id, page_type) ON DELETE CASCADE,
  CONSTRAINT ck_graded_is_choice   CHECK (NOT is_graded OR response_type <> 'free_text'),
  CONSTRAINT ck_selection_range    CHECK (min_selections IS NULL OR max_selections IS NULL
                                          OR min_selections <= max_selections),
  CONSTRAINT ck_length_range       CHECK (min_length IS NULL OR max_length IS NULL
                                          OR min_length <= max_length),
  CONSTRAINT ck_single_choice_max  CHECK (response_type <> 'single_choice'
                                          OR coalesce(max_selections, 1) = 1)
);
-- Validator rules: choice questions need >= 2 options; graded single_choice
-- needs exactly one correct option; free_text has no options.

CREATE TABLE question_options (
  id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  page_id     uuid        NOT NULL REFERENCES page_questions(page_id) ON DELETE CASCADE,
  position    integer     NOT NULL CHECK (position >= 0),
  label       text        NOT NULL CHECK (length(label) BETWEEN 1 AND 200),
  is_correct  boolean     NOT NULL DEFAULT false,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_option_position UNIQUE (page_id, position) DEFERRABLE INITIALLY DEFERRED,
  CONSTRAINT uq_option_label    UNIQUE (page_id, label),
  CONSTRAINT uq_option_id_page  UNIQUE (id, page_id)
);

-- Pool of rotating feedback headlines + illustrations ('Not quite, but…').
CREATE TABLE answer_feedback_messages (
  id                     uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  key                    text        NOT NULL UNIQUE CHECK (key ~ '^[a-z0-9_]+$'),
  outcome                text        NOT NULL CHECK (outcome IN ('correct', 'incorrect')),
  headline               text        NOT NULL,
  illustration_asset_id  uuid        NOT NULL REFERENCES media_assets(id) ON DELETE RESTRICT,
  weight                 smallint    NOT NULL DEFAULT 1 CHECK (weight > 0),
  is_active              boolean     NOT NULL DEFAULT true,
  created_at             timestamptz NOT NULL DEFAULT now(),
  updated_at             timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX ix_feedback_messages_outcome ON answer_feedback_messages (outcome) WHERE is_active;

-- Checkbox options in the 'Faced some issue?' dialog.
CREATE TABLE feedback_reasons (
  id             uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  key            text        NOT NULL UNIQUE CHECK (key ~ '^[a-z0-9_]+$'),
  label          text        NOT NULL,
  position       integer     NOT NULL CHECK (position >= 0),
  requires_text  boolean     NOT NULL DEFAULT false,   -- 'Others'
  is_active      boolean     NOT NULL DEFAULT true,
  created_at     timestamptz NOT NULL DEFAULT now(),
  updated_at     timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_reason_position UNIQUE (position) DEFERRABLE INITIALLY DEFERRED
);

-- =====================================================================
-- USER STATE — progress, answers, points, bookmarks, feedback
-- =====================================================================

-- No authentication: a seeded demo user; the app sends its id.
CREATE TABLE users (
  id                    uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  display_name          text        NOT NULL CHECK (length(display_name) BETWEEN 1 AND 60),
  health_points_total   integer     NOT NULL DEFAULT 0 CHECK (health_points_total >= 0), -- cache of ledger
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now()
);

-- One row per time a user starts a lesson. Mid-lesson resume is not
-- supported (matches 'Your progress will be lost'), so abandoned attempts
-- are kept only for analytics.
CREATE TABLE lesson_attempts (
  id                    uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id               uuid        NOT NULL REFERENCES users(id)   ON DELETE CASCADE,
  lesson_id             uuid        NOT NULL REFERENCES lessons(id) ON DELETE RESTRICT,
  status                text        NOT NULL DEFAULT 'in_progress'
                                    CHECK (status IN ('in_progress', 'completed', 'abandoned')),
  content_version       bigint      NOT NULL,        -- content_state.version at start
  health_points_earned  integer     NOT NULL DEFAULT 0 CHECK (health_points_earned >= 0),
  started_at            timestamptz NOT NULL DEFAULT now(),
  completed_at          timestamptz,
  abandoned_at          timestamptz,
  CONSTRAINT ck_attempt_completed CHECK ((status = 'completed') = (completed_at IS NOT NULL)),
  CONSTRAINT ck_attempt_abandoned CHECK ((status = 'abandoned') = (abandoned_at IS NOT NULL))
);
CREATE INDEX ix_attempts_user_lesson ON lesson_attempts (user_id, lesson_id, started_at DESC);
CREATE INDEX ix_attempts_lesson      ON lesson_attempts (lesson_id);

-- One answer per question per attempt (re-answering after Back = upsert).
CREATE TABLE attempt_answers (
  id                   uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  attempt_id           uuid        NOT NULL REFERENCES lesson_attempts(id) ON DELETE CASCADE,
  page_id              uuid        NOT NULL REFERENCES page_questions(page_id) ON DELETE RESTRICT,
  free_text            text        CHECK (length(free_text) <= 2000),
  is_correct           boolean,    -- NULL for ungraded questions
  feedback_message_id  uuid        REFERENCES answer_feedback_messages(id) ON DELETE SET NULL,
  answered_at          timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_answer_per_question UNIQUE (attempt_id, page_id),
  CONSTRAINT uq_answer_id_page      UNIQUE (id, page_id)
);
CREATE INDEX ix_answers_page ON attempt_answers (page_id);

-- Selected options; composite FKs guarantee the option belongs to the
-- same question that was answered.
CREATE TABLE attempt_answer_options (
  answer_id  uuid NOT NULL,
  page_id    uuid NOT NULL,
  option_id  uuid NOT NULL,
  PRIMARY KEY (answer_id, option_id),
  CONSTRAINT fk_aao_answer FOREIGN KEY (answer_id, page_id)
    REFERENCES attempt_answers (id, page_id) ON DELETE CASCADE,
  CONSTRAINT fk_aao_option FOREIGN KEY (option_id, page_id)
    REFERENCES question_options (id, page_id) ON DELETE RESTRICT
);
CREATE INDEX ix_aao_option ON attempt_answer_options (option_id);

-- Summary used to render checkmarks quickly.
CREATE TABLE user_lesson_progress (
  user_id             uuid        NOT NULL REFERENCES users(id)   ON DELETE CASCADE,
  lesson_id           uuid        NOT NULL REFERENCES lessons(id) ON DELETE CASCADE,
  first_completed_at  timestamptz NOT NULL,
  last_completed_at   timestamptz NOT NULL,
  completion_count    integer     NOT NULL DEFAULT 1 CHECK (completion_count >= 1),
  PRIMARY KEY (user_id, lesson_id),
  CONSTRAINT ck_progress_dates CHECK (last_completed_at >= first_completed_at)
);
CREATE INDEX ix_progress_lesson ON user_lesson_progress (lesson_id);

-- A node is recorded complete once all its lessons are done. Kept explicit
-- so that adding a lesson later does not re-lock a user's journey.
CREATE TABLE user_node_completions (
  user_id       uuid        NOT NULL REFERENCES users(id)         ON DELETE CASCADE,
  node_id       uuid        NOT NULL REFERENCES journey_nodes(id) ON DELETE CASCADE,
  completed_at  timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, node_id)
);
CREATE INDEX ix_node_completions_node ON user_node_completions (node_id);

-- Append-only points ledger; users.health_points_total is updated in the
-- same transaction.
CREATE TABLE health_point_transactions (
  id                 bigint      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id            uuid        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  amount             integer     NOT NULL CHECK (amount <> 0),
  reason             text        NOT NULL CHECK (reason IN ('lesson_completed', 'adjustment')),
  lesson_attempt_id  uuid        UNIQUE REFERENCES lesson_attempts(id) ON DELETE SET NULL,
  created_at         timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX ix_hp_user ON health_point_transactions (user_id, created_at DESC);

CREATE TABLE saved_lessons (
  user_id     uuid        NOT NULL REFERENCES users(id)   ON DELETE CASCADE,
  lesson_id   uuid        NOT NULL REFERENCES lessons(id) ON DELETE CASCADE,
  created_at  timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, lesson_id)
);
CREATE INDEX ix_saved_lesson ON saved_lessons (lesson_id);

CREATE TABLE lesson_feedback (
  id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid        NOT NULL REFERENCES users(id)   ON DELETE CASCADE,
  lesson_id   uuid        NOT NULL REFERENCES lessons(id) ON DELETE CASCADE,
  page_id     uuid        REFERENCES lesson_pages(id)     ON DELETE SET NULL,  -- page it was sent from
  comment     text        CHECK (length(comment) <= 1000),
  created_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX ix_feedback_lesson ON lesson_feedback (lesson_id, created_at DESC);
CREATE INDEX ix_feedback_user   ON lesson_feedback (user_id);

CREATE TABLE lesson_feedback_reasons (
  feedback_id  uuid NOT NULL REFERENCES lesson_feedback(id)  ON DELETE CASCADE,
  reason_id    uuid NOT NULL REFERENCES feedback_reasons(id) ON DELETE RESTRICT,
  PRIMARY KEY (feedback_id, reason_id)
);
CREATE INDEX ix_feedback_reasons_reason ON lesson_feedback_reasons (reason_id);

-- ---------------------------------------------------------------------
-- Indexes on content foreign keys not already covered by a unique index
-- ---------------------------------------------------------------------
CREATE INDEX ix_levels_illustration ON journey_levels (illustration_asset_id);
CREATE INDEX ix_nodes_icon          ON journey_nodes  (icon_asset_id);
CREATE INDEX ix_lessons_completion  ON lessons        (completion_asset_id);
CREATE INDEX ix_blocks_parent       ON page_blocks    (parent_block_id) WHERE parent_block_id IS NOT NULL;

-- ---------------------------------------------------------------------
-- Triggers: updated_at on mutable tables, content version on content tables
-- ---------------------------------------------------------------------
DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'media_assets', 'app_copy', 'journey_statuses', 'journey_levels', 'journey_nodes',
    'lessons', 'lesson_pages', 'page_blocks', 'page_questions', 'question_options',
    'answer_feedback_messages', 'feedback_reasons', 'users'
  ] LOOP
    EXECUTE format(
      'CREATE TRIGGER trg_%1$s_updated_at BEFORE UPDATE ON %1$I
         FOR EACH ROW EXECUTE FUNCTION set_updated_at()', t);
  END LOOP;

  FOREACH t IN ARRAY ARRAY[
    'media_assets', 'app_copy', 'journey_statuses', 'journey_levels', 'journey_nodes',
    'lessons', 'lesson_pages', 'page_blocks', 'page_questions', 'question_options',
    'answer_feedback_messages', 'feedback_reasons'
  ] LOOP
    EXECUTE format(
      'CREATE TRIGGER trg_%1$s_content_version
         AFTER INSERT OR UPDATE OR DELETE OR TRUNCATE ON %1$I
         FOR EACH STATEMENT EXECUTE FUNCTION bump_content_version()', t);
  END LOOP;
END $$;
