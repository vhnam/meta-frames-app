import '../../domain/models/models.dart';
import '../../domain/models/roll_requests.dart';

abstract class RollRepository {
  Future<List<RollSummary>> rolls({
    String? status,
    String? filmStockId,
    String? cameraId,
    String? lensId,
    int? format,
    DateTime? startedFrom,
    DateTime? startedTo,
  });
  Future<List<RollSummary>> addRolls(NewRolls rolls);
  Future<ExpiryView> expiry();
  Future<RollDetail> roll(String id);
  Future<RollDetail> update(String id, RollEdit edit);
  Future<void> delete(String id);
  Future<RollDetail> load(String id, LoadRollRequest request);
  Future<void> setLenses(String id, List<String> lensIds);
  Future<RollDetail> finish(String id, DateTime date);
}
