import 'package:flutter_test/flutter_test.dart';
import 'package:meta_frames/domain/models/roll_requests.dart';

void main() {
  test('NewRolls omits unset optional fields', () {
    expect(
      const NewRolls(
        filmStockId: 's1',
        format: 135,
        exposures: 36,
        quantity: 3,
      ).toJson(),
      {'filmStockId': 's1', 'format': 135, 'exposures': 36, 'quantity': 3},
    );
  });

  test('NewRolls sends the expiry month only with a year', () {
    const withYear = NewRolls(
      filmStockId: 's1',
      format: 135,
      exposures: 36,
      quantity: 1,
      expiryYear: 2027,
      expiryMonth: 5,
    );
    expect(withYear.toJson()['expiryMonth'], 5);
    const noYear = NewRolls(
      filmStockId: 's1',
      format: 135,
      exposures: 36,
      quantity: 1,
      expiryMonth: 5,
    );
    expect(noYear.toJson().containsKey('expiryMonth'), isFalse);
  });

  test('RollEdit sends explicit nulls to clear fields', () {
    final json = const RollEdit(
      filmStockId: 's1',
      format: 120,
      exposures: 12,
      startedAt: null,
    ).toJson();
    expect(json['price'], isNull);
    expect(json.containsKey('price'), isTrue);
    expect(json['expiryMonth'], isNull);
    expect(json['startedAt'], isNull);
    expect(json['description'], isNull);
  });

  test('RollEdit formats dates as yyyy-MM-dd', () {
    final json = RollEdit(
      filmStockId: 's1',
      format: 135,
      exposures: 36,
      startedAt: DateTime(2026, 3, 5),
      finishedAt: DateTime(2026, 12, 25),
    ).toJson();
    expect(json['startedAt'], '2026-03-05');
    expect(json['finishedAt'], '2026-12-25');
  });
}
