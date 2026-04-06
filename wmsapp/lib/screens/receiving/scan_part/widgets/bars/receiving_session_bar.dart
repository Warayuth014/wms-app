import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../../../models/wms_models.dart';
import '../../../../../theme/theme.dart';

class ReceivingSessionBar extends StatelessWidget {
  final POResponse po;
  final ReceivingSession session;

  const ReceivingSessionBar({
    super.key,
    required this.po,
    required this.session,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(MdiIcons.fileDocumentOutline, color: AppTheme.primary, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  po.poId,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppTheme.primary,
                  ),
                ),
                Text(
                  po.supplierName,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textGrey(context),
                  ),
                ),
              ],
            ),
          ),
          Text(
            'Session #${session.sessionId}',
            style: TextStyle(fontSize: 12, color: AppTheme.textGrey(context)),
          ),
        ],
      ),
    );
  }
}
