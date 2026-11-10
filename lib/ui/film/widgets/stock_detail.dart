import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/models.dart';
import '../../../domain/models/roll_filter.dart';
import '../../../providers.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/common.dart';
import '../../rolls/widgets/roll_tile.dart';
import '../../../routing/routes.dart';

import 'package:go_router/go_router.dart';

/// A film stock and the stocks that share its base. Read-only: the dashboard
/// edits stocks.
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
            _BadgeRow('Type', _typeBadge(s.type, cs)),
            DetailInfoRow('Box ISO', s.boxIso),
            _BadgeRow('Process', ProcessBadge(s.process)),
            _BadgeRow('Packaging', _packagingBadge(s.packaging, cs)),
            DetailInfoRow('Stock origin', s.stockOrigin),
            if (s.packaging != Packaging.factory)
              DetailInfoRow('Pack origin', s.packOrigin),
            if (notes.isNotEmpty) _NotesRow(notes),
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

StampBadge _typeBadge(StockType type, ColorScheme cs) => switch (type) {
  StockType.color => StampBadge('Color', color: cs.onPrimaryContainer),
  StockType.bw => StampBadge('B&W', color: cs.onSurfaceVariant),
  StockType.slide => StampBadge('Slide', color: cs.tertiary),
};

StampBadge _packagingBadge(Packaging packaging, ColorScheme cs) =>
    switch (packaging) {
      Packaging.factory => StampBadge('Factory', color: cs.onSurfaceVariant),
      Packaging.repack => StampBadge('Repack', color: cs.tertiary),
      Packaging.respooled => StampBadge(
        'Respooled',
        color: cs.onPrimaryContainer,
      ),
    };

/// Label on the left, badge on the right; a row inside a [CardList].
class _BadgeRow extends StatelessWidget {
  const _BadgeRow(this.label, this.badge);
  final String label;
  final Widget badge;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        badge,
      ],
    ),
  );
}

/// Label above the note, which fills the row and renders as Markdown.
class _NotesRow extends StatelessWidget {
  const _NotesRow(this.notes);
  final String notes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Notes',
            style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          MarkdownBody(
            data: notes,
            // A line break typed in the form stays a line break.
            softLineBreak: true,
            styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
              p: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: cs.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
