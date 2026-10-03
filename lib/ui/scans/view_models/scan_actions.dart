import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/models.dart';
import '../../../providers.dart';

/// Writes that change frames and scans. Each refreshes only what it affects.
class ScanActions {
  ScanActions(this._ref);
  final Ref _ref;

  Future<void> saveFrameNotes(String rollId, int frame, String? notes) async {
    await _ref
        .read(scanRepositoryProvider)
        .saveFrameNotes(rollId, frame, notes);
    _ref
      ..invalidate(frameProvider((rollId, frame)))
      ..invalidate(rollDetailProvider(rollId));
  }

  Future<ImportResult> importScan(
    String processingId, {
    required Scanner scanner,
    required String path,
    required String fileName,
    required int frameNumber,
    required bool replace,
  }) => _ref
      .read(scanRepositoryProvider)
      .importScan(
        processingId,
        scanner: scanner,
        path: path,
        fileName: fileName,
        frameNumber: frameNumber,
        replace: replace,
      );

  /// Streams [s] to [dest] for sharing.
  Future<void> download(Scan s, File dest) =>
      _ref.read(scanRepositoryProvider).download(s, dest);

  /// Call once after a batch of imports. Imports can move a roll to scanned.
  void importsFinished(String processingId) => _ref
    ..invalidate(scansProvider)
    ..invalidate(compareProvider)
    ..invalidate(frameProvider)
    ..invalidate(processingProvider(processingId))
    ..invalidate(rollDetailProvider)
    ..invalidate(rollsProvider);
}

final scanActionsProvider = Provider<ScanActions>(ScanActions.new);

/// Builds absolute URLs for scan images.
final scanUrlProvider = Provider<String Function(Scan)>(
  (ref) => ref.watch(scanRepositoryProvider).fileUrl,
);
final scanRefUrlProvider = Provider<String Function(String scanId)>(
  (ref) => ref.watch(scanRepositoryProvider).scanUrl,
);
