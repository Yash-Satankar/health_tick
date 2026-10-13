import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';

import 'core/config/env.dart';
import 'core/network/api_client.dart';
import 'core/network/sse_client.dart';
import 'features/app_config/data/app_config_repository_impl.dart';
import 'features/app_config/domain/bootstrap.dart';
import 'features/app_config/presentation/app_config_cubit.dart';
import 'features/home/data/home_repository_impl.dart';
import 'features/home/domain/home.dart';
import 'features/home/presentation/bloc/home_cubit.dart';
import 'features/journey/data/journey_repository_impl.dart';
import 'features/journey/domain/journey.dart';
import 'features/journey/presentation/bloc/journey_cubit.dart';
import 'features/lesson/data/lesson_repository_impl.dart';
import 'features/lesson/domain/lesson.dart';
import 'features/search/data/search_repository_impl.dart';
import 'features/search/domain/search.dart';
import 'features/search/presentation/bloc/search_bloc.dart';

final GetIt sl = GetIt.instance;

/// Registers the object graph. Tests call [resetDependencies] and register fakes instead.
void configureDependencies({String baseUrl = Env.apiBaseUrl, String userId = Env.demoUserId}) {
  final dio = createDio(baseUrl: baseUrl, userId: userId);
  sl
    ..registerSingleton<Dio>(dio)
    ..registerSingleton<ApiClient>(ApiClient(dio))
    ..registerLazySingleton<SseClient>(() => SseClient(sl<Dio>()))
    // repositories
    ..registerLazySingleton<AppConfigRepository>(
      () => AppConfigRepositoryImpl(AppConfigRemoteDataSource(sl<ApiClient>())),
    )
    ..registerLazySingleton<HomeRepository>(() => HomeRepositoryImpl(HomeRemoteDataSource(sl<ApiClient>())))
    ..registerLazySingleton<JourneyRepository>(() => JourneyRepositoryImpl(JourneyRemoteDataSource(sl<ApiClient>())))
    ..registerLazySingleton<LessonRepository>(() => LessonRepositoryImpl(LessonRemoteDataSource(sl<ApiClient>())))
    ..registerLazySingleton<SearchRepository>(() => SearchRepositoryImpl(SearchRemoteDataSource(sl<ApiClient>())))
    // app-wide state (the content sync service refreshes these)
    ..registerLazySingleton<AppConfigCubit>(() => AppConfigCubit(sl<AppConfigRepository>()))
    ..registerLazySingleton<HomeCubit>(() => HomeCubit(sl<HomeRepository>()))
    ..registerLazySingleton<JourneyCubit>(() => JourneyCubit(sl<JourneyRepository>()))
    // per-screen
    ..registerFactory<SearchBloc>(() => SearchBloc(sl<SearchRepository>()));
}

Future<void> resetDependencies() => sl.reset();
