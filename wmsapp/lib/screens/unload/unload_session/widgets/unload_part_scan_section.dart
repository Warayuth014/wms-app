import 'package:flutter/material.dart';

import '../../../../theme/theme.dart';
import '../../../../widgets/common_widgets.dart';

class UnloadPartScanSection extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSubmit;

  const UnloadPartScanSection({
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
          'สแกน Part',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary(context),
          ),
        ),
        const SizedBox(height: 12),
        ScanTextField(
          controller: controller,
          label: 'Part ID เช่น PT-1122',
          hint: 'PT-1122',
          onSubmit: onSubmit,
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
