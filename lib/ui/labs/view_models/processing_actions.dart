import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/lab_requests.dart';
import '../../../providers.dart';

/// Writes that move a roll through processing.
class ProcessingActions {
  ProcessingActions(this._ref);
  final Ref _ref;

  /// Job state shows in the job, the roll, the roll list and the lab list.
  void _invalidateJob(String? processingId, String? rollId) {
    if (processingId != null) _ref.invalidate(processingProvider(processingId));
    if (rollId != null) _ref.invalidate(rollDetailProvider(rollId));
    _ref
      ..invalidate(rollsProvider)
      ..invalidate(negativesAtLabProvider);
  }

  Future<void> send(String rollId, NewProcessing job) async {
    await _ref.read(processingRepositoryProvider).send(rollId, job);
    _invalidateJob(null, rollId);
  }

  Future<void> markScansReceived(String processingId, DateTime date) async {
    final p = await _ref
        .read(processingRepositoryProvider)
        .scansReceived(processingId, date);
    _invalidateJob(processingId, p.rollId);
  }

  Future<void> markNegativesReturned(String processingId, DateTime date) async {
    final p = await _ref
        .read(processingRepositoryProvider)
        .negativesReturned(processingId, date);
    _invalidateJob(processingId, p.rollId);
  }
}

final processingActionsProvider = Provider<ProcessingActions>(
  ProcessingActions.new,
);
