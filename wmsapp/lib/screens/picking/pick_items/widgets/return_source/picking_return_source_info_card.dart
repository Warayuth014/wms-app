import 'package:flutter/material.dart';

import '../../../../../theme/theme.dart';

class PickingReturnSourceInfoCard extends StatelessWidget {
  final String palletId;

  const PickingReturnSourceInfoCard({
    super.key,
    required this.palletId,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.warning.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.info_outline,
            color: AppTheme.warning,
            size: 40,
          ),
          const SizedBox(height: 8),
          Text(
            palletId,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'ไม่มีสินค้าที่ต้อง Pick บน Pallet นี้',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textGrey(context),
            ),
          ),
        ],
      ),
    );
  }
}
