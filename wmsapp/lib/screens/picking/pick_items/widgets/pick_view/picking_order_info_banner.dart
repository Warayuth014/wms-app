import 'package:flutter/material.dart';

import '../../../../../theme/theme.dart';

class PickingOrderInfoBanner extends StatelessWidget {
  final String pickOrderId;

  const PickingOrderInfoBanner({
    super.key,
    required this.pickOrderId,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.assignment, color: AppTheme.primary, size: 18),
          const SizedBox(width: 6),
          Text(
            'Pick Order: $pickOrderId',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: AppTheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}
