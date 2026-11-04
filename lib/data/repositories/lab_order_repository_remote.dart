import '../../domain/models/lab_order_requests.dart';
import '../../domain/models/models.dart';
import '../services/api_client.dart';
import 'lab_order_repository.dart';

class LabOrderRepositoryRemote implements LabOrderRepository {
  LabOrderRepositoryRemote(this._api);
  final ApiClient _api;

  @override
  Future<List<LabOrder>> orders() async =>
      decodeList(await _api.send('GET', '/lab-orders'), LabOrder.fromJson);
  @override
  Future<LabOrder> order(String id) async =>
      LabOrder.fromJson(await _api.send('GET', '/lab-orders/$id'));
  @override
  Future<LabOrder> save(String id, LabOrderEdit order) async =>
      LabOrder.fromJson(
        await _api.send('PUT', '/lab-orders/$id', body: order.toJson()),
      );
  @override
  Future<void> delete(String id) => _api.send('DELETE', '/lab-orders/$id');
  @override
  Future<List<LabOrderJob>> linkableJobs(String id) async => decodeList(
    await _api.send('GET', '/lab-orders/$id/linkable-jobs'),
    LabOrderJob.fromJson,
  );
}
