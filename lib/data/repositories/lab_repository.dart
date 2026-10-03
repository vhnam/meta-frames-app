import '../../domain/models/models.dart';

abstract class LabRepository {
  Future<List<Lab>> labs();
  Future<Lab> create(Map<String, dynamic> body);
  Future<Lab> update(String id, Map<String, dynamic> body);
  Future<void> delete(String id);
}
