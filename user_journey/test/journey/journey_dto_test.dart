import 'package:flutter_test/flutter_test.dart';
import 'package:user_journey/features/journey/data/journey_dto.dart';
import 'package:user_journey/features/journey/domain/journey.dart';

import '../helpers/fixtures.dart';

void main() {
  test('parses the journey contract', () {
    final journey = parseJourney(journeyJson(completed: 1));
    expect(journey.contentVersion, 1);
    expect(journey.statuses.map((s) => s.title), ['Beginner', 'Insider']);
    final level = journey.statuses.first.levels.single;
    expect(level.label, 'LEVEL-1');
    expect(level.nodes, hasLength(7));
    expect(level.nodes.last.type, NodeType.checkpoint);
    expect(level.nodes.first.state, ProgressState.completed);
    expect(level.nodes.first.completedAt, DateTime.utc(2026, 10, 12, 10));
    expect(level.nodes[1].state, ProgressState.available);
    expect(journey.statuses.first.cardTheme.background.toARGB32(), 0xFFF9E4C9);
  });

  test('unknown node types render as lesson nodes; unknown states are locked', () {
    final json = journeyJson();
    final node = ((((json['statuses'] as List).first as Map)['levels'] as List).first as Map)['nodes'] as List;
    (node.first as Map)
      ..['type'] = 'boss_fight'
      ..['state'] = 'glowing';
    final parsed = parseJourney(json).statuses.first.levels.first.nodes.first;
    expect(parsed.type, NodeType.lesson);
    expect(parsed.state, ProgressState.locked);
  });

  test('malformed responses throw FormatException/TypeError (→ ParsingFailure)', () {
    expect(() => parseJourney({'statuses': []}), throwsA(anything)); // no contentVersion
    expect(() => parseJourney({'contentVersion': 1, 'statuses': 'nope'}), throwsFormatException);
    expect(() => parseJourney('not an object'), throwsFormatException);
  });

  test('popover action follows SPEC 4.6', () {
    final nodes = parseJourney(journeyJson(completed: 1)).statuses.first.levels.first.nodes;
    expect(popoverActionFor(nodes[0])!.action, PopoverAction.doItAgain);
    expect(popoverActionFor(nodes[1])!.action, PopoverAction.start);
    expect(popoverActionFor(nodes[2]), isNull); // locked
    final partial = parseJourney({
      'contentVersion': 1,
      'statuses': [
        {
          'id': 's',
          'key': 's',
          'title': 'S',
          'cardTheme': {},
          'levels': [
            {
              'id': 'l',
              'key': 'l',
              'label': 'L',
              'title': 'T',
              'nodes': [nodeJson('n', state: 'available', lessons: 3, completedLessons: 1)],
            },
          ],
        },
      ],
    }).nodes.single;
    final action = popoverActionFor(partial)!;
    expect(action.action, PopoverAction.continueLesson);
    expect(action.lessonId, 'n-l1');
  });
}
