import 'package:flutter_test/flutter_test.dart';
import 'package:meta_frames/domain/models/models.dart';

final _options = [
  ScanOption.fromJson({
    'key': 'format',
    'label': 'Format',
    'type': 'enum',
    'values': [
      {'value': 'jpeg', 'label': 'JPEG'},
      {'value': 'tiff', 'label': 'TIFF'},
    ],
    'default': 'jpeg',
  }),
  ScanOption.fromJson({
    'key': 'dust',
    'label': 'Dust removal',
    'type': 'boolean',
    'default': false,
  }),
  ScanOption.fromJson({
    'key': 'dpi',
    'label': 'DPI',
    'type': 'integer',
    'min': 100,
    'max': 200,
    'default': 150,
  }),
];

void main() {
  test('fills every option with its default', () {
    expect(completeSettings(_options, {}), {
      'format': 'jpeg',
      'dust': false,
      'dpi': 150,
    });
  });

  test('keeps values the options allow', () {
    final kept = {'format': 'tiff', 'dust': true, 'dpi': 200};
    expect(completeSettings(_options, kept), kept);
  });

  test('replaces values the options refuse with the default', () {
    expect(completeSettings(_options, {'format': 'png', 'dpi': 999}), {
      'format': 'jpeg',
      'dust': false,
      'dpi': 150,
    });
  });

  test('drops keys of another kind, which the server refuses', () {
    expect(
      completeSettings(_options, {'pixel_shift': true}).keys,
      isNot(contains('pixel_shift')),
    );
  });
}
