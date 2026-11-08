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
  Future<Lens> create(LensEdit lens, {String? id}) async =>
      Lens.fromJson(await _api.create('/lenses', lens.toJson(), id: id));
}
