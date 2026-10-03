import 'dart:io';

import '../../domain/models/models.dart';

abstract class ScanRepository {
  Future<Frame> frame(String rollId, int n);
  Future<Frame> saveFrameNotes(String rollId, int n, String? notes);
  Future<List<Scan>> scans(String processingId, {Scanner? scanner});
  Future<List<ImportPreviewItem>> previewImport(
    String processingId,
    List<String> names, {
    int? startFrame,
    int? offset,
  });
  Future<ImportResult> importScan(
    String processingId, {
    required Scanner scanner,
    required String path,
    required String fileName,
    required int frameNumber,
    required bool replace,
  });
  Future<FrameComparison> compare(String processingId, int n);

  /// Absolute URL to display or download [s].
  String fileUrl(Scan s);

  /// Absolute URL of the file behind a scan reference.
  String scanUrl(String scanId);

  /// Streams [s] to [dest] without holding the whole file in memory.
  Future<void> download(Scan s, File dest);
}
