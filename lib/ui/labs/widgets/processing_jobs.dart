import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/models.dart';
import '../../../providers.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/common.dart';
import '../view_models/job_steps.dart';

/// A roll's processing jobs, latest first, each with its dates, scanners and
/// notes. Follows the dashboard's job list.
class ProcessingJobs extends StatelessWidget {
  const ProcessingJobs({super.key, required this.rollId, required this.jobs});
  final String rollId;
  final List<Processing> jobs;

  /// Jobs sent the same day keep the later one on top.
  List<Processing> get _latestFirst {
    final order = [for (var i = 0; i < jobs.length; i++) i];
    order.sort((a, b) {
      final bySent = jobs[b].sentAt.compareTo(jobs[a].sentAt);
      return bySent != 0 ? bySent : b - a;
    });
    return [for (final i in order) jobs[i]];
  }

  @override
  Widget build(BuildContext context) {
    if (jobs.isEmpty) {
      return Text(
        'Not sent for processing yet.',
        style: TextStyle(
          fontSize: 13,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
    }
    return CardList(
      gap: 12,
      children: [
        for (final j in _latestFirst) _JobCard(key: ValueKey(j.id), job: j),
      ],
    );
  }
}

class _JobCard extends StatelessWidget {
  const _JobCard({super.key, required this.job});
  final Processing job;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final notes = job.notes?.trim() ?? '';
    final summary = [
      job.type.label,
      job.process.label,
      if (job.price != null) fmtVnd(job.price),
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 16,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 12,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 2,
                  children: [
                    Text(
                      job.where,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      summary,
                      style: TextStyle(
                        fontSize: 13,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    if (job.order case final order?)
                      Text(
                        'Order #${order.code} · ${order.products}',
                        style: TextStyle(
                          fontSize: 13,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              job.isOpen
                  ? StampBadge('Open', color: cs.onPrimaryContainer)
                  : StampBadge('Closed', color: cs.onSurfaceVariant),
            ],
          ),
          _Section(title: 'Dates', child: JobDates(job)),
          if (job.scanOrders.isNotEmpty)
            _Section(title: 'Scans', child: JobScanOrders(job.scanOrders)),
          if (notes.isNotEmpty)
            _Section(title: 'Notes', child: JobNotes(notes)),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: 8,
    children: [SectionLabel(title), child],
  );
}

/// The job's steps, each with its dates and status.
class JobDates extends StatelessWidget {
  const JobDates(this.job, {super.key});
  final Processing job;

  @override
  Widget build(BuildContext context) => Column(
    spacing: 10,
    children: [for (final s in jobSteps(job, DateTime.now())) _StepRow(s)],
  );
}

/// A job's notes, rendered as Markdown.
class JobNotes extends StatelessWidget {
  const JobNotes(this.notes, {super.key});
  final String notes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MarkdownBody(
      data: notes,
      // A line break typed in the form stays a line break.
      softLineBreak: true,
      styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
        p: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface),
      ),
    );
  }
}

/// The step and its status on one line, its dates on the next: a phone has no
/// width for the dashboard's table.
class _StepRow extends StatelessWidget {
  const _StepRow(this.step);
  final JobStep step;

  Color _tone(ColorScheme cs) {
    final dark = cs.brightness == Brightness.dark;
    return switch (step.tone) {
      JobStepTone.done => dark ? Colors.green.shade300 : Colors.green.shade800,
      JobStepTone.late => dark ? Colors.amber.shade300 : Colors.amber.shade900,
      JobStepTone.overdue => cs.error,
      JobStepTone.due => cs.onSurface,
      JobStepTone.pending => cs.onSurfaceVariant,
    };
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tone = _tone(cs);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 2,
      children: [
        Row(
          spacing: 8,
          children: [
            Expanded(
              child: Text(
                step.label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(Icons.circle, size: 6, color: tone),
            Text(
              step.status,
              style: TextStyle(
                fontSize: 13,
                color: tone,
                fontWeight: step.tone == JobStepTone.overdue
                    ? FontWeight.w500
                    : FontWeight.w400,
              ),
            ),
          ],
        ),
        Text(
          'Expected ${fmtDate(step.expected)} · Actual ${fmtDate(step.actual)}',
          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// Each ordered scanner with its settings, worded by the scanner's kind.
class JobScanOrders extends ConsumerWidget {
  const JobScanOrders(this.orders, {super.key});
  final List<JobScanOrder> orders;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final scanners = ref.watch(scannersProvider).value ?? const [];
    final kinds = ref.watch(scannerKindsProvider).value ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        for (final o in orders)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 2,
            children: [
              Text(
                o.scannerName,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                describeSettings(
                  o.settings,
                  optionsForKind(
                    kinds,
                    scanners
                        .where((s) => s.id == o.scannerId)
                        .firstOrNull
                        ?.kind,
                  ),
                ),
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
            ],
          ),
      ],
    );
  }
}
