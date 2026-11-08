import 'dart:convert';

import '../../domain/utils.dart';
import 'pending_op.dart';

/// What the screens show: the server's answer for a read, with every open
/// operation laid over it in order. Pure functions on decoded JSON, so the
/// existing model decoders read the result.
///
/// Reads are named by their path and query (`/cameras`, `/rolls?status=…`,
/// `/rolls/<id>`, `/rolls/<id>/frames/<n>`). Reads no operation can change are
/// returned as they are.

/// [json] with [ops] (open operations, in order) applied. [json] is null for a
/// frame the server does not have (a 404).
dynamic project(String key, dynamic json, Iterable<PendingOp> ops) {
  var out = _copy(json);
  for (final op in ops) {
    out = applyOp(key, out, op);
  }
  return out;
}

/// [json] with one operation applied: used for each open operation when
/// reading, and for good when an operation is done so the stored lists agree
/// with the server without waiting for a refresh.
dynamic applyOp(String key, dynamic json, PendingOp op) {
  final read = ReadKey.parse(key);
  switch (read.kind) {
    case ReadKind.cameras:
      return [
        for (final c in json as List) _camera(c as Map<String, dynamic>, op),
      ];
    case ReadKind.camera:
      return _camera(json as Map<String, dynamic>, op);
    case ReadKind.rolls:
      final status = read.query['status'];
      return [
        for (final r in json as List)
          if (_summary(r as Map<String, dynamic>, op) case final s
              when status == null || s['status'] == status)
            s,
      ];
    case ReadKind.roll:
      if (read.rollId != op.rollId) return json;
      final d = json as Map<String, dynamic>;
      d['roll'] = _summary(d['roll'] as Map<String, dynamic>, op);
      if (op.kind == OpKind.frameNotes) {
        d['frames'] = _frames((d['frames'] as List?) ?? const [], op);
      }
      return d;
    case ReadKind.frame:
      if (op.kind != OpKind.frameNotes ||
          op.rollId != read.rollId ||
          op.frame != read.frame) {
        return json;
      }
      final f = (json as Map<String, dynamic>?) ?? _newFrame(op);
      f['notes'] = _notes(op.text);
      return f;
    case ReadKind.expiry:
      final e = json as Map<String, dynamic>;
      bool inStock(Map<String, dynamic> r) => r['status'] == 'in_stock';
      e['expiring'] = [
        for (final x in (e['expiring'] as List? ?? const []))
          if (x as Map<String, dynamic> case final m
              when inStock(m['roll'] = _summary(m['roll'], op)))
            m,
      ];
      e['noExpiry'] = [
        for (final r in (e['noExpiry'] as List? ?? const []))
          if (_summary(r as Map<String, dynamic>, op) case final s
              when inStock(s))
            s,
      ];
      return e;
    case ReadKind.other:
      return json;
  }
}

Map<String, dynamic> _camera(Map<String, dynamic> c, PendingOp op) {
  switch (op.kind) {
    case OpKind.load:
      if (c['id'] != op.cameraId) return c;
      final p = op.payload;
      final started = DateTime.parse(p['startedAt'] as String);
      return c
        ..['loadedRoll'] = {
          'rollId': op.rollId,
          'stockId': p['stockId'],
          'stockBrand': p['stockBrand'],
          'stockName': p['stockName'],
          'shotIso': p['shotIso'],
          'startedAt': ymd(started),
          'daysLoaded': _daysSince(started),
        };
    case OpKind.finish:
      final loaded = c['loadedRoll'] as Map<String, dynamic>?;
      if (loaded == null || loaded['rollId'] != op.rollId) return c;
      return c..['loadedRoll'] = null;
    case OpKind.frameNotes || OpKind.rollNotes:
      return c;
  }
}

Map<String, dynamic> _summary(Map<String, dynamic> r, PendingOp op) {
  if (r['id'] != op.rollId) return r;
  final p = op.payload;
  switch (op.kind) {
    case OpKind.load:
      return r
        ..['status'] = 'in_camera'
        ..['cameraId'] = op.cameraId
        ..['cameraName'] = p['cameraName']
        ..['startedAt'] = p['startedAt']
        ..['shotIso'] = p['shotIso'];
    case OpKind.finish:
      return r
        ..['status'] = 'done_shooting'
        ..['finishedAt'] = p['date'];
    case OpKind.rollNotes:
      return r..['description'] = _notes(op.text);
    case OpKind.frameNotes:
      return r;
  }
}

List<Map<String, dynamic>> _frames(List frames, PendingOp op) {
  final out = [for (final f in frames) f as Map<String, dynamic>];
  final at = out.indexWhere((f) => f['number'] == op.frame);
  if (at >= 0) {
    out[at]['notes'] = _notes(op.text);
  } else {
    out.add(_newFrame(op)..['notes'] = _notes(op.text));
    out.sort((a, b) => (a['number'] as int).compareTo(b['number'] as int));
  }
  return out;
}

/// A frame the server has not created yet: it is created on first save.
Map<String, dynamic> _newFrame(PendingOp op) => {
  'id': 'local:${op.rollId}:${op.frame}',
  'number': op.frame,
  'notes': null,
  'scans': <Object>[],
};

/// The server stores cleared notes as none.
String? _notes(String text) => text.trim().isEmpty ? null : text.trim();

int _daysSince(DateTime d) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return today.difference(DateTime(d.year, d.month, d.day)).inDays;
}

/// A deep copy, so applying operations never changes a stored answer.
dynamic _copy(dynamic json) =>
    json == null ? null : jsonDecode(jsonEncode(json));

enum ReadKind { cameras, camera, rolls, roll, frame, expiry, other }

/// A read's path and query, as the snapshot store names it.
class ReadKey {
  const ReadKey(this.kind, {this.rollId, this.frame, this.query = const {}});

  factory ReadKey.parse(String key) {
    final uri = Uri.parse(key);
    final s = uri.pathSegments;
    final q = uri.queryParameters;
    if (s.length == 1 && s[0] == 'cameras') {
      return const ReadKey(ReadKind.cameras);
    }
    if (s.length == 2 && s[0] == 'cameras') {
      return const ReadKey(ReadKind.camera);
    }
    if (s.length == 1 && s[0] == 'rolls') {
      return ReadKey(ReadKind.rolls, query: q);
    }
    if (s.length == 2 && s[0] == 'rolls') {
      return ReadKey(ReadKind.roll, rollId: s[1]);
    }
    if (s.length == 4 && s[0] == 'rolls' && s[2] == 'frames') {
      return ReadKey(ReadKind.frame, rollId: s[1], frame: int.tryParse(s[3]));
    }
    if (s.length == 1 && s[0] == 'expiry') {
      return const ReadKey(ReadKind.expiry);
    }
    return const ReadKey(ReadKind.other);
  }

  final ReadKind kind;
  final String? rollId;
  final int? frame;
  final Map<String, String> query;
}

/// The name a read is stored under: its path, and its query sorted so the
/// same read always has the same name.
String readKey(String path, Map<String, String?>? query) {
  final params = <String, String>{
    for (final e in (query ?? const <String, String?>{}).entries)
      if (e.value != null && e.value!.isNotEmpty) e.key: e.value!,
  };
  if (params.isEmpty) return path;
  final names = params.keys.toList()..sort();
  return Uri(
    path: path,
    queryParameters: {for (final n in names) n: params[n]!},
  ).toString();
}

/// Reads kept on the device and served when the server cannot be reached.
/// Scans are never kept. Searches (`q=`) are not kept either: offline they say
/// "not available offline" rather than showing an unrelated earlier search.
bool isKeptRead(String path, Map<String, String?>? query) {
  if (query?['q']?.isNotEmpty ?? false) return false;
  final s = Uri.parse(path).pathSegments;
  if (s.isEmpty) return false;
  return switch (s[0]) {
    'cameras' => s.length == 1 || s.length == 2 || s[2] == 'lenses',
    'rolls' =>
      s.length == 1 || s.length == 2 || (s.length == 4 && s[2] == 'frames'),
    'film-stocks' => s.length <= 2,
    'inventory' || 'labs' || 'lenses' || 'expiry' => s.length <= 2,
    'auth' => s.length == 2 && s[1] == 'me',
    _ => false,
  };
}
