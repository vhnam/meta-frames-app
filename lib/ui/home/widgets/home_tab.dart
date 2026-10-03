import 'package:flutter/material.dart';

import '../../core/theme.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/models.dart';
import '../../../providers.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/common.dart';
import '../../gear/widgets/camera_detail.dart';
import '../../labs/widgets/send_roll.dart';
import '../../gear/widgets/camera_form.dart';
import '../../rolls/widgets/add_rolls.dart';
import '../../rolls/widgets/roll_detail.dart';

const _followUpDays = 14;

/// M-01 home overview.
class HomeTab extends ConsumerWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cams = ref.watch(camerasProvider);
    final done = ref.watch(rollsProvider(emptyRollFilter));
    final neg = ref.watch(negativesAtLabProvider);
    final exp = ref.watch(expiryProvider);
    final stocks = {
      for (final s in ref.watch(stocksProvider).value ?? const <FilmStock>[])
        s.id: s,
    };
    final welcome =
        (cams.value?.isEmpty ?? false) && (done.value?.isEmpty ?? false);
    void open(Widget w) =>
        Navigator.push(context, MaterialPageRoute(builder: (_) => w));

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const ScreenHeader(
              kicker: 'MetaFrames · Film log',
              title: 'Overview',
            ),
            if (!welcome)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: _Counter(
                  cells: [
                    (
                      'Loaded',
                      cams.value
                          ?.where((c) => c.isActive && c.loadedRoll != null)
                          .length,
                    ),
                    (
                      'Ready',
                      done.value
                          ?.where((r) => r.status == RollStatus.doneShooting)
                          .length,
                    ),
                    ('At lab', neg.value?.length),
                    ('Expiring', exp.value?.expiring.length),
                  ],
                ),
              ),
            if (!welcome)
              Divider(color: Theme.of(context).colorScheme.outlineVariant),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => refreshAll(ref),
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 16),
                  children: [
                    if (welcome)
                      _Welcome(
                        onAddCamera: () => open(const CameraFormScreen()),
                        onAddRolls: () => open(const AddRollsScreen()),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _Section<List<Camera>, Camera>(
                              no: '01',
                              label: 'LOADED CAMERAS',
                              value: cams,
                              items: (list) => list
                                  .where(
                                    (c) => c.isActive && c.loadedRoll != null,
                                  )
                                  .toList(),
                              empty: 'No camera is loaded.',
                              builder: (items) => CardList(
                                gap: 8,
                                children: [
                                  for (final c in items)
                                    _loadedCamera(
                                      context,
                                      c,
                                      stocks[c.loadedRoll!.stockId],
                                    ),
                                ],
                              ),
                            ),
                            _Section<List<RollSummary>, RollSummary>(
                              no: '02',
                              label: 'READY FOR LAB',
                              value: done,
                              items: (rolls) => rolls
                                  .where(
                                    (r) => r.status == RollStatus.doneShooting,
                                  )
                                  .toList(),
                              empty: 'No finished rolls waiting.',
                              builder: (items) => CardList(
                                gap: 8,
                                children: [
                                  for (final r in items)
                                    _readyRoll(
                                      context,
                                      r,
                                      stocks[r.filmStockId],
                                    ),
                                ],
                              ),
                            ),
                            _Section<
                              List<NegativesAtLabItem>,
                              NegativesAtLabItem
                            >(
                              no: '03',
                              label: 'NEGATIVES AT LAB',
                              value: neg,
                              items: (list) => list,
                              empty: 'Nothing waiting at a lab.',
                              builder: (items) => CardList(
                                children: [
                                  for (final it in items)
                                    _negative(context, it),
                                ],
                              ),
                            ),
                            _Section<ExpiryView, ExpiryRoll>(
                              no: '04',
                              label: 'EXPIRING SOON',
                              value: exp,
                              items: (v) => v.expiring,
                              empty: 'No film expiring within 6 months.',
                              builder: (items) => CardList(
                                outline: Theme.of(context).colorScheme.error
                                    .withValues(alpha: 0.5),
                                children: [
                                  for (final e in items)
                                    _expiring(
                                      context,
                                      e,
                                      stocks[e.roll.filmStockId],
                                    ),
                                ],
                              ),
                              last: true,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _loadedCamera(BuildContext context, Camera c, FilmStock? stock) {
    final r = c.loadedRoll!;
    final iso = r.shotIso ?? stock?.boxIso;
    final pushed =
        r.shotIso != null && stock != null && r.shotIso != stock.boxIso;
    final subtitle = [
      '${r.stockBrand} ${r.stockName}',
      if (iso != null) 'ISO $iso (${pushed ? 'pushed/pulled' : 'box'})',
      '${r.daysLoaded}d',
    ].join(' · ');
    return CardTile(
      icon: Icons.photo_camera,
      iconSize: 44,
      title: c.name,
      subtitle: subtitle,
      badge: stock == null ? null : ProcessBadge(stock.process),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => CameraDetailScreen(cameraId: c.id)),
      ),
    );
  }

  Widget _readyRoll(BuildContext context, RollSummary r, FilmStock? stock) =>
      CardTile(
        icon: Icons.movie_outlined,
        title: r.stockLabel,
        subtitle: [
          '${r.format} · ${r.exposures} exp',
          if (r.finishedAt != null)
            'finished ${r.finishedAt!.toIso8601String().substring(0, 10)}',
        ].join(' · '),
        compact: true,
        trailing: FilledButton(
          style: FilledButton.styleFrom(
            minimumSize: Size.zero,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          onPressed: stock == null
              ? null
              : () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SendRollScreen(roll: r, stock: stock),
                  ),
                ),
          child: const Text('Send'),
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => RollDetailScreen(rollId: r.id)),
        ),
      );

  Widget _negative(BuildContext context, NegativesAtLabItem it) {
    final cs = Theme.of(context).colorScheme;
    final late = it.daysSinceSent >= _followUpDays;
    return CardTile(
      icon: Icons.science,
      iconBg: late ? cs.errorContainer : cs.tertiaryContainer,
      iconColor: late ? cs.error : cs.onTertiaryContainer,
      title: it.stockName,
      subtitle:
          '${it.labName} · ${it.daysSinceSent}d ago${late ? ' · follow up?' : ''}',
      subtitleColor: late ? cs.error : null,
      compact: true,
      trailing: late
          ? Icon(Icons.warning_rounded, size: 18, color: cs.error)
          : null,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => RollDetailScreen(rollId: it.rollId)),
      ),
    );
  }

  Widget _expiring(BuildContext context, ExpiryRoll e, FilmStock? stock) {
    final cs = Theme.of(context).colorScheme;
    return CardTile(
      leading: Icon(Icons.warning_rounded, size: 18, color: cs.error),
      title: e.roll.stockLabel,
      subtitle: e.expired
          ? 'Expired ${e.roll.expiry ?? ''}'.trim()
          : 'Expires ${e.roll.expiry ?? fmtDate(e.expiresOn)}',
      subtitleColor: cs.error,
      compact: true,
      badge: stock == null ? null : ProcessBadge(stock.process),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => RollDetailScreen(rollId: e.roll.id)),
      ),
    );
  }
}

class _Welcome extends StatelessWidget {
  const _Welcome({required this.onAddCamera, required this.onAddRolls});
  final VoidCallback onAddCamera, onAddRolls;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 64),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: kCorners,
              border: Border.all(
                color: cs.onPrimaryContainer,
                width: kHairline,
              ),
            ),
            child: Icon(Icons.photo_camera, size: 40, color: cs.primary),
          ),
          const SizedBox(height: 20),
          Text(
            'Welcome to MetaFrames',
            style: text.headlineSmall?.copyWith(fontSize: 22),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 280,
            child: Text(
              'Track your cameras, film rolls, and lab jobs — all in one place. Start by adding your gear.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                height: 1.6,
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 32),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton(
                  onPressed: onAddCamera,
                  child: const Text('Add your first camera'),
                ),
                const SizedBox(height: 10),
                FilledButton.tonal(
                  onPressed: onAddRolls,
                  child: const Text('Add rolls to your inventory'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'You can also import existing rolls from a spreadsheet on the web app.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Section label + async content. Renders an empty hint when there are no items.
class _Section<T, E> extends StatelessWidget {
  const _Section({
    required this.no,
    required this.label,
    required this.value,
    required this.items,
    required this.empty,
    required this.builder,
    this.last = false,
  });
  final String no, label, empty;
  final AsyncValue<T> value;
  final List<E> Function(T) items;
  final Widget Function(List<E>) builder;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final body = value.when(
      skipLoadingOnRefresh: true,
      loading: () => const Padding(
        padding: EdgeInsets.only(top: 8),
        child: LinearProgressIndicator(),
      ),
      error: (e, _) =>
          Padding(padding: const EdgeInsets.only(top: 8), child: Text('$e')),
      data: (d) {
        final list = items(d);
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: list.isEmpty
              ? Text(
                  empty,
                  style: monoStyle(
                    fontSize: 12.5,
                    letterSpacing: 0.2,
                    color: cs.onSurfaceVariant,
                  ),
                )
              : builder(list),
        );
      },
    );
    final count = value.hasValue ? items(value.requireValue).length : null;
    final style = monoStyle(
      fontWeight: FontWeight.w600,
      letterSpacing: 1.6,
      color: cs.onSurfaceVariant,
    );
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(no, style: style.copyWith(color: cs.onPrimaryContainer)),
              const SizedBox(width: 8),
              Text(label, style: style),
              const SizedBox(width: 12),
              Expanded(
                child: Divider(color: cs.outlineVariant, height: kHairline),
              ),
              if (count != null) ...[
                const SizedBox(width: 12),
                Text(count.toString().padLeft(2, '0'), style: style),
              ],
            ],
          ),
          body,
        ],
      ),
    );
  }
}

/// Frame-counter strip: one big number per status, divided by hairlines.
class _Counter extends StatelessWidget {
  const _Counter({required this.cells});
  final List<(String, int?)> cells;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: kCorners,
        border: Border.all(color: cs.outline, width: kHairline),
      ),
      // Every cell has the same content height, so the hairline dividers are
      // cell borders rather than IntrinsicHeight + VerticalDivider.
      child: Row(
        children: [
          for (var i = 0; i < cells.length; i++)
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: i == 0
                      ? null
                      : Border(
                          left: BorderSide(
                            color: cs.outlineVariant,
                            width: kHairline,
                          ),
                        ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    children: [
                      Text(
                        cells[i].$2?.toString().padLeft(2, '0') ?? '--',
                        style: headingStyle(
                          fontSize: 26,
                          letterSpacing: -0.5,
                          height: 1.1,
                          color: (cells[i].$2 ?? 0) > 0 && i == 3
                              ? cs.error
                              : cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        cells[i].$1.toUpperCase(),
                        style: monoStyle(
                          fontSize: 9.5,
                          letterSpacing: 1.2,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
