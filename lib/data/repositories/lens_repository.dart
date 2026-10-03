import '../../domain/models/gear_requests.dart';
import '../../domain/models/models.dart';

abstract class LensRepository {
  Future<List<Lens>> lenses({String? preferMount});
  Future<Lens> lens(String id);
  Future<Lens> create(LensEdit lens);
  Future<Lens> update(String id, LensEdit lens);
  Future<void> delete(String id);
  Future<Lens> setActive(String id, bool active);
}
