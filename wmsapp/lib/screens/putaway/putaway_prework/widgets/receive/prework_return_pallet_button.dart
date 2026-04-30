import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../../../theme/theme.dart';

class PreworkReturnPalletButton extends StatelessWidget {
  final EdgeInsets padding;
  final VoidCallback onPressed;

  const PreworkReturnPalletButton({
    super.key,
    required this.padding,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: onPressed,
          icon: Icon(MdiIcons.undoVariant, color: Colors.white),
          label: const Text(
            'Return Empty Pallet',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: Colors.white,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.danger,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }
}
