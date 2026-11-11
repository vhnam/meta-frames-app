import 'package:flutter_test/flutter_test.dart';
import 'package:meta_frames/domain/models/models.dart';
import 'package:meta_frames/domain/models/roll_stage.dart';

void main() {
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

  group('stage label', () {
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

    test('the processing detail wins over the stage', () {
      final roll = summary('at_lab', {
        'stage': 'processing',
        'stageDetail': 'waiting_lab_scan',
      });
      expect(
        rollStageLabel(roll),
        stageDetailLabel(StageDetail.waitingLabScan),
      );
      expect(
        rollStageLabel(summary('scanned', {'stage': 'completed'})),
        stageLabel(RollLifecycleStage.completed),
      );
    });

    test('a roll cached without a stage shows its plain status', () {
      expect(rollStageLabel(summary('developed')), RollStatus.developed.label);
    });

    test('only a lab step or an old at-lab status says the lab has it', () {
      expect(
        stageLabelSaysLab(
          summary('at_lab', {
            'stage': 'processing',
            'stageDetail': 'lab_developing',
          }),
        ),
        isTrue,
      );
      expect(stageLabelSaysLab(summary('at_lab')), isTrue);
      // Completed while the lab still holds the negatives: say it apart.
      expect(
        stageLabelSaysLab(
          summary('developed', {'stage': 'completed', 'negativesAtLab': true}),
        ),
        isFalse,
      );
      expect(
        stageLabelSaysLab(
          summary('at_lab', {
            'stage': 'processing',
            'stageDetail': 'home_scanning',
          }),
        ),
        isFalse,
      );
    });
  });
}
