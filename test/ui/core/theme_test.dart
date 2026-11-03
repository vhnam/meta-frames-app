import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_frames/ui/core/theme.dart';

double _contrast(Color a, Color b) {
  final (x, y) = (a.computeLuminance(), b.computeLuminance());
  return (max(x, y) + 0.05) / (min(x, y) + 0.05);
}

/// Pumps an enabled and a disabled text button in [theme].
Future<void> _pump(WidgetTester tester, ThemeData theme) => tester.pumpWidget(
  MaterialApp(
    theme: theme,
    home: Scaffold(
      body: Column(
        children: [
          TextButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.add),
            label: const Text('On'),
          ),
          TextButton.icon(
            onPressed: null,
            icon: const Icon(Icons.remove),
            label: const Text('Off'),
          ),
        ],
      ),
    ),
  ),
);

Color _textColor(WidgetTester tester, String text) =>
    DefaultTextStyle.of(tester.element(find.text(text))).style.color!;

Color _iconColor(WidgetTester tester, IconData icon) =>
    IconTheme.of(tester.element(find.byIcon(icon))).color!;

void main() {
  for (final brightness in Brightness.values) {
    final theme = buildTheme(brightness);
    final cs = theme.colorScheme;

    group('$brightness text button', () {
      testWidgets('text and icon are readable on every page surface', (
        tester,
      ) async {
        await _pump(tester, theme);
        for (final surface in [cs.surface, cs.surfaceContainerLow]) {
          expect(
            _contrast(_textColor(tester, 'On'), surface),
            greaterThanOrEqualTo(4.5),
          );
          expect(
            _contrast(_iconColor(tester, Icons.add), surface),
            greaterThanOrEqualTo(4.5),
          );
        }
      });

      testWidgets('a disabled button still looks disabled', (tester) async {
        await _pump(tester, theme);
        expect(_textColor(tester, 'Off'), isNot(_textColor(tester, 'On')));
        expect(
          _iconColor(tester, Icons.remove),
          isNot(_iconColor(tester, Icons.add)),
        );
      });
    });
  }
}
