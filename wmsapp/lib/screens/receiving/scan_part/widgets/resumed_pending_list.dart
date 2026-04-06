import 'package:flutter/material.dart';

import '../../../../models/wms_models.dart';
import '../../../../theme/theme.dart';
import '../../../../widgets/common_widgets.dart';

class ResumedPendingList extends StatelessWidget {
  final List<ReceiptLineResponse> lines;
  final bool canAssign;
  final String title;
  final String buttonLabel;
  final String quantitySuffix;
  final void Function(ReceiptLineResponse line) onAssign;

  const ResumedPendingList({
    super.key,
    required this.lines,
    required this.canAssign,
    required this.title,
    required this.buttonLabel,
    required this.quantitySuffix,
    required this.onAssign,
  });

  @override
  Widget build(BuildContext context) {
    return WmsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.warning,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${lines.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...lines.map(
            (line) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.warning.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppTheme.warning.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
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
                      StatusBadge(line.condition),
                    ],
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: canAssign ? () => onAssign(line) : null,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(buttonLabel, style: const TextStyle(fontSize: 13)),
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
