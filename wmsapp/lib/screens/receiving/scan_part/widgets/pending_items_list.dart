import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../../models/wms_models.dart';
import '../../../../theme/theme.dart';
import '../../../../widgets/common_widgets.dart';

class PendingItemsList extends StatelessWidget {
  final List<POItem> items;
  final String title;
  final String quantitySuffix;

  const PendingItemsList({
    super.key,
    required this.items,
    required this.title,
    required this.quantitySuffix,
  });

  @override
  Widget build(BuildContext context) {
    return WmsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppTheme.textGrey(context),
            ),
          ),
          const SizedBox(height: 12),
          ...items.map(
            (item) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.background(context),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.radio_button_unchecked, color: Colors.grey, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.partId,
                          style: const TextStyle(fontWeight: FontWeight.w600),
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
                            if (item.lotNumber != null && item.lotNumber!.isNotEmpty) ...[
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
                                      style: TextStyle(fontWeight: FontWeight.bold),
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
                      ],
                    ),
                  ),
                  Text(
                    '${item.qtyRemaining > 0 ? item.qtyRemaining : item.qtyOrdered} $quantitySuffix',
                    style: TextStyle(
                      color: AppTheme.textGrey(context),
                      fontSize: 13,
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
