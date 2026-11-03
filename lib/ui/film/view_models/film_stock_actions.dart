import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/film_requests.dart';
import '../../../domain/models/models.dart';
import '../../../providers.dart';

/// Writes that change film stocks.
class FilmStockActions {
  FilmStockActions(this._ref);
  final Ref _ref;

  /// Creates a stock, or updates [existing].
  Future<FilmStockDetail> save(
    FilmStockEdit stock, {
    FilmStock? existing,
  }) async {
    final repo = _ref.read(filmStockRepositoryProvider);
    final saved = existing == null
        ? await repo.create(stock)
        : await repo.update(existing.id, stock);
    _ref
      ..invalidate(stocksProvider)
      // Base, sibling and derived stocks list each other.
      ..invalidate(stockDetailProvider)
      ..invalidate(inventoryProvider);
    if (existing != null) {
      // Roll cards, roll details, loaded cameras and lab jobs show the stock name.
      _ref
        ..invalidate(rollsProvider)
        ..invalidate(rollDetailProvider)
        ..invalidate(expiryProvider)
        ..invalidate(camerasProvider)
        ..invalidate(negativesAtLabProvider);
    }
    return saved;
  }
}

final filmStockActionsProvider = Provider<FilmStockActions>(
  FilmStockActions.new,
);
