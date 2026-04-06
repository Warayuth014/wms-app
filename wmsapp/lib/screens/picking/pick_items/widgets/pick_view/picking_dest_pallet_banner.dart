import 'package:flutter/material.dart';

import '../../../../../theme/theme.dart';

class PickingDestPalletBanner extends StatelessWidget {
  final String destPalletId;

  const PickingDestPalletBanner({
    super.key,
    required this.destPalletId,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.secondary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.secondary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.inventory_2, color: AppTheme.secondary, size: 18),
          const SizedBox(width: 6),
          Text(
            'Dest Pallet: $destPalletId',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: AppTheme.secondary,
            ),
          ),
        ],
      ),
    );
  }
}
