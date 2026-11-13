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

  group('detail rules', () {
    Processing job({
      String type = 'develop',
      bool isOpen = true,
      String? developedAt,
      String? negativesReturnedAt,
    }) => Processing.fromJson({
      'id': 'j1',
      'rollId': 'r1',
      'labId': 'lab1',
      'type': type,
      'process': 'C-41',
      'sentAt': '2026-10-02',
      'developedAt': developedAt,
      'negativesReturnedAt': negativesReturnedAt,
      'isOpen': isOpen,
    });

    test('Mark developed: an open develop job without its date, or no job', () {
      bool can(RollStatus status, List<Processing> jobs, bool atLab) =>
          canMarkDeveloped(status, jobs, negativesAtLab: atLab);
      expect(can(RollStatus.atLab, [job()], true), isTrue);
      expect(can(RollStatus.atLab, [job(type: 'develop_scan')], false), isTrue);
      expect(can(RollStatus.doneShooting, [], false), isTrue);
      // The last lab job was cancelled but the lab still holds the roll.
      expect(can(RollStatus.doneShooting, [], true), isFalse);
      expect(
        can(RollStatus.atLab, [job(developedAt: '2026-10-03')], false),
        isFalse,
      );
      // An old develop + scan job with the negatives back is developed.
      expect(
        can(RollStatus.atLab, [
          job(type: 'develop_scan', negativesReturnedAt: '2026-10-04'),
        ], false),
        isFalse,
      );
      expect(can(RollStatus.developed, [job(isOpen: false)], false), isFalse);
      expect(can(RollStatus.scanned, [job(type: 'scan')], false), isFalse);
    });

    test('a home develop needs a finished roll with no job, home', () {
      expect(
        canStartHomeDevelop(RollStatus.doneShooting, [], negativesAtLab: false),
        isTrue,
      );
      expect(
        canStartHomeDevelop(RollStatus.doneShooting, [
          job(isOpen: false),
        ], negativesAtLab: false),
        isFalse,
      );
      expect(
        canStartHomeDevelop(RollStatus.developed, [], negativesAtLab: false),
        isFalse,
      );
    });

    test(
      'a home scan: waiting for a scan, or marked where a scan job fits',
      () {
        bool can(RollStatus status, StageDetail? detail, bool needsScan) =>
            canStartHomeScan(status, detail, needsScan: needsScan);
        expect(
          can(RollStatus.developed, StageDetail.waitingScan, false),
          isTrue,
        );
        expect(
          can(RollStatus.developed, StageDetail.waitingLabScan, false),
          isTrue,
        );
        expect(can(RollStatus.scanned, null, true), isTrue);
        expect(
          can(RollStatus.scanned, StageDetail.labScanning, false),
          isFalse,
        );
        expect(can(RollStatus.scanned, null, false), isFalse);
        expect(can(RollStatus.doneShooting, null, true), isTrue);
        // Developed by a lab that still holds it: passes; the caller says why.
        expect(
          can(RollStatus.atLab, StageDetail.waitingHomeScan, false),
          isTrue,
        );
        // Marked while still developing at home: no scan job yet.
        expect(
          can(RollStatus.atLab, StageDetail.homeDeveloping, true),
          isFalse,
        );
      },
    );
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
