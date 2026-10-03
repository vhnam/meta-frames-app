import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/roll_requests.dart';
import '../../../providers.dart';

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
    ..invalidate(cameraProvider);

  Future<void> add(NewRolls rolls) async {
    await _ref.read(rollRepositoryProvider).addRolls(rolls);
    _invalidateRollLists();
  }

  Future<void> edit(String rollId, RollEdit edit) async {
    await _ref.read(rollRepositoryProvider).update(rollId, edit);
    _ref.invalidate(rollDetailProvider(rollId));
    _invalidateRollLists();
  }

  Future<void> delete(String rollId) async {
    await _ref.read(rollRepositoryProvider).delete(rollId);
    _ref.invalidate(rollDetailProvider(rollId));
    _invalidateRollLists();
  }

  Future<void> load(String rollId, LoadRollRequest request) async {
    await _ref.read(rollRepositoryProvider).load(rollId, request);
    _ref.invalidate(rollDetailProvider(rollId));
    _invalidateRollLists();
  }

  Future<void> finish(String rollId, DateTime date) async {
    await _ref.read(rollRepositoryProvider).finish(rollId, date);
    _ref.invalidate(rollDetailProvider(rollId));
    _invalidateRollLists();
  }

  Future<void> setLenses(String rollId, List<String> lensIds) async {
    await _ref.read(rollRepositoryProvider).setLenses(rollId, lensIds);
    _ref.invalidate(rollDetailProvider(rollId));
  }
}

final rollActionsProvider = Provider<RollActions>(RollActions.new);
