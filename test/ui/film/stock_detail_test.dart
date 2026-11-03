import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_frames/domain/models/models.dart';
import 'package:meta_frames/providers.dart';
import 'package:meta_frames/ui/core/theme.dart';
import 'package:meta_frames/ui/core/widgets/common.dart';
import 'package:meta_frames/ui/film/widgets/stock_detail.dart';

import '../../testing/fakes.dart';

class _StockRepository extends FakeFilmStockRepository {
  _StockRepository(
    this.description, {
    this.type = 'color',
    this.process = 'C-41',
    this.packaging = 'factory',
  });
  final String? description;
  final String type, process, packaging;

  @override
  Future<FilmStockDetail> stock(String id) async => FilmStockDetail.fromJson({
    'stock': {
      'id': id,
      'brand': 'Kodak',
      'name': 'Gold',
      'type': type,
      'boxIso': '200',
      'process': process,
      'packaging': packaging,
      'description': description,
    },
  });
}

Future<void> _pump(
  WidgetTester tester,
  String? description, {
  String type = 'color',
  String process = 'C-41',
  String packaging = 'factory',
  ThemeData? theme,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        filmStockRepositoryProvider.overrideWithValue(
          _StockRepository(
            description,
            type: type,
            process: process,
            packaging: packaging,
          ),
        ),
        rollRepositoryProvider.overrideWithValue(FakeRollRepository()),
      ],
      child: MaterialApp(
        theme: theme,
        home: const StockDetailScreen(stockId: 's1'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// WCAG contrast of a badge's text over its tint on the card surface.
double _contrast(StampBadge badge, Color card) {
  final bg = Color.alphaBlend(badge.color.withValues(alpha: 0.1), card);
  final (a, b) = (badge.color.computeLuminance(), bg.computeLuminance());
  return (max(a, b) + 0.05) / (min(a, b) + 0.05);
}

void main() {
  group('dark mode badges meet 4.5:1', () {
    final theme = buildTheme(Brightness.dark);
    final cases = [
      ('color', 'C-41', 'factory'),
      ('bw', 'BW', 'repack'),
      ('slide', 'E-6', 'respooled'),
      ('color', 'ECN-2', 'factory'),
    ];
    for (final (type, process, packaging) in cases) {
      testWidgets('$type $process $packaging', (tester) async {
        await _pump(
          tester,
          null,
          type: type,
          process: process,
          packaging: packaging,
          theme: theme,
        );
        final badges = tester.widgetList<StampBadge>(find.byType(StampBadge));
        expect(badges, hasLength(3));
        for (final b in badges) {
          expect(
            _contrast(b, theme.colorScheme.surfaceContainerLow),
            greaterThanOrEqualTo(4.5),
            reason: b.text,
          );
        }
      });
    }
  });

  testWidgets('shows type, process and packaging as badges', (tester) async {
    await _pump(tester, null);
    expect(find.byType(StampBadge), findsNWidgets(3));
    expect(find.text('COLOR'), findsOneWidget);
    expect(find.text('C-41'), findsOneWidget);
    expect(find.text('FACTORY'), findsOneWidget);
  });

  testWidgets('labels B&W film and repacked rolls', (tester) async {
    await _pump(tester, null, type: 'bw', process: 'BW', packaging: 'repack');
    expect(find.text('B&W'), findsNWidgets(2));
    expect(find.text('REPACK'), findsOneWidget);
  });

  testWidgets('renders the notes as Markdown', (tester) async {
    await _pump(tester, '**Warm** tones');
    expect(find.byType(MarkdownBody), findsOneWidget);
    expect(find.text('Warm tones'), findsOneWidget);
    expect(find.textContaining('**'), findsNothing);
  });

  testWidgets('puts the notes in one column below their label', (tester) async {
    await _pump(tester, 'Warm tones');
    final label = tester.getTopLeft(find.text('Notes'));
    final note = tester.getTopLeft(find.byType(MarkdownBody));
    expect(note.dx, label.dx);
    expect(note.dy, greaterThan(label.dy));
  });

  testWidgets('keeps a typed line break', (tester) async {
    await _pump(tester, 'First line\nSecond line');
    expect(find.text('First line\nSecond line'), findsOneWidget);
  });

  testWidgets('hides the notes row without notes', (tester) async {
    await _pump(tester, null);
    expect(find.text('Notes'), findsNothing);
    expect(find.byType(MarkdownBody), findsNothing);
  });
}
