import '../../domain/models/film_requests.dart';
import '../../domain/models/models.dart';

abstract class FilmStockRepository {
  Future<List<FilmStock>> stocks({String? q});
  Future<FilmStockDetail> stock(String id);

  /// Creates a record. With [id] (a client id kept by the draft), the create is
  /// create-only: if the id is already taken the server answers
  /// `412 already_exists` and changes nothing, so a retry never duplicates.
  Future<FilmStockDetail> create(FilmStockEdit stock, {String? id});
  Future<List<InventoryItem>> inventory({
    String? type,
    String? process,
    int? iso,
  });
}
