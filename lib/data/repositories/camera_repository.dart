import '../../domain/models/gear_requests.dart';
import '../../domain/models/models.dart';

abstract class CameraRepository {
  Future<List<Camera>> cameras();
  Future<Camera> camera(String id);

  /// Creates a record. With [id] (a client id kept by the draft), the create is
  /// create-only: if the id is already taken the server answers
  /// `412 already_exists` and changes nothing, so a retry never duplicates.
  Future<Camera> create(CameraEdit camera, {String? id});
  Future<List<Lens>> lenses(String id);
  Future<void> setLenses(String id, List<String> lensIds);
}
