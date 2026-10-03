import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/models.dart';
import '../../../providers.dart';
import '../../core/widgets/common.dart';
import '../../rolls/widgets/roll_tile.dart';
import 'stock_form.dart';

/// M-13 view/edit stock, M-15 stocks sharing a base stock.
class StockDetailScreen extends ConsumerWidget {
  const StockDetailScreen({super.key, required this.stockId});
  final String stockId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(stockDetailProvider(stockId));
    return Scaffold(
      appBar: AppBar(
        title: Text(v.value?.stock.label ?? 'Film stock'),
        actions: [
          if (v.value != null)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => StockFormScreen(
                    stock: v.value!.stock,
                    baseStock: v.value!.baseStock,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: AsyncBody(
        value: v,
        onRefresh: () async => ref.refresh(stockDetailProvider(stockId).future),
        builder: (d) {
          final s = d.stock;
          final rolls = ref.watch(
            rollsProvider((
              stockId: s.id,
              cameraId: null,
              lensId: null,
              format: null,
              from: null,
              to: null,
            )),
          );
          void open(FilmStock x) => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => StockDetailScreen(stockId: x.id)),
          );
          Widget stockList(List<FilmStock> l) => Column(
            children: [
              for (final x in l)
                ListTile(
                  title: Text(x.label),
                  subtitle: Text('ISO ${x.boxIso} · ${x.packaging.name}'),
                  onTap: () => open(x),
                ),
            ],
          );
          return ListView(
            children: [
              WarningBanner(d.warnings),
              InfoRow('Type', s.type.name.toUpperCase()),
              InfoRow('Box ISO', '${s.boxIso}'),
              InfoRow('Process', s.process.wire),
              InfoRow('Packaging', s.packaging.name),
              InfoRow('Stock origin', s.stockOrigin),
              InfoRow('Pack origin', s.packOrigin),
              InfoRow('Description', s.description),
              if (d.baseStock != null) ...[
                const SectionHeader('Base stock'),
                stockList([d.baseStock!]),
              ],
              if (d.siblings.isNotEmpty) ...[
                const SectionHeader('Same base stock'),
                stockList(d.siblings),
              ],
              if (d.derived.isNotEmpty) ...[
                const SectionHeader('Based on this stock'),
                stockList(d.derived),
              ],
              const SectionHeader('Rolls'),
              ...rolls.when(
                data: (rs) => rs.isEmpty
                    ? [
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('No rolls'),
                        ),
                      ]
                    : [for (final r in rs) RollTile(roll: r)],
                loading: () => [const LinearProgressIndicator()],
                error: (e, _) => [
                  Padding(padding: const EdgeInsets.all(16), child: Text('$e')),
                ],
              ),
              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }
}
