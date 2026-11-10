import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:meta_frames/providers.dart';
import 'package:meta_frames/ui/rolls/view_models/frame_notes.dart';
import 'package:meta_frames/ui/rolls/widgets/frame_notes.dart';

import '../../testing/fakes.dart';

void main() {
  group('parseFrameNumber', () {
    test('takes any whole number from 0, past the exposure count too', () {
      expect(parseFrameNumber('0'), 0);
      expect(parseFrameNumber(' 12 '), 12);
      expect(parseFrameNumber('38'), 38);
    });

    test('refuses what the server would refuse', () {
      for (final bad in ['', ' ', '-1', '3.5', 'seven', '2147483648']) {
        expect(parseFrameNumber(bad), isNull, reason: bad);
      }
    });
  });

  group('NotesActions', () {
    late FakeRollRepository rolls;
    late ProviderContainer container;

    setUp(() {
      // A roll in a camera with no lab jobs and no scans.
      rolls = FakeRollRepository([roll('r1', status: 'in_camera')]);
      container = ProviderContainer(
        overrides: [rollRepositoryProvider.overrideWithValue(rolls)],
      );
      addTearDown(container.dispose);
    });

    test(
      'notes frames picked freely, skipping others, then edits one',
      () async {
        final actions = container.read(notesActionsProvider);
        await actions.save((rollId: 'r1', frame: 7), ' Market, backlit ');
        await actions.save((rollId: 'r1', frame: 12), 'Bridge at dusk');
        await actions.save((
          rollId: 'r1',
          frame: 7,
        ), 'Market, backlit, +1 stop');

        expect(rolls.calls, [
          'frameNotes:r1:7',
          'frameNotes:r1:12',
          'frameNotes:r1:7',
        ]);
        expect(rolls.frameNotes, {
          ('r1', 7): 'Market, backlit, +1 stop',
          ('r1', 12): 'Bridge at dusk',
        });
      },
    );

    test('saving empty text clears the note', () async {
      final actions = container.read(notesActionsProvider);
      await actions.save((rollId: 'r1', frame: 3), 'Portrait');
      await actions.save((rollId: 'r1', frame: 3), '   ');
      expect(rolls.frameNotes[('r1', 3)], isNull);
    });

    test(
      'a frame never noted reads as empty, and shows a saved note',
      () async {
        final provider = frameProvider(('r1', 5));
        final sub = container.listen(provider, (_, _) {});
        addTearDown(sub.close);

        expect(await container.read(provider.future), isNull);

        await container.read(notesActionsProvider).save((
          rollId: 'r1',
          frame: 5,
        ), 'Tree');
        expect((await container.read(provider.future))!.notes, 'Tree');
      },
    );
  });

  group('noteFrame', () {
    Future<List<String>> pump(WidgetTester tester) async {
      final opened = <String>[];
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, _) => Scaffold(
              body: TextButton(
                onPressed: () => noteFrame(context, 'r1'),
                child: const Text('note'),
              ),
            ),
          ),
          GoRoute(
            path: '/rolls/:id/frames/:n',
            builder: (_, s) {
              opened.add(s.matchedLocation);
              return const Scaffold(body: BackButton());
            },
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      return opened;
    }

    Future<void> open(WidgetTester tester, String number) async {
      await tester.tap(find.text('note'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), number);
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
    }

    testWidgets('opens the typed frame and starts empty every time', (
      tester,
    ) async {
      final opened = await pump(tester);

      await open(tester, '7');
      expect(opened, ['/rolls/r1/frames/7']);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      // Nothing is counted for the photographer: no number is suggested.
      await tester.tap(find.text('note'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
    });

    testWidgets('a number the server refuses opens nothing', (tester) async {
      final opened = await pump(tester);
      await open(tester, '-2');
      expect(opened, isEmpty);
      expect(find.byType(AlertDialog), findsOneWidget);
    });
  });
}
