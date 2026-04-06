import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../../theme/theme.dart';
import '../models/station_info.dart';

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
            ? _buildDispatchingContent()
            : _buildNormalContent(),
      ),
    );
  }

  Widget _buildDispatchingContent() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(MdiIcons.robotIndustrialOutline, color: Colors.white70, size: 22),
        ),
        const SizedBox(height: 6),
        AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _arrow(phase: 0.0),
                const SizedBox(width: 2),
                _arrow(phase: 0.33),
                const SizedBox(width: 2),
                _arrow(phase: 0.66),
              ],
            );
          },
        ),
        const SizedBox(height: 6),
        Text(
          widget.station.id,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          widget.station.pwRole == PWRole.receive
              ? 'AMR กำลังนำ Pallet มา...'
              : 'AMR กำลังมารับ...',
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
        if (widget.busyPalletId != null) ...[
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
                  widget.busyPalletId!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (widget.busyDestination != null)
                  Text(
                    '-> ${widget.busyDestination}',
                    style: const TextStyle(color: Colors.white70, fontSize: 10),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _arrow({required double phase}) {
    double t = (_ctrl.value - phase) % 1.0;
    double opacity = t < 0.5 ? t * 2 : (1.0 - t) * 2;
    opacity = opacity.clamp(0.15, 1.0);
    return Opacity(
      opacity: opacity,
      child: const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 22),
    );
  }

  Widget _buildNormalContent() {
    final hasBusy = widget.busyPalletId != null;

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
          child: Icon(widget.station.icon, color: Colors.white, size: 30),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [_agvWheel(), const SizedBox(width: 8), _agvWheel()],
        ),
        const SizedBox(height: 8),
        Text(
          widget.station.id,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
        Text(
          widget.station.label,
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
                  widget.busyPalletId!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (widget.busyDestination != null)
                  Text(
                    widget.busyDestination!,
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

  Widget _agvWheel() => Container(
    width: 10,
    height: 10,
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.5),
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 1.5),
    ),
  );
}
