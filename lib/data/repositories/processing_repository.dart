import '../../domain/models/lab_requests.dart';
import '../../domain/models/models.dart';

abstract class ProcessingRepository {
  Future<List<Processing>> forRoll(String rollId);
  Future<Processing> send(String rollId, NewProcessing job);
  Future<Processing> processing(String id);

  /// Refused while the job has imported scans.
  Future<void> delete(String id);
  Future<Processing> scansReceived(String id, DateTime date);
  Future<Processing> negativesReturned(String id, DateTime date);
  Future<List<NegativesAtLabItem>> negativesAtLab();

  /// Replaces the order lines a job is billed on; none takes it off its order.
  Future<Processing> setOrderLines(String id, List<String> lineIds);
}
