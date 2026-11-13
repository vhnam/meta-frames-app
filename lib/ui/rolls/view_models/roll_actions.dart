import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/sync/pending_op.dart';
import '../../../domain/models/models.dart';
import '../../../domain/models/roll_requests.dart';
import '../../../domain/utils.dart';
import '../../../providers.dart';

/// The server answered an add with rolls that are not the ones asked for:
/// the idempotency key had already been used by an earlier attempt with other
/// values, and the server replayed that one. Nothing was added twice; the
/// changes made since were not sent.
class EarlierRollsReplayed implements Exception {
  EarlierRollsReplayed(this.added);
  final List<RollSummary> added;
  @override
  String toString() =>
      'An earlier attempt already added ${added.length} roll${added.length == 1 ? '' : 's'}'
      '${added.isEmpty ? '' : ' of ${added.first.stockLabel}'}. '
      'Your later changes were not sent: check them and save again.';
}

/// Writes that change rolls. Each one refreshes only the data it can affect.
class RollActions {
  RollActions(this._ref);
  final Ref _ref;

  /// Lists that show roll status, stock counts or loaded rolls.
  void _invalidateRollLists() => _ref
    ..invalidate(rollsProvider)
    ..invalidate(inventoryProvider)
    ..invalidate(expiryProvider)
    ..invalidate(camerasProvider)
    ..invalidate(cameraProvider)
    // A job's entry names the roll's stock.
    ..invalidate(negativesAtLabProvider);

  /// Adds rolls under [idempotencyKey], which the caller keeps (with its
  /// draft) across retries and restarts, so a request that landed but whose
  /// answer was lost is never added again.
  Future<List<RollSummary>> add(
    NewRolls rolls, {
    required String idempotencyKey,
  }) async {
    final added = await _ref
        .read(rollRepositoryProvider)
        .addRolls(rolls, idempotencyKey: idempotencyKey);
    _invalidateRollLists();
    final same =
        added.length == rolls.quantity &&
        added.every(
          (r) =>
              r.filmStockId == rolls.filmStockId &&
              r.format == rolls.format &&
              r.exposures == rolls.exposures,
        );
    if (!same) throw EarlierRollsReplayed(added);
    return added;
  }

  /// Replaces the roll if it is still at [version] (the one the form was
  /// opened with). A newer change gets `412 roll_changed` and nothing is
  /// written: the form then shows what changed and the user decides.
  Future<void> edit(String rollId, RollEdit edit, {int? version}) async {
    await _ref
        .read(rollRepositoryProvider)
        .update(rollId, edit, version: version);
    _ref.invalidate(rollDetailProvider(rollId));
    _invalidateRollLists();
  }

  Future<void> delete(String rollId) async {
    await _ref.read(rollRepositoryProvider).delete(rollId);
    _ref.invalidate(rollDetailProvider(rollId));
    _invalidateRollLists();
  }

  /// Loads [roll] into [camera]. With a partition open it is recorded on the
  /// phone and shown at once, and sent after anything earlier on this roll or
  /// camera (such as finishing the roll that was in it).
  Future<void> load(
    RollSummary roll,
    Camera camera,
    LoadRollRequest request,
  ) async {
    final store = _ref.read(localStoreProvider);
    if (store == null) {
      await _ref.read(rollRepositoryProvider).load(roll.id, request);
    } else {
      await store.enqueueStep(
        kind: OpKind.load,
        rollId: roll.id,
        cameraId: camera.id,
        payload: {
          ...request.toJson(),
          // Shown on the camera and the roll until the server answers.
          'cameraName': camera.name,
          'fixedLens': camera.hasFixedLens,
          'stockId': roll.filmStockId,
          'stockBrand': roll.stockBrand,
          'stockName': roll.stockName,
        },
      );
      unawaited(_ref.read(partitionControllerProvider).sync());
    }
    _ref.invalidate(rollDetailProvider(roll.id));
    _invalidateRollLists();
  }

  /// Finishes the roll in [cameraId] on [date] (always sent explicitly, so a
  /// replay on another day is not mistaken for this one).
  Future<void> finish(String rollId, DateTime date, {String? cameraId}) async {
    final store = _ref.read(localStoreProvider);
    if (store == null) {
      await _ref.read(rollRepositoryProvider).finish(rollId, date);
    } else {
      await store.enqueueStep(
        kind: OpKind.finish,
        rollId: rollId,
        cameraId: cameraId ?? await _cameraHolding(rollId),
        payload: {'date': ymd(date)},
      );
      unawaited(_ref.read(partitionControllerProvider).sync());
    }
    _ref.invalidate(rollDetailProvider(rollId));
    _invalidateRollLists();
  }

  /// The camera the roll is in, as the phone knows it.
  Future<String?> _cameraHolding(String rollId) async {
    try {
      final cams = await _ref.read(camerasProvider.future);
      for (final c in cams) {
        if (c.loadedRoll?.rollId == rollId) return c.id;
      }
    } on Object {
      // Unknown: the finish then waits only for this roll's earlier steps.
    }
    return null;
  }

  /// Sends the plan straight to the server (never queued on the phone) and
  /// refreshes only after the server took it, so a failed save shows nothing
  /// new. The plan can move the roll's stage, so the lists refresh too.
  Future<void> setPlan(String rollId, RollPlan plan) async {
    await _ref.read(rollRepositoryProvider).setPlan(rollId, plan);
    _ref
      ..invalidate(rollDetailProvider(rollId))
      ..invalidate(rollsProvider);
  }

  /// Marks or unmarks the roll for a scan, online only like [setPlan]. The
  /// mark shows in the details and the Rolls list's Needs scan filter.
  Future<void> setNeedsScan(String rollId, bool needed) async {
    await _ref.read(rollRepositoryProvider).setNeedsScan(rollId, needed);
    _ref
      ..invalidate(rollDetailProvider(rollId))
      ..invalidate(rollsProvider);
  }

  /// Records the develop date, online only like [setPlan]. On a `409`/`422`
  /// it throws the server's reason and refreshes nothing.
  Future<void> markDeveloped(String rollId, DevelopedInput input) async {
    await _ref.read(rollRepositoryProvider).markDeveloped(rollId, input);
    _ref
      ..invalidate(rollDetailProvider(rollId))
      ..invalidate(rollsProvider);
  }

  /// Returns the negatives of handoff [handoffId], online only like
  /// [setPlan]. Every job of the handoff gets the return date, so the jobs,
  /// the roll and the lists that show where the negatives are all refresh.
  /// A roll without a handoff id returns its negatives job by job instead.
  Future<void> returnHandoff(String handoffId, DateTime date) async {
    final roll = await _ref
        .read(rollRepositoryProvider)
        .returnHandoff(handoffId, date);
    _ref
      ..invalidate(rollDetailProvider(roll.id))
      ..invalidate(processingProvider)
      ..invalidate(rollsProvider)
      ..invalidate(expiryProvider)
      ..invalidate(negativesAtLabProvider);
  }

  Future<void> setLenses(String rollId, List<String> lensIds) async {
    await _ref.read(rollRepositoryProvider).setLenses(rollId, lensIds);
    _ref
      ..invalidate(rollDetailProvider(rollId))
      // The Rolls filter finds rolls by lens.
      ..invalidate(rollsProvider);
  }
}

final rollActionsProvider = Provider<RollActions>(RollActions.new);

/// What the roll Details screen offers. The stage picks how the roll reads;
/// the raw status, jobs, who holds the negatives and the plan pick what is
/// valid.
enum DetailAction {
  loadRoll,
  logFrame,
  finish,
  startHomeDevelop,
  handToLab,

  /// The "how is it processed" sheet: no plan step chosen yet.
  choosePlan,
  markDeveloped,

  /// Opens the one job to record on ([DetailActions.jobId]).
  openJob,

  /// Several jobs fit, or none is known: pick one in the history. The app
  /// never picks a job to write on by itself.
  pickJob,
  startHomeScan,

  /// The "where is it scanned" sheet.
  chooseScanPlace,

  /// Returns the negatives by the roll's `openHandoffId`.
  returnHandoff,

  /// A roll from before handoffs: opens the job whose negatives the lab holds
  /// ([DetailActions.jobId]) to return them there.
  returnJob,
  changePlan,
  markNeedsScan,
  unmarkNeedsScan,

  /// Too little is known to write (a roll cached without its stage).
  refresh,
}

/// The main button, the job it opens when it is [DetailAction.openJob] or
/// [DetailAction.returnJob], and the other valid actions for the menu.
typedef DetailActions = ({
  DetailAction? primary,
  String? jobId,
  List<DetailAction> menu,
});

/// Ports the dashboard's detail rules (types.ts, canHandOver in rollList.ts)
/// in the order of the mobile rolls handoff.
DetailActions detailActions(RollDetail detail) {
  final roll = detail.roll;
  final jobs = detail.processing;
  final openJobs = jobs.where((job) => job.isOpen).toList();
  final atLab = roll.negativesAtLab;
  final stage = roll.stage;
  final stageDetail = roll.stageDetail;

  // [action] on the one open job that fits; several or none: pick in the
  // history, or refresh when the roll has no job at all.
  (DetailAction, String?) jobFor(
    bool Function(Processing job) fits, {
    DetailAction action = DetailAction.openJob,
    bool openOnly = true,
  }) {
    final fitting = (openOnly ? openJobs : jobs).where(fits).toList();
    if (fitting.length == 1) return (action, fitting.single.id);
    return (jobs.isEmpty ? DetailAction.refresh : DetailAction.pickJob, null);
  }

  // The lab still holds the film: returning it comes first.
  (DetailAction, String?)? giveBack() {
    if (roll.openHandoffId != null) return (DetailAction.returnHandoff, null);
    if (!atLab) return null;
    return jobFor(
      (job) => !job.isHome && job.negativesReturnedAt == null,
      action: DetailAction.returnJob,
      // A lab scan job closes on its scans while the lab keeps the negatives.
      openOnly: false,
    );
  }

  final homeDevelop = canStartHomeDevelop(
    roll.status,
    jobs,
    negativesAtLab: atLab,
  );
  final markDeveloped = canMarkDeveloped(
    roll.status,
    jobs,
    negativesAtLab: atLab,
  );
  // A home scan needs the negatives at home, so it is not offered while a
  // lab holds them.
  final homeScan =
      !atLab &&
      canStartHomeScan(
        roll.status,
        stageDetail,
        needsScan: roll.needsScan == true,
      );
  final waiting = switch (stageDetail) {
    StageDetail.waitingScan ||
    StageDetail.waitingHomeScan ||
    StageDetail.waitingLabScan => true,
    _ => false,
  };

  final (primary, jobId) = switch (stage) {
    null => (DetailAction.refresh, null),
    RollLifecycleStage.inStock => (DetailAction.loadRoll, null),
    RollLifecycleStage.inCamera => (DetailAction.logFrame, null),
    RollLifecycleStage.doneShooting => switch (roll.plan?.developBy) {
      StepActor.self when homeDevelop => (DetailAction.startHomeDevelop, null),
      StepActor.self => giveBack() ?? (null, null),
      StepActor.lab => (DetailAction.handToLab, null),
      null => (DetailAction.choosePlan, null),
    },
    RollLifecycleStage.processing when waiting && atLab =>
      giveBack() ?? (null, null),
    RollLifecycleStage.processing => switch (stageDetail) {
      StageDetail.labDeveloping || StageDetail.homeDeveloping =>
        markDeveloped
            ? (DetailAction.markDeveloped, null)
            : jobFor((job) => job.type.developsFilm),
      StageDetail.labScanning ||
      StageDetail.homeScanning ||
      StageDetail.rescanning => jobFor((job) => job.type.hasScans),
      StageDetail.printing => jobFor((job) => job.type == ProcessingType.print),
      StageDetail.waitingHomeScan => (DetailAction.startHomeScan, null),
      StageDetail.waitingLabScan => (DetailAction.handToLab, null),
      StageDetail.waitingScan => (DetailAction.chooseScanPlace, null),
      null => jobFor((_) => true),
    },
    RollLifecycleStage.completed =>
      giveBack() ??
          (roll.needsScan == true
              ? switch (roll.plan?.scanBy) {
                  StepActor.self when homeScan => (
                    DetailAction.startHomeScan,
                    null,
                  ),
                  StepActor.self => (null, null),
                  StepActor.lab => (DetailAction.handToLab, null),
                  null => (DetailAction.chooseScanPlace, null),
                }
              : (null, null)),
  };

  final afterShooting =
      stage == RollLifecycleStage.doneShooting ||
      stage == RollLifecycleStage.processing ||
      stage == RollLifecycleStage.completed;
  final canHandOver =
      stage == RollLifecycleStage.doneShooting ||
      (stage == RollLifecycleStage.processing && waiting) ||
      (stage == RollLifecycleStage.completed && roll.needsScan == true);
  final menu = [
    if (stage == RollLifecycleStage.inCamera) DetailAction.finish,
    // A roll with no job can start a home develop or record one done.
    if (afterShooting && homeDevelop) DetailAction.startHomeDevelop,
    if (afterShooting && markDeveloped) DetailAction.markDeveloped,
    if (afterShooting && homeScan) DetailAction.startHomeScan,
    if (canHandOver) DetailAction.handToLab,
    if (roll.openHandoffId != null) DetailAction.returnHandoff,
    // The plan and the scan mark can be set ahead, while still shooting.
    if (stage != null) DetailAction.changePlan,
    if (stage != null && roll.needsScan == false) DetailAction.markNeedsScan,
    if (stage != null && roll.needsScan == true) DetailAction.unmarkNeedsScan,
  ]..remove(primary);
  return (primary: primary, jobId: jobId, menu: menu);
}
