import '../../domain/models/models.dart';
import '../services/api_client.dart';
import 'scanner_repository.dart';

class ScannerRepositoryRemote implements ScannerRepository {
  ScannerRepositoryRemote(this._api);
  final ApiClient _api;

  @override
  Future<List<ScannerDevice>> scanners() async =>
      decodeList(await _api.send('GET', '/scanners'), ScannerDevice.fromJson);
  @override
  Future<List<ScannerKindOptions>> kinds() async => decodeList(
    await _api.send('GET', '/scanner-kinds'),
    ScannerKindOptions.fromJson,
  );
}
