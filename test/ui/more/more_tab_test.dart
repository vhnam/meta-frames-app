import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:meta_frames/domain/models/models.dart';
import 'package:meta_frames/providers.dart';
import 'package:meta_frames/routing/routes.dart';
import 'package:meta_frames/ui/more/view_models/settings_actions.dart';
import 'package:meta_frames/ui/more/widgets/more_tab.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('the Dashboard row follows the address saved after the build', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final opened = <Uri>[];
    final container = ProviderContainer(
      overrides: [
        prefsProvider.overrideWithValue(prefs),
        currentUserProvider.overrideWith(
          (ref) async => User.fromJson({'id': 'u1', 'email': 'a@b.c'}),
        ),
        openOpsProvider.overrideWith((ref) async => []),
        draftsProvider.overrideWith((ref) async => []),
        urlOpenerProvider.overrideWithValue((uri) async {
          opened.add(uri);
          return true;
        }),
      ],
    );
    addTearDown(container.dispose);
    var settingsOpened = 0;
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const MoreTab()),
        GoRoute(
          path: Routes.settings,
          builder: (_, _) {
            settingsOpened++;
            return const SizedBox();
          },
        ),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    final row = find.byIcon(Icons.open_in_new);
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(settingsOpened, 1);
    expect(opened, isEmpty);

    router.pop();
    await tester.pumpAndSettle();
    await container
        .read(settingsActionsProvider)
        .setDashboardUrl(
          container.read(settingsActionsProvider).baseUrl,
          'https://dash.example.com',
        );
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(opened, [Uri.parse('https://dash.example.com')]);
    expect(settingsOpened, 1);
  });
}
