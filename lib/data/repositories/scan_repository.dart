import 'dart:io';

import '../../domain/models/models.dart';

abstract class ScanRepository {
  Future<List<Scan>> scans(String processingId, {Scanner? scanner});

  /// Absolute URL to display or download [s].
  String fileUrl(Scan s);

  /// Absolute URL of the file behind a scan reference.
  String scanUrl(String scanId);

  /// Streams [s] to [dest] without holding the whole file in memory.
  Future<void> download(Scan s, File dest);
}
