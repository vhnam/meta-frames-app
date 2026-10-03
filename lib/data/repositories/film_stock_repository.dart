import '../../domain/models/models.dart';

abstract class FilmStockRepository {
  Future<List<FilmStock>> stocks({String? q});
  Future<FilmStockDetail> stock(String id);
  Future<FilmStockDetail> create(Map<String, dynamic> body);
  Future<FilmStockDetail> update(String id, Map<String, dynamic> body);
  Future<List<InventoryItem>> inventory({
    String? type,
    String? process,
    int? iso,
  });
}
