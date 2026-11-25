import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_frames/data/services/session_store.dart';

const _binding = SessionBinding(
  server: 'https://api.example.com',
  userId: 'u1',
  email: 'ansel@example.com',
  name: 'Ansel',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  // load() builds the store the next start of the app reads from the keychain.
  Future<SecureSessionStore> restart() => SecureSessionStore.load();

  test('a fresh install loads no session', () async {
    final store = await restart();
    expect(store.signedIn, isFalse);
    expect(store.binding, isNull);
  });

  test('a token survives a restart, its binding is verified again', () async {
    final first = await restart();
    await first.setToken('t1');

    final second = await restart();
    expect(second.token, 't1');
    expect(second.binding, isNull);
  });

  test('a bound account survives a restart with its token', () async {
    final first = await restart();
    await first.setToken('t1');
    expect(await first.bind(_binding, forToken: 't1'), isTrue);

    final second = await restart();
    expect(second.token, 't1');
    expect(second.binding, _binding);
    expect(second.binding?.email, 'ansel@example.com');
  });

  test('ending the session removes the token and the binding', () async {
    final first = await restart();
    await first.setToken('t1');
    await first.bind(_binding, forToken: 't1');
    await first.setToken(null);

    final second = await restart();
    expect(second.signedIn, isFalse);
    expect(second.binding, isNull);
  });

  test('a new token drops the old account until it is verified', () async {
    final first = await restart();
    await first.setToken('t1');
    await first.bind(_binding, forToken: 't1');
    await first.setToken('t2');

    final second = await restart();
    expect(second.token, 't2');
    expect(second.binding, isNull);
  });

  test('a binding stored for another token is ignored on load', () async {
    FlutterSecureStorage.setMockInitialValues({
      'session_token': 't2',
      'session_binding': storedBinding('t1', _binding),
    });
    final store = await restart();
    expect(store.token, 't2');
    expect(store.binding, isNull);
  });

  test(
    'a slow answer for an earlier token cannot bind a newer session',
    () async {
      final store = await restart();
      await store.setToken('t1');
      await store.setToken('t2');
      expect(await store.bind(_binding, forToken: 't1'), isFalse);
      expect(store.binding, isNull);
    },
  );
}
