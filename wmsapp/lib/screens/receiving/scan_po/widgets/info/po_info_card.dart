import 'package:flutter/material.dart';

import '../../../../../models/wms_models.dart';
import '../../../../../theme/theme.dart';
import '../../../../../widgets/common_widgets.dart';

class PoInfoCard extends StatelessWidget {
  final POResponse po;

  const PoInfoCard({
    super.key,
    required this.po,
  });

  @override
  Widget build(BuildContext context) {
    return WmsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                po.poId,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primary,
                ),
              ),
              StatusBadge(po.status),
            ],
          ),
          const Divider(height: 20),
          InfoRow(label: 'Supplier', value: po.supplierName),
          InfoRow(label: 'จำนวน Part', value: '${po.items.length} รายการ'),
          InfoRow(
            label: 'รับแล้ว',
            value:
                '${po.items.where((item) => item.status == 'RECEIVED').length} รายการ',
          ),
        ],
      ),
    );
  }
}
