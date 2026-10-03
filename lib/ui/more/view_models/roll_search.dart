import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/models.dart';
import '../../../providers.dart';

/// M-38 find rolls by focal length, M-39 search rolls by stock/camera/lens name.
class RollSearch {
  RollSearch(this._ref);
  final Ref _ref;

  Future<List<RollSummary>> byFocalLength(int mm) async {
    final hits = await _ref
        .read(rollRepositoryProvider)
        .searchByFocalLength(mm);
    return hits.map((r) => r.roll).toList();
  }

  /// Rolls whose stock or camera name contains [query], plus rolls shot with a
  /// lens whose name does. Roll summaries carry no lens names, so lenses are
  /// matched first and then each one's rolls are fetched.
  Future<List<RollSummary>> byName(String query) async {
    final rolls = _ref.read(rollRepositoryProvider);
    final lower = query.toLowerCase();
    final byId = <String, RollSummary>{
      for (final r in await rolls.rolls())
        if (r.stockLabel.toLowerCase().contains(lower) ||
            (r.cameraName ?? '').toLowerCase().contains(lower))
          r.id: r,
    };
    final lenses = (await _ref.read(lensRepositoryProvider).lenses()).where(
      (l) => l.name.toLowerCase().contains(lower),
    );
    for (final l in lenses) {
      for (final r in await rolls.rolls(lensId: l.id)) {
        byId[r.id] = r;
      }
    }
    return byId.values.toList();
  }
}

final rollSearchProvider = Provider<RollSearch>(RollSearch.new);
