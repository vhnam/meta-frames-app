import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:http/http.dart' as http;

/// A scan file, loaded with the session through the app's HTTP [client], so
/// images follow the same origin rules as every other request. Cached by [url]
/// and [headers] together: one session never receives what another loaded.
@immutable
class SessionImage extends ImageProvider<SessionImage> {
  const SessionImage(this.url, {required this.client, required this.headers});

  final String url;
  final http.Client client;

  /// The session this image is loaded for and cached under.
  final Map<String, String> headers;

  @override
  Future<SessionImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<SessionImage>(this);

  @override
  ImageStreamCompleter loadImage(
    SessionImage key,
    ImageDecoderCallback decode,
  ) {
    final chunks = StreamController<ImageChunkEvent>();
    return MultiFrameImageStreamCompleter(
      codec: _load(key, decode, chunks),
      chunkEvents: chunks.stream,
      scale: 1,
      debugLabel: key.url,
    );
  }

  Future<ui.Codec> _load(
    SessionImage key,
    ImageDecoderCallback decode,
    StreamController<ImageChunkEvent> chunks,
  ) async {
    final uri = Uri.parse(key.url);
    try {
      final response = await key.client.send(
        http.Request('GET', uri)..headers.addAll(key.headers),
      );
      if (response.statusCode != 200) {
        await response.stream.listen(null).cancel();
        throw NetworkImageLoadException(
          statusCode: response.statusCode,
          uri: uri,
        );
      }
      // Progress is what lets a loading builder show while the file arrives.
      final received = BytesBuilder(copy: false);
      await for (final chunk in response.stream) {
        received.add(chunk);
        chunks.add(
          ImageChunkEvent(
            cumulativeBytesLoaded: received.length,
            expectedTotalBytes: response.contentLength,
          ),
        );
      }
      final bytes = received.takeBytes();
      if (bytes.isEmpty) {
        throw NetworkImageLoadException(statusCode: 200, uri: uri);
      }
      return await decode(await ui.ImmutableBuffer.fromUint8List(bytes));
    } on Object {
      // A failed load is not kept, so the next build tries again.
      scheduleMicrotask(() => PaintingBinding.instance.imageCache.evict(key));
      rethrow;
    } finally {
      unawaited(chunks.close());
    }
  }

  @override
  bool operator ==(Object other) =>
      other is SessionImage &&
      other.url == url &&
      mapEquals(other.headers, headers);

  @override
  int get hashCode => Object.hash(
    url,
    Object.hashAllUnordered(
      headers.entries.map((entry) => Object.hash(entry.key, entry.value)),
    ),
  );
}
