import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/lab_requests.dart';
import '../../../domain/models/models.dart';
import '../../../providers.dart';

/// Writes that change labs.
class LabActions {
  LabActions(this._ref);
  final Ref _ref;

  /// Creates a lab, or updates [existing] when given.
  Future<Lab> save(LabEdit lab, {Lab? existing}) async {
    final repo = _ref.read(labRepositoryProvider);
    final saved = existing == null
        ? await repo.create(lab)
        : await repo.update(existing.id, lab);
    _ref.invalidate(labsProvider);
    if (existing != null) {
      // A renamed lab shows up wherever a job names it.
      _ref
        ..invalidate(negativesAtLabProvider)
        ..invalidate(processingProvider)
        ..invalidate(rollDetailProvider);
    }
    return saved;
  }

  Future<void> delete(String labId) async {
    await _ref.read(labRepositoryProvider).delete(labId);
    _ref.invalidate(labsProvider);
  }
}

final labActionsProvider = Provider<LabActions>(LabActions.new);
