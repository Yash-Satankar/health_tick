import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:user_journey/core/models/asset_ref.dart';
import 'package:user_journey/core/theme/theme.dart';
import 'package:user_journey/core/widgets/remote_image.dart';
import 'package:user_journey/features/app_config/domain/bootstrap.dart';
import 'package:user_journey/features/app_config/presentation/app_config_cubit.dart';
import 'package:user_journey/features/home/domain/home.dart';
import 'package:user_journey/features/home/presentation/bloc/home_cubit.dart';
import 'package:user_journey/features/journey/domain/journey.dart';
import 'package:user_journey/features/journey/presentation/bloc/journey_cubit.dart';
import 'package:user_journey/features/lesson/domain/lesson_exit.dart';

import 'fixtures.dart';

class MockJourneyRepository extends Mock implements JourneyRepository {}

class MockHomeRepository extends Mock implements HomeRepository {}

class MockAppConfigRepository extends Mock implements AppConfigRepository {}

/// Network images are replaced by a coloured box in widget tests (plugins are unavailable).
void useFakeImages() {
  RemoteImage.debugBuilder = (context, AssetRef asset, fit) =>
      ColoredBox(key: ValueKey('img-${asset.url}'), color: const Color(0xFF444444));
}

/// Phone-sized surface (360 × 780 dp).
void usePhoneScreen(WidgetTester tester, {Size size = const Size(360, 780)}) {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

/// Last lesson route opened in a test, and what it pops.
class LessonRouteRecorder {
  final List<String> opened = [];
  LessonExit? exitToReturn;
}

/// Pumps [home] at '/' inside the real theme and bloc providers. `/journey`, `/journey/search` and
/// `/lesson/:id` are stub pages; the lesson stub pops [LessonRouteRecorder.exitToReturn] on tap.
Future<void> pumpScreen(
  WidgetTester tester,
  Widget home, {
  JourneyCubit? journeyCubit,
  HomeCubit? homeCubit,
  Bootstrap? bootstrap,
  LessonRouteRecorder? lessons,
  String initialLocation = '/',
  Map<String, Widget> extraRoutes = const {},
}) async {
  useFakeImages();
  final configRepo = MockAppConfigRepository();
  final resolvedBootstrap = bootstrap ?? testBootstrap();
  when(configRepo.bootstrap).thenAnswer((_) async => resolvedBootstrap);
  final config = AppConfigCubit(configRepo)..emit(AppConfigState.ready(resolvedBootstrap));
  final journey = journeyCubit ?? JourneyCubit(MockJourneyRepository());
  final homeCub = homeCubit ?? HomeCubit(MockHomeRepository());
  final recorder = lessons ?? LessonRouteRecorder();

  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(path: '/', builder: (_, _) => home),
      for (final entry in extraRoutes.entries) GoRoute(path: entry.key, builder: (_, _) => entry.value),
      GoRoute(
        path: '/journey/search',
        builder: (_, _) => const Scaffold(key: ValueKey('stub-search')),
      ),
      GoRoute(
        path: '/lesson/:id',
        builder: (context, state) {
          recorder.opened.add(state.pathParameters['id']!);
          return Scaffold(
            key: const ValueKey('stub-lesson'),
            body: GestureDetector(
              key: const ValueKey('stub-lesson-exit'),
              behavior: HitTestBehavior.opaque,
              onTap: () => context.pop(recorder.exitToReturn),
              child: const SizedBox.expand(),
            ),
          );
        },
      ),
    ],
  );

  await tester.pumpWidget(
    MultiBlocProvider(
      providers: [
        BlocProvider<AppConfigCubit>.value(value: config),
        BlocProvider<JourneyCubit>.value(value: journey),
        BlocProvider<HomeCubit>.value(value: homeCub),
      ],
      child: MaterialApp.router(theme: buildAppTheme(), routerConfig: router),
    ),
  );
}
