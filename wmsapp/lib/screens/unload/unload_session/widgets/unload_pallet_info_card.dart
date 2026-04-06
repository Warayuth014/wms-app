import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../../models/wms_models.dart';
import '../../../../theme/theme.dart';
import '../../../../widgets/common_widgets.dart';

class UnloadPalletInfoCard extends StatelessWidget {
  final PalletScanResponse pallet;
  final int? sessionId;
  final int confirmedCount;
  final int totalCount;

  const UnloadPalletInfoCard({
    super.key,
    required this.pallet,
    required this.sessionId,
    required this.confirmedCount,
    required this.totalCount,
  });

  @override
  Widget build(BuildContext context) {
    return WmsCard(
      child: Row(
        children: [
          Icon(
            MdiIcons.packageVariantClosed,
            color: AppTheme.primary,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pallet.palletId,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                Text(
                  'Session #${sessionId ?? '-'} - ${pallet.items.length} รายการ',
                  style: TextStyle(
                    color: AppTheme.textGrey(context),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '$confirmedCount/$totalCount',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppTheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}
