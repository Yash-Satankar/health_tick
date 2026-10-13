import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';

import 'core/config/env.dart';
import 'core/network/api_client.dart';
import 'core/network/sse_client.dart';
import 'features/app_config/data/app_config_repository_impl.dart';
import 'features/app_config/domain/bootstrap.dart';
import 'features/app_config/presentation/app_config_cubit.dart';

final GetIt sl = GetIt.instance;

/// Registers the object graph. Tests call [resetDependencies] and register fakes instead.
void configureDependencies({String baseUrl = Env.apiBaseUrl, String userId = Env.demoUserId}) {
  final dio = createDio(baseUrl: baseUrl, userId: userId);
  sl
    ..registerSingleton<Dio>(dio)
    ..registerSingleton<ApiClient>(ApiClient(dio))
    ..registerLazySingleton<SseClient>(() => SseClient(sl<Dio>()))
    ..registerLazySingleton<AppConfigRepository>(
      () => AppConfigRepositoryImpl(AppConfigRemoteDataSource(sl<ApiClient>())),
    )
    ..registerLazySingleton<AppConfigCubit>(() => AppConfigCubit(sl<AppConfigRepository>()));
}

Future<void> resetDependencies() => sl.reset();
