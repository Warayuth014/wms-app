import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../theme/theme.dart';
import '../../../widgets/common_widgets.dart';

class SortingCartonScanCard extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onScan;

  const SortingCartonScanCard({
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
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'สแกน Carton ลง Pallet',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'รับได้ทั้ง Tracking ID หรือ Pallet ID',
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.textGrey(context),
            ),
          ),
          const SizedBox(height: 12),
          ScanTextField(
            label: 'Carton / Tracking',
            hint: 'Scan Carton',
            controller: controller,
            focusNode: focusNode,
            onSubmit: onScan,
          ),
        ],
      ),
    );
  }
}
