import '../../domain/models/models.dart';
import '../../domain/models/scanner_requests.dart';

abstract class ScannerRepository {
  Future<List<ScannerDevice>> scanners();
  Future<ScannerDevice> scanner(String id);

  /// The scan options of each scanner kind.
  Future<List<ScannerKindOptions>> kinds();
  Future<ScannerDevice> create(ScannerEdit scanner);
  Future<ScannerDevice> update(String id, ScannerEdit scanner);
  Future<void> delete(String id);
}
