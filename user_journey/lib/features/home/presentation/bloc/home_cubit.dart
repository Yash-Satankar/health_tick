import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/home.dart';

part 'home_cubit.freezed.dart';

@freezed
sealed class HomeState with _$HomeState {
  const factory HomeState.loading() = HomeLoading;
  const factory HomeState.ready(HomeData data, {Failure? refreshError, @Default(0) int errorId}) = HomeReady;
  const factory HomeState.failure(Failure failure) = HomeFailure;
}

/// loading → ready / failure (SPEC §8.4). [refresh] runs silently and keeps data on failure.
class HomeCubit extends Cubit<HomeState> {
  HomeCubit(this._repository) : super(const HomeState.loading());

  final HomeRepository _repository;
  int _errorSeq = 0;

  Future<void> load() async {
    emit(const HomeState.loading());
    await _fetch();
  }

  /// On route return, pull-to-refresh and content change.
  Future<void> refresh() async {
    if (state is! HomeReady) return load();
    await _fetch();
  }

  Future<void> _fetch() async {
    try {
      emit(HomeState.ready(await _repository.getHome()));
    } catch (error) {
      final failure = mapError(error);
      final current = state;
      if (current is HomeReady) {
        emit(current.copyWith(refreshError: failure, errorId: ++_errorSeq));
      } else {
        emit(HomeState.failure(failure));
      }
    }
  }
}
