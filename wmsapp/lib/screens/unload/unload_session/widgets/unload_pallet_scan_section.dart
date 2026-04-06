import 'package:flutter/material.dart';

import '../../../../theme/theme.dart';
import '../../../../widgets/common_widgets.dart';

class UnloadPalletScanSection extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSubmit;

  const UnloadPalletScanSection({
    super.key,
    required this.controller,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'สแกน Pallet',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary(context),
          ),
        ),
        const SizedBox(height: 12),
        ScanTextField(
          controller: controller,
          label: 'Pallet ID เช่น PAL-001',
          hint: 'PAL-001',
          onSubmit: onSubmit,
        ),
      ],
    );
  }
}
