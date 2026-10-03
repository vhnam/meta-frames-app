import '../../domain/models/models.dart';
import '../services/api_client.dart';
import 'lab_repository.dart';

class LabRepositoryRemote implements LabRepository {
  LabRepositoryRemote(this._api);
  final ApiClient _api;

  @override
  Future<List<Lab>> labs() async =>
      decodeList(await _api.send('GET', '/labs'), Lab.fromJson);
  @override
  Future<Lab> create(Map<String, dynamic> body) async =>
      Lab.fromJson(await _api.send('POST', '/labs', body: body));
  @override
  Future<Lab> update(String id, Map<String, dynamic> body) async =>
      Lab.fromJson(await _api.send('PUT', '/labs/$id', body: body));
  @override
  Future<void> delete(String id) => _api.send('DELETE', '/labs/$id');
}
