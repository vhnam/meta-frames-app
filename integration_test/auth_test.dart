import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/finders.dart';
import 'support/harness.dart';
import 'support/server_api.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final server = ServerApi();

  // E01: register, log out, a wrong password, then the right one.
  testWidgets('E01 a new account registers, logs out and logs back in', (
    tester,
  ) async {
    final email = newEmail('e01');
    const password = 'Zone-System5';
    final session = await startApp(tester);
    expect(session.token, isNull);

    await tapOn(tester, find.text(Ui.createAccountLink));
    await enterField(tester, Ui.nameHint, 'E2E One');
    await enterField(tester, Ui.emailHint, email);
    await enterField(tester, Ui.newPasswordHint, password);
    await enterField(tester, Ui.confirmPasswordHint, password);
    await tapOn(tester, find.text(Ui.createAccount));
    await pumpUntil(tester, () => session.token != null);
    expect((await server.me(session.token!))['email'], email);

    await pumpUntilFound(tester, find.byType(NavigationBar));
    await tapOn(tester, find.text(Ui.moreTab));
    await tapOn(tester, find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text(Ui.logOut), 100);
    await tapOn(tester, find.text(Ui.logOut));
    await pumpUntil(tester, () => session.token == null);

    await enterField(tester, Ui.emailHint, email);
    await enterField(tester, Ui.passwordHint, 'Wrong-Pass9');
    await tapOn(tester, find.text(Ui.logIn));
    // The button shows a spinner from the tap until the server has answered.
    expect(find.text(Ui.logIn), findsNothing);
    await pumpUntilFound(tester, find.text(Ui.logIn));
    expect(session.token, isNull);

    await enterField(tester, Ui.passwordHint, password);
    await tapOn(tester, find.text(Ui.logIn));
    await pumpUntil(tester, () => session.token != null);
    expect((await server.me(session.token!))['email'], email);
  });
}
