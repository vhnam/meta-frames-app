import '../../domain/models/lab_order_requests.dart';
import '../../domain/models/models.dart';

abstract class LabOrderRepository {
  Future<List<LabOrder>> orders();
  Future<LabOrder> order(String id);

  /// Creates the order at this id, or replaces it and its lines.
  Future<LabOrder> save(String id, LabOrderEdit order);

  /// Refused while the order has rolls.
  Future<void> delete(String id);

  /// Jobs at the order's lab that are on no order, or only on this one.
  Future<List<LabOrderJob>> linkableJobs(String id);
}
