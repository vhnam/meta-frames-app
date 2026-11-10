import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:meta_frames/data/services/api_client.dart';
import 'package:meta_frames/domain/models/gear_requests.dart';
import 'package:meta_frames/domain/models/film_requests.dart';
import 'package:meta_frames/domain/models/models.dart';
import 'package:meta_frames/domain/models/roll_requests.dart';
import 'package:meta_frames/providers.dart';
import 'package:meta_frames/routing/router.dart';
import 'package:meta_frames/routing/routes.dart';
import 'package:meta_frames/ui/film/widgets/stock_form.dart';
import 'package:meta_frames/ui/gear/widgets/camera_form.dart';
import 'package:meta_frames/ui/gear/widgets/lens_form.dart';
import 'package:meta_frames/ui/labs/widgets/lab_dialog.dart';
import 'package:meta_frames/ui/rolls/widgets/add_rolls.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../testing/fakes.dart';

/// Records each create request and its client id; can answer with a timeout.
class _Cameras extends FakeCameraRepository {
  final sent = <(CameraEdit, String?)>[];
  int timeouts = 0;

  @override
  Future<Camera> create(CameraEdit camera, {String? id}) async {
    sent.add((camera, id));
    if (timeouts > 0) {
      timeouts--;
      throw ApiException(0, 'network', 'timeout');
    }
    return super.create(camera, id: id);
  }
}

class _Lenses extends FakeLensRepository {
  final sent = <LensEdit>[];
  @override
  Future<Lens> create(LensEdit lens, {String? id}) async {
    sent.add(lens);
    return super.create(lens, id: id);
  }
}

class _Stocks extends FakeFilmStockRepository {
  final sent = <FilmStockEdit>[];

  /// The form only needs the request to have left; the answer is not used.
  @override
  Future<FilmStockDetail> create(FilmStockEdit stock, {String? id}) async {
    sent.add(stock);
    throw ApiException(0, 'network', 'timeout');
  }
}

class _Rolls extends FakeRollRepository {
  _Rolls() : super(const []);
  final sent = <NewRolls>[];
  @override
  Future<List<RollSummary>> addRolls(
    NewRolls rolls, {
    String? idempotencyKey,
  }) async {
    sent.add(rolls);
    return super.addRolls(rolls, idempotencyKey: idempotencyKey);
  }
}

/// Opens [screen] on top of an empty page, so the form can close itself.
Future<void> _open(
  WidgetTester tester,
  Widget screen, {
  _Cameras? cameras,
  _Lenses? lenses,
  _Stocks? stocks,
  _Rolls? rolls,
}) async {
  tester.view
    ..physicalSize = const Size(800, 3000)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(),
        routes: [GoRoute(path: 'form', builder: (_, _) => screen)],
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        prefsProvider.overrideWithValue(prefs),
        cameraRepositoryProvider.overrideWithValue(cameras ?? _Cameras()),
        lensRepositoryProvider.overrideWithValue(lenses ?? _Lenses()),
        filmStockRepositoryProvider.overrideWithValue(stocks ?? _Stocks()),
        rollRepositoryProvider.overrideWithValue(rolls ?? _Rolls()),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  router.push('/form');
  await tester.pumpAndSettle();
}

Future<void> _type(WidgetTester tester, int field, String text) =>
    tester.enterText(find.byType(TextFormField).at(field), text);

/// Fills a camera's brand, model and (required when interchangeable) mount.
Future<void> _camera(WidgetTester tester) async {
  await _type(tester, 0, 'Borrowed');
  await _type(tester, 1, 'Body');
  await _type(tester, 2, 'F');
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.tap(f);
  // Not pumpAndSettle: a focused text field never stops blinking its cursor.
  // Twice: a route opened after an await starts its animation on the second.
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pump(const Duration(milliseconds: 600));
}

void main() {
  group('quick modes send only the minimum', () {
    testWidgets('a camera: names and mount, no links', (tester) async {
      final cameras = _Cameras();
      await _open(tester, const CameraFormScreen(), cameras: cameras);
      await _camera(tester);
      await _tap(tester, find.text('Add camera'));
      final json = cameras.sent.single.$1.toJson();
      expect(json, {
        'brand': 'Borrowed',
        'model': 'Body',
        'mount': 'F',
        'hasFixedLens': false,
      });
      expect(cameras.lensWrites, isEmpty);
    });

    testWidgets('a lens: focal length and aperture only', (tester) async {
      final lenses = _Lenses();
      await _open(tester, const LensFormScreen(), lenses: lenses);
      await _type(tester, 2, '35');
      await _type(tester, 3, '2');
      await _tap(tester, find.text('Add lens'));
      expect(lenses.sent.single.toJson(), {
        'focalLength': 35,
        'maxAperture': 2.0,
      });
    });

    testWidgets('a lab: only its name, no scanners', (tester) async {
      final labs = FakeLabRepository();
      tester.view
        ..physicalSize = const Size(800, 3000)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            prefsProvider.overrideWithValue(prefs),
            labRepositoryProvider.overrideWithValue(labs),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () => editLab(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Foto Lab');
      await _tap(tester, find.text('Save'));
      expect(labs.saved!.toJson(), {'name': 'Foto Lab'});
    });

    testWidgets('a stock: the type, process and packaging picked, not '
        'inferred', (tester) async {
      final stocks = _Stocks();
      await _open(tester, const StockFormScreen(), stocks: stocks);
      await _type(tester, 0, 'Cine');
      await _type(tester, 1, 'Still');
      await _type(tester, 2, '800');
      // Slide with ECN-2 and repack: the form must not "fix" the mismatch.
      await _tap(tester, find.text('Slide'));
      await _tap(tester, find.text('ECN-2'));
      await _tap(tester, find.text('Repack'));
      await _tap(tester, find.text('Add film stock'));
      final stock = stocks.sent.single;
      expect(stock.type, StockType.slide);
      expect(stock.process, Process.ecn2);
      expect(stock.packaging, Packaging.repack);
      expect(stock.stockOrigin, isNull);
      expect(stock.baseStockId, isNull);
    });

    testWidgets('rolls: no price key, the draft id is the idempotency key', (
      tester,
    ) async {
      final rolls = _Rolls();
      await _open(
        tester,
        AddRollsScreen(stock: stock('s1'), quick: true),
        rolls: rolls,
      );
      await _tap(tester, find.text('Add roll'));
      final json = rolls.sent.single.toJson();
      expect(json.containsKey('price'), isFalse);
      expect(json.containsKey('expiry'), isFalse);
      expect(rolls.keys.single, isNotEmpty);
    });
  });

  test('NewRolls without a price has no price key', () {
    const rolls = NewRolls(
      filmStockId: 's1',
      format: 135,
      exposures: 36,
      quantity: 1,
    );
    expect(rolls.toJson().containsKey('price'), isFalse);
  });

  testWidgets('a save that timed out keeps the same client id', (tester) async {
    final cameras = _Cameras()..timeouts = 1;
    await _open(tester, const CameraFormScreen(), cameras: cameras);
    await _camera(tester);
    await _tap(tester, find.text('Add camera'));
    expect(cameras.sent, hasLength(1));
    await _tap(tester, find.text('Cancel'));
    await _tap(tester, find.text('Add camera'));
    expect(cameras.sent, hasLength(2));
    expect(cameras.sent[1].$2, isNotNull);
    expect(cameras.sent[1].$2, cameras.sent[0].$2);
  });

  testWidgets('a camera added from the load picker is selected there', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final router = buildRouter(initialLocation: Routes.load);
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          prefsProvider.overrideWithValue(prefs),
          cameraRepositoryProvider.overrideWithValue(_Cameras()),
          rollRepositoryProvider.overrideWithValue(_Rolls()),
          lensRepositoryProvider.overrideWithValue(_Lenses()),
          filmStockRepositoryProvider.overrideWithValue(_Stocks()),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    await _tap(tester, find.text('Select a camera'));
    await _tap(tester, find.text('Add a camera'));
    await _camera(tester);
    await _tap(tester, find.text('Add camera'));
    expect(find.text('Borrowed Body'), findsOneWidget);
    expect(find.text('Select a camera'), findsNothing);
  });
}
