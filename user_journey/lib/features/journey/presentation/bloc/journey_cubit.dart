import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/journey.dart';

part 'journey_cubit.freezed.dart';

/// What the loaded journey is doing in the background.
enum JourneyActivity { idle, reloading, refreshing }

@freezed
sealed class JourneyState with _$JourneyState {
  const JourneyState._();

  /// First load: full-screen spinner.
  const factory JourneyState.loading() = JourneyLoading;

  /// First-load failure (no data yet): ErrorView with retry.
  const factory JourneyState.failure(Failure failure) = JourneyFailure;

  /// Data on screen. `reloading` shows the overlay; `refreshing` is silent. A `transientError`
  /// keeps the data and shows a snackbar (identified by `errorId` so it is shown once).
  const factory JourneyState.loaded({
    required Journey journey,
    String? selectedNodeId,
    @Default(JourneyActivity.idle) JourneyActivity activity,
    Failure? transientError,
    @Default(0) int errorId,
    @Default(0) int scrollToTopId,
    String? pulseNodeId,
  }) = JourneyLoaded;

  Journey? get journeyOrNull => switch (this) {
    JourneyLoaded(:final journey) => journey,
    _ => null,
  };
}

/// SPEC §8.4: load, reload (overlay), silentRefresh (content change / resume), selectNode, clearSelection.
class JourneyCubit extends Cubit<JourneyState> {
  JourneyCubit(this._repository) : super(const JourneyState.loading());

  final JourneyRepository _repository;
  int _errorSeq = 0;

  Future<void> load() async {
    emit(const JourneyState.loading());
    try {
      emit(JourneyState.loaded(journey: await _repository.getJourney(force: true)));
    } catch (error) {
      emit(JourneyState.failure(mapError(error)));
    }
  }

  /// Reload button: overlay over the current path; on success scroll to the top.
  Future<void> reload() async {
    final current = state;
    if (current is! JourneyLoaded) return load();
    if (current.activity == JourneyActivity.reloading) return;
    emit(current.copyWith(activity: JourneyActivity.reloading, transientError: null));
    try {
      final journey = await _repository.getJourney(force: true);
      emit(
        current.copyWith(
          journey: journey,
          activity: JourneyActivity.idle,
          selectedNodeId: null,
          transientError: null,
          scrollToTopId: current.scrollToTopId + 1,
        ),
      );
    } catch (error) {
      emit(_withError(current, mapError(error)));
    }
  }

  /// Silent: swaps the data without any loader (SSE content change, app resume, route return).
  Future<void> silentRefresh() async {
    final current = state;
    if (current is! JourneyLoaded) {
      if (current is JourneyFailure) return load();
      return; // a first load is in progress
    }
    emit(current.copyWith(activity: JourneyActivity.refreshing));
    try {
      final journey = await _repository.getJourney();
      final latest = state is JourneyLoaded ? state as JourneyLoaded : current;
      final keepSelection = latest.selectedNodeId != null && journey.nodeById(latest.selectedNodeId!) != null;
      emit(
        latest.copyWith(
          journey: journey,
          activity: JourneyActivity.idle,
          selectedNodeId: keepSelection ? latest.selectedNodeId : null,
        ),
      );
    } catch (error) {
      final latest = state is JourneyLoaded ? state as JourneyLoaded : current;
      emit(_withError(latest, mapError(error)));
    }
  }

  void selectNode(String nodeId) {
    final current = state;
    if (current is JourneyLoaded && current.journey.nodeById(nodeId) != null) {
      emit(current.copyWith(selectedNodeId: nodeId));
    }
  }

  void clearSelection() {
    final current = state;
    if (current is JourneyLoaded && current.selectedNodeId != null) emit(current.copyWith(selectedNodeId: null));
  }

  /// Briefly pulse a node that was just unlocked (SPEC §9.6 completion).
  void pulse(String? nodeId) {
    final current = state;
    if (current is JourneyLoaded) emit(current.copyWith(pulseNodeId: nodeId));
  }

  JourneyLoaded _withError(JourneyLoaded current, Failure failure) =>
      current.copyWith(activity: JourneyActivity.idle, transientError: failure, errorId: ++_errorSeq);
}
