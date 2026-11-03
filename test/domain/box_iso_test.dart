import 'package:flutter_test/flutter_test.dart';
import 'package:meta_frames/domain/models/models.dart';

FilmStock stock(Object boxIso) => FilmStock.fromJson({
  'id': 'stock',
  'brand': 'Lomography',
  'name': 'Color',
  'type': 'color',
  'boxIso': boxIso,
  'process': 'C-41',
  'packaging': 'factory',
});

void main() {
  test('a box ISO is a single speed or a rising range', () {
    for (final valid in ['400', '100-400', '50-200']) {
      expect(isValidBoxIso(valid), isTrue, reason: valid);
    }
    for (final invalid in [
      '',
      '0',
      '-400',
      '400-',
      '400-100',
      '200-200',
      'x',
    ]) {
      expect(isValidBoxIso(invalid), isFalse, reason: invalid);
    }
  });

  test('a box ISO sent as a number reads as text', () {
    expect(stock(400).boxIso, '400');
    expect(stock(400).isBoxSpeed(400), isTrue);
  });

  test('a speed within a range is the box speed', () {
    expect(stock('100-400').isBoxSpeed(200), isTrue);
    expect(stock('100-400').isBoxSpeed(800), isFalse);
    expect(stock('400').isBoxSpeed(400), isTrue);
    expect(stock('400').isBoxSpeed(800), isFalse);
  });
}
