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

  group('server stage fields', () {
    RollSummary summary(String status, [Map<String, dynamic>? more]) =>
        RollSummary.fromJson({
          'id': 'roll',
          'filmStockId': 's1',
          'stockBrand': 'Kodak',
          'stockName': 'Gold',
          'format': 135,
          'exposures': 36,
          'status': status,
          ...?more,
        });

    test('every stage and detail in the OpenAPI enums is read', () {
      // Wire strings copied from RollSummary in openapi.yaml, not from the enums.
      const stages = {
        'in_stock': RollLifecycleStage.inStock,
        'in_camera': RollLifecycleStage.inCamera,
        'done_shooting': RollLifecycleStage.doneShooting,
        'processing': RollLifecycleStage.processing,
        'completed': RollLifecycleStage.completed,
      };
      const details = {
        'lab_developing': StageDetail.labDeveloping,
        'lab_scanning': StageDetail.labScanning,
        'home_developing': StageDetail.homeDeveloping,
        'home_scanning': StageDetail.homeScanning,
        'rescanning': StageDetail.rescanning,
        'waiting_scan': StageDetail.waitingScan,
        'waiting_home_scan': StageDetail.waitingHomeScan,
        'waiting_lab_scan': StageDetail.waitingLabScan,
        'printing': StageDetail.printing,
      };
      for (final MapEntry(key: wire, value: stage) in stages.entries) {
        expect(summary('at_lab', {'stage': wire}).stage, stage, reason: wire);
      }
      for (final MapEntry(key: wire, value: detail) in details.entries) {
        final roll = summary('at_lab', {
          'stage': 'processing',
          'stageDetail': wire,
        });
        expect(roll.stageDetail, detail, reason: wire);
      }
    });

    test('the server stage wins over the status', () {
      // Raw status developed, but the server says the roll is completed.
      final roll = summary('developed', {
        'stage': 'completed',
        'needsScan': true,
      });
      expect(roll.stage, RollLifecycleStage.completed);
      expect(roll.needsScan, isTrue);
    });

    test('an old cache settles the stage only from pre-processing status', () {
      expect(summary('in_stock').stage, RollLifecycleStage.inStock);
      expect(summary('in_camera').stage, RollLifecycleStage.inCamera);
      expect(summary('done_shooting').stage, RollLifecycleStage.doneShooting);
      for (final status in ['at_lab', 'developed', 'scanned']) {
        expect(summary(status).stage, isNull, reason: status);
      }
    });

    test('an old cache leaves needsScan and plan unknown, not cleared', () {
      final roll = summary('scanned');
      expect(roll.needsScan, isNull);
      expect(roll.plan, isNull);
      expect(roll.stageDetail, isNull);
      expect(roll.openHandoffId, isNull);
    });

    test('an unknown stage or detail does not break the roll', () {
      final roll = summary('at_lab', {
        'stage': 'archived',
        'stageDetail': 'drying',
      });
      expect(roll.stage, isNull);
      expect(roll.stageDetail, isNull);
    });

    test('plan fields left out are undecided', () {
      final empty = summary('done_shooting', {'plan': <String, dynamic>{}});
      expect(empty.plan, isNotNull);
      expect(empty.plan!.target, isNull);
      expect(empty.plan!.developBy, isNull);
      expect(empty.plan!.scanBy, isNull);
    });

    test('a full plan and the open handoff are read', () {
      final roll = summary('done_shooting', {
        'plan': {'target': 'scanned', 'developBy': 'lab', 'scanBy': 'self'},
        'openHandoffId': 'h1',
      });
      expect(roll.plan!.target, PlanTarget.scanned);
      expect(roll.plan!.developBy, StepActor.lab);
      expect(roll.plan!.scanBy, StepActor.self);
      expect(roll.openHandoffId, 'h1');
    });

    test('a job reads its developed date', () {
      final job = Processing.fromJson({
        'id': 'j1',
        'rollId': 'roll',
        'type': 'develop',
        'process': 'C-41',
        'sentAt': '2026-11-01',
        'developedAt': '2026-11-03',
        'scanOrders': [],
        'isOpen': true,
      });
      expect(job.developedAt, DateTime(2026, 11, 3));
    });
  });
}
