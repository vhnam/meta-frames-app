import '../../domain/models/lab_requests.dart';
import '../../domain/models/models.dart';

abstract class LabRepository {
  Future<List<Lab>> labs();
  Future<Lab> create(LabEdit lab);
  Future<Lab> update(String id, LabEdit lab);
  Future<void> delete(String id);
}
