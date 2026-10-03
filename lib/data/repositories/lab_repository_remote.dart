import '../../domain/models/lab_requests.dart';
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
  Future<Lab> create(LabEdit lab) async =>
      Lab.fromJson(await _api.send('POST', '/labs', body: lab.toJson()));
  @override
  Future<Lab> update(String id, LabEdit lab) async =>
      Lab.fromJson(await _api.send('PUT', '/labs/$id', body: lab.toJson()));
  @override
  Future<void> delete(String id) => _api.send('DELETE', '/labs/$id');
}
