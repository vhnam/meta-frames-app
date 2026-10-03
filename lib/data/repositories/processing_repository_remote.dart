import '../../domain/models/lab_requests.dart';
import '../../domain/models/models.dart';
import '../../domain/utils.dart';
import '../services/api_client.dart';
import 'processing_repository.dart';

class ProcessingRepositoryRemote implements ProcessingRepository {
  ProcessingRepositoryRemote(this._api);
  final ApiClient _api;

  @override
  Future<List<Processing>> forRoll(String rollId) async => decodeList(
    await _api.send('GET', '/rolls/$rollId/processing'),
    Processing.fromJson,
  );
  @override
  Future<Processing> send(String rollId, NewProcessing job) async =>
      Processing.fromJson(
        await _api.send(
          'PUT',
          '/rolls/$rollId/processing/${newId()}',
          body: job.toJson(),
        ),
      );
  @override
  Future<Processing> processing(String id) async =>
      Processing.fromJson(await _api.send('GET', '/processing/$id'));
  @override
  Future<Processing> scansReceived(String id, DateTime date) async =>
      Processing.fromJson(
        await _api.send(
          'PUT',
          '/processing/$id/scans-received',
          body: {'date': ymd(date)},
        ),
      );
  @override
  Future<Processing> negativesReturned(String id, DateTime date) async =>
      Processing.fromJson(
        await _api.send(
          'PUT',
          '/processing/$id/negatives-returned',
          body: {'date': ymd(date)},
        ),
      );
  @override
  Future<List<NegativesAtLabItem>> negativesAtLab() async => decodeList(
    await _api.send('GET', '/negatives-at-lab'),
    NegativesAtLabItem.fromJson,
  );
}
