import 'package:flutter/foundation.dart';

import '../../journey/domain/journey.dart';

enum SearchSort {
  relevance,
  journey;

  String get copyKey => 'search.sort.$name';
}

@immutable
class SearchResult {
  const SearchResult({
    required this.lessonId,
    required this.title,
    required this.nodeId,
    required this.nodeTitle,
    required this.levelLabel,
    required this.statusTitle,
    required this.state,
  });

  final String lessonId;
  final String title;
  final String nodeId;
  final String nodeTitle;
  final String levelLabel;
  final String statusTitle;
  final ProgressState state;

  bool get isLocked => state == ProgressState.locked;

  /// "status · level · node" subtitle (SPEC §9.5).
  String get path => '$statusTitle · $levelLabel · $nodeTitle';

  @override
  bool operator ==(Object other) => other is SearchResult && other.lessonId == lessonId && other.state == state;
  @override
  int get hashCode => Object.hash(lessonId, state);
}

abstract interface class SearchRepository {
  Future<List<SearchResult>> search(String query, SearchSort sort);
}
