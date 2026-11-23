import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:material_ui/material_ui.dart' show MaterialApp, RawImage;
import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:meta_frames/data/services/api_client.dart';
import 'package:meta_frames/data/services/fixed_origin_client.dart';
import 'package:meta_frames/data/services/server_policy.dart';
import 'package:meta_frames/data/services/session_image.dart';
import 'package:meta_frames/data/services/session_store.dart';
import 'package:meta_frames/providers.dart';
import 'package:meta_frames/ui/scans/widgets/zoomable_scan.dart';

const _origin = 'https://api.example.com';
const _elsewhere = 'https://evil.example.net/steal';

/// One transparent pixel.
final _pixel = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGNgYGBgAAAABQAB'
  'pfZFQAAAAABJRU5ErkJggg==',
);

/// Records what reaches the network. Answers every request with [status], and
/// follows a redirect the way the platform does when a request allows it.
class _Network extends http.BaseClient {
  _Network(this.status);
  final int status;
  final seen = <http.BaseRequest>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    seen.add(request);
    if (request.followRedirects && status >= 300 && status < 400) {
      seen.add(
        http.Request(request.method, Uri.parse(_elsewhere))
          ..headers.addAll(request.headers),
      );
    }
    return http.StreamedResponse(
      Stream.value(_pixel),
      status,
      headers: {'location': _elsewhere},
    );
  }
}

/// What resolving [image] ends in: an error, or null for a decoded image.
Future<Object?> _resolve(
  ImageProvider image, {
  void Function(int width, int height)? onSize,
}) async {
  final done = Completer<Object?>();
  final stream = image.resolve(ImageConfiguration.empty);
  final listener = ImageStreamListener(
    (info, _) {
      onSize?.call(info.image.width, info.image.height);
      info.dispose();
      if (!done.isCompleted) done.complete(null);
    },
    onError: (error, _) {
      if (!done.isCompleted) done.complete(error);
    },
  );
  stream.addListener(listener);
  try {
    return await done.future;
  } finally {
    stream.removeListener(listener);
  }
}

void main() {
  group('FixedOriginClient', () {
    final others = [
      'http://api.example.com/auth/me',
      'https://other.example.com/auth/me',
      'https://api.example.com:8443/auth/me',
    ];
    for (final url in others) {
      test('sends nothing to $url', () async {
        final network = _Network(200);
        final client = FixedOriginClient(_origin, network);

        await expectLater(
          client.get(Uri.parse(url)),
          throwsA(isA<BlockedRequest>()),
        );
        expect(network.seen, isEmpty);
      });
    }

    test('the default HTTPS port is the same origin', () async {
      final network = _Network(200);
      final client = FixedOriginClient(_origin, network);

      final response = await client.get(
        Uri.parse('https://api.example.com:443/auth/me'),
      );

      expect(response.statusCode, 200);
    });

    for (final status in [300, 301, 302, 303, 304, 307, 308]) {
      test('$status is a failed request and is not followed', () async {
        final network = _Network(status);
        final client = FixedOriginClient(_origin, network);

        await expectLater(
          client.get(Uri.parse('$_origin/auth/me')),
          throwsA(isA<BlockedRequest>()),
        );
        expect(network.seen.single.url.host, 'api.example.com');
        expect(network.seen.single.followRedirects, isFalse);
      });
    }
  });

  group('a cross-origin redirect', () {
    late _Network network;
    late SessionStore session;
    late ApiClient api;

    setUp(() {
      network = _Network(302);
      session = SessionStore('secret-token');
      api = ApiClient(
        () => _origin,
        FixedOriginClient(_origin, network),
        session,
      );
    });

    final credentials = {
      '/auth/login': {'email': 'a@example.com', 'password': 'hunter2'},
      '/auth/google': {'idToken': 'google-id-token'},
    };
    credentials.forEach((path, body) {
      test('keeps the credentials of $path on the origin', () async {
        await expectLater(
          api.send('POST', path, body: body),
          throwsA(
            isA<ApiException>().having(
              (error) => error.isNetwork,
              'network',
              isTrue,
            ),
          ),
        );

        expect(network.seen, hasLength(1));
        expect(network.seen.single.url.origin, _origin);
      });
    });

    test('does not end the session', () async {
      await expectLater(api.send('GET', '/auth/me'), throwsA(anything));
      expect(session.token, 'secret-token');
    });

    test('on a download is an API error and writes no file', () async {
      final dir = await Directory.systemTemp.createTemp('mf_redirect');
      addTearDown(() => dir.delete(recursive: true));
      final dest = File('${dir.path}/scan.jpg');

      await expectLater(
        api.download('/scans/1/file', dest),
        throwsA(isA<ApiException>()),
      );

      expect(dest.existsSync(), isFalse);
      expect(network.seen, hasLength(1));
      expect(network.seen.single.url.origin, _origin);
    });

    testWidgets('on a scan image fails and is not cached', (tester) async {
      final image = SessionImage(
        '$_origin/scans/1/file',
        client: FixedOriginClient(_origin, network),
        headers: api.sessionHeaders,
      );
      addTearDown(imageCache.clear);

      await tester.runAsync(() async {
        expect(await _resolve(image), isA<BlockedRequest>());
        await Future<void>.delayed(Duration.zero);
        expect(network.seen, hasLength(1));
        expect(network.seen.single.url.origin, _origin);

        await _resolve(image);
        expect(network.seen, hasLength(2));
      });
    });
  });

  group('SessionImage', () {
    testWidgets('a resized scan is cached only for its authorized session', (
      tester,
    ) async {
      final scan = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAQAAAACCAIAAADwyuo0AAAAEElEQVR4nGP4xcAARwzI'
        'HABtegfReN69CAAAAABJRU5ErkJggg==',
      );
      final cookies = <String?>[];
      final network = MockClient((request) async {
        final cookie = request.headers['Cookie'];
        cookies.add(cookie);
        return cookie?.endsWith('=first-account') == true
            ? http.Response.bytes(scan, 200)
            : http.Response('', 403);
      });
      final client = FixedOriginClient(_origin, network);
      final session = SessionStore('first-account');
      final api = ApiClient(() => _origin, client, session);
      ImageProvider thumbnail() => ResizeImage.resizeIfNeeded(
        2,
        null,
        SessionImage(
          '$_origin/scans/private/file',
          client: client,
          headers: api.sessionHeaders,
        ),
      );
      addTearDown(imageCache.clear);

      await tester.runAsync(() async {
        (int, int)? decoded;
        expect(
          await _resolve(
            thumbnail(),
            onSize: (width, height) => decoded = (width, height),
          ),
          isNull,
        );
        expect(decoded, (2, 1));
        expect(await _resolve(thumbnail()), isNull);
        expect(cookies, hasLength(1));
      });

      await session.setToken('second-account');
      await tester.runAsync(() async {
        final result = await _resolve(thumbnail());
        expect(cookies, hasLength(2));
        expect(cookies.last, endsWith('=second-account'));
        expect(
          result,
          isA<NetworkImageLoadException>().having(
            (error) => error.statusCode,
            'status',
            403,
          ),
        );
      });
    });

    testWidgets('sends the session it is cached under', (tester) async {
      final network = _Network(200);
      final session = SessionStore('first');
      final api = ApiClient(() => _origin, network, session);
      final image = SessionImage(
        '$_origin/scans/2/file',
        client: network,
        headers: api.sessionHeaders,
      );
      addTearDown(imageCache.clear);
      await session.setToken('second');

      await tester.runAsync(() async {
        expect(await _resolve(image), isNull);
      });

      expect(network.seen.single.headers['Cookie'], endsWith('=first'));
    });

    testWidgets('reports progress for a loading builder', (tester) async {
      final image = SessionImage(
        '$_origin/scans/4/file',
        client: _Network(200),
        headers: const {},
      );
      addTearDown(imageCache.clear);
      final progress = <int>[];

      await tester.runAsync(() async {
        final done = Completer<void>();
        image
            .resolve(ImageConfiguration.empty)
            .addListener(
              ImageStreamListener(
                (_, _) => done.complete(),
                onChunk: (event) => progress.add(event.cumulativeBytesLoaded),
              ),
            );
        await done.future;
      });

      expect(progress, [_pixel.length]);
    });

    testWidgets('a refused status is an error', (tester) async {
      final network = _Network(401);
      final image = SessionImage(
        '$_origin/scans/3/file',
        client: network,
        headers: const {},
      );
      addTearDown(imageCache.clear);

      await tester.runAsync(() async {
        expect(await _resolve(image), isA<NetworkImageLoadException>());
      });
    });
  });

  test('a session change gives scan images the new session', () async {
    final session = SessionStore('first');
    final api = ApiClient(() => _origin, _Network(200), session);
    final container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(api),
        sessionStoreProvider.overrideWithValue(session),
      ],
    );
    addTearDown(container.dispose);
    final images = container.listen(scanImageProvider, (_, _) {});
    final before = images.read()('$_origin/scans/1/file');

    await session.setToken('second');
    final after = container.read(scanImageProvider)('$_origin/scans/1/file');

    expect(after, isNot(before));
    expect(after.headers['Cookie'], endsWith('=second'));
  });

  testWidgets('a mounted scan clears old pixels while a new session loads', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    addTearDown(tester.view.reset);
    addTearDown(imageCache.clear);
    const url = '$_origin/scans/mounted/file';
    final nextResponse = Completer<http.Response>();
    final cookies = <String?>[];
    final client = FixedOriginClient(
      _origin,
      MockClient((request) async {
        final cookie = request.headers['Cookie'];
        cookies.add(cookie);
        if (cookie?.endsWith('=first') == true) {
          return http.Response.bytes(_pixel, 200);
        }
        return nextResponse.future;
      }),
    );
    final session = SessionStore('first');
    final container = ProviderContainer(
      overrides: [
        httpClientProvider.overrideWithValue(client),
        apiClientProvider.overrideWithValue(
          ApiClient(() => _origin, client, session),
        ),
        sessionStoreProvider.overrideWithValue(session),
      ],
    );
    addTearDown(container.dispose);
    final initial = container.read(scanImageProvider)(url);
    await tester.runAsync(() async {
      expect(
        await _resolve(ResizeImage.resizeIfNeeded(320, null, initial)),
        isNull,
      );
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ZoomableScan(url: url)),
      ),
    );
    await tester.pump();
    expect(tester.widget<RawImage>(find.byType(RawImage)).image, isNotNull);
    expect(cookies, hasLength(1));

    await session.setToken('second');
    await tester.pump();
    final pendingImages = tester.widgetList<RawImage>(find.byType(RawImage));
    final retainedOldPixels = pendingImages.any((image) => image.image != null);
    nextResponse.complete(http.Response('', 403));
    await tester.pumpAndSettle();

    expect(cookies.last, endsWith('=second'));
    expect(cookies, hasLength(2));
    expect(retainedOldPixels, isFalse);
  });

  testWidgets(
    'a binding update keeps the frame during a resize for one token',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 640);
      addTearDown(tester.view.reset);
      addTearDown(imageCache.clear);
      const url = '$_origin/scans/resizing/file';
      final resizedResponse = Completer<http.Response>();
      var requests = 0;
      final client = FixedOriginClient(
        _origin,
        MockClient((_) async {
          requests++;
          if (requests == 1) return http.Response.bytes(_pixel, 200);
          return resizedResponse.future;
        }),
      );
      final session = SessionStore('current-token');
      final container = ProviderContainer(
        overrides: [
          httpClientProvider.overrideWithValue(client),
          apiClientProvider.overrideWithValue(
            ApiClient(() => _origin, client, session),
          ),
          sessionStoreProvider.overrideWithValue(session),
        ],
      );
      addTearDown(container.dispose);
      final initial = container.read(scanImageProvider)(url);
      await tester.runAsync(() async {
        expect(
          await _resolve(ResizeImage.resizeIfNeeded(320, null, initial)),
          isNull,
        );
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: ZoomableScan(url: url)),
        ),
      );
      await tester.pump();
      bool hasFrame() => tester
          .widgetList<RawImage>(find.byType(RawImage))
          .any((image) => image.image != null);
      expect(hasFrame(), isTrue);

      tester.view.physicalSize = const Size(480, 640);
      await tester.pump();
      final heldDuringResize = hasFrame();
      final bound = await session.bind(
        const SessionBinding(
          server: _origin,
          userId: 'same-user',
          email: 'same@example.com',
        ),
        forToken: 'current-token',
      );
      await tester.pump();
      final heldAfterBinding = hasFrame();
      resizedResponse.complete(http.Response('', 403));
      await tester.pumpAndSettle();

      expect(requests, 2);
      expect(bound, isTrue);
      expect(session.token, 'current-token');
      expect(heldDuringResize, isTrue);
      expect(heldAfterBinding, isTrue);
    },
  );

  group('httpClientProvider', () {
    http.Client clientUnder(ServerPolicy policy) {
      final container = ProviderContainer(
        overrides: [serverPolicyProvider.overrideWithValue(policy)],
      );
      addTearDown(container.dispose);
      return container.read(httpClientProvider);
    }

    test('a fixed build stays on its origin', () {
      expect(clientUnder(const FixedServer(_origin)), isA<FixedOriginClient>());
    });

    test('a debug build keeps the plain client', () {
      expect(
        clientUnder(const DebugServers()),
        isNot(isA<FixedOriginClient>()),
      );
    });
  });
}
