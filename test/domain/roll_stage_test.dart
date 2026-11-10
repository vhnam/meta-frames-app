import 'package:flutter_test/flutter_test.dart';
import 'package:meta_frames/domain/models/models.dart';
import 'package:meta_frames/domain/models/roll_stage.dart';

import '../testing/fakes.dart';

void main() {
  RollStage? stage(
    String status, {
    bool? developed,
    bool? scanned,
    List<String>? open,
    bool? openAtLab,
  }) => rollStage(
    roll(
      'r',
      status: status,
      developed: developed,
      scanned: scanned,
      openJobTypes: open,
      openAtLab: openAtLab,
    ),
  );

  group('at the lab, the open jobs give the steps', () {
    test('develop only', () {
      expect(
        stage('at_lab', developed: false, scanned: false, open: ['develop']),
        (open: true, atHome: false, develop: true, scan: false, print: false),
      );
    });
    test('develop + scan in one job', () {
      expect(stage('at_lab', open: ['develop_scan']), (
        open: true,
        atHome: false,
        develop: true,
        scan: true,
        print: false,
      ));
    });
    test('scan only: rescan after developing, or old negatives', () {
      expect(stage('at_lab', developed: true, open: ['scan']), (
        open: true,
        atHome: false,
        develop: false,
        scan: true,
        print: false,
      ));
    });
    test('print', () {
      expect(stage('at_lab', open: ['print']), (
        open: true,
        atHome: false,
        develop: false,
        scan: false,
        print: true,
      ));
    });
  });

  group('processed at home', () {
    test('no open job at a lab: at home, with the open steps', () {
      expect(stage('at_lab', open: ['develop'], openAtLab: false), (
        open: true,
        atHome: true,
        develop: true,
        scan: false,
        print: false,
      ));
    });
    test('an open lab job too: at the lab', () {
      expect(stage('at_lab', open: ['develop', 'print'], openAtLab: true), (
        open: true,
        atHome: false,
        develop: true,
        scan: false,
        print: true,
      ));
    });
    test('without openAtLab (older server): at the lab', () {
      expect(stage('at_lab', open: ['develop'])?.atHome, isFalse);
    });
    test('only in All: under no status chip', () {
      final r = roll(
        'r',
        status: 'at_lab',
        developed: false,
        scanned: false,
        openJobTypes: ['develop'],
        openAtLab: false,
      );
      for (final s in RollStatus.values) {
        expect(inStatusChip(r, s), isFalse, reason: s.wire);
      }
    });
    test(
      'developed at a lab, then an open home scan: under no status chip',
      () {
        final r = roll(
          'r',
          status: 'at_lab',
          developed: true,
          scanned: true,
          openJobTypes: ['scan'],
          openAtLab: false,
        );
        for (final s in RollStatus.values) {
          expect(inStatusChip(r, s), isFalse, reason: s.wire);
        }
      },
    );
    test('without openAtLab the roll stays under At lab', () {
      final r = roll('r', status: 'at_lab', openJobTypes: ['develop']);
      expect(inStatusChip(r, RollStatus.atLab), isTrue);
    });
  });

  group('back from the lab, the recorded results give the steps', () {
    test('develop only', () {
      expect(stage('developed', developed: true, scanned: false), (
        open: false,
        atHome: false,
        develop: true,
        scan: false,
        print: false,
      ));
    });
    test('develop + scan, in one job or a later scan job', () {
      expect(stage('scanned', developed: true, scanned: true), (
        open: false,
        atHome: false,
        develop: true,
        scan: true,
        print: false,
      ));
    });
    test('scan only, for old negatives', () {
      expect(stage('scanned', developed: false, scanned: true), (
        open: false,
        atHome: false,
        develop: false,
        scan: true,
        print: false,
      ));
    });
    test('print only', () {
      expect(stage('developed', developed: false, scanned: false), (
        open: false,
        atHome: false,
        develop: false,
        scan: false,
        print: true,
      ));
    });
  });

  test('without the job fields every roll falls back to its status', () {
    for (final s in RollStatus.values) {
      expect(stage(s.wire), isNull, reason: s.wire);
    }
  });

  group('status chips', () {
    test('a developed and scanned roll is under both chips', () {
      final r = roll('r', status: 'scanned', developed: true, scanned: true);
      expect(inStatusChip(r, RollStatus.developed), isTrue);
      expect(inStatusChip(r, RollStatus.scanned), isTrue);
    });
    test('scan only is not under Developed', () {
      final r = roll('r', status: 'scanned', developed: false, scanned: true);
      expect(inStatusChip(r, RollStatus.developed), isFalse);
      expect(inStatusChip(r, RollStatus.scanned), isTrue);
    });
    test('a roll sent for a rescan stays under Developed and At lab', () {
      final r = roll('r', status: 'at_lab', developed: true, scanned: false);
      expect(inStatusChip(r, RollStatus.developed), isTrue);
      expect(inStatusChip(r, RollStatus.atLab), isTrue);
      expect(inStatusChip(r, RollStatus.scanned), isFalse);
    });
    test('without the job fields the chip follows the status', () {
      final r = roll('r', status: 'scanned');
      expect(inStatusChip(r, RollStatus.scanned), isTrue);
      expect(inStatusChip(r, RollStatus.developed), isFalse);
    });
  });
}
