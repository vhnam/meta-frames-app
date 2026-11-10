import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/local_store.dart';
import '../../../data/services/api_client.dart';
import '../../../domain/utils.dart';
import '../../../providers.dart';
import '../../rolls/view_models/roll_actions.dart' show EarlierRollsReplayed;

/// A create whose id belongs to no record this account can see (`404` on the
/// read-back), or whose rolls an earlier attempt already added. Nothing was
/// overwritten. The draft is kept under [newId], so saving it again creates a
/// separate record on purpose.
class DraftIdTaken implements Exception {
  DraftIdTaken(this.newId, this.message);
  final String newId;
  final String message;
  @override
  String toString() => message;
}

/// [DraftIdTaken] as an error for `guard` to show.
ApiException draftError(DraftIdTaken e) =>
    ApiException(412, 'already_exists', e.message);

/// Creates that keep what the user typed until the server confirms it.
///
/// Each create form has a draft id, kept for the life of the form (and of a
/// draft resumed later). It is the record's client id, or the idempotency key
/// for added rolls, so sending again after a timeout or a restart can never
/// make a second record. The draft is written before the first request and
/// deleted only once the server has confirmed the create, directly or by the
/// read-back after a `412`. No record is created offline: an unsent draft
/// waits in Sync status and in the picker it came from.
class DraftActions {
  DraftActions(this._ref);
  final Ref _ref;

  /// Sends a create for draft [id]. [form] is what reopens the form (its
  /// request and anything else it shows); [label] names the draft in lists.
  ///
  /// [send] makes the request with [id]. [readBack] runs when the server says
  /// the id is taken (`412`): it reads the record at [id] and returns it if it
  /// is this draft's own earlier create, null if it differs. A `404` from the
  /// read-back means the id belongs to no record this account can see.
  ///
  /// The whole workflow belongs to the account and server that started it. If
  /// either changes (signing out, another account, another server), no further
  /// request is made, [SessionChanged] is thrown whatever the outcome of a
  /// request already out, and the draft stays in its own partition: the
  /// original account's later send under the same id reads back what landed.
  Future<T> submit<T>({
    required String id,
    required DraftKind kind,
    required String label,
    required Map<String, dynamic> form,
    required Future<T> Function() send,
    Future<T?> Function()? readBack,
  }) async {
    final store = _ref.read(localStoreProvider);
    final pin = _ref.read(apiClientProvider).pin();
    final work = _Work(store, pin);
    final json = {...form, 'label': label};
    return pin.run(() async {
      await work.write((s) => s.saveDraft(id, kind, json));
      try {
        late T saved;
        try {
          pin.check();
          saved = await send();
        } on ApiException catch (e) {
          if (e.status != 412 || readBack == null) rethrow;
          final T? landed;
          try {
            pin.check();
            landed = await readBack();
          } on ApiException catch (r) {
            if (r.status != 404) rethrow;
            throw await _retire(
              work,
              id,
              kind,
              json,
              'This draft could not be saved under its id. It is kept: save it again to send it as a new record.',
            );
          }
          if (landed == null) {
            // A different record holds the id: show the conflict, change
            // nothing. The draft keeps its id (a new one only after a 404).
            throw ApiException(
              412,
              'already_exists',
              'A record with this draft’s id already exists with other values. Nothing was changed. Select that record in the list, or discard this draft in Sync status.',
            );
          }
          saved = landed;
        }
        // Landed, but for whom? An answer of an earlier session is never
        // delivered as the current one's: the draft stays for its account.
        pin.check();
        await work.write((s) => s.deleteDraft(id));
        return saved;
      } on SessionChanged {
        rethrow;
      } on EarlierRollsReplayed catch (e) {
        // The earlier attempt's rolls exist; these values were not sent.
        // Keep them under a new key so saving again adds them on purpose.
        throw await _retire(work, id, kind, json, e.toString());
      } on ApiException catch (e) {
        // An error that arrives after the session moved on is that session's.
        pin.check();
        await work.write(
          (s) => s.saveDraft(id, kind, {...json, 'error': e.message}),
        );
        rethrow;
      }
    });
  }

  /// Moves the draft to a new id after its id turned out to be taken.
  Future<DraftIdTaken> _retire(
    _Work work,
    String oldId,
    DraftKind kind,
    Map<String, dynamic> json,
    String message,
  ) async {
    final fresh = newId();
    await work.write(
      (s) => s.moveDraft(oldId, fresh, kind, {...json, 'error': message}),
    );
    return DraftIdTaken(fresh, message);
  }

  Future<void> discard(String id) async =>
      _ref.read(localStoreProvider)?.deleteDraft(id);

  Future<Draft?> read(String id) async =>
      _ref.read(localStoreProvider)?.draft(id);
}

/// The draft writes of one [DraftActions.submit]: to the partition that was
/// open when it began, and only while its session is current.
class _Work {
  _Work(this._store, this._pin);
  final LocalStore? _store;
  final SessionPin _pin;

  /// Runs [step] on the partition. Throws [SessionChanged], not a database
  /// failure, once the partition has closed or the session has moved on, also
  /// when it moved on while [step] was running: the step is kept (a draft
  /// written stays for its own account) but its caller never carries on, or
  /// reports a result, as if the session were still the same.
  Future<void> write(Future<void> Function(LocalStore store) step) async {
    final store = _store;
    if (store == null) return;
    _pin.check();
    if (store.isClosed) throw SessionChanged();
    try {
      await step(store);
    } on Object {
      if (store.isClosed || !_pin.current) throw SessionChanged();
      rethrow;
    }
    _pin.check();
  }
}

final draftActionsProvider = Provider<DraftActions>(DraftActions.new);

/// One draft, to reopen its form. Null when it was sent or discarded.
final draftProvider = FutureProvider.autoDispose.family<Draft?, String>((
  ref,
  id,
) {
  ref.watch(draftsProvider);
  return ref.read(draftActionsProvider).read(id);
});

/// Unsent drafts of [kind], for a picker's footer. Empty when nothing is kept
/// on this device.
Future<List<Draft>> draftsOf(WidgetRef ref, DraftKind kind) async {
  try {
    final all = await ref.read(draftsProvider.future);
    return [
      for (final d in all)
        if (d.kind == kind) d,
    ];
  } on Object {
    return const [];
  }
}
