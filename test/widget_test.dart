import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_frames/app.dart';
import 'package:meta_frames/core/models.dart';
import 'package:meta_frames/features/rolls/load_roll.dart';
import 'package:meta_frames/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('expiry: unknown month counts as December', () {
    final now = DateTime.now();
    expect(isExpired(ExpiryMonth.fromJson({'year': now.year - 1})), isTrue);
    expect(isExpired(ExpiryMonth.fromJson({'year': now.year})), now.month > 12);
    expect(isExpired(ExpiryMonth.fromJson({'year': now.year + 1, 'month': 1})), isFalse);
    expect(isExpired(null), isFalse);
  });

  test('Lens name formatting', () {
    final l = Lens.fromJson({
      'id': '1', 'brand': 'Nikon', 'model': '50mm', 'focalLength': 50,
      'maxAperture': 1.8, 'isBuiltIn': false, 'isActive': true,
    });
    expect(l.name, 'Nikon 50mm 50mm f/1.8');
  });

  testWidgets('app shows bottom navigation', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(ProviderScope(
      overrides: [prefsProvider.overrideWithValue(prefs)],
      child: const MetaFramesApp(),
    ));
    expect(find.text('Gear'), findsOneWidget);
    expect(find.text('Rolls'), findsWidgets);
  });
}
