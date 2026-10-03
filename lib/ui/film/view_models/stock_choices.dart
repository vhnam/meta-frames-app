import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/models.dart';
import '../../../domain/models/roll_filter.dart';
import '../../../providers.dart';

/// Stocks offered by the stock picker, with how many rolls each has.
class StockChoices {
  const StockChoices(this.stocks, this.rollCounts);
  final List<FilmStock> stocks;
  final Map<String, int> rollCounts;
}

typedef StockChoicesArgs = ({bool withRollsFirst, String? exclude});

/// Stocks sorted by label. With `withRollsFirst`, stocks that already have
/// rolls come first, most rolls first (M-17). `exclude` hides one stock (M-14).
final stockChoicesProvider = FutureProvider.autoDispose
    .family<StockChoices, StockChoicesArgs>((ref, args) async {
      final all = await ref.watch(stocksProvider.future);
      final counts = <String, int>{};
      if (args.withRollsFirst) {
        for (final r in await ref.watch(
          rollsProvider(RollFilter.empty).future,
        )) {
          counts.update(r.filmStockId, (v) => v + 1, ifAbsent: () => 1);
        }
      }
      final stocks = all.where((s) => s.id != args.exclude).toList()
        ..sort((a, b) {
          final d = (counts[b.id] ?? 0).compareTo(counts[a.id] ?? 0);
          return d != 0 ? d : a.label.compareTo(b.label);
        });
      return StockChoices(stocks, counts);
    });
