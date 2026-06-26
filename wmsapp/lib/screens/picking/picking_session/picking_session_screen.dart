// lib/screens/picking/picking_session/picking_session_screen.dart
//
// Backward-compat redirect — Home → Picking ใช้ route นี้
// เด้งไป PickingOrdersListScreen (flow ใหม่) ทันที

import 'package:flutter/material.dart';

import '../orders_list/picking_orders_list_screen.dart';

class PickingSessionScreen extends StatefulWidget {
  final String userId;
  final String fullName;

  const PickingSessionScreen({
    super.key,
    required this.userId,
    required this.fullName,
  });

  @override
  State<PickingSessionScreen> createState() => _PickingSessionScreenState();
}

class _PickingSessionScreenState extends State<PickingSessionScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PickingOrdersListScreen(
            userId: widget.userId,
            fullName: widget.fullName,
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}
