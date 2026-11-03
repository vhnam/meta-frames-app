import '../../domain/models/models.dart';
import '../../domain/models/scanner_requests.dart';
import '../services/api_client.dart';
import 'scanner_repository.dart';

class ScannerRepositoryRemote implements ScannerRepository {
  ScannerRepositoryRemote(this._api);
  final ApiClient _api;

  @override
  Future<List<ScannerDevice>> scanners() async =>
      decodeList(await _api.send('GET', '/scanners'), ScannerDevice.fromJson);
  @override
  Future<ScannerDevice> scanner(String id) async =>
      ScannerDevice.fromJson(await _api.send('GET', '/scanners/$id'));
  @override
  Future<List<ScannerKindOptions>> kinds() async => decodeList(
    await _api.send('GET', '/scanner-kinds'),
    ScannerKindOptions.fromJson,
  );
  @override
  Future<ScannerDevice> create(ScannerEdit scanner) async =>
      ScannerDevice.fromJson(
        await _api.send('POST', '/scanners', body: scanner.toJson()),
      );
  @override
  Future<ScannerDevice> update(String id, ScannerEdit scanner) async =>
      ScannerDevice.fromJson(
        await _api.send('PUT', '/scanners/$id', body: scanner.toJson()),
      );
  @override
  Future<void> delete(String id) => _api.send('DELETE', '/scanners/$id');
}
