import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:user_journey/core/error/app_exception.dart';
import 'package:user_journey/core/error/failure.dart';
import 'package:user_journey/features/home/data/home_dto.dart';
import 'package:user_journey/features/home/domain/home.dart';
import 'package:user_journey/features/home/presentation/bloc/home_cubit.dart';
import 'package:user_journey/features/home/presentation/pages/home_page.dart';
import 'package:user_journey/features/journey/presentation/bloc/journey_cubit.dart';

import '../helpers/fixtures.dart';
import '../helpers/harness.dart';

const _task = TodayTask(lessonId: 'l1', lessonTitle: 'Welcome to Health Tick!', nodeId: 'b1', statusTitle: 'Beginner');
const _home = HomeData(displayName: 'yash', healthPointsTotal: 37, streakDays: 2, todayTask: _task);

void main() {
  test('HomeDto parses the contract, including a null todayTask', () {
    final data = HomeDto.fromJson({
      'user': {'displayName': 'Yash', 'healthPointsTotal': 3, 'streakDays': 1},
      'todayTask': null,
    }).toDomain();
    expect(data.todayTask, isNull);
    expect(() => HomeDto.fromJson({'user': {}}), throwsA(anything));
  });

  group('HomeCubit', () {
    late MockHomeRepository repo;
    setUp(() => repo = MockHomeRepository());

    blocTest<HomeCubit, HomeState>(
      'loading → ready',
      setUp: () => when(repo.getHome).thenAnswer((_) async => _home),
      build: () => HomeCubit(repo),
      act: (c) => c.load(),
      expect: () => [const HomeState.loading(), const HomeState.ready(_home)],
    );

    blocTest<HomeCubit, HomeState>(
      'loading → failure',
      setUp: () => when(repo.getHome).thenThrow(const AppException(NetworkFailure())),
      build: () => HomeCubit(repo),
      act: (c) => c.load(),
      expect: () => [const HomeState.loading(), const HomeState.failure(NetworkFailure())],
    );

    blocTest<HomeCubit, HomeState>(
      'refresh failure keeps the data',
      setUp: () => when(repo.getHome).thenThrow(const AppException(TimeoutFailure())),
      build: () => HomeCubit(repo),
      seed: () => const HomeState.ready(_home),
      act: (c) => c.refresh(),
      expect: () => [const HomeState.ready(_home, refreshError: TimeoutFailure(), errorId: 1)],
    );
  });

  group('HomePage', () {
    testWidgets('shows avatar initial, streak, points, title, link and task', (tester) async {
      usePhoneScreen(tester);
      final repo = MockHomeRepository();
      when(repo.getHome).thenAnswer((_) async => _home);
      await pumpScreen(tester, const HomePage(), homeCubit: HomeCubit(repo));
      await tester.pumpAndSettle();
      expect(find.text('Y'), findsOneWidget);
      expect(find.descendant(of: find.byKey(const ValueKey('home-streak')), matching: find.text('2')), findsOneWidget);
      expect(
        find.descendant(of: find.byKey(const ValueKey('home-health-points')), matching: find.text('37')),
        findsOneWidget,
      );
      expect(find.text("today's task"), findsOneWidget);
      expect(find.text('JOURNEY'), findsOneWidget);
      expect(find.text('Welcome to Health Tick!'), findsOneWidget);
    });

    testWidgets('tapping the task opens the lesson', (tester) async {
      usePhoneScreen(tester);
      final repo = MockHomeRepository();
      when(repo.getHome).thenAnswer((_) async => _home);
      final journeyRepo = MockJourneyRepository();
      when(() => journeyRepo.getJourney(force: any(named: 'force'))).thenAnswer((_) async => testJourney());
      final lessons = LessonRouteRecorder();
      await pumpScreen(
        tester,
        const HomePage(),
        homeCubit: HomeCubit(repo),
        journeyCubit: JourneyCubit(journeyRepo),
        lessons: lessons,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('home-task-card')));
      await tester.pumpAndSettle();
      expect(lessons.opened, ['l1']);
    });

    testWidgets('all-done text when there is no task', (tester) async {
      usePhoneScreen(tester);
      final repo = MockHomeRepository();
      when(repo.getHome).thenAnswer(
        (_) async => const HomeData(displayName: 'Yash', healthPointsTotal: 99, streakDays: 0, todayTask: null),
      );
      await pumpScreen(tester, const HomePage(), homeCubit: HomeCubit(repo));
      await tester.pumpAndSettle();
      expect(find.text('You have completed your journey!'), findsOneWidget);
    });

    testWidgets('loading skeleton, then error with retry that recovers', (tester) async {
      usePhoneScreen(tester);
      final repo = MockHomeRepository();
      var calls = 0;
      when(repo.getHome).thenAnswer((_) async {
        calls++;
        if (calls == 1) throw const AppException(NetworkFailure());
        return _home;
      });
      await pumpScreen(tester, const HomePage(), homeCubit: HomeCubit(repo));
      expect(find.byKey(const ValueKey('home-skeleton')), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text("You're offline (api)"), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('error-retry')));
      await tester.pumpAndSettle();
      expect(find.text('Welcome to Health Tick!'), findsOneWidget);
    });
  });
}
