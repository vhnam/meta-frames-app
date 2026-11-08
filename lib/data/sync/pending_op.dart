import 'dart:convert';

import '../../domain/models/roll_requests.dart';

/// A field change recorded on the phone and sent to the server later.
enum OpKind {
  frameNotes,
  rollNotes,
  load,
  finish;

  bool get isNotes => this == frameNotes || this == rollNotes;
}

/// Where an operation is in its life.
///
/// - [pending]: waiting to be sent (or to be sent again: see `attempts`).
/// - [sending]: a request is on its way.
/// - [unknown]: a request may or may not have reached the server (a timeout,
///   a lost answer, an app killed mid-request). Read back before anything else
///   on the same roll or camera is sent.
/// - [conflict]: the server holds something else. Kept, with the server's
///   value, until the user chooses.
/// - [failed]: the server refused the request itself. Kept until the user
///   discards it.
/// - [done]: the server has it. Purged after a week.
enum OpState { pending, sending, unknown, conflict, failed, done }

/// Why an operation is in [OpState.conflict] when no server error says it.
const predecessorDiscarded = 'predecessor_discarded';

class PendingOp {
  const PendingOp({
    required this.seq,
    required this.opId,
    required this.kind,
    required this.rollId,
    this.cameraId,
    this.frame,
    required this.payload,
    this.base,
    required this.state,
    this.attempts = 0,
    this.predecessor,
    this.lastError,
    this.serverValue,
    required this.createdAt,
    required this.updatedAt,
  });

  PendingOp.fromRow(Map<String, Object?> row)
    : seq = row['seq'] as int,
      opId = row['op_id'] as String,
      kind = OpKind.values.byName(row['kind'] as String),
      rollId = row['roll_id'] as String,
      cameraId = row['camera_id'] as String?,
      frame = row['frame'] as int?,
      payload = jsonDecode(row['payload'] as String) as Map<String, dynamic>,
      base = row['base'] as String?,
      state = OpState.values.byName(row['state'] as String),
      attempts = row['attempts'] as int,
      predecessor = row['predecessor'] as String?,
      lastError = row['last_error'] as String?,
      serverValue = row['server_value'] as String?,
      createdAt = DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
      updatedAt = DateTime.fromMillisecondsSinceEpoch(row['updated_at'] as int);

  /// Order of recording. Operations sharing a roll, camera or note are sent in
  /// this order, one after the other.
  final int seq;
  final String opId;
  final OpKind kind;
  final String rollId;

  /// The camera a load or finish acts on.
  final String? cameraId;
  final int? frame;

  /// What the user asked for: `{text}` for notes, the request (and what the
  /// screens need to show it before the server answers) for load and finish.
  final Map<String, dynamic> payload;

  /// For notes: the text this edit was based on, "" for none. Null means the
  /// saved notes were not on the phone when the edit was made: they are read
  /// from the server before anything is sent, never assumed empty.
  final String? base;
  final OpState state;

  /// Requests ever started for this operation. Only one never attempted may be
  /// rewritten by a newer edit: an attempted one may already be on the server.
  final int attempts;

  /// The operation on the same note this one was based on.
  final String? predecessor;
  final String? lastError;

  /// For a conflict: the server's value when it was found, as text.
  final String? serverValue;
  final DateTime createdAt, updatedAt;

  /// The notes text asked for ("" clears).
  String get text => payload['text'] as String? ?? '';

  /// What this operation must wait for: any earlier operation sharing one of
  /// these is sent first. A load or finish holds its roll and its camera, so
  /// finishing roll A and then loading roll B into the same camera go in that
  /// order. A note holds only itself: it does not depend on the roll's status.
  Set<String> get keys => switch (kind) {
    OpKind.frameNotes => {'frame:$rollId:$frame'},
    OpKind.rollNotes => {'notes:$rollId'},
    OpKind.load ||
    OpKind.finish => {'roll:$rollId', if (cameraId != null) 'camera:$cameraId'},
  };

  bool get isOpen => state != OpState.done;

  /// Needs the user: nothing more is sent for it, or for what waits on it.
  bool get needsAttention =>
      state == OpState.conflict || state == OpState.failed;

  /// The load request recorded for a [OpKind.load].
  LoadRollRequest get loadRequest => LoadRollRequest(
    cameraId: cameraId!,
    startedAt: DateTime.parse(payload['startedAt'] as String),
    shotIso: payload['shotIso'] as int?,
    lensIds: List<String>.from(payload['lensIds'] as List? ?? const []),
  );

  /// The date recorded for a [OpKind.finish].
  DateTime get finishDate => DateTime.parse(payload['date'] as String);
}

/// Whether two notes texts are the same note, as the server compares them.
bool sameNotes(String? a, String? b) => (a ?? '').trim() == (b ?? '').trim();
