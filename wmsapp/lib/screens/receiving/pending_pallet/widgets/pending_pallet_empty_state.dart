import 'package:flutter/material.dart';

import '../../../../theme/theme.dart';

class PendingPalletEmptyState extends StatelessWidget {
  const PendingPalletEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_outline, size: 72, color: AppTheme.success),
          const SizedBox(height: 16),
          Text(
            'ไม่มีรายการค้างการผูก Pallet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textGrey(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'ทุกรายการผูก Pallet เรียบร้อยแล้ว',
            style: TextStyle(fontSize: 14, color: AppTheme.textGrey(context)),
          ),
        ],
      ),
    );
  }
}
