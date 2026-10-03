import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/models.dart';
import '../../../providers.dart';
import '../../core/widgets/common.dart';
import 'stock_form.dart';

/// Pick a stock, with inline creation. [withRollsFirst] lists stocks that
/// already have rolls first (M-17). [exclude] hides a stock id (M-14).
/// [allowCreate] shows "Create new stock"; the stock form turns it off for its
/// base-stock picker so forms cannot nest forever.
Future<FilmStock?> pickStock(
  BuildContext context,
  WidgetRef ref, {
  String title = 'Film stock',
  bool withRollsFirst = false,
  String? exclude,
  bool allowCreate = true,
}) async {
  List<FilmStock> stocks;
  final counts = <String, int>{};
  try {
    stocks = await ref.read(filmStockRepositoryProvider).stocks();
    if (withRollsFirst) {
      for (final r in await ref.read(rollRepositoryProvider).rolls()) {
        counts.update(r.filmStockId, (v) => v + 1, ifAbsent: () => 1);
      }
    }
  } catch (e) {
    if (context.mounted) toast(context, e.toString());
    return null;
  }
  stocks = stocks.where((s) => s.id != exclude).toList()
    ..sort((a, b) {
      final d = (counts[b.id] ?? 0).compareTo(counts[a.id] ?? 0);
      return d != 0 ? d : a.label.compareTo(b.label);
    });
  if (!context.mounted) return null;
  return pickOne<FilmStock>(
    context,
    title: title,
    items: stocks,
    label: (s) => s.label,
    subtitle: (s) =>
        'ISO ${s.boxIso} · ${s.process.wire}${(counts[s.id] ?? 0) > 0 ? ' · ${counts[s.id]} rolls' : ''}',
    footer: !allowCreate
        ? null
        : Builder(
            builder: (c) => Padding(
              padding: const EdgeInsets.all(8),
              child: TextButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Create new stock'),
                onPressed: () async {
                  final s = await Navigator.push<FilmStock>(
                    c,
                    MaterialPageRoute(builder: (_) => const StockFormScreen()),
                  );
                  if (c.mounted && s != null) Navigator.pop(c, s);
                },
              ),
            ),
          ),
  );
}
