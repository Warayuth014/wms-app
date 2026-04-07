import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../models/wms_models.dart';
import '../../../theme/theme.dart';
import '../../../widgets/common_widgets.dart';

class SortingSessionHeader extends StatelessWidget {
  final SortSession session;

  const SortingSessionHeader({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    return WmsCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              MdiIcons.sortVariant,
              color: AppTheme.primary,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Station ${session.stationId}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textGrey(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  session.sortPalletId,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Session #${session.sessionId} • ${session.status}',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.textGrey(context),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.secondary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${session.items.length} Carton',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.secondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
