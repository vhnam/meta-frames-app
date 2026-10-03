import '../../domain/models/models.dart';

abstract class LensRepository {
  Future<List<Lens>> lenses({String? preferMount});
  Future<Lens> lens(String id);
  Future<Lens> create(Map<String, dynamic> body);
  Future<Lens> update(String id, Map<String, dynamic> body);
  Future<void> delete(String id);
  Future<Lens> setActive(String id, bool active);
}
