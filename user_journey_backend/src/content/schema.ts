import { z } from 'zod';

/**
 * Zod schema for seed/journey_content.yaml and seed/asset-manifest.json.
 * `provenance`, `notes` and `corrections` are documentation only (accepted, never stored).
 * Every object is strict so a typo in a key is reported instead of silently ignored.
 */

const doc = {
  provenance: z.string().optional(),
  notes: z.string().optional(),
  corrections: z.array(z.string()).optional(),
};

const key = z.string().regex(/^[a-z0-9_]+$/, 'keys use lowercase letters, digits and underscores');
const assetKey = z.string().regex(/^[a-z0-9_.-]+$/);
const hexColor = z.string().regex(/^#[0-9A-Fa-f]{6}$/, 'must be a #RRGGBB colour');
const text = z.string();

const leafBlocks = [
  z.strictObject({ type: z.literal('heading'), text, ...doc }),
  z.strictObject({ type: z.literal('paragraph'), text, ...doc }),
  z.strictObject({ type: z.literal('bulleted_list'), items: z.array(text).min(1), ...doc }),
  z.strictObject({ type: z.literal('numbered_list'), items: z.array(text).min(1), ...doc }),
  z.strictObject({ type: z.literal('image'), asset: assetKey, ...doc }),
  z.strictObject({ type: z.literal('callout'), text, asset: assetKey, ...doc }),
  z.strictObject({
    type: z.literal('icon_heading'),
    text,
    color: hexColor,
    asset: assetKey.optional(),
    ...doc,
  }),
  z.strictObject({ type: z.literal('spacer'), size: z.number().positive().max(200), ...doc }),
] as const;

export const LeafBlockSchema = z.discriminatedUnion('type', [...leafBlocks]);

// Accordion children are parsed loosely here so the validator can report
// "accordion children belong to an accordion parent" (e.g. nested accordions) with a clear message.
export const AccordionBlockSchema = z.strictObject({
  type: z.literal('accordion'),
  title: text,
  children: z.array(z.looseObject({ type: z.string() })).min(1),
  ...doc,
});

export const BlockSchema = z.discriminatedUnion('type', [...leafBlocks, AccordionBlockSchema]);

const OptionSchema = z.union([
  z.string().min(1),
  z.strictObject({ label: z.string().min(1), correct: z.boolean().optional() }),
]);

export const QuestionSchema = z.strictObject({
  response: z.enum(['single_choice', 'multiple_choice', 'free_text']),
  graded: z.boolean().default(false),
  min_selections: z.number().int().min(0).optional(),
  max_selections: z.number().int().min(1).optional(),
  answer_key: z
    .string()
    .regex(/^[a-z][a-z0-9_]*$/)
    .optional(),
  input_placeholder: z.string().optional(),
  min_length: z.number().int().min(0).optional(),
  max_length: z.number().int().min(1).max(2000).optional(),
  validation_message: z.string().optional(),
  explanation: z.string().optional(),
  options: z.array(OptionSchema).optional(),
});

export const PageSchema = z.strictObject({
  type: z.enum(['content', 'question']),
  cta: z.string().min(1).max(40),
  blocks: z.array(z.unknown()).default([]),
  question: QuestionSchema.optional(),
  ...doc,
});

const CompletionSchema = z.strictObject({
  headline: z.string().min(1),
  message: z.string().min(1),
  asset: assetKey.optional(),
});

export const LessonSchema = z.strictObject({
  key,
  title: z.string().min(1).max(120),
  summary: z.string().optional(),
  completion: CompletionSchema.optional(),
  pages: z.array(PageSchema).optional(),
  ...doc,
});

export const NodeSchema = z.strictObject({
  key,
  type: z.enum(['lesson', 'checkpoint']),
  title: z.string().min(1).max(80),
  icon: assetKey,
  lessons: z.array(LessonSchema),
  ...doc,
});

export const LevelSchema = z.strictObject({
  key,
  label: z.string().min(1).max(30),
  title: z.string().min(1).max(80),
  illustration: assetKey.optional(),
  nodes: z.array(NodeSchema),
  ...doc,
});

export const StatusSchema = z.strictObject({
  key,
  title: z.string().min(1).max(60),
  card_background_color: hexColor,
  card_shadow_color: hexColor,
  card_text_color: hexColor,
  levels: z.array(LevelSchema),
  ...doc,
});

export const ContentFileSchema = z.strictObject({
  meta: z.strictObject({ content_version_note: z.string().optional(), locale: z.string().default('en') }),
  demo_user: z.strictObject({ id: z.uuid(), display_name: z.string().min(1).max(60) }),
  app_copy: z.record(z.string().regex(/^[a-z0-9_.]+$/, 'copy keys use [a-z0-9_.]'), z.string()),
  answer_feedback_messages: z.array(
    z.strictObject({
      key,
      outcome: z.enum(['correct', 'incorrect']),
      asset: assetKey,
      headline: z.string().min(1),
      weight: z.number().int().min(1).max(32767).optional(),
      active: z.boolean().optional(),
    }),
  ),
  feedback_reasons: z.array(
    z.strictObject({ key, label: z.string().min(1), requires_text: z.boolean().optional() }),
  ),
  ui_assets: z.record(key, assetKey),
  statuses: z.array(StatusSchema),
  placeholder_template: z.strictObject({ cta: z.string().min(1).max(40), completion: CompletionSchema }),
});

export const ManifestSchema = z.looseObject({
  assets: z.array(
    z.looseObject({
      key: assetKey,
      file: z.string().regex(/^[A-Za-z0-9_.-]+$/),
      kind: z.enum(['image', 'icon', 'animation']),
      format: z.enum(['png', 'webp', 'jpg', 'svg', 'lottie']),
      alt_text: z.string().default(''),
    }),
  ),
});

export type ContentFile = z.infer<typeof ContentFileSchema>;
export type Manifest = z.infer<typeof ManifestSchema>;
export type YamlLesson = z.infer<typeof LessonSchema>;
export type YamlPage = z.infer<typeof PageSchema>;
export type YamlQuestion = z.infer<typeof QuestionSchema>;
