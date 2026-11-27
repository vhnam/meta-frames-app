import '../../domain/models/models.dart';
import '../services/api_client.dart';
import 'auth_repository.dart';

class AuthRepositoryRemote implements AuthRepository {
  AuthRepositoryRemote(this._api);
  final ApiClient _api;

  @override
  Future<User> me() async => User.fromJson(await _api.send('GET', '/auth/me'));

  @override
  Future<void> login({required String email, required String password}) =>
      _api.send(
        'POST',
        '/auth/login',
        body: {'email': email, 'password': password},
      );

  @override
  Future<String> googleServerClientId() async {
    final config = await _api.send('GET', '/auth/google/config');
    return config['serverClientId'] as String;
  }

  @override
  Future<void> loginWithGoogle(String idToken) =>
      _api.send('POST', '/auth/google/token', body: {'idToken': idToken});

  @override
  Future<String?> register({
    required String email,
    required String password,
    String? name,
  }) async {
    final result = await _api.send(
      'POST',
      '/auth/register',
      body: {'email': email, 'password': password, 'name': ?name},
    );
    if (result is! Map || result['verificationRequired'] != true) return null;
    final message = result['message'];
    if (message is String && message.isNotEmpty) return message;
    throw ApiException(
      201,
      'invalid_response',
      'Your account was created. Check your email to verify it, then sign in.',
    );
  }

  @override
  Future<void> logout() => _api.send('POST', '/auth/logout');

  @override
  Future<String> recover(String email) async {
    final result = await _api.send(
      'POST',
      '/auth/recover',
      body: {'email': email},
    );
    return result['message'] as String;
  }
}
