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
  Future<Lab> lab(String id) async =>
      Lab.fromJson(await _api.send('GET', '/labs/$id'));
  @override
  Future<Lab> create(LabEdit lab, {String? id}) async =>
      Lab.fromJson(await _api.create('/labs', lab.toJson(), id: id));
}
