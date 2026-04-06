import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../../theme/theme.dart';
import '../../../../widgets/common_widgets.dart';

class CurrentPalletBar extends StatelessWidget {
  final String palletId;
  final String palletType;
  final VoidCallback onClear;

  const CurrentPalletBar({
    super.key,
    required this.palletId,
    required this.palletType,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final color = palletType == 'FG' ? AppTheme.success : AppTheme.warning;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(MdiIcons.packageVariantClosed, color: color, size: 18),
          const SizedBox(width: 8),
          Text(
            'Pallet: $palletId',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: color,
            ),
          ),
          const SizedBox(width: 8),
          StatusBadge(palletType),
          const Spacer(),
          GestureDetector(
            onTap: onClear,
            child: Icon(
              Icons.close,
              size: 18,
              color: AppTheme.textGrey(context),
            ),
          ),
        ],
      ),
    );
  }
}
