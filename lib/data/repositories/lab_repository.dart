import '../../domain/models/lab_requests.dart';
import '../../domain/models/models.dart';

abstract class LabRepository {
  Future<List<Lab>> labs();
  Future<Lab> lab(String id);

  /// Creates a record. With [id] (a client id kept by the draft), the create is
  /// create-only: if the id is already taken the server answers
  /// `412 already_exists` and changes nothing, so a retry never duplicates.
  Future<Lab> create(LabEdit lab, {String? id});
}
