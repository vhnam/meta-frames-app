import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/models.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/form_kit.dart';
import '../../rolls/view_models/rolls_view_model.dart';
import '../../rolls/widgets/roll_card.dart';
import '../view_models/roll_search.dart';
import '../../core/widgets/common.dart';

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
    try {
      final search = ref.read(rollSearchProvider);
      final List<RollSummary> out;
      if (focal) {
        final mm = int.tryParse(q);
        if (mm == null) throw 'Enter focal length in mm, e.g. 40';
        out = await search.byFocalLength(mm);
      } else {
        out = await search.byName(q);
      }
      if (mounted) setState(() => results = out);
    } catch (e) {
      if (mounted) toast(context, e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final processes = ref.watch(stockProcessByIdProvider);
    final found = results;
    return Scaffold(
      appBar: AppBar(title: const Text('Search rolls')),
      body: Column(
        children: [
          SegmentSwitcher(
            labels: const ['Name', 'Focal length'],
            selected: focal ? 1 : 0,
            onChanged: (i) => setState(() {
              focal = i == 1;
              results = null;
            }),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: focal ? TextInputType.number : TextInputType.text,
              textInputAction: TextInputAction.search,
              decoration:
                  formInputDecoration(
                    focal
                        ? 'Focal length in mm, e.g. 40'
                        : 'Stock, camera or lens name',
                    cs,
                  ).copyWith(
                    prefixIcon: const Icon(Icons.search),
                    suffixText: focal ? 'mm' : null,
                  ),
              onSubmitted: (_) => _search(),
            ),
          ),
          if (busy) const LinearProgressIndicator(),
          Expanded(
            child: found == null
                ? const SizedBox.shrink()
                : found.isEmpty
                ? ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    children: const [
                      EmptyCard(
                        icon: Icons.search_off,
                        title: 'No rolls found',
                        text: 'Try another name or a different focal length.',
                      ),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: found.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => RollCard(
                      roll: found[i],
                      process: processes[found[i].filmStockId],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
