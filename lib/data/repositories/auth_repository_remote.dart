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
  Future<void> register({
    required String email,
    required String password,
    String? name,
  }) => _api.send(
    'POST',
    '/auth/register',
    body: {'email': email, 'password': password, 'name': ?name},
  );

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
