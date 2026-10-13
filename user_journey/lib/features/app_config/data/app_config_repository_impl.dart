import '../../../core/network/api_client.dart';
import '../domain/bootstrap.dart';
import 'bootstrap_dto.dart';

class AppConfigRemoteDataSource {
  AppConfigRemoteDataSource(this._api);

  final ApiClient _api;

  Future<BootstrapDto> fetchBootstrap() =>
      _api.get('/api/v1/bootstrap', (data) => BootstrapDto.fromJson(asJsonMap(data)));
}

class AppConfigRepositoryImpl implements AppConfigRepository {
  AppConfigRepositoryImpl(this._remote);

  final AppConfigRemoteDataSource _remote;

  @override
  Future<Bootstrap> bootstrap() async => (await _remote.fetchBootstrap()).toDomain();
}
