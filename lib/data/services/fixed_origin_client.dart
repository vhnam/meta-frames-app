import 'package:http/http.dart' as http;

/// A request this build refused to make, or a redirect it refused to follow.
class BlockedRequest extends http.ClientException {
  BlockedRequest(Uri url) : super('Blocked request', url);
}

/// Keeps every request on one origin, so a session cookie, a password or a
/// Google ID token cannot reach another scheme, host or port. The API serves
/// its endpoints directly, so any redirect counts as a failed request.
class FixedOriginClient extends http.BaseClient {
  FixedOriginClient(String origin, [http.Client? inner])
    : _origin = Uri.parse(origin),
      _inner = inner ?? http.Client();

  final Uri _origin;
  final http.Client _inner;

  bool _allows(Uri url) =>
      url.scheme == _origin.scheme &&
      url.host == _origin.host &&
      url.port == _origin.port;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (!_allows(request.url)) throw BlockedRequest(request.url);
    request.followRedirects = false;
    final response = await _inner.send(request);
    if (response.statusCode >= 300 && response.statusCode < 400) {
      await response.stream.listen(null).cancel();
      throw BlockedRequest(request.url);
    }
    return response;
  }

  @override
  void close() => _inner.close();
}
