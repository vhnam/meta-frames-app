import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/models.dart';
import '../../../data/services/api_client.dart';
import '../../../providers.dart';
import 'scan_actions.dart';

/// A picked file and the frame the server (or the user) assigned to it.
class ImportItem {
  const ImportItem(this.name, this.path, {this.frame, this.error});
  final String name, path;
  final int? frame;
  final String? error;

  bool get ready => frame != null && error == null;
}

class ImportScansState {
  const ImportScansState({
    this.scanner = Scanner.noritsu,
    this.replace = false,
    this.items = const [],
    this.failures = const [],
    this.busy = false,
    this.progress,
  });
  final Scanner scanner;
  final bool replace;
  final List<ImportItem> items;
  final List<ImportFailure> failures;
  final bool busy;
  final String? progress;

  bool get canImport => !busy && items.any((e) => e.ready);

  ImportScansState copyWith({
    Scanner? scanner,
    bool? replace,
    List<ImportItem>? items,
    List<ImportFailure>? failures,
    bool? busy,
    String? progress,
    bool clearProgress = false,
  }) => ImportScansState(
    scanner: scanner ?? this.scanner,
    replace: replace ?? this.replace,
    items: items ?? this.items,
    failures: failures ?? this.failures,
    busy: busy ?? this.busy,
    progress: clearProgress ? null : (progress ?? this.progress),
  );
}

/// Counts reported after an import run.
class ImportSummary {
  const ImportSummary({
    required this.imported,
    required this.skipped,
    required this.failed,
  });
  final int imported, skipped, failed;

  bool get complete => failed == 0;

  String get message =>
      '$imported imported${skipped > 0 ? ', $skipped skipped' : ''}${failed > 0 ? ', $failed failed' : ''}';
}

/// M-33 import scans from the device, M-34 offset / start frame numbering.
class ImportScansViewModel extends Notifier<ImportScansState> {
  ImportScansViewModel(this._processingId);
  final String _processingId;

  @override
  ImportScansState build() => const ImportScansState();

  void setScanner(Scanner s) => state = state.copyWith(scanner: s);
  void setReplace(bool v) => state = state.copyWith(replace: v);

  /// Replaces the selection, then asks the server to number the files.
  Future<void> setFiles(
    List<({String name, String path})> files, {
    int? startFrame,
    int? offset,
  }) {
    state = state.copyWith(
      items: [
        for (final f in [...files]..sort((a, b) => a.name.compareTo(b.name)))
          ImportItem(f.name, f.path),
      ],
      failures: const [],
    );
    return preview(startFrame: startFrame, offset: offset);
  }

  /// Maps file names to frame numbers on the server (M-34 applies here).
  Future<void> preview({int? startFrame, int? offset}) async {
    if (state.items.isEmpty) return;
    final map = await ref
        .read(scanRepositoryProvider)
        .previewImport(
          _processingId,
          state.items.map((e) => e.name).toList(),
          startFrame: startFrame,
          offset: offset,
        );
    final byName = {for (final m in map) m.fileName: m};
    state = state.copyWith(
      items: [
        for (final it in state.items)
          if (byName[it.name] case final m?)
            ImportItem(it.name, it.path, frame: m.frameNumber, error: m.error)
          else
            it,
      ],
    );
  }

  /// Manual frame number for one file; clears its error.
  void setFrame(String name, int frame) => state = state.copyWith(
    items: [
      for (final it in state.items)
        if (it.name == name) ImportItem(it.name, it.path, frame: frame) else it,
    ],
  );

  /// Uploads every ready file. Files that fail stay selected for a retry.
  Future<ImportSummary> import() async {
    final todo = state.items.where((e) => e.ready).toList();
    if (todo.isEmpty) {
      return const ImportSummary(imported: 0, skipped: 0, failed: 0);
    }
    state = state.copyWith(busy: true, failures: const []);
    final actions = ref.read(scanActionsProvider);
    var done = 0, skipped = 0;
    final failed = <ImportFailure>[];
    for (final it in todo) {
      state = state.copyWith(
        progress: 'Uploading ${done + failed.length + 1} of ${todo.length}…',
      );
      try {
        final r = await actions.importScan(
          _processingId,
          scanner: state.scanner,
          path: it.path,
          fileName: it.name,
          frameNumber: it.frame!,
          replace: state.replace,
        );
        done += r.imported.length;
        skipped += r.skipped.length;
        failed.addAll(r.failed);
      } catch (e) {
        failed.add(
          ImportFailure.fromJson({'fileName': it.name, 'reason': e.toString()}),
        );
      }
    }
    actions.importsFinished(_processingId);
    if (ref.mounted) {
      state = state.copyWith(
        busy: false,
        clearProgress: true,
        failures: failed,
        // Keep only failures so the user can retry them.
        items: state.items
            .where((e) => failed.any((f) => f.fileName == e.name))
            .toList(),
      );
    }
    return ImportSummary(
      imported: done,
      skipped: skipped,
      failed: failed.length,
    );
  }
}

final importScansViewModelProvider = NotifierProvider.autoDispose
    .family<ImportScansViewModel, ImportScansState, String>(
      ImportScansViewModel.new,
    );

/// Frame notes. A 404 means the frame has no scans or notes yet: it is created
/// on first save, so it reads as no frame rather than an error.
final frameNotesProvider = FutureProvider.autoDispose
    .family<Frame?, (String, int)>((ref, k) async {
      try {
        return await ref.watch(frameProvider(k).future);
      } on ApiException catch (e) {
        if (e.status == 404) return null;
        rethrow;
      }
    });
