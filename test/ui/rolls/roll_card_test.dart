import 'package:flutter_test/flutter_test.dart';
import 'package:meta_frames/domain/models/models.dart';
import 'package:meta_frames/ui/rolls/widgets/roll_card.dart';

RollSummary _roll(
  String id, {
  String status = 'scanned',
  String stage = 'completed',
  String? cameraName = 'FM2',
  String startedAt = '2026-10-01',
  String stockName = 'Portra 400',
  bool negativesAtLab = false,
}) => RollSummary.fromJson({
  'id': id,
  'filmStockId': 's1',
  'stockBrand': 'Kodak',
  'stockName': stockName,
  'format': 135,
  'exposures': 36,
  'status': status,
  'stage': stage,
  'cameraName': ?cameraName,
  'startedAt': startedAt,
  'negativesAtLab': negativesAtLab,
});

void main() {
  group('rollIdHints', () {
    test('two rolls that read the same get the id start that splits them', () {
      final hints = rollIdHints([
        _roll('1c8d5f3a-aaaa'),
        _roll('6a2e4c8b-bbbb'),
      ]);
      expect(hints, {'1c8d5f3a-aaaa': '1c8d', '6a2e4c8b-bbbb': '6a2e'});
    });

    test('the hint grows until the ids differ', () {
      final hints = rollIdHints([
        _roll('1c8d5f3a-aaaa'),
        _roll('1c8d9e00-bbbb'),
      ]);
      expect(hints.values.toSet(), {'1c8d5', '1c8d9'});
    });

    test('rolls that already differ get no hint', () {
      expect(
        rollIdHints([
          _roll('a1', cameraName: 'FM2'),
          _roll('b2', cameraName: 'F3'),
          _roll('c3', stockName: 'Gold 200'),
          _roll('d4', stage: 'processing', status: 'at_lab'),
        ]),
        isEmpty,
      );
    });

    test('the Negatives at lab stamp already tells two rolls apart', () {
      expect(
        rollIdHints([_roll('a1'), _roll('b2', negativesAtLab: true)]),
        isEmpty,
      );
    });

    test('only the rolls that look alike get a hint', () {
      final hints = rollIdHints([
        _roll('aaaa1111'),
        _roll('bbbb2222'),
        _roll('cccc3333', startedAt: '2026-09-01'),
      ]);
      expect(hints.keys, unorderedEquals(['aaaa1111', 'bbbb2222']));
    });
  });
}
