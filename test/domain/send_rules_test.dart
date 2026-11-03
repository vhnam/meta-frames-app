import 'package:flutter_test/flutter_test.dart';
import 'package:meta_frames/domain/models/models.dart';

void main() {
  group('sendableTypes', () {
    test('a finished roll with no job can have any service', () {
      expect(sendableTypes(RollStatus.doneShooting, 0), ProcessingType.values);
    });

    test('developing happens once', () {
      for (final status in [
        RollStatus.doneShooting,
        RollStatus.developed,
        RollStatus.scanned,
      ]) {
        expect(sendableTypes(status, 1), [
          ProcessingType.scan,
          ProcessingType.print,
        ]);
      }
    });

    test('nothing while the roll is unfinished or at the lab', () {
      for (final status in [
        RollStatus.inStock,
        RollStatus.inCamera,
        RollStatus.atLab,
      ]) {
        expect(sendableTypes(status, 0), isEmpty);
      }
    });
  });

  test('a scan takes a negatives date only from a lab', () {
    const scan = ProcessingType.scan;
    expect(scan.recordsNegativesReturned(atLab: true), isTrue);
    expect(scan.recordsNegativesReturned(atLab: false), isFalse);
    expect(ProcessingType.print.recordsNegativesReturned(atLab: false), isTrue);
  });

  group('describeSettings', () {
    final options = [
      ScanOption.fromJson({
        'key': 'format',
        'label': 'Format',
        'type': 'enum',
        'values': [
          {'value': 'tiff', 'label': 'TIFF'},
        ],
        'default': 'tiff',
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
        'default': 100,
      }),
    ];

    test('reads in option order, and a boolean off says nothing', () {
      expect(
        describeSettings({
          'dpi': 3200,
          'dust': false,
          'format': 'tiff',
        }, options),
        'TIFF · DPI: 3200',
      );
    });

    test('names a key it does not know', () {
      expect(describeSettings({'old': 1}, options), 'old: 1');
    });

    test('says when there is nothing to show', () {
      expect(describeSettings({}, options), 'Default settings');
    });
  });
}
