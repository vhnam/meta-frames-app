import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/models.dart';
import '../../../domain/models/roll_filter.dart';
import '../../../providers.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/common.dart';
import '../../rolls/widgets/roll_tile.dart';
import '../../../routing/routes.dart';

import 'package:go_router/go_router.dart';

/// M-13 view/edit stock, M-15 stocks sharing a base stock.
class StockDetailScreen extends ConsumerWidget {
  const StockDetailScreen({super.key, required this.stockId});
  final String stockId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(stockDetailProvider(stockId));
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surfaceContainerLow,
      appBar: AppBar(
        backgroundColor: cs.surface,
        scrolledUnderElevation: 0,
        shape: Border(
          bottom: BorderSide(color: cs.outlineVariant, width: 0.65),
        ),
        title: Text(
          v.value?.stock.label ?? 'Film stock',
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
        ),
        actions: [
          if (v.value != null)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: TextButton(
                onPressed: () =>
                    context.push(Routes.stockEdit(v.value!.stock.id)),
                child: const Text(
                  'Edit',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ),
        ],
      ),
      body: AsyncBody(
        value: v,
        onRefresh: () async => ref.refresh(stockDetailProvider(stockId).future),
        builder: (d) => _Body(detail: d),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.detail});
  final FilmStockDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = detail;
    final s = d.stock;
    final cs = Theme.of(context).colorScheme;
    final rolls = ref.watch(rollsProvider(RollFilter(stockId: s.id)));
    final notes = s.description?.trim() ?? '';
    Widget muted(String t) =>
        Text(t, style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant));
    Widget stockList(List<FilmStock> l) => CardList(
      children: [
        for (final x in l)
          CardTile(
            compact: true,
            title: x.label,
            subtitle: 'ISO ${x.boxIso} · ${x.packaging.name}',
            trailing: Icon(
              Icons.chevron_right,
              size: 20,
              color: cs.onSurfaceVariant,
            ),
            onTap: () => context.push(Routes.stock(x.id)),
          ),
      ],
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        WarningBanner(d.warnings),
        CardList(
          children: [
            DetailInfoRow('Type', s.type.name.toUpperCase()),
            DetailInfoRow('Box ISO', '${s.boxIso}'),
            DetailInfoRow('Process', s.process.wire),
            DetailInfoRow('Packaging', s.packaging.name),
            DetailInfoRow('Stock origin', s.stockOrigin),
            if (s.packaging != Packaging.factory)
              DetailInfoRow('Pack origin', s.packOrigin),
            if (notes.isNotEmpty) DetailInfoRow('Notes', notes),
          ],
        ),
        if (d.baseStock != null) ...[
          const DetailLabel('BASE STOCK'),
          stockList([d.baseStock!]),
        ],
        if (d.siblings.isNotEmpty) ...[
          const DetailLabel('SAME BASE STOCK'),
          stockList(d.siblings),
        ],
        if (d.derived.isNotEmpty) ...[
          const DetailLabel('BASED ON THIS STOCK'),
          stockList(d.derived),
        ],
        const DetailLabel('ROLLS'),
        rolls.when(
          data: (rs) => rs.isEmpty
              ? muted('No rolls')
              : CardList(children: [for (final r in rs) RollTile(roll: r)]),
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('$e'),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
