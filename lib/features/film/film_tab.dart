import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../providers.dart';
import '../../widgets/common.dart';
import '../rolls/add_rolls.dart';
import 'stock_detail.dart';
import 'stock_form.dart';

class FilmTab extends ConsumerStatefulWidget {
  const FilmTab({super.key});
  @override
  ConsumerState<FilmTab> createState() => _State();
}

class _State extends ConsumerState<FilmTab> {
  bool inventory = true;
  String q = '';
  InventoryFilter filter = (type: null, process: null, iso: null);

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      centerTitle: true,
      title: SegmentedButton<bool>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(value: true, label: Text('Inventory')),
          ButtonSegment(value: false, label: Text('Stocks')),
        ],
        selected: {inventory},
        onSelectionChanged: (s) => setState(() => inventory = s.first),
      ),
    ),
    floatingActionButton: inventory
        ? FloatingActionButton.extended(
            icon: const Icon(Icons.add),
            label: const Text('Add rolls'),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddRollsScreen()),
            ),
          )
        : FloatingActionButton(
            child: const Icon(Icons.add),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const StockFormScreen()),
            ),
          ),
    body: inventory ? _inventory() : _stocks(),
  );

  Widget _inventory() {
    final v = ref.watch(inventoryProvider(filter));
    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            spacing: 8,
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
                child: Chip(label: Text(filter.type?.toUpperCase() ?? 'Type')),
              ),
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
                child: Chip(label: Text(filter.process ?? 'Process')),
              ),
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
                child: Chip(
                  label: Text(filter.iso == null ? 'ISO' : 'ISO ${filter.iso}'),
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
              if (items.isEmpty)
                return const EmptyState('No unused rolls in stock.');
              return ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (c, i) {
                  final it = items[i];
                  return ListTile(
                    title: Text(it.stock.label),
                    subtitle: Text(
                      [
                        for (final f in it.formats) '${f.$2} × ${f.$1}',
                        'ISO ${it.stock.boxIso}',
                        it.stock.process.wire,
                        if (it.soonestExpiry != null) 'exp ${it.soonestExpiry}',
                      ].join(' · '),
                    ),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => StockDetailScreen(stockId: it.stock.id),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _stocks() {
    final v = ref.watch(stocksProvider);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Search stocks',
              prefixIcon: Icon(Icons.search),
            ),
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
              if (shown.isEmpty) return const EmptyState('No film stocks.');
              return ListView.separated(
                itemCount: shown.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (c, i) => ListTile(
                  title: Text(shown[i].label),
                  subtitle: Text(
                    '${shown[i].type.name.toUpperCase()} · ISO ${shown[i].boxIso} · ${shown[i].process.wire} · ${shown[i].packaging.name}',
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => StockDetailScreen(stockId: shown[i].id),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
