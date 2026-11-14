import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import 'harness.dart';

/// The test's own client to the server: it seeds data, writes like the
/// dashboard and checks what the app did. It is never switched offline with
/// the app.
class ServerApi {
  final _http = http.Client();

  Future<dynamic> _send(
    String method,
    String path, {
    String? token,
    Object? body,
    void Function(http.Response response)? onResponse,
  }) async {
    final request = http.Request(method, Uri.parse('$serverUrl$path'))
      ..headers['Content-Type'] = 'application/json'
      ..headers['X-Actor'] = 'test';
    if (token != null) request.headers['Cookie'] = 'metaframes_session=$token';
    if (body != null) request.body = jsonEncode(body);
    final response = await http.Response.fromStream(await _http.send(request));
    onResponse?.call(response);
    if (response.statusCode ~/ 100 != 2) {
      throw StateError(
        '$method $path: ${response.statusCode} ${response.body}',
      );
    }
    return response.body.isEmpty ? null : jsonDecode(response.body);
  }

  /// The account that [token] signs in, as `/auth/me` answers.
  Future<Map<String, dynamic>> me(String token) async =>
      await _send('GET', '/auth/me', token: token) as Map<String, dynamic>;

  /// Registers a new account and returns its session token.
  Future<String> register(String email, String password) async {
    late String token;
    await _send(
      'POST',
      '/auth/register',
      body: {'email': email, 'password': password, 'name': 'E2E'},
      onResponse: (response) {
        final match = RegExp('metaframes_session=([^;,]+)')
            .firstMatch(response.headers['set-cookie'] ?? '');
        if (match == null) throw StateError('register: no session cookie');
        token = match[1]!;
      },
    );
    return token;
  }

  /// A film stock with [name] and one `in_stock` 135 roll of it.
  Future<({String rollId, String stockName})> seedRoll(
    String token, {
    required String stockName,
  }) async {
    final stockId = const Uuid().v4();
    await _send(
      'PUT',
      '/film-stocks/$stockId',
      token: token,
      body: {
        'brand': 'Kodak',
        'name': stockName,
        'type': 'color',
        'boxIso': '400',
        'process': 'C-41',
        'packaging': 'factory',
      },
    );
    final rolls = await _send(
      'POST',
      '/rolls/bulk',
      token: token,
      body: {
        'filmStockId': stockId,
        'format': 135,
        'exposures': 36,
        'quantity': 1,
      },
    );
    return (
      rollId: (rolls as List).single['id'] as String,
      stockName: stockName,
    );
  }

  /// A write that is not the app's: a new lab.
  Future<String> addLab(String token, String name) async {
    final id = const Uuid().v4();
    await _send('PUT', '/labs/$id', token: token, body: {'name': name});
    return id;
  }

  /// The labs of the account.
  Future<List<dynamic>> labs(String token) async =>
      await _send('GET', '/labs', token: token) as List<dynamic>;

  /// The notes of frame [number], or null when the frame does not exist.
  Future<String?> frameNotes(String token, String rollId, int number) async {
    try {
      final frame = await _send(
        'GET',
        '/rolls/$rollId/frames/$number',
        token: token,
      ) as Map<String, dynamic>;
      return frame['notes'] as String?;
    } on StateError catch (error) {
      if (error.message.contains(': 404 ')) return null;
      rethrow;
    }
  }
}
