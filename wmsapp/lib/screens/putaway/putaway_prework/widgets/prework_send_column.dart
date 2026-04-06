import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../shared/putaway_shared_widgets.dart';
import 'prework_column_header.dart';

class PreworkSendColumn extends StatelessWidget {
  final List<StationInfo> stations;
  final Color color;
  final Map<String, Map<String, dynamic>> stationStatus;
  final ValueChanged<StationInfo> onStationTap;

  const PreworkSendColumn({
    super.key,
    required this.stations,
    required this.color,
    required this.stationStatus,
    required this.onStationTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        PreworkColumnHeader(
          label: 'ส่ง Pallet',
          icon: MdiIcons.trayArrowUp,
          color: color,
        ),
        const SizedBox(height: 10),
        for (final station in stations) ...[
          StationCard(
            station: station,
            isDispatching: stationStatus.containsKey(station.id),
            busyPalletId: stationStatus[station.id]?['palletId'] as String?,
            busyDestination: stationStatus[station.id]?['destination'] as String?,
            onTap: () => onStationTap(station),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}
