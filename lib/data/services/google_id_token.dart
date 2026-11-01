import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'api_client.dart';

/// Gets a Google ID token from the device's account picker, for the server to
/// verify.
abstract class GoogleIdTokenSource {
  /// False on an iOS build without its client id: the app hides Google sign-in.
  bool get available;

  /// An ID token for [serverClientId], the server's web client, or null if the
  /// user closed the picker. Throws an
  /// [ApiException] if Google sign-in fails.
  Future<String?> idToken({required String serverClientId});

  /// Forgets the chosen account, so the next sign-in shows the picker again.
  Future<void> signOut();
}

/// The iOS client id comes from `google_sign_in.json` through
/// `--dart-define-from-file`. See "Sign in with Google" in the README.
class NativeGoogleIdTokenSource implements GoogleIdTokenSource {
  static const _iosClientId = String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');

  Future<void>? _initialized;
  String? _initializedFor;

  /// `initialize` may run only once per app launch, so a server with another
  /// web client needs a restart.
  Future<void> _initialize(String serverClientId) {
    if (_initializedFor != null && _initializedFor != serverClientId) {
      throw ApiException(
        400,
        'google_failed',
        'Restart the app to use Google sign-in with this server.',
      );
    }
    _initializedFor = serverClientId;
    return _initialized ??= GoogleSignIn.instance.initialize(
      clientId: _isIos ? _iosClientId : null,
      serverClientId: serverClientId,
    );
  }

  bool get _isIos => defaultTargetPlatform == TargetPlatform.iOS;

  @override
  bool get available => !_isIos || _iosClientId.isNotEmpty;

  @override
  Future<String?> idToken({required String serverClientId}) async {
    try {
      await _initialize(serverClientId);
      final account = await GoogleSignIn.instance.authenticate();
      final token = account.authentication.idToken;
      if (token == null) throw _failure('Google returned no ID token.');
      return token;
    } on GoogleSignInException catch (error) {
      // On Android, a wrong package name or SHA-1 also reports `canceled`.
      debugPrint('Google sign-in: ${error.code} ${error.description}');
      if (error.code == GoogleSignInExceptionCode.canceled ||
          error.code == GoogleSignInExceptionCode.interrupted) {
        return null;
      }
      throw _failure(error.description);
    }
  }

  ApiException _failure(String? reason) {
    debugPrint('Google sign-in failed: $reason');
    return ApiException(
      400,
      'google_failed',
      'Sign-in with Google failed. Try again.',
    );
  }

  @override
  Future<void> signOut() async {
    final initialized = _initialized;
    if (initialized == null) return; // nothing chosen since this launch
    try {
      await initialized;
      await GoogleSignIn.instance.signOut();
    } on Exception catch (error) {
      debugPrint('Google sign-out failed: $error');
    }
  }
}
