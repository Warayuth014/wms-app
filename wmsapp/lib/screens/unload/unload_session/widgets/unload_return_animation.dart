import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../../theme/theme.dart';
import '../../../../widgets/common_widgets.dart';

class UnloadReturnAnimation extends StatelessWidget {
  final String userName;
  final Animation<double> arrowAnimation;

  const UnloadReturnAnimation({
    super.key,
    required this.userName,
    required this.arrowAnimation,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: WmsAppBar(title: 'Unload', userName: userName),
      body: SafeArea(
        top: false,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: arrowAnimation,
                builder: (_, __) => Transform.translate(
                  offset: Offset(0, arrowAnimation.value),
                  child: const Icon(
                    Icons.arrow_upward,
                    color: AppTheme.warning,
                    size: 80,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Icon(
                MdiIcons.forklift,
                color: AppTheme.textGrey(context),
                size: 56,
              ),
              const SizedBox(height: 24),
              Text(
                'โฟล์คลิฟท์กำลังรับ Pallet...',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary(context),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'กรุณารอสักครู่',
                style: TextStyle(color: AppTheme.textGrey(context)),
              ),
              const SizedBox(height: 32),
              const _CountdownTimer(seconds: 5),
            ],
          ),
        ),
      ),
    );
  }
}

class _CountdownTimer extends StatefulWidget {
  final int seconds;

  const _CountdownTimer({required this.seconds});

  @override
  State<_CountdownTimer> createState() => _CountdownTimerState();
}

class _CountdownTimerState extends State<_CountdownTimer> {
  late int _remaining;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _remaining = widget.seconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remaining > 0) {
        setState(() => _remaining--);
      } else {
        _timer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      '$_remaining วินาที',
      style: const TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: AppTheme.warning,
      ),
    );
  }
}
