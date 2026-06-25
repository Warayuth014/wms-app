import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../../../theme/theme.dart';
import '../../../../../widgets/common_widgets.dart';

class UnloadPalletInfoCard extends StatelessWidget {
  final String palletId;
  final int itemCount;
  final int? sessionId;
  final int confirmedCount;
  final int totalCount;

  const UnloadPalletInfoCard({
    super.key,
    required this.palletId,
    required this.itemCount,
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
                  palletId,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                Text(
                  'Session #${sessionId ?? '-'} - $itemCount รายการ',
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
