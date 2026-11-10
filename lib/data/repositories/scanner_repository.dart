import '../../domain/models/models.dart';

abstract class ScannerRepository {
  Future<List<ScannerDevice>> scanners();

  /// The scan options of each scanner kind.
  Future<List<ScannerKindOptions>> kinds();
}
