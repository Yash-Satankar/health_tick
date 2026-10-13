// Human-paced demo walkthrough for the screen recording (not a correctness test; see app_flow_test.dart).
//
// Driven by scripts/record-demo.ps1, which reacts to the `DEMO_MARKER:*` lines printed here:
//   START            → start the screen recorder
//   REALTIME         → npm run demo:set-node-count -- --level insider_l2 --count 5
//   REALTIME_REVERT  → … --count 3
//   STOP_API         → stop the API, wait 6 s, start it again
//   SHOT:<name>      → take a verification screenshot
//   DONE             → stop the recorder
//
// Run (profile build, real device, API on the laptop via adb reverse):
//   flutter drive --profile --driver=test_driver/integration_test.dart \
//     --target=integration_test/demo_walkthrough_test.dart -d <device> \
//     --dart-define=API_BASE_URL=http://localhost:3000
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:user_journey/app.dart';
import 'package:user_journey/di.dart';
import 'package:user_journey/features/app_config/presentation/app_config_cubit.dart';
import 'package:user_journey/features/journey/presentation/bloc/journey_cubit.dart';
import 'package:user_journey/features/journey/presentation/widgets/journey_node_view.dart';
import 'package:user_journey/features/lesson/presentation/widgets/question_view.dart';

const screenPause = Duration(milliseconds: 2500);
const tapPause = Duration(milliseconds: 700);

void marker(String name) {
  // ignore: avoid_print
  print('DEMO_MARKER:$name');
}

Finder byKey(String key) => find.byKey(ValueKey(key));

Finder nodeTitled(String title) =>
    find.byWidgetPredicate((w) => w is JourneyNodeView && w.node.title == title, description: 'node "$title"');

/// Real-time wait (the binding is fully live, so frames keep rendering while we wait).
Future<void> wait(WidgetTester tester, Duration d) async {
  await Future<void>.delayed(d);
  await tester.pump();
}

Future<void> waitFor(WidgetTester tester, Finder finder, {Duration timeout = const Duration(seconds: 20)}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await wait(tester, const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return;
  }
  throw TestFailure('Timed out waiting for $finder');
}

Future<bool> waitUntil(bool Function() condition, WidgetTester tester, Duration timeout) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    if (condition()) return true;
    await wait(tester, const Duration(milliseconds: 200));
  }
  return condition();
}

/// Short pause so viewers can see what is about to be tapped, then tap.
Future<void> tapSlow(WidgetTester tester, Finder finder, {Duration after = const Duration(milliseconds: 600)}) async {
  await waitFor(tester, finder);
  await wait(tester, tapPause);
  await tester.tap(finder.first);
  await wait(tester, after);
}

ScrollableState? scrollableIn(WidgetTester tester, Finder scrollView) {
  final scrollables = find.descendant(of: scrollView, matching: find.byType(Scrollable));
  if (scrollables.evaluate().isEmpty) return null;
  return tester.state<ScrollableState>(scrollables.first);
}

/// Animates a scroll view to [to] (clamped; `double.infinity` = bottom) slowly.
Future<void> smoothScroll(WidgetTester tester, Finder scrollView, double to, {Duration? duration}) async {
  final state = scrollableIn(tester, scrollView);
  if (state == null) return;
  final position = state.position;
  final target = to.clamp(position.minScrollExtent, position.maxScrollExtent);
  final distance = (target - position.pixels).abs();
  if (distance < 1) return;
  final d = duration ?? Duration(milliseconds: (distance * 2.2).clamp(600, 4000).round());
  final done = position.animateTo(target, duration: d, curve: Curves.easeInOut);
  await wait(tester, d + const Duration(milliseconds: 150));
  await done;
}

final journeyScroll = byKey('journey-scroll');
final lessonScroll = find.byWidgetPredicate(
  (w) =>
      w is SingleChildScrollView && w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('page-'),
  description: 'lesson page scroll view',
);

JourneyCubit get journeyCubit => sl<JourneyCubit>();

int insiderNodeCount() => journeyCubit.state.journeyOrNull?.statuses.last.levels.first.nodes.length ?? -1;

/// Reads the current lesson page: scroll to the bottom slowly, pause, press the CTA.
Future<void> readPageAndContinue(WidgetTester tester) async {
  await wait(tester, const Duration(milliseconds: 900));
  await smoothScroll(tester, lessonScroll, double.infinity);
  await wait(tester, const Duration(milliseconds: 900));
  await tapSlow(tester, byKey('lesson-cta'), after: const Duration(milliseconds: 900));
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // Render every frame (animations, scrolling) for the recording, not just pumped frames.
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('demo walkthrough', timeout: const Timeout(Duration(minutes: 15)), (tester) async {
    marker('START');
    configureDependencies();
    await tester.pumpWidget(const HealthTickApp());
    await wait(tester, const Duration(seconds: 3)); // recorder warm-up on the launch frame

    // 1. Home → Journey → fill animation → scroll to Insider and back.
    await waitFor(tester, byKey('home-health-points'));
    await wait(tester, screenPause);
    marker('SHOT:home');
    await tapSlow(tester, byKey('home-journey-link'));
    await waitFor(tester, nodeTitled('Day 1'));
    await wait(tester, const Duration(milliseconds: 3000)); // let the path fill finish
    marker('SHOT:journey');
    await smoothScroll(tester, journeyScroll, double.infinity, duration: const Duration(seconds: 5));
    await wait(tester, screenPause);
    marker('SHOT:journey_bottom');
    await smoothScroll(tester, journeyScroll, 0, duration: const Duration(seconds: 4));
    await wait(tester, const Duration(seconds: 1));

    // 2. Node 1 → popover → START → welcome lesson → completion → back with the popover → close.
    await tapSlow(tester, nodeTitled('Day 1'));
    await waitFor(tester, byKey('node-popover'));
    await wait(tester, screenPause);
    marker('SHOT:popover');
    await tapSlow(tester, byKey('popover-primary'), after: const Duration(milliseconds: 1500));
    await waitFor(tester, byKey('lesson-cta'));
    for (var page = 0; page < 3; page++) {
      if (page == 0) marker('SHOT:welcome');
      await readPageAndContinue(tester);
    }
    await waitFor(tester, byKey('completion-view'));
    await wait(tester, screenPause);
    marker('SHOT:completion_welcome');
    await tapSlow(tester, byKey('completion-continue'), after: const Duration(milliseconds: 1500));
    await waitFor(tester, byKey('node-popover'));
    await wait(tester, screenPause);
    await tapSlow(tester, byKey('popover-close'));

    // 3. Only node 1's other lessons are pending; finishing them unlocks Day 2. To keep the video focused, the
    //    remaining node-1 lessons are completed here quickly (CONTINUE → page → done).
    for (var i = 0; i < 4; i++) {
      await tapSlow(tester, nodeTitled('Day 1'), after: const Duration(milliseconds: 500));
      await waitFor(tester, byKey('popover-primary'));
      await tapSlow(tester, byKey('popover-primary'), after: const Duration(milliseconds: 1000));
      await waitFor(tester, byKey('lesson-cta'));
      while (byKey('completion-view').evaluate().isEmpty) {
        final options = find.descendant(of: find.byType(ChoiceOptions), matching: find.byType(InkWell));
        if (options.evaluate().isNotEmpty) {
          await tapSlow(tester, options.first, after: const Duration(milliseconds: 300));
        }
        await tapSlow(tester, byKey('lesson-cta'), after: const Duration(milliseconds: 900));
        if (byKey('feedback-card').evaluate().isNotEmpty) {
          await tapSlow(tester, byKey('lesson-cta'), after: const Duration(milliseconds: 900));
        }
      }
      await tapSlow(tester, byKey('completion-continue'), after: const Duration(milliseconds: 1200));
      await waitFor(tester, byKey('node-popover'));
      await tapSlow(tester, byKey('popover-close'), after: const Duration(milliseconds: 400));
    }
    // Watch the fill flow into node 2.
    await wait(tester, const Duration(milliseconds: 3000));
    marker('SHOT:fill_node2');

    await tapSlow(tester, nodeTitled('Day 2'));
    await waitFor(tester, byKey('node-popover'));
    await wait(tester, const Duration(milliseconds: 1500));
    await tapSlow(tester, byKey('popover-primary'), after: const Duration(milliseconds: 1500));
    await waitFor(tester, byKey('lesson-cta'));
    await readPageAndContinue(tester); // page 1 (intro)

    // Q1 answered WRONG → feedback card.
    await waitFor(tester, find.byType(ChoiceOptions));
    await wait(tester, const Duration(milliseconds: 1200));
    await tapSlow(tester, find.text('The total calories I eat in one day'));
    await tapSlow(tester, byKey('lesson-cta'), after: const Duration(milliseconds: 1000));
    await waitFor(tester, byKey('feedback-card'));
    await wait(tester, screenPause);
    marker('SHOT:feedback_wrong');
    await smoothScroll(tester, lessonScroll, double.infinity);
    await wait(tester, const Duration(milliseconds: 1500));
    await tapSlow(tester, byKey('lesson-cta'), after: const Duration(milliseconds: 1200)); // NEXT

    // Back until the exit sheet appears → "Let's Complete".
    for (var i = 0; i < 6 && byKey('exit-sheet').evaluate().isEmpty; i++) {
      await tapSlow(tester, byKey('lesson-back'), after: const Duration(milliseconds: 1100));
    }
    await waitFor(tester, byKey('exit-sheet'));
    await wait(tester, screenPause);
    marker('SHOT:exit_sheet');
    await tapSlow(tester, byKey('exit-cancel'), after: const Duration(milliseconds: 1000));

    // Continue through the lesson: answer the rest correctly, expand one accordion, finish.
    const answers = ['Raisins', 'D. Both A and B', 'Both of the above'];
    var expandedAccordion = false;
    for (var step = 0; step < 40 && byKey('completion-view').evaluate().isEmpty; step++) {
      await wait(tester, const Duration(milliseconds: 700));
      if (byKey('feedback-card').evaluate().isNotEmpty) {
        await wait(tester, const Duration(milliseconds: 1500));
        await readPageAndContinue(tester);
        continue;
      }
      final choice = find.byType(ChoiceOptions);
      if (choice.evaluate().isNotEmpty) {
        for (final label in answers) {
          final option = find.descendant(of: choice, matching: find.text(label));
          if (option.evaluate().isNotEmpty) {
            await tapSlow(tester, option);
            break;
          }
        }
        await tapSlow(tester, byKey('lesson-cta'), after: const Duration(milliseconds: 1000));
        continue;
      }
      final accordion = find.byWidgetPredicate(
        (w) => w is InkWell && w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('accordion-'),
      );
      if (!expandedAccordion && accordion.evaluate().isNotEmpty) {
        await smoothScroll(tester, lessonScroll, double.infinity);
        await tapSlow(tester, accordion, after: const Duration(milliseconds: 800));
        await smoothScroll(tester, lessonScroll, double.infinity);
        await wait(tester, screenPause);
        marker('SHOT:accordion');
        expandedAccordion = true;
      }
      await readPageAndContinue(tester);
    }
    await waitFor(tester, byKey('completion-view'));
    await wait(tester, const Duration(milliseconds: 3000)); // health points on the completion screen
    marker('SHOT:completion_points');
    await tapSlow(tester, byKey('completion-continue'), after: const Duration(milliseconds: 1500));
    await waitFor(tester, byKey('node-popover'));
    await tapSlow(tester, byKey('popover-close'));

    // 4. Real-time: the laptop changes the node count; the path updates without interaction.
    await smoothScroll(tester, journeyScroll, double.infinity, duration: const Duration(seconds: 4));
    await wait(tester, const Duration(seconds: 1));
    marker('REALTIME');
    final grew = await waitUntil(() => insiderNodeCount() == 5, tester, const Duration(seconds: 30));
    expect(grew, isTrue, reason: 'the journey should update in real time (5 Insider nodes)');
    await wait(tester, const Duration(milliseconds: 1500));
    await smoothScroll(tester, journeyScroll, double.infinity, duration: const Duration(seconds: 2));
    await wait(tester, screenPause);
    marker('SHOT:realtime_5');
    marker('REALTIME_REVERT');
    final reverted = await waitUntil(() => insiderNodeCount() == 3, tester, const Duration(seconds: 30));
    expect(reverted, isTrue, reason: 'the journey should revert in real time (3 Insider nodes)');
    await wait(tester, screenPause);
    marker('SHOT:realtime_3');
    await smoothScroll(tester, journeyScroll, 0, duration: const Duration(seconds: 4));

    // 5. Search "procrast" → results → back. Reload overlay.
    await tapSlow(tester, byKey('journey-search'));
    await waitFor(tester, byKey('search-field'));
    await wait(tester, const Duration(milliseconds: 1200));
    const query = 'procrast';
    // On a real device the test text input isn't registered (the real keyboard is), so tester.enterText
    // never reaches onChanged. Feed the text to the field's EditableText directly, one character at a time.
    final editable = tester.state<EditableTextState>(
      find.descendant(of: byKey('search-field'), matching: find.byType(EditableText)),
    );
    for (var i = 1; i <= query.length; i++) {
      editable.updateEditingValue(
        TextEditingValue(
          text: query.substring(0, i),
          selection: TextSelection.collapsed(offset: i),
        ),
      );
      await wait(tester, const Duration(milliseconds: 280));
    }
    await waitFor(tester, find.text('Procrastination for health'));
    await wait(tester, screenPause);
    marker('SHOT:search');
    await wait(tester, tapPause);
    await tester.pageBack();
    await wait(tester, const Duration(milliseconds: 1200));
    await tapSlow(tester, byKey('journey-reload'), after: Duration.zero);
    marker('SHOT:reload');
    await wait(tester, screenPause);

    // 6. Open an available lesson → ⋮ Save (toast) → ⋮ Send feedback → exit via the exit sheet.
    await tapSlow(tester, nodeTitled('Day 2'));
    await waitFor(tester, byKey('popover-primary'));
    await wait(tester, const Duration(milliseconds: 1200));
    await tapSlow(tester, byKey('popover-primary'), after: const Duration(milliseconds: 1500));
    await waitFor(tester, byKey('lesson-menu-button'));
    await tapSlow(tester, byKey('lesson-menu-button'));
    await waitFor(tester, byKey('menu-save'));
    await tapSlow(tester, byKey('menu-save'), after: const Duration(milliseconds: 300));
    await wait(tester, screenPause);
    marker('SHOT:saved_toast');
    await tester.tapAt(const Offset(200, 150)); // close the sheet
    await wait(tester, const Duration(milliseconds: 1200));
    await tapSlow(tester, byKey('lesson-menu-button'));
    await tapSlow(tester, byKey('menu-feedback'), after: const Duration(milliseconds: 1000));
    await waitFor(tester, byKey('feedback-dialog'));
    await wait(tester, const Duration(milliseconds: 1500));
    await tapSlow(tester, byKey('reason-too_text_heavy'));
    await wait(tester, const Duration(milliseconds: 800));
    marker('SHOT:feedback_dialog');
    await tapSlow(tester, byKey('feedback-submit'), after: const Duration(milliseconds: 500));
    await wait(tester, screenPause);
    marker('SHOT:feedback_sent');
    await tapSlow(tester, byKey('lesson-back'));
    await waitFor(tester, byKey('exit-sheet'));
    await wait(tester, const Duration(milliseconds: 1800));
    await tapSlow(tester, byKey('exit-confirm'), after: const Duration(milliseconds: 1500));
    if (byKey('popover-close').evaluate().isNotEmpty) await tapSlow(tester, byKey('popover-close'));

    // 7. API stopped → offline state → retry until the API is back → Journey again.
    final offlineText = sl<AppConfigCubit>().state.copy('error.network.message');
    marker('STOP_API');
    await wait(tester, const Duration(seconds: 2));
    await tapSlow(tester, byKey('journey-reload'), after: Duration.zero);
    await waitFor(tester, find.text(offlineText), timeout: const Duration(seconds: 15));
    await wait(tester, const Duration(milliseconds: 1500));
    marker('SHOT:offline');
    // The Journey keeps its data on a failed reload (SPEC §8.4) and shows the offline message; Reload is its retry.
    var recovered = false;
    final end = DateTime.now().add(const Duration(seconds: 20));
    while (!recovered && DateTime.now().isBefore(end)) {
      await wait(tester, const Duration(seconds: 4));
      final before = journeyCubit.state;
      final errorIdBefore = before is JourneyLoaded ? before.errorId : -1;
      await tester.tap(byKey('journey-reload'));
      await waitUntil(
        () {
          final s = journeyCubit.state;
          return s is JourneyLoaded && s.activity == JourneyActivity.idle;
        },
        tester,
        const Duration(seconds: 12),
      );
      final after = journeyCubit.state;
      recovered = after is JourneyLoaded && after.errorId == errorIdBefore;
    }
    expect(recovered, isTrue, reason: 'the Journey should load again once the API is back');
    await wait(tester, const Duration(seconds: 3));
    marker('SHOT:recovered');
    marker('DONE');
    await wait(tester, const Duration(seconds: 1));
  });
}
