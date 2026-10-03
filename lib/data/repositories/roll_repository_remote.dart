import '../../domain/models/models.dart';
import '../../domain/models/roll_requests.dart';
import '../../domain/utils.dart';
import '../services/api_client.dart';
import 'roll_repository.dart';

class RollRepositoryRemote implements RollRepository {
  RollRepositoryRemote(this._api);
  final ApiClient _api;

  @override
  Future<List<RollSummary>> rolls({
    String? status,
    String? filmStockId,
    String? cameraId,
    String? lensId,
    int? format,
    DateTime? startedFrom,
    DateTime? startedTo,
  }) async => decodeList(
    await _api.send(
      'GET',
      '/rolls',
      query: {
        'status': status,
        'filmStockId': filmStockId,
        'cameraId': cameraId,
        'lensId': lensId,
        'format': format?.toString(),
        'startedFrom': startedFrom == null ? null : ymd(startedFrom),
        'startedTo': startedTo == null ? null : ymd(startedTo),
      },
    ),
    RollSummary.fromJson,
  );
  @override
  Future<List<RollSummary>> addRolls(NewRolls rolls) async => decodeList(
    await _api.send(
      'POST',
      '/rolls/bulk',
      body: rolls.toJson(),
      extraHeaders: {'Idempotency-Key': newId()},
    ),
    RollSummary.fromJson,
  );
  @override
  Future<ExpiryView> expiry() async =>
      ExpiryView.fromJson(await _api.send('GET', '/expiry'));
  @override
  Future<RollDetail> roll(String id) async =>
      RollDetail.fromJson(await _api.send('GET', '/rolls/$id'));
  @override
  Future<RollDetail> update(String id, RollEdit edit) async =>
      RollDetail.fromJson(
        await _api.send('PUT', '/rolls/$id', body: edit.toJson()),
      );
  @override
  Future<void> delete(String id) => _api.send('DELETE', '/rolls/$id');
  @override
  Future<RollDetail> load(String id, LoadRollRequest request) async =>
      RollDetail.fromJson(
        await _api.send('PUT', '/rolls/$id/load', body: request.toJson()),
      );
  @override
  Future<void> setLenses(String id, List<String> lensIds) =>
      _api.send('PUT', '/rolls/$id/lenses', body: {'lensIds': lensIds});
  @override
  Future<RollDetail> finish(String id, DateTime date) async =>
      RollDetail.fromJson(
        await _api.send('PUT', '/rolls/$id/finish', body: {'date': ymd(date)}),
      );
  @override
  Future<List<SearchResult>> searchByFocalLength(int mm) async => decodeList(
    await _api.send('GET', '/search/rolls', query: {'focalLength': '$mm'}),
    SearchResult.fromJson,
  );
}
