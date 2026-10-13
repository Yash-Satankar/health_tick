import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:user_journey/core/error/app_exception.dart';
import 'package:user_journey/core/error/failure.dart';
import 'package:user_journey/features/journey/data/journey_dto.dart';
import 'package:user_journey/features/journey/domain/journey.dart';
import 'package:user_journey/features/journey/presentation/bloc/journey_cubit.dart';
import 'package:user_journey/features/journey/presentation/pages/journey_page.dart';
import 'package:user_journey/features/journey/presentation/widgets/path_painter.dart';
import 'package:user_journey/features/lesson/domain/lesson_exit.dart';

import '../helpers/fixtures.dart';
import '../helpers/harness.dart';

Finder nodeFinder(String id) => find.byKey(ValueKey('journey-node-$id'));
final popover = find.byKey(const ValueKey('node-popover'));

Future<MockJourneyRepository> pumpJourney(WidgetTester tester, Journey journey, {LessonRouteRecorder? lessons}) async {
  usePhoneScreen(tester);
  final repo = MockJourneyRepository();
  when(() => repo.getJourney(force: any(named: 'force'))).thenAnswer((_) async => journey);
  await pumpScreen(tester, const JourneyPage(), journeyCubit: JourneyCubit(repo), lessons: lessons);
  await tester.pumpAndSettle();
  return repo;
}

void main() {
  fillAnimationTests();

  group('Journey renders the dynamic path', () {
    for (final count in [1, 7, 25]) {
      testWidgets('$count Beginner nodes + checkpoint, 3 Insider nodes', (tester) async {
        final journey = testJourney(beginner: count, insider: 3);
        await pumpJourney(tester, journey);
        expect(tester.takeException(), isNull);
        expect(find.text('Your Journey'), findsOneWidget);
        expect(find.byKey(const ValueKey('journey-card-lv-1')), findsOneWidget);
        expect(find.byKey(const ValueKey('journey-card-lv-2')), findsOneWidget);
        for (final node in journey.nodes) {
          expect(nodeFinder(node.id), findsOneWidget, reason: node.id);
        }
        expect(find.text('Beginner'), findsOneWidget);
        expect(find.text('LEVEL-1'), findsOneWidget);
        expect(find.text('Status'), findsNWidgets(2));
      });
    }

    testWidgets('a completed node shows the green check', (tester) async {
      await pumpJourney(tester, testJourney(completed: 1));
      expect(find.byKey(const ValueKey('journey-node-check-b1')), findsOneWidget);
      expect(find.byKey(const ValueKey('journey-node-check-b2')), findsNothing);
    });
  });

  group('popover', () {
    testWidgets('tap an available node → popover with lessons and START; ⊗ and outside tap close it', (tester) async {
      await pumpJourney(tester, testJourney());
      expect(popover, findsNothing);
      await tester.tap(nodeFinder('b1'));
      await tester.pumpAndSettle();
      expect(popover, findsOneWidget);
      expect(find.text('Lesson 0 of b1'), findsOneWidget);
      expect(find.text('Lesson 1 of b1'), findsOneWidget);
      expect(find.text('START'), findsOneWidget);
      expect(find.byIcon(Icons.radio_button_unchecked_rounded), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('popover-close')));
      await tester.pumpAndSettle();
      expect(popover, findsNothing);

      await tester.tap(nodeFinder('b1'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(20, 120)); // outside the popover
      await tester.pumpAndSettle();
      expect(popover, findsNothing);
    });

    testWidgets('a completed node shows DO IT AGAIN and Completed On {d MMM yyyy}', (tester) async {
      await pumpJourney(tester, testJourney(completed: 1));
      await tester.tap(nodeFinder('b1'));
      await tester.pumpAndSettle();
      expect(find.text('DO IT AGAIN'), findsOneWidget);
      expect(find.textContaining('Completed On 12 Oct 2026'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsNWidgets(2));
    });

    testWidgets('START opens the first lesson; returning reopens the popover', (tester) async {
      final lessons = LessonRouteRecorder()
        ..exitToReturn = const LessonExit(reason: LessonExitReason.abandoned, nodeId: 'b1');
      await pumpJourney(tester, testJourney(), lessons: lessons);
      await tester.tap(nodeFinder('b1'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('popover-primary')));
      await tester.pumpAndSettle();
      expect(lessons.opened, ['b1-l0']);
      await tester.tap(find.byKey(const ValueKey('stub-lesson-exit')));
      await tester.pumpAndSettle();
      expect(popover, findsOneWidget);
    });

    testWidgets('a locked node shakes and shows the locked snackbar; no popover', (tester) async {
      await pumpJourney(tester, testJourney());
      await tester.tap(nodeFinder('b3'));
      await tester.pump();
      expect(find.text('Complete the previous step to unlock this one.'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(popover, findsNothing);
    });

    testWidgets('an available checkpoint opens its lesson directly (no popover)', (tester) async {
      final lessons = LessonRouteRecorder();
      await pumpJourney(tester, testJourney(beginner: 2, completed: 2), lessons: lessons);
      await tester.tap(nodeFinder('cp'));
      await tester.pumpAndSettle();
      expect(lessons.opened, ['cp-l0']);
    });
  });

  group('states', () {
    testWidgets('first load shows a full-screen spinner', (tester) async {
      usePhoneScreen(tester);
      final repo = MockJourneyRepository();
      final completer = Completer<Journey>();
      when(() => repo.getJourney(force: any(named: 'force'))).thenAnswer((_) => completer.future);
      await pumpScreen(tester, const JourneyPage(), journeyCubit: JourneyCubit(repo));
      await tester.pump();
      expect(find.byKey(const ValueKey('journey-loading')), findsOneWidget);
      completer.complete(testJourney());
      await tester.pumpAndSettle();
      expect(nodeFinder('b1'), findsOneWidget);
    });

    testWidgets('first-load failure shows ErrorView; Retry recovers', (tester) async {
      usePhoneScreen(tester);
      final repo = MockJourneyRepository();
      var calls = 0;
      when(() => repo.getJourney(force: any(named: 'force'))).thenAnswer((_) async {
        if (calls++ == 0) throw const AppException(ServerFailure('INTERNAL_ERROR', statusCode: 500));
        return testJourney();
      });
      await pumpScreen(tester, const JourneyPage(), journeyCubit: JourneyCubit(repo));
      await tester.pumpAndSettle();
      expect(find.text('Something went wrong on our side. (api)'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('error-retry')));
      await tester.pumpAndSettle();
      expect(nodeFinder('b1'), findsOneWidget);
    });

    testWidgets('empty journey (no statuses) shows a message with retry', (tester) async {
      await pumpJourney(tester, parseJourney({'contentVersion': 1, 'statuses': []}));
      expect(find.byKey(const ValueKey('journey-empty')), findsOneWidget);
      expect(find.byKey(const ValueKey('error-retry')), findsOneWidget);
    });

    testWidgets('Reload shows the overlay with title and subtitle, then the new data', (tester) async {
      usePhoneScreen(tester);
      final repo = MockJourneyRepository();
      final completer = Completer<Journey>();
      var calls = 0;
      when(() => repo.getJourney(force: any(named: 'force'))).thenAnswer((_) {
        if (calls++ == 0) return Future.value(testJourney());
        return completer.future;
      });
      await pumpScreen(tester, const JourneyPage(), journeyCubit: JourneyCubit(repo));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('journey-reload')));
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('Reloading Your Journey'), findsOneWidget);
      expect(find.text('Please wait while we reload your journey'), findsOneWidget);
      final overlay = tester.widget<AnimatedOpacity>(
        find.ancestor(of: find.byKey(const ValueKey('journey-reload-overlay')), matching: find.byType(AnimatedOpacity)),
      );
      expect(overlay.opacity, 1);
      completer.complete(testJourney(completed: 1));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('journey-node-check-b1')), findsOneWidget);
    });

    testWidgets('a failed silent refresh keeps the path and shows a snackbar', (tester) async {
      usePhoneScreen(tester);
      final repo = MockJourneyRepository();
      when(() => repo.getJourney(force: true)).thenAnswer((_) async => testJourney());
      when(() => repo.getJourney()).thenThrow(const AppException(NetworkFailure()));
      final cubit = JourneyCubit(repo);
      await pumpScreen(tester, const JourneyPage(), journeyCubit: cubit);
      await tester.pumpAndSettle();
      await cubit.silentRefresh();
      await tester.pump();
      expect(find.text('Check your internet connection and try again. (api)'), findsOneWidget);
      expect(nodeFinder('b1'), findsOneWidget);
    });
  });
}

JourneyPathPainter pathPainter(WidgetTester tester) =>
    tester.widget<CustomPaint>(find.byKey(const ValueKey('journey-path-paint'))).painter! as JourneyPathPainter;

void fillAnimationTests() {
  group('fill animation (SPEC 9.4)', () {
    Future<(MockJourneyRepository, JourneyCubit)> pumpLoaded(WidgetTester tester, Journey journey) async {
      usePhoneScreen(tester);
      final repo = MockJourneyRepository();
      when(() => repo.getJourney(force: any(named: 'force'))).thenAnswer((_) async => journey);
      final cubit = JourneyCubit(repo);
      await pumpScreen(tester, const JourneyPage(), journeyCubit: cubit);
      await tester.pump(); // journey loaded → first frame with the path
      return (repo, cubit);
    }

    testWidgets('after load: nothing filled at t=0, partial mid-way, complete after settling', (tester) async {
      await pumpLoaded(tester, testJourney(completed: 2));
      final painter = pathPainter(tester);
      final target = painter.layout.filledLength;
      expect(target, greaterThan(0));
      expect(painter.animatedLength, 0);
      await tester.pump(); // post-frame callback starts the animation
      await tester.pump(const Duration(milliseconds: 150));
      final mid = pathPainter(tester).animatedLength;
      expect(mid, greaterThan(0));
      expect(mid, lessThan(target));
      await tester.pumpAndSettle();
      expect(pathPainter(tester).animatedLength, closeTo(target, 0.001));
    });

    testWidgets('a silent refresh that unlocks more animates only the new part; a shrink jumps', (tester) async {
      final (repo, cubit) = await pumpLoaded(tester, testJourney(completed: 1));
      await tester.pumpAndSettle();
      final before = pathPainter(tester).animatedLength;

      when(() => repo.getJourney()).thenAnswer((_) async => testJourney(completed: 3));
      await cubit.silentRefresh();
      await tester.pump(); // new layout
      await tester.pump(); // animation starts from the previous length
      expect(pathPainter(tester).animatedLength, closeTo(before, 0.001));
      await tester.pump(const Duration(milliseconds: 100));
      expect(pathPainter(tester).animatedLength, greaterThan(before));
      await tester.pumpAndSettle();
      final grown = pathPainter(tester).layout.filledLength;
      expect(pathPainter(tester).animatedLength, closeTo(grown, 0.001));

      when(() => repo.getJourney()).thenAnswer((_) async => testJourney(completed: 0)); // progress reset
      await cubit.silentRefresh();
      await tester.pump();
      await tester.pump();
      final shrunk = pathPainter(tester).layout.filledLength;
      expect(shrunk, lessThan(grown));
      expect(pathPainter(tester).animatedLength, closeTo(shrunk, 0.001)); // no animation
    });

    testWidgets('with reduced motion the final state is drawn immediately', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
        disableAnimations: true,
      );
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      await pumpLoaded(tester, testJourney(completed: 2));
      await tester.pump();
      final painter = pathPainter(tester);
      expect(painter.animatedLength, closeTo(painter.layout.filledLength, 0.001));
    });
  });
}
