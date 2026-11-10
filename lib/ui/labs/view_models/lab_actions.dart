import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/lab_requests.dart';
import '../../../domain/models/models.dart';
import '../../../providers.dart';

/// Quick add of labs. The dashboard edits and deletes them.
class LabActions {
  LabActions(this._ref);
  final Ref _ref;

  /// Creates a lab (at client id [id] when given).
  Future<Lab> save(LabEdit lab, {String? id}) async {
    final saved = await _ref.read(labRepositoryProvider).create(lab, id: id);
    _ref.invalidate(labsProvider);
    return saved;
  }

  /// After a create at [id] was refused because the id is taken: the lab at
  /// [id] if it is this create's, else null.
  Future<Lab?> landed(String id, LabEdit lab) async {
    final l = await _ref.read(labRepositoryProvider).lab(id);
    if (l.name != lab.name || (l.address ?? '') != (lab.address ?? '')) {
      return null;
    }
    _ref.invalidate(labsProvider);
    return l;
  }
}

final labActionsProvider = Provider<LabActions>(LabActions.new);
