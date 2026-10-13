import 'package:flutter/foundation.dart';

import '../../../core/models/asset_ref.dart';
import '../../../core/network/api_client.dart';
import '../domain/lesson.dart';

/// Hand-written parsing for the polymorphic lesson payload (SPEC §6.2) so that unknown block types are
/// skipped (debug log) and the rest of the page still renders (SPEC §8.5).
Lesson parseLesson(Object? json) {
  final map = asJsonMap(json);
  final pages = _list(map['pages']).map(_page).toList(growable: false)
    ..sort((a, b) => a.position.compareTo(b.position));
  return Lesson(
    id: _str(map, 'id'),
    title: _str(map, 'title'),
    nodeId: _str(map, 'nodeId'),
    nodeType: map['nodeType'] as String? ?? 'lesson',
    isSaved: map['isSaved'] as bool? ?? false,
    pages: pages,
  );
}

List<Object?> _list(Object? value) {
  if (value is List) return value;
  throw FormatException('Expected a list, got ${value.runtimeType}');
}

String _str(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is String) return value;
  throw FormatException('"$key" must be a string');
}

int? _int(Object? value) => value is num ? value.toInt() : null;

LessonPage _page(Object? json) {
  final map = asJsonMap(json);
  final question = map['question'] == null ? null : _question(asJsonMap(map['question']));
  return LessonPage(
    id: _str(map, 'id'),
    position: _int(map['position']) ?? 0,
    type: map['type'] == 'question' && question != null ? PageType.question : PageType.content,
    ctaLabel: _str(map, 'ctaLabel'),
    blocks: parseBlocks(map['blocks']),
    question: question,
  );
}

Question? _question(Map<String, dynamic> map) {
  final type = switch (map['responseType']) {
    'single_choice' => ResponseType.singleChoice,
    'multiple_choice' => ResponseType.multipleChoice,
    'free_text' => ResponseType.freeText,
    _ => null,
  };
  if (type == null) {
    debugPrint('Lesson: unknown responseType ${map['responseType']}; page rendered as content');
    return null;
  }
  return Question(
    responseType: type,
    isGraded: map['isGraded'] as bool? ?? false,
    minSelections: _int(map['minSelections']),
    maxSelections: _int(map['maxSelections']),
    answerKey: map['answerKey'] as String?,
    inputPlaceholder: map['inputPlaceholder'] as String?,
    minLength: _int(map['minLength']),
    maxLength: _int(map['maxLength']),
    validationMessage: map['validationMessage'] as String?,
    options: _list(map['options'] ?? const [])
        .map((o) {
          final option = asJsonMap(o);
          return QuestionOption(id: _str(option, 'id'), label: _str(option, 'label'));
        })
        .toList(growable: false),
  );
}

/// Parses a block list; unknown or malformed blocks are skipped with a debug log.
List<LessonBlock> parseBlocks(Object? json) {
  if (json is! List) return const [];
  final blocks = <LessonBlock>[];
  for (final raw in json) {
    try {
      final block = _block(asJsonMap(raw));
      if (block != null) blocks.add(block);
    } on Object catch (error) {
      debugPrint('Lesson: skipped malformed block ($error)');
    }
  }
  return List.unmodifiable(blocks);
}

LessonBlock? _block(Map<String, dynamic> map) {
  final id = _str(map, 'id');
  final type = map['type'];
  final asset = AssetRef.fromJsonOrNull(map['asset']);
  switch (type) {
    case 'heading':
      return HeadingBlock(id, _str(map, 'text'));
    case 'paragraph':
      return ParagraphBlock(id, _str(map, 'text'));
    case 'bulleted_list':
    case 'numbered_list':
      final items = _list(map['items']).whereType<String>().toList(growable: false);
      return ListBlock(id, items, ordered: type == 'numbered_list');
    case 'image':
      return ImageBlock(id, asset);
    case 'callout':
      return CalloutBlock(id, _str(map, 'text'), asset);
    case 'icon_heading':
      return IconHeadingBlock(id, _str(map, 'text'), map['color'] as String?, asset);
    case 'accordion':
      return AccordionBlock(id, _str(map, 'title'), parseBlocks(map['children']));
    case 'spacer':
      return SpacerBlock(id, (map['size'] as num?)?.toDouble() ?? 16);
    default:
      debugPrint('Lesson: skipped unknown block type "$type"');
      return null;
  }
}

AnswerResult parseAnswerResult(Object? json) {
  final map = asJsonMap(json);
  final feedback = map['feedback'] == null ? null : asJsonMap(map['feedback']);
  return AnswerResult(
    pageId: _str(map, 'pageId'),
    isCorrect: map['isCorrect'] as bool?,
    feedback: feedback == null
        ? null
        : AnswerFeedback(
            headline: _str(feedback, 'headline'),
            illustration: AssetRef.fromJsonOrNull(feedback['illustration']),
            correctAnswers: _list(feedback['correctAnswers'] ?? const []).whereType<String>().toList(growable: false),
            explanation: feedback['explanation'] as String?,
          ),
  );
}

LessonCompletion parseCompletion(Object? json) {
  final map = asJsonMap(json);
  final completion = asJsonMap(map['completion']);
  return LessonCompletion(
    attemptId: _str(map, 'attemptId'),
    firstCompletion: map['firstCompletion'] as bool? ?? false,
    healthPointsEarned: _int(map['healthPointsEarned']) ?? 0,
    healthPointsTotal: _int(map['healthPointsTotal']) ?? 0,
    nodeCompleted: map['nodeCompleted'] as bool? ?? false,
    unlockedNodeId: map['unlockedNodeId'] as String?,
    headline: _str(completion, 'headline'),
    message: _str(completion, 'message'),
    asset: AssetRef.fromJsonOrNull(completion['asset']),
  );
}
