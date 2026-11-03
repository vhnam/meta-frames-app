import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/models.dart';
import '../../../domain/models/scanner_requests.dart';
import '../../../providers.dart';

/// Writes that change scanners.
class ScannerActions {
  ScannerActions(this._ref);
  final Ref _ref;

  /// Creates a scanner, or updates [existing] when given.
  Future<ScannerDevice> save(
    ScannerEdit scanner, {
    ScannerDevice? existing,
  }) async {
    final repo = _ref.read(scannerRepositoryProvider);
    final saved = existing == null
        ? await repo.create(scanner)
        : await repo.update(existing.id, scanner);
    _ref.invalidate(scannersProvider);
    if (existing != null) {
      // A renamed scanner shows up wherever a job names it.
      _ref
        ..invalidate(scannerProvider(existing.id))
        ..invalidate(processingProvider)
        ..invalidate(rollDetailProvider);
    }
    return saved;
  }

  Future<void> delete(String scannerId) async {
    await _ref.read(scannerRepositoryProvider).delete(scannerId);
    _ref
      ..invalidate(scannersProvider)
      ..invalidate(scannerProvider(scannerId))
      // Labs that ran the scanner lose it.
      ..invalidate(labsProvider)
      ..invalidate(labProvider);
  }
}

final scannerActionsProvider = Provider<ScannerActions>(ScannerActions.new);
