import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/models.dart';
import '../../../providers.dart';

/// Stocks offered by the stock picker, sorted by label.
final stockChoicesProvider = FutureProvider.autoDispose<List<FilmStock>>((
  ref,
) async {
  final all = await ref.watch(stocksProvider.future);
  return [...all]..sort((a, b) => a.label.compareTo(b.label));
});
