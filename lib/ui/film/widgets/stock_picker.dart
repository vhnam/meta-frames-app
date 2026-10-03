import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/models.dart';
import '../../core/widgets/common.dart';
import '../view_models/stock_choices.dart';
import '../../../routing/routes.dart';

import 'package:go_router/go_router.dart';

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
  final StockChoices choices;
  try {
    choices = await ref.read(
      stockChoicesProvider((withRollsFirst: withRollsFirst, exclude: exclude))
          .future,
    );
  } catch (e) {
    if (context.mounted) toast(context, e.toString());
    return null;
  }
  final counts = choices.rollCounts;
  if (!context.mounted) return null;
  return pickOne<FilmStock>(
    context,
    title: title,
    items: choices.stocks,
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
                  final s = await c.push<FilmStock>(Routes.stockNew);
                  if (c.mounted && s != null) Navigator.pop(c, s);
                },
              ),
            ),
          ),
  );
}
