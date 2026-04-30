import 'package:flutter/material.dart';

import '../../../shared/putaway_shared_widgets.dart';

class PreworkReceiveSheetHeader extends StatelessWidget {
  final StationInfo station;
  final String? palletId;
  final String? palletStatus;

  const PreworkReceiveSheetHeader({
    super.key,
    required this.station,
    required this.palletId,
    required this.palletStatus,
  });

  @override
  Widget build(BuildContext context) {
    final hasPallet = palletId != null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: station.color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(station.icon, color: Colors.white, size: 28),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  station.id,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  hasPallet ? palletId! : 'Empty - waiting for pallet',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const Spacer(),
            if (hasPallet)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  palletStatus ?? '',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
