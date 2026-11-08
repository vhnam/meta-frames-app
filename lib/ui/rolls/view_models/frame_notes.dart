import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/sync/pending_op.dart';
import '../../../providers.dart';

/// The largest frame number the server stores (a Postgres `integer`).
const _maxFrameNumber = 0x7fffffff;

/// The frame number typed by the photographer, or null when it is not one. The
/// server takes any whole number from 0: frame 0, and frames past the roll's
/// exposure count, are real on many cameras. Nothing here counts frames for the
/// photographer, so each note starts from a number they type.
int? parseFrameNumber(String text) {
  final n = int.tryParse(text.trim());
  if (n == null || n < 0 || n > _maxFrameNumber) return null;
  return n;
}

/// The notes being edited: a frame's ([frame] set) or the roll's own.
typedef NotesTarget = ({String rollId, int? frame});

/// Notes written while a roll is shot: on its frames, which need no scans, and
/// on the roll itself (subject, place, conditions, incidents). Both are kept
/// apart from the lab's development request.
class NotesActions {
  NotesActions(this._ref);
  final Ref _ref;

  /// Saves [text] (empty clears it). [seenBase] is the saved text the user
  /// was shown, or null when it was not available (offline, never fetched):
  /// the edit is then not sent blindly, the saved text is read first.
  ///
  /// With a partition open the edit is recorded on the phone first, and sent
  /// from there: it survives a restart and is never lost to a failed request.
  /// Returns true when it is only on the phone so far.
  Future<bool> save(NotesTarget target, String text, {String? seenBase}) async {
    final store = _ref.read(localStoreProvider);
    if (store == null) {
      // Nothing kept on this device: straight to the server, still guarded
      // by what the user saw.
      await _sendNow(target, text.trim(), seenBase);
      _refresh(target);
      return false;
    }
    await store.enqueueNotes(
      kind: target.frame == null ? OpKind.rollNotes : OpKind.frameNotes,
      rollId: target.rollId,
      frame: target.frame,
      text: text.trim(),
      seenBase: seenBase,
    );
    _refresh(target);
    unawaited(_ref.read(partitionControllerProvider).sync());
    return true;
  }

  Future<void> _sendNow(NotesTarget t, String text, String? base) async {
    final rolls = _ref.read(rollRepositoryProvider);
    if (t.frame == null) {
      await rolls.saveRollNotes(t.rollId, text, baseDescription: base);
    } else {
      await rolls.saveFrameNotes(
        t.rollId,
        t.frame!,
        text.isEmpty ? null : text,
        baseNotes: base,
      );
    }
  }

  void _refresh(NotesTarget t) {
    if (t.frame != null) _ref.invalidate(frameProvider((t.rollId, t.frame!)));
    _ref
      // The roll's page and the Shooting tab list its frames and notes.
      ..invalidate(rollDetailProvider(t.rollId))
      ..invalidate(rollsProvider);
  }
}

final notesActionsProvider = Provider<NotesActions>(NotesActions.new);
