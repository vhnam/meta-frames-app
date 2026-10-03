import '../../domain/models/gear_requests.dart';
import '../../domain/models/models.dart';
import '../services/api_client.dart';
import 'lens_repository.dart';

class LensRepositoryRemote implements LensRepository {
  LensRepositoryRemote(this._api);
  final ApiClient _api;

  @override
  Future<List<Lens>> lenses({String? preferMount}) async => decodeList(
    await _api.send('GET', '/lenses', query: {'preferMount': preferMount}),
    Lens.fromJson,
  );
  @override
  Future<Lens> lens(String id) async =>
      Lens.fromJson(await _api.send('GET', '/lenses/$id'));
  @override
  Future<Lens> create(LensEdit lens) async =>
      Lens.fromJson(await _api.send('POST', '/lenses', body: lens.toJson()));
  @override
  Future<Lens> update(String id, LensEdit lens) async =>
      Lens.fromJson(await _api.send('PUT', '/lenses/$id', body: lens.toJson()));
  @override
  Future<void> delete(String id) => _api.send('DELETE', '/lenses/$id');
  @override
  Future<Lens> setActive(String id, bool active) async => Lens.fromJson(
    await _api.send('PUT', '/lenses/$id/active', body: {'isActive': active}),
  );
}
