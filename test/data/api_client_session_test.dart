import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:meta_frames/data/repositories/auth_repository_remote.dart';
import 'package:meta_frames/data/services/api_client.dart';
import 'package:meta_frames/data/services/session_store.dart';

const _setSession =
    'metaframes_session=abc123; Path=/; Max-Age=604800; HttpOnly';

http.Response _json(
  Object body, {
  int status = 200,
  Map<String, String> headers = const {},
}) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json', ...headers},
);

ApiClient _client(
  SessionStore session,
  Future<http.Response> Function(http.Request) handler,
) => ApiClient(() => 'http://srv:8080', MockClient(handler), session);

void main() {
  group('session cookie', () {
    test('login stores the token and later requests send it', () async {
      final session = SessionStore();
      final seen = <http.Request>[];
      final api = _client(session, (request) async {
        seen.add(request);
        return request.url.path == '/auth/login'
            ? _json({'message': 'ok'}, headers: {'set-cookie': _setSession})
            : _json([]);
      });

      await AuthRepositoryRemote(api)
          .login(email: 'a@b.co', password: 'secret');
      await api.send('GET', '/cameras');

      expect(session.token, 'abc123');
      expect(seen.first.headers.containsKey('Cookie'), isFalse);
      expect(seen.last.headers['Cookie'], 'metaframes_session=abc123');
    });

    test('finds the cookie among several joined Set-Cookie values', () async {
      final session = SessionStore();
      final api = _client(
        session,
        (_) async => _json(
          {},
          headers: {
            'set-cookie':
                'metaframes_oauth2=x; Expires=Mon, 02 Jan 2026 00:00:00 GMT, '
                '$_setSession',
          },
        ),
      );

      await api.send('POST', '/auth/login');

      expect(session.token, 'abc123');
    });

    test('an empty cookie clears the token', () async {
      final session = SessionStore('abc123');
      final api = _client(
        session,
        (_) async => _json(
          {},
          headers: {'set-cookie': 'metaframes_session=; Path=/; Max-Age=0'},
        ),
      );

      await api.send('POST', '/auth/logout');

      expect(session.signedIn, isFalse);
    });

    test('a 401 on a request with a session ends the session', () async {
      final session = SessionStore('abc123');
      var notified = 0;
      session.addListener(() => notified++);
      final api = _client(
        session,
        (_) async => _json({'code': 'unauthorized'}, status: 401),
      );

      await expectLater(
        api.send('GET', '/cameras'),
        throwsA(isA<ApiException>()),
      );

      expect(session.signedIn, isFalse);
      expect(notified, 1);
    });

    test(
      'a slow 401 from before a new sign-in keeps the new session',
      () async {
        final session = SessionStore('old');
        final api = _client(session, (_) async {
          await session.setToken('new');
          return _json({'code': 'unauthorized'}, status: 401);
        });

        await expectLater(
          api.send('GET', '/cameras'),
          throwsA(isA<ApiException>()),
        );

        expect(session.token, 'new');
      },
    );

    test('wrong credentials do not touch the session state', () async {
      final session = SessionStore();
      var notified = 0;
      session.addListener(() => notified++);
      final api = _client(
        session,
        (_) async => _json({
          'code': 'invalid_credentials',
          'message': 'Invalid Credentials',
        }, status: 401),
      );

      await expectLater(
        AuthRepositoryRemote(api).login(email: 'a@b.co', password: 'wrong'),
        throwsA(
          isA<ApiException>().having(
            (error) => error.message,
            'message',
            'Invalid Credentials',
          ),
        ),
      );

      expect(notified, 0);
    });

    test('download sends the session and a 401 ends it', () async {
      final session = SessionStore('abc123');
      late http.Request seen;
      final api = _client(session, (request) async {
        seen = request;
        return http.Response('', 401);
      });
      final dir = Directory.systemTemp.createTempSync('session_download');
      addTearDown(() => dir.deleteSync(recursive: true));

      await expectLater(
        api.download('/scans/1/file', File('${dir.path}/scan.jpg')),
        throwsA(isA<ApiException>()),
      );

      expect(seen.headers['Cookie'], 'metaframes_session=abc123');
      expect(session.signedIn, isFalse);
    });

    test('a Google ID token is posted and starts the session', () async {
      final session = SessionStore();
      late http.Request seen;
      final api = _client(session, (request) async {
        seen = request;
        return _json({'message': 'ok'}, headers: {'set-cookie': _setSession});
      });

      await AuthRepositoryRemote(api).loginWithGoogle('id-token');

      expect(seen.url.path, '/auth/google/token');
      expect(jsonDecode(seen.body), {'idToken': 'id-token'});
      expect(session.token, 'abc123');
    });

    test('the web client id comes from the server', () async {
      late http.Request seen;
      final api = _client(SessionStore(), (request) async {
        seen = request;
        return _json({'serverClientId': 'web-client'});
      });

      final clientId = await AuthRepositoryRemote(api).googleServerClientId();

      expect(clientId, 'web-client');
      expect(seen.url.path, '/auth/google/config');
    });

    test('sessionHeaders follows the token', () async {
      final session = SessionStore();
      final api = _client(session, (_) async => _json({}));
      expect(api.sessionHeaders, isEmpty);

      await session.setToken('abc123');

      expect(api.sessionHeaders, {'Cookie': 'metaframes_session=abc123'});
    });
  });

  group('failure logs', () {
    late List<String> logged;
    late DebugPrintCallback original;

    setUp(() {
      logged = [];
      original = debugPrint;
      debugPrint = (message, {wrapWidth}) => logged.add(message ?? '');
    });
    tearDown(() => debugPrint = original);

    test('hide the password and the session token', () async {
      final session = SessionStore('tokenvalue');
      final api = _client(
        session,
        (_) async => _json({'message': 'no'}, status: 400),
      );

      await expectLater(
        AuthRepositoryRemote(api)
            .login(email: 'a@b.co', password: 'hunter2!Aa'),
        throwsA(isA<ApiException>()),
      );

      final log = logged.join('\n');
      expect(log, contains('/auth/login'));
      expect(log, isNot(contains('hunter2!Aa')));
      expect(log, isNot(contains('tokenvalue')));
    });
  });
}
