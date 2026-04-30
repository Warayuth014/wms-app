import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../../../theme/theme.dart';
import '../../../../../widgets/common_widgets.dart';

class PickingScanSourceCard extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onScan;

  const PickingScanSourceCard({
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
              Icon(MdiIcons.barcodeScan, color: AppTheme.primary),
              const SizedBox(width: 8),
              Text(
                'Scan Source Pallet',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'สแกน Pallet ที่ต้องการหยิบของออก',
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textGrey(context),
            ),
          ),
          const SizedBox(height: 12),
          ScanTextField(
            label: 'Source Pallet ID',
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
