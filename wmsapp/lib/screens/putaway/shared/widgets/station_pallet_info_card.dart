import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../../models/wms_models.dart';
import '../../../../theme/theme.dart';
import '../../../../widgets/common_widgets.dart';

class StationPalletInfoCard extends StatelessWidget {
  final PutawayPalletInfo pallet;
  final bool hasFixedDestination;
  final VoidCallback onViewItems;

  const StationPalletInfoCard({
    super.key,
    required this.pallet,
    required this.hasFixedDestination,
    required this.onViewItems,
  });

  @override
  Widget build(BuildContext context) {
    final isFG = pallet.type == 'FG';
    final typeColor = isFG ? AppTheme.success : AppTheme.warning;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.background(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                pallet.palletId,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary(context),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  pallet.type,
                  style: TextStyle(
                    color: typeColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 16),
          InfoRow(label: 'สถานะ', value: pallet.status),
          InfoRow(
            label: 'ปลายทาง',
            value: hasFixedDestination ? 'ASRS (convert PW->FG)' : 'เลือกด้านล่าง',
          ),
          InfoRow(label: 'สินค้า', value: '${pallet.items.length} รายการ'),
          if (pallet.message.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              pallet.message,
              style: TextStyle(color: AppTheme.textGrey(context), fontSize: 12),
            ),
          ],
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onViewItems,
              icon: Icon(MdiIcons.eyeOutline, size: 18),
              label: Text('ดูสินค้าใน Pallet (${pallet.items.length})'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primary,
                side: const BorderSide(color: AppTheme.primary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
