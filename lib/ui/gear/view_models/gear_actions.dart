import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/gear_requests.dart';
import '../../../domain/models/models.dart';
import '../../../providers.dart';

/// Quick add of cameras. The dashboard edits them.
class CameraActions {
  CameraActions(this._ref);
  final Ref _ref;

  /// Creates a camera (at client id [id] when given).
  Future<Camera> save(CameraEdit camera, {String? id}) async {
    final saved = await _ref
        .read(cameraRepositoryProvider)
        .create(camera, id: id);
    return _saved(saved);
  }

  /// After a create at [id] was refused because the id is taken: the camera
  /// at [id] if it is this create's (the earlier attempt landed), else null.
  Future<Camera?> landed(String id, CameraEdit camera) async {
    final c = await _ref.read(cameraRepositoryProvider).camera(id);
    final same =
        c.brand == camera.brand &&
        c.model == camera.model &&
        c.hasFixedLens == camera.hasFixedLens &&
        (c.mount ?? '') == (camera.mount ?? '') &&
        (c.description ?? '') == (camera.description ?? '');
    return same ? _saved(c) : null;
  }

  Camera _saved(Camera saved) {
    _ref
      ..invalidate(camerasProvider)
      ..invalidate(cameraProvider(saved.id))
      // A fixed-lens camera owns a built-in lens.
      ..invalidate(lensesProvider);
    return saved;
  }
}

final cameraActionsProvider = Provider<CameraActions>(CameraActions.new);

/// Quick add of lenses. The dashboard edits and links them.
class LensActions {
  LensActions(this._ref);
  final Ref _ref;

  /// Creates a lens (at client id [id] when given).
  Future<Lens> save(LensEdit lens, {String? id}) async {
    final saved = await _ref.read(lensRepositoryProvider).create(lens, id: id);
    return _saved(saved);
  }

  /// After a create at [id] was refused because the id is taken: the lens at
  /// [id] if it is this create's, else null.
  Future<Lens?> landed(String id, LensEdit lens) async {
    final l = await _ref.read(lensRepositoryProvider).lens(id);
    final same =
        l.focalLength == lens.focalLength &&
        l.maxAperture == lens.maxAperture &&
        (l.brand ?? '') == (lens.brand ?? '') &&
        (l.model ?? '') == (lens.model ?? '') &&
        (l.mount ?? '') == (lens.mount ?? '');
    return same ? _saved(l) : null;
  }

  Lens _saved(Lens saved) {
    _ref
      ..invalidate(lensesProvider)
      ..invalidate(lensProvider(saved.id));
    return saved;
  }
}

final lensActionsProvider = Provider<LensActions>(LensActions.new);
