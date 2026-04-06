import 'package:flutter/material.dart';

import '../../../../theme/theme.dart';
import '../../../../widgets/common_widgets.dart';
import '../ui_models/assigned_receiving_line.dart';

class AssignedList extends StatelessWidget {
  final List<AssignedReceivingLine> lines;
  final String titlePrefix;
  final String quantitySuffix;

  const AssignedList({
    super.key,
    required this.lines,
    required this.titlePrefix,
    required this.quantitySuffix,
  });

  @override
  Widget build(BuildContext context) {
    return WmsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle, color: AppTheme.success, size: 18),
              const SizedBox(width: 6),
              Text(
                '$titlePrefix (${lines.length})',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...lines.map(
            (line) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.success.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppTheme.success.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: AppTheme.success, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          line.partId,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          line.itemDesc,
                          style: TextStyle(
                            color: AppTheme.textGrey(context),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${line.qtyReceived} $quantitySuffix',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '${line.palletId} (${line.condition})',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textGrey(context),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
