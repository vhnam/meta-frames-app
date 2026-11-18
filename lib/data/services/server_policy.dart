import 'package:flutter/foundation.dart';

import '../repositories/settings_repository.dart';

final _ipv6Literal = RegExp(r'^\[[0-9A-Fa-f:.]+\]$');
final _dnsLabel = RegExp(r'^[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?$');
final _digits = RegExp(r'^\d+$');
final _explicitPort = RegExp(r':(\d*)$');

/// Whether [host] is a bracketed IPv6 address (`Uri` has parsed it), an IPv4
/// address, or a DNS name with an optional root dot at its end.
bool _isValidHost(String host) {
  if (host.startsWith('[')) return _ipv6Literal.hasMatch(host);
  final name = host.endsWith('.') ? host.substring(0, host.length - 1) : host;
  if (name.isEmpty || name.length > 253) return false;
  final labels = name.split('.');
  if (!labels.every(_dnsLabel.hasMatch)) return false;
  // A DNS name never ends in an all-numeric label: this is meant as IPv4,
  // and an IPv4 address takes no root dot.
  if (!_digits.hasMatch(labels.last)) return true;
  try {
    Uri.parseIPv4Address(host);
    return true;
  } on FormatException {
    return false;
  }
}

/// [raw] in the form URLs are stored and compared in (see [normalizeBaseUrl]),
/// or null unless it is an absolute HTTPS origin: a host and an optional port
/// in 1-65535, with no credentials, path, query or fragment. Host spelling and
/// an explicit port are kept, because stored URLs compare as exact strings.
String? parseFixedOrigin(String raw) {
  final origin = normalizeBaseUrl(raw);
  const scheme = 'https://';
  if (!origin.toLowerCase().startsWith(scheme)) return null;
  final uri = Uri.tryParse(origin);
  if (uri == null ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.path.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment) {
    return null;
  }
  final authority = origin.substring(scheme.length);
  final port = _explicitPort.firstMatch(authority);
  if (port != null) {
    final number = int.tryParse(port[1]!);
    if (number == null || number < 1 || number > 65535) return null;
  }
  final host = port == null ? authority : authority.substring(0, port.start);
  return _isValidHost(host) ? origin : null;
}

/// Which API server this build may talk to.
sealed class ServerPolicy {
  const ServerPolicy();

  /// The policy of a build in debug mode or not, with [define] as the value of
  /// `API_BASE_URL`. Debug builds ignore [define].
  factory ServerPolicy.resolve({required bool debug, required String define}) {
    if (debug) return const DebugServers();
    final origin = parseFixedOrigin(define);
    return origin == null ? const InvalidServerBuild() : FixedServer(origin);
  }

  /// The policy this build was compiled with.
  factory ServerPolicy.fromBuild() => ServerPolicy.resolve(
    debug: kDebugMode,
    define: const String.fromEnvironment('API_BASE_URL'),
  );
}

/// Debug builds: the user picks the server in Settings.
final class DebugServers extends ServerPolicy {
  const DebugServers();
}

/// Release and profile builds: one server, set when the app is built.
final class FixedServer extends ServerPolicy {
  const FixedServer(this.url);
  final String url;
}

/// A release or profile build without a usable `API_BASE_URL`. The app must
/// not start, and must not fall back to any other server.
final class InvalidServerBuild extends ServerPolicy {
  const InvalidServerBuild();
}
