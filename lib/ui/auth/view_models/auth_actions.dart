import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/services/api_client.dart';
import '../../../providers.dart';

/// Account actions for the auth screens. A change of session moves the user
/// between the login screen and the app (see `authRedirect`), so no action
/// navigates.
class AuthActions {
  AuthActions(this._ref);
  final Ref _ref;

  Future<void> login({required String email, required String password}) => _ref
      .read(authRepositoryProvider)
      .login(email: email.trim(), password: password);

  bool get googleAvailable => _ref.read(googleIdTokenSourceProvider).available;

  /// Does nothing if the user closes Google's account picker.
  Future<void> signInWithGoogle() async {
    final auth = _ref.read(authRepositoryProvider);
    final idToken = await _ref
        .read(googleIdTokenSourceProvider)
        .idToken(serverClientId: await auth.googleServerClientId());
    if (idToken == null) return;
    await auth.loginWithGoogle(idToken);
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) => _ref
      .read(authRepositoryProvider)
      .register(email: email.trim(), password: password, name: name.trim());

  Future<String> recover(String email) =>
      _ref.read(authRepositoryProvider).recover(email.trim());

  /// Ends the session on this device even if the server cannot be reached.
  /// What this phone keeps for the account (unsynced changes, drafts, saved
  /// reads) stays, to sync when the same account signs in on the same server,
  /// unless [discardKept] (the user's explicit choice).
  Future<void> logout({bool discardKept = false}) async {
    final kept = _ref.read(localStoreProvider)?.key;
    if (discardKept && kept != null) {
      await _ref.read(partitionControllerProvider).discard(kept);
    }
    try {
      await _ref.read(authRepositoryProvider).logout();
    } on ApiException {
      // The server keeps its session row until it expires, but no client holds
      // the token any more.
    } finally {
      await _ref.read(sessionStoreProvider).setToken(null);
    }
    await _ref.read(googleIdTokenSourceProvider).signOut();
  }
}

final authActionsProvider = Provider<AuthActions>(AuthActions.new);
