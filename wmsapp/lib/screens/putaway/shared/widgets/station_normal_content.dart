import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../models/station_info.dart';

class StationNormalContent extends StatelessWidget {
  final StationInfo station;
  final String? busyPalletId;
  final String? busyDestination;

  const StationNormalContent({
    super.key,
    required this.station,
    required this.busyPalletId,
    required this.busyDestination,
  });

  @override
  Widget build(BuildContext context) {
    final hasBusy = busyPalletId != null;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(station.icon, color: Colors.white, size: 30),
        ),
        const SizedBox(height: 10),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [_AgvWheel(), SizedBox(width: 8), _AgvWheel()],
        ),
        const SizedBox(height: 8),
        Text(
          station.id,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
        Text(
          station.label,
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
        if (hasBusy) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Text(
                  busyPalletId!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (busyDestination != null)
                  Text(
                    busyDestination!,
                    style: const TextStyle(color: Colors.white70, fontSize: 10),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                hasBusy ? Icons.info_outline : MdiIcons.gestureTap,
                color: Colors.white,
                size: 11,
              ),
              const SizedBox(width: 3),
              Text(
                hasBusy ? 'กดดูรายละเอียด' : 'กดเลือก',
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AgvWheel extends StatelessWidget {
  const _AgvWheel();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.5),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
      ),
    );
  }
}
