import 'package:flutter/material.dart';

import '../../../../../models/wms_models.dart';
import '../../../../../theme/theme.dart';
import '../../../../../widgets/common_widgets.dart';

class PickingPickedSummaryCard extends StatelessWidget {
  final Map<String, int> pickedItems;
  final List<PickItemOnPallet> palletItems;

  const PickingPickedSummaryCard({
    super.key,
    required this.pickedItems,
    required this.palletItems,
  });

  @override
  Widget build(BuildContext context) {
    return WmsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.check_circle, color: AppTheme.success, size: 18),
              SizedBox(width: 6),
              Text(
                'รายการที่หยิบ',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...pickedItems.entries.map((entry) {
            final item = palletItems.firstWhere(
              (palletItem) => palletItem.partId == entry.key,
            );
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  const Icon(Icons.check, size: 14, color: AppTheme.success),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${entry.key} - ${item.itemDesc}',
                      style: const TextStyle(fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    'x${entry.value}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.success,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
