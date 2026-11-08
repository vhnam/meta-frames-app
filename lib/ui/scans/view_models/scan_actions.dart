import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/models.dart';
import '../../../providers.dart';

/// Writes that change scans. Each refreshes only what it affects. Frame notes
/// belong to the roll, in `ui/rolls`.
class ScanActions {
  ScanActions(this._ref);
  final Ref _ref;

  /// Streams [s] to [dest] for sharing.
  Future<void> download(Scan s, File dest) =>
      _ref.read(scanRepositoryProvider).download(s, dest);
}

final scanActionsProvider = Provider<ScanActions>(ScanActions.new);

/// Builds absolute URLs for scan images.
final scanUrlProvider = Provider<String Function(Scan)>(
  (ref) => ref.watch(scanRepositoryProvider).fileUrl,
);
final scanRefUrlProvider = Provider<String Function(String scanId)>(
  (ref) => ref.watch(scanRepositoryProvider).scanUrl,
);
