import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:meta_frames/data/local/local_store.dart';

import 'support/finders.dart';
import 'support/harness.dart';
import 'support/server_api.dart';

/// A new account of its own: its session token and its partition.
Future<({String token, PartitionKey key})> _account(
  ServerApi server,
  String testCase,
) async {
  final token = await server.register(newEmail(testCase), 'Zone-System5');
  return (
    token: token,
    key: partitionOf((await server.me(token))['id'] as String),
  );
}

/// Starts the app signed in as [account], after its data is seeded.
Future<Device> _open(
  WidgetTester tester,
  ({String token, PartitionKey key}) account,
) async {
  final device = await newDevice(token: account.token);
  await launch(tester, device);
  await waitForPartition(tester, account.key);
  return device;
}

String _unique(String label) =>
    '$label ${DateTime.now().millisecondsSinceEpoch}';

/// Taps [finder] once the menu, sheet or dialog that holds it has stopped
/// moving: a tap on a moving item misses it.
Future<void> _tapWhenSettled(WidgetTester tester, Finder finder) async {
  await pumpUntilFound(tester, finder);
  await tester.pump(const Duration(milliseconds: 500));
  await tapOn(tester, finder);
}

Future<void> _openRoll(WidgetTester tester, String stockName) async {
  await tapOn(tester, find.text(Ui.rollsTab));
  await tapOn(tester, find.textContaining(stockName));
}

/// Writes [text] on frame [number] of the open roll. [existing] is the text
/// the frame has now: the screen is filled before the new text is typed.
Future<void> _writeFrameNote(
  WidgetTester tester,
  int number,
  String text, {
  String? existing,
}) async {
  await tapOn(tester, find.text(Ui.logFrame));
  final numberField = find.descendant(
    of: find.byType(AlertDialog),
    matching: find.byType(TextField),
  );
  await pumpUntilFound(tester, numberField);
  await tester.enterText(numberField, '$number');
  await _tapWhenSettled(tester, find.text(Ui.openFrame));
  await pumpUntilFound(tester, find.text(Ui.save));
  if (existing != null) await pumpUntilFound(tester, find.text(existing));
  await tester.enterText(find.byType(TextField), text);
  // The editor's Save is off until the saved notes are known.
  bool saveReady() => tester
      .widgetList<TextButton>(find.byType(TextButton))
      .any(
        (button) =>
            (button.child as Text?)?.data == Ui.save &&
            button.onPressed != null,
      );
  await pumpUntil(tester, saveReady);
  await tapOn(tester, find.text(Ui.save));
  // The editor closes; the next note starts from the roll page.
  await pumpUntil(tester, () => find.text(Ui.save).evaluate().isEmpty);
  await pumpUntilFound(tester, find.text(Ui.logFrame));
  // The roll page reloads after a save and lists the frame. A dialog opened
  // before that ends loses its screen: its result is dropped.
  await pumpUntilFound(tester, find.text('#$number'));
  await tester.pump(const Duration(seconds: 1));
}

/// Loads the open roll into the camera named [cameraName] through its page.
Future<void> _loadFromRollPage(
  WidgetTester tester,
  String cameraName, {
  String? isoHint,
  String? iso,
}) async {
  await tapOn(tester, find.text(Ui.loadIntoCamera));
  await tapOn(tester, find.text(Ui.selectCamera));
  await _tapWhenSettled(tester, find.textContaining(cameraName));
  if (iso != null) await enterField(tester, isoHint!, iso);
  await tapOn(tester, find.widgetWithText(FilledButton, Ui.load));
  await pumpUntilFound(tester, find.byTooltip(Ui.moreActions));
}

/// The roll page has no "Finish roll" in its menu while the roll is in the
/// camera, so the roll is finished from its camera's card on the Shooting tab.
Future<void> _finishFromShootingTab(WidgetTester tester) async {
  await tester.pageBack();
  await pumpUntilFound(tester, find.byType(NavigationBar));
  await tapOn(tester, find.text(Ui.shootingTab));
  await tapOn(tester, find.widgetWithText(OutlinedButton, Ui.finish));
  await _tapWhenSettled(tester, find.widgetWithText(FilledButton, Ui.finish));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final server = ServerApi();

  testWidgets('E02 each camera card opens its own roll', (tester) async {
    final account = await _account(server, 'e02');
    final token = account.token;
    final stockId = await server.seedStock(token, _unique('E02 stock'));
    final rollIds = await server.seedRolls(token, stockId, quantity: 2);
    final cameras = [_unique('E02 A'), _unique('E02 B')];
    final notes = [_unique('first-roll-note'), _unique('second-roll-note')];
    for (var index = 0; index < 2; index++) {
      final cameraId = await server.seedCamera(token, cameras[index]);
      await server.loadRoll(
        token,
        rollIds[index],
        cameraId,
        shotIso: index == 0 ? 200 : 1600,
      );
      await server.putRollNotes(token, rollIds[index], notes[index]);
    }
    await _open(tester, account);

    for (var index = 0; index < 2; index++) {
      await tapOn(tester, find.text(Ui.shootingTab));
      await tapOn(tester, find.textContaining(cameras[index]));
      await pumpUntilFound(tester, find.textContaining(notes[index]));
      expect(find.textContaining(notes[1 - index]), findsNothing);
      await tester.pageBack();
      await tester.pump();
    }
  });

  testWidgets('E03 load, note two frames, edit one, finish', (tester) async {
    final account = await _account(server, 'e03');
    final token = account.token;
    final stock = _unique('E03 stock');
    final rollId = (await server.seedRoll(token, stockName: stock)).rollId;
    final camera = _unique('E03 cam');
    await server.seedCamera(token, camera);
    await _open(tester, account);

    await _openRoll(tester, stock);
    await _loadFromRollPage(tester, camera);
    await pumpUntilAsync(
      tester,
      () async => (await server.roll(token, rollId))['status'] == 'in_camera',
    );
    await _writeFrameNote(tester, 7, 'text-A');
    await _writeFrameNote(tester, 12, 'text-B');
    await _writeFrameNote(tester, 7, 'text-C', existing: 'text-A');
    await _finishFromShootingTab(tester);

    await pumpUntilAsync(
      tester,
      () async =>
          (await server.roll(token, rollId))['status'] == 'done_shooting',
    );
    final roll = await server.roll(token, rollId);
    expect(roll['startedAt'], isNotNull);
    expect(roll['finishedAt'], isNotNull);
    final frames = await server.frames(token, rollId);
    expect(
      {for (final frame in frames) frame['number']: frame['notes']},
      {7: 'text-C', 12: 'text-B'},
    );
    expect((await openOps(tester)), isEmpty);
  });

  testWidgets(
    'E04 a 400 stock loaded at ISO 800 is sent with no push request',
    (tester) async {
      final account = await _account(server, 'e04');
      final token = account.token;
      final stock = _unique('E04 stock');
      final rollId = (await server.seedRoll(token, stockName: stock)).rollId;
      final camera = _unique('E04 cam');
      await server.seedCamera(token, camera);
      final labName = _unique('E04 lab');
      final labId = await server.addLab(token, labName);
      await _open(tester, account);

      await _openRoll(tester, stock);
      await _loadFromRollPage(
        tester,
        camera,
        isoHint: 'Empty = box ISO 400',
        iso: '800',
      );
      await _finishFromShootingTab(tester);
      await _openRoll(tester, stock);
      await pumpUntilAsync(
        tester,
        () async =>
            (await server.roll(token, rollId))['status'] == 'done_shooting',
      );
      await tapOn(tester, find.byTooltip(Ui.moreActions));
      await _tapWhenSettled(tester, find.text(Ui.sendToLab));
      // The form starts at home ("Self-develop"); the lab field changes that.
      await tapOn(tester, find.textContaining(Ui.selfPrefix));
      await _tapWhenSettled(tester, find.textContaining(labName));
      // A toast from the earlier steps can cover the button.
      await pumpUntil(tester, () => find.byType(SnackBar).evaluate().isEmpty);
      await _tapWhenSettled(
        tester,
        find.widgetWithText(FilledButton, Ui.sendToLab),
      );

      await pumpUntilAsync(
        tester,
        () async => (await server.processing(token, rollId)).isNotEmpty,
      );
      expect((await server.roll(token, rollId))['shotIso'], 800);
      final jobs = await server.processing(token, rollId);
      expect(jobs, hasLength(1));
      expect(jobs.single['labId'], labId);
      expect(jobs.single['notes'] ?? '', isEmpty);
    },
  );

  testWidgets('E05 quick-add three rolls of one stock', (tester) async {
    final account = await _account(server, 'e05');
    final token = account.token;
    final stock = _unique('E05 stock');
    final stockId = await server.seedStock(token, stock);
    await _open(tester, account);

    await tapOn(tester, find.text(Ui.rollsTab));
    await tapOn(tester, find.text(Ui.addRollsButton));
    await tapOn(tester, find.text(Ui.selectStock));
    await _tapWhenSettled(tester, find.textContaining(stock));
    final quantity = find.byWidgetPredicate(
      (widget) => widget is TextFormField && widget.controller?.text == '1',
    );
    await pumpUntilFound(tester, quantity);
    await tester.enterText(quantity, '3');
    await tester.pump();
    await tapOn(tester, find.text('Add 3 rolls'));

    await pumpUntilAsync(
      tester,
      () async => (await server.rolls(token)).length == 3,
    );
    final rolls = await server.rolls(token);
    expect({for (final roll in rolls) roll['filmStockId']}, {stockId});
    expect({for (final roll in rolls) roll['status']}, {'in_stock'});
  });
}
