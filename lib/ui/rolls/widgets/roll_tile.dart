import 'package:flutter/material.dart';

import '../../../domain/models/models.dart';
import '../../core/widgets/common.dart';
import '../../../routing/routes.dart';

import 'package:go_router/go_router.dart';

class RollTile extends StatelessWidget {
  const RollTile({super.key, required this.roll, this.trailing});
  final RollSummary roll;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => ListTile(
    title: Text(roll.stockLabel),
    subtitle: Text(
      [
        '${roll.format} · ${roll.exposures} exp',
        if (roll.cameraName != null) roll.cameraName!,
        if (roll.shotIso != null) 'ISO ${roll.shotIso}',
        if (roll.startedAt != null) fmtDate(roll.startedAt),
        if (roll.expiry != null && roll.status == RollStatus.inStock)
          'exp ${roll.expiry}',
      ].join(' · '),
    ),
    trailing:
        trailing ??
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            StatusChip(roll.status),
            if (roll.negativesAtLab)
              Text(
                'Negatives at lab',
                style: TextStyle(
                  fontSize: 10,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
          ],
        ),
    onTap: () => context.push(Routes.roll(roll.id)),
  );
}
