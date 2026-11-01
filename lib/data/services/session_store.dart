import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Holds the server's session token, the value of its session cookie.
/// Listeners run when the user signs in or the session ends.
class SessionStore extends ChangeNotifier {
  SessionStore([this._token]);

  String? _token;
  String? get token => _token;
  bool get signedIn => _token != null;

  Future<void> setToken(String? token) async {
    if (token == _token) return;
    _token = token;
    notifyListeners();
    await persist(token);
  }

  @protected
  Future<void> persist(String? token) async {}
}

/// Keeps the token in the iOS Keychain or the Android Keystore, so a session
/// survives app restarts. If storage fails, the session lasts until the app
/// closes and the user signs in again on the next launch.
class SecureSessionStore extends SessionStore {
  SecureSessionStore._(super.token, this._storage);

  static const _tokenKey = 'session_token';

  final FlutterSecureStorage _storage;

  static Future<SecureSessionStore> load() async {
    const storage = FlutterSecureStorage();
    String? token;
    try {
      token = await storage.read(key: _tokenKey);
    } on Exception catch (error) {
      debugPrint('Cannot read the saved session: $error');
    }
    return SecureSessionStore._(token, storage);
  }

  @override
  Future<void> persist(String? token) async {
    try {
      if (token == null) {
        await _storage.delete(key: _tokenKey);
      } else {
        await _storage.write(key: _tokenKey, value: token);
      }
    } on Exception catch (error) {
      debugPrint('Cannot save the session: $error');
    }
  }
}
