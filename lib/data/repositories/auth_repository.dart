import '../../domain/models/models.dart';

abstract class AuthRepository {
  /// The signed-in user. Throws an `ApiException` with status 401 without a
  /// valid session.
  Future<User> me();

  /// Starts a session. The API client stores the session cookie from the answer.
  Future<void> login({required String email, required String password});

  /// The server's web client id, which Google needs to issue it an ID token.
  Future<String> googleServerClientId();

  /// Starts a session from a Google ID token, creating the account if needed.
  Future<void> loginWithGoogle(String idToken);

  /// Creates an account. Returns `null` when the server started its session
  /// (the API client stores the cookie). Returns the server's message when the
  /// server needs the user to verify the email address first, with no session.
  Future<String?> register({
    required String email,
    required String password,
    String? name,
  });

  Future<void> logout();

  /// Emails a reset link and returns the server's message. The answer is the
  /// same whether or not the account exists.
  Future<String> recover(String email);
}
