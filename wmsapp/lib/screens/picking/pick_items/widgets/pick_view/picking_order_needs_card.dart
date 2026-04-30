import 'package:flutter/material.dart';

import '../../../../../models/wms_models.dart';
import '../../../../../theme/theme.dart';
import '../../../../../widgets/common_widgets.dart';

class PickingOrderNeedsCard extends StatelessWidget {
  final String pickOrderId;
  final List<PickOrderDetail> pickOrderItems;

  const PickingOrderNeedsCard({
    super.key,
    required this.pickOrderId,
    required this.pickOrderItems,
  });

  @override
  Widget build(BuildContext context) {
    return WmsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.assignment,
                color: AppTheme.secondary,
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                'Pick Order: $pickOrderId',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...pickOrderItems.map(
            (orderItem) => Padding(
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
                      '${orderItem.partId}: ${orderItem.itemDesc}',
                      style: const TextStyle(fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    'ต้องการ ${orderItem.remainingQty}',
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
