import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/models/models.dart';
import '../../../domain/models/roll_stage.dart';
import '../../../routing/routes.dart';
import '../../core/theme.dart';
import '../../core/widgets/common.dart';

/// One roll: status-tinted icon, name, meta line, status and process stamps.
/// Opens the roll. Used by every list of rolls that is not inside a detail.
class RollCard extends StatelessWidget {
  const RollCard({
    super.key,
    required this.roll,
    this.process,
    this.expiring = false,
    this.extraBadge,
  });
  final RollSummary roll;
  final Process? process;

  /// Warning outline and icon for film that is expired or about to be.
  final bool expiring;

  /// Shown after the status stamps, e.g. "Expired".
  final Widget? extraBadge;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tone = statusTone(context, roll.status);
    final meta = [
      '${roll.format} · ${roll.exposures} exp',
      if (roll.cameraName != null) roll.cameraName!,
      if (roll.shotIso != null) 'ISO ${roll.shotIso}',
      if (roll.startedAt != null) fmtDate(roll.startedAt),
      if (roll.expiry != null && roll.status == RollStatus.inStock)
        'exp ${roll.expiry}',
    ].join(' · ');
    return Material(
      color: cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: kCorners,
        side: BorderSide(
          color: expiring ? cs.error.withValues(alpha: 0.5) : cs.outlineVariant,
          width: kHairline,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(Routes.roll(roll.id)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: 0.1),
                  borderRadius: kCorners,
                  border: Border.all(
                    color: tone.withValues(alpha: 0.5),
                    width: kHairline,
                  ),
                ),
                child: Icon(Icons.movie_outlined, size: 22, color: tone),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      roll.stockLabel,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      meta,
                      style: monoStyle(
                        letterSpacing: 0.2,
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        StampBadge(_statusLabel(roll), color: tone),
                        if (process != null) ProcessBadge(process!),
                        ?extraBadge,
                        // An at-lab label already says the negatives are away.
                        if (roll.negativesAtLab &&
                            roll.status != RollStatus.atLab)
                          StampBadge(
                            'Negatives at lab',
                            color: cs.onPrimaryContainer,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (expiring) ...[
                const SizedBox(width: 8),
                Tooltip(
                  message: 'Expiring soon',
                  child: Icon(Icons.warning_rounded, size: 18, color: cs.error),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The status with what the jobs add: "At lab · Develop + Scan" while at the
/// lab, "At home · Develop" while processed at home, "Developed + Scanned"
/// once back.
String _statusLabel(RollSummary roll) {
  final stage = rollStage(roll);
  if (stage == null) return roll.status.label;
  if (stage.open) {
    final steps = [
      if (stage.develop) 'Develop',
      if (stage.scan) 'Scan',
      if (stage.print) 'Print',
    ];
    final place = stage.atHome ? 'At home' : roll.status.label;
    return '$place · ${steps.join(' + ')}';
  }
  return [
    if (stage.develop) 'Developed',
    if (stage.scan) 'Scanned',
    if (stage.print) 'Printed',
  ].join(' + ');
}
