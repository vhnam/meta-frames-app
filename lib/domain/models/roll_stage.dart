import 'models.dart';

/// The dashboard's labels (RollStageBadge.vue), so a roll reads the same on
/// both.
String stageLabel(RollLifecycleStage stage) => switch (stage) {
  RollLifecycleStage.inStock => 'In stock',
  RollLifecycleStage.inCamera => 'In camera',
  RollLifecycleStage.doneShooting => 'Done shooting',
  RollLifecycleStage.processing => 'Processing',
  RollLifecycleStage.completed => 'Completed',
};

String stageDetailLabel(StageDetail detail) => switch (detail) {
  StageDetail.labDeveloping => 'Lab developing',
  StageDetail.labScanning => 'Lab scanning',
  StageDetail.homeDeveloping => 'Developing at home',
  StageDetail.homeScanning => 'Scanning at home',
  StageDetail.rescanning => 'Rescanning',
  StageDetail.waitingScan => 'Waiting for scan',
  StageDetail.waitingHomeScan => 'Waiting to scan at home',
  StageDetail.waitingLabScan => 'Waiting for lab scan',
  StageDetail.printing => 'Printing',
};

/// One label per roll: what a processing roll is waiting for, else its stage.
/// A roll cached without a stage shows its plain status until a refresh.
String rollStageLabel(RollSummary roll) =>
    switch ((roll.stage, roll.stageDetail)) {
      (_, final detail?) => stageDetailLabel(detail),
      (final stage?, null) => stageLabel(stage),
      (null, null) => roll.status.label,
    };

/// Whether [rollStageLabel] already says a lab has the roll, so a separate
/// "Negatives at lab" stamp would repeat it.
bool stageLabelSaysLab(RollSummary roll) =>
    roll.stageDetail == StageDetail.labDeveloping ||
    roll.stageDetail == StageDetail.labScanning ||
    (roll.stage == null && roll.status == RollStatus.atLab);
