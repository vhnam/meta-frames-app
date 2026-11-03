import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/models.dart';
import '../../../providers.dart';

/// Stocks offered by the stock picker, sorted by label. The argument hides one
/// stock (M-14).
final stockChoicesProvider = FutureProvider.autoDispose
    .family<List<FilmStock>, String?>((ref, exclude) async {
      final all = await ref.watch(stocksProvider.future);
      return all.where((s) => s.id != exclude).toList()
        ..sort((a, b) => a.label.compareTo(b.label));
    });
