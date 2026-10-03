import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/expiry.dart';
import '../../../domain/models/models.dart';
import '../../../domain/models/roll_requests.dart';
import '../../../providers.dart';
import 'roll_actions.dart';

/// Camera and roll the screen was opened with; either may be null.
typedef LoadRollArgs = ({Camera? camera, RollSummary? roll});

class LoadRollState {
  const LoadRollState({
    this.camera,
    this.roll,
    required this.started,
    this.lensIds = const {},
    this.suggested,
    this.extra = const {},
    this.lensError,
  });
  final Camera? camera;
  final RollSummary? roll;
  final DateTime started;

  /// Lenses ticked for this roll.
  final Set<String> lensIds;

  /// Lenses linked to the camera. Null while loading.
  final List<Lens>? suggested;

  /// Adapted lenses added for this roll only.
  final Map<String, Lens> extra;
  final String? lensError;

  bool get expired => isExpired(roll?.expiry);
  bool get canSubmit => roll != null && camera != null;
  bool get needsLensList => camera != null && !camera!.hasFixedLens;
  List<Lens> get lensChoices => [...?suggested, ...extra.values];

  LoadRollState copyWith({
    Camera? camera,
    RollSummary? roll,
    DateTime? started,
    Set<String>? lensIds,
    List<Lens>? suggested,
    Map<String, Lens>? extra,
    String? lensError,
    bool resetCamera = false,
  }) => LoadRollState(
    camera: camera ?? this.camera,
    roll: roll ?? this.roll,
    started: started ?? this.started,
    lensIds: lensIds ?? this.lensIds,
    suggested: resetCamera ? null : (suggested ?? this.suggested),
    extra: extra ?? this.extra,
    lensError: resetCamera ? null : (lensError ?? this.lensError),
  );
}

/// M-19 load a roll into a camera.
class LoadRollViewModel extends Notifier<LoadRollState> {
  LoadRollViewModel(this._args);
  final LoadRollArgs _args;

  @override
  LoadRollState build() {
    if (_args.camera != null) Future.microtask(_loadLenses);
    return LoadRollState(
      camera: _args.camera,
      roll: _args.roll,
      started: DateTime.now(),
    );
  }

  Future<void> _loadLenses() async {
    final camera = state.camera;
    if (camera == null) return;
    if (camera.hasFixedLens) {
      state = state.copyWith(suggested: const []);
      return;
    }
    try {
      final lenses = await ref.read(cameraRepositoryProvider).lenses(camera.id);
      // Ignore a late answer for a camera the user has since replaced.
      if (ref.mounted && state.camera?.id == camera.id) {
        state = state.copyWith(suggested: lenses);
      }
    } catch (e) {
      if (ref.mounted) state = state.copyWith(lensError: e.toString());
    }
  }

  /// In-stock rolls, soonest expiry first.
  Future<List<RollSummary>> inStockRolls() async {
    final rolls = await ref
        .read(rollRepositoryProvider)
        .rolls(status: 'in_stock');
    return rolls
      ..sort((a, b) => expiryKey(a.expiry).compareTo(expiryKey(b.expiry)));
  }

  /// Active cameras with nothing loaded.
  Future<List<Camera>> emptyCameras() async {
    final cams = await ref.read(cameraRepositoryProvider).cameras();
    return cams.where((c) => c.isActive && c.loadedRoll == null).toList();
  }

  /// Active, non-built-in lenses not already offered for the camera.
  Future<List<Lens>> otherLenses() async {
    final all = await ref.read(lensRepositoryProvider).lenses();
    final offered = {...?state.suggested?.map((l) => l.id)};
    return all
        .where((l) => l.isActive && !l.isBuiltIn && !offered.contains(l.id))
        .toList();
  }

  void selectRoll(RollSummary r) => state = state.copyWith(roll: r);

  void selectCamera(Camera c) {
    state = LoadRollState(camera: c, roll: state.roll, started: state.started);
    _loadLenses();
  }

  void setStarted(DateTime d) => state = state.copyWith(started: d);

  void toggleLens(String id, bool on) {
    final ids = {...state.lensIds};
    on ? ids.add(id) : ids.remove(id);
    state = state.copyWith(lensIds: ids);
  }

  /// Ticks an adapted lens that is not linked to the camera.
  void addExtraLens(Lens l) => state = state.copyWith(
    extra: {...state.extra, l.id: l},
    lensIds: {...state.lensIds, l.id},
  );

  /// Remembers [l] as one of the camera's lenses for future rolls.
  Future<void> linkLens(Lens l) async {
    final cameras = ref.read(cameraRepositoryProvider);
    final id = state.camera!.id;
    final current = (await cameras.lenses(id)).map((x) => x.id);
    await cameras.setLenses(id, {...current, l.id}.toList());
    ref
      ..invalidate(cameraLensesProvider)
      ..invalidate(lensCamerasProvider);
  }

  Future<void> submit({int? shotIso}) {
    final s = state;
    return ref
        .read(rollActionsProvider)
        .load(
          s.roll!.id,
          LoadRollRequest(
            cameraId: s.camera!.id,
            startedAt: s.started,
            shotIso: shotIso,
            lensIds: s.camera!.hasFixedLens ? const [] : s.lensIds.toList(),
          ),
        );
  }
}

final loadRollViewModelProvider = NotifierProvider.autoDispose
    .family<LoadRollViewModel, LoadRollState, LoadRollArgs>(
      LoadRollViewModel.new,
    );
