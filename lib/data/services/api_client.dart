import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'session_store.dart';

class ApiException implements Exception {
  ApiException(this.status, this.code, this.message);
  final int status;
  final String code, message;
  bool get isNetwork => status == 0;
  @override
  String toString() => message;
}

/// Thrown when work begun under one session or server finds, before its next
/// request, that another is current. It is not a network failure: nothing is
/// retried, and nothing after it is sent.
class SessionChanged extends ApiException {
  SessionChanged()
    : super(401, 'session_changed', 'The session changed. Nothing was sent.');
}

/// The session and server that were current when a multi-step piece of work
/// began (see [ApiClient.pin]). Inside [run], every request through the same
/// session first checks it still is: a later step is never sent as another
/// account or to another server.
class SessionPin {
  SessionPin._(this._session, this._baseUrl)
    : _generation = _session.generation,
      _server = _baseUrl();

  final SessionStore _session;
  final String Function() _baseUrl;
  final int _generation;
  final String _server;

  bool get current =>
      _session.generation == _generation && _baseUrl() == _server;

  /// Throws [SessionChanged] unless the pinned session and server are current.
  void check() {
    if (!current) throw SessionChanged();
  }

  static final _zoneKey = Object();

  /// Runs [body] with this pin active for every request it starts.
  Future<T> run<T>(Future<T> Function() body) =>
      runZoned(body, zoneValues: {_zoneKey: this});
}

/// What a [ReadCache] makes of a read: the JSON to decode, or "read again".
class ReadResult {
  const ReadResult(this.json) : retry = false;
  const ReadResult.retry() : json = null, retry = true;
  final dynamic json;
  final bool retry;
}

/// One read seen by a [ReadCache], from start to answer.
abstract class ReadTicket {
  /// The server answered 2xx with [json]. With [last] the answer is not asked
  /// to be read again. An answer a change has overtaken is never returned,
  /// last or not: the device's latest state is, or a retriable failure when it
  /// has none.
  Future<ReadResult> fresh(dynamic json, {bool last = false});

  /// The server answered 404. Rethrows [error] unless the cache knows better.
  /// [last] as in [fresh].
  Future<ReadResult> notFound(ApiException error, {bool last = false});

  /// The server could not be reached. Serves what is kept, or throws.
  Future<ReadResult> offline(ApiException error);

  /// A ticket for reading again after [ReadResult.retry]: same session and
  /// server as this one, with the device's state as it is now. Throws when
  /// the session or [baseUrl] is no longer the one this read started under,
  /// so a retry is never made as, or for, anyone else. Call it right before
  /// the request is made.
  ReadTicket again(String baseUrl);
}

/// Keeps reads on the device. [begin] is called as a GET starts, with the
/// server it goes to; null means the read is not kept.
abstract class ReadCache {
  ReadTicket? begin(String baseUrl, String path, Map<String, String?>? query);
}

/// Transport only: builds requests against the configured server, maps
/// failures to [ApiException], and decodes JSON. Knows no endpoints.
///
/// The server's session is an HTTP-only cookie, and Dart's HTTP client has no
/// cookie jar, so this class plays that part: it keeps the session cookie in
/// [SessionStore] and sends it with every request. A 401 on a request that
/// carried the cookie means the session has ended.
class ApiClient {
  ApiClient(this._baseUrl, [http.Client? client, SessionStore? session])
    : _http = client ?? http.Client(),
      _session = session ?? SessionStore();

  final String Function() _baseUrl;
  final http.Client _http;
  final SessionStore _session;

  /// Kept reads, when the device keeps data for the current account.
  ReadCache? readCache;

  static const _sessionCookie = 'metaframes_session';

  /// Matches the session cookie in a Set-Cookie header. The HTTP client joins
  /// several Set-Cookie headers into one value with commas.
  static final _setSessionCookie = RegExp(
    '(?:^|,\\s*)$_sessionCookie=([^;,]*)',
  );

  String get baseUrl => _baseUrl();

  /// The session and server current now, to hold a multi-step piece of work to.
  SessionPin pin() => SessionPin._(_session, _baseUrl);

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

  /// Headers that prove the session, for requests made outside this client
  /// such as `Image.network`.
  Map<String, String> get sessionHeaders {
    final token = _session.token;
    return token == null ? const {} : {'Cookie': '$_sessionCookie=$token'};
  }

  Future<dynamic> send(
    String method,
    String path, {
    Map<String, String?>? query,
    Object? body,
    Map<String, String>? extraHeaders,
  }) async {
    final ticket = method == 'GET'
        ? readCache?.begin(baseUrl, path, query)
        : null;
    if (ticket == null) {
      return _send(method, path, query, body, extraHeaders, _timeout);
    }
    return _sendKept(ticket, path, query, extraHeaders);
  }

  /// Reads that make no change can be read again at no cost: a read that was
  /// out while one of the phone's own changes reached the server may hold the
  /// old state, so it is asked again, each time under a fresh ticket of the
  /// same session. An answer proven stale is never published: once the reads
  /// are used up the device's latest state is served, or the read fails and
  /// can be tried again.
  Future<dynamic> _sendKept(
    ReadTicket first,
    String path,
    Map<String, String?>? query,
    Map<String, String>? extraHeaders,
  ) async {
    var ticket = first;
    for (var attempt = 0; ; attempt++) {
      final last = attempt >= _keptRetries;
      final result = await _answer(ticket, path, query, extraHeaders, last);
      if (!result.retry) return result.json;
      ticket = ticket.again(baseUrl);
    }
  }

  /// One request, and what [ticket] makes of its outcome.
  Future<ReadResult> _answer(
    ReadTicket ticket,
    String path,
    Map<String, String?>? query,
    Map<String, String>? extraHeaders,
    bool last,
  ) async {
    final dynamic json;
    try {
      // A kept read falls back to the device sooner.
      json = await _send('GET', path, query, null, extraHeaders, _keptTimeout);
    } on ApiException catch (e) {
      if (e.isNetwork) return ticket.offline(e);
      if (e.status == 404) return ticket.notFound(e, last: last);
      rethrow;
    }
    return ticket.fresh(json, last: last);
  }

  /// How many times a kept read is asked again before its last answer is used.
  static const _keptRetries = 3;

  static const _timeout = Duration(seconds: 20);
  static const _keptTimeout = Duration(seconds: 10);

  Future<dynamic> _send(
    String method,
    String path,
    Map<String, String?>? query,
    Object? body,
    Map<String, String>? extraHeaders,
    Duration timeout,
  ) async {
    final req = http.Request(method, uri(path, query))
      ..headers.addAll({..._headers, ...?extraHeaders});
    if (body != null) req.body = jsonEncode(body);
    return _decode(await _sendLogged(req, timeout));
  }

  /// Creates a record. With a client [id] the create is a `PUT` at that id
  /// with `If-None-Match: *`: a retry of a create that already landed gets
  /// `412 already_exists` instead of a second record or an overwrite.
  Future<dynamic> create(String path, Object body, {String? id}) => id == null
      ? send('POST', path, body: body)
      : send(
          'PUT',
          '$path/$id',
          body: body,
          extraHeaders: const {'If-None-Match': '*'},
        );

  /// Streams a server-relative [path] to [dest] without buffering it in memory.
  Future<void> download(String path, File dest) async {
    final sent = _session.token;
    final res = await _http.send(
      http.Request('GET', Uri.parse(absolute(path)))
        ..headers.addAll(sessionHeaders),
    );
    await _trackSession(res, sent);
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

  Future<http.Response> _sendLogged(
    http.BaseRequest req,
    Duration timeout, [
    String suffix = '',
  ]) async {
    // Work pinned to a session sends nothing once that session has moved on.
    final pin = Zone.current[SessionPin._zoneKey] as SessionPin?;
    if (pin != null && identical(pin._session, _session)) pin.check();
    final sent = _session.token;
    req.headers.addAll(sessionHeaders);
    try {
      final res = await _roundTrip(req, timeout, suffix);
      await _trackSession(res, sent);
      if (res.statusCode < 200 || res.statusCode >= 300) _logFailed(req, res);
      return res;
    } on ApiException {
      _logFailed(req);
      rethrow;
    }
  }

  /// Applies a session cookie from the response, which signing out sends empty.
  /// A 401 ends the session only if the request carried the current token, so a
  /// slow answer from before a new sign-in cannot end the new session.
  Future<void> _trackSession(http.BaseResponse res, String? sent) async {
    final match = _setSessionCookie.firstMatch(res.headers['set-cookie'] ?? '');
    if (match != null) {
      final token = match[1]!;
      await _session.setToken(token.isEmpty ? null : token);
    } else if (res.statusCode == 401 &&
        sent != null &&
        _session.token == sent) {
      await _session.setToken(null);
    }
  }

  void _logFailed(http.BaseRequest req, [http.Response? res]) {
    debugPrint(_curl(req), wrapWidth: 100000);
    if (res != null) {
      debugPrint('HTTP ${res.statusCode} ${res.body}', wrapWidth: 100000);
    }
  }

  /// One line, safe to paste into a shell. Single quotes in values are escaped.
  /// The session cookie and auth request bodies, which hold passwords, are
  /// replaced so they never reach the device log.
  String _curl(http.BaseRequest req) {
    final parts = <String>['curl -X ${req.method}'];
    for (final e in req.headers.entries) {
      if (e.key.toLowerCase() == 'content-length') continue;
      final value = e.key.toLowerCase() == 'cookie' ? _redacted : e.value;
      parts.add("-H '${_shell(e.key)}: ${_shell(value)}'");
    }
    if (req is http.Request && req.body.isNotEmpty) {
      final body = req.url.path.contains('/auth/') ? _redacted : req.body;
      parts.add("-d '${_shell(body)}'");
    }
    parts.add("'${_shell(req.url.toString())}'");
    return parts.join(' ');
  }

  static const _redacted = '<redacted>';

  String _shell(String value) => value.replaceAll("'", r"'\''");

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
