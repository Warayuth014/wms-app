import 'package:flutter/material.dart';

import '../../../shared/putaway_shared_widgets.dart';

class PreworkReceiveStationCard extends StatelessWidget {
  final StationInfo station;
  final bool isReturning;
  final String returnAnimText;
  final Map<String, dynamic>? info;
  final VoidCallback onTap;

  const PreworkReceiveStationCard({
    super.key,
    required this.station,
    required this.isReturning,
    required this.returnAnimText,
    required this.info,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (isReturning) {
      return StationCard(
        station: station,
        isDispatching: true,
        busyPalletId: '',
        busyDestination: returnAnimText,
        onTap: () {},
      );
    }

    final palletId = info?['palletId'] as String?;
    final palletStatus = info?['palletStatus'] as String?;
    final isInTransit = palletStatus == 'IN_TRANSIT';
    final hasPallet = palletId != null;

    return StationCard(
      station: station,
      isDispatching: isInTransit,
      busyPalletId: palletId,
      busyDestination: isInTransit
          ? 'Arriving...'
          : hasPallet
              ? 'Cut complete'
              : null,
      onTap: onTap,
    );
  }
}
