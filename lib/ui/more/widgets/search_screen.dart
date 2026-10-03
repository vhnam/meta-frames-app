import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/models.dart';
import '../../../providers.dart';
import '../../core/widgets/common.dart';
import '../../rolls/widgets/roll_tile.dart';

/// M-38 find rolls by focal length, M-39 search rolls by stock/camera/lens name.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});
  @override
  ConsumerState<SearchScreen> createState() => _State();
}

class _State extends ConsumerState<SearchScreen> {
  bool focal = false;
  final ctrl = TextEditingController();
  List<RollSummary>? results;
  bool busy = false;

  Future<void> _search() async {
    final q = ctrl.text.trim();
    if (q.isEmpty) return;
    setState(() => busy = true);
    final api = ref.read(apiProvider);
    try {
      List<RollSummary> out;
      if (focal) {
        final mm = int.tryParse(q);
        if (mm == null) throw 'Enter focal length in mm, e.g. 40';
        out = (await api.searchByFocalLength(mm)).map((r) => r.roll).toList();
      } else {
        final lower = q.toLowerCase();
        final all = await api.rolls();
        final byId = <String, RollSummary>{
          for (final r in all)
            if (r.stockLabel.toLowerCase().contains(lower) ||
                (r.cameraName ?? '').toLowerCase().contains(lower))
              r.id: r,
        };
        // Lens names are not on the roll summary: resolve via lens filter.
        final lenses = (await api.lenses()).where(
          (l) => l.name.toLowerCase().contains(lower),
        );
        for (final l in lenses) {
          for (final r in await api.rolls(lensId: l.id)) {
            byId[r.id] = r;
          }
        }
        out = byId.values.toList();
      }
      if (mounted) setState(() => results = out);
    } catch (e) {
      if (mounted) toast(context, e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Search rolls')),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            spacing: 12,
            children: [
              SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: false, label: Text('Name')),
                  ButtonSegment(value: true, label: Text('Focal length')),
                ],
                selected: {focal},
                onSelectionChanged: (s) => setState(() {
                  focal = s.first;
                  results = null;
                }),
              ),
              TextField(
                controller: ctrl,
                autofocus: true,
                keyboardType: focal ? TextInputType.number : TextInputType.text,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: focal
                      ? 'Focal length in mm, e.g. 40'
                      : 'Stock, camera or lens name',
                  prefixIcon: const Icon(Icons.search),
                  suffixText: focal ? 'mm' : null,
                ),
                onSubmitted: (_) => _search(),
              ),
            ],
          ),
        ),
        if (busy) const LinearProgressIndicator(),
        Expanded(
          child: results == null
              ? const SizedBox.shrink()
              : results!.isEmpty
              ? const EmptyState('No rolls found.')
              : ListView.separated(
                  itemCount: results!.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, i) => RollTile(roll: results![i]),
                ),
        ),
      ],
    ),
  );
}
