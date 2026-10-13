import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/search.dart';

part 'search_bloc.freezed.dart';

sealed class SearchEvent {
  const SearchEvent();
}

final class SearchQueryChanged extends SearchEvent {
  const SearchQueryChanged(this.query);
  final String query;
}

final class SearchSortChanged extends SearchEvent {
  const SearchSortChanged(this.sort);
  final SearchSort sort;
}

final class SearchRetryPressed extends SearchEvent {
  const SearchRetryPressed();
}

final class _SearchRequested extends SearchEvent {
  const _SearchRequested(this.requestId);
  final int requestId;
}

enum SearchStatus { idle, loading, success, failure }

@freezed
sealed class SearchState with _$SearchState {
  const SearchState._();

  const factory SearchState({
    @Default('') String query,
    @Default(SearchSort.relevance) SearchSort sort,
    @Default(SearchStatus.idle) SearchStatus status,
    @Default(<SearchResult>[]) List<SearchResult> results,
    Failure? failure,
  }) = _SearchState;

  /// No results for a valid query.
  bool get isEmptyResult => status == SearchStatus.success && results.isEmpty;
}

/// SPEC §8.4: 300 ms debounce, only the latest request is processed, < 2 characters → empty state,
/// switchable sort.
class SearchBloc extends Bloc<SearchEvent, SearchState> {
  SearchBloc(this._repository, {this.debounce = const Duration(milliseconds: 300)}) : super(const SearchState()) {
    on<SearchQueryChanged>(_onQueryChanged);
    on<SearchSortChanged>(_onSortChanged);
    on<SearchRetryPressed>((event, emit) => _schedule(emit, immediate: true));
    on<_SearchRequested>(_onRequested);
  }

  static const minQueryLength = 2;

  final SearchRepository _repository;
  final Duration debounce;
  Timer? _timer;
  int _latestRequestId = 0;

  void _onQueryChanged(SearchQueryChanged event, Emitter<SearchState> emit) {
    final query = event.query.trim();
    if (query == state.query && state.status != SearchStatus.idle) return;
    emit(state.copyWith(query: query));
    _schedule(emit);
  }

  void _onSortChanged(SearchSortChanged event, Emitter<SearchState> emit) {
    if (event.sort == state.sort) return;
    emit(state.copyWith(sort: event.sort));
    _schedule(emit, immediate: true);
  }

  void _schedule(Emitter<SearchState> emit, {bool immediate = false}) {
    _timer?.cancel();
    final requestId = ++_latestRequestId; // invalidates any in-flight request
    if (state.query.length < minQueryLength) {
      emit(state.copyWith(status: SearchStatus.idle, results: const [], failure: null));
      return;
    }
    emit(state.copyWith(status: SearchStatus.loading, failure: null));
    if (immediate) {
      add(_SearchRequested(requestId));
    } else {
      _timer = Timer(debounce, () => add(_SearchRequested(requestId)));
    }
  }

  Future<void> _onRequested(_SearchRequested event, Emitter<SearchState> emit) async {
    if (event.requestId != _latestRequestId) return;
    final query = state.query;
    final sort = state.sort;
    try {
      final results = await _repository.search(query, sort);
      if (event.requestId != _latestRequestId) return; // a newer request superseded this one
      emit(state.copyWith(status: SearchStatus.success, results: results, failure: null));
    } catch (error) {
      if (event.requestId != _latestRequestId) return;
      emit(state.copyWith(status: SearchStatus.failure, failure: mapError(error)));
    }
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}
