import 'dart:io';

import '../../domain/models/models.dart';
import '../services/api_client.dart';
import 'scan_repository.dart';

class ScanRepositoryRemote implements ScanRepository {
  ScanRepositoryRemote(this._api);
  final ApiClient _api;

  @override
  Future<List<Scan>> scans(String processingId, {Scanner? scanner}) async =>
      decodeList(
        await _api.send(
          'GET',
          '/processing/$processingId/scans',
          query: {'scanner': scanner?.name},
        ),
        Scan.fromJson,
      );
  @override
  String fileUrl(Scan s) => _api.absolute(s.fileUrl);
  @override
  String scanUrl(String scanId) => _api.absolute('/scans/$scanId/file');
  @override
  Future<void> download(Scan s, File dest) => _api.download(s.fileUrl, dest);
}
