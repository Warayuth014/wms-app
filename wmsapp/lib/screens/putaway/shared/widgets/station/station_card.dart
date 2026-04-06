import 'package:flutter/material.dart';

import '../../../../../theme/theme.dart';
import '../../models/station_info.dart';
import 'station_dispatching_content.dart';
import 'station_normal_content.dart';

class StationCard extends StatefulWidget {
  final StationInfo station;
  final VoidCallback onTap;
  final bool isDispatching;
  final String? busyPalletId;
  final String? busyDestination;

  const StationCard({
    super.key,
    required this.station,
    required this.onTap,
    this.isDispatching = false,
    this.busyPalletId,
    this.busyDestination,
  });

  @override
  State<StationCard> createState() => _StationCardState();
}

class _StationCardState extends State<StationCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    if (widget.isDispatching) _ctrl.repeat();
  }

  @override
  void didUpdateWidget(StationCard old) {
    super.didUpdateWidget(old);
    if (widget.isDispatching && !old.isDispatching) {
      _ctrl.repeat();
    } else if (!widget.isDispatching && old.isDispatching) {
      _ctrl.stop();
      _ctrl.reset();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
        decoration: BoxDecoration(
          color: widget.isDispatching ? AppTheme.danger : widget.station.color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color:
                  (widget.isDispatching
                          ? AppTheme.danger
                          : widget.station.color)
                      .withValues(alpha: 0.4),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: widget.isDispatching
            ? StationDispatchingContent(
                animation: _ctrl,
                station: widget.station,
                busyPalletId: widget.busyPalletId,
                busyDestination: widget.busyDestination,
              )
            : StationNormalContent(
                station: widget.station,
                busyPalletId: widget.busyPalletId,
                busyDestination: widget.busyDestination,
              ),
      ),
    );
  }
}
