import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'models.dart';

const defaultBaseUrl = 'http://10.0.2.2:8080';
const _baseUrlKey = 'base_url';
const _uuid = Uuid();

String newId() => _uuid.v4();

String ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class ApiException implements Exception {
  ApiException(this.status, this.code, this.message);
  final int status;
  final String code, message;
  bool get isNetwork => status == 0;
  @override
  String toString() => message;
}

class Api {
  Api(this.prefs, [http.Client? client]) : _http = client ?? http.Client();

  final SharedPreferences prefs;
  final http.Client _http;

  String get baseUrl => prefs.getString(_baseUrlKey) ?? defaultBaseUrl;
  Future<void> setBaseUrl(String v) =>
      prefs.setString(_baseUrlKey, v.trim().replaceAll(RegExp(r'/+$'), ''));

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'X-Actor': 'mobile',
  };

  Uri _uri(String path, [Map<String, String?>? q]) {
    final params = <String, String>{
      for (final e in (q ?? {}).entries)
        if (e.value != null && e.value!.isNotEmpty) e.key: e.value!,
    };
    return Uri.parse('$baseUrl$path')
        .replace(queryParameters: params.isEmpty ? null : params);
  }

  /// Absolute URL for a server-relative path such as a scan's `fileUrl`.
  String absolute(String path) => '$baseUrl$path';

  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, String?>? query,
    Object? body,
    Map<String, String>? extraHeaders,
  }) async {
    final req = http.Request(method, _uri(path, query))
      ..headers.addAll({..._headers, ...?extraHeaders});
    if (body != null) req.body = jsonEncode(body);
    final http.Response res;
    try {
      res = await http.Response.fromStream(
        await _http.send(req).timeout(const Duration(seconds: 20)),
      );
    } on Exception {
      throw ApiException(0, 'network', 'Cannot reach the server at $baseUrl.');
    }
    return _decode(res);
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

  List<T> _l<T>(dynamic j, T Function(Map<String, dynamic>) f) =>
      (j as List).map((e) => f(e as Map<String, dynamic>)).toList();

  // Cameras
  Future<List<Camera>> cameras() async =>
      _l(await _send('GET', '/cameras'), Camera.fromJson);
  Future<Camera> camera(String id) async =>
      Camera.fromJson(await _send('GET', '/cameras/$id'));
  Future<Camera> createCamera(Map<String, dynamic> body) async =>
      Camera.fromJson(await _send('POST', '/cameras', body: body));
  Future<Camera> updateCamera(String id, Map<String, dynamic> body) async =>
      Camera.fromJson(await _send('PUT', '/cameras/$id', body: body));
  Future<void> deleteCamera(String id) => _send('DELETE', '/cameras/$id');
  Future<Camera> setCameraActive(String id, bool active) async =>
      Camera.fromJson(
        await _send('PUT', '/cameras/$id/active', body: {'isActive': active}),
      );
  Future<List<Lens>> cameraLenses(String id) async =>
      _l(await _send('GET', '/cameras/$id/lenses'), Lens.fromJson);
  Future<void> setCameraLenses(String id, List<String> lensIds) =>
      _send('PUT', '/cameras/$id/lenses', body: {'lensIds': lensIds});

  // Lenses
  Future<List<Lens>> lenses({String? preferMount}) async => _l(
    await _send('GET', '/lenses', query: {'preferMount': preferMount}),
    Lens.fromJson,
  );
  Future<Lens> lens(String id) async =>
      Lens.fromJson(await _send('GET', '/lenses/$id'));
  Future<Lens> createLens(Map<String, dynamic> body) async =>
      Lens.fromJson(await _send('POST', '/lenses', body: body));
  Future<Lens> updateLens(String id, Map<String, dynamic> body) async =>
      Lens.fromJson(await _send('PUT', '/lenses/$id', body: body));
  Future<void> deleteLens(String id) => _send('DELETE', '/lenses/$id');
  Future<Lens> setLensActive(String id, bool active) async => Lens.fromJson(
    await _send('PUT', '/lenses/$id/active', body: {'isActive': active}),
  );

  // Film stocks
  Future<List<FilmStock>> stocks({String? q}) async => _l(
    await _send('GET', '/film-stocks', query: {'q': q}),
    FilmStock.fromJson,
  );
  Future<FilmStockDetail> stock(String id) async =>
      FilmStockDetail.fromJson(await _send('GET', '/film-stocks/$id'));
  Future<FilmStockDetail> createStock(Map<String, dynamic> body) async =>
      FilmStockDetail.fromJson(await _send('POST', '/film-stocks', body: body));
  Future<FilmStockDetail> updateStock(
    String id,
    Map<String, dynamic> body,
  ) async => FilmStockDetail.fromJson(
    await _send('PUT', '/film-stocks/$id', body: body),
  );
  Future<List<InventoryItem>> inventory({
    String? type,
    String? process,
    int? iso,
  }) async => _l(
    await _send(
      'GET',
      '/inventory',
      query: {'type': type, 'process': process, 'iso': iso?.toString()},
    ),
    InventoryItem.fromJson,
  );

  // Labs
  Future<List<Lab>> labs() async =>
      _l(await _send('GET', '/labs'), Lab.fromJson);
  Future<Lab> createLab(Map<String, dynamic> body) async =>
      Lab.fromJson(await _send('POST', '/labs', body: body));
  Future<Lab> updateLab(String id, Map<String, dynamic> body) async =>
      Lab.fromJson(await _send('PUT', '/labs/$id', body: body));
  Future<void> deleteLab(String id) => _send('DELETE', '/labs/$id');

  // Rolls
  Future<List<RollSummary>> rolls({
    String? status,
    String? filmStockId,
    String? cameraId,
    String? lensId,
    int? format,
    DateTime? startedFrom,
    DateTime? startedTo,
  }) async => _l(
    await _send(
      'GET',
      '/rolls',
      query: {
        'status': status,
        'filmStockId': filmStockId,
        'cameraId': cameraId,
        'lensId': lensId,
        'format': format?.toString(),
        'startedFrom': startedFrom == null ? null : ymd(startedFrom),
        'startedTo': startedTo == null ? null : ymd(startedTo),
      },
    ),
    RollSummary.fromJson,
  );
  Future<List<RollSummary>> addRolls(Map<String, dynamic> body) async => _l(
    await _send(
      'POST',
      '/rolls/bulk',
      body: body,
      extraHeaders: {'Idempotency-Key': newId()},
    ),
    RollSummary.fromJson,
  );
  Future<ExpiryView> expiry() async =>
      ExpiryView.fromJson(await _send('GET', '/expiry'));
  Future<RollDetail> roll(String id) async =>
      RollDetail.fromJson(await _send('GET', '/rolls/$id'));
  Future<RollDetail> updateRoll(String id, Map<String, dynamic> body) async =>
      RollDetail.fromJson(await _send('PUT', '/rolls/$id', body: body));
  Future<void> deleteRoll(String id) => _send('DELETE', '/rolls/$id');
  Future<RollDetail> loadRoll(String id, Map<String, dynamic> body) async =>
      RollDetail.fromJson(await _send('PUT', '/rolls/$id/load', body: body));
  Future<void> setRollLenses(String id, List<String> lensIds) =>
      _send('PUT', '/rolls/$id/lenses', body: {'lensIds': lensIds});
  Future<RollDetail> finishRoll(String id, DateTime date) async =>
      RollDetail.fromJson(
        await _send('PUT', '/rolls/$id/finish', body: {'date': ymd(date)}),
      );

  // Processing
  Future<List<Processing>> processingFor(String rollId) async =>
      _l(await _send('GET', '/rolls/$rollId/processing'), Processing.fromJson);
  Future<Processing> sendRoll(String rollId, Map<String, dynamic> body) async =>
      Processing.fromJson(
        await _send('PUT', '/rolls/$rollId/processing/${newId()}', body: body),
      );
  Future<Processing> processing(String id) async =>
      Processing.fromJson(await _send('GET', '/processing/$id'));
  Future<Processing> scansReceived(String id, DateTime date) async =>
      Processing.fromJson(
        await _send(
          'PUT',
          '/processing/$id/scans-received',
          body: {'date': ymd(date)},
        ),
      );
  Future<Processing> negativesReturned(String id, DateTime date) async =>
      Processing.fromJson(
        await _send(
          'PUT',
          '/processing/$id/negatives-returned',
          body: {'date': ymd(date)},
        ),
      );
  Future<List<NegativesAtLabItem>> negativesAtLab() async =>
      _l(await _send('GET', '/negatives-at-lab'), NegativesAtLabItem.fromJson);

  // Frames & scans
  Future<Frame> frame(String rollId, int n) async =>
      Frame.fromJson(await _send('GET', '/rolls/$rollId/frames/$n'));
  Future<Frame> saveFrameNotes(String rollId, int n, String? notes) async =>
      Frame.fromJson(
        await _send('PUT', '/rolls/$rollId/frames/$n', body: {'notes': notes}),
      );
  Future<List<Scan>> scans(String processingId, {Scanner? scanner}) async => _l(
    await _send(
      'GET',
      '/processing/$processingId/scans',
      query: {'scanner': scanner?.name},
    ),
    Scan.fromJson,
  );
  Future<List<ImportPreviewItem>> previewImport(
    String processingId,
    List<String> names, {
    int? startFrame,
    int? offset,
  }) async => _l(
    await _send(
      'POST',
      '/processing/$processingId/scans/preview',
      body: {'fileNames': names, 'startFrame': ?startFrame, 'offset': ?offset},
    ),
    ImportPreviewItem.fromJson,
  );
  Future<ImportResult> importScan(
    String processingId, {
    required Scanner scanner,
    required String path,
    required String fileName,
    required int frameNumber,
    required bool replace,
  }) async {
    final req =
        http.MultipartRequest('POST', _uri('/processing/$processingId/scans'))
          ..headers['X-Actor'] = 'mobile'
          ..fields['scanner'] = scanner.name
          ..fields['onConflict'] = replace ? 'replace' : 'skip'
          ..fields['frameNumber'] = '$frameNumber'
          ..files.add(
            await http.MultipartFile.fromPath('file', path, filename: fileName),
          );
    final http.Response res;
    try {
      res = await http.Response.fromStream(
        await _http.send(req).timeout(const Duration(minutes: 2)),
      );
    } on Exception {
      throw ApiException(
        0,
        'network',
        'Cannot reach the server at $baseUrl. Upload failed.',
      );
    }
    return ImportResult.fromJson(_decode(res));
  }

  Future<FrameComparison> compare(String processingId, int n) async =>
      FrameComparison.fromJson(
        await _send('GET', '/processing/$processingId/frames/$n/compare'),
      );
  Future<List<int>> scanBytes(Scan s) async {
    final res = await _http.get(Uri.parse(absolute(s.fileUrl)));
    if (res.statusCode != 200) {
      throw ApiException(res.statusCode, 'error', 'Cannot download scan.');
    }
    return res.bodyBytes;
  }

  // Search
  Future<List<SearchResult>> searchByFocalLength(int mm) async => _l(
    await _send('GET', '/search/rolls', query: {'focalLength': '$mm'}),
    SearchResult.fromJson,
  );
}
