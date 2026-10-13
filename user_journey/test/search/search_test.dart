import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:user_journey/core/error/app_exception.dart';
import 'package:user_journey/core/error/failure.dart';
import 'package:user_journey/features/journey/domain/journey.dart';
import 'package:user_journey/features/journey/presentation/bloc/journey_cubit.dart';
import 'package:user_journey/features/search/domain/search.dart';
import 'package:user_journey/features/search/presentation/bloc/search_bloc.dart';
import 'package:user_journey/features/search/presentation/pages/search_page.dart';

import '../helpers/fixtures.dart';
import '../helpers/harness.dart';

class MockSearchRepository extends Mock implements SearchRepository {}

SearchResult result(String id, {ProgressState state = ProgressState.available}) => SearchResult(
  lessonId: id,
  title: 'Procrastination for health $id',
  nodeId: 'b5',
  nodeTitle: 'Day 5',
  levelLabel: 'LEVEL-1',
  statusTitle: 'Beginner',
  state: state,
);

void main() {
  setUpAll(() => registerFallbackValue(SearchSort.relevance));

  group('SearchBloc (SPEC 8.4)', () {
    late MockSearchRepository repo;
    setUp(() => repo = MockSearchRepository());

    blocTest<SearchBloc, SearchState>(
      'debounces typing: only one request for the final query',
      setUp: () => when(() => repo.search(any(), any())).thenAnswer((_) async => [result('1')]),
      build: () => SearchBloc(repo, debounce: const Duration(milliseconds: 300)),
      act: (bloc) async {
        bloc.add(const SearchQueryChanged('pr'));
        await Future<void>.delayed(const Duration(milliseconds: 100));
        bloc.add(const SearchQueryChanged('pro'));
        await Future<void>.delayed(const Duration(milliseconds: 100));
        bloc.add(const SearchQueryChanged('procrast'));
      },
      wait: const Duration(milliseconds: 500),
      verify: (bloc) {
        verify(() => repo.search('procrast', SearchSort.relevance)).called(1);
        verifyNoMoreInteractions(repo);
        expect(bloc.state.status, SearchStatus.success);
        expect(bloc.state.results, hasLength(1));
      },
    );

    test('a stale (slower) response is ignored', () async {
      final slow = Completer<List<SearchResult>>();
      when(() => repo.search('first', any())).thenAnswer((_) => slow.future);
      when(() => repo.search('second', any())).thenAnswer((_) async => [result('new')]);
      final bloc = SearchBloc(repo, debounce: Duration.zero);
      bloc.add(const SearchQueryChanged('first'));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      bloc.add(const SearchQueryChanged('second'));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      slow.complete([result('old')]);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(bloc.state.results.single.lessonId, 'new');
      await bloc.close();
    });

    blocTest<SearchBloc, SearchState>(
      'queries shorter than 2 characters show the empty state without a request',
      build: () => SearchBloc(repo, debounce: Duration.zero),
      act: (bloc) => bloc.add(const SearchQueryChanged(' p ')),
      wait: const Duration(milliseconds: 20),
      expect: () => [const SearchState(query: 'p')],
      verify: (_) => verifyNever(() => repo.search(any(), any())),
    );

    blocTest<SearchBloc, SearchState>(
      'switching the sort re-runs the query immediately',
      setUp: () => when(() => repo.search(any(), any())).thenAnswer((_) async => [result('1')]),
      build: () => SearchBloc(repo, debounce: Duration.zero),
      seed: () => SearchState(query: 'keystone', status: SearchStatus.success, results: [result('0')]),
      act: (bloc) => bloc.add(const SearchSortChanged(SearchSort.journey)),
      wait: const Duration(milliseconds: 20),
      verify: (bloc) {
        verify(() => repo.search('keystone', SearchSort.journey)).called(1);
        expect(bloc.state.sort, SearchSort.journey);
      },
    );

    blocTest<SearchBloc, SearchState>(
      'failure, then Retry succeeds',
      setUp: () {
        var calls = 0;
        when(() => repo.search(any(), any())).thenAnswer((_) async {
          if (calls++ == 0) throw const AppException(TimeoutFailure());
          return [result('1')];
        });
      },
      build: () => SearchBloc(repo, debounce: Duration.zero),
      act: (bloc) async {
        bloc.add(const SearchQueryChanged('procrast'));
        await Future<void>.delayed(const Duration(milliseconds: 20));
        bloc.add(const SearchRetryPressed());
      },
      wait: const Duration(milliseconds: 50),
      expect: () => [
        const SearchState(query: 'procrast'),
        const SearchState(query: 'procrast', status: SearchStatus.loading),
        const SearchState(query: 'procrast', status: SearchStatus.failure, failure: TimeoutFailure()),
        const SearchState(query: 'procrast', status: SearchStatus.loading),
        SearchState(query: 'procrast', status: SearchStatus.success, results: [result('1')]),
      ],
    );
  });

  group('SearchPage states', () {
    Future<MockSearchRepository> pumpSearch(WidgetTester tester) async {
      usePhoneScreen(tester);
      final repo = MockSearchRepository();
      final journeyRepo = MockJourneyRepository();
      when(() => journeyRepo.getJourney(force: any(named: 'force'))).thenAnswer((_) async => testJourney());
      await pumpScreen(
        tester,
        BlocProvider(
          create: (_) => SearchBloc(repo, debounce: Duration.zero),
          child: const SearchView(),
        ),
        journeyCubit: JourneyCubit(journeyRepo),
      );
      await tester.pump();
      return repo;
    }

    testWidgets('empty prompt, then results with path subtitle and lock icon', (tester) async {
      final repo = await pumpSearch(tester);
      expect(find.text('Start typing to search lessons'), findsOneWidget);
      when(
        () => repo.search(any(), any()),
      ).thenAnswer((_) async => [result('1'), result('2', state: ProgressState.locked)]);
      await tester.enterText(find.byKey(const ValueKey('search-field')), 'procrast');
      await tester.pumpAndSettle();
      expect(find.text('Procrastination for health 1'), findsOneWidget);
      expect(find.text('Beginner · LEVEL-1 · Day 5'), findsNWidgets(2));
      expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
    });

    testWidgets('tapping a locked result shows the locked snackbar', (tester) async {
      final repo = await pumpSearch(tester);
      when(() => repo.search(any(), any())).thenAnswer((_) async => [result('2', state: ProgressState.locked)]);
      await tester.enterText(find.byKey(const ValueKey('search-field')), 'procrast');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('search-result-2')));
      await tester.pump();
      expect(find.text('Complete the previous step to unlock this one.'), findsOneWidget);
    });

    testWidgets('loading and no-results states', (tester) async {
      final repo = await pumpSearch(tester);
      final completer = Completer<List<SearchResult>>();
      when(() => repo.search(any(), any())).thenAnswer((_) => completer.future);
      await tester.enterText(find.byKey(const ValueKey('search-field')), 'zzz');
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const ValueKey('search-loading')), findsOneWidget);
      completer.complete([]);
      await tester.pumpAndSettle();
      expect(find.text('No lessons found'), findsOneWidget);
    });

    testWidgets('error with retry', (tester) async {
      final repo = await pumpSearch(tester);
      when(() => repo.search(any(), any())).thenThrow(const AppException(NetworkFailure()));
      await tester.enterText(find.byKey(const ValueKey('search-field')), 'procrast');
      await tester.pumpAndSettle();
      expect(find.text("You're offline (api)"), findsOneWidget);
      when(() => repo.search(any(), any())).thenAnswer((_) async => [result('1')]);
      await tester.tap(find.byKey(const ValueKey('error-retry')));
      await tester.pumpAndSettle();
      expect(find.text('Procrastination for health 1'), findsOneWidget);
    });

    testWidgets('sort menu lists both sorts from copy', (tester) async {
      await pumpSearch(tester);
      await tester.tap(find.byKey(const ValueKey('search-sort')));
      await tester.pumpAndSettle();
      expect(find.text('Journey order'), findsOneWidget);
      expect(find.text('Most relevant'), findsWidgets);
    });
  });
}
