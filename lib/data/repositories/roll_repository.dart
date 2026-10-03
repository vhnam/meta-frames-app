import '../../domain/models/models.dart';

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
  Future<List<RollSummary>> addRolls(Map<String, dynamic> body);
  Future<ExpiryView> expiry();
  Future<RollDetail> roll(String id);
  Future<RollDetail> update(String id, Map<String, dynamic> body);
  Future<void> delete(String id);
  Future<RollDetail> load(String id, Map<String, dynamic> body);
  Future<void> setLenses(String id, List<String> lensIds);
  Future<RollDetail> finish(String id, DateTime date);
  Future<List<SearchResult>> searchByFocalLength(int mm);
}
