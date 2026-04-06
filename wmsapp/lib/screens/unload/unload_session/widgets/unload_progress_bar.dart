import 'package:flutter/material.dart';

import '../../../../theme/theme.dart';

class UnloadProgressBar extends StatelessWidget {
  final int confirmedCount;
  final int totalCount;
  final bool allConfirmed;

  const UnloadProgressBar({
    super.key,
    required this.confirmedCount,
    required this.totalCount,
    required this.allConfirmed,
  });

  @override
  Widget build(BuildContext context) {
    final progress = totalCount == 0 ? 0.0 : confirmedCount / totalCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Unload แล้ว $confirmedCount จาก $totalCount',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '${(progress * 100).toInt()}%',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppTheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(
              allConfirmed ? AppTheme.success : AppTheme.primary,
            ),
          ),
        ),
      ],
    );
  }
}
