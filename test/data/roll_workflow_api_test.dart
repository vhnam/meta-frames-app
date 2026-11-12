import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:meta_frames/data/repositories/roll_repository_remote.dart';
import 'package:meta_frames/data/services/api_client.dart';
import 'package:meta_frames/domain/models/models.dart';

/// A RollDetail as the server answers it, with [plan] and [stage] set.
Map<String, dynamic> _detail(
  Map<String, dynamic> plan,
  String stage, {
  bool needsScan = false,
}) => {
  'roll': {
    'id': 'r1',
    'filmStockId': 's1',
    'stockBrand': 'Kodak',
    'stockName': 'Gold',
    'format': 135,
    'exposures': 36,
    'status': 'done_shooting',
    'negativesAtLab': false,
    'plan': plan,
    'stage': stage,
    'needsScan': needsScan,
  },
  'stock': {
    'id': 's1',
    'brand': 'Kodak',
    'name': 'Gold',
    'type': 'color',
    'boxIso': '200',
    'process': 'C-41',
    'packaging': 'factory',
  },
  'lenses': [],
  'processing': [],
  'frames': [],
  'totals': {
    'rollPrice': 0,
    'processingPrice': 0,
    'total': 0,
    'incomplete': false,
  },
  'warnings': [],
};

void main() {
  late List<http.Request> requests;
  late Map<String, dynamic> reply;

  RollRepositoryRemote repo() => RollRepositoryRemote(
    ApiClient(
      () => 'http://srv',
      MockClient((request) async {
        requests.add(request);
        return http.Response(
          jsonEncode(reply),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    ),
  );

  setUp(() => requests = []);

  group('PUT /rolls/{id}/plan', () {
    test('sets a plan and reads the roll the server returns', () async {
      reply = _detail({
        'target': 'scanned',
        'developBy': 'lab',
        'scanBy': 'self',
      }, 'done_shooting');
      final detail = await repo().setPlan(
        'r1',
        const RollPlan(
          target: PlanTarget.scanned,
          developBy: StepActor.lab,
          scanBy: StepActor.self,
        ),
      );

      final request = requests.single;
      expect('${request.method} ${request.url.path}', 'PUT /rolls/r1/plan');
      expect(jsonDecode(request.body), {
        'target': 'scanned',
        'developBy': 'lab',
        'scanBy': 'self',
      });
      expect(detail.roll.plan!.scanBy, StepActor.self);
      expect(detail.roll.stage, RollLifecycleStage.doneShooting);
    });

    test('a changed plan leaves out what is no longer decided', () async {
      reply = _detail({
        'target': 'developed',
        'developBy': 'self',
      }, 'done_shooting');
      await repo().setPlan(
        'r1',
        const RollPlan(target: PlanTarget.developed, developBy: StepActor.self),
      );
      // The PUT replaces the plan: scanBy left out is cleared on the server.
      expect(jsonDecode(requests.single.body), {
        'target': 'developed',
        'developBy': 'self',
      });
    });

    test('clearing the plan sends an empty object', () async {
      reply = _detail({}, 'done_shooting');
      final detail = await repo().setPlan('r1', const RollPlan());
      expect(jsonDecode(requests.single.body), <String, dynamic>{});
      expect(detail.roll.plan!.target, isNull);
    });

    test('a network failure is an error, not a saved plan', () async {
      final offline = RollRepositoryRemote(
        ApiClient(
          () => 'http://srv',
          MockClient((_) async => throw http.ClientException('offline')),
        ),
      );
      await expectLater(
        offline.setPlan('r1', const RollPlan(target: PlanTarget.scanned)),
        throwsA(
          isA<ApiException>().having(
            (error) => error.isNetwork,
            'isNetwork',
            true,
          ),
        ),
      );
    });
  });

  group('/rolls/{id}/scan-request', () {
    test('PUT marks the roll and sends no body', () async {
      reply = _detail({}, 'completed', needsScan: true);
      final detail = await repo().setNeedsScan('r1', true);

      final request = requests.single;
      expect(
        '${request.method} ${request.url.path}',
        'PUT /rolls/r1/scan-request',
      );
      expect(request.body, isEmpty);
      expect(detail.roll.needsScan, isTrue);
    });

    test('DELETE removes the mark', () async {
      reply = _detail({}, 'completed');
      final detail = await repo().setNeedsScan('r1', false);

      expect(
        '${requests.single.method} ${requests.single.url.path}',
        'DELETE /rolls/r1/scan-request',
      );
      expect(detail.roll.needsScan, isFalse);
    });

    test('a network failure is an error, not a changed mark', () async {
      final offline = RollRepositoryRemote(
        ApiClient(
          () => 'http://srv',
          MockClient((_) async => throw http.ClientException('offline')),
        ),
      );
      await expectLater(
        offline.setNeedsScan('r1', true),
        throwsA(
          isA<ApiException>().having(
            (error) => error.isNetwork,
            'isNetwork',
            true,
          ),
        ),
      );
    });
  });
}
