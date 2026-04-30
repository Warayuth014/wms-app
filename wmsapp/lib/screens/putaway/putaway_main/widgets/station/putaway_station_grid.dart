import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../../../widgets/common_widgets.dart';
import '../../../shared/putaway_shared_widgets.dart';

class PutawayStationGrid extends StatelessWidget {
  final List<StationInfo> stations;
  final Map<String, Map<String, dynamic>> stationStatus;
  final ValueChanged<StationInfo> onStationTap;

  const PutawayStationGrid({
    super.key,
    required this.stations,
    required this.stationStatus,
    required this.onStationTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'เลือก Station',
          icon: MdiIcons.viewGridOutline,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            for (int i = 0; i < stations.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(
                child: StationCard(
                  station: stations[i],
                  isDispatching: stationStatus.containsKey(stations[i].id),
                  busyPalletId: stationStatus[stations[i].id]?['palletId'] as String?,
                  busyDestination:
                      stationStatus[stations[i].id]?['destination'] as String?,
                  onTap: () => onStationTap(stations[i]),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
