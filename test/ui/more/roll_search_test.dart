import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_frames/providers.dart';
import 'package:meta_frames/ui/more/view_models/roll_search.dart';

import '../../testing/fakes.dart';

void main() {
  late RollSearch search;

  setUp(() {
    final rolls = FakeRollRepository([
      roll('gold'),
      RollSummaryFixture.withCamera('hp5', 'Leica M6'),
      RollSummaryFixture.withCamera('other', 'Nikon FM2'),
    ]);
    // A roll found only through its lens: neither its stock nor camera match.
    rolls.rollIdsByLens['l-summicron'] = {'other'};
    final container = ProviderContainer(
      overrides: [
        rollRepositoryProvider.overrideWithValue(rolls),
        lensRepositoryProvider.overrideWithValue(
          FakeLensRepository([lens('l-summicron')]),
        ),
      ],
    );
    addTearDown(container.dispose);
    search = container.read(rollSearchProvider);
  });

  test('matches the stock name', () async {
    expect((await search.byName('gold')).map((r) => r.id), ['gold']);
  });

  test('matches the camera name, ignoring case', () async {
    expect((await search.byName('LEICA')).map((r) => r.id), ['hp5']);
  });

  test('matches rolls shot with a lens whose name matches', () async {
    // The fake lens is named "Nikon l-summicron 50mm f/1.8".
    final ids = (await search.byName('summicron')).map((r) => r.id);
    expect(ids, ['other']);
  });

  test('a roll that matches twice is listed once', () async {
    final ids = (await search.byName('nikon')).map((r) => r.id).toList();
    expect(ids, ['other']);
  });

  test('no match gives an empty list', () async {
    expect(await search.byName('polaroid'), isEmpty);
  });
}
