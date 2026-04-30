import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../shared/putaway_shared_widgets.dart';
import 'prework_column_header.dart';
import 'prework_receive_station_card.dart';

class PreworkReceiveColumn extends StatelessWidget {
  final List<StationInfo> stations;
  final Color color;
  final String? returnAnimStation;
  final String returnAnimText;
  final Map<String, Map<String, dynamic>> receiveStatus;
  final ValueChanged<StationInfo> onStationTap;

  const PreworkReceiveColumn({
    super.key,
    required this.stations,
    required this.color,
    required this.returnAnimStation,
    required this.returnAnimText,
    required this.receiveStatus,
    required this.onStationTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        PreworkColumnHeader(
          label: 'รับ Pallet',
          icon: MdiIcons.trayArrowDown,
          color: color,
        ),
        const SizedBox(height: 10),
        for (final station in stations) ...[
          PreworkReceiveStationCard(
            station: station,
            isReturning: returnAnimStation == station.id,
            returnAnimText: returnAnimText,
            info: receiveStatus[station.id],
            onTap: () => onStationTap(station),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}
