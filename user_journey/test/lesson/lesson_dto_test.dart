import 'package:flutter_test/flutter_test.dart';
import 'package:user_journey/features/lesson/data/lesson_dto.dart';
import 'package:user_journey/features/lesson/domain/lesson.dart';

Map<String, Object?> lessonJson(List<Object?> blocks, {Map<String, Object?>? question}) => {
  'id': 'l1',
  'title': 'Welcome',
  'nodeId': 'n1',
  'nodeType': 'lesson',
  'isSaved': true,
  'pageCount': 1,
  'pages': [
    {
      'id': 'p1',
      'position': 0,
      'type': question == null ? 'content' : 'question',
      'ctaLabel': 'NEXT',
      'blocks': blocks,
      'question': question,
    },
  ],
};

void main() {
  test('parses every block type including accordion children', () {
    final lesson = parseLesson(
      lessonJson([
        {'id': '1', 'type': 'heading', 'text': 'H'},
        {'id': '2', 'type': 'paragraph', 'text': 'P'},
        {
          'id': '3',
          'type': 'bulleted_list',
          'items': ['a'],
        },
        {
          'id': '4',
          'type': 'numbered_list',
          'items': ['a', 'b'],
        },
        {
          'id': '5',
          'type': 'image',
          'asset': {'url': '/static/assets/x.png', 'width': 10, 'height': 5},
        },
        {
          'id': '6',
          'type': 'callout',
          'text': 'C',
          'asset': {'url': '/static/assets/y.png'},
        },
        {'id': '7', 'type': 'icon_heading', 'text': 'ZONE-1', 'color': '#F5A04A', 'asset': null},
        {
          'id': '8',
          'type': 'accordion',
          'title': 'More',
          'children': [
            {
              'id': '9',
              'type': 'bulleted_list',
              'items': ['x'],
            },
          ],
        },
        {'id': '10', 'type': 'spacer', 'size': 24},
      ]),
    );
    final blocks = lesson.pages.single.blocks;
    expect(blocks.map((b) => b.runtimeType.toString()), [
      'HeadingBlock',
      'ParagraphBlock',
      'ListBlock',
      'ListBlock',
      'ImageBlock',
      'CalloutBlock',
      'IconHeadingBlock',
      'AccordionBlock',
      'SpacerBlock',
    ]);
    expect((blocks[3] as ListBlock).ordered, isTrue);
    expect((blocks[4] as ImageBlock).asset!.aspectRatio, 2);
    expect((blocks[7] as AccordionBlock).children.single, isA<ListBlock>());
    expect(lesson.isSaved, isTrue);
  });

  test('unknown and malformed blocks are skipped; the rest of the page renders', () {
    final lesson = parseLesson(
      lessonJson([
        {'id': '1', 'type': 'paragraph', 'text': 'kept'},
        {'id': '2', 'type': 'video', 'url': 'x'},
        {'id': '3', 'type': 'paragraph'}, // missing text
        'not an object',
        {'id': '4', 'type': 'heading', 'text': 'also kept'},
      ]),
    );
    expect(lesson.pages.single.blocks.map((b) => b.id), ['1', '4']);
  });

  test('question payload (no correctness fields)', () {
    final lesson = parseLesson(
      lessonJson(
        [],
        question: {
          'responseType': 'single_choice',
          'isGraded': true,
          'minSelections': null,
          'maxSelections': 1,
          'answerKey': null,
          'inputPlaceholder': null,
          'minLength': null,
          'maxLength': null,
          'validationMessage': null,
          'options': [
            {'id': 'o1', 'label': 'A'},
            {'id': 'o2', 'label': 'B'},
          ],
        },
      ),
    );
    final page = lesson.pages.single;
    expect(page.isQuestion, isTrue);
    expect(page.question!.responseType, ResponseType.singleChoice);
    expect(page.question!.options.map((o) => o.label), ['A', 'B']);
  });

  test('an unknown response type renders the page as content', () {
    final lesson = parseLesson(lessonJson([], question: {'responseType': 'slider', 'options': []}));
    expect(lesson.pages.single.isQuestion, isFalse);
  });

  test('a malformed lesson (missing pages) throws → ParsingFailure', () {
    expect(() => parseLesson({'id': 'x', 'title': 't', 'nodeId': 'n'}), throwsFormatException);
  });

  test('answer and completion payloads', () {
    final answer = parseAnswerResult({
      'pageId': 'p1',
      'isCorrect': false,
      'feedback': {
        'headline': 'Not quite',
        'illustration': {'url': '/static/assets/f.png'},
        'correctAnswers': ['Raisins'],
        'explanation': null,
      },
    });
    expect(answer.feedback!.correctAnswers, ['Raisins']);
    expect(parseAnswerResult({'pageId': 'p', 'isCorrect': null, 'feedback': null}).feedback, isNull);
    final done = parseCompletion({
      'attemptId': 'a',
      'lessonId': 'l',
      'completedAt': '2026-10-13T00:00:00Z',
      'firstCompletion': true,
      'healthPointsEarned': 13,
      'healthPointsTotal': 50,
      'nodeCompleted': false,
      'unlockedNodeId': null,
      'completion': {
        'headline': 'You have won the day 😎',
        'message': 'm',
        'asset': {'url': '/static/assets/ui_completion_medal.png'},
      },
    });
    expect(done.healthPointsEarned, 13);
    expect(done.asset!.url, '/static/assets/ui_completion_medal.png');
  });
}
