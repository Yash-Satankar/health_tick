import 'package:json_annotation/json_annotation.dart';

import '../../../core/network/api_client.dart';
import '../../journey/domain/journey.dart';
import '../domain/search.dart';

part 'search_repository_impl.g.dart';

@JsonSerializable(createToJson: false, checked: true)
class SearchResultDto {
  const SearchResultDto({
    required this.lessonId,
    required this.title,
    required this.nodeId,
    required this.nodeTitle,
    required this.levelLabel,
    required this.statusTitle,
    required this.state,
  });

  factory SearchResultDto.fromJson(Map<String, dynamic> json) => _$SearchResultDtoFromJson(json);

  final String lessonId;
  final String title;
  final String nodeId;
  final String nodeTitle;
  final String levelLabel;
  final String statusTitle;
  final String state;

  SearchResult toDomain() => SearchResult(
    lessonId: lessonId,
    title: title,
    nodeId: nodeId,
    nodeTitle: nodeTitle,
    levelLabel: levelLabel,
    statusTitle: statusTitle,
    state: ProgressState.parse(state),
  );
}

class SearchRemoteDataSource {
  SearchRemoteDataSource(this._api);

  final ApiClient _api;

  Future<List<SearchResultDto>> search(String query, SearchSort sort) => _api.get('/api/v1/lessons/search', (data) {
    final results = asJsonMap(data)['results'];
    if (results is! List) throw const FormatException('results must be a list');
    return results.map((r) => SearchResultDto.fromJson(asJsonMap(r))).toList();
  }, query: {'q': query, 'sort': sort.name});
}

class SearchRepositoryImpl implements SearchRepository {
  SearchRepositoryImpl(this._remote);

  final SearchRemoteDataSource _remote;

  @override
  Future<List<SearchResult>> search(String query, SearchSort sort) async =>
      (await _remote.search(query, sort)).map((r) => r.toDomain()).toList(growable: false);
}
