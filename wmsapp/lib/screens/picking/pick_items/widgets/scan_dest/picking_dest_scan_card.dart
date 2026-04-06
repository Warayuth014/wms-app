import 'package:flutter/material.dart';

import '../../../../../theme/theme.dart';
import '../../../../../widgets/common_widgets.dart';

class PickingDestScanCard extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onConfirm;

  const PickingDestScanCard({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return WmsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.qr_code_scanner, color: AppTheme.secondary),
              SizedBox(width: 8),
              Text(
                'Scan Pallet ปลายทาง',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'สแกน Pallet ปลายทางที่จะใส่สินค้าที่หยิบมา',
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textGrey(context),
            ),
          ),
          const SizedBox(height: 12),
          ScanTextField(
            label: 'Dest Pallet ID',
            hint: 'Scan Pallet ปลายทาง',
            controller: controller,
            focusNode: focusNode,
            onSubmit: onConfirm,
          ),
          const SizedBox(height: 12),
          PrimaryButton(
            label: 'ยืนยัน',
            icon: Icons.check,
            onPressed: onConfirm,
          ),
        ],
      ),
    );
  }
}
