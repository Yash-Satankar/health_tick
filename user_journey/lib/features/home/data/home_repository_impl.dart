import '../../../core/network/api_client.dart';
import '../domain/home.dart';
import 'home_dto.dart';

class HomeRemoteDataSource {
  HomeRemoteDataSource(this._api);

  final ApiClient _api;

  Future<HomeDto> fetch() => _api.get('/api/v1/home', (data) => HomeDto.fromJson(asJsonMap(data)));
}

class HomeRepositoryImpl implements HomeRepository {
  HomeRepositoryImpl(this._remote);

  final HomeRemoteDataSource _remote;

  @override
  Future<HomeData> getHome() async => (await _remote.fetch()).toDomain();
}
