import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../../../theme/theme.dart';
import '../../../../../widgets/common_widgets.dart';

class PutawayStationScanCard extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSubmit;

  const PutawayStationScanCard({
    super.key,
    required this.controller,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return WmsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(MdiIcons.barcodeScan, color: AppTheme.primary, size: 20),
              const SizedBox(width: 8),
              const Text(
                'สแกนบาร์โค้ด Station',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'หรือกดที่รูป Station ด้านล่าง',
            style: TextStyle(fontSize: 12, color: AppTheme.textGrey(context)),
          ),
          const SizedBox(height: 12),
          ScanTextField(
            label: 'Station ID',
            hint: 'เช่น STN-1',
            controller: controller,
            onSubmit: onSubmit,
          ),
        ],
      ),
    );
  }
}
