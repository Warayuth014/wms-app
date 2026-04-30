import 'package:flutter/material.dart';

import '../../../../../models/wms_models.dart';
import '../../../../../theme/theme.dart';
import '../../../../../widgets/common_widgets.dart';

class PickingRemainingItemsCard extends StatelessWidget {
  final List<PickRemainingItem> remainingItems;

  const PickingRemainingItemsCard({
    super.key,
    required this.remainingItems,
  });

  @override
  Widget build(BuildContext context) {
    final visibleItems = remainingItems
        .where((item) => item.remainingQty > 0)
        .toList();

    return WmsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.pending_actions,
                color: AppTheme.warning,
                size: 18,
              ),
              SizedBox(width: 6),
              Text(
                'ยังต้อง Pick เพิ่ม',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...visibleItems.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Icon(
                    Icons.arrow_right,
                    size: 14,
                    color: AppTheme.textGrey(context),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${item.partId}: ${item.itemDesc}',
                      style: const TextStyle(fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    'เหลือ ${item.remainingQty}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.warning,
                    ),
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
