import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/copy/app_copy.dart';
import '../../../core/error/app_exception.dart';
import '../../../core/error/failure.dart';
import '../../../core/network/api_client.dart';
import '../domain/bootstrap.dart';

part 'app_config_cubit.freezed.dart';

@freezed
sealed class AppConfigState with _$AppConfigState {
  const AppConfigState._();

  const factory AppConfigState.loading() = AppConfigLoading;
  const factory AppConfigState.ready(Bootstrap bootstrap) = AppConfigReady;
  const factory AppConfigState.failure(Failure failure) = AppConfigFailure;

  /// Copy if loaded; otherwise empty (texts fall back to FallbackMessages).
  AppCopy get copy => switch (this) {
    AppConfigReady(:final bootstrap) => bootstrap.copy,
    _ => AppCopy.empty,
  };

  Bootstrap? get bootstrapOrNull => switch (this) {
    AppConfigReady(:final bootstrap) => bootstrap,
    _ => null,
  };
}

/// loading → ready(bootstrap) / failure (SPEC §8.4). `reload` keeps the current data while refreshing.
class AppConfigCubit extends Cubit<AppConfigState> {
  AppConfigCubit(this._repository) : super(const AppConfigState.loading());

  final AppConfigRepository _repository;

  Future<void> load() async {
    if (state is! AppConfigReady) emit(const AppConfigState.loading());
    try {
      emit(AppConfigState.ready(await _repository.bootstrap()));
    } on AppException catch (e) {
      if (state is! AppConfigReady) emit(AppConfigState.failure(e.failure));
    } catch (e) {
      if (state is! AppConfigReady) emit(AppConfigState.failure(mapError(e)));
    }
  }
}
