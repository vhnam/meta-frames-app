import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/models/models.dart';
import '../../../domain/models/roll_stage.dart';
import '../../../routing/routes.dart';
import '../../core/theme.dart';
import '../../core/widgets/common.dart';

/// One roll: status-tinted icon, name, meta line, stage and process stamps.
/// Opens the roll. Used by every list of rolls that is not inside a detail.
class RollCard extends StatelessWidget {
  const RollCard({
    super.key,
    required this.roll,
    this.process,
    this.expiring = false,
    this.extraBadge,
    this.idHint,
  });
  final RollSummary roll;
  final Process? process;

  /// Warning outline and icon for film that is expired or about to be.
  final bool expiring;

  /// Shown after the status stamps, e.g. "Expired".
  final Widget? extraBadge;

  /// The start of the roll's id, when another roll in the list looks the same.
  final String? idHint;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tone = statusTone(context, roll.status);
    final meta = [_meta(roll), if (idHint != null) '#$idHint'].join(' · ');
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
                        StampBadge(rollStageLabel(roll), color: tone),
                        if (process != null) ProcessBadge(process!),
                        ?extraBadge,
                        if (_showsLabStamp(roll))
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

String _meta(RollSummary roll) => [
  '${roll.format} · ${roll.exposures} exp',
  if (roll.cameraName != null) roll.cameraName!,
  if (roll.shotIso != null) 'ISO ${roll.shotIso}',
  if (roll.startedAt != null) fmtDate(roll.startedAt),
  if (roll.expiry != null && roll.status == RollStatus.inStock)
    'exp ${roll.expiry}',
].join(' · ');

/// The stage label does not already say a lab has the roll.
bool _showsLabStamp(RollSummary roll) =>
    roll.negativesAtLab && !stageLabelSaysLab(roll);

/// For rolls whose cards would read the same (stock, meta line, stage label
/// and Negatives at lab stamp), the shortest start of the id, from 4 characters, that tells them
/// apart. Rolls that already differ get none.
Map<String, String> rollIdHints(List<RollSummary> rolls) {
  final groups = <String, Set<String>>{};
  for (final roll in rolls) {
    final look = [
      roll.stockLabel,
      _meta(roll),
      rollStageLabel(roll),
      _showsLabStamp(roll),
    ].join('|');
    (groups[look] ??= {}).add(roll.id);
  }
  final hints = <String, String>{};
  for (final ids in groups.values.where((ids) => ids.length > 1)) {
    // A set holds each id once, so at full length the prefixes differ.
    var length = 4;
    while ({for (final id in ids) _prefix(id, length)}.length < ids.length) {
      length++;
    }
    for (final id in ids) {
      hints[id] = _prefix(id, length);
    }
  }
  return hints;
}

String _prefix(String id, int length) =>
    id.length <= length ? id : id.substring(0, length);
