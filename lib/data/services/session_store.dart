import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The account a session token was verified for: the server it was issued by
/// and the user `/auth/me` answered with for that very token. Data kept on the
/// device is filed under this pair, so it is never shown to, or sent as,
/// another account or another server.
@immutable
class SessionBinding {
  const SessionBinding({
    required this.server,
    required this.userId,
    required this.email,
    this.name,
  });

  SessionBinding.fromJson(Map<String, dynamic> j)
    : server = j['server'],
      userId = j['userId'],
      email = j['email'],
      name = j['name'];

  /// Normalised base URL (see `normalizeBaseUrl`).
  final String server;
  final String userId, email;
  final String? name;

  Map<String, Object?> toJson() => {
    'server': server,
    'userId': userId,
    'email': email,
    'name': name,
  };

  @override
  bool operator ==(Object other) =>
      other is SessionBinding &&
      other.server == server &&
      other.userId == userId;

  @override
  int get hashCode => Object.hash(server, userId);
}

/// Holds the server's session token, the value of its session cookie, and the
/// [binding] verified for that token. Listeners run when the user signs in,
/// the binding is verified, or the session ends.
///
/// [generation] moves on every change of token or binding. A request records
/// it when it starts; an answer that comes back under another generation
/// belongs to an earlier session and must not be stored or acted on.
class SessionStore extends ChangeNotifier {
  SessionStore([this._token, this._binding]);

  String? _token;
  SessionBinding? _binding;
  int _generation = 0;

  String? get token => _token;
  bool get signedIn => _token != null;

  /// Null until `/auth/me` has answered for the current token.
  SessionBinding? get binding => _binding;
  int get generation => _generation;

  /// A new token, or none, drops the binding: a new token has no account until
  /// `/auth/me` answers for it, so an older account is never paired with it.
  Future<void> setToken(String? token) async {
    if (token == _token) return;
    _token = token;
    _binding = null;
    _generation++;
    notifyListeners();
    await _save(token, null);
  }

  /// Records that [binding] is the account of [forToken]. Does nothing when
  /// the token has changed since `/auth/me` was asked, so a slow answer cannot
  /// bind a newer session. Returns whether it bound.
  Future<bool> bind(SessionBinding binding, {required String forToken}) async {
    if (_token == null || _token != forToken) return false;
    if (_binding == binding) return true;
    _binding = binding;
    _generation++;
    notifyListeners();
    await _save(_token, binding);
    return true;
  }

  Future<void> _saved = Future.value();

  /// Runs [persist] after every earlier save has finished, so storage ends up
  /// holding the newest state: a slow write for an earlier token or binding
  /// cannot land after, and undo, a later sign-out.
  Future<void> _save(String? token, SessionBinding? binding) {
    final run = _saved.then((_) => persist(token, binding));
    _saved = run.catchError((Object _) {});
    return run;
  }

  @protected
  Future<void> persist(String? token, SessionBinding? binding) async {}
}

/// Keeps the token and its binding in the iOS Keychain or the Android
/// Keystore, so a session, and offline access to its data, survive restarts.
/// The binding is stored with a fingerprint of its token and is ignored on
/// load if it does not match, so a token and an account from different
/// sessions are never paired. If storage fails, the session lasts until the
/// app closes.
class SecureSessionStore extends SessionStore {
  SecureSessionStore._(super.token, super.binding, this._storage);

  static const _tokenKey = 'session_token';
  static const _bindingKey = 'session_binding';

  final FlutterSecureStorage _storage;

  static Future<SecureSessionStore> load() async {
    const storage = FlutterSecureStorage();
    String? token;
    SessionBinding? binding;
    try {
      token = await storage.read(key: _tokenKey);
      final raw = await storage.read(key: _bindingKey);
      binding = token == null ? null : bindingFor(token, raw);
    } on Exception catch (error) {
      debugPrint('Cannot read the saved session: $error');
    }
    return SecureSessionStore._(token, binding, storage);
  }

  @override
  Future<void> persist(String? token, SessionBinding? binding) async {
    try {
      // The binding goes first and comes back last, so a crash in between
      // leaves a token without a binding, never the other way round.
      if (binding == null) await _storage.delete(key: _bindingKey);
      if (token == null) {
        await _storage.delete(key: _tokenKey);
      } else {
        await _storage.write(key: _tokenKey, value: token);
      }
      if (token != null && binding != null) {
        await _storage.write(
          key: _bindingKey,
          value: storedBinding(token, binding),
        );
      }
    } on Exception catch (error) {
      debugPrint('Cannot save the session: $error');
    }
  }
}

/// The stored form of [binding]: its fields and its token's fingerprint.
String storedBinding(String token, SessionBinding binding) =>
    jsonEncode({...binding.toJson(), 'token': tokenFingerprint(token)});

/// The binding in [raw] if it was stored for [token], otherwise null.
SessionBinding? bindingFor(String token, String? raw) {
  if (raw == null) return null;
  try {
    final j = jsonDecode(raw) as Map<String, dynamic>;
    if (j['token'] != tokenFingerprint(token)) return null;
    return SessionBinding.fromJson(j);
  } on Object {
    return null;
  }
}

/// A short, stable fingerprint (FNV-1a, 64 bits) so the token itself is not
/// stored twice.
String tokenFingerprint(String token) => fnv64(token);

/// FNV-1a over the UTF-8 bytes of [text], as 16 hex digits.
String fnv64(String text) {
  var hash = BigInt.parse('cbf29ce484222325', radix: 16);
  final prime = BigInt.parse('100000001b3', radix: 16);
  final mask = (BigInt.one << 64) - BigInt.one;
  for (final b in utf8.encode(text)) {
    hash = ((hash ^ BigInt.from(b)) * prime) & mask;
  }
  return hash.toRadixString(16).padLeft(16, '0');
}
