import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../../models/wms_models.dart';
import '../../../../theme/theme.dart';
import '../../../../widgets/common_widgets.dart';
import '../../../../widgets/part_thumbnail.dart';

class PoItemsList extends StatelessWidget {
  final List<POItem> items;

  const PoItemsList({
    super.key,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return WmsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'รายการสินค้า',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          ...items.map(
            (item) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.background(context),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: item.status == 'RECEIVED'
                      ? AppTheme.success.withValues(alpha: 0.3)
                      : Colors.grey.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  PartThumbnail(imageUrl: item.imageUrl),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.partId,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          item.itemDesc,
                          style: TextStyle(
                            color: AppTheme.textGrey(context),
                            fontSize: 12,
                          ),
                        ),
                        Row(
                          children: [
                            if (item.lotNumber != null &&
                                item.lotNumber!.isNotEmpty) ...[
                              Icon(
                                MdiIcons.tagOutline,
                                size: 12,
                                color: AppTheme.textGrey(context),
                              ),
                              const SizedBox(width: 2),
                              RichText(
                                text: TextSpan(
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textGrey(context),
                                  ),
                                  children: [
                                    const TextSpan(
                                      text: 'Batch No',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    TextSpan(text: ' : ${item.lotNumber!}'),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            StatusBadge(item.condition),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${item.owner} / ${item.brand}',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.textGrey(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${item.qtyReceived}/${item.qtyOrdered}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        'ชิ้น',
                        style: TextStyle(
                          color: AppTheme.textGrey(context),
                          fontSize: 12,
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
