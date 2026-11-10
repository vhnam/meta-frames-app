import 'package:flutter_test/flutter_test.dart';
import 'package:meta_frames/data/sync/pending_op.dart';
import 'package:meta_frames/data/sync/projection.dart';

PendingOp _op(
  OpKind kind, {
  String roll = 'r1',
  String? camera = 'c1',
  int? frame,
  Map<String, dynamic> payload = const {},
}) => PendingOp(
  seq: 1,
  opId: 'o',
  kind: kind,
  rollId: roll,
  cameraId: camera,
  frame: frame,
  payload: payload,
  state: OpState.pending,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

final _load = _op(
  OpKind.load,
  payload: {
    'startedAt': '2026-11-07',
    'cameraName': 'FM2',
    'stockId': 's1',
    'stockBrand': 'Kodak',
    'stockName': 'Gold',
    'shotIso': 800,
  },
);

void main() {
  test('a pending load leaves the in-stock list and fills its camera', () {
    final rolls = [
      {'id': 'r1', 'status': 'in_stock'},
      {'id': 'r2', 'status': 'in_stock'},
    ];
    final inStock = project('/rolls?status=in_stock', rolls, [_load]) as List;
    expect(inStock.map((r) => r['id']), ['r2']);
    final all = project('/rolls', rolls, [_load]) as List;
    expect(all.first['status'], 'in_camera');
    expect(
      rolls.first['status'],
      'in_stock',
      reason: 'the kept answer is untouched',
    );

    final cams = project(
      '/cameras',
      [
        {'id': 'c1', 'loadedRoll': null},
      ],
      [_load],
    ) as List;
    expect(cams.single['loadedRoll']['rollId'], 'r1');
    expect(cams.single['loadedRoll']['shotIso'], 800);
  });

  test('a pending finish empties the camera holding that roll only', () {
    final cams = project(
      '/cameras',
      [
        {
          'id': 'c1',
          'loadedRoll': {'rollId': 'r1'},
        },
        {
          'id': 'c2',
          'loadedRoll': {'rollId': 'r9'},
        },
      ],
      [
        _op(OpKind.finish, payload: {'date': '2026-11-08'}),
      ],
    ) as List;
    expect(cams.first['loadedRoll'], isNull);
    expect(cams.last['loadedRoll'], isNotNull);
  });

  test('a note on a frame the server lacks shows on that frame only', () {
    final note = _op(OpKind.frameNotes, frame: 7, payload: {'text': ' Tree '});
    expect(project('/rolls/r1/frames/7', null, [note])['notes'], 'Tree');
    expect(project('/rolls/r1/frames/8', null, [note]), isNull);
    final detail = project(
      '/rolls/r1',
      {
        'roll': {'id': 'r1'},
        'frames': [
          {'number': 9, 'notes': 'x'},
        ],
      },
      [note],
    );
    expect((detail['frames'] as List).map((f) => f['number']), [7, 9]);
  });

  test(
    'reads are kept by path and sorted query; searches and scans are not',
    () {
      expect(
        readKey('/rolls', {'status': 'in_stock', 'cameraId': null}),
        '/rolls?status=in_stock',
      );
      expect(readKey('/rolls', {'b': '2', 'a': '1'}), '/rolls?a=1&b=2');
      expect(isKeptRead('/rolls/r1/frames/3', null), isTrue);
      expect(isKeptRead('/film-stocks', {'q': 'portra'}), isFalse);
      expect(isKeptRead('/processing/p1/scans', null), isFalse);
    },
  );
}
