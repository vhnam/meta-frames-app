import '../../domain/models/film_requests.dart';
import '../../domain/models/models.dart';
import '../services/api_client.dart';
import 'film_stock_repository.dart';

class FilmStockRepositoryRemote implements FilmStockRepository {
  FilmStockRepositoryRemote(this._api);
  final ApiClient _api;

  @override
  Future<List<FilmStock>> stocks({String? q}) async => decodeList(
    await _api.send('GET', '/film-stocks', query: {'q': q}),
    FilmStock.fromJson,
  );
  @override
  Future<FilmStockDetail> stock(String id) async =>
      FilmStockDetail.fromJson(await _api.send('GET', '/film-stocks/$id'));
  @override
  Future<FilmStockDetail> create(FilmStockEdit stock) async =>
      FilmStockDetail.fromJson(
        await _api.send('POST', '/film-stocks', body: stock.toJson()),
      );
  @override
  Future<FilmStockDetail> update(String id, FilmStockEdit stock) async =>
      FilmStockDetail.fromJson(
        await _api.send('PUT', '/film-stocks/$id', body: stock.toJson()),
      );
  @override
  Future<List<InventoryItem>> inventory({
    String? type,
    String? process,
    int? iso,
  }) async => decodeList(
    await _api.send(
      'GET',
      '/inventory',
      query: {'type': type, 'process': process, 'iso': iso?.toString()},
    ),
    InventoryItem.fromJson,
  );
}
