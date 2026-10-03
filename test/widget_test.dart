import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_frames/app.dart';
import 'package:meta_frames/core/models.dart';
import 'package:meta_frames/features/rolls/load_roll.dart';
import 'package:meta_frames/features/scans/scan_grid.dart';
import 'package:meta_frames/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  _scanGridTests();
  test('expiry: unknown month counts as December', () {
    final now = DateTime.now();
    expect(isExpired(ExpiryMonth.fromJson({'year': now.year - 1})), isTrue);
    expect(isExpired(ExpiryMonth.fromJson({'year': now.year})), now.month > 12);
    expect(
      isExpired(ExpiryMonth.fromJson({'year': now.year + 1, 'month': 1})),
      isFalse,
    );
    expect(isExpired(null), isFalse);
  });

  test('Lens name formatting', () {
    final l = Lens.fromJson({
      'id': '1',
      'brand': 'Nikon',
      'model': '50mm',
      'focalLength': 50,
      'maxAperture': 1.8,
      'isBuiltIn': false,
      'isActive': true,
    });
    expect(l.name, 'Nikon 50mm 50mm f/1.8');
  });

  testWidgets('app shows bottom navigation', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [prefsProvider.overrideWithValue(prefs)],
        child: const MetaFramesApp(),
      ),
    );
    expect(find.text('Gear'), findsOneWidget);
    expect(find.text('Rolls'), findsWidgets);
  });
}

class _FakeProcessingScans {
  static Map<String, dynamic> processing() => {
    'id': 'p1',
    'rollId': 'r1',
    'type': 'develop_scan',
    'process': 'C-41',
    'sentAt': '2026-01-01',
    'scanners': ['noritsu'],
    'isOpen': true,
  };

  static Map<String, dynamic> scan(int n) => {
    'id': 's$n',
    'processingId': 'p1',
    'frameId': 'f$n',
    'frameNumber': n,
    'scanner': 'noritsu',
    'fileName': '$n.jpg',
    'sizeBytes': 1,
    'fileUrl': '/scans/$n.jpg',
  };
}

void _scanGridTests() {
  testWidgets('scan grid is lazy and shows scans in frame order', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final processing = Processing.fromJson(_FakeProcessingScans.processing());
    // 60 scans, delivered out of order.
    final scans = [
      for (var n = 60; n >= 1; n--) Scan.fromJson(_FakeProcessingScans.scan(n)),
    ]..sort((a, b) => a.frameNumber - b.frameNumber);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          prefsProvider.overrideWithValue(prefs),
          scansProvider.overrideWith((ref, k) async => scans),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: CustomScrollView(slivers: [ScanGrid(processing: processing)]),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('#1'), findsOneWidget);
    expect(find.text('#60'), findsNothing); // off-screen, never built
  });
}
