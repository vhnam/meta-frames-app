import 'dart:io';

import '../../domain/models/models.dart';
import '../services/api_client.dart';
import 'scan_repository.dart';

class ScanRepositoryRemote implements ScanRepository {
  ScanRepositoryRemote(this._api);
  final ApiClient _api;

  @override
  Future<Frame> frame(String rollId, int n) async =>
      Frame.fromJson(await _api.send('GET', '/rolls/$rollId/frames/$n'));
  @override
  Future<Frame> saveFrameNotes(String rollId, int n, String? notes) async =>
      Frame.fromJson(
        await _api.send(
          'PUT',
          '/rolls/$rollId/frames/$n',
          body: {'notes': notes},
        ),
      );
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
  Future<List<ImportPreviewItem>> previewImport(
    String processingId,
    List<String> names, {
    int? startFrame,
    int? offset,
  }) async => decodeList(
    await _api.send(
      'POST',
      '/processing/$processingId/scans/preview',
      body: {'fileNames': names, 'startFrame': ?startFrame, 'offset': ?offset},
    ),
    ImportPreviewItem.fromJson,
  );
  @override
  Future<ImportResult> importScan(
    String processingId, {
    required Scanner scanner,
    required String path,
    required String fileName,
    required int frameNumber,
    required bool replace,
  }) async => ImportResult.fromJson(
    await _api.upload(
      '/processing/$processingId/scans',
      fields: {
        'scanner': scanner.name,
        'onConflict': replace ? 'replace' : 'skip',
        'frameNumber': '$frameNumber',
      },
      fileField: 'file',
      filePath: path,
      fileName: fileName,
    ),
  );
  @override
  Future<FrameComparison> compare(String processingId, int n) async =>
      FrameComparison.fromJson(
        await _api.send('GET', '/processing/$processingId/frames/$n/compare'),
      );
  @override
  String fileUrl(Scan s) => _api.absolute(s.fileUrl);
  @override
  String scanUrl(String scanId) => _api.absolute('/scans/$scanId/file');
  @override
  Future<void> download(Scan s, File dest) => _api.download(s.fileUrl, dest);
}
