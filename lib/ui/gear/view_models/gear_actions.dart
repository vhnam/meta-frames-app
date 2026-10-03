import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/gear_requests.dart';
import '../../../domain/models/models.dart';
import '../../../providers.dart';

/// Writes that change cameras. Each refreshes only the data it can affect.
class CameraActions {
  CameraActions(this._ref);
  final Ref _ref;

  /// Creates a camera, or updates [existing]. For a camera with interchangeable
  /// lenses, [lensIds] replaces its linked lenses; pass null to leave them.
  Future<Camera> save(
    CameraEdit camera, {
    Camera? existing,
    Set<String>? lensIds,
  }) async {
    final repo = _ref.read(cameraRepositoryProvider);
    final saved = existing == null
        ? await repo.create(camera)
        : await repo.update(existing.id, camera);
    if (!camera.hasFixedLens && lensIds != null) {
      await repo.setLenses(saved.id, lensIds.toList());
    }
    _ref
      ..invalidate(camerasProvider)
      ..invalidate(cameraProvider(saved.id))
      ..invalidate(cameraLensesProvider)
      ..invalidate(lensCamerasProvider)
      // A fixed-lens camera owns a built-in lens.
      ..invalidate(lensesProvider)
      // Roll cards and details show the camera name.
      ..invalidate(rollsProvider)
      ..invalidate(rollDetailProvider);
    return saved;
  }

  Future<void> setActive(Camera camera, bool active) async {
    await _ref.read(cameraRepositoryProvider).setActive(camera.id, active);
    _ref
      ..invalidate(camerasProvider)
      ..invalidate(cameraProvider(camera.id))
      // A built-in lens follows its camera.
      ..invalidate(lensesProvider)
      ..invalidate(lensProvider);
  }

  Future<void> delete(String cameraId) async {
    await _ref.read(cameraRepositoryProvider).delete(cameraId);
    _ref
      ..invalidate(camerasProvider)
      ..invalidate(cameraProvider(cameraId))
      ..invalidate(lensesProvider)
      ..invalidate(lensCamerasProvider);
  }

  Future<void> setLenses(String cameraId, List<String> lensIds) async {
    await _ref.read(cameraRepositoryProvider).setLenses(cameraId, lensIds);
    _ref
      ..invalidate(cameraLensesProvider(cameraId))
      ..invalidate(lensCamerasProvider);
  }
}

final cameraActionsProvider = Provider<CameraActions>(CameraActions.new);

/// Which cameras a lens should be linked to when it is saved.
class LensLinks {
  const LensLinks({
    required this.cameras,
    required this.wanted,
    required this.initial,
  });

  /// Cameras the user could see and change.
  final List<Camera> cameras;

  /// Camera ids ticked now, and ticked when the form opened.
  final Set<String> wanted, initial;
}

/// Writes that change lenses.
class LensActions {
  LensActions(this._ref);
  final Ref _ref;

  /// Creates a lens, or updates [existing], then adds or removes it from the
  /// cameras in [links] whose tick changed.
  Future<Lens> save(LensEdit lens, {Lens? existing, LensLinks? links}) async {
    final saved = existing == null
        ? await _ref.read(lensRepositoryProvider).create(lens)
        : await _ref.read(lensRepositoryProvider).update(existing.id, lens);
    if (links != null) {
      await _syncLinks(saved, links, editing: existing != null);
    }
    _ref
      ..invalidate(lensesProvider)
      ..invalidate(lensProvider(saved.id))
      ..invalidate(lensCamerasProvider)
      ..invalidate(cameraLensesProvider)
      // Roll details list the lenses used.
      ..invalidate(rollDetailProvider);
    return saved;
  }

  Future<void> _syncLinks(
    Lens lens,
    LensLinks links, {
    required bool editing,
  }) async {
    final cameras = _ref.read(cameraRepositoryProvider);
    for (final c in links.cameras) {
      final want = links.wanted.contains(c.id);
      final had = links.initial.contains(c.id);
      if (want == had && editing) continue;
      if (!want && !had) continue;
      final current = (await cameras.lenses(c.id)).map((l) => l.id).toSet();
      want ? current.add(lens.id) : current.remove(lens.id);
      await cameras.setLenses(c.id, current.toList());
    }
  }

  Future<void> setActive(String lensId, bool active) async {
    await _ref.read(lensRepositoryProvider).setActive(lensId, active);
    _ref
      ..invalidate(lensesProvider)
      ..invalidate(lensProvider(lensId))
      ..invalidate(cameraLensesProvider);
  }

  Future<void> delete(String lensId) async {
    await _ref.read(lensRepositoryProvider).delete(lensId);
    _ref
      ..invalidate(lensesProvider)
      ..invalidate(lensProvider(lensId))
      ..invalidate(lensCamerasProvider)
      ..invalidate(cameraLensesProvider);
  }
}

final lensActionsProvider = Provider<LensActions>(LensActions.new);
