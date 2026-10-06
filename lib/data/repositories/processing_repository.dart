import '../../domain/models/lab_requests.dart';
import '../../domain/models/models.dart';

abstract class ProcessingRepository {
  Future<List<Processing>> forRoll(String rollId);
  Future<Processing> send(String rollId, NewProcessing job);
  Future<Processing> processing(String id);
  Future<Processing> scansReceived(String id, DateTime date);
  Future<Processing> negativesReturned(String id, DateTime date);
  Future<List<NegativesAtLabItem>> negativesAtLab();
}
