import '../../domain/models/film_requests.dart';
import '../../domain/models/models.dart';

abstract class FilmStockRepository {
  Future<List<FilmStock>> stocks({String? q});
  Future<FilmStockDetail> stock(String id);
  Future<FilmStockDetail> create(FilmStockEdit stock);
  Future<FilmStockDetail> update(String id, FilmStockEdit stock);
  Future<List<InventoryItem>> inventory({
    String? type,
    String? process,
    int? iso,
  });
}
