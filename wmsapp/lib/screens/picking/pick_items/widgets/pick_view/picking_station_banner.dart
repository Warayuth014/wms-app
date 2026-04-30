import 'package:flutter/material.dart';

import '../../../../../models/wms_models.dart';
import '../../../../../theme/theme.dart';

class PickingStationBanner extends StatelessWidget {
  final AssignPickStationResponse assignment;

  const PickingStationBanner({
    super.key,
    required this.assignment,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.success.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppTheme.success.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.location_on,
            color: AppTheme.success,
            size: 22,
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                assignment.stationName,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: AppTheme.success,
                ),
              ),
              Text(
                'Station: ${assignment.stationId}',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textGrey(context),
                ),
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              assignment.palletId,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: AppTheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
