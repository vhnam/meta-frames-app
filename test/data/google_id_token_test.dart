import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:meta_frames/data/services/api_client.dart';
import 'package:meta_frames/data/services/google_id_token.dart';

/// The device side of Google sign-in: answers `authenticate` with [result] or
/// throws [failure], and records how it was started.
class _FakeGooglePlatform extends GoogleSignInPlatform {
  AuthenticationResults? result;
  Object? failure;
  final inits = <InitParameters>[];
  var signOuts = 0;

  @override
  Future<void> init(InitParameters params) async => inits.add(params);

  @override
  Future<AuthenticationResults> authenticate(
    AuthenticateParameters params,
  ) async {
    if (failure != null) throw failure!;
    return result!;
  }

  @override
  Future<void> signOut(SignOutParams params) async => signOuts++;

  @override
  Future<AuthenticationResults?>? attemptLightweightAuthentication(
    AttemptLightweightAuthenticationParameters params,
  ) => null;

  @override
  bool supportsAuthenticate() => true;

  @override
  bool authorizationRequiresUserInteraction() => false;

  @override
  Future<ClientAuthorizationTokenData?> clientAuthorizationTokensForScopes(
    ClientAuthorizationTokensForScopesParameters params,
  ) async => null;

  @override
  Future<ServerAuthorizationTokenData?> serverAuthorizationTokensForScopes(
    ServerAuthorizationTokensForScopesParameters params,
  ) async => null;

  @override
  Future<void> disconnect(DisconnectParams params) async {}
}

AuthenticationResults _signedIn(String? idToken) => AuthenticationResults(
  user: const GoogleSignInUserData(email: 'ansel@example.com', id: 'g-1'),
  authenticationTokens: AuthenticationTokenData(idToken: idToken),
);

GoogleSignInException _error(GoogleSignInExceptionCode code) =>
    GoogleSignInException(code: code, description: 'test');

void main() {
  late _FakeGooglePlatform platform;
  late NativeGoogleIdTokenSource source;

  setUp(() {
    platform = _FakeGooglePlatform();
    GoogleSignInPlatform.instance = platform;
    source = NativeGoogleIdTokenSource();
  });

  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('returns the ID token and names the server web client', () async {
    platform.result = _signedIn('id-token');
    expect(await source.idToken(serverClientId: 'web-client'), 'id-token');
    expect(platform.inits.single.serverClientId, 'web-client');
  });

  test('closing the picker is not an error', () async {
    for (final code in [
      GoogleSignInExceptionCode.canceled,
      GoogleSignInExceptionCode.interrupted,
    ]) {
      platform.failure = _error(code);
      expect(await source.idToken(serverClientId: 'web-client'), isNull);
    }
  });

  test('any other Google failure is a failed sign-in', () async {
    platform.failure = _error(
      GoogleSignInExceptionCode.clientConfigurationError,
    );
    await expectLater(
      source.idToken(serverClientId: 'web-client'),
      throwsA(
        isA<ApiException>()
            .having((error) => error.code, 'code', 'google_failed')
            .having((error) => error.status, 'status', 400),
      ),
    );
  });

  test('an account without an ID token is a failed sign-in', () async {
    platform.result = _signedIn(null);
    await expectLater(
      source.idToken(serverClientId: 'web-client'),
      throwsA(
        isA<ApiException>().having(
          (error) => error.code,
          'code',
          'google_failed',
        ),
      ),
    );
  });

  test('initializes once, and another web client needs a restart', () async {
    platform.result = _signedIn('id-token');
    await source.idToken(serverClientId: 'web-client');
    await source.idToken(serverClientId: 'web-client');
    expect(platform.inits, hasLength(1));

    await expectLater(
      source.idToken(serverClientId: 'other-web-client'),
      throwsA(
        isA<ApiException>().having(
          (error) => error.message,
          'message',
          contains('Restart the app'),
        ),
      ),
    );
    expect(platform.inits, hasLength(1));
  });

  test('signing out before any sign-in does not touch Google', () async {
    await source.signOut();
    expect(platform.signOuts, 0);
  });

  test('signing out after a sign-in forgets the account', () async {
    platform.result = _signedIn('id-token');
    await source.idToken(serverClientId: 'web-client');
    await source.signOut();
    expect(platform.signOuts, 1);
  });

  test('iOS without a client id hides Google sign-in, Android keeps it', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(source.available, isFalse);
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(source.available, isTrue);
  });
}
