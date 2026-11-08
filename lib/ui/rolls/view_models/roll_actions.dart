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

  Future<void> setLenses(String rollId, List<String> lensIds) async {
    await _ref.read(rollRepositoryProvider).setLenses(rollId, lensIds);
    _ref
      ..invalidate(rollDetailProvider(rollId))
      // The Rolls filter finds rolls by lens.
      ..invalidate(rollsProvider);
  }
}

final rollActionsProvider = Provider<RollActions>(RollActions.new);
