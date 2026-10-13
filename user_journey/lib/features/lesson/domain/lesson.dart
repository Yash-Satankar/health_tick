import 'package:flutter/foundation.dart';

import '../../../core/models/asset_ref.dart';

/// Content blocks (SPEC §6.2). Unknown block types are skipped when parsing.
@immutable
sealed class LessonBlock {
  const LessonBlock(this.id);
  final String id;
}

final class HeadingBlock extends LessonBlock {
  const HeadingBlock(super.id, this.text);
  final String text;
}

final class ParagraphBlock extends LessonBlock {
  const ParagraphBlock(super.id, this.text);
  final String text;
}

final class ListBlock extends LessonBlock {
  const ListBlock(super.id, this.items, {required this.ordered});
  final List<String> items;
  final bool ordered;
}

final class ImageBlock extends LessonBlock {
  const ImageBlock(super.id, this.asset);
  final AssetRef? asset;
}

final class CalloutBlock extends LessonBlock {
  const CalloutBlock(super.id, this.text, this.asset);
  final String text;
  final AssetRef? asset;
}

final class IconHeadingBlock extends LessonBlock {
  const IconHeadingBlock(super.id, this.text, this.color, this.asset);
  final String text;
  final String? color;
  final AssetRef? asset;
}

final class AccordionBlock extends LessonBlock {
  const AccordionBlock(super.id, this.title, this.children);
  final String title;
  final List<LessonBlock> children;
}

final class SpacerBlock extends LessonBlock {
  const SpacerBlock(super.id, this.size);
  final double size;
}

enum ResponseType { singleChoice, multipleChoice, freeText }

@immutable
class QuestionOption {
  const QuestionOption({required this.id, required this.label});
  final String id;
  final String label;
}

@immutable
class Question {
  const Question({
    required this.responseType,
    required this.isGraded,
    required this.options,
    this.minSelections,
    this.maxSelections,
    this.answerKey,
    this.inputPlaceholder,
    this.minLength,
    this.maxLength,
    this.validationMessage,
  });

  final ResponseType responseType;
  final bool isGraded;
  final List<QuestionOption> options;
  final int? minSelections;
  final int? maxSelections;
  final String? answerKey;
  final String? inputPlaceholder;
  final int? minLength;
  final int? maxLength;
  final String? validationMessage;

  bool get isChoice => responseType != ResponseType.freeText;
  int get effectiveMinSelections => responseType == ResponseType.singleChoice ? 1 : (minSelections ?? 1);
  int? get effectiveMaxSelections => responseType == ResponseType.singleChoice ? 1 : maxSelections;
  int get effectiveMinLength => minLength ?? 1;
  int get effectiveMaxLength => maxLength ?? 2000;
}

enum PageType { content, question }

@immutable
class LessonPage {
  const LessonPage({
    required this.id,
    required this.position,
    required this.type,
    required this.ctaLabel,
    required this.blocks,
    this.question,
  });

  final String id;
  final int position;
  final PageType type;
  final String ctaLabel;
  final List<LessonBlock> blocks;
  final Question? question;

  bool get isQuestion => type == PageType.question && question != null;
}

@immutable
class Lesson {
  const Lesson({
    required this.id,
    required this.title,
    required this.nodeId,
    required this.nodeType,
    required this.isSaved,
    required this.pages,
  });

  final String id;
  final String title;
  final String nodeId;
  final String nodeType;
  final bool isSaved;
  final List<LessonPage> pages;

  int get pageCount => pages.length;
}

@immutable
class AnswerFeedback {
  const AnswerFeedback({
    required this.headline,
    required this.illustration,
    required this.correctAnswers,
    this.explanation,
  });

  final String headline;
  final AssetRef? illustration;
  final List<String> correctAnswers;
  final String? explanation;
}

@immutable
class AnswerResult {
  const AnswerResult({required this.pageId, this.isCorrect, this.feedback});
  final String pageId;
  final bool? isCorrect;
  final AnswerFeedback? feedback;
}

@immutable
class LessonCompletion {
  const LessonCompletion({
    required this.attemptId,
    required this.firstCompletion,
    required this.healthPointsEarned,
    required this.healthPointsTotal,
    required this.nodeCompleted,
    required this.headline,
    required this.message,
    this.unlockedNodeId,
    this.asset,
  });

  final String attemptId;
  final bool firstCompletion;
  final int healthPointsEarned;
  final int healthPointsTotal;
  final bool nodeCompleted;
  final String? unlockedNodeId;
  final String headline;
  final String message;
  final AssetRef? asset;
}

abstract interface class LessonRepository {
  Future<Lesson> getLesson(String lessonId);
  Future<String> startAttempt(String lessonId);
  Future<AnswerResult> submitChoice(String attemptId, String pageId, List<String> optionIds);
  Future<AnswerResult> submitText(String attemptId, String pageId, String text);
  Future<LessonCompletion> complete(String attemptId);
  Future<void> abandon(String attemptId);
  Future<bool> setSaved(String lessonId, {required bool saved});
  Future<void> sendFeedback(String lessonId, {required List<String> reasonIds, String? comment, String? pageId});
}
