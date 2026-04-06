import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../../theme/theme.dart';

class PreworkReceiveInTransitState extends StatelessWidget {
  final String palletId;
  final EdgeInsets padding;

  const PreworkReceiveInTransitState({
    super.key,
    required this.palletId,
    required this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.warning.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.warning.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(
              MdiIcons.truckDeliveryOutline,
              color: AppTheme.warning,
              size: 40,
            ),
            const SizedBox(height: 12),
            Text(
              palletId,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              'AMR is delivering the pallet...',
              style: TextStyle(fontSize: 14, color: AppTheme.textGrey(context)),
            ),
            const SizedBox(height: 8),
            Text(
              'Call API simulate/asrs/receive-pallet\nto simulate pallet arrival at Prework',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: AppTheme.textGrey(context)),
            ),
          ],
        ),
      ),
    );
  }
}
