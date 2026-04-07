import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../theme/theme.dart';
import '../../../widgets/common_widgets.dart';

class PackingScanCard extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onScan;

  const PackingScanCard({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onScan,
  });

  @override
  Widget build(BuildContext context) {
    return WmsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                MdiIcons.barcodeScan,
                color: AppTheme.primary,
                size: 24,
              ),
              const SizedBox(width: 8),
              const Text(
                'Scan Pallet เพื่อ Pack',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Pallet ต้องมีสถานะ PACKED จาก Picking ก่อน',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textGrey(context),
            ),
          ),
          const SizedBox(height: 16),
          ScanTextField(
            label: 'Pallet ID',
            hint: 'Scan Pallet ID',
            controller: controller,
            focusNode: focusNode,
            onSubmit: onScan,
          ),
          const SizedBox(height: 12),
          PrimaryButton(
            label: 'Scan',
            icon: Icons.search,
            onPressed: onScan,
          ),
        ],
      ),
    );
  }
}
