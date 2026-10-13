import '../../../core/network/api_client.dart';
import '../domain/journey.dart';
import 'journey_dto.dart';

class JourneyRemoteDataSource {
  JourneyRemoteDataSource(this._api);

  final ApiClient _api;

  Future<({Journey? value, String? etag})> fetch({String? etag}) =>
      _api.getConditional('/api/v1/journey', parseJourney, etag: etag);
}

/// Keeps the last journey and its ETag so unchanged journeys cost a 304 (SPEC §6.2).
class JourneyRepositoryImpl implements JourneyRepository {
  JourneyRepositoryImpl(this._remote);

  final JourneyRemoteDataSource _remote;
  Journey? _cached;
  String? _etag;

  @override
  Future<Journey> getJourney({bool force = false}) async {
    final cached = _cached;
    final result = await _remote.fetch(etag: force || cached == null ? null : _etag);
    final journey = result.value ?? cached;
    if (journey == null) throw const FormatException('304 without a cached journey');
    _cached = journey;
    _etag = result.etag;
    return journey;
  }
}
