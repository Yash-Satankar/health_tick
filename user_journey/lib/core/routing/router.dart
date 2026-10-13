import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../features/home/presentation/pages/home_page.dart';
import '../../features/journey/presentation/pages/journey_page.dart';
import '../../features/lesson/presentation/pages/lesson_player_page.dart';
import '../../features/search/presentation/pages/search_page.dart';

/// Routes (SPEC §8.3). `/lesson/:lessonId` pops a `LessonExit`.
class AppRoutes {
  const AppRoutes._();

  static const home = '/';
  static const journey = '/journey';
  static const search = '/journey/search';
  static String lesson(String lessonId) => '/lesson/$lessonId';
}

/// Observes route changes so the content sync service knows whether the Journey is visible.
final RouteObserver<ModalRoute<void>> appRouteObserver = RouteObserver<ModalRoute<void>>();

GoRouter buildRouter({String initialLocation = AppRoutes.home, List<NavigatorObserver> observers = const []}) =>
    GoRouter(
      initialLocation: initialLocation,
      observers: [appRouteObserver, ...observers],
      routes: [
        GoRoute(
          path: AppRoutes.home,
          builder: (context, state) => const HomePage(),
          routes: [
            GoRoute(
              path: 'journey',
              builder: (context, state) => const JourneyPage(),
              routes: [GoRoute(path: 'search', builder: (context, state) => const SearchPage())],
            ),
          ],
        ),
        GoRoute(
          path: '/lesson/:lessonId',
          builder: (context, state) => LessonPlayerPage(lessonId: state.pathParameters['lessonId']!),
        ),
      ],
    );
