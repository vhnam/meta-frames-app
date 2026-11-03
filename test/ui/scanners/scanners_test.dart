import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:meta_frames/domain/models/models.dart';
import 'package:meta_frames/providers.dart';
import 'package:meta_frames/routing/router.dart';
import 'package:meta_frames/routing/routes.dart';

import '../../testing/fakes.dart';

final _kinds = [
  ScannerKindOptions.fromJson({
    'kind': 'flatbed',
    'label': 'Flatbed',
    'options': [
      {
        'key': 'dpi',
        'label': 'DPI',
        'type': 'integer',
        'min': 100,
        'max': 200,
        'default': 150,
      },
      {
        'key': 'dust_removal',
        'label': 'Dust removal',
        'type': 'boolean',
        'default': false,
      },
    ],
  }),
  ScannerKindOptions.fromJson({
    'kind': 'minilab',
    'label': 'Lab minilab',
    'options': [
      {
        'key': 'format',
        'label': 'Format',
        'type': 'enum',
        'values': [
          {'value': 'jpeg', 'label': 'JPEG'},
          {'value': 'tiff', 'label': 'TIFF'},
        ],
        'default': 'jpeg',
      },
    ],
  }),
  ScannerKindOptions.fromJson({'label': 'Unknown kind', 'options': []}),
];

final _builtIn = scanner(
  'b1',
  'Noritsu HS-1800',
  kind: 'minilab',
  builtIn: true,
);
final _own = scanner(
  's1',
  'Epson V850',
  kind: 'flatbed',
  notes: 'Holder',
  defaultSettings: {'dpi': 120, 'dust_removal': true},
);

/// Opens the Scanners screen with [push] over it, so closing returns to it.
Future<GoRouter> _pump(
  WidgetTester tester,
  FakeScannerRepository repo, {
  String? push,
  bool settle = true,
}) async {
  tester.view
    ..physicalSize = const Size(800, 3000)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = buildRouter(initialLocation: Routes.scanners);
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [scannerRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  if (push != null) {
    router.push(push);
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    }
  }
  return router;
}

String _location(GoRouter r) =>
    r.routerDelegate.currentConfiguration.last.matchedLocation;

Finder _field(String label) => find.ancestor(
  of: find.text(label.toUpperCase()),
  matching: find.byType(Column),
);

Finder _input(String label) =>
    find.descendant(of: _field(label).first, matching: find.byType(TextField));

void main() {
  group('list', () {
    testWidgets('groups built-in scanners and your own', (tester) async {
      await _pump(tester, FakeScannerRepository([_builtIn, _own]));
      expect(find.text('Built-in · 1'.toUpperCase()), findsOneWidget);
      expect(find.text('Yours · 1'.toUpperCase()), findsOneWidget);
      expect(find.text('Noritsu HS-1800'), findsOneWidget);
      expect(find.text('Lab minilab'), findsOneWidget);
      expect(find.text('Epson V850'), findsOneWidget);
    });

    testWidgets('says when you have no scanners of your own', (tester) async {
      await _pump(tester, FakeScannerRepository([_builtIn]));
      expect(find.text('No scanners of your own'), findsOneWidget);
    });

    testWidgets('a row opens the scanner', (tester) async {
      final router = await _pump(tester, FakeScannerRepository([_own], _kinds));
      await tester.tap(find.text('Epson V850'));
      await tester.pumpAndSettle();
      expect(_location(router), '/scanners/s1');
      expect(find.text('Edit Scanner'), findsOneWidget);
    });
  });

  group('add', () {
    testWidgets('needs a brand', (tester) async {
      final repo = FakeScannerRepository(const [], _kinds);
      await _pump(tester, repo, push: Routes.scannerNew);
      await tester.tap(find.text('Add scanner'));
      await tester.pumpAndSettle();
      expect(find.text('Required'), findsOneWidget);
      expect(repo.calls, isEmpty);
    });

    testWidgets('saves and returns to the list', (tester) async {
      final repo = FakeScannerRepository(const [], _kinds);
      final router = await _pump(tester, repo, push: Routes.scannerNew);
      await tester.enterText(_input('Brand'), ' Epson ');
      await tester.enterText(_input('Model (optional)'), 'V850');
      await tester.tap(find.text('Add scanner'));
      await tester.pumpAndSettle();
      expect(repo.calls, ['create']);
      expect(repo.saved!.brand, 'Epson');
      expect(repo.saved!.model, 'V850');
      expect(repo.saved!.kind, isNull);
      expect(_location(router), Routes.scanners);
    });

    testWidgets('the fields follow the picked kind', (tester) async {
      final repo = FakeScannerRepository(const [], _kinds);
      await _pump(tester, repo, push: Routes.scannerNew);
      expect(find.text('No options for this scanner.'), findsOneWidget);

      await tester.tap(find.text('Unknown kind'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Flatbed').last);
      await tester.pumpAndSettle();
      expect(find.text('DPI'.toUpperCase()), findsOneWidget);
      expect(find.text('Dust removal'), findsOneWidget);

      await tester.enterText(_input('Brand'), 'Epson');
      await tester.tap(find.text('Add scanner'));
      await tester.pumpAndSettle();
      expect(repo.saved!.kind, ScannerKind.flatbed);
      expect(repo.saved!.defaultSettings, {'dpi': 150, 'dust_removal': false});
    });
  });

  group('edit', () {
    testWidgets('keeps the default settings it does not change', (
      tester,
    ) async {
      final repo = FakeScannerRepository([_own], _kinds);
      await _pump(tester, repo, push: Routes.scanner('s1'));
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      expect(repo.calls, ['update:s1']);
      expect(repo.saved!.defaultSettings, {'dpi': 120, 'dust_removal': true});
      expect(repo.saved!.notes, 'Holder');
    });

    testWidgets('changing a setting saves the new value', (tester) async {
      final repo = FakeScannerRepository([_own], _kinds);
      await _pump(tester, repo, push: Routes.scanner('s1'));
      await tester.enterText(_input('DPI'), '180');
      await tester.pump();
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      expect(repo.saved!.defaultSettings, {'dpi': 180, 'dust_removal': false});
    });

    testWidgets('refuses a number outside the option\'s range', (tester) async {
      final repo = FakeScannerRepository([_own], _kinds);
      await _pump(tester, repo, push: Routes.scanner('s1'));
      await tester.enterText(_input('DPI'), '999');
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      expect(find.text('Enter 100 to 200'), findsOneWidget);
      expect(repo.calls, isEmpty);
    });

    testWidgets(
      'cannot save before the kinds load, which would clear settings',
      (tester) async {
        final repo = _SlowKinds([_own]);
        await _pump(tester, repo, push: Routes.scanner('s1'), settle: false);
        await tester.tap(find.text('Save changes'));
        await tester.pump();
        expect(repo.calls, isEmpty);
        repo.finish();
        await tester.pumpAndSettle();
        await tester.tap(find.text('Save changes'));
        await tester.pumpAndSettle();
        expect(repo.calls, ['update:s1']);
        expect(repo.saved!.defaultSettings, {'dpi': 120, 'dust_removal': true});
      },
    );

    testWidgets('delete asks first, then returns to the list', (tester) async {
      final repo = FakeScannerRepository([_own], _kinds);
      final router = await _pump(tester, repo, push: Routes.scanner('s1'));

      await tester.tap(find.text('Delete scanner'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(repo.calls, isEmpty);

      await tester.tap(find.text('Delete scanner'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(repo.calls, ['delete:s1']);
      expect(_location(router), Routes.scanners);
    });
  });

  group('built-in', () {
    testWidgets('opens read-only, with no save or delete', (tester) async {
      await _pump(
        tester,
        FakeScannerRepository([_builtIn], _kinds),
        push: Routes.scanner('b1'),
      );
      expect(find.text('Built-in Scanner'), findsOneWidget);
      expect(find.text('Save changes'), findsNothing);
      expect(find.text('Delete scanner'), findsNothing);
      for (final f in tester.widgetList<TextField>(find.byType(TextField))) {
        expect(f.enabled, isFalse);
      }
    });
  });
}

/// Holds the scan options back until [finish].
class _SlowKinds extends FakeScannerRepository {
  _SlowKinds(super.all);
  final _options = Completer<List<ScannerKindOptions>>();

  @override
  Future<List<ScannerKindOptions>> kinds() => _options.future;

  void finish() => _options.complete(_kinds);
}
