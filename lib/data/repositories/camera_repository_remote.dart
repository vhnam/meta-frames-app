import '../../domain/models/gear_requests.dart';
import '../../domain/models/models.dart';
import '../services/api_client.dart';
import 'camera_repository.dart';

class CameraRepositoryRemote implements CameraRepository {
  CameraRepositoryRemote(this._api);
  final ApiClient _api;

  @override
  Future<List<Camera>> cameras() async =>
      decodeList(await _api.send('GET', '/cameras'), Camera.fromJson);
  @override
  Future<Camera> camera(String id) async =>
      Camera.fromJson(await _api.send('GET', '/cameras/$id'));
  @override
  Future<Camera> create(CameraEdit camera) async => Camera.fromJson(
    await _api.send('POST', '/cameras', body: camera.toJson()),
  );
  @override
  Future<Camera> update(String id, CameraEdit camera) async => Camera.fromJson(
    await _api.send('PUT', '/cameras/$id', body: camera.toJson()),
  );
  @override
  Future<void> delete(String id) => _api.send('DELETE', '/cameras/$id');
  @override
  Future<Camera> setActive(String id, bool active) async => Camera.fromJson(
    await _api.send('PUT', '/cameras/$id/active', body: {'isActive': active}),
  );
  @override
  Future<List<Lens>> lenses(String id) async =>
      decodeList(await _api.send('GET', '/cameras/$id/lenses'), Lens.fromJson);
  @override
  Future<void> setLenses(String id, List<String> lensIds) =>
      _api.send('PUT', '/cameras/$id/lenses', body: {'lensIds': lensIds});
}
