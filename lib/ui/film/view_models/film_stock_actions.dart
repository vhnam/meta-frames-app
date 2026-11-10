import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/film_requests.dart';
import '../../../domain/models/models.dart';
import '../../../providers.dart';

/// Quick add of film stocks. The dashboard edits them.
class FilmStockActions {
  FilmStockActions(this._ref);
  final Ref _ref;

  /// Creates a stock (at client id [id] when given).
  Future<FilmStockDetail> save(FilmStockEdit stock, {String? id}) async {
    final saved = await _ref
        .read(filmStockRepositoryProvider)
        .create(stock, id: id);
    _ref
      ..invalidate(stocksProvider)
      // Base, sibling and derived stocks list each other.
      ..invalidate(stockDetailProvider)
      ..invalidate(inventoryProvider);
    return saved;
  }

  /// After a create at [id] was refused because the id is taken: the stock
  /// at [id] if it is this create's, else null.
  Future<FilmStockDetail?> landed(String id, FilmStockEdit stock) async {
    final d = await _ref.read(filmStockRepositoryProvider).stock(id);
    final s = d.stock;
    final same =
        s.brand == stock.brand &&
        s.name == stock.name &&
        s.type == stock.type &&
        s.boxIso == stock.boxIso &&
        s.process == stock.process &&
        s.packaging == stock.packaging;
    if (!same) return null;
    _ref
      ..invalidate(stocksProvider)
      ..invalidate(inventoryProvider);
    return d;
  }
}

final filmStockActionsProvider = Provider<FilmStockActions>(
  FilmStockActions.new,
);
