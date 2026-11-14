import 'dart:convert';

import 'package:http/http.dart' as http;

import 'harness.dart';

/// The test's own client to the server: it checks what the app did, and is
/// never switched offline with the app.
class ServerApi {
  final _http = http.Client();

  /// The account that [token] signs in, as `/auth/me` answers.
  Future<Map<String, dynamic>> me(String token) async {
    final response = await _http.get(
      Uri.parse('$serverUrl/auth/me'),
      headers: {'Cookie': 'metaframes_session=$token'},
    );
    if (response.statusCode != 200) {
      throw StateError('GET /auth/me: ${response.statusCode} ${response.body}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}
