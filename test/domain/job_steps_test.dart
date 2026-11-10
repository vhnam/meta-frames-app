import 'package:flutter_test/flutter_test.dart';
import 'package:meta_frames/domain/models/models.dart';
import 'package:meta_frames/ui/labs/view_models/job_steps.dart';

Processing _job(Map<String, dynamic> fields) => Processing.fromJson({
  'id': 'j',
  'rollId': 'r',
  'process': 'C-41',
  'sentAt': '2026-09-01',
  'isOpen': true,
  ...fields,
});

void main() {
  final today = DateTime(2026, 9, 10);

  List<(String, String)> steps(Processing job) => [
    for (final s in jobSteps(job, today)) (s.label, s.status),
  ];

  test('a lab job tracks sending, negatives and scans', () {
    final job = _job({
      'labId': 'l',
      'type': 'develop_scan',
      'negativesExpectedAt': '2026-09-04',
      'negativesReturnedAt': '2026-09-06',
      'scansExpectedAt': '2026-09-05',
    });
    expect(steps(job), [
      ('Sent', 'Done'),
      ('Negatives back', 'Done'),
      ('Scans back', 'Overdue 5 days'),
    ]);
    expect(jobSteps(job, today).last.tone, JobStepTone.overdue);
  });

  test('scans that arrive after the expected date are late', () {
    final job = _job({
      'labId': 'l',
      'type': 'scan',
      'scansExpectedAt': '2026-09-05',
      'scansReceivedAt': '2026-09-06',
    });
    expect(jobSteps(job, today)[2].status, '1 day late');
    expect(jobSteps(job, today)[2].tone, JobStepTone.late);
  });

  test('counts the days left on a date still to come', () {
    final job = _job({
      'labId': 'l',
      'type': 'scan',
      'scansExpectedAt': '2026-09-12',
    });
    expect(jobSteps(job, today)[2].status, 'Due in 2 days');
    final dueToday = _job({
      'labId': 'l',
      'type': 'scan',
      'scansExpectedAt': '2026-09-10',
    });
    expect(jobSteps(dueToday, today)[2].status, 'Due today');
  });

  test('home work is worded as done by you and keeps a stored expected date', () {
    expect(
      steps(
        _job({
          'type': 'develop_scan',
          'negativesReturnedAt': '2026-09-01',
          'scansExpectedAt': '2026-09-02',
        }),
      ),
      [('Started', 'Done'), ('Negatives', 'Done'), ('Scans', 'Overdue 8 days')],
    );
    expect(steps(_job({'type': 'print'})), [
      ('Started', 'Done'),
      ('Prints', 'Waiting'),
    ]);
  });

  test('a home scan records no negatives step', () {
    expect(steps(_job({'type': 'scan'})), [
      ('Started', 'Done'),
      ('Scans', 'Waiting'),
    ]);
  });
}
