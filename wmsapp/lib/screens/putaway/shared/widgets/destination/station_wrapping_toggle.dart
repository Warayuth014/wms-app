import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../../../theme/theme.dart';

class StationWrappingToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const StationWrappingToggle({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: value ? AppTheme.primary.withValues(alpha: 0.08) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: value ? AppTheme.primary.withValues(alpha: 0.5) : Colors.grey.shade200,
          ),
        ),
        child: Row(
          children: [
            Icon(
              MdiIcons.textBoxOutline,
              color: value ? AppTheme.primary : Colors.grey,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'พันสินค้า (Wrapping Machine)',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: value ? AppTheme.primary : AppTheme.textPrimary(context),
                    ),
                  ),
                  Text(
                    'พัน Pallet ก่อนนำเข้า ASRS',
                    style: TextStyle(fontSize: 11, color: AppTheme.textGrey(context)),
                  ),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: AppTheme.primary,
            ),
          ],
        ),
      ),
    );
  }
}
