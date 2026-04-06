import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../models/station_info.dart';

class StationDispatchingContent extends StatelessWidget {
  final Animation<double> animation;
  final StationInfo station;
  final String? busyPalletId;
  final String? busyDestination;

  const StationDispatchingContent({
    super.key,
    required this.animation,
    required this.station,
    required this.busyPalletId,
    required this.busyDestination,
  });

  @override
  Widget build(BuildContext context) {
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
          animation: animation,
          builder: (_, __) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _Arrow(animation: animation, phase: 0.0),
                const SizedBox(width: 2),
                _Arrow(animation: animation, phase: 0.33),
                const SizedBox(width: 2),
                _Arrow(animation: animation, phase: 0.66),
              ],
            );
          },
        ),
        const SizedBox(height: 6),
        Text(
          station.id,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          station.pwRole == PWRole.receive
              ? 'AMR กำลังนำ Pallet มา...'
              : 'AMR กำลังมารับ...',
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
        if (busyPalletId != null) ...[
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
                    '-> $busyDestination',
                    style: const TextStyle(color: Colors.white70, fontSize: 10),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _Arrow extends StatelessWidget {
  final Animation<double> animation;
  final double phase;

  const _Arrow({
    required this.animation,
    required this.phase,
  });

  @override
  Widget build(BuildContext context) {
    double t = (animation.value - phase) % 1.0;
    double opacity = t < 0.5 ? t * 2 : (1.0 - t) * 2;
    opacity = opacity.clamp(0.15, 1.0);

    return Opacity(
      opacity: opacity,
      child: const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 22),
    );
  }
}
