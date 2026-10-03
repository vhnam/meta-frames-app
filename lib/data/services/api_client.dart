import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class ApiException implements Exception {
  ApiException(this.status, this.code, this.message);
  final int status;
  final String code, message;
  bool get isNetwork => status == 0;
  @override
  String toString() => message;
}

/// Transport only: builds requests against the configured server, maps
/// failures to [ApiException], and decodes JSON. Knows no endpoints.
class ApiClient {
  ApiClient(this._baseUrl, [http.Client? client])
    : _http = client ?? http.Client();

  final String Function() _baseUrl;
  final http.Client _http;

  String get baseUrl => _baseUrl();

  static const _headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'X-Actor': 'mobile',
  };

  Uri uri(String path, [Map<String, String?>? q]) {
    final params = <String, String>{
      for (final e in (q ?? {}).entries)
        if (e.value != null && e.value!.isNotEmpty) e.key: e.value!,
    };
    return Uri.parse('$baseUrl$path')
        .replace(queryParameters: params.isEmpty ? null : params);
  }

  /// Absolute URL for a server-relative path such as a scan's `fileUrl`.
  String absolute(String path) => '$baseUrl$path';

  Future<dynamic> send(
    String method,
    String path, {
    Map<String, String?>? query,
    Object? body,
    Map<String, String>? extraHeaders,
  }) async {
    final req = http.Request(method, uri(path, query))
      ..headers.addAll({..._headers, ...?extraHeaders});
    if (body != null) req.body = jsonEncode(body);
    return _decode(await _roundTrip(req, const Duration(seconds: 20)));
  }

  /// POST a single file as multipart form data.
  Future<dynamic> upload(
    String path, {
    required Map<String, String> fields,
    required String fileField,
    required String filePath,
    required String fileName,
  }) async {
    final req = http.MultipartRequest('POST', uri(path))
      ..headers['X-Actor'] = 'mobile'
      ..fields.addAll(fields)
      ..files.add(
        await http.MultipartFile.fromPath(
          fileField,
          filePath,
          filename: fileName,
        ),
      );
    return _decode(
      await _roundTrip(req, const Duration(minutes: 2), ' Upload failed.'),
    );
  }

  /// Streams a server-relative [path] to [dest] without buffering it in memory.
  Future<void> download(String path, File dest) async {
    final res = await _http.send(
      http.Request('GET', Uri.parse(absolute(path))),
    );
    if (res.statusCode != 200) {
      throw ApiException(res.statusCode, 'error', 'Cannot download scan.');
    }
    final sink = dest.openWrite();
    try {
      await res.stream.pipe(sink);
    } catch (_) {
      await dest.delete().catchError((_) => dest);
      rethrow;
    }
  }

  Future<http.Response> _roundTrip(
    http.BaseRequest req,
    Duration timeout, [
    String suffix = '',
  ]) async {
    try {
      return await http.Response.fromStream(
        await _http.send(req).timeout(timeout),
      );
    } on Exception {
      throw ApiException(
        0,
        'network',
        'Cannot reach the server at $baseUrl.$suffix',
      );
    }
  }

  dynamic _decode(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (res.body.isEmpty) return null;
      return jsonDecode(utf8.decode(res.bodyBytes));
    }
    var code = 'error', msg = 'Request failed (${res.statusCode})';
    try {
      final j = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      code = j['code'] ?? code;
      msg = j['message'] ?? msg;
    } catch (_) {}
    throw ApiException(res.statusCode, code, msg);
  }
}

/// Decodes a JSON array into a list of [T].
List<T> decodeList<T>(dynamic j, T Function(Map<String, dynamic>) f) =>
    (j as List).map((e) => f(e as Map<String, dynamic>)).toList();
