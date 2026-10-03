import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:meta_frames/data/services/api_client.dart';

ApiClient clientFor(
  Future<http.Response> Function(http.Request) handler, {
  String base = 'http://srv:8080',
}) => ApiClient(() => base, MockClient(handler));

http.Response json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  group('requests', () {
    test('sends method, path, headers and a JSON body', () async {
      late http.Request seen;
      final api = clientFor((r) async {
        seen = r;
        return json({'ok': true});
      });

      final res = await api.send('PUT', '/cameras/1', body: {'a': 1});

      expect(res, {'ok': true});
      expect(seen.method, 'PUT');
      expect(seen.url.toString(), 'http://srv:8080/cameras/1');
      expect(seen.headers['X-Actor'], 'mobile');
      expect(seen.headers['Accept'], 'application/json');
      expect(jsonDecode(seen.body), {'a': 1});
    });

    test('drops null and empty query values', () async {
      late Uri seen;
      final api = clientFor((r) async {
        seen = r.url;
        return json([]);
      });

      await api.send('GET', '/rolls', query: {'a': '1', 'b': null, 'c': ''});

      expect(seen.queryParameters, {'a': '1'});
    });

    test('reads the base URL on every request', () async {
      var base = 'http://one';
      final urls = <String>[];
      final api = ApiClient(
        () => base,
        MockClient((r) async {
          urls.add(r.url.host);
          return json({});
        }),
      );

      await api.send('GET', '/x');
      base = 'http://two';
      await api.send('GET', '/x');

      expect(urls, ['one', 'two']);
    });

    test('builds absolute URLs for server paths', () {
      expect(
        clientFor((_) async => json({})).absolute('/scans/1/file'),
        'http://srv:8080/scans/1/file',
      );
    });

    test('an empty success body decodes to null', () async {
      final api = clientFor((_) async => http.Response('', 204));
      expect(await api.send('DELETE', '/cameras/1'), isNull);
    });

    test('decodes UTF-8 bodies', () async {
      final api = clientFor(
        (_) async => http.Response.bytes(
          utf8.encode(jsonEncode({'name': 'Nikon Zf — 50mm'})),
          200,
        ),
      );
      expect((await api.send('GET', '/x'))['name'], 'Nikon Zf — 50mm');
    });
  });

  group('errors', () {
    test('maps the server error body to ApiException', () async {
      final api = clientFor(
        (_) async => json({'code': 'conflict', 'message': 'Has rolls'}, 409),
      );

      await expectLater(
        api.send('DELETE', '/cameras/1'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.status, 'status', 409)
              .having((e) => e.code, 'code', 'conflict')
              .having((e) => e.message, 'message', 'Has rolls')
              .having((e) => e.isNetwork, 'isNetwork', isFalse),
        ),
      );
    });

    test(
      'falls back to a generic message when the error body is not JSON',
      () async {
        final api = clientFor((_) async => http.Response('<html>', 502));

        await expectLater(
          api.send('GET', '/x'),
          throwsA(
            isA<ApiException>()
                .having((e) => e.status, 'status', 502)
                .having((e) => e.code, 'code', 'error')
                .having((e) => e.message, 'message', 'Request failed (502)'),
          ),
        );
      },
    );

    test('an unreachable server is a network error naming the URL', () async {
      final api = clientFor((_) async => throw const SocketException('down'));

      await expectLater(
        api.send('GET', '/x'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.isNetwork, 'isNetwork', isTrue)
              .having(
                (e) => e.message,
                'message',
                'Cannot reach the server at http://srv:8080.',
              ),
        ),
      );
    });

    test('an ApiException prints its message', () {
      expect(ApiException(500, 'error', 'Boom').toString(), 'Boom');
    });
  });

  group('upload', () {
    late File file;

    setUp(() async {
      final dir = await Directory.systemTemp.createTemp('api_client_test');
      addTearDown(() => dir.delete(recursive: true));
      file = File('${dir.path}/scan.jpg')..writeAsBytesSync([1, 2, 3]);
    });

    test('posts a multipart form with the fields and the file', () async {
      late http.Request seen;
      final api = clientFor((r) async {
        seen = r;
        return json({'imported': []});
      });

      await api.upload(
        '/processing/p1/scans',
        fields: {'scanner': 'noritsu', 'frameNumber': '3'},
        fileField: 'file',
        filePath: file.path,
        fileName: 'frame3.jpg',
      );

      expect(seen.method, 'POST');
      expect(seen.url.path, '/processing/p1/scans');
      expect(seen.headers['content-type'], startsWith('multipart/form-data'));
      expect(seen.headers['X-Actor'], 'mobile');
      expect(seen.body, contains('name="scanner"'));
      expect(seen.body, contains('noritsu'));
      expect(seen.body, contains('filename="frame3.jpg"'));
    });

    test('a failed upload says so in the network error', () async {
      final api = clientFor((_) async => throw const SocketException('down'));

      await expectLater(
        api.upload(
          '/x',
          fields: {},
          fileField: 'file',
          filePath: file.path,
          fileName: 'a.jpg',
        ),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            'Cannot reach the server at http://srv:8080. Upload failed.',
          ),
        ),
      );
    });
  });

  group('download', () {
    late Directory dir;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('api_client_download');
      addTearDown(() => dir.delete(recursive: true));
    });

    test('streams the body to the file', () async {
      final api = ApiClient(
        () => 'http://srv',
        MockClient.streaming(
          (r, _) async => http.StreamedResponse(
            Stream.fromIterable([
              [1, 2],
              [3, 4],
            ]),
            200,
          ),
        ),
      );
      final dest = File('${dir.path}/out.jpg');

      await api.download('/scans/1/file', dest);

      expect(dest.readAsBytesSync(), [1, 2, 3, 4]);
    });

    test('a non-200 response throws and leaves no file', () async {
      final api = ApiClient(
        () => 'http://srv',
        MockClient.streaming(
          (r, _) async => http.StreamedResponse(const Stream.empty(), 404),
        ),
      );
      final dest = File('${dir.path}/out.jpg');

      await expectLater(
        api.download('/scans/1/file', dest),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 404)),
      );
      expect(dest.existsSync(), isFalse);
    });

    test('a stream that fails midway deletes the partial file', () async {
      final api = ApiClient(
        () => 'http://srv',
        MockClient.streaming((r, _) async {
          Stream<List<int>> body() async* {
            yield [1, 2];
            throw const SocketException('cut');
          }

          return http.StreamedResponse(body(), 200);
        }),
      );
      final dest = File('${dir.path}/out.jpg');

      await expectLater(
        api.download('/scans/1/file', dest),
        throwsA(isA<SocketException>()),
      );
      expect(dest.existsSync(), isFalse);
    });
  });

  test('decodeList maps every element', () {
    expect(
      decodeList<int>([
        {'n': 1},
        {'n': 2},
      ], (m) => m['n'] as int),
      [1, 2],
    );
  });
}
