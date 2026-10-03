import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/models.dart';
import '../../../providers.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/form_kit.dart';
import '../../../routing/routes.dart';

import 'package:go_router/go_router.dart';

/// Film catalog: unused rolls in stock, and every known film stock.
class FilmTab extends ConsumerStatefulWidget {
  const FilmTab({super.key});
  @override
  ConsumerState<FilmTab> createState() => _State();
}

class _State extends ConsumerState<FilmTab> {
  bool inventory = true;
  String q = '';
  InventoryFilter filter = (type: null, process: null, iso: null);

  static const _listPadding = EdgeInsets.fromLTRB(16, 12, 16, 16);
  static const _tilePadding = EdgeInsets.symmetric(
    horizontal: 16,
    vertical: 14,
  );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // Contextual label while the current segment is empty, as on the Gear tab.
    final empty = inventory
        ? ref.watch(inventoryProvider(filter)).value?.isEmpty
        : ref.watch(stocksProvider).value?.isEmpty;
    final addLabel = (empty ?? false)
        ? (inventory ? '+ Rolls' : '+ Stock')
        : '+ Add';
    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            ScreenHeader(
              kicker: 'MetaFrames · Film catalog',
              title: 'Film stocks',
              back: true,
              trailing: TextButton(
                onPressed: () => context.push(
                  inventory ? Routes.rollNew() : Routes.stockNew,
                ),
                child: Text(addLabel),
              ),
            ),
            SegmentSwitcher(
              labels: const ['Inventory', 'Stocks'],
              selected: inventory ? 0 : 1,
              onChanged: (i) => setState(() => inventory = i == 0),
            ),
            Expanded(child: inventory ? _inventory() : _stocks()),
          ],
        ),
      ),
    );
  }

  Widget _inventory() {
    final v = ref.watch(inventoryProvider(filter));
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        SizedBox(
          height: 60,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            children: [
              PopupMenuButton<String?>(
                onSelected: (v) => setState(
                  () => filter = (
                    type: v,
                    process: filter.process,
                    iso: filter.iso,
                  ),
                ),
                itemBuilder: (_) => [
                  const PopupMenuItem(value: null, child: Text('Any type')),
                  for (final t in StockType.values)
                    PopupMenuItem(
                      value: t.name,
                      child: Text(t.name.toUpperCase()),
                    ),
                ],
                child: FilterPill(
                  label: filter.type ?? 'Type',
                  on: filter.type != null,
                ),
              ),
              const SizedBox(width: 6),
              PopupMenuButton<String?>(
                onSelected: (v) => setState(
                  () =>
                      filter = (type: filter.type, process: v, iso: filter.iso),
                ),
                itemBuilder: (_) => [
                  const PopupMenuItem(value: null, child: Text('Any process')),
                  for (final p in Process.values)
                    PopupMenuItem(value: p.wire, child: Text(p.wire)),
                ],
                child: FilterPill(
                  label: filter.process ?? 'Process',
                  on: filter.process != null,
                ),
              ),
              const SizedBox(width: 6),
              PopupMenuButton<int?>(
                onSelected: (v) => setState(
                  () => filter = (
                    type: filter.type,
                    process: filter.process,
                    iso: v,
                  ),
                ),
                itemBuilder: (_) => [
                  const PopupMenuItem(value: null, child: Text('Any ISO')),
                  for (final i in [50, 100, 200, 400, 800, 1600, 3200])
                    PopupMenuItem(value: i, child: Text('ISO $i')),
                ],
                child: FilterPill(
                  label: filter.iso == null ? 'ISO' : 'ISO ${filter.iso}',
                  on: filter.iso != null,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: AsyncBody(
            value: v,
            onRefresh: () async =>
                ref.refresh(inventoryProvider(filter).future),
            builder: (items) {
              if (items.isEmpty) {
                return ListView(
                  padding: _listPadding,
                  children: const [
                    EmptyCard(
                      icon: Icons.inventory_2_outlined,
                      title: 'No unused rolls',
                      text: 'Rolls you add to stock show up here until you load them into a camera.',
                    ),
                  ],
                );
              }
              return ListView(
                padding: _listPadding,
                children: [
                  SectionLabel('In stock · ${items.length}'),
                  const SizedBox(height: 8),
                  CardList(
                    children: [
                      for (final it in items)
                        CardTile(
                          icon: Icons.local_movies_outlined,
                          iconSize: 44,
                          iconBg: cs.surfaceContainer,
                          iconColor: cs.onSurfaceVariant,
                          padding: _tilePadding,
                          title: it.stock.label,
                          subtitle: [
                            for (final f in it.formats) '${f.$2} × ${f.$1}',
                            'ISO ${it.stock.boxIso}',
                            if (it.soonestExpiry != null)
                              'exp ${it.soonestExpiry}',
                          ].join(' · '),
                          badge: ProcessBadge(it.stock.process),
                          onTap: () => context.push(Routes.stock(it.stock.id)),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _stocks() {
    final v = ref.watch(stocksProvider);
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: TextField(
            decoration: formInputDecoration(
              'Search stocks',
              cs,
            ).copyWith(prefixIcon: const Icon(Icons.search)),
            onChanged: (s) => setState(() => q = s.toLowerCase()),
          ),
        ),
        Expanded(
          child: AsyncBody(
            value: v,
            onRefresh: () async => ref.refresh(stocksProvider.future),
            builder: (all) {
              final shown =
                  all.where((s) => s.label.toLowerCase().contains(q)).toList()
                    ..sort((a, b) => a.label.compareTo(b.label));
              if (shown.isEmpty) {
                return ListView(
                  padding: _listPadding,
                  children: [
                    EmptyCard(
                      icon: Icons.local_movies_outlined,
                      title: q.isEmpty ? 'No film stocks' : 'No match',
                      text: q.isEmpty
                          ? 'Add the films you shoot to build your catalog.'
                          : 'No film stock matches your search.',
                    ),
                  ],
                );
              }
              return ListView(
                padding: _listPadding,
                children: [
                  SectionLabel('Stocks · ${shown.length}'),
                  const SizedBox(height: 8),
                  CardList(
                    children: [
                      for (final s in shown)
                        CardTile(
                          icon: Icons.local_movies_outlined,
                          iconSize: 44,
                          iconBg: cs.surfaceContainer,
                          iconColor: cs.onSurfaceVariant,
                          padding: _tilePadding,
                          title: s.label,
                          subtitle:
                              '${s.type.name.toUpperCase()} · ISO ${s.boxIso} · ${s.packaging.name}',
                          badge: ProcessBadge(s.process),
                          onTap: () => context.push(Routes.stock(s.id)),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
