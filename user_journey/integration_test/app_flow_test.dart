// End-to-end flow (SPEC §11.4) against the local backend.
//
// Preconditions (see README "End-to-end test"):
//   docker compose up -d; cd user_journey_backend; npm run db:seed; npm run progress:reset; npm run dev
// Run (emulator):
//   flutter test integration_test/app_flow_test.dart --dart-define=API_BASE_URL=http://10.0.2.2:3000
//
// Flow: Home → Journey → open node 1 → complete the welcome lesson → back to the Journey (popover open)
// → finish node 1 → open a graded lesson → answer wrong → feedback → complete → the health total increased.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:user_journey/app.dart';
import 'package:user_journey/di.dart';
import 'package:user_journey/features/journey/presentation/widgets/journey_node_view.dart';
import 'package:user_journey/features/lesson/presentation/widgets/question_view.dart';

Finder byKey(String key) => find.byKey(ValueKey(key));

Finder nodeTitled(String title) =>
    find.byWidgetPredicate((w) => w is JourneyNodeView && w.node.title == title, description: 'node "$title"');

/// Pumps until [finder] matches (real network: pumpAndSettle alone is not enough).
Future<void> waitFor(WidgetTester tester, Finder finder, {Duration timeout = const Duration(seconds: 20)}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (finder.evaluate().isNotEmpty) return;
  }
  throw TestFailure('Timed out waiting for $finder');
}

int healthPoints(WidgetTester tester) {
  final text = tester.widget<Text>(find.descendant(of: byKey('home-health-points'), matching: find.byType(Text)));
  return int.parse(text.data!);
}

/// Plays the open lesson to its completion screen. On question pages it picks the first option
/// (or types an answer). Returns whether a feedback card was shown at least once.
Future<bool> playLesson(WidgetTester tester) async {
  var sawFeedback = false;
  for (var step = 0; step < 60; step++) {
    await tester.pumpAndSettle();
    if (byKey('completion-view').evaluate().isNotEmpty) return sawFeedback;
    final onFeedback = byKey('feedback-card').evaluate().isNotEmpty;
    if (!onFeedback) {
      final options = find.descendant(of: find.byType(ChoiceOptions), matching: find.byType(InkWell));
      if (options.evaluate().isNotEmpty) {
        await tester.ensureVisible(options.first);
        await tester.tap(options.first);
        await tester.pump();
      } else if (byKey('free-text').evaluate().isNotEmpty) {
        await tester.enterText(byKey('free-text'), 'Walk 10 minutes after dinner');
        await tester.pump();
      }
    }
    await tester.tap(byKey('lesson-cta'));
    await waitFor(
      tester,
      find.byWidgetPredicate(
        (w) =>
            w.key == const ValueKey('completion-view') ||
            w.key == const ValueKey('feedback-card') ||
            w.key == const ValueKey('lesson-cta'),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    if (byKey('feedback-card').evaluate().isNotEmpty) {
      sawFeedback = true;
      expect(byKey('feedback-correct-answer'), findsOneWidget);
    }
  }
  throw TestFailure('Lesson did not complete within 60 steps');
}

Future<void> continueFromCompletion(WidgetTester tester) async {
  await tester.tap(byKey('completion-continue'));
  await tester.pumpAndSettle();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Home → Journey → lessons → feedback → points increase', (tester) async {
    configureDependencies();
    await tester.pumpWidget(const HealthTickApp());
    await waitFor(tester, byKey('home-health-points'));
    final initialPoints = healthPoints(tester);

    // Home → Journey
    await tester.tap(byKey('home-journey-link'));
    await waitFor(tester, nodeTitled('Day 1'));

    // Open node 1 → START → welcome lesson
    await tester.tap(nodeTitled('Day 1'));
    await waitFor(tester, byKey('node-popover'));
    await tester.tap(byKey('popover-primary'));
    await waitFor(tester, byKey('lesson-cta'));
    await playLesson(tester);
    expect(find.textContaining('+3'), findsOneWidget); // 3 pages, first completion
    await continueFromCompletion(tester);

    // Back on the Journey with the popover reopened
    await waitFor(tester, byKey('node-popover'));

    // Finish the remaining 4 lessons of node 1 via CONTINUE
    for (var i = 0; i < 4; i++) {
      await tester.tap(byKey('popover-primary'));
      await waitFor(tester, byKey('lesson-cta'));
      await playLesson(tester);
      await continueFromCompletion(tester);
      await waitFor(tester, byKey('node-popover'));
    }
    await tester.tap(byKey('popover-close'));
    await tester.pumpAndSettle();

    // Node 2 is now available: graded lesson, first option is wrong for the first question → feedback card
    await tester.ensureVisible(nodeTitled('Day 2'));
    await tester.tap(nodeTitled('Day 2'));
    await waitFor(tester, byKey('node-popover'));
    await tester.tap(byKey('popover-primary'));
    await waitFor(tester, byKey('lesson-cta'));
    final sawFeedback = await playLesson(tester);
    expect(sawFeedback, isTrue, reason: 'a graded question answered wrong shows the feedback card');
    await continueFromCompletion(tester);

    // Back to Home: the health total increased
    await waitFor(tester, byKey('node-popover'));
    await tester.tap(byKey('popover-close'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await waitFor(tester, byKey('home-health-points'));
    await tester.pump(const Duration(seconds: 1));
    expect(healthPoints(tester), greaterThan(initialPoints));
  });
}
