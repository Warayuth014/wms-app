// lib/screens/picking/picking_session_screen.dart

import 'package:flutter/material.dart';
import '../../theme/theme.dart';
import '../../widgets/common_widgets.dart';
import '../../services/api_service.dart';
import 'pick_items_screen.dart';

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
  final _api = ApiService();
  final _scanCtrl = TextEditingController();
  final _scanFocus = FocusNode();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scanFocus.requestFocus();
    });
  }

  Future<void> _scanPallet() async {
    final palletId = _scanCtrl.text.trim().toUpperCase();
    if (palletId.isEmpty) return;

    setState(() => _loading = true);
    final result = await _api.assignPickStation(
      palletId: palletId,
      operatorId: widget.userId,
    );
    if (!mounted) return;
    setState(() => _loading = false);

    if (!result.success) {
      showErrorDialog(
        context,
        message: result.error ?? 'สแกน Pallet ไม่สำเร็จ',
      );
      _scanCtrl.clear();
      _scanFocus.requestFocus();
      return;
    }

    final assignment = result.data!;

    // Navigate to pick flow — เริ่มจาก pickView เลย (ไม่ต้อง scan อีก)
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PickItemsScreen(
          userId: widget.userId,
          fullName: widget.fullName,
          pickOrderId: assignment.pickOrderId,
          initialAssignment: assignment,
        ),
      ),
    ).then((_) {
      // กลับมาแล้ว clear + focus ใหม่
      _scanCtrl.clear();
      _scanFocus.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: WmsAppBar(title: 'Picking', userName: widget.fullName),
      body: LoadingOverlay(
        loading: _loading,
        message: 'กำลังค้นหา...',
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Scan card
              WmsCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.qr_code_scanner,
                          color: AppTheme.primary,
                          size: 24,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Scan Pallet',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // const Text(
                    //   'สแกน Pallet ที่ต้องการ Pick\nระบบจะหา Pick Order + Station อัตโนมัติ',
                    //   style: TextStyle(fontSize: 13, color: AppTheme.textGrey),
                    // ),
                    const SizedBox(height: 16),
                    ScanTextField(
                      label: 'Pallet ID',
                      hint: 'Scan Pallet ID',
                      controller: _scanCtrl,
                      focusNode: _scanFocus,
                      onSubmit: _scanPallet,
                    ),
                    const SizedBox(height: 12),
                    PrimaryButton(
                      label: 'Scan',
                      icon: Icons.search,
                      onPressed: _scanPallet,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _scanCtrl.dispose();
    _scanFocus.dispose();
    super.dispose();
  }
}
