import '../../domain/models/gear_requests.dart';
import '../../domain/models/models.dart';

abstract class CameraRepository {
  Future<List<Camera>> cameras();
  Future<Camera> camera(String id);
  Future<Camera> create(CameraEdit camera);
  Future<Camera> update(String id, CameraEdit camera);
  Future<void> delete(String id);
  Future<Camera> setActive(String id, bool active);
  Future<List<Lens>> lenses(String id);
  Future<void> setLenses(String id, List<String> lensIds);
}
