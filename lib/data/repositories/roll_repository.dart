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

  /// Adds rolls to stock. The same [idempotencyKey] sent again gets the rolls
  /// the first request added instead of adding more, so a draft keeps one key
  /// across retries and restarts.
  Future<List<RollSummary>> addRolls(NewRolls rolls, {String? idempotencyKey});
  Future<ExpiryView> expiry();
  Future<RollDetail> roll(String id);

  /// Replaces the roll. With [version], only if the roll is still at that
  /// version: a newer change gets a `412 roll_changed` and nothing is written.
  Future<RollDetail> update(String id, RollEdit edit, {int? version});
  Future<void> delete(String id);
  Future<RollDetail> load(String id, LoadRollRequest request);
  Future<void> setLenses(String id, List<String> lensIds);
  Future<RollDetail> finish(String id, DateTime date);

  /// One frame of a roll. Frames are numbered by the photographer and exist
  /// once they have notes or scans, so an unknown number is a 404.
  Future<Frame> frame(String rollId, int n);

  /// Sets a frame's notes, creating the frame on first save. Needs no scans.
  /// With [baseNotes] (the notes the edit was based on, "" for none) the save
  /// is a compare-and-set: `409 frame_notes_conflict` if they changed since.
  Future<Frame> saveFrameNotes(
    String rollId,
    int n,
    String? notes, {
    String? baseNotes,
  });

  /// Sets only the roll's notes (its description), with the same
  /// compare-and-set as [saveFrameNotes] when [baseDescription] is given.
  Future<RollDetail> saveRollNotes(
    String id,
    String description, {
    String? baseDescription,
  });
}
