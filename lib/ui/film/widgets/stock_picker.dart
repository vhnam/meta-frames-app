import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/local_store.dart';
import '../../../domain/models/models.dart';
import '../../core/widgets/common.dart';
import '../../sync/view_models/drafts.dart' show draftsOf;
import '../../sync/widgets/create_footer.dart';
import '../view_models/stock_choices.dart';
import '../../../routing/routes.dart';

import 'package:go_router/go_router.dart';

/// Pick a stock, with inline creation (only what the server needs) and the
/// unsent stock drafts.
Future<FilmStock?> pickStock(
  BuildContext context,
  WidgetRef ref, {
  String title = 'Film stock',
}) async {
  final List<FilmStock> stocks;
  try {
    stocks = await ref.read(stockChoicesProvider.future);
  } catch (e) {
    if (context.mounted) toast(context, e.toString());
    return null;
  }
  final drafts = await draftsOf(ref, DraftKind.stock);
  if (!context.mounted) return null;
  return pickOne<FilmStock>(
    context,
    title: title,
    items: stocks,
    label: (s) => s.label,
    subtitle: (s) => 'ISO ${s.boxIso} · ${s.process.wire}',
    footer: CreateFooter<FilmStock>(
      label: 'Create new stock',
      drafts: drafts,
      create: (c) => c.push(Routes.stockCreate()),
      resume: (c, d) => c.push(Routes.stockCreate(draft: d.id)),
    ),
  );
}
