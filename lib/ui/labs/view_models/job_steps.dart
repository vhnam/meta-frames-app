import '../../../domain/models/models.dart';

enum JobStepTone { done, late, overdue, due, pending }

/// One stage of a job, with where it stands.
class JobStep {
  const JobStep({
    required this.label,
    this.expected,
    this.actual,
    required this.status,
    required this.tone,
  });
  final String label;
  final DateTime? expected, actual;
  final String status;
  final JobStepTone tone;
}

/// Whole days between two dates, read as UTC so daylight saving cannot shift
/// them.
int _daysBetween(DateTime from, DateTime to) => DateTime.utc(
  to.year,
  to.month,
  to.day,
).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

String _days(int count) => '$count day${count == 1 ? '' : 's'}';

JobStep _waiting(String label, DateTime? expected, DateTime today) {
  if (expected == null) {
    return JobStep(label: label, status: 'Waiting', tone: JobStepTone.pending);
  }
  final left = _daysBetween(today, expected);
  return JobStep(
    label: label,
    expected: expected,
    status: left < 0
        ? 'Overdue ${_days(-left)}'
        : left == 0
        ? 'Due today'
        : 'Due in ${_days(left)}',
    tone: left < 0 ? JobStepTone.overdue : JobStepTone.due,
  );
}

JobStep _arrived(String label, DateTime? expected, DateTime actual, int late) =>
    JobStep(
      label: label,
      expected: expected,
      actual: actual,
      status: late > 0 ? '${_days(late)} late' : 'Done',
      tone: late > 0 ? JobStepTone.late : JobStepTone.done,
    );

/// The job's steps in order: the roll goes out, then the negatives (or prints)
/// and the scans come back. A stored expected date is shown at home too.
List<JobStep> jobSteps(Processing job, DateTime today) {
  final atLab = !job.isHome;
  final negativesExpected = job.negativesExpectedAt;
  final scansExpected = job.scansExpectedAt;
  final negativesLabel = !atLab && job.type == ProcessingType.print
      ? 'Prints'
      : atLab
      ? 'Negatives back'
      : 'Negatives';
  final scansLabel = atLab ? 'Scans back' : 'Scans';
  return [
    JobStep(
      label: atLab ? 'Sent' : 'Started',
      actual: job.sentAt,
      status: 'Done',
      tone: JobStepTone.done,
    ),
    if (job.type.recordsNegativesReturned(atLab: atLab) ||
        job.negativesExpectedAt != null)
      job.negativesReturnedAt == null
          ? _waiting(negativesLabel, negativesExpected, today)
          // Negatives can come back with the scans: never counted as late.
          : _arrived(
              negativesLabel,
              negativesExpected,
              job.negativesReturnedAt!,
              0,
            ),
    if (job.type.hasScans)
      job.scansReceivedAt == null
          ? _waiting(scansLabel, scansExpected, today)
          : _arrived(
              scansLabel,
              scansExpected,
              job.scansReceivedAt!,
              scansExpected == null
                  ? 0
                  : _daysBetween(scansExpected, job.scansReceivedAt!),
            ),
  ];
}
