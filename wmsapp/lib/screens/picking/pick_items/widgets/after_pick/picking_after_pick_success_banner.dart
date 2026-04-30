import 'package:flutter/material.dart';

import '../../../../../theme/theme.dart';

class PickingAfterPickSuccessBanner extends StatelessWidget {
  final bool isComplete;
  final String? destPalletId;

  const PickingAfterPickSuccessBanner({
    super.key,
    required this.isComplete,
    required this.destPalletId,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.success.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.success.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        children: [
          Icon(
            isComplete ? Icons.celebration : Icons.check_circle,
            color: AppTheme.success,
            size: 48,
          ),
          const SizedBox(height: 8),
          Text(
            isComplete ? 'Pick Order ครบแล้ว!' : 'Pick รอบนี้สำเร็จ',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.success,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Dest Pallet: ${destPalletId ?? '-'}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary(context),
            ),
          ),
        ],
      ),
    );
  }
}
