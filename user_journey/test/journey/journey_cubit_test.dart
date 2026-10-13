import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:user_journey/core/error/app_exception.dart';
import 'package:user_journey/core/error/failure.dart';
import 'package:user_journey/features/journey/presentation/bloc/journey_cubit.dart';

import '../helpers/fixtures.dart';
import '../helpers/harness.dart';

void main() {
  late MockJourneyRepository repo;
  final v1 = testJourney(version: 1);
  final v2 = testJourney(version: 2, completed: 1);

  setUp(() => repo = MockJourneyRepository());

  blocTest<JourneyCubit, JourneyState>(
    'load: loading → loaded',
    setUp: () => when(() => repo.getJourney(force: true)).thenAnswer((_) async => v1),
    build: () => JourneyCubit(repo),
    act: (c) => c.load(),
    expect: () => [const JourneyState.loading(), JourneyState.loaded(journey: v1)],
  );

  blocTest<JourneyCubit, JourneyState>(
    'load: loading → failure (no data yet)',
    setUp: () => when(() => repo.getJourney(force: true)).thenThrow(const AppException(NetworkFailure())),
    build: () => JourneyCubit(repo),
    act: (c) => c.load(),
    expect: () => [const JourneyState.loading(), const JourneyState.failure(NetworkFailure())],
  );

  blocTest<JourneyCubit, JourneyState>(
    'reload: overlay (reloading) → new data, selection cleared, scroll to top',
    setUp: () => when(() => repo.getJourney(force: true)).thenAnswer((_) async => v2),
    build: () => JourneyCubit(repo),
    seed: () => JourneyState.loaded(journey: v1, selectedNodeId: 'b1'),
    act: (c) => c.reload(),
    expect: () => [
      JourneyState.loaded(journey: v1, selectedNodeId: 'b1', activity: JourneyActivity.reloading),
      JourneyState.loaded(journey: v2, scrollToTopId: 1),
    ],
  );

  blocTest<JourneyCubit, JourneyState>(
    'reload failure keeps the data and reports a transient error',
    setUp: () => when(() => repo.getJourney(force: true)).thenThrow(const AppException(TimeoutFailure())),
    build: () => JourneyCubit(repo),
    seed: () => JourneyState.loaded(journey: v1),
    act: (c) => c.reload(),
    expect: () => [
      JourneyState.loaded(journey: v1, activity: JourneyActivity.reloading),
      JourneyState.loaded(journey: v1, transientError: const TimeoutFailure(), errorId: 1),
    ],
  );

  blocTest<JourneyCubit, JourneyState>(
    'silentRefresh swaps the data without a loader and keeps a still-valid selection',
    setUp: () => when(() => repo.getJourney()).thenAnswer((_) async => v2),
    build: () => JourneyCubit(repo),
    seed: () => JourneyState.loaded(journey: v1, selectedNodeId: 'b1'),
    act: (c) => c.silentRefresh(),
    expect: () => [
      JourneyState.loaded(journey: v1, selectedNodeId: 'b1', activity: JourneyActivity.refreshing),
      JourneyState.loaded(journey: v2, selectedNodeId: 'b1'),
    ],
  );

  blocTest<JourneyCubit, JourneyState>(
    'silentRefresh clears the selection when the node disappeared',
    setUp: () => when(() => repo.getJourney()).thenAnswer((_) async => testJourney(beginner: 1, insider: 0)),
    build: () => JourneyCubit(repo),
    seed: () => JourneyState.loaded(journey: v1, selectedNodeId: 'b5'),
    act: (c) => c.silentRefresh(),
    verify: (c) => expect((c.state as JourneyLoaded).selectedNodeId, isNull),
  );

  blocTest<JourneyCubit, JourneyState>(
    'silent refresh failure keeps the data',
    setUp: () => when(() => repo.getJourney()).thenThrow(const AppException(NetworkFailure())),
    build: () => JourneyCubit(repo),
    seed: () => JourneyState.loaded(journey: v1),
    act: (c) => c.silentRefresh(),
    expect: () => [
      JourneyState.loaded(journey: v1, activity: JourneyActivity.refreshing),
      JourneyState.loaded(journey: v1, transientError: const NetworkFailure(), errorId: 1),
    ],
  );

  blocTest<JourneyCubit, JourneyState>(
    'silentRefresh after a first-load failure performs a full load',
    setUp: () => when(() => repo.getJourney(force: true)).thenAnswer((_) async => v1),
    build: () => JourneyCubit(repo),
    seed: () => const JourneyState.failure(NetworkFailure()),
    act: (c) => c.silentRefresh(),
    expect: () => [const JourneyState.loading(), JourneyState.loaded(journey: v1)],
  );

  blocTest<JourneyCubit, JourneyState>(
    'selectNode / clearSelection / pulse',
    build: () => JourneyCubit(repo),
    seed: () => JourneyState.loaded(journey: v1),
    act: (c) => c
      ..selectNode('b1')
      ..selectNode('does-not-exist')
      ..clearSelection()
      ..pulse('b2'),
    expect: () => [
      JourneyState.loaded(journey: v1, selectedNodeId: 'b1'),
      JourneyState.loaded(journey: v1),
      JourneyState.loaded(journey: v1, pulseNodeId: 'b2'),
    ],
  );
}
