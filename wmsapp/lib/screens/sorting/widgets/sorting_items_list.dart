import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../models/wms_models.dart';
import '../../../theme/theme.dart';
import '../../../widgets/common_widgets.dart';

class SortingItemsList extends StatelessWidget {
  final List<SortSessionItem> items;

  const SortingItemsList({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return WmsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                MdiIcons.formatListBulleted,
                color: AppTheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'รายการ Carton ที่ Sort แล้ว',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'ยังไม่มี Carton ที่สแกน',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textGrey(context),
                  ),
                ),
              ),
            )
          else
            ...items.map((item) => _buildItem(context, item)),
        ],
      ),
    );
  }

  Widget _buildItem(BuildContext context, SortSessionItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppTheme.success.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            MdiIcons.checkCircle,
            color: AppTheme.success,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.sourcePalletId,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (item.trackingId != null && item.trackingId!.isNotEmpty)
                  Text(
                    item.trackingId!,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.textGrey(context),
                    ),
                  ),
              ],
            ),
          ),
          Text(
            '${item.scannedAt.toLocal()}'.split('.').first.split(' ').last,
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.textGrey(context),
            ),
          ),
        ],
      ),
    );
  }
}
