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

  /// Sends the roll. Work done at home is finished when it is recorded, so its
  /// receipt dates go with it; the API has its own endpoints for them.
  Future<void> send(
    String rollId,
    NewProcessing job, {
    DateTime? scansReceivedAt,
    DateTime? negativesReturnedAt,
  }) async {
    final repo = _ref.read(processingRepositoryProvider);
    String? jobId;
    try {
      jobId = (await repo.send(rollId, job)).id;
      if (scansReceivedAt != null) {
        await repo.scansReceived(jobId, scansReceivedAt);
      }
      if (negativesReturnedAt != null) {
        await repo.negativesReturned(jobId, negativesReturnedAt);
      }
    } finally {
      _invalidateJob(jobId, rollId);
    }
  }

  /// The server recomputes the roll's status.
  Future<void> delete(String processingId, String rollId) async {
    await _ref.read(processingRepositoryProvider).delete(processingId);
    // The job is gone: reloading it could only fail.
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
