import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/lab_order_requests.dart';
import '../../../domain/models/models.dart';
import '../../../providers.dart';

/// Writes that change orders and the rolls on them.
class LabOrderActions {
  LabOrderActions(this._ref);
  final Ref _ref;

  /// An order's lines and amounts set the price of the rolls on it.
  void _invalidate() {
    _ref
      ..invalidate(labOrdersProvider)
      ..invalidate(labOrderProvider)
      ..invalidate(linkableJobsProvider)
      ..invalidate(processingProvider)
      ..invalidate(rollDetailProvider);
  }

  Future<LabOrder> save(String id, LabOrderEdit order) async {
    final saved = await _ref.read(labOrderRepositoryProvider).save(id, order);
    _invalidate();
    return saved;
  }

  Future<void> delete(String id) async {
    await _ref.read(labOrderRepositoryProvider).delete(id);
    _invalidate();
  }

  /// Replaces the lines a job is billed on; none takes it off its order.
  Future<void> setJobLines(String jobId, List<String> lineIds) async {
    await _ref.read(processingRepositoryProvider).setOrderLines(jobId, lineIds);
    _invalidate();
  }
}

final labOrderActionsProvider = Provider<LabOrderActions>(LabOrderActions.new);
