import '../../domain/models/gear_requests.dart';
import '../../domain/models/models.dart';

abstract class LensRepository {
  Future<List<Lens>> lenses({String? preferMount});
  Future<Lens> lens(String id);

  /// Creates a record. With [id] (a client id kept by the draft), the create is
  /// create-only: if the id is already taken the server answers
  /// `412 already_exists` and changes nothing, so a retry never duplicates.
  Future<Lens> create(LensEdit lens, {String? id});
}
