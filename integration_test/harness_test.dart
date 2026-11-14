import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:meta_frames/data/sync/pending_op.dart';
import 'package:meta_frames/providers.dart';

import 'support/finders.dart';
import 'support/harness.dart';
import 'support/server_api.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final server = ServerApi();

  // Proves the offline switch (D2) and the restart helper (D3).
  testWidgets('H01 a note taken offline survives a restart and syncs', (
    tester,
  ) async {
    const password = 'Zone-System5';
    const note = 'Golden hour on the bridge';
    final token = await server.register(newEmail('h01'), password);
    final stock = 'E2E stock ${DateTime.now().millisecondsSinceEpoch}';
    final seeded = await server.seedRoll(token, stockName: stock);
    final key = partitionOf((await server.me(token))['id'] as String);

    final device = await newDevice(token: token);
    await launch(tester, device);
    await waitForPartition(tester, key);

    // Open the roll while online, so the phone has it. Then go offline.
    await tapOn(tester, find.text(Ui.rollsTab));
    await tapOn(tester, find.textContaining(seeded.stockName));
    await pumpUntilFound(tester, find.text(Ui.addNotes));
    device.net.online = false;

    // The roll's own notes have a button with the same label, above the frames'.
    await tapOn(tester, find.text(Ui.addNotes).last);
    final frameNumber = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    await pumpUntilFound(tester, frameNumber);
    await tester.enterText(frameNumber, '7');
    await tapOn(tester, find.text(Ui.openFrame));
    await pumpUntilFound(tester, find.text(Ui.save));
    await tester.enterText(find.byType(TextField), note);
    await pumpUntil(
      tester,
      () =>
          tester
              .widget<TextButton>(find.widgetWithText(TextButton, Ui.save))
              .onPressed !=
          null,
    );
    await tapOn(tester, find.text(Ui.save));

    final before = await openOps(tester);
    expect(before, hasLength(1));
    expect(before.single.kind, OpKind.frameNotes);
    // The server is reachable for the test and has nothing yet.
    expect(await server.frameNotes(token, seeded.rollId, 7), isNull);
    final labId = await server.addLab(token, 'Offline lab');
    expect((await server.labs(token)).map((lab) => lab['id']), contains(labId));

    await restart(tester, device);
    final after = await openOps(tester);
    expect(after.map((op) => op.opId), before.map((op) => op.opId));

    device.net.online = true;
    await scope(tester).read(partitionControllerProvider).sync();
    await pumpUntilAsync(
      tester,
      () async => await server.frameNotes(token, seeded.rollId, 7) == note,
    );
    await pumpUntilAsync(tester, () async => (await openOps(tester)).isEmpty);
  });
}
